const std = @import("std");
const registry = @import("packages.zig");
const zon_manifest = @import("zon_manifest.zig");

const max_file_size = 16 * 1024 * 1024;

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 2) {
        usage();
        return 2;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "check")) {
        try check(allocator, io);
    } else if (std.mem.eql(u8, command, "list")) {
        try list(allocator, io);
    } else if (std.mem.eql(u8, command, "graph")) {
        try graph(allocator, io);
    } else if (std.mem.eql(u8, command, "ci-matrix")) {
        try ciMatrix(io);
    } else if (std.mem.eql(u8, command, "sync-local")) {
        if (args.len > 3 or (args.len == 3 and !std.mem.eql(u8, args[2], "--check"))) {
            usage();
            return 2;
        }
        if (args.len == 2) try syncLocal(allocator, io);
        try check(allocator, io);
    } else {
        std.debug.print("unknown command: {s}\n", .{command});
        usage();
        return 2;
    }
    return 0;
}

fn usage() void {
    std.debug.print(
        "usage: package-tool <check|list|graph|ci-matrix|sync-local [--check]>\n",
        .{},
    );
}

fn check(allocator: std.mem.Allocator, io: std.Io) !void {
    try registry.validate(allocator, &registry.all);
    if (registry.all.len != 23) return error.UnexpectedPackageCount;

    const root_license = try readFile(allocator, io, "LICENSE.txt");
    const root_readme = try readFile(allocator, io, "README.md");
    try checkRootReadme(root_readme);
    const catalog = try readFile(allocator, io, "doc/package-catalog.md");

    for (registry.all) |entry| {
        if (std.mem.indexOf(u8, catalog, entry.name) == null) {
            return error.PackageMissingFromCatalog;
        }
        if (entry.ownership != .main_owned) continue;
        const workspace_path = entry.workspace_path orelse
            return error.MissingWorkspacePath;
        const readme_path = try std.fs.path.join(
            allocator,
            &.{ workspace_path, "README.md" },
        );
        _ = try readFile(allocator, io, readme_path);

        const license_path = try std.fs.path.join(
            allocator,
            &.{ workspace_path, "LICENSE.txt" },
        );
        const package_license = try readFile(allocator, io, license_path);
        if (!std.mem.eql(u8, root_license, package_license)) {
            return error.PackageLicenseMismatch;
        }

        const build_path = try std.fs.path.join(
            allocator,
            &.{ workspace_path, "build.zig" },
        );
        _ = try readFile(allocator, io, build_path);
        const root_source_path = try std.fs.path.join(
            allocator,
            &.{ workspace_path, entry.root_source_file },
        );
        _ = try readFile(allocator, io, root_source_path);
        try checkManifest(allocator, io, entry);
    }
    std.debug.print("package registry: {d} packages valid\n", .{registry.all.len});
}

fn checkRootReadme(readme: []const u8) !void {
    if (!std.mem.startsWith(u8, readme, "# Azure SDK for Zig\n")) {
        return error.InvalidRootReadmeTitle;
    }
    const expected = [_][]const u8{
        "## SDK Packages",
        "## Documentation",
        "## License",
    };
    var heading_index: usize = 0;
    var lines = std.mem.splitScalar(u8, readme, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "## ")) continue;
        if (heading_index >= expected.len or
            !std.mem.eql(u8, line, expected[heading_index]))
        {
            return error.InvalidRootReadmeSection;
        }
        heading_index += 1;
    }
    if (heading_index != expected.len) return error.InvalidRootReadmeSection;
}

fn list(allocator: std.mem.Allocator, io: std.Io) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &stdout_buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    const order = try registry.topologicalOrder(allocator, &registry.all);
    for (order) |index| {
        const entry = registry.all[index];
        const workspace_path = entry.workspace_path orelse "-";
        try writer.print(
            "{s}\t{s}\t{s}\t{s}\n",
            .{ entry.name, workspace_path, entry.branch, @tagName(entry.ownership) },
        );
    }
}

fn graph(allocator: std.mem.Allocator, io: std.Io) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &stdout_buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    const order = try registry.topologicalOrder(allocator, &registry.all);
    for (order) |index| {
        const entry = registry.all[index];
        try writer.print("{s}", .{entry.name});
        for (entry.dependencies) |dependency| {
            try writer.print("\t{s}", .{dependency});
        }
        try writer.writeByte('\n');
    }
}

fn ciMatrix(io: std.Io) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &stdout_buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    try writer.writeAll("{\"include\":[");
    var first = true;
    for (registry.all) |entry| {
        if (entry.ownership != .main_owned) continue;
        const workspace_path = entry.workspace_path orelse
            return error.MissingWorkspacePath;
        if (!first) try writer.writeByte(',');
        first = false;
        try writer.print(
            "{{\"package\":\"{s}\",\"path\":\"{s}\"}}",
            .{ entry.name, workspace_path },
        );
    }
    try writer.writeAll("]}\n");
}

