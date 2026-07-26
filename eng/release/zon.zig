//! Small, syntax-aware helpers for the repository's build.zig.zon shape.
//! Port of eng/release/zon.py.

const std = @import("std");

pub const ZonError = error{
    MalformedVersion,
    UnbalancedBraces,
    MissingField,
    MalformedField,
    EmptyMinimumZigVersion,
    MissingFingerprint,
    UnterminatedString,
    MissingTrailingComma,
    DuplicateDependency,
    MissingDependency,
    NotLocalPath,
    NotImmutablePin,
    OutOfMemory,
};

pub const Semver = struct {
    major: u64,
    minor: u64,
    patch: u64,

    pub fn order(a: Semver, b: Semver) std.math.Order {
        if (a.major != b.major) return std.math.order(a.major, b.major);
        if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
        return std.math.order(a.patch, b.patch);
    }

    pub fn eql(a: Semver, b: Semver) bool {
        return a.order(b) == .eq;
    }
};

/// Strict SemVer: exactly X.Y.Z with no leading zeros (except a bare 0),
/// no pre-release or build metadata. Mirrors zon.py's SEMVER regex.
pub fn parseSemver(value: []const u8) ZonError!Semver {
    var parts: [3]u64 = undefined;
    var it = std.mem.splitScalar(u8, value, '.');
    var index: usize = 0;
    while (it.next()) |part| {
        if (index >= 3) return error.MalformedVersion;
        if (part.len == 0) return error.MalformedVersion;
        if (part.len > 1 and part[0] == '0') return error.MalformedVersion;
        for (part) |c| {
            if (!std.ascii.isDigit(c)) return error.MalformedVersion;
        }
        parts[index] = std.fmt.parseInt(u64, part, 10) catch
            return error.MalformedVersion;
        index += 1;
    }
    if (index != 3) return error.MalformedVersion;
    return .{ .major = parts[0], .minor = parts[1], .patch = parts[2] };
}

pub const Dependency = struct {
    name: []const u8,
    start: usize,
    end: usize,
    indent: []const u8,
    path: ?[]const u8,
    url: ?[]const u8,
    hash: ?[]const u8,
};

pub const Manifest = struct {
    name: []const u8,
    version: []const u8,
    fingerprint: []const u8,
    minimum_zig_version: []const u8,
    dependencies: []const Dependency,
    paths: []const []const u8,
    dependencies_open: usize,
    dependencies_close: usize,

    pub fn findDependency(self: Manifest, name: []const u8) ?Dependency {
        for (self.dependencies) |dependency| {
            if (std.mem.eql(u8, dependency.name, name)) return dependency;
        }
        return null;
    }
};

fn matchingBrace(text: []const u8, opening: usize) ZonError!usize {
    var depth: usize = 0;
    var quote = false;
    var escape = false;
    var line_comment = false;
    var index = opening;
    while (index < text.len) : (index += 1) {
        const char = text[index];
        if (line_comment) {
            if (char == '\n') line_comment = false;
            continue;
        }
        if (quote) {
            if (escape) {
                escape = false;
            } else if (char == '\\') {
                escape = true;
            } else if (char == '"') {
                quote = false;
            }
            continue;
        }
        if (char == '/' and index + 1 < text.len and text[index + 1] == '/') {
            line_comment = true;
            index += 1;
        } else if (char == '"') {
            quote = true;
        } else if (char == '{') {
            depth += 1;
        } else if (char == '}') {
            if (depth == 0) return error.UnbalancedBraces;
            depth -= 1;
            if (depth == 0) return index;
        }
    }
    return error.UnbalancedBraces;
}

/// Locate the start of the line holding `.field = ...`, returning the byte
/// offset of the value (first non-space character after `=`). Line based,
/// comment aware; mirrors the `(?m)^\s*\.field\s*=` anchor used in zon.py.
fn valueStart(text: []const u8, field: []const u8) ?usize {
    var line_start: usize = 0;
    while (line_start < text.len) {
        const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse
            text.len;
        const line = text[line_start..line_end];
        const trimmed = std.mem.trimStart(u8, line, " \t\r");
        if (!std.mem.startsWith(u8, trimmed, "//") and
            trimmed.len > field.len + 1 and
            trimmed[0] == '.' and
            std.mem.eql(u8, trimmed[1 .. field.len + 1], field))
        {
            const after = trimmed[field.len + 1];
            if (after == ' ' or after == '\t' or after == '=') {
                const eq = std.mem.indexOfScalarPos(u8, text, line_start, '=') orelse
                    return null;
                var index = eq + 1;
                while (index < text.len and
                    (text[index] == ' ' or text[index] == '\t' or text[index] == '\r'))
                {
                    index += 1;
                }
                return index;
            }
        }
        line_start = if (line_end < text.len) line_end + 1 else text.len;
    }
    return null;
}

