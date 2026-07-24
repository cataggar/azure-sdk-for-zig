# Package Catalog

`eng/packages.zig` is authoritative. Main paths are listed only for
Main-owned packages; branch-owned source lives at the root of the named branch.

| Package | Ownership | Main path | Package branch | Internal dependencies |
| --- | --- | --- | --- | --- |
| `azure_sdk_core_tracing` | Main | [`sdk/core/tracing`](../sdk/core/tracing) | `sdk/core_tracing` | — |
| `azure_sdk_core_perf` | Main | [`sdk/core/perf`](../sdk/core/perf) | `sdk/core_perf` | `azure_sdk_core_tracing` |
| `azure_sdk_core_amqp` | Main | [`sdk/core/amqp`](../sdk/core/amqp) | `sdk/core_amqp` | `azure_sdk_core_tracing` |
| `azure_sdk_core` | Main | [`sdk/core`](../sdk/core) | `sdk/core` | `azure_sdk_core_tracing` |
| `azure_sdk_core_testing` | Main | [`sdk/core/testing`](../sdk/core/testing) | `sdk/core_testing` | `azure_sdk_core`, `azure_sdk_core_tracing` |
| `azure_rest_arm_avs` | Branch | — | `rest/arm_avs` | `azure_sdk_core` |
| `azure_rest_keyvault_secrets` | Branch | — | `rest/keyvault_secrets` | `azure_sdk_core` |
| `azure_rest_container_registry` | Branch | — | `rest/container_registry` | `azure_sdk_core` |
| `azure_sdk_container_registry` | Branch | — | `sdk/container_registry` | `azure_sdk_core`, `azure_rest_container_registry` |
| `azure_sdk_storage_common` | Branch | — | `sdk/storage_common` | `azure_sdk_core` |
| `azure_sdk_storage_blobs` | Branch | — | `sdk/storage_blobs` | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_queues` | Branch | — | `sdk/storage_queues` | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_files_shares` | Branch | — | `sdk/storage_files_shares` | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_files_datalake` | Branch | — | `sdk/storage_files_datalake` | `azure_sdk_core`, `azure_sdk_storage_common`, `azure_sdk_storage_blobs` |
| `azure_sdk_keyvault` | Branch | — | `sdk/keyvault` | `azure_sdk_core` |
| `azure_sdk_data_tables` | Branch | — | `sdk/data_tables` | `azure_sdk_core` |
| `azure_sdk_data_cosmos` | Branch | — | `sdk/data_cosmos` | `azure_sdk_core` |
| `azure_sdk_data_appconfiguration` | Branch | — | `sdk/data_appconfiguration` | `azure_sdk_core` |
| `azure_sdk_attestation` | Branch | — | `sdk/attestation` | `azure_sdk_core` |
| `azure_sdk_messaging_common` | Branch | — | `sdk/messaging_common` | `azure_sdk_core` |
| `azure_sdk_eventhubs` | Branch | — | `sdk/eventhubs` | `azure_sdk_core`, `azure_sdk_messaging_common`, `azure_sdk_storage_blobs` |
| `azure_sdk_servicebus` | Branch | — | `sdk/servicebus` | `azure_sdk_core`, `azure_sdk_messaging_common` |
| `azure_sdk_kusto` | Branch | — | `sdk/kusto` | `azure_sdk_core`, `azure_sdk_storage_common`, `azure_sdk_storage_blobs`, `azure_sdk_storage_queues` |

`azure_sdk_kusto` also pins the external `serde` dependency.
