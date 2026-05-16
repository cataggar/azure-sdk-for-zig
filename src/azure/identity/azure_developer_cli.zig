const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates using the Azure Developer CLI (`azd`).
///
/// Shells out: `azd auth token --output json --scope {scope}`
/// Parses JSON response fields: `token`, `expiresOn`.
pub const AzureDeveloperCliCredential = struct {
    allocator: std.mem.Allocator,
    tenant_id: ?[]const u8 = null,
    credential: TokenCredential,

    pub fn init(allocator: std.mem.Allocator) AzureDeveloperCliCredential {
        return .{
            .allocator = allocator,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *AzureDeveloperCliCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *AzureDeveloperCliCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        const scope = if (request_context.scopes.len > 0)
            request_context.scopes[0]
        else
            return error.NoScopesProvided;

        const result = try runCommand(allocator, scope, self.tenant_id);
        defer allocator.free(result);

        return parseAzdResponse(allocator, result);
    }
};

/// Parse the `azd auth token` JSON output.
/// Format: {"token":"...","expiresOn":"<unix-seconds>"}
fn parseAzdResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    const AzdResponseSchema = struct {
        token: []const u8,
        expiresOn: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(AzdResponseSchema, arena.allocator(), body) catch
        return error.InvalidTokenResponse;

    var expires_on: i64 = 0;
    if (parsed.expiresOn) |s|
        expires_on = std.fmt.parseInt(i64, s, 10) catch 0;

    const token = try allocator.dupe(u8, parsed.token);
    return .{ .token = token, .expires_on = expires_on };
}

/// Run the azd auth token command and capture stdout.
fn runCommand(allocator: std.mem.Allocator, scope: []const u8, tenant_id: ?[]const u8) ![]u8 {
    var argv_buf: [8][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "azd";
    argc += 1;
    argv_buf[argc] = "auth";
    argc += 1;
    argv_buf[argc] = "token";
    argc += 1;
    argv_buf[argc] = "--output";
    argc += 1;
    argv_buf[argc] = "json";
    argc += 1;
    argv_buf[argc] = "--scope";
    argc += 1;
    argv_buf[argc] = scope;
    argc += 1;

    if (tenant_id) |tid| {
        argv_buf[argc] = "--tenant-id";
        argc += 1;
        argv_buf[argc] = tid;
        argc += 1;
    }

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var stdout_buf: std.ArrayList(u8) = .empty;
    defer stdout_buf.deinit(allocator);
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);

    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1024 * 1024);
    const term = try child.wait();

    if (term.Exited != 0) return error.AzdCliNotAvailable;

    return stdout_buf.toOwnedSlice(allocator);
}

test "parseAzdResponse" {
    const body =
        \\{"token":"azd-tok-123","expiresOn":"1743523200"}
    ;
    const token = try parseAzdResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("azd-tok-123", token.token);
    try std.testing.expectEqual(@as(i64, 1743523200), token.expires_on);
}
