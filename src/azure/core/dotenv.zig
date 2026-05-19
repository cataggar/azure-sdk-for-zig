//! Minimal `.env` file loader for examples and tests.
//!
//! Parses `KEY=VALUE` lines, ignoring blank lines and `#` comments.
//! Supports an optional `export ` prefix and single- or double-quoted values.
//! Inline `#` comments are honored only when the value isn't quoted.
//!
//! This is intentionally tiny: it deliberately does not perform variable
//! expansion (`$VAR`), escape sequences, or multi-line values.

const std = @import("std");

/// In-memory key→value store backed by a `StringHashMap`.
///
/// `DotEnv` owns its keys and values; both are freed on `deinit`.
pub const DotEnv = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]u8),

    pub fn init(allocator: std.mem.Allocator) DotEnv {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap([]u8).init(allocator),
        };
    }

    pub fn deinit(self: *DotEnv) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn get(self: *const DotEnv, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    /// Parse `.env` text into the store. The first occurrence of a key wins;
    /// duplicates are skipped (so process-env values pre-populated by the
    /// caller take precedence over file values).
    pub fn parse(self: *DotEnv, contents: []const u8) !void {
        var line_iter = std.mem.splitAny(u8, contents, "\r\n");
        while (line_iter.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t");
            if (line.len == 0 or line[0] == '#') continue;

            var rest = line;
            if (std.mem.startsWith(u8, rest, "export ")) {
                rest = std.mem.trimStart(u8, rest["export ".len..], " \t");
            }

            const eq = std.mem.indexOfScalar(u8, rest, '=') orelse continue;
            const key = std.mem.trim(u8, rest[0..eq], " \t");
            if (key.len == 0) continue;

            var value = std.mem.trim(u8, rest[eq + 1 ..], " \t");
            if (value.len >= 2 and (value[0] == '"' or value[0] == '\'') and value[value.len - 1] == value[0]) {
                value = value[1 .. value.len - 1];
            } else if (std.mem.indexOfScalar(u8, value, '#')) |hash| {
                value = std.mem.trimEnd(u8, value[0..hash], " \t");
            }

            if (self.map.contains(key)) continue;

            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            const owned_value = try self.allocator.dupe(u8, value);
            errdefer self.allocator.free(owned_value);
            try self.map.put(owned_key, owned_value);
        }
    }

    /// Insert a key→value pair without overwriting an existing entry.
    /// Useful for pre-populating with process-env values before calling `parse`.
    pub fn putIfAbsent(self: *DotEnv, key: []const u8, value: []const u8) !void {
        if (self.map.contains(key)) return;
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.map.put(owned_key, owned_value);
    }
};

/// Read `path` (relative to the current working directory) and parse it
/// into a fresh `DotEnv`. Returns the file-system error verbatim if the
/// file is missing or unreadable.
pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !DotEnv {
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &read_buf);
    const reader = &file_reader.interface;

    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();
    _ = reader.streamRemaining(&body.writer) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        error.ReadFailed => return error.ReadFailed,
    };

    const contents = try body.toOwnedSlice();
    defer allocator.free(contents);

    var dotenv = DotEnv.init(allocator);
    errdefer dotenv.deinit();
    try dotenv.parse(contents);
    return dotenv;
}

/// Convenience for examples: try to load `path`; on any error (typically
/// missing file) silently return an empty `DotEnv`.
pub fn loadFromFileOrEmpty(allocator: std.mem.Allocator, io: std.Io, path: []const u8) DotEnv {
    return loadFromFile(allocator, io, path) catch DotEnv.init(allocator);
}

test "parses key=value pairs" {
    var env = DotEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.parse(
        \\FOO=bar
        \\BAZ = qux
    );

    try std.testing.expectEqualStrings("bar", env.get("FOO").?);
    try std.testing.expectEqualStrings("qux", env.get("BAZ").?);
}

test "ignores blank lines and comments" {
    var env = DotEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.parse(
        \\# a comment
        \\
        \\FOO=bar
        \\  # indented comment
        \\BAZ=qux  # inline comment
    );

    try std.testing.expectEqualStrings("bar", env.get("FOO").?);
    try std.testing.expectEqualStrings("qux", env.get("BAZ").?);
}

test "supports export prefix and quoted values" {
    var env = DotEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.parse(
        \\export FOO="value with spaces"
        \\export BAR='single quoted'
        \\QUOTED_WITH_HASH = "this # is not a comment"
    );

    try std.testing.expectEqualStrings("value with spaces", env.get("FOO").?);
    try std.testing.expectEqualStrings("single quoted", env.get("BAR").?);
    try std.testing.expectEqualStrings("this # is not a comment", env.get("QUOTED_WITH_HASH").?);
}

test "first occurrence wins" {
    var env = DotEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.putIfAbsent("FOO", "from-process");
    try env.parse(
        \\FOO=from-file
        \\BAR=only-in-file
    );

    try std.testing.expectEqualStrings("from-process", env.get("FOO").?);
    try std.testing.expectEqualStrings("only-in-file", env.get("BAR").?);
}

test "handles crlf line endings" {
    var env = DotEnv.init(std.testing.allocator);
    defer env.deinit();

    try env.parse("FOO=bar\r\nBAZ=qux\r\n");

    try std.testing.expectEqualStrings("bar", env.get("FOO").?);
    try std.testing.expectEqualStrings("qux", env.get("BAZ").?);
}
