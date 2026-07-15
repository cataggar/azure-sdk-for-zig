const std = @import("std");
const core = @import("../root.zig");
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
/// `expiresOn` is normally RFC3339; numeric Unix seconds are accepted for
/// compatibility with older fixtures and CLI versions.
fn parseAzdResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    const AzdResponseSchema = struct {
        token: []const u8,
        expiresOn: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(AzdResponseSchema, arena.allocator(), body) catch
        return error.InvalidTokenResponse;

    const expiration = parsed.expiresOn orelse return error.InvalidTokenResponse;
    const expires_on = std.fmt.parseInt(i64, expiration, 10) catch
        parseRfc3339Unix(expiration) catch return error.InvalidTokenResponse;
    if (expires_on <= 0) return error.InvalidTokenResponse;

    const token = try allocator.dupe(u8, parsed.token);
    return .{
        .token = token,
        .expires_on = expires_on,
        .allocator = allocator,
    };
}

fn parseRfc3339Unix(value: []const u8) !i64 {
    if (value.len < 20 or
        value[4] != '-' or
        value[7] != '-' or
        value[10] != 'T' or
        value[13] != ':' or
        value[16] != ':')
    {
        return error.InvalidRfc3339;
    }

    const year = try std.fmt.parseInt(i64, value[0..4], 10);
    const month_number = try std.fmt.parseInt(u8, value[5..7], 10);
    const day = try std.fmt.parseInt(u8, value[8..10], 10);
    const hour = try std.fmt.parseInt(u8, value[11..13], 10);
    const minute = try std.fmt.parseInt(u8, value[14..16], 10);
    const second = try std.fmt.parseInt(u8, value[17..19], 10);
    if (year < 1 or hour > 23 or minute > 59 or second > 59)
        return error.InvalidRfc3339;
    const month = std.enums.fromInt(std.time.epoch.Month, month_number) orelse
        return error.InvalidRfc3339;
    if (day == 0 or day > std.time.epoch.getDaysInMonth(@intCast(year), month))
        return error.InvalidRfc3339;

    var timezone_index: usize = 19;
    if (timezone_index < value.len and value[timezone_index] == '.') {
        timezone_index += 1;
        const fraction_start = timezone_index;
        while (timezone_index < value.len and std.ascii.isDigit(value[timezone_index])) {
            timezone_index += 1;
        }
        if (timezone_index == fraction_start) return error.InvalidRfc3339;
    }

    var offset_seconds: i64 = 0;
    if (timezone_index < value.len and value[timezone_index] == 'Z') {
        if (timezone_index + 1 != value.len) return error.InvalidRfc3339;
    } else {
        if (timezone_index + 6 != value.len or
            (value[timezone_index] != '+' and value[timezone_index] != '-') or
            value[timezone_index + 3] != ':')
        {
            return error.InvalidRfc3339;
        }
        const offset_hour = try std.fmt.parseInt(u8, value[timezone_index + 1 .. timezone_index + 3], 10);
        const offset_minute = try std.fmt.parseInt(u8, value[timezone_index + 4 .. timezone_index + 6], 10);
        if (offset_hour > 23 or offset_minute > 59) return error.InvalidRfc3339;
        const magnitude = @as(i64, offset_hour) * 3600 + @as(i64, offset_minute) * 60;
        offset_seconds = if (value[timezone_index] == '+') magnitude else -magnitude;
    }

    const adjusted_year = year - @intFromBool(month_number <= 2);
    const era = @divFloor(adjusted_year, 400);
    const year_of_era = adjusted_year - era * 400;
    const adjusted_month = @as(i64, month_number) +
        (if (month_number > 2) @as(i64, -3) else @as(i64, 9));
    const day_of_year = @divFloor(153 * adjusted_month + 2, 5) + day - 1;
    const day_of_era = year_of_era * 365 + @divFloor(year_of_era, 4) -
        @divFloor(year_of_era, 100) + day_of_year;
    const days_since_epoch = era * 146_097 + day_of_era - 719_468;
    const local_seconds = days_since_epoch * std.time.s_per_day +
        @as(i64, hour) * std.time.s_per_hour +
        @as(i64, minute) * std.time.s_per_min +
        second;
    return local_seconds - offset_seconds;
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
        \\{"token":"azd-tok-123","expiresOn":"2025-04-01T12:30:45Z"}
    ;
    const token = try parseAzdResponse(std.testing.allocator, body);
    defer std.testing.allocator.free(token.token);
    try std.testing.expectEqualStrings("azd-tok-123", token.token);
    try std.testing.expectEqual(@as(i64, 1743510645), token.expires_on);
}
