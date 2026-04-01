const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -- Modules (libraries exposed to consumers) --

    const core_mod = b.addModule("azure_core", .{
        .root_source_file = b.path("src/azure/core/root.zig"),
        .target = target,
    });

    const identity_mod = b.addModule("azure_identity", .{
        .root_source_file = b.path("src/azure/identity/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
        },
    });

    _ = b.addModule("azure_storage_blobs", .{
        .root_source_file = b.path("src/azure/storage/blobs/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_identity", .module = identity_mod },
        },
    });

    _ = b.addModule("azure_storage_common", .{
        .root_source_file = b.path("src/azure/storage/common/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
        },
    });

    _ = b.addModule("azure_keyvault_secrets", .{
        .root_source_file = b.path("src/azure/keyvault/secrets/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_identity", .module = identity_mod },
        },
    });

    _ = b.addModule("azure_data_tables", .{
        .root_source_file = b.path("src/azure/data/tables/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_identity", .module = identity_mod },
        },
    });

    // -- Tests --

    const core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/azure/core/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const identity_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/azure/identity/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
            },
        }),
    });

    const run_core_tests = b.addRunArtifact(core_tests);
    const run_identity_tests = b.addRunArtifact(identity_tests);

    const storage_common_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/azure/storage/common/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
            },
        }),
    });
    const run_storage_common_tests = b.addRunArtifact(storage_common_tests);

    const kv_secrets_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/azure/keyvault/secrets/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
                .{ .name = "azure_identity", .module = identity_mod },
            },
        }),
    });
    const run_kv_secrets_tests = b.addRunArtifact(kv_secrets_tests);

    const tables_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/azure/data/tables/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
                .{ .name = "azure_identity", .module = identity_mod },
            },
        }),
    });
    const run_tables_tests = b.addRunArtifact(tables_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_identity_tests.step);
    test_step.dependOn(&run_storage_common_tests.step);
    test_step.dependOn(&run_kv_secrets_tests.step);
    test_step.dependOn(&run_tables_tests.step);

    // -- Example executable --

    const example = b.addExecutable(.{
        .name = "azure_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/examples/hello.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
                .{ .name = "azure_identity", .module = identity_mod },
            },
        }),
    });

    b.installArtifact(example);

    const run_example = b.addRunArtifact(example);
    run_example.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_example.addArgs(args);
    }

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_example.step);
}
