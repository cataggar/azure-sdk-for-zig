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

        // Build command.
        const base_cmd = try std.fmt.allocPrint(
            allocator,
            "az account get-access-token --output json --scope \"{s}\"",
            .{scope},
        );
        defer allocator.free(base_cmd);

        const cmd = if (self.tenant_id) |tid|
            try std.fmt.allocPrint(allocator, "{s} --tenant \"{s}\"", .{ base_cmd, tid })
        else
            try allocator.dupe(u8, base_cmd);
        defer allocator.free(cmd);

        // Execute.
        const result = try runCommand(allocator, cmd);
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

/// Run a shell command and capture stdout (platform-aware).
fn runCommand(allocator: std.mem.Allocator, cmd: []const u8) ![]u8 {
    _ = allocator;
    _ = cmd;
    // In production this would use std.process.Child.
    // For now, return an error — actual CLI exec requires std.Io.
    return error.AzureCliNotAvailable;
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