fn quotedValue(text: []const u8, index: *usize) ZonError![]const u8 {
    if (text[index.*] != '"') return error.MalformedField;
    const start = index.* + 1;
    index.* += 1;
    var escape = false;
    while (index.* < text.len) : (index.* += 1) {
        const char = text[index.*];
        if (escape) {
            escape = false;
        } else if (char == '\\') {
            escape = true;
        } else if (char == '"') {
            const value = text[start..index.*];
            index.* += 1;
            return value;
        }
    }
    return error.UnterminatedString;
}

fn requiredString(text: []const u8, field: []const u8) ZonError![]const u8 {
    return optionalString(text, field) orelse error.MissingField;
}

fn optionalString(text: []const u8, field: []const u8) ?[]const u8 {
    const start = valueStart(text, field) orelse return null;
    if (start >= text.len or text[start] != '"') return null;
    var index = start;
    return quotedValue(text, &index) catch null;
}

fn requiredEnum(text: []const u8, field: []const u8) ZonError![]const u8 {
    const start = valueStart(text, field) orelse return error.MissingField;
    if (start >= text.len or text[start] != '.') return error.MalformedField;
    const end = identifierEnd(text, start + 1);
    if (end == start + 1) return error.MalformedField;
    return text[start + 1 .. end];
}

fn identifierEnd(text: []const u8, start: usize) usize {
    var end = start;
    while (end < text.len and
        (std.ascii.isAlphanumeric(text[end]) or text[end] == '_'))
    {
        end += 1;
    }
    return end;
}

fn requiredFingerprint(text: []const u8) ZonError![]const u8 {
    const start = valueStart(text, "fingerprint") orelse return error.MissingFingerprint;
    if (start + 2 > text.len or text[start] != '0' or text[start + 1] != 'x') {
        return error.MissingFingerprint;
    }
    var end = start + 2;
    while (end < text.len and std.ascii.isHex(text[end])) end += 1;
    if (end == start + 2) return error.MissingFingerprint;
    // Require a trailing comma (optionally after spaces) to match the regex.
    var comma = end;
    while (comma < text.len and (text[comma] == ' ' or text[comma] == '\t')) comma += 1;
    if (comma >= text.len or text[comma] != ',') return error.MissingFingerprint;
    return text[start..end];
}

fn fieldBlock(text: []const u8, field: []const u8) ZonError!struct { open: usize, close: usize } {
    const start = blk: {
        var line_start: usize = 0;
        while (line_start < text.len) {
            const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse
                text.len;
            const line = text[line_start..line_end];
            const trimmed = std.mem.trimStart(u8, line, " \t\r");
            if (!std.mem.startsWith(u8, trimmed, "//") and
                trimmed.len > field.len + 1 and
                trimmed[0] == '.' and
                std.mem.eql(u8, trimmed[1 .. field.len + 1], field))
            {
                const after = trimmed[field.len + 1];
                if (after == ' ' or after == '\t' or after == '=') {
                    break :blk line_start + (line.len - trimmed.len);
                }
            }
            line_start = if (line_end < text.len) line_end + 1 else text.len;
        }
        return error.MissingField;
    };
    const opening = std.mem.indexOfScalarPos(u8, text, start, '{') orelse
        return error.MissingField;
    const closing = try matchingBrace(text, opening);
    return .{ .open = opening, .close = closing };
}

fn uncommentedStrings(
    allocator: std.mem.Allocator,
    text: []const u8,
) ZonError![]const []const u8 {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer values.deinit(allocator);
    var index: usize = 0;
    while (index < text.len) {
        if (std.mem.startsWith(u8, text[index..], "//")) {
            const newline = std.mem.indexOfScalarPos(u8, text, index + 2, '\n');
            index = if (newline) |n| n + 1 else text.len;
            continue;
        }
        if (text[index] != '"') {
            index += 1;
            continue;
        }
        const value = try quotedValue(text, &index);
        try values.append(allocator, value);
    }
    return values.toOwnedSlice(allocator);
}

