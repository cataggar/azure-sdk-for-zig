const std = @import("std");
const zon_manifest = @import("zon_manifest.zig");

const max_file_size = 16 * 1024 * 1024;

const Example = struct {
    name: []const u8,
    branch: []const u8,
    manifest_name: []const u8,
    version: []const u8,
    fingerprint: []const u8,
    paths: []const []const u8,
    source_paths: []const []const u8,
    build_zig: []const u8,
};

const arm_avs = Example{
    .name = "arm_avs",
    .branch = "example/arm_avs",
    .manifest_name = "avs_example",
    .version = "0.1.0",
    .fingerprint = "0xb722575032cc9eb4",
    .paths = &.{
        "build.zig",
        "build.zig.zon",
        "list_private_clouds.zig",
        "list_clusters.zig",
        "README.md",
        "LICENSE",
        ".gitignore",
    },
    .source_paths = &.{
        "list_private_clouds.zig",
        "list_clusters.zig",
    },
    .build_zig =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\
    \\    const core_dependency = b.dependency("azure_sdk_core", .{
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    const core_module = core_dependency.module("azure_sdk_core");
    \\    const arm_avs_dependency = b.dependency("azure_rest_arm_avs", .{
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    const arm_avs_module = arm_avs_dependency.module("azure_rest_arm_avs");
    \\
    \\    const test_step = b.step("test", "Compile all examples");
    \\    _ = b.step("live-test", "Live tests require Azure credentials");
    \\
    \\    const ExampleDefinition = struct {
    \\        step: []const u8,
    \\        source: []const u8,
    \\        description: []const u8,
    \\    };
    \\    const examples = [_]ExampleDefinition{
    \\        .{
    \\            .step = "list-private-clouds",
    \\            .source = "list_private_clouds.zig",
    \\            .description = "List Microsoft.AVS private clouds in a subscription",
    \\        },
    \\        .{
    \\            .step = "list-clusters",
    \\            .source = "list_clusters.zig",
    \\            .description = "List clusters in a private cloud",
    \\        },
    \\    };
    \\
    \\    for (examples) |example| {
    \\        const executable = b.addExecutable(.{
    \\            .name = example.step,
    \\            .root_module = b.createModule(.{
    \\                .root_source_file = b.path(example.source),
    \\                .target = target,
    \\                .optimize = optimize,
    \\                .imports = &.{
    \\                    .{ .name = "azure_sdk_core", .module = core_module },
    \\                    .{ .name = "azure_rest_arm_avs", .module = arm_avs_module },
    \\                },
    \\            }),
    \\        });
    \\        b.installArtifact(executable);
    \\        test_step.dependOn(&executable.step);
    \\
    \\        const run = b.addRunArtifact(executable);
    \\        if (b.args) |args| run.addArgs(args);
    \\        const run_step = b.step(example.step, example.description);
    \\        run_step.dependOn(&run.step);
    \\    }
    \\}
    \\
    ,
};

const arm_avs_wasi = Example{
    .name = "arm_avs_wasi",
    .branch = "example/arm_avs_wasi",
    .manifest_name = "avs_wasi",
    .version = "0.0.0",
    .fingerprint = "0x4eaf77d39eba7682",
    .paths = &.{
        "build.zig",
        "build.zig.zon",
        "src",
        "wit",
    },
    .source_paths = &.{"src/main.zig"},
    .build_zig =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const optimize = b.standardOptimizeOption(.{
    \\        .preferred_optimize_mode = .ReleaseSmall,
    \\    });
    \\    const target = b.resolveTargetQuery(.{
    \\        .cpu_arch = .wasm32,
    \\        .os_tag = .wasi,
    \\    });
    \\
    \\    const core_dependency = b.dependency("azure_sdk_core", .{
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    const core_module = core_dependency.module("azure_sdk_core");
    \\    const arm_avs_dependency = b.dependency("azure_rest_arm_avs", .{
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    const arm_avs_module = arm_avs_dependency.module("azure_rest_arm_avs");
    \\
    \\    const executable = b.addExecutable(.{
    \\        .name = "avs.core",
    \\        .root_module = b.createModule(.{
    \\            .root_source_file = b.path("src/main.zig"),
    \\            .target = target,
    \\            .optimize = optimize,
    \\            .imports = &.{
    \\                .{ .name = "azure_sdk_core", .module = core_module },
    \\                .{ .name = "azure_rest_arm_avs", .module = arm_avs_module },
    \\            },
    \\        }),
    \\    });
    \\    executable.entry = .disabled;
    \\    executable.rdynamic = true;
    \\    executable.use_llvm = false;
    \\    executable.use_lld = false;
    \\    b.installArtifact(executable);
    \\
    \\    const test_step = b.step("test", "Compile the WASI example");
    \\    test_step.dependOn(&executable.step);
    \\    _ = b.step("live-test", "Live tests require a WASI component runtime");
    \\}
    \\
    ,
};

const all = [_]Example{ arm_avs, arm_avs_wasi };

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len < 3) {
        usage();
        return 2;
    }
    const example = find(args[2]) orelse return error.UnknownExample;

    if (std.mem.eql(u8, args[1], "metadata") and args.len == 3) {
        try printMetadata(init.io, example);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "apply") and args.len == 4) {
        try apply(allocator, init.io, example, args[3]);
        try validate(allocator, init.io, example, args[3]);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "validate") and args.len == 4) {
        try validate(allocator, init.io, example, args[3]);
        return 0;
    }

    usage();
    return 2;
}

fn usage() void {
    std.debug.print(
        "usage: example-compatibility-tool <metadata NAME|apply NAME ROOT|" ++
            "validate NAME ROOT>\n",
        .{},
    );
}

fn find(name: []const u8) ?Example {
    for (all) |example| {
        if (std.mem.eql(u8, example.name, name)) return example;
    }
    return null;
}

fn printMetadata(io: std.Io, example: Example) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(io, &buffer);
    defer stdout.interface.flush() catch {};
    try stdout.interface.print("branch\t{s}\n", .{example.branch});
    try stdout.interface.writeAll("test\tzig build test --summary all\n");
    try stdout.interface.writeAll("live-test\tzig build live-test --summary all\n");
}

fn apply(
    allocator: std.mem.Allocator,
    io: std.Io,
    example: Example,
    root: []const u8,
) !void {
    var directory = try openRoot(io, root);
    defer directory.close(io);

    try directory.writeFile(io, .{
        .sub_path = "build.zig",
        .data = example.build_zig,
    });
    const manifest = try renderManifest(allocator, example);
    try directory.writeFile(io, .{
        .sub_path = "build.zig.zon",
        .data = manifest,
    });

    for (example.source_paths) |path| {
        const original = try directory.readFileAlloc(
            io,
            path,
            allocator,
            .limited(max_file_size),
        );
        const with_core = try replaceRequired(
            allocator,
            original,
            "@import(\"azure_core\")",
            "@import(\"azure_sdk_core\")",
        );
        const with_identity = try replaceOptional(
            allocator,
            with_core,
            "@import(\"azure_identity\")",
            "@import(\"azure_sdk_core\").identity",
        );
        const canonical = try replaceRequired(
            allocator,
            with_identity,
            "@import(\"arm_avs\")",
            "@import(\"azure_rest_arm_avs\")",
        );
        try directory.writeFile(io, .{ .sub_path = path, .data = canonical });
    }

    const readme = try directory.readFileAlloc(
        io,
        "README.md",
        allocator,
        .limited(max_file_size),
    );
    const canonical_readme = if (std.mem.eql(u8, example.name, "arm_avs"))
        try transformArmReadme(allocator, readme)
    else
        try transformWasiReadme(allocator, readme);
    try directory.writeFile(io, .{
        .sub_path = "README.md",
        .data = canonical_readme,
    });
}

fn validate(
    allocator: std.mem.Allocator,
    io: std.Io,
    example: Example,
    root: []const u8,
) !void {
    var directory = try openRoot(io, root);
    defer directory.close(io);

    const build_zig = try directory.readFileAlloc(
        io,
        "build.zig",
        allocator,
        .limited(max_file_size),
    );
    if (!std.mem.eql(u8, build_zig, example.build_zig)) {
        return error.BuildDefinitionMismatch;
    }

    const manifest_text = try directory.readFileAlloc(
        io,
        "build.zig.zon",
        allocator,
        .limited(max_file_size),
    );
    const manifest = try zon_manifest.parse(allocator, manifest_text);
    if (!std.mem.eql(u8, manifest.name, example.manifest_name) or
        !std.mem.eql(u8, manifest.version, example.version) or
        !std.mem.eql(u8, manifest.fingerprint, example.fingerprint))
    {
        return error.ManifestMetadataMismatch;
    }
    try expectExactSet(example.paths, manifest.paths);
    if (manifest.dependencies.len != 2 or
        zon_manifest.findDependency(manifest, "azure_sdk_core") == null or
        zon_manifest.findDependency(manifest, "azure_rest_arm_avs") == null)
    {
        return error.ManifestDependencyMismatch;
    }

    for (example.source_paths) |path| {
        const text = try directory.readFileAlloc(
            io,
            path,
            allocator,
            .limited(max_file_size),
        );
        if (std.mem.indexOf(u8, text, "@import(\"azure_sdk_core\")") == null or
            std.mem.indexOf(u8, text, "@import(\"azure_rest_arm_avs\")") == null or
            std.mem.indexOf(u8, text, "@import(\"azure_core\")") != null or
            std.mem.indexOf(u8, text, "@import(\"azure_identity\")") != null or
            std.mem.indexOf(u8, text, "@import(\"arm_avs\")") != null)
        {
            return error.NonCanonicalImport;
        }
    }
}

fn renderManifest(allocator: std.mem.Allocator, example: Example) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;

    try writer.print(
        \\.{{
        \\    .name = .{s},
        \\    .version = "{s}",
        \\    .fingerprint = {s},
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{{
        \\        .azure_sdk_core = .{{
        \\            .path = ".",
        \\        }},
        \\        .azure_rest_arm_avs = .{{
        \\            .path = ".",
        \\        }},
        \\    }},
        \\    .paths = .{{
        \\
    , .{ example.manifest_name, example.version, example.fingerprint });
    for (example.paths) |path| {
        try writer.print("        \"{s}\",\n", .{path});
    }
    try writer.writeAll(
        \\    },
        \\}
        \\
    );
    return output.toOwnedSlice();
}

fn transformArmReadme(
    allocator: std.mem.Allocator,
    text: []const u8,
) ![]const u8 {
    const title = try replaceRequired(
        allocator,
        text,
        "# arm-avs examples",
        "# azure_rest_arm_avs examples",
    );
    const package_name = try replaceRequired(
        allocator,
        title,
        "**`arm_avs`**",
        "**`azure_rest_arm_avs`**",
    );
    const core_name = try replaceRequired(
        allocator,
        package_name,
        "`azure_core` / `azure_identity`",
        "`azure_sdk_core`",
    );
    return replaceRequired(
        allocator,
        core_name,
        "blob/main/sdk/identity/azure_cli.zig",
        "blob/main/sdk/core/identity/azure_cli.zig",
    );
}

fn transformWasiReadme(
    allocator: std.mem.Allocator,
    text: []const u8,
) ![]const u8 {
    const package_name = try replaceRequired(
        allocator,
        text,
        "generated [`arm_avs`]",
        "generated [`azure_rest_arm_avs`]",
    );
    return replaceRequired(
        allocator,
        package_name,
        "`azure_core`'s `sdk/core/http/wasi_http.zig`",
        "`azure_sdk_core`'s `sdk/core/http/wasi_http.zig`",
    );
}

fn replaceRequired(
    allocator: std.mem.Allocator,
    text: []const u8,
    old: []const u8,
    new: []const u8,
) ![]const u8 {
    if (std.mem.indexOf(u8, text, old) == null) {
        if (std.mem.indexOf(u8, text, new) != null) return text;
        return error.ExpectedTextNotFound;
    }
    return std.mem.replaceOwned(u8, allocator, text, old, new);
}

fn replaceOptional(
    allocator: std.mem.Allocator,
    text: []const u8,
    old: []const u8,
    new: []const u8,
) ![]const u8 {
    if (std.mem.indexOf(u8, text, old) == null) return text;
    return std.mem.replaceOwned(u8, allocator, text, old, new);
}

fn openRoot(io: std.Io, root: []const u8) !std.Io.Dir {
    return if (std.fs.path.isAbsolute(root))
        std.Io.Dir.openDirAbsolute(io, root, .{ .iterate = true })
    else
        std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true });
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

test "compatibility definitions use canonical dependencies" {
    for (all) |example| {
        try std.testing.expect(
            std.mem.indexOf(u8, example.build_zig, "azure_sdk_core") != null,
        );
        try std.testing.expect(
            std.mem.indexOf(u8, example.build_zig, "azure_rest_arm_avs") != null,
        );
        const manifest = try renderManifest(std.testing.allocator, example);
        defer std.testing.allocator.free(manifest);
        const parsed = try zon_manifest.parse(std.testing.allocator, manifest);
        defer std.testing.allocator.free(parsed.dependencies);
        defer std.testing.allocator.free(parsed.paths);
        try std.testing.expectEqual(@as(usize, 2), parsed.dependencies.len);
        try expectExactSet(example.paths, parsed.paths);
    }
}
