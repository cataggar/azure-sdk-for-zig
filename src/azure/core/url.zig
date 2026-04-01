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
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try self.format(buf.writer());
        return try buf.toOwnedSlice();
    }
};

test "parse https url" {
    const u = try Url.parse("https://myaccount.blob.core.windows.net/container/blob?sv=2021-06-08&sr=b");
    try std.testing.expectEqualStrings("https", u.scheme);
    try std.testing.expectEqualStrings("myaccount.blob.core.windows.net", u.host);
    try std.testing.expectEqualStrings("/container/blob", u.path);
}
