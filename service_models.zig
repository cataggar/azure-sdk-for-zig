//! Stored access policy, metrics, logging, CORS, and geo-replication models.

const std = @import("std");
const protocol = @import("azure_rest_data_tables");
const sas = @import("sas.zig");
const serde = @import("serde");

pub const max_stored_access_policies = 5;

/// Azure Tables stores policy timestamps at 100-nanosecond precision.
///
/// `parse` accepts an ISO 8601 UTC designator or numeric offset and normalizes
/// the represented instant to UTC. The original fractional precision is
/// retained so a generated XML round trip does not invent precision.
pub const AccessPolicyTime = struct {
    unix_seconds: i64,
    fraction_100ns: u32 = 0,
    fractional_digits: u8 = 0,

    pub fn fromUnixSeconds(unix_seconds: i64) AccessPolicyTime {
        return .{ .unix_seconds = unix_seconds };
    }

    pub fn fromUnixNanoseconds(unix_seconds: i64, nanoseconds: u32) !AccessPolicyTime {
        if (nanoseconds >= std.time.ns_per_s) return error.InvalidAccessPolicyTime;
        if (nanoseconds % 100 != 0) return error.AccessPolicyTimePrecisionLoss;
        const ticks = nanoseconds / 100;
        return .{
            .unix_seconds = unix_seconds,
            .fraction_100ns = ticks,
            .fractional_digits = if (ticks == 0) 0 else 7,
        };
    }

    pub fn parse(value: []const u8) !AccessPolicyTime {
        if (value.len < 20 or value[4] != '-' or value[7] != '-' or
            (value[10] != 'T' and value[10] != 't') or value[13] != ':' or
            value[16] != ':')
        {
            return error.InvalidAccessPolicyTime;
        }

        const year = try parseDigits(value[0..4]);
        const month = try parseDigits(value[5..7]);
        const day = try parseDigits(value[8..10]);
        const hour = try parseDigits(value[11..13]);
        const minute = try parseDigits(value[14..16]);
        const second = try parseDigits(value[17..19]);
        if (year < 1 or year > 9999 or month < 1 or month > 12 or
            day < 1 or day > daysInMonth(year, month) or hour > 23 or
            minute > 59 or second > 59)
        {
            return error.InvalidAccessPolicyTime;
        }

        var index: usize = 19;
        var ticks: u32 = 0;
        var precision: u8 = 0;
        if (index < value.len and value[index] == '.') {
            index += 1;
            const fraction_start = index;
            while (index < value.len and std.ascii.isDigit(value[index])) : (index += 1) {
                if (precision == 7) return error.AccessPolicyTimePrecisionLoss;
                ticks = ticks * 10 + (value[index] - '0');
                precision += 1;
            }
            if (index == fraction_start) return error.InvalidAccessPolicyTime;
            var pad = precision;
            while (pad < 7) : (pad += 1) ticks *= 10;
        }

        var offset_seconds: i64 = 0;
        if (index == value.len) return error.InvalidAccessPolicyTime;
        switch (value[index]) {
            'Z', 'z' => index += 1,
            '+', '-' => |sign| {
                if (index + 6 != value.len or value[index + 3] != ':')
                    return error.InvalidAccessPolicyTime;
                const offset_hour = try parseDigits(value[index + 1 .. index + 3]);
                const offset_minute = try parseDigits(value[index + 4 .. index + 6]);
                if (offset_hour > 23 or offset_minute > 59)
                    return error.InvalidAccessPolicyTime;
                offset_seconds = @as(i64, @intCast(offset_hour * 3600 + offset_minute * 60));
                if (sign == '-') offset_seconds = -offset_seconds;
                index += 6;
            },
            else => return error.InvalidAccessPolicyTime,
        }
        if (index != value.len) return error.InvalidAccessPolicyTime;

        const days = daysFromCivil(
            @as(i64, @intCast(year)),
            @as(i64, @intCast(month)),
            @as(i64, @intCast(day)),
        );
        const local_seconds = try std.math.add(
            i64,
            try std.math.mul(i64, days, std.time.s_per_day),
            @as(i64, @intCast(hour * 3600 + minute * 60 + second)),
        );
        return .{
            .unix_seconds = try std.math.sub(i64, local_seconds, offset_seconds),
            .fraction_100ns = ticks,
            .fractional_digits = precision,
        };
    }

    pub fn format(self: AccessPolicyTime, buffer: *[32]u8) ![]const u8 {
        if (self.fraction_100ns >= 10_000_000 or self.fractional_digits > 7)
            return error.InvalidAccessPolicyTime;
        const divisor = powers_of_ten[7 - self.fractional_digits];
        if (self.fraction_100ns % divisor != 0)
            return error.AccessPolicyTimePrecisionLoss;

        const days = @divFloor(self.unix_seconds, std.time.s_per_day);
        const seconds: u64 = @intCast(@mod(self.unix_seconds, std.time.s_per_day));
        const civil = civilFromDays(days);
        if (civil.year < 1 or civil.year > 9999) return error.InvalidAccessPolicyTime;

        var output = std.Io.Writer.fixed(buffer);
        try output.print(
            "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}",
            .{
                @as(u64, @intCast(civil.year)),
                @as(u64, @intCast(civil.month)),
                @as(u64, @intCast(civil.day)),
                seconds / 3600,
                (seconds / 60) % 60,
                seconds % 60,
            },
        );
        if (self.fractional_digits != 0) {
            try output.writeByte('.');
            try output.print(
                "{d:0>[1]}",
                .{ self.fraction_100ns / divisor, self.fractional_digits },
            );
        }
        try output.writeByte('Z');
        return output.buffered();
    }
};

