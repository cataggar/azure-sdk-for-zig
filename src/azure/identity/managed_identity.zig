const std = @import("std");
const core = @import("azure_core");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates using the Azure Instance Metadata Service (IMDS).
///
/// GET `http://169.254.169.254/metadata/identity/oauth2/token`
///   ?api-version=2018-02-01&resource={scope}[&client_id={id}]
///   Header: `Metadata: true`
pub const ManagedIdentityCredential = struct {
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,
    client_id: ?[]const u8 = null,
    endpoint: []const u8 = "http://169.254.169.254/metadata/identity/oauth2/token",

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
    ) ManagedIdentityCredential {
        return .{
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn withClientId(self: *ManagedIdentityCredential, client_id: []const u8) void {
        self.client_id = client_id;
    }

    pub fn asCredential(self: *ManagedIdentityCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *ManagedIdentityCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        // Build resource from first scope (strip /.default suffix).
        const scope = if (request_context.scopes.len > 0)
            request_context.scopes[0]
        else
            return error.NoScopesProvided;

        const resource = if (std.mem.endsWith(u8, scope, "/.default"))
            scope[0 .. scope.len - "/.default".len]
        else
            scope;

        // Build URL with query params.
        const base_url = try std.fmt.allocPrint(
            allocator,
            "{s}?api-version=2018-02-01&resource={s}",
            .{ self.endpoint, resource },
        );
        defer allocator.free(base_url);

        const url_str = if (self.client_id) |cid|
            try std.fmt.allocPrint(allocator, "{s}&client_id={s}", .{ base_url, cid })
        else
            try allocator.dupe(u8, base_url);
        defer allocator.free(url_str);

        var req = core.http.Request.init(allocator, .GET, url_str);
        defer req.deinit();
        try req.setHeader("Metadata", "true");

        var resp = try self.transport.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.AuthenticationFailed;
        }

        const parse = @import("client_secret.zig");
        return parse.parseTokenResponse(allocator, resp.body);
    }
};

test "ManagedIdentityCredential" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"msi-token","expires_in":86400}
    );
    defer mock.deinit();
    var cred = ManagedIdentityCredential.init(allocator, mock.asTransport());
    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("msi-token", token.token);
    try std.testing.expectEqual(core.http.Method.GET, mock.last_method.?);
    // Verify URL contains resource without /.default.
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "resource=https://vault.azure.net") != null);
}

test "ManagedIdentityCredential with client_id" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"msi-ua","expires_in":3600}
    );
    defer mock.deinit();
    var cred = ManagedIdentityCredential.init(allocator, mock.asTransport());
    cred.withClientId("user-assigned-id");
    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://storage.azure.com/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("msi-ua", token.token);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "client_id=user-assigned-id") != null);
}
