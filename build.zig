const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dependency = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_module = core_dependency.module("azure_sdk_core");
    const arm_avs_dependency = b.dependency("azure_rest_arm_avs", .{
        .target = target,
        .optimize = optimize,
    });
    const arm_avs_module = arm_avs_dependency.module("azure_rest_arm_avs");

    const test_step = b.step("test", "Compile all examples");
    _ = b.step("live-test", "Live tests require Azure credentials");

    const ExampleDefinition = struct {
        step: []const u8,
        source: []const u8,
        description: []const u8,
    };
    const examples = [_]ExampleDefinition{
        .{
            .step = "list-private-clouds",
            .source = "list_private_clouds.zig",
            .description = "List Microsoft.AVS private clouds in a subscription",
        },
        .{
            .step = "list-clusters",
            .source = "list_clusters.zig",
            .description = "List clusters in a private cloud",
        },
    };

    for (examples) |example| {
        const executable = b.addExecutable(.{
            .name = example.step,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_module },
                    .{ .name = "azure_rest_arm_avs", .module = arm_avs_module },
                },
            }),
        });
        b.installArtifact(executable);
        test_step.dependOn(&executable.step);

        const run = b.addRunArtifact(executable);
        if (b.args) |args| run.addArgs(args);
        const run_step = b.step(example.step, example.description);
        run_step.dependOn(&run.step);
    }
}
