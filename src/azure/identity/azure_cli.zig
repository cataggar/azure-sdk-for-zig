const std = @import("std");
const core = @import("azure_core");

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
    tenant_id: ?[]const u8 = null,
    credential: TokenCredential,

    pub fn init(allocator: std.mem.Allocator) AzureCliCredential {
        return .{
            .allocator = allocator,
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

        const result = try runCommand(allocator, scope, self.tenant_id);
        defer allocator.free(result);

        return parseCliResponse(allocator, result);
    }
};

/// Parse the `az account get-access-token` JSON output.
fn parseCliResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{});
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return error.InvalidTokenResponse;

    const token_str = if (obj.get("accessToken")) |v| switch (v) {
        .string => |s| s,
        else => return error.InvalidTokenResponse,
    } else return error.InvalidTokenResponse;

    // Try expires_on (newer CLI) first, then expiresIn.
    var expires_on: i64 = 0;
    if (obj.get("expires_on")) |v| {
        switch (v) {
            .integer => |n| expires_on = n,
            .string => |s| expires_on = std.fmt.parseInt(i64, s, 10) catch 0,
            else => {},
        }
    }
    if (expires_on == 0) {
        if (obj.get("expiresIn")) |v| {
            switch (v) {
                .integer => |n| expires_on = n,
                else => {},
            }
        }
    }

    const token = try allocator.dupe(u8, token_str);
    return .{ .token = token, .expires_on = expires_on };
}

/// Run the Azure CLI command and capture stdout.
fn runCommand(allocator: std.mem.Allocator, scope: []const u8, tenant_id: ?[]const u8) ![]u8 {
    // Build argv for std.process.Child.
    var argv_buf: [8][]const u8 = undefined;
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

    // Optionally add --tenant.
    const tenant_args: [2][]const u8 = .{ "--tenant", tenant_id orelse "" };
    if (tenant_id != null) {
        argv_buf[argc] = tenant_args[0];
        argc += 1;
        argv_buf[argc] = tenant_args[1];
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

    if (term.Exited != 0) return error.AzureCliNotAvailable;

    return stdout_buf.toOwnedSlice(allocator);
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