pub fn parse(allocator: std.mem.Allocator, text: []const u8) ZonError!Manifest {
    const name = try requiredEnum(text, "name");
    const version = try requiredString(text, "version");
    const fingerprint = try requiredFingerprint(text);
    const minimum_zig_version = try requiredString(text, "minimum_zig_version");
    if (std.mem.trim(u8, minimum_zig_version, " \t\r\n").len == 0) {
        return error.EmptyMinimumZigVersion;
    }

    const deps_block = try fieldBlock(text, "dependencies");
    const paths_block = try fieldBlock(text, "paths");
    const paths = try uncommentedStrings(
        allocator,
        text[paths_block.open + 1 .. paths_block.close],
    );

    var dependencies: std.ArrayList(Dependency) = .empty;
    errdefer dependencies.deinit(allocator);

    const body_start = deps_block.open + 1;
    const body = text[body_start..deps_block.close];
    var cursor: usize = 0;
    while (cursor < body.len) {
        const entry = findEntry(body, cursor) orelse break;
        const opening = body_start +
            (std.mem.indexOfScalarPos(u8, body, entry.line_start, '{') orelse
                return error.MalformedField);
        const closing = try matchingBrace(text, opening);
        var comma = closing + 1;
        while (comma < text.len and (text[comma] == ' ' or text[comma] == '\t')) {
            comma += 1;
        }
        if (comma >= text.len or text[comma] != ',') return error.MissingTrailingComma;
        const end = comma + 1;
        const block = text[opening + 1 .. closing];
        const dependency: Dependency = .{
            .name = entry.name,
            .start = body_start + entry.line_start,
            .end = end,
            .indent = entry.indent,
            .path = optionalString(block, "path"),
            .url = optionalString(block, "url"),
            .hash = optionalString(block, "hash"),
        };
        for (dependencies.items) |existing| {
            if (std.mem.eql(u8, existing.name, dependency.name)) {
                return error.DuplicateDependency;
            }
        }
        try dependencies.append(allocator, dependency);
        cursor = end - body_start;
    }

    return .{
        .name = name,
        .version = version,
        .fingerprint = fingerprint,
        .minimum_zig_version = minimum_zig_version,
        .dependencies = try dependencies.toOwnedSlice(allocator),
        .paths = paths,
        .dependencies_open = deps_block.open,
        .dependencies_close = deps_block.close,
    };
}

const Entry = struct {
    line_start: usize,
    indent: []const u8,
    name: []const u8,
};

/// Find the next `<indent>.<name> = .{` entry at or after `from` in `body`.
/// Mirrors Python's `re.search(pattern, body, cursor)` where the pattern is
/// anchored with `^` (multiline): the match begins at the first line boundary
/// (start-of-body or the position after a newline) at or after `from`.
fn findEntry(body: []const u8, from: usize) ?Entry {
    // Advance to the smallest line-start position >= from.
    var line_start = from;
    while (line_start < body.len and
        !(line_start == 0 or body[line_start - 1] == '\n'))
    {
        line_start += 1;
    }
    while (line_start < body.len) {
        const line_end = std.mem.indexOfScalarPos(u8, body, line_start, '\n') orelse
            body.len;
        const line = body[line_start..line_end];
        var indent_len: usize = 0;
        while (indent_len < line.len and (line[indent_len] == ' ' or line[indent_len] == '\t')) {
            indent_len += 1;
        }
        const rest = line[indent_len..];
        if (rest.len > 1 and rest[0] == '.') {
            const name_end = identifierEnd(rest, 1);
            if (name_end > 1) {
                var after = rest[name_end..];
                after = std.mem.trimStart(u8, after, " \t");
                if (std.mem.startsWith(u8, after, "=")) {
                    const value = std.mem.trimStart(u8, after[1..], " \t");
                    if (std.mem.startsWith(u8, value, ".{")) {
                        return .{
                            .line_start = line_start,
                            .indent = line[0..indent_len],
                            .name = rest[1..name_end],
                        };
                    }
                }
            }
        }
        line_start = if (line_end < body.len) line_end + 1 else body.len;
    }
    return null;
}

pub const Pin = struct {
    name: []const u8,
    url: []const u8,
    hash: []const u8,
};

pub const PathPin = struct {
    name: []const u8,
    path: []const u8,
};

const Replacement = struct { start: usize, end: usize, text: []const u8 };

fn applyReplacements(
    allocator: std.mem.Allocator,
    text: []const u8,
    replacements: []Replacement,
) ZonError![]u8 {
    std.mem.sort(Replacement, replacements, {}, struct {
        fn lessThan(_: void, a: Replacement, b: Replacement) bool {
            return a.start > b.start;
        }
    }.lessThan);
    var result = try allocator.dupe(u8, text);
    for (replacements) |replacement| {
        const before = result[0..replacement.start];
        const after = result[replacement.end..];
        const combined = try allocator.alloc(
            u8,
            before.len + replacement.text.len + after.len,
        );
        @memcpy(combined[0..before.len], before);
        @memcpy(combined[before.len..][0..replacement.text.len], replacement.text);
        @memcpy(combined[before.len + replacement.text.len ..], after);
        result = combined;
    }
    return result;
}

