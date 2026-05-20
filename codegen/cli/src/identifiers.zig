//! Helpers that turn an arbitrary string into a valid Zig identifier.

const std = @import("std");

const reserved = [_][]const u8{
    "addrspace",   "align",          "allowzero",   "and",
    "anyframe",    "anytype",        "asm",         "async",
    "await",       "break",          "callconv",    "catch",
    "comptime",    "const",          "continue",    "defer",
    "else",        "enum",           "errdefer",    "error",
    "export",      "extern",         "fn",          "for",
    "if",          "inline",         "linksection", "noalias",
    "noinline",    "nosuspend",      "opaque",      "or",
    "orelse",      "packed",         "pub",         "resume",
    "return",      "struct",         "suspend",     "switch",
    "test",        "threadlocal",    "try",         "union",
    "unreachable", "usingnamespace", "var",         "volatile",
    "while",
};

pub fn isReserved(s: []const u8) bool {
    for (reserved) |k| if (std.mem.eql(u8, s, k)) return true;
    return false;
}

/// Returns true when `s` is a valid bare Zig identifier — first char is
/// an ASCII letter or '_', remaining are letters / digits / '_'.
pub fn isValidBare(s: []const u8) bool {
    if (s.len == 0) return false;
    if (!(std.ascii.isAlphabetic(s[0]) or s[0] == '_')) return false;
    for (s[1..]) |c| {
        if (!(std.ascii.isAlphanumeric(c) or c == '_')) return false;
    }
    return true;
}

/// Returns the source-level representation of `s` as a Zig identifier:
///   * bare:   foo
///   * quoted: `@"7.5"` when `s` contains non-identifier chars or is a
///     reserved keyword.
/// Caller owns the returned slice.
pub fn quoteIfNeeded(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    if (isValidBare(s) and !isReserved(s)) return try allocator.dupe(u8, s);
    return try std.fmt.allocPrint(allocator, "@\"{s}\"", .{s});
}

test "quoteIfNeeded" {
    const a = std.testing.allocator;
    {
        const s = try quoteIfNeeded(a, "foo");
        defer a.free(s);
        try std.testing.expectEqualStrings("foo", s);
    }
    {
        const s = try quoteIfNeeded(a, "error");
        defer a.free(s);
        try std.testing.expectEqualStrings("@\"error\"", s);
    }
    {
        const s = try quoteIfNeeded(a, "v7.5");
        defer a.free(s);
        try std.testing.expectEqualStrings("@\"v7.5\"", s);
    }
}
