const std = @import("std");
const core = @import("azure_core");

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

    tenant_id: []const u8,
    client_id: []const u8,
    token_file_path: []const u8,
    authority_host: []const u8 = "https://login.microsoftonline.com",

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        token_file_path: []const u8,
    ) WorkloadIdentityCredential {
        return .{
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
            .tenant_id = tenant_id,
            .client_id = client_id,
            .token_file_path = token_file_path,
        };
    }

    pub fn asCredential(self: *WorkloadIdentityCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *WorkloadIdentityCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        // Read the federated token from the projected file.
        const assertion = readTokenFile(self.token_file_path) catch
            return error.WorkloadTokenFileNotFound;

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

        const body = try std.fmt.allocPrint(
            allocator,
            "grant_type=client_credentials" ++
                "&client_id={s}" ++
                "&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" ++
                "&client_assertion={s}" ++
                "&scope={s}",
            .{ self.client_id, assertion, scope },
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

fn readTokenFile(path: []const u8) ![]const u8 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch
        return error.WorkloadTokenFileNotFound;
    defer file.close(io);
    // Token files are small (typically < 4KB JWT).
    var buf: [8192]u8 = undefined;
    const n = file.readStreaming(io, &.{&buf}) catch return error.WorkloadTokenFileNotFound;
    // Trim trailing whitespace/newlines.
    const trimmed = std.mem.trimEnd(u8, buf[0..n], " \t\r\n");
    return trimmed;
}

test "WorkloadIdentityCredential fields" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    const cred = WorkloadIdentityCredential.init(
        allocator,
        mock.asTransport(),
        "tenant",
        "client",
        "/var/run/secrets/azure/tokens/azure-identity-token",
    );
    try std.testing.expectEqualStrings("tenant", cred.tenant_id);
    try std.testing.expectEqualStrings("client", cred.client_id);
}
