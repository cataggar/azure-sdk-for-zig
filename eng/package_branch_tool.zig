const std = @import("std");
const registry = @import("packages.zig");
const zon_manifest = @import("zon_manifest.zig");

const max_file_size = 16 * 1024 * 1024;

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 3) {
        usage();
        return 2;
    }
    try registry.validate(allocator, &registry.all);
    const package = try branchPackage(args[2]);

    if (std.mem.eql(u8, args[1], "metadata") and args.len == 3) {
        try printMetadata(init.io, package);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "publish-paths") and args.len == 3) {
        try printPublishPaths(init.io, package);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "dependency-metadata") and args.len == 3) {
        try printDependencyMetadata(init.io, package);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "validate-tree") and args.len == 4) {
        _ = try validateTree(allocator, init.io, package, args[3]);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "tag") and args.len == 4) {
        const manifest = try validateTree(allocator, init.io, package, args[3]);
        try printLine(init.io, "{s}/v{s}\n", .{ package.name, manifest.version });
        return 0;
    }
    if (std.mem.eql(u8, args[1], "dependencies") and args.len == 4) {
        const manifest = try validateTree(allocator, init.io, package, args[3]);
        try printDependencies(init.io, package, manifest);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "render-ci") and args.len == 4) {
        try renderCi(allocator, init.io, package, args[3]);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "check-version")) {
        if (args.len < 4) {
            usage();
            return 2;
        }
        try checkVersion(args[3], args[4..]);
        return 0;
    }
    usage();
    return 2;
}

fn usage() void {
    std.debug.print(
        "usage: package-branch-tool <metadata|validate-tree|tag|dependencies|" ++
            "dependency-metadata|publish-paths|render-ci|check-version> PACKAGE " ++
            "[PATH|VERSION [PREVIOUS...]]\n",
        .{},
    );
}

fn branchPackage(name: []const u8) !registry.Package {
    const index = registry.find(&registry.all, name) orelse return error.UnknownPackage;
    const package = registry.all[index];
    if (package.ownership != .branch_owned) return error.PackageIsMainOwned;
    return package;
}

fn validateTree(
    allocator: std.mem.Allocator,
    io: std.Io,
    package: registry.Package,
    root: []const u8,
) !zon_manifest.Manifest {
    var directory = if (std.fs.path.isAbsolute(root))
        try std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true })
    else
        try std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true });
    defer directory.close(io);

    const manifest_text = try directory.readFileAlloc(
        io,
        "build.zig.zon",
        allocator,
        .limited(max_file_size),
    );
    const manifest = try zon_manifest.parse(allocator, manifest_text);
    if (!std.mem.eql(u8, manifest.name, package.name)) {
        return error.ManifestNameMismatch;
    }
    try expectExactSet(package.publish_paths, manifest.paths);
    if (manifest.dependencies.len !=
        package.dependencies.len + package.external_dependencies.len)
    {
        return error.ManifestDependencyMismatch;
    }
    for (package.dependencies) |dependency_name| {
        const dependency = zon_manifest.findDependency(manifest, dependency_name) orelse
            return error.ManifestDependencyMismatch;
        if (dependency.path != null or dependency.url == null or dependency.hash == null) {
            return error.InternalDependencyIsNotImmutable;
        }
    }
    for (package.external_dependencies) |dependency_name| {
        const dependency = zon_manifest.findDependency(manifest, dependency_name) orelse
            return error.ManifestDependencyMismatch;
        if (dependency.path != null or dependency.url == null or dependency.hash == null) {
            return error.InvalidExternalDependency;
        }
    }
    for (package.publish_paths) |path| {
        const stat = try directory.statFile(io, path, .{ .follow_symlinks = false });
        if (stat.kind == .sym_link) return error.PublishedPathIsSymlink;
    }
    var walker = try directory.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind == .sym_link) return error.PackageTreeContainsSymlink;
        if (std.mem.eql(u8, entry.basename, ".zig-cache") or
            std.mem.eql(u8, entry.basename, "zig-cache") or
            std.mem.eql(u8, entry.basename, "zig-out") or
            std.mem.eql(u8, entry.basename, "zig-pkg"))
        {
            return error.PackageTreeContainsBuildArtifact;
        }
    }
    return manifest;
}

