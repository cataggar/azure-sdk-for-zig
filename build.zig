const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    _ = b.addModule("azure_sdk_keyvault", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const test_step = b.step("test", "Run Key Vault tests");
    const namespace_roots = [_][]const u8{
        "secrets/root.zig",
        "keys/root.zig",
        "certificates/root.zig",
        "administration/root.zig",
    };
    for (namespace_roots) |namespace_root| {
        const tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(namespace_root),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(tests).step);
    }
}
