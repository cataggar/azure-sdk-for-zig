const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracing_dep = b.dependency("azure_sdk_core_tracing", .{
        .target = target,
        .optimize = optimize,
    });
    const tracing_mod = tracing_dep.module("azure_sdk_core_tracing");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    _ = b.addModule("azure_sdk_core", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core_tracing", .module = tracing_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core_tracing", .module = tracing_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Core tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
