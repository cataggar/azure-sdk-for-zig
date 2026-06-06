const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_dep = b.dependency("azure_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_core_mod = azure_sdk_dep.module("azure_core");

    _ = b.addModule("keyvault_secrets", .{
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
}
