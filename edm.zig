//! Azure Tables EDM binary, DateTime, GUID, and Int64 value wrappers.

const std = @import("std");

/// A binary EDM property. `bytes` is borrowed when serializing and owned when
/// it was produced by an entity decoder.
pub const EdmBinary = struct {
    bytes: []const u8,
};

/// An EDM DateTime represented in the RFC 3339 UTC form required by Tables.
pub const EdmDateTime = struct {
    value: []const u8,

    pub fn init(value: []const u8) !EdmDateTime {
        if (!isValidDateTime(value)) return error.InvalidDateTime;
        return .{ .value = value };
    }
};

/// An EDM GUID in canonical `8-4-4-4-12` hexadecimal form.
pub const EdmGuid = struct {
    value: []const u8,

    pub fn init(value: []const u8) !EdmGuid {
        if (!isValidGuid(value)) return error.InvalidGuid;
        return .{ .value = value };
    }
};

/// An EDM Int64. Tables represents this value as a JSON string plus an EDM
/// annotation to preserve precision in JavaScript JSON implementations.
pub const EdmInt64 = struct {
    value: i64,
};

pub fn isValidGuid(value: []const u8) bool {
    if (value.len != 36) return false;
    for (value, 0..) |c, index| {
        if (index == 8 or index == 13 or index == 18 or index == 23) {
            if (c != '-') return false;
        } else if (!std.ascii.isHex(c)) {
            return false;
        }
    }
    return true;
}

pub fn isValidDateTime(value: []const u8) bool {
    if (value.len < 20 or value[value.len - 1] != 'Z') return false;
    if (value[4] != '-' or value[7] != '-' or value[10] != 'T' or
        value[13] != ':' or value[16] != ':') return false;

    const year = parseDecimal(value[0..4]) orelse return false;
    const month = parseDecimal(value[5..7]) orelse return false;
    const day = parseDecimal(value[8..10]) orelse return false;
    const hour = parseDecimal(value[11..13]) orelse return false;
    const minute = parseDecimal(value[14..16]) orelse return false;
    const second = parseDecimal(value[17..19]) orelse return false;
    if (year == 0 or month < 1 or month > 12 or hour > 23 or minute > 59 or second > 59) return false;

    const max_day: u16 = switch (month) {
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 31,
    };
    if (day < 1 or day > max_day) return false;

    if (value.len == 20) return true;
    if (value[19] != '.' or value.len == 21) return false;
    for (value[20 .. value.len - 1]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

fn parseDecimal(value: []const u8) ?u16 {
    var result: u16 = 0;
    for (value) |c| {
        if (c < '0' or c > '9') return null;
        result = result * 10 + (c - '0');
    }
    return result;
}

fn isLeapYear(year: u16) bool {
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
}

test "EDM GUID and DateTime validation" {
    _ = try EdmGuid.init("01234567-89ab-CDEF-0123-456789abcdef");
    try std.testing.expectError(error.InvalidGuid, EdmGuid.init("not-a-guid"));
    _ = try EdmDateTime.init("2024-02-29T23:59:59.123Z");
    try std.testing.expectError(error.InvalidDateTime, EdmDateTime.init("2023-02-29T00:00:00Z"));
    try std.testing.expectError(error.InvalidDateTime, EdmDateTime.init("2024-01-01T00:00:00+00:00"));
}
