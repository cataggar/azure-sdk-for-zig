const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const common_dep = b.dependency("azure_sdk_messaging_common", .{
        .target = target,
        .optimize = optimize,
    });
    const common_mod = common_dep.module("azure_sdk_messaging_common");

    const blobs_dep = b.dependency("azure_sdk_storage_blobs", .{
        .target = target,
        .optimize = optimize,
    });
    const blobs_mod = blobs_dep.module("azure_sdk_storage_blobs");

    const uamqp_dep = b.dependency("uamqp", .{});
    const uamqp_mod = b.createModule(.{
        .root_source_file = uamqp_dep.path("src/zig/uamqp.zig"),
        .target = target,
    });

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    blobs_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("serde", serde_mod);

    _ = b.addModule("azure_sdk_eventhubs", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_messaging_common", .module = common_mod },
            .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
            .{ .name = "uamqp", .module = uamqp_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const eventhubs_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_messaging_common", .module = common_mod },
                .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                .{ .name = "uamqp", .module = uamqp_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const checkpoint_store_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("checkpoint_store.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Event Hubs tests");
    test_step.dependOn(&b.addRunArtifact(eventhubs_tests).step);
    test_step.dependOn(&b.addRunArtifact(checkpoint_store_tests).step);
}
