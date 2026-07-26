//! Read the release fields from eng/packages.zig without duplicating metadata.
//! Port of eng/release/registry.py.

const std = @import("std");

pub const RegistryError = error{
    UnbalancedBraces,
    MissingMarker,
    MissingRequiredField,
    UnsupportedArrayExpression,
    DuplicatePackage,
    NoPackages,
    UnknownDependency,
    NotInWorkspace,
    OutOfMemory,
};

pub const Ownership = enum { main_owned, branch_owned };

pub const Package = struct {
    name: []const u8,
    ownership: Ownership,
    workspace_path: ?[]const u8,
    historical_source_path: []const u8,
    branch: []const u8,
    version: []const u8,
    historical_names: []const []const u8,
    dependencies: []const []const u8,
    external_dependencies: []const []const u8,
    publish_paths: []const []const u8,
    test_command: ?[]const u8,
    examples_command: ?[]const u8,
    live_test_command: ?[]const u8,
    regeneration_command: ?[]const u8,

    pub fn sourcePath(self: Package) RegistryError![]const u8 {
        return self.workspace_path orelse error.NotInWorkspace;
    }
};

pub const Registry = struct {
    packages: []Package,

    pub fn find(self: Registry, name: []const u8) ?*Package {
        for (self.packages) |*package| {
            if (std.mem.eql(u8, package.name, name)) return package;
        }
        return null;
    }
};

const Constant = struct { name: []const u8, values: []const []const u8 };

