# Package catalog

`eng/packages.zig` is the authoritative machine-readable catalog. All
canonical packages start at `0.1.0`; package-scoped release tags use
`<package>/v<version>`.

`package` means a package-local build exists today. `monolithic` means the
module is still built from the integration workspace and will be extracted in
dependency order.

| Package | Source documentation | Branch | State |
| --- | --- | --- | --- |
| `azure_sdk_core_tracing` | [Core Tracing](../sdk/core/tracing/README.md) | `sdk/core_tracing` | monolithic |
| `azure_sdk_core_perf` | [Core Performance](../sdk/core/perf/README.md) | `sdk/core_perf` | monolithic |
| `azure_sdk_core_amqp` | [Core AMQP](../sdk/core/amqp/README.md) | `sdk/core_amqp` | monolithic |
| `azure_sdk_core` | [Core](../sdk/core/README.md) | `sdk/core` | monolithic |
| `azure_sdk_core_testing` | [Core Testing](../sdk/core/testing/README.md) | `sdk/core_testing` | monolithic |
| `azure_rest_arm_avs` | [ARM AVS REST](../rest/arm_avs/README.md) | `rest/arm_avs` | monolithic |
| `azure_rest_keyvault_secrets` | [Key Vault Secrets REST](../rest/keyvault_secrets/README.md) | `rest/keyvault_secrets` | monolithic |
| `azure_rest_container_registry` | [Container Registry REST](../rest/container_registry/README.md) | `rest/container_registry` | package |
| `azure_sdk_container_registry` | [Container Registry SDK](../sdk/container_registry/README.md) | `sdk/container_registry` | package |
| `azure_sdk_storage_common` | [Storage Common](../sdk/storage/common/README.md) | `sdk/storage_common` | monolithic |
| `azure_sdk_storage_blobs` | [Storage Blobs](../sdk/storage/blobs/README.md) | `sdk/storage_blobs` | monolithic |
| `azure_sdk_storage_queues` | [Storage Queues](../sdk/storage/queues/README.md) | `sdk/storage_queues` | monolithic |
| `azure_sdk_storage_files_shares` | [Files Shares](../sdk/storage/files/shares/README.md) | `sdk/storage_files_shares` | monolithic |
| `azure_sdk_storage_files_datalake` | [Data Lake](../sdk/storage/files/datalake/README.md) | `sdk/storage_files_datalake` | monolithic |
| `azure_sdk_keyvault` | [Key Vault](../sdk/keyvault/README.md) | `sdk/keyvault` | monolithic |
| `azure_sdk_data_tables` | [Data Tables](../sdk/data/tables/README.md) | `sdk/data_tables` | monolithic |
| `azure_sdk_data_cosmos` | [Cosmos](../sdk/data/cosmos/README.md) | `sdk/data_cosmos` | monolithic |
| `azure_sdk_data_appconfiguration` | [App Configuration](../sdk/data/appconfiguration/README.md) | `sdk/data_appconfiguration` | monolithic |
| `azure_sdk_attestation` | [Attestation](../sdk/attestation/README.md) | `sdk/attestation` | monolithic |
| `azure_sdk_messaging_common` | [Messaging Common](../sdk/messaging/common/README.md) | `sdk/messaging_common` | monolithic |
| `azure_sdk_eventhubs` | [Event Hubs](../sdk/messaging/eventhubs/README.md) | `sdk/eventhubs` | monolithic |
| `azure_sdk_servicebus` | [Service Bus](../sdk/messaging/servicebus/README.md) | `sdk/servicebus` | monolithic |
| `azure_sdk_kusto_common` | [Kusto Common](../sdk/kusto/common/README.md) | `sdk/kusto_common` | monolithic |
| `azure_sdk_kusto_data` | [Kusto Data](../sdk/kusto/data/README.md) | `sdk/kusto_data` | monolithic |
| `azure_sdk_kusto_ingest` | [Kusto Ingest](../sdk/kusto/ingest/README.md) | `sdk/kusto_ingest` | monolithic |
| `azure_sdk` | [Aggregate](../sdk/aggregate/README.md) | `sdk/aggregate` | monolithic |
