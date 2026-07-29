const std = @import("std");

/// Single source of truth for the package version: the manifest.
const package_version = @import("build.zig.zon").version;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const options = b.addOptions();
    options.addOption([]const u8, "version", package_version);
    const options_mod = options.createModule();

    _ = b.addModule("azure_sdk_core", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "serde", .module = serde_mod },
            .{ .name = "build_options", .module = options_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "serde", .module = serde_mod },
                .{ .name = "build_options", .module = options_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Core tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