pub fn rewriteInternalDependencies(
    allocator: std.mem.Allocator,
    text: []const u8,
    pins: []const Pin,
) ZonError![]u8 {
    const manifest = try parse(allocator, text);
    var replacements: std.ArrayList(Replacement) = .empty;
    for (pins) |pin| {
        const dependency = manifest.findDependency(pin.name) orelse
            return error.MissingDependency;
        if (dependency.path == null or dependency.url != null) return error.NotLocalPath;
        const replacement = try std.fmt.allocPrint(
            allocator,
            "{s}.{s} = .{{\n{s}    .url = \"{s}\",\n{s}    .hash = \"{s}\",\n{s}}},",
            .{
                dependency.indent, pin.name,
                dependency.indent, pin.url,
                dependency.indent, pin.hash,
                dependency.indent,
            },
        );
        try replacements.append(allocator, .{
            .start = dependency.start,
            .end = dependency.end,
            .text = replacement,
        });
    }
    return applyReplacements(allocator, text, replacements.items);
}

pub fn rewriteInternalPaths(
    allocator: std.mem.Allocator,
    text: []const u8,
    paths: []const PathPin,
) ZonError![]u8 {
    const manifest = try parse(allocator, text);
    var replacements: std.ArrayList(Replacement) = .empty;
    for (paths) |pin| {
        const dependency = manifest.findDependency(pin.name) orelse
            return error.MissingDependency;
        if (dependency.path != null or dependency.url == null or dependency.hash == null) {
            return error.NotImmutablePin;
        }
        const replacement = try std.fmt.allocPrint(
            allocator,
            "{s}.{s} = .{{\n{s}    .path = \"{s}\",\n{s}}},",
            .{ dependency.indent, pin.name, dependency.indent, pin.path, dependency.indent },
        );
        try replacements.append(allocator, .{
            .start = dependency.start,
            .end = dependency.end,
            .text = replacement,
        });
    }
    return applyReplacements(allocator, text, replacements.items);
}

test "parseSemver strict" {
    try std.testing.expectEqual(Semver{ .major = 0, .minor = 1, .patch = 0 }, try parseSemver("0.1.0"));
    try std.testing.expectEqual(Semver{ .major = 10, .minor = 20, .patch = 30 }, try parseSemver("10.20.30"));
    try std.testing.expectError(error.MalformedVersion, parseSemver("1.0"));
    try std.testing.expectError(error.MalformedVersion, parseSemver("1.2.3.4"));
    try std.testing.expectError(error.MalformedVersion, parseSemver("01.2.3"));
    try std.testing.expectError(error.MalformedVersion, parseSemver("1.2.3-pre"));
}

test "parse and rewrite dependencies" {
    const allocator = std.testing.allocator;
    const text =
        \\.{
        \\    .name = .azure_sdk_core,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0x0fdf522a4b433c07,
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{
        \\        .azure_sdk_core_tracing = .{
        \\            .path = "tracing",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "build.zig",
        \\        // "ignored",
        \\        "root.zig",
        \\    },
        \\}
        \\
    ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const manifest = try parse(a, text);
    try std.testing.expectEqualStrings("azure_sdk_core", manifest.name);
    try std.testing.expectEqualStrings("0.1.0", manifest.version);
    try std.testing.expectEqual(@as(usize, 2), manifest.paths.len);
    try std.testing.expectEqual(@as(usize, 1), manifest.dependencies.len);
    try std.testing.expectEqualStrings("tracing", manifest.dependencies[0].path.?);

    const pins = [_]Pin{.{
        .name = "azure_sdk_core_tracing",
        .url = "git+file:///x#abc",
        .hash = "azure_sdk_core_tracing-0.1.0-hash",
    }};
    const rewritten = try rewriteInternalDependencies(a, text, &pins);
    try std.testing.expect(std.mem.indexOf(u8, rewritten, ".url = \"git+file:///x#abc\",") != null);
    try std.testing.expect(std.mem.indexOf(u8, rewritten, ".hash = \"azure_sdk_core_tracing-0.1.0-hash\",") != null);
    try std.testing.expect(std.mem.indexOf(u8, rewritten, ".path = \"tracing\"") == null);

    // Round-trip back to a path pin.
    const path_pins = [_]PathPin{.{ .name = "azure_sdk_core_tracing", .path = "../dep" }};
    const back = try rewriteInternalPaths(a, rewritten, &path_pins);
    try std.testing.expect(std.mem.indexOf(u8, back, ".path = \"../dep\",") != null);
    try std.testing.expect(std.mem.indexOf(u8, back, ".url = ") == null);
}

test "missing fingerprint rejected" {
    const allocator = std.testing.allocator;
    const text =
        \\.{
        \\    .name = .pkg,
        \\    .version = "0.1.0",
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{},
        \\    .paths = .{ "build.zig" },
        \\}
    ;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    try std.testing.expectError(error.MissingFingerprint, parse(arena.allocator(), text));
}
