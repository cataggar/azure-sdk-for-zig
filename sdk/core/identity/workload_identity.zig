const std = @import("std");
const core = @import("../root.zig");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates using Kubernetes workload identity (OIDC federation).
///
/// Reads the projected service-account token from a file, then exchanges it
/// for an AAD token via the client-assertion flow.
pub const WorkloadIdentityCredential = struct {
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,

    tenant_id: []u8,
    client_id: []u8,
    token_file_path: []u8,
    authority_host: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        token_file_path: []const u8,
    ) !WorkloadIdentityCredential {
        const owned_tenant_id = try allocator.dupe(u8, tenant_id);
        errdefer allocator.free(owned_tenant_id);
        const owned_client_id = try allocator.dupe(u8, client_id);
        errdefer allocator.free(owned_client_id);
        const owned_token_file_path = try allocator.dupe(u8, token_file_path);
        errdefer allocator.free(owned_token_file_path);
        const authority_host = try allocator.dupe(u8, "https://login.microsoftonline.com");
        errdefer allocator.free(authority_host);
        return .{
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
            .tenant_id = owned_tenant_id,
            .client_id = owned_client_id,
            .token_file_path = owned_token_file_path,
            .authority_host = authority_host,
        };
    }

    pub fn asCredential(self: *WorkloadIdentityCredential) *TokenCredential {
        return &self.credential;
    }

    pub fn setAuthorityHost(
        self: *WorkloadIdentityCredential,
        authority_host: []const u8,
    ) !void {
        const replacement = try self.allocator.dupe(u8, authority_host);
        self.allocator.free(self.authority_host);
        self.authority_host = replacement;
    }

    pub fn deinit(self: *WorkloadIdentityCredential) void {
        self.allocator.free(self.tenant_id);
        self.allocator.free(self.client_id);
        self.allocator.free(self.token_file_path);
        self.allocator.free(self.authority_host);
        self.* = undefined;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *WorkloadIdentityCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        // Read the federated token from the projected file.
        const assertion = try readTokenFile(allocator, self.token_file_path);
        defer allocator.free(assertion);

        const scope = if (request_context.scopes.len > 0)
            request_context.scopes[0]
        else
            return error.NoScopesProvided;

        // POST client_assertion to the token endpoint.
        const url = try std.fmt.allocPrint(allocator, "{s}/{s}/oauth2/v2.0/token", .{
            self.authority_host,
            self.tenant_id,
        });
        defer allocator.free(url);

        const encoded_client_id = try core.url.percentEncode(allocator, self.client_id);
        defer allocator.free(encoded_client_id);
        const encoded_assertion = try core.url.percentEncode(allocator, assertion);
        defer allocator.free(encoded_assertion);
        const encoded_scope = try core.url.percentEncode(allocator, scope);
        defer allocator.free(encoded_scope);

        const body = try std.fmt.allocPrint(
            allocator,
            "grant_type=client_credentials" ++
                "&client_id={s}" ++
                "&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" ++
                "&client_assertion={s}" ++
                "&scope={s}",
            .{ encoded_client_id, encoded_assertion, encoded_scope },
        );
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/x-www-form-urlencoded");
        req.body = body;

        var resp = try self.transport.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.AuthenticationFailed;
        }

        const parse = @import("client_secret.zig");
        return parse.parseTokenResponse(allocator, resp.body);
    }
};

fn readTokenFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch
        return error.WorkloadTokenFileNotFound;
    defer file.close(io);
    var reader_buffer: [4096]u8 = undefined;
    var reader = file.readerStreaming(io, &reader_buffer);
    const contents = reader.interface.allocRemaining(allocator, .limited(8192)) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.StreamTooLong => return error.WorkloadTokenFileTooLarge,
        else => return error.WorkloadTokenFileReadFailed,
    };
    defer allocator.free(contents);
    const trimmed = std.mem.trim(u8, contents, " \t\r\n");
    if (trimmed.len == 0) return error.WorkloadTokenFileEmpty;
    return allocator.dupe(u8, trimmed);
}

test "WorkloadIdentityCredential fields" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    var cred = try WorkloadIdentityCredential.init(
        allocator,
        mock.asTransport(),
        "tenant",
        "client",
        "/var/run/secrets/azure/tokens/azure-identity-token",
    );
    defer cred.deinit();
    try std.testing.expectEqualStrings("tenant", cred.tenant_id);
    try std.testing.expectEqualStrings("client", cred.client_id);
}
