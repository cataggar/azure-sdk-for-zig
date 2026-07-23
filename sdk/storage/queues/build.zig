const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const common_dep = b.dependency("azure_sdk_storage_common", .{
        .target = target,
        .optimize = optimize,
    });
    const common_mod = common_dep.module("azure_sdk_storage_common");
    common_mod.addImport("azure_sdk_core", core_mod);

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const queues_mod = b.addModule("azure_sdk_storage_queues", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_storage_common", .module = common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_storage_common", .module = common_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Storage Queues tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const complete_sas_message = b.addExecutable(.{
        .name = "storage-queue-complete-sas-message",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/complete_sas_message.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_storage_queues", .module = queues_mod },
            },
        }),
    });
    const examples_step = b.step("examples", "Compile Storage Queues examples");
    examples_step.dependOn(&complete_sas_message.step);
    test_step.dependOn(&complete_sas_message.step);
    const run_complete_sas_message = b.addRunArtifact(complete_sas_message);
    if (b.args) |args| run_complete_sas_message.addArgs(args);
    const complete_sas_message_step = b.step(
        "complete-sas-message",
        "Send a message through a complete Queue SAS URL",
    );
    complete_sas_message_step.dependOn(&run_complete_sas_message.step);
}
