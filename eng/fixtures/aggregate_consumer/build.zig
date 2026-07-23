const std = @import("std");

const canonical_module_names = [_][]const u8{
    "azure_sdk_core_tracing",
    "azure_sdk_core_perf",
    "azure_sdk_core_amqp",
    "azure_sdk_core",
    "azure_sdk_core_testing",
    "azure_rest_arm_avs",
    "azure_rest_keyvault_secrets",
    "azure_rest_container_registry",
    "azure_sdk_container_registry",
    "azure_sdk_storage_common",
    "azure_sdk_storage_blobs",
    "azure_sdk_storage_queues",
    "azure_sdk_storage_files_shares",
    "azure_sdk_storage_files_datalake",
    "azure_sdk_keyvault",
    "azure_sdk_data_tables",
    "azure_sdk_data_cosmos",
    "azure_sdk_data_appconfiguration",
    "azure_sdk_attestation",
    "azure_sdk_messaging_common",
    "azure_sdk_eventhubs",
    "azure_sdk_servicebus",
    "azure_sdk_kusto_common",
    "azure_sdk_kusto_data",
    "azure_sdk_kusto_ingest",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const aggregate = b.dependency("azure_sdk", .{
        .target = target,
        .optimize = optimize,
    });

    var imports: [canonical_module_names.len]std.Build.Module.Import = undefined;
    for (canonical_module_names, 0..) |name, index| {
        imports[index] = .{
            .name = name,
            .module = aggregate.module(name),
        };
    }

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/all_modules.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const test_step = b.step("test", "Compile an aggregate-only consumer");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