/// Policy permission bytes. `.table` provides the same canonical `raud`
/// ordering as table SAS generation; `.raw` preserves service extensions.
pub const AccessPolicyPermissions = union(enum) {
    table: sas.TablePermissions,
    raw: []const u8,

    pub fn string(self: AccessPolicyPermissions, buffer: *[4]u8) []const u8 {
        return switch (self) {
            .table => |permissions| permissions.string(buffer),
            .raw => |value| value,
        };
    }
};

/// Borrowed input model. Values returned by `getAccessPolicy` are owned by the
/// response arena and remain valid until the response is deinitialized.
pub const AccessPolicy = struct {
    start: ?AccessPolicyTime = null,
    expiry: ?AccessPolicyTime = null,
    permissions: AccessPolicyPermissions = .{ .raw = "" },
};

/// Borrowed input model. A response owns the identifier and raw permission
/// slices in its response arena.
pub const SignedIdentifier = struct {
    id: []const u8,
    access_policy: AccessPolicy,
};

pub fn toWire(
    allocator: std.mem.Allocator,
    identifiers: []const SignedIdentifier,
) !protocol.models.SignedIdentifiers {
    const wire = try allocator.alloc(protocol.models.SignedIdentifier, identifiers.len);
    var initialized: usize = 0;
    errdefer {
        for (wire[0..initialized]) |identifier| {
            allocator.free(identifier.id);
            allocator.free(identifier.access_policy.start);
            allocator.free(identifier.access_policy.expiry);
            allocator.free(identifier.access_policy.permission);
        }
        allocator.free(wire);
    }
    for (identifiers, wire) |identifier, *destination| {
        var start_buffer: [32]u8 = undefined;
        const start = if (identifier.access_policy.start) |value|
            try value.format(&start_buffer)
        else
            "";
        var expiry_buffer: [32]u8 = undefined;
        const expiry = if (identifier.access_policy.expiry) |value|
            try value.format(&expiry_buffer)
        else
            "";
        var permission_buffer: [4]u8 = undefined;
        const permission = identifier.access_policy.permissions.string(&permission_buffer);
        const id = try allocator.dupe(u8, identifier.id);
        errdefer allocator.free(id);
        const wire_start = try allocator.dupe(u8, start);
        errdefer allocator.free(wire_start);
        const wire_expiry = try allocator.dupe(u8, expiry);
        errdefer allocator.free(wire_expiry);
        const wire_permission = try allocator.dupe(u8, permission);
        destination.* = .{
            .id = id,
            .access_policy = .{
                .start = wire_start,
                .expiry = wire_expiry,
                .permission = wire_permission,
            },
        };
        initialized += 1;
    }
    return .{ .identifiers = wire };
}

