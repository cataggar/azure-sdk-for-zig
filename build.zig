const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_dep = b.dependency("azure_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_core_mod = azure_sdk_dep.module("azure_core");
    const azure_identity_mod = azure_sdk_dep.module("azure_identity");

    const arm_avs_dep = b.dependency("arm_avs", .{
        .target = target,
        .optimize = optimize,
    });
    const arm_avs_mod = arm_avs_dep.module("arm_avs");

    const Example = struct {
        step: []const u8,
        src: []const u8,
        desc: []const u8,
    };
    const examples = [_]Example{
        .{
            .step = "list-private-clouds",
            .src = "list_private_clouds.zig",
            .desc = "List Microsoft.AVS private clouds in a subscription.",
        },
        .{
            .step = "list-clusters",
            .src = "list_clusters.zig",
            .desc = "List clusters in a private cloud (argv: <sub-id> <rg> <private-cloud>).",
        },
    };

    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.step,
            .root_module = b.createModule(.{
                .root_source_file = b.path(ex.src),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "arm_avs", .module = arm_avs_mod },
                    .{ .name = "azure_core", .module = azure_core_mod },
                    .{ .name = "azure_identity", .module = azure_identity_mod },
                },
            }),
        });
        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        const step = b.step(ex.step, ex.desc);
        step.dependOn(&run.step);
    }
}