fn matchingBrace(text: []const u8, opening: usize) RegistryError!usize {
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

/// Collect all `"..."` quoted strings within `text`, comment-aware.
fn extractStrings(
    allocator: std.mem.Allocator,
    text: []const u8,
) RegistryError![]const []const u8 {
    var values: std.ArrayList([]const u8) = .empty;
    var index: usize = 0;
    var line_comment = false;
    while (index < text.len) {
        const char = text[index];
        if (line_comment) {
            if (char == '\n') line_comment = false;
            index += 1;
            continue;
        }
        if (char == '/' and index + 1 < text.len and text[index + 1] == '/') {
            line_comment = true;
            index += 2;
            continue;
        }
        if (char != '"') {
            index += 1;
            continue;
        }
        const start = index + 1;
        index += 1;
        var escape = false;
        while (index < text.len) : (index += 1) {
            const c = text[index];
            if (escape) {
                escape = false;
            } else if (c == '\\') {
                escape = true;
            } else if (c == '"') {
                break;
            }
        }
        try values.append(allocator, text[start..index]);
        index += 1;
    }
    return values.toOwnedSlice(allocator);
}

/// Offset of the value (first non-space after `=`) for a `.field = ...` entry.
fn valueStart(text: []const u8, field: []const u8) ?usize {
    var line_start: usize = 0;
    while (line_start < text.len) {
        const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse
            text.len;
        const line = text[line_start..line_end];
        const trimmed = std.mem.trimStart(u8, line, " \t\r");
        if (trimmed.len > field.len + 1 and
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

const FieldValue = struct { is_null: bool, text: []const u8 };

/// Mirror `_field_string`: matches `.field = "..."` or `.field = null` on a
/// single line ending with a comma. Returns null when the field is absent or
/// its value is not a string/null literal.
fn fieldValue(text: []const u8, field: []const u8) ?FieldValue {
    const start = valueStart(text, field) orelse return null;
    if (start >= text.len) return null;
    if (text[start] == 'n' and std.mem.startsWith(u8, text[start..], "null")) {
        var after = start + 4;
        while (after < text.len and (text[after] == ' ' or text[after] == '\t')) after += 1;
        if (after < text.len and text[after] == ',') return .{ .is_null = true, .text = "" };
        return null;
    }
    if (text[start] != '"') return null;
    var index = start + 1;
    var escape = false;
    while (index < text.len) : (index += 1) {
        const c = text[index];
        if (escape) {
            escape = false;
        } else if (c == '\\') {
            escape = true;
        } else if (c == '"') {
            const inner = text[start + 1 .. index];
            var after = index + 1;
            while (after < text.len and (text[after] == ' ' or text[after] == '\t')) after += 1;
            if (after < text.len and text[after] == ',') return .{ .is_null = false, .text = inner };
            return null;
        }
    }
    return null;
}

/// `_field_string(block, field, default)`: None for absent or `null`.
fn fieldString(text: []const u8, field: []const u8, default: ?[]const u8) ?[]const u8 {
    const value = fieldValue(text, field) orelse return default;
    if (value.is_null) return null;
    return value.text;
}

fn fieldEnum(text: []const u8, field: []const u8, default: []const u8) []const u8 {
    const start = valueStart(text, field) orelse return default;
    if (start >= text.len or text[start] != '.') return default;
    var end = start + 1;
    while (end < text.len and
        (std.ascii.isAlphanumeric(text[end]) or text[end] == '_'))
    {
        end += 1;
    }
    if (end == start + 1) return default;
    return text[start + 1 .. end];
}

fn fieldArray(
    allocator: std.mem.Allocator,
    text: []const u8,
    field: []const u8,
    constants: []const Constant,
) RegistryError![]const []const u8 {
    const start = valueStart(text, field) orelse return &.{};
    const tail = text[start..];
    if (std.mem.startsWith(u8, tail, "&.{")) {
        const opening = start + 2;
        const closing = try matchingBrace(text, opening);
        return extractStrings(allocator, text[opening + 1 .. closing]);
    }
    // Identifier reference into a top-level constant.
    var end = start;
    while (end < text.len and
        (std.ascii.isAlphanumeric(text[end]) or text[end] == '_'))
    {
        end += 1;
    }
    if (end > start) {
        const name = text[start..end];
        for (constants) |constant| {
            if (std.mem.eql(u8, constant.name, name)) return constant.values;
        }
    }
    return error.UnsupportedArrayExpression;
}

fn arrayBody(text: []const u8, marker: []const u8) RegistryError![]const u8 {
    const start = std.mem.indexOf(u8, text, marker) orelse return error.MissingMarker;
    const opening = std.mem.indexOfScalarPos(u8, text, start, '{') orelse
        return error.MissingMarker;
    const closing = try matchingBrace(text, opening);
    return text[opening + 1 .. closing];
}

fn collectConstants(
    allocator: std.mem.Allocator,
    text: []const u8,
) RegistryError![]const Constant {
    var constants: std.ArrayList(Constant) = .empty;
    var line_start: usize = 0;
    while (line_start < text.len) {
        const line_end = std.mem.indexOfScalarPos(u8, text, line_start, '\n') orelse
            text.len;
        const line = text[line_start..line_end];
        if (std.mem.startsWith(u8, line, "const ")) {
            var rest = line["const ".len..];
            var name_end: usize = 0;
            while (name_end < rest.len and
                (std.ascii.isAlphanumeric(rest[name_end]) or rest[name_end] == '_'))
            {
                name_end += 1;
            }
            if (name_end > 0) {
                const name = rest[0..name_end];
                const assign = std.mem.trimStart(u8, rest[name_end..], " \t");
                if (std.mem.startsWith(u8, assign, "= &.{") or
                    std.mem.startsWith(u8, assign, "=&.{"))
                {
                    const opening = std.mem.indexOfScalarPos(u8, text, line_start, '{').?;
                    const closing = try matchingBrace(text, opening);
                    try constants.append(allocator, .{
                        .name = name,
                        .values = try extractStrings(allocator, text[opening + 1 .. closing]),
                    });
                }
            }
        }
        line_start = if (line_end < text.len) line_end + 1 else text.len;
    }
    return constants.toOwnedSlice(allocator);
}

pub fn load(allocator: std.mem.Allocator, text: []const u8) RegistryError!Registry {
    const constants = try collectConstants(allocator, text);
    const body = try arrayBody(text, "pub const all = [_]Package{");

    var packages: std.ArrayList(Package) = .empty;
    var cursor: usize = 0;
    while (cursor < body.len) {
        // Find the next `.{` entry opener.
        const dot = std.mem.indexOfScalarPos(u8, body, cursor, '.') orelse break;
        var brace = dot + 1;
        while (brace < body.len and (body[brace] == ' ' or body[brace] == '\t' or
            body[brace] == '\r' or body[brace] == '\n')) brace += 1;
        if (brace >= body.len or body[brace] != '{') {
            cursor = dot + 1;
            continue;
        }
        const closing = try matchingBrace(body, brace);
        const block = body[brace + 1 .. closing];
        cursor = closing + 1;

        const name = fieldString(block, "name", null) orelse
            return error.MissingRequiredField;
        const historical_source_path = fieldString(block, "historical_source_path", null) orelse
            fieldString(block, "source_path", null) orelse
            return error.MissingRequiredField;
        var workspace_path = fieldString(block, "workspace_path", null);
        if (workspace_path == null and fieldString(block, "source_path", null) != null) {
            workspace_path = historical_source_path;
        }
        const branch = fieldString(block, "branch", null) orelse
            return error.MissingRequiredField;

        const ownership: Ownership =
            if (std.mem.eql(u8, fieldEnum(block, "ownership", "branch_owned"), "main_owned"))
                .main_owned
            else
                .branch_owned;

        var historical_names = try fieldArray(allocator, block, "historical_names", constants);
        if (historical_names.len == 0) {
            historical_names = try fieldArray(allocator, block, "legacy_names", constants);
        }

        try packages.append(allocator, .{
            .name = name,
            .ownership = ownership,
            .workspace_path = workspace_path,
            .historical_source_path = historical_source_path,
            .branch = branch,
            .version = fieldString(block, "version", "0.1.0") orelse "",
            .historical_names = historical_names,
            .dependencies = try fieldArray(allocator, block, "dependencies", constants),
            .external_dependencies = try fieldArray(allocator, block, "external_dependencies", constants),
            .publish_paths = try fieldArray(allocator, block, "publish_paths", constants),
            .test_command = fieldString(block, "test_command", "zig build test --summary all"),
            .examples_command = fieldString(block, "examples_command", null),
            .live_test_command = fieldString(block, "live_test_command", null),
            .regeneration_command = fieldString(block, "regeneration_command", null),
        });
    }

    if (packages.items.len == 0) return error.NoPackages;

    // Reject duplicate names and unknown internal dependencies.
    for (packages.items, 0..) |package, i| {
        for (packages.items[i + 1 ..]) |other| {
            if (std.mem.eql(u8, package.name, other.name)) return error.DuplicatePackage;
        }
        for (package.dependencies) |dependency| {
            var found = false;
            for (packages.items) |candidate| {
                if (std.mem.eql(u8, candidate.name, dependency)) {
                    found = true;
                    break;
                }
            }
            if (!found) return error.UnknownDependency;
        }
    }

    return .{ .packages = try packages.toOwnedSlice(allocator) };
}

test "load self-test registry" {
    const text =
        \\const Package = struct {};
        \\pub const all = [_]Package{
        \\    .{
        \\        .ownership = .main_owned,
        \\        .workspace_path = "sdk/core/tracing",
        \\        .historical_source_path = "sdk/core/tracing",
        \\        .name = "azure_sdk_core_tracing",
        \\        .branch = "sdk/core_tracing",
        \\        .version = "0.1.0",
        \\        .publish_paths = &.{
        \\            ".gitignore",
        \\            "build.zig",
        \\            "README.md",
        \\        },
        \\        .test_command = "zig build test --summary all",
        \\    },
        \\    .{
        \\        .ownership = .main_owned,
        \\        .workspace_path = "sdk/core",
        \\        .historical_source_path = "sdk/core",
        \\        .name = "azure_sdk_core",
        \\        .branch = "sdk/core",
        \\        .version = "0.1.0",
        \\        .dependencies = &.{"azure_sdk_core_tracing"},
        \\        .publish_paths = &.{ "build.zig", "root.zig" },
        \\        .test_command = "zig build test --summary all",
        \\    },
        \\    .{
        \\        .ownership = .branch_owned,
        \\        .historical_source_path = "rest/arm_avs",
        \\        .name = "azure_rest_arm_avs",
        \\        .branch = "rest/arm_avs",
        \\        .historical_names = &.{"arm_avs"},
        \\        .publish_paths = &.{"build.zig"},
        \\    },
        \\};
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const registry = try load(arena.allocator(), text);
    try std.testing.expectEqual(@as(usize, 3), registry.packages.len);

    const tracing = registry.find("azure_sdk_core_tracing").?;
    try std.testing.expectEqual(Ownership.main_owned, tracing.ownership);
    try std.testing.expectEqualStrings("sdk/core/tracing", tracing.workspace_path.?);
    try std.testing.expectEqual(@as(usize, 3), tracing.publish_paths.len);

    const core = registry.find("azure_sdk_core").?;
    try std.testing.expectEqual(@as(usize, 1), core.dependencies.len);
    try std.testing.expectEqualStrings("azure_sdk_core_tracing", core.dependencies[0]);

    const arm = registry.find("azure_rest_arm_avs").?;
    try std.testing.expectEqual(Ownership.branch_owned, arm.ownership);
    try std.testing.expect(arm.workspace_path == null);
    try std.testing.expectEqualStrings("arm_avs", arm.historical_names[0]);
    try std.testing.expectError(error.NotInWorkspace, arm.sourcePath());
    // Defaulted test_command.
    try std.testing.expectEqualStrings("zig build test --summary all", arm.test_command.?);
}
