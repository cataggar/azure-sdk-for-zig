const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_dep = b.dependency("azure_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_core_mod = azure_sdk_dep.module("azure_core");

    const rest_dep = b.dependency("azure_rest_container_registry", .{
        .target = target,
        .optimize = optimize,
    });
    const rest_mod = rest_dep.module("azure_rest_container_registry");

    _ = b.addModule("azure_sdk_container_registry", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = azure_core_mod },
            .{ .name = "azure_rest_container_registry", .module = rest_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = azure_core_mod },
                .{ .name = "azure_rest_container_registry", .module = rest_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Container Registry SDK tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
