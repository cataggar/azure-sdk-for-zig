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

    const sdk_mod = b.addModule("azure_sdk_eventhubs", .{
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

    const examples_step = b.step("examples", "Compile all Event Hubs examples");
    const example_sources = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{ .name = "eventhubs-send-events", .source = "examples/send_events.zig" },
        .{
            .name = "eventhubs-connection-string",
            .source = "examples/connection_string_auth.zig",
        },
        .{ .name = "eventhubs-batch-producer", .source = "examples/batch_producer.zig" },
        .{
            .name = "eventhubs-consume-partition",
            .source = "examples/consume_partition.zig",
        },
        .{ .name = "eventhubs-properties", .source = "examples/hub_properties.zig" },
        .{ .name = "eventhubs-processor", .source = "examples/processor.zig" },
    };
    for (example_sources) |example| {
        const executable = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                    .{ .name = "azure_sdk_eventhubs", .module = sdk_mod },
                },
            }),
        });
        examples_step.dependOn(&b.addInstallArtifact(executable, .{}).step);
        // Examples are API surface: a signature change that breaks one is a
        // break for every caller, so they build with the tests.
        test_step.dependOn(&executable.step);
    }

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("live_tests/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                .{ .name = "azure_sdk_eventhubs", .module = sdk_mod },
            },
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run Event Hubs live tests; every test skips when unconfigured",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
    test_step.dependOn(&live_tests.step);
}
