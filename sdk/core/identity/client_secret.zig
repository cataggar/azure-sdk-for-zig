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

        const encoded_client_id = try core.url.percentEncode(allocator, self.client_id);
        defer allocator.free(encoded_client_id);
        const encoded_client_secret = try core.url.percentEncode(allocator, self.client_secret);
        defer allocator.free(encoded_client_secret);
        const encoded_scope = try core.url.percentEncode(allocator, scope_buf.items);
        defer allocator.free(encoded_scope);

        // Build form body.
        const body = try std.fmt.allocPrint(allocator, "grant_type=client_credentials&client_id={s}&client_secret={s}&scope={s}", .{
            encoded_client_id,
            encoded_client_secret,
            encoded_scope,
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
    const NumericTokenResponse = struct {
        access_token: []const u8,
        expires_in: ?i64 = null,
        expires_on: ?i64 = null,
    };
    const StringTokenResponse = struct {
        access_token: []const u8,
        expires_in: ?[]const u8 = null,
        expires_on: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    if (serde.json.fromSlice(NumericTokenResponse, arena.allocator(), body)) |parsed| {
        return makeAccessToken(
            allocator,
            parsed.access_token,
            parsed.expires_in,
            parsed.expires_on,
        );
    } else |_| {}

    const parsed = serde.json.fromSlice(StringTokenResponse, arena.allocator(), body) catch
        return error.InvalidTokenResponse;
    const expires_in = if (parsed.expires_in) |value|
        std.fmt.parseInt(i64, value, 10) catch return error.InvalidTokenResponse
    else
        null;
    const expires_on = if (parsed.expires_on) |value|
        std.fmt.parseInt(i64, value, 10) catch return error.InvalidTokenResponse
    else
        null;
    return makeAccessToken(allocator, parsed.access_token, expires_in, expires_on);
}

fn makeAccessToken(
    allocator: std.mem.Allocator,
    token_value: []const u8,
    expires_in: ?i64,
    absolute_expires_on: ?i64,
) !AccessToken {
    const expires_on = if (absolute_expires_on) |value| blk: {
        if (value <= 0) return error.InvalidTokenResponse;
        break :blk value;
    } else blk: {
        const duration = expires_in orelse 3600;
        if (duration <= 0) return error.InvalidTokenResponse;
        break :blk std.math.add(
            i64,
            currentTimestamp(),
            duration,
        ) catch return error.InvalidTokenResponse;
    };
    const token = try allocator.dupe(u8, token_value);
    return .{
        .token = token,
        .expires_on = expires_on,
        .allocator = allocator,
    };
}

fn currentTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
}

test "parseTokenResponse" {
    const body =
        \\{"access_token":"eyJ0eXAi","expires_in":3600,"token_type":"Bearer"}
    ;
    const before = currentTimestamp();
    const token = try parseTokenResponse(std.testing.allocator, body);
    const after = currentTimestamp();
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("eyJ0eXAi", token.token);
    try std.testing.expect(token.expires_on >= before + 3600);
    try std.testing.expect(token.expires_on <= after + 3600);
}

test "parseTokenResponse accepts IMDS string expiration" {
    const body =
        \\{"access_token":"imds-token","expires_in":"3599","expires_on":"1910000000","token_type":"Bearer"}
    ;
    const token = try parseTokenResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("imds-token", token.token);
    try std.testing.expectEqual(@as(i64, 1910000000), token.expires_on);
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
    const before = currentTimestamp();
    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    const after = currentTimestamp();
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("mock-token", token.token);
    try std.testing.expect(token.expires_on >= before + 3600);
    try std.testing.expect(token.expires_on <= after + 3600);
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

test "ClientSecretCredential form-encodes dynamic fields" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"mock-token","expires_in":3600}
    );
    defer mock.deinit();
    var credential = ClientSecretCredential.init(
        allocator,
        mock.asTransport(),
        "tenant",
        "client&id",
        "secret+=&%",
    );
    var token = try credential.asCredential().getToken(
        .{ .scopes = &.{"scope one"} },
        Context.none,
    );
    defer token.deinit();
    try std.testing.expectEqualStrings(
        "grant_type=client_credentials&client_id=client%26id&client_secret=secret%2B%3D%26%25&scope=scope%20one",
        mock.last_body.?,
    );
}

test "parseTokenResponse malformed JSON" {
    const result = parseTokenResponse(std.testing.allocator, "not json");
    try std.testing.expectError(error.InvalidTokenResponse, result);
}

test "parseTokenResponse missing access_token" {
    const result = parseTokenResponse(std.testing.allocator, "{}");
    try std.testing.expectError(error.InvalidTokenResponse, result);
}