pub fn fromWire(
    allocator: std.mem.Allocator,
    wire: protocol.models.SignedIdentifiers,
) ![]const SignedIdentifier {
    const identifiers = try allocator.alloc(SignedIdentifier, wire.identifiers.len);
    errdefer allocator.free(identifiers);
    for (wire.identifiers, identifiers) |source, *destination| {
        destination.* = .{
            .id = source.id,
            .access_policy = .{
                .start = if (source.access_policy.start.len == 0)
                    null
                else
                    try AccessPolicyTime.parse(source.access_policy.start),
                .expiry = if (source.access_policy.expiry.len == 0)
                    null
                else
                    try AccessPolicyTime.parse(source.access_policy.expiry),
                .permissions = .{ .raw = source.access_policy.permission },
            },
        };
    }
    return identifiers;
}

/// Recognizes a valid empty generated XML collection when the generated
/// required-slice decoder reports `MissingField`.
pub fn isEmptyWireXml(body: []const u8) !bool {
    var scanner = serde.xml.Scanner{ .input = body };
    var depth: usize = 0;
    var root_seen = false;
    var root_closed = false;
    while (true) {
        switch (try scanner.next()) {
            .element_open => |name| {
                if (root_closed) return error.MalformedXml;
                if (!root_seen) {
                    if (!std.mem.eql(u8, name, "SignedIdentifiers"))
                        return false;
                    root_seen = true;
                } else if (depth == 1) {
                    return false;
                }
                depth += 1;
            },
            .self_closing => |name| {
                if (!root_seen) {
                    if (!std.mem.eql(u8, name, "SignedIdentifiers"))
                        return false;
                    root_seen = true;
                    root_closed = true;
                } else {
                    return false;
                }
            },
            .element_close => |name| {
                if (depth == 0) return error.MalformedXml;
                depth -= 1;
                if (depth == 0) {
                    if (!std.mem.eql(u8, name, "SignedIdentifiers"))
                        return error.MalformedXml;
                    root_closed = true;
                }
            },
            .text, .cdata => |text| {
                if (depth == 0 and std.mem.trim(u8, text, " \t\r\n").len != 0)
                    return error.MalformedXml;
                if (depth == 1 and std.mem.trim(u8, text, " \t\r\n").len != 0)
                    return false;
            },
            .attribute, .tag_end => {
                if (depth == 0) return error.MalformedXml;
            },
            .eof => {
                if (!root_seen or !root_closed or depth != 0)
                    return error.UnexpectedEof;
                return true;
            },
        }
    }
}

const powers_of_ten = [_]u32{
    1,
    10,
    100,
    1_000,
    10_000,
    100_000,
    1_000_000,
    10_000_000,
};

fn parseDigits(value: []const u8) !u32 {
    var result: u32 = 0;
    for (value) |byte| {
        if (!std.ascii.isDigit(byte)) return error.InvalidAccessPolicyTime;
        result = result * 10 + (byte - '0');
    }
    return result;
}

fn isLeapYear(year: u32) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

fn daysInMonth(year: u32, month: u32) u32 {
    return switch (month) {
        2 => if (isLeapYear(year)) 29 else 28,
        4, 6, 9, 11 => 30,
        else => 31,
    };
}

