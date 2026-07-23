# Azure SDK for Zig

> **Experimental and unofficial.** This AI-assisted project is not an official
> Microsoft or Azure SDK.

Azure service clients implemented in pure Zig without C dependencies.

## Packages

| Package | Documentation |
| --- | --- |
| [`azure_sdk_core_tracing`](sdk/core/tracing/README.md) | Core tracing |
| [`azure_sdk_core_perf`](sdk/core/perf/README.md) | Core performance helpers |
| [`azure_sdk_core_amqp`](sdk/core/amqp/README.md) | AMQP core integration |
| [`azure_sdk_core`](sdk/core/README.md) | HTTP pipeline, identity, and shared primitives |
| [`azure_sdk_core_testing`](sdk/core/testing/README.md) | Core test support |
| [`azure_rest_arm_avs`](rest/arm_avs/README.md) | ARM AVS generated protocol |
| [`azure_rest_keyvault_secrets`](rest/keyvault_secrets/README.md) | Key Vault Secrets generated protocol |
| [`azure_rest_container_registry`](rest/container_registry/README.md) | Container Registry generated protocol |
| [`azure_sdk_container_registry`](sdk/container_registry/README.md) | Container Registry client |
| [`azure_sdk_storage_common`](sdk/storage/common/README.md) | Storage shared primitives |
| [`azure_sdk_storage_blobs`](sdk/storage/blobs/README.md) | Blob Storage |
| [`azure_sdk_storage_queues`](sdk/storage/queues/README.md) | Queue Storage |
| [`azure_sdk_storage_files_shares`](sdk/storage/files/shares/README.md) | Azure Files shares |
| [`azure_sdk_storage_files_datalake`](sdk/storage/files/datalake/README.md) | Data Lake Storage |
| [`azure_sdk_keyvault`](sdk/keyvault/README.md) | Key Vault secrets, keys, certificates, and administration |
| [`azure_sdk_data_tables`](sdk/data/tables/README.md) | Tables |
| [`azure_sdk_data_cosmos`](sdk/data/cosmos/README.md) | Cosmos DB |
| [`azure_sdk_data_appconfiguration`](sdk/data/appconfiguration/README.md) | App Configuration |
| [`azure_sdk_attestation`](sdk/attestation/README.md) | Attestation |
| [`azure_sdk_messaging_common`](sdk/messaging/common/README.md) | Messaging shared primitives |
| [`azure_sdk_eventhubs`](sdk/messaging/eventhubs/README.md) | Event Hubs and Blob checkpoint store |
| [`azure_sdk_servicebus`](sdk/messaging/servicebus/README.md) | Service Bus |
| [`azure_sdk_kusto_common`](sdk/kusto/common/README.md) | Kusto shared primitives |
| [`azure_sdk_kusto_data`](sdk/kusto/data/README.md) | Kusto queries and management |
| [`azure_sdk_kusto_ingest`](sdk/kusto/ingest/README.md) | Kusto ingestion |

See the [package catalog](doc/package-catalog.md) for versions, release
branches, and the complete dependency graph.

## Documentation

- [Documentation index](doc/README.md)
- [Development](doc/development.md)
- [Package and branch model](doc/package-branch-model.md)
- [Package release workflow](doc/releasing-packages.md)
- [Migration to independent packages](doc/migrating-to-independent-packages.md)
- [TypeSpec code generation](codegen/README.md)
- [Examples](examples/README.md)
- Package families: [Core and Identity](sdk/core/README.md),
  [Storage](sdk/storage/README.md), [Key Vault](sdk/keyvault/README.md),
  [Data](sdk/data/README.md), [Messaging](sdk/messaging/README.md), and
  [Kusto](sdk/kusto/README.md)

## License

Licensed under the [MIT License](LICENSE.txt).
