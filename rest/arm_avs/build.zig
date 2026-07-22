const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_sdk_core_mod = azure_sdk_core_dep.module("azure_sdk_core");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const lib_mod = b.addModule("azure_rest_arm_avs", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(t).step);

    const list_private_clouds = b.addExecutable(.{
        .name = "list-private-clouds",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/list_private_clouds.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_rest_arm_avs", .module = lib_mod },
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            },
        }),
    });
    const run_list_private_clouds = b.addRunArtifact(list_private_clouds);
    if (b.args) |args| run_list_private_clouds.addArgs(args);
    const list_private_clouds_step = b.step(
        "list-private-clouds",
        "List Microsoft.AVS private clouds in a subscription",
    );
    list_private_clouds_step.dependOn(&run_list_private_clouds.step);
    test_step.dependOn(&list_private_clouds.step);

    const list_clusters = b.addExecutable(.{
        .name = "list-clusters",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/list_clusters.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_rest_arm_avs", .module = lib_mod },
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            },
        }),
    });
    const run_list_clusters = b.addRunArtifact(list_clusters);
    if (b.args) |args| run_list_clusters.addArgs(args);
    const list_clusters_step = b.step(
        "list-clusters",
        "List clusters in a private cloud",
    );
    list_clusters_step.dependOn(&run_list_clusters.step);
    test_step.dependOn(&list_clusters.step);
}