fn daysFromCivil(input_year: i64, month: i64, day: i64) i64 {
    const year = input_year - @intFromBool(month <= 2);
    const era = @divFloor(year, 400);
    const year_of_era = year - era * 400;
    const adjusted_month = month + (if (month > 2) @as(i64, -3) else 9);
    const day_of_year = @divFloor(153 * adjusted_month + 2, 5) + day - 1;
    const day_of_era = year_of_era * 365 + @divFloor(year_of_era, 4) -
        @divFloor(year_of_era, 100) + day_of_year;
    return era * 146_097 + day_of_era - 719_468;
}

fn civilFromDays(days: i64) struct { year: i64, month: i64, day: i64 } {
    const z = days + 719_468;
    const era = @divFloor(if (z >= 0) z else z - 146_096, 146_097);
    const day_of_era = z - era * 146_097;
    const year_of_era = @divFloor(
        day_of_era - @divFloor(day_of_era, 1460) +
            @divFloor(day_of_era, 36_524) - @divFloor(day_of_era, 146_096),
        365,
    );
    var year = year_of_era + era * 400;
    const day_of_year = day_of_era -
        (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));
    const month_prime = @divFloor(5 * day_of_year + 2, 153);
    const day = day_of_year - @divFloor(153 * month_prime + 2, 5) + 1;
    const month = month_prime + (if (month_prime < 10) @as(i64, 3) else -9);
    year += @intFromBool(month <= 2);
    return .{ .year = year, .month = month, .day = day };
}

test "access policy times normalize offsets and preserve service precision" {
    const cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "2026-07-26T18:32:16Z", .expected = "2026-07-26T18:32:16Z" },
        .{ .input = "2026-07-26T20:02:16.1234567+01:30", .expected = "2026-07-26T18:32:16.1234567Z" },
        .{ .input = "2026-07-25T23:32:16.120-19:00", .expected = "2026-07-26T18:32:16.120Z" },
        .{ .input = "1970-01-01T00:00:00.0000001Z", .expected = "1970-01-01T00:00:00.0000001Z" },
        .{ .input = "1969-12-31T23:59:59.9Z", .expected = "1969-12-31T23:59:59.9Z" },
    };
    for (cases) |case| {
        const parsed = try AccessPolicyTime.parse(case.input);
        var buffer: [32]u8 = undefined;
        try std.testing.expectEqualStrings(case.expected, try parsed.format(&buffer));
    }
    try std.testing.expectError(
        error.AccessPolicyTimePrecisionLoss,
        AccessPolicyTime.parse("2026-07-26T18:32:16.12345678Z"),
    );
    try std.testing.expectError(
        error.InvalidAccessPolicyTime,
        AccessPolicyTime.parse("2026-02-29T18:32:16Z"),
    );
}

test "wire conversion preserves empty and populated generated models" {
    const empty = try toWire(std.testing.allocator, &.{});
    defer std.testing.allocator.free(empty.identifiers);
    try std.testing.expectEqual(@as(usize, 0), empty.identifiers.len);

    var permission_buffer: [4]u8 = undefined;
    const source = [_]SignedIdentifier{.{
        .id = "policy<&>",
        .access_policy = .{
            .start = try AccessPolicyTime.parse("2026-07-26T20:02:16.1234567+01:30"),
            .expiry = .fromUnixSeconds(1_800_000_000),
            .permissions = .{ .table = .{ .read = true, .update = true } },
        },
    }};
    const wire = try toWire(std.testing.allocator, &source);
    defer {
        for (wire.identifiers) |identifier| {
            std.testing.allocator.free(identifier.id);
            std.testing.allocator.free(identifier.access_policy.start);
            std.testing.allocator.free(identifier.access_policy.expiry);
            std.testing.allocator.free(identifier.access_policy.permission);
        }
        std.testing.allocator.free(wire.identifiers);
    }
    try std.testing.expectEqualStrings("ru", source[0].access_policy.permissions.string(&permission_buffer));
    try std.testing.expectEqualStrings("2026-07-26T18:32:16.1234567Z", wire.identifiers[0].access_policy.start);
    try std.testing.expectEqualStrings("ru", wire.identifiers[0].access_policy.permission);
}
