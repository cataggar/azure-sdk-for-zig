const std = @import("std");

const max_file_size = 16 * 1024 * 1024;

const Definition = struct {
    target: []const u8,
    line_number: usize,
};

const ParsedDefinition = struct {
    label: []const u8,
    target: []const u8,
};

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const result = try std.process.run(allocator, init.io, .{
        .argv = &.{
            "git",
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
            "--deduplicate",
            "--",
            "*.md",
        },
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    switch (result.term) {
        .exited => |code| if (code != 0) {
            std.debug.print("{s}", .{result.stderr});
            return code;
        },
        else => return error.GitLsFilesFailed,
    }

    var root_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var cwd = try std.Io.Dir.cwd().openDir(init.io, ".", .{});
    defer cwd.close(init.io);
    const root_len = try cwd.realPath(init.io, &root_buffer);
    const root = root_buffer[0..root_len];
    var valid = true;
    var paths = std.mem.splitScalar(u8, result.stdout, 0);
    while (paths.next()) |path| {
        if (path.len == 0) continue;
        const text = std.Io.Dir.readFileAlloc(
            .cwd(),
            init.io,
            path,
            allocator,
            .limited(max_file_size),
        ) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        if (!try validateFile(allocator, init.io, root, path, text)) valid = false;
    }
    if (!valid) return 1;
    std.debug.print("documentation links valid\n", .{});
    return 0;
}

fn validateFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    markdown_path: []const u8,
    text: []const u8,
) !bool {
    var definitions = std.StringHashMap(Definition).init(allocator);
    var definition_line_number: usize = 0;
    var definition_lines = std.mem.splitScalar(u8, text, '\n');
    while (definition_lines.next()) |line| {
        definition_line_number += 1;
        if (parseDefinition(line)) |definition| {
            const label = try normalizedLabel(allocator, definition.label);
            try definitions.put(label, .{
                .target = definition.target,
                .line_number = definition_line_number,
            });
        }
    }

    var valid = true;
    var line_number: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        line_number += 1;
        if (parseDefinition(line) != null) continue;
        var cursor: usize = 0;
        while (std.mem.indexOfPos(u8, line, cursor, "](")) |marker| {
            const start = marker + 2;
            const end = std.mem.indexOfScalarPos(u8, line, start, ')') orelse break;
            const raw_target = std.mem.trim(u8, line[start..end], " \t");
            const target = linkTarget(raw_target);
            if (!try validateTarget(
                allocator,
                io,
                root,
                markdown_path,
                line_number,
                target,
            )) {
                valid = false;
            }
            cursor = end + 1;
        }
        cursor = 0;
        while (std.mem.indexOfPos(u8, line, cursor, "][")) |marker| {
            const opening = std.mem.lastIndexOfScalar(u8, line[0..marker], '[') orelse {
                cursor = marker + 2;
                continue;
            };
            const end = std.mem.indexOfScalarPos(u8, line, marker + 2, ']') orelse break;
            if (opening > 0 and line[opening - 1] == '!') {
                cursor = end + 1;
                continue;
            }
            const explicit = line[marker + 2 .. end];
            const raw_label = if (explicit.len == 0)
                line[opening + 1 .. marker]
            else
                explicit;
            const label = try normalizedLabel(allocator, raw_label);
            if (!definitions.contains(label)) {
                std.debug.print(
                    "{s}:{d}: missing link definition [{s}]\n",
                    .{ markdown_path, line_number, label },
                );
                valid = false;
            }
            cursor = end + 1;
        }
    }
    var definition_iterator = definitions.iterator();
    while (definition_iterator.next()) |entry| {
        const definition = entry.value_ptr.*;
        if (!try validateTarget(
            allocator,
            io,
            root,
            markdown_path,
            definition.line_number,
            linkTarget(definition.target),
        )) {
            valid = false;
        }
    }
    return valid;
}

fn validateTarget(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    markdown_path: []const u8,
    line_number: usize,
    target: []const u8,
) !bool {
    if (target.len == 0 or target[0] == '#' or hasScheme(target)) return true;
    const end = std.mem.indexOfAny(u8, target, "?#") orelse target.len;
    if (end == 0) return true;
    const encoded = target[0..end];
    const decoded_buffer = try allocator.dupe(u8, encoded);
    const decoded = std.Uri.percentDecodeInPlace(decoded_buffer);
    const parent = std.fs.path.dirname(markdown_path) orelse ".";
    const resolved = try std.fs.path.resolve(allocator, &.{ root, parent, decoded });
    if (!isWithinRoot(root, resolved)) {
        std.debug.print(
            "{s}:{d}: link escapes repository {s}\n",
            .{ markdown_path, line_number, target },
        );
        return false;
    }
    std.Io.Dir.accessAbsolute(io, resolved, .{}) catch {
        std.debug.print(
            "{s}:{d}: missing link target {s}\n",
            .{ markdown_path, line_number, target },
        );
        return false;
    };
    return true;
}

fn linkTarget(raw: []const u8) []const u8 {
    if (raw.len > 0 and raw[0] == '<') {
        const end = std.mem.indexOfScalarPos(u8, raw, 1, '>') orelse return raw;
        return raw[1..end];
    }
    return raw[0 .. std.mem.indexOfAny(u8, raw, " \t") orelse raw.len];
}

fn parseDefinition(line: []const u8) ?ParsedDefinition {
    const trimmed = std.mem.trimStart(u8, line, " \t");
    if (trimmed.len < 4 or trimmed[0] != '[' or
        std.mem.startsWith(u8, trimmed, "!["))
    {
        return null;
    }
    const marker = std.mem.indexOf(u8, trimmed, "]:") orelse return null;
    if (marker <= 1) return null;
    const target = std.mem.trim(u8, trimmed[marker + 2 ..], " \t");
    if (target.len == 0) return null;
    return .{
        .label = trimmed[1..marker],
        .target = target,
    };
}

fn normalizedLabel(allocator: std.mem.Allocator, label: []const u8) ![]u8 {
    const normalized = try allocator.dupe(u8, label);
    for (normalized) |*char| char.* = std.ascii.toLower(char.*);
    return normalized;
}

fn hasScheme(target: []const u8) bool {
    if (target.len == 0 or !std.ascii.isAlphabetic(target[0])) return false;
    for (target[1..]) |char| {
        if (char == ':') return true;
        if (!(std.ascii.isAlphanumeric(char) or char == '+' or char == '-' or char == '.')) {
            return false;
        }
    }
    return false;
}

fn isWithinRoot(root: []const u8, path: []const u8) bool {
    if (std.mem.eql(u8, root, path)) return true;
    if (!std.mem.startsWith(u8, path, root) or path.len <= root.len) return false;
    return std.fs.path.isSep(path[root.len]);
}

test "link targets discard titles and angle brackets" {
    try std.testing.expectEqualStrings(
        "doc/file.md",
        linkTarget("doc/file.md \"title\""),
    );
    try std.testing.expectEqualStrings(
        "doc/file.md",
        linkTarget("<doc/file.md>"),
    );
}

test "reference definitions are parsed case-insensitively" {
    const definition = parseDefinition("  [Guide]: doc/guide.md \"Guide\"").?;
    try std.testing.expectEqualStrings("Guide", definition.label);
    try std.testing.expectEqualStrings(
        "doc/guide.md",
        linkTarget(definition.target),
    );
    const normalized = try normalizedLabel(std.testing.allocator, definition.label);
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("guide", normalized);
}
