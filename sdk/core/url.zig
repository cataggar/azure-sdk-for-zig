const std = @import("std");

/// Parsed URL with query-parameter builder, wrapping `std.Uri`.
pub const Url = struct {
    scheme: []const u8 = "https",
    host: []const u8 = "",
    port: ?u16 = null,
    path: []const u8 = "/",
    raw_query: []const u8 = "",

    /// Parse a URL string.
    pub fn parse(raw: []const u8) !Url {
        const uri = try std.Uri.parse(raw);
        return .{
            .scheme = if (uri.scheme.len > 0) uri.scheme else "https",
            .host = if (uri.host) |h| switch (h) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            } else "",
            .port = uri.port,
            .path = if (uri.path.isEmpty()) "/" else switch (uri.path) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            },
            .raw_query = if (uri.query) |q| switch (q) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            } else "",
        };
    }

    /// Render the URL to a writer.
    pub fn format(self: Url, writer: anytype) !void {
        try writer.print("{s}://{s}", .{ self.scheme, self.host });
        if (self.port) |p| try writer.print(":{d}", .{p});
        try writer.writeAll(self.path);
        if (self.raw_query.len > 0) {
            try writer.print("?{s}", .{self.raw_query});
        }
    }

    /// Render the URL to an allocated string.
    pub fn toString(self: Url, allocator: std.mem.Allocator) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(allocator);
        try self.format(buf.writer(allocator));
        return try buf.toOwnedSlice(allocator);
    }
};

/// Percent-encode a string for use in URL query parameter values.
///
/// Encodes all characters except unreserved chars (A-Z, a-z, 0-9, '-', '.', '_', '~')
/// per RFC 3986 §2.3.
pub fn percentEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const hex = "0123456789ABCDEF";
    for (input) |c| {
        if (isUnreserved(c)) {
            try buf.append(allocator, c);
        } else {
            try buf.append(allocator, '%');
            try buf.append(allocator, hex[c >> 4]);
            try buf.append(allocator, hex[c & 0x0f]);
        }
    }
    return buf.toOwnedSlice(allocator);
}

/// Percent-decode a string (reverse of percentEncode).
pub fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hi = hexVal(input[i + 1]) orelse {
                try buf.append(allocator, input[i]);
                i += 1;
                continue;
            };
            const lo = hexVal(input[i + 2]) orelse {
                try buf.append(allocator, input[i]);
                i += 1;
                continue;
            };
            try buf.append(allocator, (@as(u8, hi) << 4) | @as(u8, lo));
            i += 3;
        } else if (input[i] == '+') {
            try buf.append(allocator, ' ');
            i += 1;
        } else {
            try buf.append(allocator, input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice(allocator);
}

fn isUnreserved(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or
        (c >= 'a' and c <= 'z') or
        (c >= '0' and c <= '9') or
        c == '-' or c == '.' or c == '_' or c == '~';
}

fn hexVal(c: u8) ?u4 {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    if (c >= 'A' and c <= 'F') return @intCast(c - 'A' + 10);
    if (c >= 'a' and c <= 'f') return @intCast(c - 'a' + 10);
    return null;
}

test "parse https url" {
    const u = try Url.parse("https://myaccount.blob.core.windows.net/container/blob?sv=2021-06-08&sr=b");
    try std.testing.expectEqualStrings("https", u.scheme);
    try std.testing.expectEqualStrings("myaccount.blob.core.windows.net", u.host);
    try std.testing.expectEqualStrings("/container/blob", u.path);
}

test "percentEncode basic" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "hello world");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("hello%20world", encoded);
}

test "percentEncode special chars" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "key=val&foo/bar");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("key%3Dval%26foo%2Fbar", encoded);
}

test "percentEncode unreserved passthrough" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "abc-123_XYZ.~");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("abc-123_XYZ.~", encoded);
}

test "percentDecode round-trip" {
    const allocator = std.testing.allocator;
    const original = "hello world & stuff=123";
    const encoded = try percentEncode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try percentDecode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(original, decoded);
}

test "percentDecode plus to space" {
    const allocator = std.testing.allocator;
    const decoded = try percentDecode(allocator, "hello+world");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hello world", decoded);
}
