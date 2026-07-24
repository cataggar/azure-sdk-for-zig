# Migrating to independent packages

The package split is intentionally source breaking. Package and module names
become canonical path-derived names, and no forwarding aliases are provided.
The canonical import rename lands before package extraction.

## Module mapping

| Current module/package | Canonical package, module, or import |
| --- | --- |
| `azure_core` | `azure_sdk_core` |
| `azure_core_amqp` | `azure_sdk_core_amqp` |
| `azure_core_tracing` | `azure_sdk_core_tracing` |
| `azure_core_testing` | `azure_sdk_core_testing` |
| `azure_core_perf` | `azure_sdk_core_perf` |
| `azure_rest_container_registry` | `azure_rest_container_registry` |
| `azure_sdk_container_registry` | `azure_sdk_container_registry` |
| `arm_avs` | `azure_rest_arm_avs` |
| `keyvault_secrets` | `azure_rest_keyvault_secrets` |
| `azure_storage_common` | `azure_sdk_storage_common` |
| `azure_storage_blobs` | `azure_sdk_storage_blobs` |
| `azure_storage_queues` | `azure_sdk_storage_queues` |
| `azure_storage_files_shares` | `azure_sdk_storage_files_shares` |
| `azure_storage_files_datalake` | `azure_sdk_storage_files_datalake` |
| `azure_keyvault_secrets` | `azure_sdk_keyvault` namespace `secrets` |
| `azure_keyvault_keys` | `azure_sdk_keyvault` namespace `keys` |
| `azure_keyvault_certificates` | `azure_sdk_keyvault` namespace `certificates` |
| `azure_keyvault_admin` | `azure_sdk_keyvault` namespace `administration` |
| `azure_data_tables` | `azure_sdk_data_tables` |
| `azure_data_cosmos` | `azure_sdk_data_cosmos` |
| `azure_data_appconfiguration` | `azure_sdk_data_appconfiguration` |
| `azure_attestation` | `azure_sdk_attestation` |
| `azure_messaging_common` | `azure_sdk_messaging_common` |
| `azure_messaging_eventhubs` | `azure_sdk_eventhubs` |
| `azure_messaging_eventhubs_checkpointstore_blob` | `azure_sdk_eventhubs` namespace `checkpoint_store_blob` |
| `azure_messaging_servicebus` | `azure_sdk_servicebus` |
| `azure_kusto_common` | `@import("azure_sdk_kusto").common` |
| `azure_kusto_data` | `@import("azure_sdk_kusto").data` |
| `azure_kusto_ingest` | `@import("azure_sdk_kusto").ingest` |
| `azure_sdk_kusto_common` | `@import("azure_sdk_kusto").common` |
| `azure_sdk_kusto_data` | `@import("azure_sdk_kusto").data` |
| `azure_sdk_kusto_ingest` | `@import("azure_sdk_kusto").ingest` |

## Consumer choices

Consumers depend directly on only the canonical packages they use and import
their canonical module names.

Kusto consumers take the single `azure_sdk_kusto` package and module, then
select its `common`, `data`, or `ingest` public namespace. No forwarding
packages or import aliases are provided for the former Kusto identities.

## Dependency migration

Generated REST and handwritten SDK packages depend on
`azure_sdk_core`. Family and integration packages declare their direct internal
dependencies explicitly; see the [package catalog](package-catalog.md).
