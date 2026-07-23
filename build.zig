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

    const blobs_mod = b.addModule("azure_sdk_storage_blobs", .{
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
    const test_step = b.step("test", "Run Storage Blobs tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const complete_sas_upload = b.addExecutable(.{
        .name = "storage-blob-complete-sas-upload",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/complete_sas_upload.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
            },
        }),
    });
    const examples_step = b.step("examples", "Compile Storage Blobs examples");
    examples_step.dependOn(&complete_sas_upload.step);
    test_step.dependOn(&complete_sas_upload.step);
    const run_complete_sas_upload = b.addRunArtifact(complete_sas_upload);
    if (b.args) |args| run_complete_sas_upload.addArgs(args);
    const complete_sas_upload_step = b.step(
        "complete-sas-upload",
        "Upload a file through a complete Blob SAS URL",
    );
    complete_sas_upload_step.dependOn(&run_complete_sas_upload.step);
}
