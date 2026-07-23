const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    _ = b.addModule("azure_sdk_storage_common", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Storage Common tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
