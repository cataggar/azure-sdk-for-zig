const std = @import("std");
const core = @import("azure_core");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates using environment variables.
///
/// Requires `AZURE_TENANT_ID` + `AZURE_CLIENT_ID`, then one of:
///   - `AZURE_CLIENT_SECRET`          → ClientSecretCredential
///   - `AZURE_CLIENT_CERTIFICATE_PATH` → (not yet implemented)
///
/// Optional: `AZURE_AUTHORITY_HOST` overrides the AAD endpoint.
pub const EnvironmentCredential = struct {
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,

    // Captured from env at init time.
    tenant_id: []const u8,
    client_id: []const u8,
    client_secret: ?[]const u8 = null,
    authority_host: []const u8 = "https://login.microsoftonline.com",

    /// Reads environment variables eagerly. Returns `error.EnvironmentNotConfigured`
    /// if the required vars are missing.
    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        env: anytype,
    ) !EnvironmentCredential {
        const tenant_id = envGet(env, "AZURE_TENANT_ID") orelse return error.EnvironmentNotConfigured;
        const client_id = envGet(env, "AZURE_CLIENT_ID") orelse return error.EnvironmentNotConfigured;
        const client_secret = envGet(env, "AZURE_CLIENT_SECRET");
        const authority = envGet(env, "AZURE_AUTHORITY_HOST") orelse "https://login.microsoftonline.com";

        if (client_secret == null) return error.EnvironmentNotConfigured;

        return .{
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
            .tenant_id = tenant_id,
            .client_id = client_id,
            .client_secret = client_secret,
            .authority_host = authority,
        };
    }

    pub fn asCredential(self: *EnvironmentCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: Context,
    ) anyerror!AccessToken {
        const self: *EnvironmentCredential = @fieldParentPtr("credential", cred);
        // Delegate to ClientSecretCredential.
        const client_secret_mod = @import("client_secret.zig");
        var inner = client_secret_mod.ClientSecretCredential.init(
            self.allocator,
            self.transport,
            self.tenant_id,
            self.client_id,
            self.client_secret.?,
        );
        inner.authority_host = self.authority_host;
        return inner.asCredential().getToken(request_context, ctx);
    }
};

/// Helper: read from a map-like env (supports both std.process.Environ.Map
/// and simple test hash maps).
fn envGet(env: anytype, key: []const u8) ?[]const u8 {
    return env.get(key);
}

/// Simple string map for testing (mimics env).
const TestEnv = struct {
    map: std.StringHashMap([]const u8),

    fn init(allocator: std.mem.Allocator) TestEnv {
        return .{ .map = std.StringHashMap([]const u8).init(allocator) };
    }
    fn put(self: *TestEnv, k: []const u8, v: []const u8) !void {
        try self.map.put(k, v);
    }
    fn get(self: TestEnv, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }
    fn deinit(self: *TestEnv) void {
        self.map.deinit();
    }
};

test "EnvironmentCredential missing vars" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var env = TestEnv.init(allocator);
    defer env.deinit();
    // No vars set → should fail.
    const result = EnvironmentCredential.init(allocator, mock.asTransport(), env);
    try std.testing.expectError(error.EnvironmentNotConfigured, result);
}

test "EnvironmentCredential with secret" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"env-token","expires_in":1800}
    );
    defer mock.deinit();
    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TENANT_ID", "t");
    try env.put("AZURE_CLIENT_ID", "c");
    try env.put("AZURE_CLIENT_SECRET", "s");

    var cred = try EnvironmentCredential.init(allocator, mock.asTransport(), env);
    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://management.azure.com/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("env-token", token.token);
}
