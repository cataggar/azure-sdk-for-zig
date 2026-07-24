const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const storage_common_dep = b.dependency("azure_sdk_storage_common", .{
        .target = target,
        .optimize = optimize,
    });
    const storage_common_mod =
        storage_common_dep.module("azure_sdk_storage_common");

    const blobs_dep = b.dependency("azure_sdk_storage_blobs", .{
        .target = target,
        .optimize = optimize,
    });
    const blobs_mod = blobs_dep.module("azure_sdk_storage_blobs");

    const queues_dep = b.dependency("azure_sdk_storage_queues", .{
        .target = target,
        .optimize = optimize,
    });
    const queues_mod = queues_dep.module("azure_sdk_storage_queues");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    storage_common_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    blobs_mod.addImport("serde", serde_mod);
    queues_mod.addImport("azure_sdk_core", core_mod);
    queues_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    queues_mod.addImport("serde", serde_mod);

    const common_imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "serde", .module = serde_mod },
    };
    const common_mod = b.createModule(.{
        .root_source_file = b.path("common/root.zig"),
        .target = target,
        .imports = &common_imports,
    });

    const data_imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "kusto_common_internal", .module = common_mod },
        .{ .name = "serde", .module = serde_mod },
    };
    const data_mod = b.createModule(.{
        .root_source_file = b.path("data/root.zig"),
        .target = target,
        .imports = &data_imports,
    });

    const ingest_imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "kusto_common_internal", .module = common_mod },
        .{ .name = "kusto_data_internal", .module = data_mod },
        .{ .name = "azure_sdk_storage_common", .module = storage_common_mod },
        .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
        .{ .name = "azure_sdk_storage_queues", .module = queues_mod },
        .{ .name = "serde", .module = serde_mod },
    };
    const ingest_mod = b.createModule(.{
        .root_source_file = b.path("ingest/root.zig"),
        .target = target,
        .imports = &ingest_imports,
    });

    const facade_imports = [_]std.Build.Module.Import{
        .{ .name = "kusto_common_internal", .module = common_mod },
        .{ .name = "kusto_data_internal", .module = data_mod },
        .{ .name = "kusto_ingest_internal", .module = ingest_mod },
    };
    _ = b.addModule("azure_sdk_kusto", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &facade_imports,
    });

    const test_step = b.step("test", "Run Kusto tests");
    const common_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("common/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &common_imports,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(common_tests).step);

    const data_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("data/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &data_imports,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(data_tests).step);

    const ingest_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("ingest/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &ingest_imports,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(ingest_tests).step);

    const facade_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &facade_imports,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(facade_tests).step);
}
