const std = @import("std");

/// Timestamp utilities for Azure (RFC 3339 / ISO 8601).
pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8 = 0,
    minute: u8 = 0,
    second: u8 = 0,
    nanosecond: u32 = 0,

    /// Format as RFC 3339 / ISO 8601 string: "YYYY-MM-DDTHH:MM:SSZ".
    pub fn toRfc3339(self: DateTime, buf: []u8) ![]u8 {
        return try std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
            self.year, self.month, self.day,
            self.hour, self.minute, self.second,
        });
    }

    /// Parse an RFC 3339 string (minimal, UTC only).
    pub fn parseRfc3339(s: []const u8) !DateTime {
        if (s.len < 20) return error.InvalidFormat;
        return .{
            .year = try std.fmt.parseInt(u16, s[0..4], 10),
            .month = try std.fmt.parseInt(u8, s[5..7], 10),
            .day = try std.fmt.parseInt(u8, s[8..10], 10),
            .hour = try std.fmt.parseInt(u8, s[11..13], 10),
            .minute = try std.fmt.parseInt(u8, s[14..16], 10),
            .second = try std.fmt.parseInt(u8, s[17..19], 10),
        };
    }
};

test "round-trip rfc3339" {
    const dt = DateTime{ .year = 2026, .month = 4, .day = 1, .hour = 12, .minute = 30, .second = 45 };
    var buf: [32]u8 = undefined;
    const s = try dt.toRfc3339(&buf);
    try std.testing.expectEqualStrings("2026-04-01T12:30:45Z", s);
    const parsed = try DateTime.parseRfc3339(s);
    try std.testing.expectEqual(dt.year, parsed.year);
    try std.testing.expectEqual(dt.month, parsed.month);
    try std.testing.expectEqual(dt.hour, parsed.hour);
}
