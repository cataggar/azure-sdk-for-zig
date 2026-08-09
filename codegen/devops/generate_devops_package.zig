//! Generate the `azure_rest_devops` package.
//!
//! Azure DevOps publishes 44 independent API areas that share a host
//! family, an auth scheme and a release cadence, so they ship as one
//! package with a namespace per area rather than 44 packages.
//!
//! Input is a directory of JSON code models produced by
//! `codegen/devops/build-devops-models.mjs`, described by an
//! `areas.json` index. Output is a package tree:
//!
//!   <out-dir>/
//!     build.zig
//!     build.zig.zon
//!     README.md
//!     src/
//!       root.zig          # re-exports every area
//!       clients_test.zig  # operator-owned
//!       git/{root,clients,models,enums}.zig
//!       build/{root,clients,models,enums}.zig
//!       …

const std = @import("std");
const emitter = @import("emit");

const Area = struct {
    area: []const u8,
    namespace: []const u8,
    display_name: []const u8,
    specs: usize,
    clients: usize,
    methods: usize,
    endpoint: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();
    const io = init.io;

    var args: std.process.Args.Iterator = try .initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.skip();
    const model_dir_path = args.next() orelse return error.MissingModelDirectory;
    const output_path = args.next() orelse return error.MissingOutputPath;
    var azure_sdk_core_commit: ?[]const u8 = null;
    var azure_sdk_core_hash: ?[]const u8 = null;
    var azure_sdk_core_path: ?[]const u8 = null;
    var generator_commit: ?[]const u8 = null;
    var spec_commit: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--azure-sdk-core-commit")) {
            azure_sdk_core_commit = args.next() orelse return error.MissingAzureSdkCoreCommit;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-hash")) {
            azure_sdk_core_hash = args.next() orelse return error.MissingAzureSdkCoreHash;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-path")) {
            azure_sdk_core_path = args.next() orelse return error.MissingAzureSdkCorePath;
        } else if (std.mem.eql(u8, arg, "--generator-commit")) {
            generator_commit = args.next() orelse return error.MissingGeneratorCommit;
        } else if (std.mem.eql(u8, arg, "--spec-commit")) {
            spec_commit = args.next() orelse return error.MissingSpecCommit;
        } else {
            return error.UnexpectedArgument;
        }
    }
    if ((azure_sdk_core_commit == null) != (azure_sdk_core_hash == null)) {
        return error.IncompleteAzureSdkCorePin;
    }
    if (azure_sdk_core_commit != null and azure_sdk_core_path != null) {
        return error.ConflictingAzureSdkCoreDependency;
    }

    var model_dir = try openDir(io, model_dir_path);
    defer model_dir.close(io);

    const areas_json = try model_dir.readFileAlloc(io, "areas.json", allocator, .limited(4 * 1024 * 1024));
    const areas = try std.json.parseFromSliceLeaky(
        []Area,
        allocator,
        areas_json,
        .{ .ignore_unknown_fields = true },
    );
    if (areas.len == 0) return error.NoAreas;

    var output = try recreateDir(io, output_path);
    defer output.close(io);

    // Parsed models are held for the whole run because `emitPackageShell`
    // reports per-area client and operation counts in the README.
    const namespaces = try allocator.alloc(emitter.Namespace, areas.len);
    for (areas, namespaces) |area, *namespace| {
        const file_name = try std.fmt.allocPrint(allocator, "{s}.json", .{area.namespace});
        const json = try model_dir.readFileAlloc(io, file_name, allocator, .limited(512 * 1024 * 1024));
        const model = try std.json.parseFromSliceLeaky(
            emitter.CodeModel,
            allocator,
            json,
            .{ .ignore_unknown_fields = true },
        );
        namespace.* = .{
            .name = area.namespace,
            .display_name = area.display_name,
            .model = model,
        };
        try emitter.emitNamespace(allocator, io, output, namespace.*, .{});
    }

    try emitter.emitPackageShell(
        allocator,
        io,
        output,
        namespaces[0].model.package_version,
        namespaces,
        .{
            .package_name = "azure_rest_devops",
            .display_name = "Azure DevOps REST for Zig",
            .readme_intro = readme_intro,
            .azure_sdk_core_commit = azure_sdk_core_commit,
            .azure_sdk_core_hash = azure_sdk_core_hash,
            .azure_sdk_core_path = azure_sdk_core_path orelse "../../sdk/core",
        },
    );

    const zon = try output.readFileAlloc(io, "build.zig.zon", allocator, .limited(1024 * 1024));
    try output.writeFile(io, .{
        .sub_path = "build.zig.zon",
        .data = try addLicensePath(allocator, zon),
    });
    if (std.Io.Dir.readFileAlloc(.cwd(), io, "../../LICENSE.txt", allocator, .limited(1024 * 1024))) |license| {
        try output.writeFile(io, .{ .sub_path = "LICENSE.txt", .data = license });
    } else |_| {}
    try output.writeFile(io, .{ .sub_path = "src/clients_test.zig", .data = generated_tests });
    try output.writeFile(io, .{
        .sub_path = ".azure-sdk-generator",
        .data = try renderProvenance(
            allocator,
            generator_commit,
            spec_commit,
            azure_sdk_core_commit,
            azure_sdk_core_hash,
            areas.len,
        ),
    });
}

