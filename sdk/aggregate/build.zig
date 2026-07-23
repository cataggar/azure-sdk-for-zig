const std = @import("std");

const Modules = struct {
    azure_sdk_core_tracing: *std.Build.Module,
    azure_sdk_core_perf: *std.Build.Module,
    azure_sdk_core_amqp: *std.Build.Module,
    azure_sdk_core: *std.Build.Module,
    azure_sdk_core_testing: *std.Build.Module,
    azure_rest_arm_avs: *std.Build.Module,
    azure_rest_keyvault_secrets: *std.Build.Module,
    azure_rest_container_registry: *std.Build.Module,
    azure_sdk_container_registry: *std.Build.Module,
    azure_sdk_storage_common: *std.Build.Module,
    azure_sdk_storage_blobs: *std.Build.Module,
    azure_sdk_storage_queues: *std.Build.Module,
    azure_sdk_storage_files_shares: *std.Build.Module,
    azure_sdk_storage_files_datalake: *std.Build.Module,
    azure_sdk_keyvault: *std.Build.Module,
    azure_sdk_data_tables: *std.Build.Module,
    azure_sdk_data_cosmos: *std.Build.Module,
    azure_sdk_data_appconfiguration: *std.Build.Module,
    azure_sdk_attestation: *std.Build.Module,
    azure_sdk_messaging_common: *std.Build.Module,
    azure_sdk_eventhubs: *std.Build.Module,
    azure_sdk_servicebus: *std.Build.Module,
    azure_sdk_kusto_common: *std.Build.Module,
    azure_sdk_kusto_data: *std.Build.Module,
    azure_sdk_kusto_ingest: *std.Build.Module,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const modules = loadModules(b, target, optimize);

    exportDependencyModule(b, "azure_sdk_core_tracing", modules.azure_sdk_core_tracing);
    exportDependencyModule(b, "azure_sdk_core_perf", modules.azure_sdk_core_perf);
    exportDependencyModule(b, "azure_sdk_core_amqp", modules.azure_sdk_core_amqp);
    exportDependencyModule(b, "azure_sdk_core", modules.azure_sdk_core);
    exportDependencyModule(b, "azure_sdk_core_testing", modules.azure_sdk_core_testing);
    exportDependencyModule(b, "azure_rest_arm_avs", modules.azure_rest_arm_avs);
    exportDependencyModule(b, "azure_rest_keyvault_secrets", modules.azure_rest_keyvault_secrets);
    exportDependencyModule(b, "azure_rest_container_registry", modules.azure_rest_container_registry);
    exportDependencyModule(b, "azure_sdk_container_registry", modules.azure_sdk_container_registry);
    exportDependencyModule(b, "azure_sdk_storage_common", modules.azure_sdk_storage_common);
    exportDependencyModule(b, "azure_sdk_storage_blobs", modules.azure_sdk_storage_blobs);
    exportDependencyModule(b, "azure_sdk_storage_queues", modules.azure_sdk_storage_queues);
    exportDependencyModule(b, "azure_sdk_storage_files_shares", modules.azure_sdk_storage_files_shares);
    exportDependencyModule(b, "azure_sdk_storage_files_datalake", modules.azure_sdk_storage_files_datalake);
    exportDependencyModule(b, "azure_sdk_keyvault", modules.azure_sdk_keyvault);
    exportDependencyModule(b, "azure_sdk_data_tables", modules.azure_sdk_data_tables);
    exportDependencyModule(b, "azure_sdk_data_cosmos", modules.azure_sdk_data_cosmos);
    exportDependencyModule(b, "azure_sdk_data_appconfiguration", modules.azure_sdk_data_appconfiguration);
    exportDependencyModule(b, "azure_sdk_attestation", modules.azure_sdk_attestation);
    exportDependencyModule(b, "azure_sdk_messaging_common", modules.azure_sdk_messaging_common);
    exportDependencyModule(b, "azure_sdk_eventhubs", modules.azure_sdk_eventhubs);
    exportDependencyModule(b, "azure_sdk_servicebus", modules.azure_sdk_servicebus);
    exportDependencyModule(b, "azure_sdk_kusto_common", modules.azure_sdk_kusto_common);
    exportDependencyModule(b, "azure_sdk_kusto_data", modules.azure_sdk_kusto_data);
    exportDependencyModule(b, "azure_sdk_kusto_ingest", modules.azure_sdk_kusto_ingest);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/all_modules.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &moduleImports(modules),
        }),
    });
    const test_step = b.step("test", "Compile every canonical aggregate module");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}