fn printMetadata(io: std.Io, package: registry.Package) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    try writer.print("branch\t{s}\n", .{package.branch});
    try writer.print("test\t{s}\n", .{package.test_command.?});
    try writer.print("examples\t{s}\n", .{package.examples_command orelse ":"});
    try writer.print("live-test\t{s}\n", .{package.live_test_command orelse ":"});
    try writer.print(
        "regeneration\t{s}\n",
        .{if (package.regeneration_command == null) "none" else "required"},
    );
}

fn printDependencies(
    io: std.Io,
    package: registry.Package,
    manifest: zon_manifest.Manifest,
) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    for (package.dependencies) |name| {
        const dependency = zon_manifest.findDependency(manifest, name).?;
        try writer.print(
            "{s}\t{s}\t{s}\n",
            .{ name, dependency.url.?, dependency.hash.? },
        );
    }
}

fn printPublishPaths(io: std.Io, package: registry.Package) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    for (package.publish_paths) |path| {
        try writer.writeAll(path);
        try writer.writeByte('\n');
    }
}

fn printDependencyMetadata(io: std.Io, package: registry.Package) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    for (package.dependencies) |name| {
        const dependency = registry.all[registry.find(&registry.all, name).?];
        try writer.print(
            "{s}\t{s}\t{s}\n",
            .{ name, @tagName(dependency.ownership), dependency.branch },
        );
    }
}

fn renderCi(
    allocator: std.mem.Allocator,
    io: std.Io,
    package: registry.Package,
    output: []const u8,
) !void {
    const template = @embedFile("package_branch_template/package-ci.yml");
    const with_test = try std.mem.replaceOwned(
        u8,
        allocator,
        template,
        "@TEST_COMMAND@",
        package.test_command.?,
    );
    const with_examples = try std.mem.replaceOwned(
        u8,
        allocator,
        with_test,
        "@EXAMPLES_COMMAND@",
        package.examples_command orelse "echo \"No examples configured\"",
    );
    const rendered = try std.mem.replaceOwned(
        u8,
        allocator,
        with_examples,
        "@LIVE_TEST_COMMAND@",
        package.live_test_command orelse "echo \"No live tests configured\"",
    );
    const parent_path = std.fs.path.dirname(output) orelse ".";
    const file_name = std.fs.path.basename(output);
    var parent = if (std.fs.path.isAbsolute(parent_path))
        try std.Io.Dir.openDirAbsolute(io, parent_path, .{})
    else
        try std.Io.Dir.cwd().createDirPathOpen(io, parent_path, .{});
    defer parent.close(io);
    try parent.writeFile(io, .{ .sub_path = file_name, .data = rendered });
}

fn checkVersion(target_text: []const u8, previous_texts: []const []const u8) !void {
    const target = try releaseVersion(target_text);
    for (previous_texts) |previous_text| {
        const previous = try releaseVersion(previous_text);
        if (target.order(previous) != .gt) return error.VersionIsNotMonotonic;
    }
}

fn releaseVersion(text: []const u8) !std.SemanticVersion {
    const version = std.SemanticVersion.parse(text) catch return error.InvalidVersion;
    if (version.pre != null or version.build != null) return error.InvalidVersion;
    return version;
}

fn expectExactSet(expected: []const []const u8, actual: []const []const u8) !void {
    if (expected.len != actual.len) return error.ManifestPathMismatch;
    for (expected) |value| {
        var found = false;
        for (actual) |candidate| {
            if (std.mem.eql(u8, value, candidate)) {
                found = true;
                break;
            }
        }
        if (!found) return error.ManifestPathMismatch;
    }
}

fn printLine(io: std.Io, comptime format: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    try stdout.interface.print(format, args);
    try stdout.interface.flush();
}

test "version checks require monotonic release versions" {
    try checkVersion("0.2.0", &.{ "0.1.0", "0.1.5" });
    try std.testing.expectError(
        error.VersionIsNotMonotonic,
        checkVersion("0.1.0", &.{"0.1.0"}),
    );
    try std.testing.expectError(
        error.InvalidVersion,
        checkVersion("0.2.0-dev.1", &.{"0.1.0"}),
    );
}
