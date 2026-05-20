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

    const lib_mod = b.addModule("arm_avs", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = azure_core_mod },
        },
    });

    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = azure_core_mod },
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
                .{ .name = "azure_identity", .module = azure_identity_mod },
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
}