fn loadModules(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) Modules {
    const core_tracing_mod = b.dependency("azure_sdk_core_tracing", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_core_tracing");
    const core_perf_mod = b.dependency("azure_sdk_core_perf", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_core_perf");
    const core_amqp_mod = b.dependency("azure_sdk_core_amqp", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_core_amqp");
    const core_mod = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_core");
    const core_testing_mod = b.dependency("azure_sdk_core_testing", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_core_testing");

    const uamqp_dep = b.dependency("uamqp", .{});
    const uamqp_mod = b.createModule(.{
        .root_source_file = uamqp_dep.path("src/zig/uamqp.zig"),
        .target = target,
    });
    const serde_mod = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    }).module("serde");

    core_amqp_mod.addImport("uamqp", uamqp_mod);
    core_mod.addImport("azure_sdk_core_tracing", core_tracing_mod);
    core_mod.addImport("serde", serde_mod);
    core_testing_mod.addImport("azure_sdk_core", core_mod);

    const arm_avs_mod = b.dependency("azure_rest_arm_avs", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_rest_arm_avs");
    arm_avs_mod.addImport("azure_sdk_core", core_mod);
    arm_avs_mod.addImport("serde", serde_mod);

    const keyvault_secrets_mod = b.dependency("azure_rest_keyvault_secrets", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_rest_keyvault_secrets");
    keyvault_secrets_mod.addImport("azure_sdk_core", core_mod);
    keyvault_secrets_mod.addImport("serde", serde_mod);

    const container_registry_protocol_mod =
        b.dependency("azure_rest_container_registry", .{
            .target = target,
            .optimize = optimize,
        }).module("azure_rest_container_registry");
    container_registry_protocol_mod.addImport("azure_sdk_core", core_mod);
    container_registry_protocol_mod.addImport("serde", serde_mod);

    const container_registry_sdk_mod =
        b.dependency("azure_sdk_container_registry", .{
            .target = target,
            .optimize = optimize,
        }).module("azure_sdk_container_registry");
    container_registry_sdk_mod.addImport("azure_sdk_core", core_mod);
    container_registry_sdk_mod.addImport(
        "azure_rest_container_registry",
        container_registry_protocol_mod,
    );

    const storage_common_mod = b.dependency("azure_sdk_storage_common", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_storage_common");
    storage_common_mod.addImport("azure_sdk_core", core_mod);

    const storage_blobs_mod = b.dependency("azure_sdk_storage_blobs", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_storage_blobs");
    storage_blobs_mod.addImport("azure_sdk_core", core_mod);
    storage_blobs_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    storage_blobs_mod.addImport("serde", serde_mod);

    const storage_queues_mod = b.dependency("azure_sdk_storage_queues", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_storage_queues");
    storage_queues_mod.addImport("azure_sdk_core", core_mod);
    storage_queues_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    storage_queues_mod.addImport("serde", serde_mod);

    const storage_files_shares_mod =
        b.dependency("azure_sdk_storage_files_shares", .{
            .target = target,
            .optimize = optimize,
        }).module("azure_sdk_storage_files_shares");
    storage_files_shares_mod.addImport("azure_sdk_core", core_mod);

    const storage_files_datalake_mod =
        b.dependency("azure_sdk_storage_files_datalake", .{
            .target = target,
            .optimize = optimize,
        }).module("azure_sdk_storage_files_datalake");
    storage_files_datalake_mod.addImport("azure_sdk_core", core_mod);

    const keyvault_mod = b.dependency("azure_sdk_keyvault", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_keyvault");
    keyvault_mod.addImport("azure_sdk_core", core_mod);
    keyvault_mod.addImport("serde", serde_mod);

    const data_tables_mod = b.dependency("azure_sdk_data_tables", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_data_tables");
    data_tables_mod.addImport("azure_sdk_core", core_mod);

    const data_cosmos_mod = b.dependency("azure_sdk_data_cosmos", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_data_cosmos");
    data_cosmos_mod.addImport("azure_sdk_core", core_mod);
    data_cosmos_mod.addImport("serde", serde_mod);

    const data_appconfiguration_mod =
        b.dependency("azure_sdk_data_appconfiguration", .{
            .target = target,
            .optimize = optimize,
        }).module("azure_sdk_data_appconfiguration");
    data_appconfiguration_mod.addImport("azure_sdk_core", core_mod);
    data_appconfiguration_mod.addImport("serde", serde_mod);

    const attestation_mod = b.dependency("azure_sdk_attestation", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_attestation");
    attestation_mod.addImport("azure_sdk_core", core_mod);
    attestation_mod.addImport("serde", serde_mod);

    const messaging_common_mod = b.dependency("azure_sdk_messaging_common", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_messaging_common");

    const eventhubs_mod = b.dependency("azure_sdk_eventhubs", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_eventhubs");
    eventhubs_mod.addImport("azure_sdk_core", core_mod);
    eventhubs_mod.addImport("azure_sdk_messaging_common", messaging_common_mod);
    eventhubs_mod.addImport("azure_sdk_storage_blobs", storage_blobs_mod);
    eventhubs_mod.addImport("uamqp", uamqp_mod);
    eventhubs_mod.addImport("serde", serde_mod);

    const servicebus_mod = b.dependency("azure_sdk_servicebus", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_servicebus");
    servicebus_mod.addImport("azure_sdk_core", core_mod);
    servicebus_mod.addImport("azure_sdk_messaging_common", messaging_common_mod);
    servicebus_mod.addImport("uamqp", uamqp_mod);
    servicebus_mod.addImport("serde", serde_mod);

    const kusto_common_mod = b.dependency("azure_sdk_kusto_common", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_kusto_common");
    kusto_common_mod.addImport("azure_sdk_core", core_mod);
    kusto_common_mod.addImport("serde", serde_mod);

    const kusto_data_mod = b.dependency("azure_sdk_kusto_data", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_kusto_data");
    kusto_data_mod.addImport("azure_sdk_core", core_mod);
    kusto_data_mod.addImport("azure_sdk_kusto_common", kusto_common_mod);
    kusto_data_mod.addImport("serde", serde_mod);

    const kusto_ingest_mod = b.dependency("azure_sdk_kusto_ingest", .{
        .target = target,
        .optimize = optimize,
    }).module("azure_sdk_kusto_ingest");
    kusto_ingest_mod.addImport("azure_sdk_core", core_mod);
    kusto_ingest_mod.addImport("azure_sdk_kusto_common", kusto_common_mod);
    kusto_ingest_mod.addImport("azure_sdk_kusto_data", kusto_data_mod);
    kusto_ingest_mod.addImport("azure_sdk_storage_common", storage_common_mod);
    kusto_ingest_mod.addImport("azure_sdk_storage_blobs", storage_blobs_mod);
    kusto_ingest_mod.addImport("azure_sdk_storage_queues", storage_queues_mod);
    kusto_ingest_mod.addImport("serde", serde_mod);

    return .{
        .azure_sdk_core_tracing = core_tracing_mod,
        .azure_sdk_core_perf = core_perf_mod,
        .azure_sdk_core_amqp = core_amqp_mod,
        .azure_sdk_core = core_mod,
        .azure_sdk_core_testing = core_testing_mod,
        .azure_rest_arm_avs = arm_avs_mod,
        .azure_rest_keyvault_secrets = keyvault_secrets_mod,
        .azure_rest_container_registry = container_registry_protocol_mod,
        .azure_sdk_container_registry = container_registry_sdk_mod,
        .azure_sdk_storage_common = storage_common_mod,
        .azure_sdk_storage_blobs = storage_blobs_mod,
        .azure_sdk_storage_queues = storage_queues_mod,
        .azure_sdk_storage_files_shares = storage_files_shares_mod,
        .azure_sdk_storage_files_datalake = storage_files_datalake_mod,
        .azure_sdk_keyvault = keyvault_mod,
        .azure_sdk_data_tables = data_tables_mod,
        .azure_sdk_data_cosmos = data_cosmos_mod,
        .azure_sdk_data_appconfiguration = data_appconfiguration_mod,
        .azure_sdk_attestation = attestation_mod,
        .azure_sdk_messaging_common = messaging_common_mod,
        .azure_sdk_eventhubs = eventhubs_mod,
        .azure_sdk_servicebus = servicebus_mod,
        .azure_sdk_kusto_common = kusto_common_mod,
        .azure_sdk_kusto_data = kusto_data_mod,
        .azure_sdk_kusto_ingest = kusto_ingest_mod,
    };
}

fn moduleImports(modules: Modules) [25]std.Build.Module.Import {
    return .{
        .{ .name = "azure_sdk_core_tracing", .module = modules.azure_sdk_core_tracing },
        .{ .name = "azure_sdk_core_perf", .module = modules.azure_sdk_core_perf },
        .{ .name = "azure_sdk_core_amqp", .module = modules.azure_sdk_core_amqp },
        .{ .name = "azure_sdk_core", .module = modules.azure_sdk_core },
        .{ .name = "azure_sdk_core_testing", .module = modules.azure_sdk_core_testing },
        .{ .name = "azure_rest_arm_avs", .module = modules.azure_rest_arm_avs },
        .{ .name = "azure_rest_keyvault_secrets", .module = modules.azure_rest_keyvault_secrets },
        .{ .name = "azure_rest_container_registry", .module = modules.azure_rest_container_registry },
        .{ .name = "azure_sdk_container_registry", .module = modules.azure_sdk_container_registry },
        .{ .name = "azure_sdk_storage_common", .module = modules.azure_sdk_storage_common },
        .{ .name = "azure_sdk_storage_blobs", .module = modules.azure_sdk_storage_blobs },
        .{ .name = "azure_sdk_storage_queues", .module = modules.azure_sdk_storage_queues },
        .{ .name = "azure_sdk_storage_files_shares", .module = modules.azure_sdk_storage_files_shares },
        .{ .name = "azure_sdk_storage_files_datalake", .module = modules.azure_sdk_storage_files_datalake },
        .{ .name = "azure_sdk_keyvault", .module = modules.azure_sdk_keyvault },
        .{ .name = "azure_sdk_data_tables", .module = modules.azure_sdk_data_tables },
        .{ .name = "azure_sdk_data_cosmos", .module = modules.azure_sdk_data_cosmos },
        .{ .name = "azure_sdk_data_appconfiguration", .module = modules.azure_sdk_data_appconfiguration },
        .{ .name = "azure_sdk_attestation", .module = modules.azure_sdk_attestation },
        .{ .name = "azure_sdk_messaging_common", .module = modules.azure_sdk_messaging_common },
        .{ .name = "azure_sdk_eventhubs", .module = modules.azure_sdk_eventhubs },
        .{ .name = "azure_sdk_servicebus", .module = modules.azure_sdk_servicebus },
        .{ .name = "azure_sdk_kusto_common", .module = modules.azure_sdk_kusto_common },
        .{ .name = "azure_sdk_kusto_data", .module = modules.azure_sdk_kusto_data },
        .{ .name = "azure_sdk_kusto_ingest", .module = modules.azure_sdk_kusto_ingest },
    };
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
