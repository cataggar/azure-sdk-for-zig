const std = @import("std");
const core = @import("../root.zig");
const serde = @import("serde");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates a service principal with a client secret (OAuth 2.0 client_credentials).
///
/// POST `{authority}/{tenant_id}/oauth2/v2.0/token`
/// Form: `grant_type=client_credentials&client_id=...&client_secret=...&scope=...`
pub const ClientSecretCredential = struct {
    tenant_id: []const u8,
    client_id: []const u8,
    client_secret: []const u8,
    authority_host: []const u8 = "https://login.microsoftonline.com",
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        client_secret: []const u8,
    ) ClientSecretCredential {
        return .{
            .tenant_id = tenant_id,
            .client_id = client_id,
            .client_secret = client_secret,
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *ClientSecretCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *ClientSecretCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        // Build URL.
        const url = try std.fmt.allocPrint(allocator, "{s}/{s}/oauth2/v2.0/token", .{
            self.authority_host,
            self.tenant_id,
        });
        defer allocator.free(url);

        // Build scope string (space-separated).
        var scope_buf: std.ArrayList(u8) = .empty;
        defer scope_buf.deinit(allocator);
        for (request_context.scopes, 0..) |scope, i| {
            if (i > 0) try scope_buf.append(allocator, ' ');
            try scope_buf.appendSlice(allocator, scope);
        }

        // Build form body.
        const body = try std.fmt.allocPrint(allocator, "grant_type=client_credentials&client_id={s}&client_secret={s}&scope={s}", .{
            self.client_id,
            self.client_secret,
            scope_buf.items,
        });
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

        return parseTokenResponse(allocator, resp.body);
    }
};

/// Parse the standard OAuth2 token response JSON.
///
/// The returned `token` slice is allocated with `allocator` — caller must free.
pub fn parseTokenResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    // OAuth2 RFC 6749 §5.1: `expires_in` is a JSON number.
    const TokenResponseSchema = struct {
        access_token: []const u8,
        expires_in: i64 = 3600,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(TokenResponseSchema, arena.allocator(), body) catch
        return error.InvalidTokenResponse;

    const token = try allocator.dupe(u8, parsed.access_token);
    return .{ .token = token, .expires_on = parsed.expires_in };
}

test "parseTokenResponse" {
    const body =
        \\{"access_token":"eyJ0eXAi","expires_in":3600,"token_type":"Bearer"}
    ;
    const token = try parseTokenResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("eyJ0eXAi", token.token);
    try std.testing.expectEqual(@as(i64, 3600), token.expires_on);
}

test "ClientSecretCredential init" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"mock-token","expires_in":3600}
    );
    defer mock.deinit();
    var cred = ClientSecretCredential.init(
        allocator,
        mock.asTransport(),
        "tenant-123",
        "client-456",
        "secret-789",
    );
    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("mock-token", token.token);
    try std.testing.expectEqual(@as(i64, 3600), token.expires_on);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
}

test "ClientSecretCredential auth failure" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 401,
        \\{"error":"invalid_client","error_description":"Invalid client secret"}
    );
    defer mock.deinit();
    var cred = ClientSecretCredential.init(
        allocator,
        mock.asTransport(),
        "tenant-123",
        "client-456",
        "bad-secret",
    );
    const result = cred.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    try std.testing.expectError(error.AuthenticationFailed, result);
}

test "parseTokenResponse malformed JSON" {
    const result = parseTokenResponse(std.testing.allocator, "not json");
    try std.testing.expectError(error.InvalidTokenResponse, result);
}

test "parseTokenResponse missing access_token" {
    const result = parseTokenResponse(std.testing.allocator, "{}");
    try std.testing.expectError(error.InvalidTokenResponse, result);
}
