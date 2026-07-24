const std = @import("std");
const zon_manifest = @import("zon_manifest.zig");

const max_file_size = 16 * 1024 * 1024;

const Pin = struct {
    name: []const u8,
    url: []const u8,
    hash: []const u8,
};

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 3) {
        usage();
        return 2;
    }

    if (std.mem.eql(u8, args[1], "validate") and args.len == 3) {
        const text = try readManifest(allocator, init.io, args[2]);
        const manifest = try zon_manifest.parse(allocator, text);
        try validateImmutable(manifest);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "pin") and args.len == 4) {
        const text = try readManifest(allocator, init.io, args[2]);
        const manifest = try zon_manifest.parse(allocator, text);
        const pin_text = try std.Io.Dir.readFileAlloc(
            .cwd(),
            init.io,
            args[3],
            allocator,
            .limited(max_file_size),
        );
        const pins = try parsePins(allocator, pin_text);
        const rendered = try renderPinned(allocator, manifest, pins);
        try writeManifest(init.io, args[2], rendered);
        return 0;
    }

    usage();
    return 2;
}

fn usage() void {
    std.debug.print(
        "usage: candidate-manifest-tool <validate ROOT|pin ROOT PINS_TSV>\n",
        .{},
    );
}

fn readManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
) ![]u8 {
    var directory = if (std.fs.path.isAbsolute(root))
        try std.Io.Dir.openDirAbsolute(io, root, .{})
    else
        try std.Io.Dir.cwd().openDir(io, root, .{});
    defer directory.close(io);
    return directory.readFileAlloc(
        io,
        "build.zig.zon",
        allocator,
        .limited(max_file_size),
    );
}

fn writeManifest(io: std.Io, root: []const u8, text: []const u8) !void {
    var directory = if (std.fs.path.isAbsolute(root))
        try std.Io.Dir.openDirAbsolute(io, root, .{})
    else
        try std.Io.Dir.cwd().openDir(io, root, .{});
    defer directory.close(io);
    try directory.writeFile(io, .{
        .sub_path = "build.zig.zon",
        .data = text,
    });
}

fn parsePins(allocator: std.mem.Allocator, text: []const u8) ![]const Pin {
    var pins: std.ArrayList(Pin) = .empty;
    errdefer pins.deinit(allocator);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const name = fields.next() orelse return error.InvalidPin;
        const url = fields.next() orelse return error.InvalidPin;
        const hash = fields.next() orelse return error.InvalidPin;
        if (fields.next() != null or
            name.len == 0 or
            url.len == 0 or
            hash.len == 0 or
            !isSafeString(url) or
            !isSafeString(hash))
        {
            return error.InvalidPin;
        }
        for (pins.items) |pin| {
            if (std.mem.eql(u8, pin.name, name)) return error.DuplicatePin;
        }
        try pins.append(allocator, .{
            .name = name,
            .url = url,
            .hash = hash,
        });
    }
    return pins.toOwnedSlice(allocator);
}

