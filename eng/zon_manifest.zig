const std = @import("std");

pub const Dependency = struct {
    name: []const u8,
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
};

pub fn parse(allocator: std.mem.Allocator, text: []const u8) !Manifest {
    const name = try parseEnumField(text, "name");
    const version = try parseStringField(text, "version");
    _ = std.SemanticVersion.parse(version) catch return error.InvalidVersion;
    const fingerprint = try parseTokenField(text, "fingerprint");
    if (!std.mem.startsWith(u8, fingerprint, "0x") or fingerprint.len == 2) {
        return error.InvalidFingerprint;
    }
    const minimum_zig_version = try parseStringField(text, "minimum_zig_version");
    if (std.mem.trim(u8, minimum_zig_version, " \t\r\n").len == 0) {
        return error.InvalidMinimumZigVersion;
    }

    const dependency_block = try fieldBlock(text, "dependencies");
    const path_block = try fieldBlock(text, "paths");
    return .{
        .name = name,
        .version = version,
        .fingerprint = fingerprint,
        .minimum_zig_version = minimum_zig_version,
        .dependencies = try parseDependencies(allocator, dependency_block),
        .paths = try parseStrings(allocator, path_block),
    };
}

pub fn findDependency(manifest: Manifest, name: []const u8) ?Dependency {
    for (manifest.dependencies) |dependency| {
        if (std.mem.eql(u8, dependency.name, name)) return dependency;
    }
    return null;
}

fn parseDependencies(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]const Dependency {
    var dependencies: std.ArrayList(Dependency) = .empty;
    errdefer dependencies.deinit(allocator);

    var index: usize = 0;
    while (index < body.len) {
        const line_end = std.mem.indexOfScalarPos(u8, body, index, '\n') orelse body.len;
        const line = body[index..line_end];
        const trimmed = std.mem.trimStart(u8, line, " \t\r");
        if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "//")) {
            index = if (line_end < body.len) line_end + 1 else body.len;
            continue;
        }
        if (trimmed[0] != '.') return error.InvalidDependencyEntry;

        const name_end = identifierEnd(trimmed, 1);
        if (name_end == 1) return error.InvalidDependencyEntry;
        const name = trimmed[1..name_end];
        const opening_in_line = std.mem.indexOfScalarPos(u8, trimmed, name_end, '{') orelse
            return error.InvalidDependencyEntry;
        const opening = index + (line.len - trimmed.len) + opening_in_line;
        const closing = try matchingBrace(body, opening);
        const block = body[opening + 1 .. closing];
        const dependency: Dependency = .{
            .name = name,
            .path = optionalStringField(block, "path"),
            .url = optionalStringField(block, "url"),
            .hash = optionalStringField(block, "hash"),
        };
        if (findDependency(.{
            .name = "",
            .version = "",
            .fingerprint = "",
            .minimum_zig_version = "",
            .dependencies = dependencies.items,
            .paths = &.{},
        }, name) != null) {
            return error.DuplicateDependency;
        }
        try dependencies.append(allocator, dependency);
        index = closing + 1;
        while (index < body.len and
            (body[index] == ' ' or body[index] == '\t' or body[index] == '\r'))
        {
            index += 1;
        }
        if (index >= body.len or body[index] != ',') {
            return error.InvalidDependencyEntry;
        }
        index += 1;
        if (index < body.len and body[index] == '\n') index += 1;
    }
    return dependencies.toOwnedSlice(allocator);
}

fn parseStrings(
    allocator: std.mem.Allocator,
    body: []const u8,
) ![]const []const u8 {
    var strings: std.ArrayList([]const u8) = .empty;
    errdefer strings.deinit(allocator);

    var index: usize = 0;
    var line_comment = false;
    while (index < body.len) {
        if (line_comment) {
            if (body[index] == '\n') line_comment = false;
            index += 1;
            continue;
        }
        if (body[index] == '/' and index + 1 < body.len and body[index + 1] == '/') {
            line_comment = true;
            index += 2;
            continue;
        }
        if (body[index] != '"') {
            index += 1;
            continue;
        }
        const value = try quotedValue(body, &index);
        try strings.append(allocator, value);
    }
    return strings.toOwnedSlice(allocator);
}

fn fieldBlock(text: []const u8, field: []const u8) ![]const u8 {
    const assignment = findField(text, field) orelse return error.MissingField;
    const opening = std.mem.indexOfScalar(u8, text[assignment..], '{') orelse
        return error.InvalidField;
    const absolute_opening = assignment + opening;
    const closing = try matchingBrace(text, absolute_opening);
    return text[absolute_opening + 1 .. closing];
}

fn matchingBrace(text: []const u8, opening: usize) !usize {
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

fn parseEnumField(text: []const u8, field: []const u8) ![]const u8 {
    const start = valueStart(text, field) orelse return error.MissingField;
    if (start >= text.len or text[start] != '.') return error.InvalidField;
    const end = identifierEnd(text, start + 1);
    if (end == start + 1) return error.InvalidField;
    return text[start + 1 .. end];
}

fn parseStringField(text: []const u8, field: []const u8) ![]const u8 {
    return optionalStringField(text, field) orelse error.MissingField;
}

fn optionalStringField(text: []const u8, field: []const u8) ?[]const u8 {
    const start = valueStart(text, field) orelse return null;
    if (start >= text.len or text[start] != '"') return null;
    var index = start;
    return quotedValue(text, &index) catch null;
}

fn parseTokenField(text: []const u8, field: []const u8) ![]const u8 {
    const start = valueStart(text, field) orelse return error.MissingField;
    var end = start;
    while (end < text.len and
        text[end] != ',' and
        text[end] != ' ' and
        text[end] != '\t' and
        text[end] != '\r' and
        text[end] != '\n')
    {
        end += 1;
    }
    if (end == start) return error.InvalidField;
    return text[start..end];
}

fn valueStart(text: []const u8, field: []const u8) ?usize {
    const assignment = findField(text, field) orelse return null;
    var index = assignment;
    while (index < text.len and text[index] != '=') : (index += 1) {}
    if (index == text.len) return null;
    index += 1;
    while (index < text.len and
        (text[index] == ' ' or text[index] == '\t' or text[index] == '\r'))
    {
        index += 1;
    }
    return index;
}

fn findField(text: []const u8, field: []const u8) ?usize {
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
                return line_start + (line.len - trimmed.len);
            }
        }
        line_start = if (line_end < text.len) line_end + 1 else text.len;
    }
    return null;
}

fn quotedValue(text: []const u8, index: *usize) ![]const u8 {
    if (text[index.*] != '"') return error.InvalidString;
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
    return error.InvalidString;
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

test "parse manifest ignores commented paths" {
    const text =
        \\.{
        \\    .name = .azure_sdk_example,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0x1234,
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{
        \\        .azure_sdk_core = .{
        \\            .path = "../core",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "root.zig",
        \\        // "ignored.zig",
        \\    },
        \\}
    ;
    const manifest = try parse(std.testing.allocator, text);
    defer std.testing.allocator.free(manifest.dependencies);
    defer std.testing.allocator.free(manifest.paths);

    try std.testing.expectEqualStrings("azure_sdk_example", manifest.name);
    try std.testing.expectEqual(@as(usize, 1), manifest.dependencies.len);
    try std.testing.expectEqualStrings("../core", manifest.dependencies[0].path.?);
    try std.testing.expectEqual(@as(usize, 1), manifest.paths.len);
    try std.testing.expectEqualStrings("root.zig", manifest.paths[0]);
}
