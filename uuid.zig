const std = @import("std");

/// UUID v4 (random).
///
/// Accepts a `std.Random` so callers can supply their own source
/// (e.g. `std.Random.DefaultCsprng` seeded from `std.Io.random`).
pub const Uuid = struct {
    bytes: [16]u8,

    pub fn init(rng: std.Random) Uuid {
        var bytes: [16]u8 = undefined;
        rng.bytes(&bytes);
        // Set version 4 (bits 48-51).
        bytes[6] = (bytes[6] & 0x0f) | 0x40;
        // Set variant 1 (bits 64-65).
        bytes[8] = (bytes[8] & 0x3f) | 0x80;
        return .{ .bytes = bytes };
    }

    /// Format as canonical "8-4-4-4-12" hex string.
    pub fn toString(self: Uuid) [36]u8 {
        const hex = "0123456789abcdef";
        var buf: [36]u8 = undefined;
        var pos: usize = 0;
        for (self.bytes, 0..) |byte, i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                buf[pos] = '-';
                pos += 1;
            }
            buf[pos] = hex[byte >> 4];
            buf[pos + 1] = hex[byte & 0x0f];
            pos += 2;
        }
        return buf;
    }
};

test "uuid v4 format" {
    // Use a deterministic PRNG for reproducible tests.
    var prng = std.Random.DefaultPrng.init(42);
    const id = Uuid.init(prng.random());
    const s = id.toString();
    // Version nibble
    try std.testing.expectEqual(@as(u8, '4'), s[14]);
    // Variant nibble ∈ {8,9,a,b}
    try std.testing.expect(s[19] == '8' or s[19] == '9' or s[19] == 'a' or s[19] == 'b');
    // Dashes in right places
    try std.testing.expectEqual(@as(u8, '-'), s[8]);
    try std.testing.expectEqual(@as(u8, '-'), s[13]);
    try std.testing.expectEqual(@as(u8, '-'), s[18]);
    try std.testing.expectEqual(@as(u8, '-'), s[23]);
}
