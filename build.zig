const std = @import("std");
const package_registry = @import("eng/packages.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -- Dependencies --

    const core_tracing_dep = b.dependency("azure_sdk_core_tracing", .{
        .target = target,
        .optimize = optimize,
    });
    const core_tracing_mod = core_tracing_dep.module("azure_sdk_core_tracing");

    const core_perf_dep = b.dependency("azure_sdk_core_perf", .{
        .target = target,
        .optimize = optimize,
    });
    const core_perf_mod = core_perf_dep.module("azure_sdk_core_perf");

    const core_amqp_dep = b.dependency("azure_sdk_core_amqp", .{
        .target = target,
        .optimize = optimize,
    });
    const core_amqp_mod = core_amqp_dep.module("azure_sdk_core_amqp");

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const core_testing_dep = b.dependency("azure_sdk_core_testing", .{
        .target = target,
        .optimize = optimize,
    });
    const core_testing_mod = core_testing_dep.module("azure_sdk_core_testing");

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

    const arm_avs_dep = b.dependency("azure_rest_arm_avs", .{
        .target = target,
        .optimize = optimize,
    });
    const arm_avs_mod = arm_avs_dep.module("azure_rest_arm_avs");
    arm_avs_mod.addImport("azure_sdk_core", core_mod);
    arm_avs_mod.addImport("serde", serde_mod);

    const keyvault_secrets_dep = b.dependency("azure_rest_keyvault_secrets", .{
        .target = target,
        .optimize = optimize,
    });
    const keyvault_secrets_mod = keyvault_secrets_dep.module("azure_rest_keyvault_secrets");
    keyvault_secrets_mod.addImport("azure_sdk_core", core_mod);
    keyvault_secrets_mod.addImport("serde", serde_mod);

    const container_registry_protocol_dep = b.dependency("azure_rest_container_registry", .{
        .target = target,
        .optimize = optimize,
    });
    const container_registry_protocol_mod =
        container_registry_protocol_dep.module("azure_rest_container_registry");
    container_registry_protocol_mod.addImport("azure_sdk_core", core_mod);
    container_registry_protocol_mod.addImport("serde", serde_mod);

    const container_registry_sdk_dep = b.dependency("azure_sdk_container_registry", .{
        .target = target,
        .optimize = optimize,
    });
    const container_registry_sdk_mod =
        container_registry_sdk_dep.module("azure_sdk_container_registry");
    // Keep the SDK and generated protocol package on the workspace-owned
    // Core module so the dependency diamond has one source owner.
    container_registry_sdk_mod.addImport("azure_sdk_core", core_mod);
    container_registry_sdk_mod.addImport(
        "azure_rest_container_registry",
        container_registry_protocol_mod,
    );

    const storage_common_dep = b.dependency("azure_sdk_storage_common", .{
        .target = target,
        .optimize = optimize,
    });
    const storage_common_mod = storage_common_dep.module("azure_sdk_storage_common");
    storage_common_mod.addImport("azure_sdk_core", core_mod);

    const storage_blobs_dep = b.dependency("azure_sdk_storage_blobs", .{
        .target = target,
        .optimize = optimize,
    });
    const blobs_mod = storage_blobs_dep.module("azure_sdk_storage_blobs");
    blobs_mod.addImport("azure_sdk_core", core_mod);
    blobs_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    blobs_mod.addImport("serde", serde_mod);

    const storage_queues_dep = b.dependency("azure_sdk_storage_queues", .{
        .target = target,
        .optimize = optimize,
    });
    const queues_mod = storage_queues_dep.module("azure_sdk_storage_queues");
    queues_mod.addImport("azure_sdk_core", core_mod);
    queues_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    queues_mod.addImport("serde", serde_mod);

    const storage_files_shares_dep = b.dependency("azure_sdk_storage_files_shares", .{
        .target = target,
        .optimize = optimize,
    });
    const storage_files_shares_mod =
        storage_files_shares_dep.module("azure_sdk_storage_files_shares");
    storage_files_shares_mod.addImport("azure_sdk_core", core_mod);

    const storage_files_datalake_dep = b.dependency("azure_sdk_storage_files_datalake", .{
        .target = target,
        .optimize = optimize,
    });
    const storage_files_datalake_mod =
        storage_files_datalake_dep.module("azure_sdk_storage_files_datalake");
    storage_files_datalake_mod.addImport("azure_sdk_core", core_mod);

    // -- Modules (libraries exposed to consumers) --

    exportDependencyModule(b, "azure_sdk_core_tracing", core_tracing_mod);
    exportDependencyModule(b, "azure_sdk_core_perf", core_perf_mod);
    exportDependencyModule(b, "azure_sdk_core_amqp", core_amqp_mod);
    exportDependencyModule(b, "azure_sdk_core", core_mod);
    exportDependencyModule(b, "azure_sdk_core_testing", core_testing_mod);
    exportDependencyModule(b, "azure_rest_arm_avs", arm_avs_mod);
    exportDependencyModule(b, "azure_rest_keyvault_secrets", keyvault_secrets_mod);
    exportDependencyModule(b, "azure_rest_container_registry", container_registry_protocol_mod);
    exportDependencyModule(b, "azure_sdk_container_registry", container_registry_sdk_mod);
    exportDependencyModule(b, "azure_sdk_storage_common", storage_common_mod);
    exportDependencyModule(b, "azure_sdk_storage_blobs", blobs_mod);
    exportDependencyModule(b, "azure_sdk_storage_queues", queues_mod);
    exportDependencyModule(b, "azure_sdk_storage_files_shares", storage_files_shares_mod);
    exportDependencyModule(b, "azure_sdk_storage_files_datalake", storage_files_datalake_mod);

    _ = b.addModule("azure_sdk_keyvault", .{
        .root_source_file = b.path("sdk/keyvault/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_sdk_data_tables", .{
        .root_source_file = b.path("sdk/data/tables/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
        },
    });

    _ = b.addModule("azure_sdk_data_cosmos", .{
        .root_source_file = b.path("sdk/data/cosmos/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_sdk_data_appconfiguration", .{
        .root_source_file = b.path("sdk/data/appconfiguration/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_sdk_attestation", .{
        .root_source_file = b.path("sdk/attestation/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const kusto_common_mod = b.addModule("azure_sdk_kusto_common", .{
        .root_source_file = b.path("sdk/kusto/common.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const kusto_data_mod = b.addModule("azure_sdk_kusto_data", .{
        .root_source_file = b.path("sdk/kusto/data/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const kusto_ingest_mod = b.addModule("azure_sdk_kusto_ingest", .{
        .root_source_file = b.path("sdk/kusto/ingest/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
            .{ .name = "azure_sdk_kusto_data", .module = kusto_data_mod },
            .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
            .{ .name = "azure_sdk_storage_common", .module = storage_common_mod },
            .{ .name = "azure_sdk_storage_queues", .module = queues_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const messaging_common_mod = b.addModule("azure_sdk_messaging_common", .{
        .root_source_file = b.path("sdk/messaging/common.zig"),
        .target = target,
    });

    _ = b.addModule("azure_sdk_eventhubs", .{
        .root_source_file = b.path("sdk/messaging/eventhubs/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "uamqp", .module = uamqp_mod },
            .{ .name = "azure_sdk_messaging_common", .module = messaging_common_mod },
            .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_sdk_servicebus", .{
        .root_source_file = b.path("sdk/messaging/servicebus/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "uamqp", .module = uamqp_mod },
            .{ .name = "azure_sdk_messaging_common", .module = messaging_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    // -- Tests --

    const storage_common_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/storage/common/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const run_storage_common_tests = b.addRunArtifact(storage_common_tests);

    const keyvault_secrets_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/keyvault/secrets/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const run_keyvault_secrets_tests = b.addRunArtifact(keyvault_secrets_tests);

    const tables_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/data/tables/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
            },
        }),
    });
    const run_tables_tests = b.addRunArtifact(tables_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_storage_common_tests.step);
    test_step.dependOn(&run_keyvault_secrets_tests.step);
    test_step.dependOn(&run_tables_tests.step);

    const package_tool_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("eng/package_tool_test.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(package_tool_tests).step);

    const package_tool = b.addExecutable(.{
        .name = "package-tool",
        .root_module = b.createModule(.{
            .root_source_file = b.path("eng/package_tool.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
    const package_check_run = b.addRunArtifact(package_tool);
    package_check_run.addArg("check");
    package_check_run.setCwd(b.path("."));
    test_step.dependOn(&package_check_run.step);
    const package_check_step = b.step(
        "package-check",
        "Validate package metadata, documentation, licenses, and manifests",
    );
    package_check_step.dependOn(&package_check_run.step);

    const package_list_run = b.addRunArtifact(package_tool);
    package_list_run.addArg("list");
    package_list_run.setCwd(b.path("."));
    const package_list_step = b.step("package-list", "List packages in release order");
    package_list_step.dependOn(&package_list_run.step);

    const package_graph_run = b.addRunArtifact(package_tool);
    package_graph_run.addArg("graph");
    package_graph_run.setCwd(b.path("."));
    const package_graph_step = b.step("package-graph", "Print the package dependency graph");
    package_graph_step.dependOn(&package_graph_run.step);

    const package_matrix_run = b.addRunArtifact(package_tool);
    package_matrix_run.addArg("ci-matrix");
    package_matrix_run.setCwd(b.path("."));
    const package_matrix_step = b.step(
        "package-ci-matrix",
        "Print the independently buildable package CI matrix",
    );
    package_matrix_step.dependOn(&package_matrix_run.step);

    const package_sync_run = b.addRunArtifact(package_tool);
    package_sync_run.addArg("sync-local");
    package_sync_run.setCwd(b.path("."));
    package_sync_run.has_side_effects = true;
    const package_sync_step = b.step(
        "package-sync",
        "Synchronize package licenses and local manifest identities",
    );
    package_sync_step.dependOn(&package_sync_run.step);

    const aggregate_export_fixture = b.dependency("aggregate_export_fixture", .{
        .target = target,
        .optimize = optimize,
    });
    const aggregate_export_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("eng/fixtures/aggregate_export_consumer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "fixture_module",
                    .module = aggregate_export_fixture.module("fixture_module"),
                },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(aggregate_export_tests).step);

    for (package_registry.all) |package| {
        if (package.state != .package) continue;
        const package_tests = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "test",
            "--summary",
            "all",
        });
        package_tests.setCwd(b.path(package.source_path));
        test_step.dependOn(&package_tests.step);
    }

    // Service SDK tests — core + identity deps
    const service_test_sources_ci = [_][]const u8{
        "sdk/keyvault/root.zig",
        "sdk/keyvault/keys/root.zig",
        "sdk/keyvault/certificates/root.zig",
        "sdk/keyvault/administration/root.zig",
        "sdk/data/appconfiguration/root.zig",
        "sdk/data/cosmos/root.zig",
        "sdk/attestation/root.zig",
    };
    for (service_test_sources_ci) |src| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_storage_common", .module = storage_common_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // EventHubs tests — needs core + identity + uamqp + messaging_common
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/messaging/eventhubs/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "uamqp", .module = uamqp_mod },
                    .{ .name = "azure_sdk_messaging_common", .module = messaging_common_mod },
                    .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // EventHubs checkpoint store tests — needs core + blobs
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/messaging/eventhubs/checkpoint_store.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Messaging common tests — no deps
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/messaging/common.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Service Bus tests — needs core + identity + uamqp + messaging_common
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/messaging/servicebus/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "uamqp", .module = uamqp_mod },
                    .{ .name = "azure_sdk_messaging_common", .module = messaging_common_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Kusto error tests — needs core + serde
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/kusto/error.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Kusto common tests — needs core + identity
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/kusto/common.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Kusto data tests — needs core + identity + kusto_common
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/kusto/data/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Kusto ingest tests — needs core + Kusto + complete-SAS storage clients
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/kusto/ingest/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
                    .{ .name = "azure_sdk_kusto_data", .module = kusto_data_mod },
                    .{ .name = "azure_sdk_storage_blobs", .module = blobs_mod },
                    .{ .name = "azure_sdk_storage_common", .module = storage_common_mod },
                    .{ .name = "azure_sdk_storage_queues", .module = queues_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // -- Example executable --

    const example = b.addExecutable(.{
        .name = "azure_example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/hello.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
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

    const kusto_example = b.addExecutable(.{
        .name = "azure_kusto_examples",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/kusto/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
                .{ .name = "azure_sdk_kusto_data", .module = kusto_data_mod },
                .{ .name = "azure_sdk_kusto_ingest", .module = kusto_ingest_mod },
            },
        }),
    });
    b.installArtifact(kusto_example);

    const run_kusto_example = b.addRunArtifact(kusto_example);
    run_kusto_example.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_kusto_example.addArgs(args);
    const run_kusto_step = b.step(
        "run-kusto-examples",
        "Run an opt-in Kusto example",
    );
    run_kusto_step.dependOn(&run_kusto_example.step);

    const kusto_live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/kusto/live_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_kusto_common", .module = kusto_common_mod },
                .{ .name = "azure_sdk_kusto_data", .module = kusto_data_mod },
                .{ .name = "azure_sdk_kusto_ingest", .module = kusto_ingest_mod },
            },
        }),
    });
    const run_kusto_live_tests = b.addRunArtifact(kusto_live_tests);
    const kusto_live_test_step = b.step(
        "kusto-live-test",
        "Run opt-in Kusto live tests; unconfigured tests skip",
    );
    kusto_live_test_step.dependOn(&run_kusto_live_tests.step);

    const acr_example_support_mod = b.createModule(.{
        .root_source_file = b.path("sdk/container_registry/examples/support.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{
                .name = "azure_sdk_container_registry",
                .module = container_registry_sdk_mod,
            },
        },
    });
    const acr_examples_step = b.step(
        "container-registry-examples",
        "Compile all Container Registry examples",
    );
    const acr_example_sources = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{
            .name = "acr-list-repositories-tags",
            .source = "sdk/container_registry/examples/list_repositories_tags.zig",
        },
        .{
            .name = "acr-anonymous-read",
            .source = "sdk/container_registry/examples/anonymous_read.zig",
        },
        .{
            .name = "acr-oci-push-pull",
            .source = "sdk/container_registry/examples/oci_push_pull.zig",
        },
        .{
            .name = "acr-delete-artifact",
            .source = "sdk/container_registry/examples/delete_artifact.zig",
        },
    };
    for (acr_example_sources) |acr_example| {
        const executable = b.addExecutable(.{
            .name = acr_example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(acr_example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{
                        .name = "azure_sdk_container_registry",
                        .module = container_registry_sdk_mod,
                    },
                    .{
                        .name = "acr_example_support",
                        .module = acr_example_support_mod,
                    },
                },
            }),
        });
        acr_examples_step.dependOn(&executable.step);
        test_step.dependOn(&executable.step);
    }

    const acr_live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/container_registry/live_tests/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{
                    .name = "azure_sdk_container_registry",
                    .module = container_registry_sdk_mod,
                },
            },
        }),
    });
    const acr_live_test_step = b.step(
        "container-registry-live-test",
        "Run destructive opt-in Container Registry live tests; unconfigured tests skip",
    );
    acr_live_test_step.dependOn(&b.addRunArtifact(acr_live_tests).step);

    // -- tspconfigs tool --
    //
    // Builds and exposes two steps that manage `codegen/tspconfigs.yaml`:
    //   * tspconfigs-update  — reconcile entries against ../azure-rest-api-specs
    //   * tspconfigs-resolve — fill in name/branch/zig_import from each tspconfig.yaml
    const tspconfigs_exe = b.addExecutable(.{
        .name = "tspconfigs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("codegen/tspconfigs/main.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const tspconfigs_update_run = b.addRunArtifact(tspconfigs_exe);
    tspconfigs_update_run.addArg("update");
    tspconfigs_update_run.setCwd(b.path("."));
    tspconfigs_update_run.has_side_effects = true;
    const tspconfigs_update_step = b.step(
        "tspconfigs-update",
        "Reconcile codegen/tspconfigs.yaml against ../azure-rest-api-specs",
    );
    tspconfigs_update_step.dependOn(&tspconfigs_update_run.step);

    const tspconfigs_resolve_run = b.addRunArtifact(tspconfigs_exe);
    tspconfigs_resolve_run.addArg("resolve");
    tspconfigs_resolve_run.setCwd(b.path("."));
    tspconfigs_resolve_run.has_side_effects = true;
    const tspconfigs_resolve_step = b.step(
        "tspconfigs-resolve",
        "Fill in name/branch/zig_import by parsing each tspconfig.yaml",
    );
    tspconfigs_resolve_step.dependOn(&tspconfigs_resolve_run.step);
}

fn exportDependencyModule(
    b: *std.Build,
    name: []const u8,
    module: *std.Build.Module,
) void {
    b.modules.put(
        b.graph.arena,
        b.dupe(name),
        module,
    ) catch @panic("OOM");
}
