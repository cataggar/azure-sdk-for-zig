const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_dep = b.dependency("azure_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_core_mod = azure_sdk_dep.module("azure_core");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const lib_mod = b.addModule("arm_avs", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = azure_core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = azure_core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(t).step);

    // -- Examples --
    //
    // `zig build list-private-clouds` (or `zig build list-private-clouds -- <sub-id>`).
    const example = b.addExecutable(.{
        .name = "list-private-clouds",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/list_private_clouds.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "arm_avs", .module = lib_mod },
                .{ .name = "azure_core", .module = azure_core_mod },
            },
        }),
    });
    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    const example_step = b.step(
        "list-private-clouds",
        "List Microsoft.AVS private clouds in $AZURE_SUBSCRIPTION_ID (or argv[1]).",
    );
    example_step.dependOn(&run_example.step);

    // `zig build list-clusters -- <sub-id> <rg> <private-cloud>`
    const list_clusters_exe = b.addExecutable(.{
        .name = "list-clusters",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/list_clusters.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "arm_avs", .module = lib_mod },
                .{ .name = "azure_core", .module = azure_core_mod },
            },
        }),
    });
    const run_list_clusters = b.addRunArtifact(list_clusters_exe);
    if (b.args) |args| run_list_clusters.addArgs(args);
    const list_clusters_step = b.step(
        "list-clusters",
        "List clusters in a private cloud (argv: <sub-id> <rg> <private-cloud>).",
    );
    list_clusters_step.dependOn(&run_list_clusters.step);
}
