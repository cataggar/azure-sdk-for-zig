const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates using a locally installed Azure CLI.
///
/// Shells out: `az account get-access-token --output json --scope {scope}`
/// Parses JSON response fields: `accessToken`, `expiresOn`.
pub const AzureCliCredential = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    tenant_id: ?[]const u8 = null,
    credential: TokenCredential,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) AzureCliCredential {
        return .{
            .allocator = allocator,
            .io = io,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *AzureCliCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *AzureCliCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        const scope = if (request_context.scopes.len > 0)
            request_context.scopes[0]
        else
            return error.NoScopesProvided;

        const result = try runCommand(allocator, self.io, scope, self.tenant_id);
        defer allocator.free(result);

        return parseCliResponse(allocator, result);
    }
};

/// Parse the `az account get-access-token` JSON output.
///
/// Azure CLI emits `expires_on` (POSIX timestamp seconds) — older versions
/// stringify it, newer versions return an integer. We accept either by
/// running two best-effort passes against the same JSON body.
fn parseCliResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    const SchemaInt = struct {
        accessToken: []const u8,
        expires_on: ?i64 = null,
        expiresIn: ?i64 = null,
    };
    const SchemaStr = struct {
        accessToken: []const u8,
        expires_on: ?[]const u8 = null,
        expiresIn: ?i64 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var access_token: []const u8 = "";
    var expires_on: i64 = 0;

    if (serde.json.fromSlice(SchemaInt, arena.allocator(), body)) |parsed| {
        access_token = parsed.accessToken;
        if (parsed.expires_on) |n| expires_on = n;
        if (expires_on == 0) {
            if (parsed.expiresIn) |n| expires_on = n;
        }
    } else |_| {
        const parsed = serde.json.fromSlice(SchemaStr, arena.allocator(), body) catch
            return error.InvalidTokenResponse;
        access_token = parsed.accessToken;
        if (parsed.expires_on) |s|
            expires_on = std.fmt.parseInt(i64, s, 10) catch 0;
        if (expires_on == 0) {
            if (parsed.expiresIn) |n| expires_on = n;
        }
    }

    const token = try allocator.dupe(u8, access_token);
    return .{ .token = token, .expires_on = expires_on };
}

/// Run the Azure CLI command and capture stdout.
fn runCommand(allocator: std.mem.Allocator, io: std.Io, scope: []const u8, tenant_id: ?[]const u8) ![]u8 {
    // Build argv for std.process.run.
    var argv_buf: [9][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "az";
    argc += 1;
    argv_buf[argc] = "account";
    argc += 1;
    argv_buf[argc] = "get-access-token";
    argc += 1;
    argv_buf[argc] = "--output";
    argc += 1;
    argv_buf[argc] = "json";
    argc += 1;
    argv_buf[argc] = "--scope";
    argc += 1;
    argv_buf[argc] = scope;
    argc += 1;

    if (tenant_id) |t| {
        argv_buf[argc] = "--tenant";
        argc += 1;
        argv_buf[argc] = t;
        argc += 1;
    }

    const result = try std.process.run(allocator, io, .{
        .argv = argv_buf[0..argc],
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    defer allocator.free(result.stderr);
    errdefer allocator.free(result.stdout);

    switch (result.term) {
        .exited => |code| if (code != 0) return error.AzureCliNotAvailable,
        else => return error.AzureCliNotAvailable,
    }

    return result.stdout;
}

test "parseCliResponse" {
    const body =
        \\{"accessToken":"cli-tok","expiresOn":"2026-04-01 15:00:00","expires_on":"1743523200"}
    ;
    const token = try parseCliResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("cli-tok", token.token);
    try std.testing.expectEqual(@as(i64, 1743523200), token.expires_on);
}

test "parseCliResponse accepts integer expires_on" {
    // Modern Azure CLI emits expires_on as a POSIX timestamp integer
    // and includes additional fields (subscription, tenant, tokenType).
    const body =
        \\{"accessToken":"cli-tok-2","expiresOn":"2026-04-01 15:00:00.000000","expires_on":1743523200,"subscription":"sub","tenant":"tenant","tokenType":"Bearer"}
    ;
    const token = try parseCliResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("cli-tok-2", token.token);
    try std.testing.expectEqual(@as(i64, 1743523200), token.expires_on);
}
