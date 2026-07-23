const std = @import("std");

const azure_sdk_core_tracing = @import("azure_sdk_core_tracing");
const azure_sdk_core_perf = @import("azure_sdk_core_perf");
const azure_sdk_core_amqp = @import("azure_sdk_core_amqp");
const azure_sdk_core = @import("azure_sdk_core");
const azure_sdk_core_testing = @import("azure_sdk_core_testing");
const azure_rest_arm_avs = @import("azure_rest_arm_avs");
const azure_rest_keyvault_secrets = @import("azure_rest_keyvault_secrets");
const azure_rest_container_registry = @import("azure_rest_container_registry");
const azure_sdk_container_registry = @import("azure_sdk_container_registry");
const azure_sdk_storage_common = @import("azure_sdk_storage_common");
const azure_sdk_storage_blobs = @import("azure_sdk_storage_blobs");
const azure_sdk_storage_queues = @import("azure_sdk_storage_queues");
const azure_sdk_storage_files_shares = @import("azure_sdk_storage_files_shares");
const azure_sdk_storage_files_datalake = @import("azure_sdk_storage_files_datalake");
const azure_sdk_keyvault = @import("azure_sdk_keyvault");
const azure_sdk_data_tables = @import("azure_sdk_data_tables");
const azure_sdk_data_cosmos = @import("azure_sdk_data_cosmos");
const azure_sdk_data_appconfiguration = @import("azure_sdk_data_appconfiguration");
const azure_sdk_attestation = @import("azure_sdk_attestation");
const azure_sdk_messaging_common = @import("azure_sdk_messaging_common");
const azure_sdk_eventhubs = @import("azure_sdk_eventhubs");
const azure_sdk_servicebus = @import("azure_sdk_servicebus");
const azure_sdk_kusto_common = @import("azure_sdk_kusto_common");
const azure_sdk_kusto_data = @import("azure_sdk_kusto_data");
const azure_sdk_kusto_ingest = @import("azure_sdk_kusto_ingest");

test "aggregate exports every canonical module" {
    _ = azure_sdk_core_tracing;
    _ = azure_sdk_core_perf;
    _ = azure_sdk_core_amqp;
    _ = azure_sdk_core;
    _ = azure_sdk_core_testing;
    _ = azure_rest_arm_avs;
    _ = azure_rest_keyvault_secrets;
    _ = azure_rest_container_registry;
    _ = azure_sdk_container_registry;
    _ = azure_sdk_storage_common;
    _ = azure_sdk_storage_blobs;
    _ = azure_sdk_storage_queues;
    _ = azure_sdk_storage_files_shares;
    _ = azure_sdk_storage_files_datalake;
    _ = azure_sdk_keyvault;
    _ = azure_sdk_data_tables;
    _ = azure_sdk_data_cosmos;
    _ = azure_sdk_data_appconfiguration;
    _ = azure_sdk_attestation;
    _ = azure_sdk_messaging_common;
    _ = azure_sdk_eventhubs;
    _ = azure_sdk_servicebus;
    _ = azure_sdk_kusto_common;
    _ = azure_sdk_kusto_data;
    _ = azure_sdk_kusto_ingest;

    try std.testing.expectEqualStrings("0.1.0", azure_sdk_core.version);
    try std.testing.expect(@sizeOf(azure_sdk_kusto_ingest.StreamingIngestTarget) > 0);
}
