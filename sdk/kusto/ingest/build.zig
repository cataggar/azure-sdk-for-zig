const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const common_dep = b.dependency("azure_sdk_kusto_common", .{
        .target = target,
        .optimize = optimize,
    });
    const common_mod = common_dep.module("azure_sdk_kusto_common");

    const data_dep = b.dependency("azure_sdk_kusto_data", .{
        .target = target,
        .optimize = optimize,
    });
    const data_mod = data_dep.module("azure_sdk_kusto_data");

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

    common_mod.addImport("azure_sdk_core", core_mod);
    common_mod.addImport("serde", serde_mod);
    data_mod.addImport("azure_sdk_core", core_mod);
    data_mod.addImport("azure_sdk_kusto_common", common_mod);
    data_mod.addImport("serde", serde_mod);
    storage_common_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    blobs_mod.addImport("serde", serde_mod);
    queues_mod.addImport("azure_sdk_core", core_mod);
    queues_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    queues_mod.addImport("serde", serde_mod);

    const imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "azure_sdk_kusto_common", .module = common_mod },
        .{ .name = "azure_sdk_kusto_data", .module = data_mod },
        .{ .name = "azure_sdk_storage_common", .module = storage_common_mod },
        .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
        .{ .name = "azure_sdk_storage_queues", .module = queues_mod },
        .{ .name = "serde", .module = serde_mod },
    };
    const ingest_mod = b.addModule("azure_sdk_kusto_ingest", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &imports,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const test_step = b.step("test", "Run Kusto Ingest tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const example_imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "azure_sdk_kusto_common", .module = common_mod },
        .{ .name = "azure_sdk_kusto_ingest", .module = ingest_mod },
    };
    const example = b.addExecutable(.{
        .name = "kusto-ingest-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &example_imports,
        }),
    });
    const examples_step = b.step("examples", "Compile Kusto Ingest examples");
    examples_step.dependOn(&example.step);
    test_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    const run_example_step = b.step("run-example", "Run a Kusto Ingest example");
    run_example_step.dependOn(&run_example.step);

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/live_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &example_imports,
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run opt-in Kusto Ingest live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
