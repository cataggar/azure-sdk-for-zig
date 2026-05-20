const std = @import("std");

/// Case-insensitive string hash map — suitable for HTTP headers.
///
/// Keys are compared after ASCII lower-casing.
pub fn CaseInsensitiveMap(comptime V: type) type {
    return std.HashMap([]const u8, V, CaseInsensitiveContext, std.hash_map.default_max_load_percentage);
}

pub const CaseInsensitiveContext = struct {
    pub fn hash(_: CaseInsensitiveContext, key: []const u8) u64 {
        var h: u64 = 0xcbf29ce484222325; // FNV-1a offset basis
        for (key) |c| {
            const lower: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
            h ^= lower;
            h *%= 0x100000001b3; // FNV-1a prime
        }
        return h;
    }

    pub fn eql(_: CaseInsensitiveContext, a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |ca, cb| {
            const la: u8 = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
            const lb: u8 = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
            if (la != lb) return false;
        }
        return true;
    }
};

test "case-insensitive map" {
    const allocator = std.testing.allocator;
    var map = CaseInsensitiveMap([]const u8).initContext(allocator, .{});
    defer map.deinit();
    try map.ensureTotalCapacity(4);
    map.putAssumeCapacity("Content-Type", "application/json");
    const val = map.get("content-type");
    try std.testing.expect(val != null);
    try std.testing.expectEqualStrings("application/json", val.?);

    const val2 = map.get("CONTENT-TYPE");
    try std.testing.expect(val2 != null);
}