fn syncLocal(allocator: std.mem.Allocator, io: std.Io) !void {
    const root_license = try readFile(allocator, io, "LICENSE.txt");
    for (registry.all) |entry| {
        if (entry.ownership != .main_owned) continue;
        const workspace_path = entry.workspace_path orelse
            return error.MissingWorkspacePath;
        const license_path = try std.fs.path.join(
            allocator,
            &.{ workspace_path, "LICENSE.txt" },
        );
        try std.Io.Dir.writeFile(
            .cwd(),
            io,
            .{ .sub_path = license_path, .data = root_license },
        );
        try syncManifest(allocator, io, entry);
    }
}

fn checkManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    entry: registry.Package,
) !void {
    const workspace_path = entry.workspace_path orelse
        return error.MissingWorkspacePath;
    const manifest_path = try std.fs.path.join(
        allocator,
        &.{ workspace_path, "build.zig.zon" },
    );
    const manifest = try readFile(allocator, io, manifest_path);
    const parsed = try zon_manifest.parse(allocator, manifest);
    if (!std.mem.eql(u8, parsed.name, entry.name)) return error.ManifestNameMismatch;
    if (!std.mem.eql(u8, parsed.version, entry.version)) {
        return error.ManifestVersionMismatch;
    }
    try expectExactSet(entry.publish_paths, parsed.paths, error.ManifestPathMismatch);

    const expected_dependency_count =
        entry.dependencies.len + entry.external_dependencies.len;
    if (parsed.dependencies.len != expected_dependency_count) {
        return error.ManifestDependencyMismatch;
    }
    for (entry.dependencies) |dependency_name| {
        const dependency = zon_manifest.findDependency(parsed, dependency_name) orelse
            return error.ManifestDependencyMismatch;
        if (dependency.path == null or dependency.url != null or dependency.hash != null) {
            return error.InvalidLocalDependency;
        }
        const dependency_entry = registry.all[
            registry.find(&registry.all, dependency_name).?
        ];
        if (dependency_entry.ownership != .main_owned) {
            return error.MainDependsOnBranchOwned;
        }
        const dependency_workspace = dependency_entry.workspace_path orelse
            return error.MissingWorkspacePath;
        if (std.fs.path.isAbsolute(dependency.path.?)) {
            return error.InvalidLocalDependency;
        }
        const actual = try std.fs.path.resolve(
            allocator,
            &.{ workspace_path, dependency.path.? },
        );
        const expected = try std.fs.path.resolve(allocator, &.{dependency_workspace});
        if (!std.mem.eql(u8, actual, expected)) return error.InvalidLocalDependency;
    }
    for (entry.external_dependencies) |dependency_name| {
        const dependency = zon_manifest.findDependency(parsed, dependency_name) orelse
            return error.ManifestDependencyMismatch;
        if (dependency.path != null or dependency.url == null or dependency.hash == null) {
            return error.InvalidExternalDependency;
        }
    }
}

fn expectExactSet(
    expected: []const []const u8,
    actual: []const []const u8,
    mismatch: anyerror,
) !void {
    if (expected.len != actual.len) return mismatch;
    for (expected, 0..) |value, index| {
        var found = false;
        for (actual) |candidate| {
            if (std.mem.eql(u8, value, candidate)) {
                found = true;
                break;
            }
        }
        if (!found) return mismatch;
        for (expected[index + 1 ..]) |other| {
            if (std.mem.eql(u8, value, other)) return mismatch;
        }
    }
}

fn syncManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    entry: registry.Package,
) !void {
    const workspace_path = entry.workspace_path orelse
        return error.MissingWorkspacePath;
    const manifest_path = try std.fs.path.join(
        allocator,
        &.{ workspace_path, "build.zig.zon" },
    );
    const manifest = try readFile(allocator, io, manifest_path);

    var output: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, manifest, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        const indent = line[0 .. line.len - trimmed.len];
        if (std.mem.startsWith(u8, trimmed, ".name = .")) {
            try output.appendSlice(allocator, indent);
            try output.appendSlice(allocator, ".name = .");
            try output.appendSlice(allocator, entry.name);
            try output.appendSlice(allocator, ",");
        } else if (std.mem.startsWith(u8, trimmed, ".version = \"")) {
            try output.appendSlice(allocator, indent);
            try output.appendSlice(allocator, ".version = \"");
            try output.appendSlice(allocator, entry.version);
            try output.appendSlice(allocator, "\",");
        } else {
            try output.appendSlice(allocator, line);
        }
        if (lines.peek() != null) try output.append(allocator, '\n');
    }

    try std.Io.Dir.writeFile(
        .cwd(),
        io,
        .{ .sub_path = manifest_path, .data = output.items },
    );
}

fn readFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) ![]u8 {
    return std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        path,
        allocator,
        .limited(max_file_size),
    );
}
