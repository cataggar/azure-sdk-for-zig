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

    const amqp_dep = b.dependency("azure_sdk_amqp", .{
        .target = target,
        .optimize = optimize,
    });
    const amqp_mod = amqp_dep.module("azure_sdk_amqp");
    // Reuse the AMQP package's uamqp module rather than building a second one.
    // Two modules over the same source produce two incompatible copies of
    // every type, so an `AmqpValue` could not cross the package boundary.
    const uamqp_mod = amqp_dep.module("uamqp");

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
            .{ .name = "azure_sdk_amqp", .module = amqp_mod },
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
                .{ .name = "azure_sdk_amqp", .module = amqp_mod },
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
            },
        }),
    });
    const test_step = b.step("test", "Run Event Hubs tests");
    test_step.dependOn(&b.addRunArtifact(eventhubs_tests).step);
    test_step.dependOn(&b.addRunArtifact(checkpoint_store_tests).step);
}
