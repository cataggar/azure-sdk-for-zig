const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -- Dependencies --

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

    // -- Modules (libraries exposed to consumers) --

    const core_mod = b.addModule("azure_core", .{
        .root_source_file = b.path("sdk/core/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const storage_common_mod = b.addModule("azure_storage_common", .{
        .root_source_file = b.path("sdk/storage/common/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const blobs_mod = b.addModule("azure_storage_blobs", .{
        .root_source_file = b.path("sdk/storage/blobs/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_storage_common", .module = storage_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_keyvault_secrets", .{
        .root_source_file = b.path("sdk/keyvault/secrets/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_data_tables", .{
        .root_source_file = b.path("sdk/data/tables/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
        },
    });

    _ = b.addModule("azure_data_cosmos", .{
        .root_source_file = b.path("sdk/data/cosmos/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_keyvault_keys", .{
        .root_source_file = b.path("sdk/keyvault/keys/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_keyvault_certificates", .{
        .root_source_file = b.path("sdk/keyvault/certificates/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_keyvault_admin", .{
        .root_source_file = b.path("sdk/keyvault/administration/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_storage_queues", .{
        .root_source_file = b.path("sdk/storage/queues/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_storage_common", .module = storage_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_storage_files_shares", .{
        .root_source_file = b.path("sdk/storage/files/shares/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_storage_files_datalake", .{
        .root_source_file = b.path("sdk/storage/files/datalake/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_data_appconfiguration", .{
        .root_source_file = b.path("sdk/data/appconfiguration/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_attestation", .{
        .root_source_file = b.path("sdk/attestation/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const kusto_common_mod = b.addModule("azure_kusto_common", .{
        .root_source_file = b.path("sdk/kusto/common.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_kusto_data", .{
        .root_source_file = b.path("sdk/kusto/data/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_kusto_common", .module = kusto_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_kusto_ingest", .{
        .root_source_file = b.path("sdk/kusto/ingest/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_kusto_common", .module = kusto_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_core_amqp", .{
        .root_source_file = b.path("sdk/core/amqp/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "uamqp", .module = uamqp_mod },
        },
    });

    const messaging_common_mod = b.addModule("azure_messaging_common", .{
        .root_source_file = b.path("sdk/messaging/common.zig"),
        .target = target,
    });

    const eventhubs_mod = b.addModule("azure_messaging_eventhubs", .{
        .root_source_file = b.path("sdk/messaging/eventhubs/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "uamqp", .module = uamqp_mod },
            .{ .name = "azure_messaging_common", .module = messaging_common_mod },
        },
    });

    _ = b.addModule("azure_messaging_eventhubs_checkpointstore_blob", .{
        .root_source_file = b.path("sdk/messaging/eventhubs/checkpoint_store.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "azure_storage_blobs", .module = blobs_mod },
            .{ .name = "azure_messaging_eventhubs", .module = eventhubs_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_messaging_servicebus", .{
        .root_source_file = b.path("sdk/messaging/servicebus/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
            .{ .name = "uamqp", .module = uamqp_mod },
            .{ .name = "azure_messaging_common", .module = messaging_common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    _ = b.addModule("azure_core_tracing", .{
        .root_source_file = b.path("sdk/core/tracing/root.zig"),
        .target = target,
    });

    _ = b.addModule("azure_core_testing", .{
        .root_source_file = b.path("sdk/core/testing/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_core", .module = core_mod },
        },
    });

    _ = b.addModule("azure_core_perf", .{
        .root_source_file = b.path("sdk/core/perf/root.zig"),
        .target = target,
    });

    // -- Tests --

    const core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/core/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });

    const run_core_tests = b.addRunArtifact(core_tests);

    const storage_common_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/storage/common/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const run_storage_common_tests = b.addRunArtifact(storage_common_tests);

    const kv_secrets_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/keyvault/secrets/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const run_kv_secrets_tests = b.addRunArtifact(kv_secrets_tests);

    const tables_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("sdk/data/tables/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_core", .module = core_mod },
            },
        }),
    });
    const run_tables_tests = b.addRunArtifact(tables_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_core_tests.step);
    test_step.dependOn(&run_storage_common_tests.step);
    test_step.dependOn(&run_kv_secrets_tests.step);
    test_step.dependOn(&run_tables_tests.step);

    // Service SDK tests — core + identity deps
    const service_test_sources_ci = [_][]const u8{
        "sdk/keyvault/keys/root.zig",
        "sdk/keyvault/certificates/root.zig",
        "sdk/keyvault/administration/root.zig",
        "sdk/storage/blobs/root.zig",
        "sdk/storage/queues/root.zig",
        "sdk/storage/files/shares/root.zig",
        "sdk/storage/files/datalake/root.zig",
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
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "azure_storage_common", .module = storage_common_mod },
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
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "uamqp", .module = uamqp_mod },
                    .{ .name = "azure_messaging_common", .module = messaging_common_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // EventHubs checkpoint store tests — needs core + identity + blobs + eventhubs
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/messaging/eventhubs/checkpoint_store.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "azure_storage_blobs", .module = blobs_mod },
                    .{ .name = "azure_messaging_eventhubs", .module = eventhubs_mod },
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
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "uamqp", .module = uamqp_mod },
                    .{ .name = "azure_messaging_common", .module = messaging_common_mod },
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
                    .{ .name = "azure_core", .module = core_mod },
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
                    .{ .name = "azure_core", .module = core_mod },
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
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "azure_kusto_common", .module = kusto_common_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Kusto ingest tests — needs core + kusto_common
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/kusto/ingest/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_core", .module = core_mod },
                    .{ .name = "azure_kusto_common", .module = kusto_common_mod },
                    .{ .name = "serde", .module = serde_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Core infrastructure tests — no deps
    const core_infra_sources = [_][]const u8{
        "sdk/core/tracing/root.zig",
        "sdk/core/perf/root.zig",
    };
    for (core_infra_sources) |src| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(src),
                .target = target,
                .optimize = optimize,
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // AMQP tests — needs uamqp dep
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/core/amqp/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "uamqp", .module = uamqp_mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // Testing framework tests — needs azure_core
    {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("sdk/core/testing/root.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_core", .module = core_mod },
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
                .{ .name = "azure_core", .module = core_mod },
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