/// Render the `.azure-sdk-generator` provenance file every package branch
/// carries, recording the generator revision, the spec revision and the
/// command that reproduces this output.
fn renderProvenance(
    allocator: std.mem.Allocator,
    generator_commit: ?[]const u8,
    spec_commit: ?[]const u8,
    core_commit: ?[]const u8,
    core_hash: ?[]const u8,
    area_count: usize,
) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;
    try w.print("generator_commit={s}\n", .{generator_commit orelse "unknown"});
    try w.writeAll("source_repository=https://github.com/cataggar/vsts-rest-api-specs\n");
    try w.print("source_commit={s}\n", .{spec_commit orelse "unknown"});
    try w.writeAll("source_branch=typespec\n");
    try w.writeAll("source_path=typespec/specs\n");
    try w.writeAll("selected_api_version=7.2\n");
    try w.print("api_areas={d}\n", .{area_count});
    try w.print(
        "command=(node codegen/devops/build-devops-models.mjs <specs-dir> <model-dir> && cd codegen/cli && zig build" ++
            " -Ddevops-models=<model-dir> -Ddevops-output=<package-output>" ++
            " -Dazure-sdk-core-commit={s} -Dazure-sdk-core-hash={s} generate-devops-package)\n",
        .{ core_commit orelse "<commit>", core_hash orelse "<hash>" },
    );
    return try aw.toOwnedSlice();
}

fn openDir(io: std.Io, path: []const u8) !std.Io.Dir {
    return if (std.fs.path.isAbsolute(path))
        std.Io.Dir.openDirAbsolute(io, path, .{})
    else
        std.Io.Dir.cwd().openDir(io, path, .{});
}

fn recreateDir(io: std.Io, path: []const u8) !std.Io.Dir {
    const parent_path = std.fs.path.dirname(path) orelse ".";
    const directory_name = std.fs.path.basename(path);
    if (std.mem.eql(u8, directory_name, ".") or std.mem.eql(u8, directory_name, "..")) {
        return error.InvalidOutputPath;
    }
    var parent = if (std.fs.path.isAbsolute(path))
        try std.Io.Dir.openDirAbsolute(io, parent_path, .{})
    else
        try std.Io.Dir.cwd().createDirPathOpen(io, parent_path, .{});
    defer parent.close(io);
    try parent.deleteTree(io, directory_name);
    return parent.createDirPathOpen(io, directory_name, .{});
}

fn addLicensePath(allocator: std.mem.Allocator, zon: []const u8) ![]u8 {
    const marker = "        \"README.md\",\n";
    const index = std.mem.indexOf(u8, zon, marker) orelse return error.MissingReadmePath;
    const insertion = marker ++ "        \"LICENSE.txt\",\n";
    const output = try allocator.alloc(u8, zon.len - marker.len + insertion.len);
    @memcpy(output[0..index], zon[0..index]);
    @memcpy(output[index .. index + insertion.len], insertion);
    @memcpy(output[index + insertion.len ..], zon[index + marker.len ..]);
    return output;
}

const readme_intro =
    \\`azure_rest_devops` is the generated Azure DevOps protocol package for
    \\the **7.2** REST contract. It is entirely generator-owned; update the
    \\TypeSpec source or emitter and regenerate instead of editing package
    \\files by hand.
    \\
    \\## Protocol surface
    \\
    \\Azure DevOps publishes its REST API as 44 independent areas that share
    \\a host family, an auth scheme and a release cadence, so they ship here
    \\as one package with a Zig namespace per area rather than 44 packages.
    \\Each area exposes a root client (`root.git.GitClient`) whose accessor
    \\methods reach the area's operation groups
    \\(`git_client.repositories()`), matching the shape Azure DevOps uses in
    \\its REST documentation.
    \\
    \\`api-version` is client state pinned to the area's 7.2 contract, and
    \\each area's root client carries the default endpoint for its own host
    \\(`dev.azure.com`, `vssps.dev.azure.com`, `pkgs.dev.azure.com`, …),
    \\overridable through `InitOptions` for Azure DevOps Server.
    \\
    \\The source contract is the `typespec` branch of
    \\[`cataggar/vsts-rest-api-specs`](https://github.com/cataggar/vsts-rest-api-specs/tree/typespec/typespec),
    \\which converts Microsoft's published Swagger 2.0 definitions to
    \\TypeSpec. The `.azure-sdk-generator` provenance file records the
    \\generator revision, the spec revision and the reproducible generation
    \\command.
    \\
    \\## Build and regeneration
    \\
    \\```bash
    \\zig build test --summary all
    \\```
    \\
    \\The manifest pins `azure_sdk_core` by immutable release commit and Zig
    \\package hash.
    \\
;

const generated_tests =
    \\//! Tests for the generated Azure DevOps clients.
    \\//!
    \\//! Kept in a separate file so the emitter can overwrite every
    \\//! `clients.zig` without losing test coverage. Wired into the
    \\//! package's test step via `root.zig`.
    \\//!
    \\//! This file is **operator-owned**: `codegen/scripts/sync.sh` marks
    \\//! it as operator-managed and never overwrites an existing copy.
    \\
    \\const std = @import("std");
    \\const root = @import("root.zig");
    \\
    \\test "every API area is reachable from the package root" {
    \\    try std.testing.expect(@hasDecl(root, "git"));
    \\    try std.testing.expect(@hasDecl(root, "build"));
    \\}
    \\
    \\test "operation groups are reachable from an area root client" {
    \\    try std.testing.expect(@hasDecl(root.git.GitClient, "repositories"));
    \\    try std.testing.expect(@hasDecl(root.build.BuildClient, "builds"));
    \\}
    \\
;
