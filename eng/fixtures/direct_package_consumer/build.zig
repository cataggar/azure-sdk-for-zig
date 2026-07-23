const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ingest_mod = b.dependency("azure_sdk_kusto_ingest", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_kusto_ingest");

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_kusto_ingest", .module = ingest_mod },
            },
        }),
    });
    const test_step = b.step("test", "Compile a direct-package consumer");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