fn renderPinned(
    allocator: std.mem.Allocator,
    manifest: zon_manifest.Manifest,
    pins: []const Pin,
) ![]u8 {
    for (pins) |pin| {
        if (zon_manifest.findDependency(manifest, pin.name) == null) {
            return error.UnknownPin;
        }
    }

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;

    try writer.print(
        \\.{{
        \\    .name = .{s},
        \\    .version = "{s}",
        \\    .fingerprint = {s},
        \\    .minimum_zig_version = "{s}",
    , .{
        manifest.name,
        manifest.version,
        manifest.fingerprint,
        manifest.minimum_zig_version,
    });
    try writer.writeByte('\n');
    if (manifest.dependencies.len == 0) {
        try writer.writeAll(
            \\    .dependencies = .{},
            \\
        );
    } else {
        try writer.writeAll(
            \\    .dependencies = .{
            \\
        );
        for (manifest.dependencies) |dependency| {
            const pin = findPin(pins, dependency.name);
            const url = if (pin) |value|
                value.url
            else
                dependency.url orelse return error.MissingPin;
            const hash = if (pin) |value|
                value.hash
            else
                dependency.hash orelse return error.MissingPin;
            try writer.print(
                \\        .{s} = .{{
                \\            .url = "{s}",
                \\            .hash = "{s}",
                \\        }},
                \\
            , .{ dependency.name, url, hash });
        }
        try writer.writeAll(
            \\    },
            \\
        );
    }
    try writer.writeAll(
        \\    .paths = .{
        \\
    );
    for (manifest.paths) |path| {
        if (!isSafeString(path)) return error.InvalidPath;
        try writer.print("        \"{s}\",\n", .{path});
    }
    try writer.writeAll(
        \\    },
        \\}
        \\
    );

    const rendered = try output.toOwnedSlice();
    const reparsed = try zon_manifest.parse(allocator, rendered);
    defer allocator.free(reparsed.dependencies);
    defer allocator.free(reparsed.paths);
    try validateImmutable(reparsed);
    return rendered;
}

fn validateImmutable(manifest: zon_manifest.Manifest) !void {
    for (manifest.dependencies) |dependency| {
        if (dependency.path != null or
            dependency.url == null or
            dependency.hash == null)
        {
            return error.DependencyIsNotImmutable;
        }
    }
}

fn findPin(pins: []const Pin, name: []const u8) ?Pin {
    for (pins) |pin| {
        if (std.mem.eql(u8, pin.name, name)) return pin;
    }
    return null;
}

fn isSafeString(value: []const u8) bool {
    return std.mem.indexOfAny(u8, value, "\"\\\r\n") == null;
}

test "render pins local dependencies and preserves external dependencies" {
    const manifest_text =
        \\.{
        \\    .name = .azure_sdk_example,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0x1234,
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{
        \\        .azure_sdk_core = .{
        \\            .path = "../core",
        \\        },
        \\        .serde = .{
        \\            .url = "git+https://example.invalid/serde#abc",
        \\            .hash = "serde-1.0.0-example",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "root.zig",
        \\    },
        \\}
    ;
    const manifest = try zon_manifest.parse(std.testing.allocator, manifest_text);
    defer std.testing.allocator.free(manifest.dependencies);
    defer std.testing.allocator.free(manifest.paths);

    const rendered = try renderPinned(std.testing.allocator, manifest, &.{
        .{
            .name = "azure_sdk_core",
            .url = "git+https://example.invalid/sdk#def",
            .hash = "azure_sdk_core-0.1.0-example",
        },
    });
    defer std.testing.allocator.free(rendered);

    const reparsed = try zon_manifest.parse(std.testing.allocator, rendered);
    defer std.testing.allocator.free(reparsed.dependencies);
    defer std.testing.allocator.free(reparsed.paths);
    try validateImmutable(reparsed);
    const core = zon_manifest.findDependency(reparsed, "azure_sdk_core").?;
    try std.testing.expectEqualStrings(
        "git+https://example.invalid/sdk#def",
        core.url.?,
    );
    const serde = zon_manifest.findDependency(reparsed, "serde").?;
    try std.testing.expectEqualStrings("serde-1.0.0-example", serde.hash.?);
}

test "render uses canonical syntax for empty dependencies" {
    const manifest_text =
        \\.{
        \\    .name = .empty_dependencies,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0x1234,
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{},
        \\    .paths = .{
        \\        "root.zig",
        \\    },
        \\}
    ;
    const manifest = try zon_manifest.parse(std.testing.allocator, manifest_text);
    defer std.testing.allocator.free(manifest.dependencies);
    defer std.testing.allocator.free(manifest.paths);

    const rendered = try renderPinned(std.testing.allocator, manifest, &.{});
    defer std.testing.allocator.free(rendered);
    try std.testing.expect(
        std.mem.indexOf(u8, rendered, ".dependencies = .{},") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, rendered, ".dependencies = .{\n    },") == null,
    );
}
