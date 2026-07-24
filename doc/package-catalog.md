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
| `azure_rest_arm_avs` | Branch | — | [`rest/arm_avs`](https://github.com/cataggar/azure-sdk-for-zig/tree/rest/arm_avs) | `azure_sdk_core` |
| `azure_rest_keyvault_secrets` | Branch | — | [`rest/keyvault_secrets`](https://github.com/cataggar/azure-sdk-for-zig/tree/rest/keyvault_secrets) | `azure_sdk_core` |
| `azure_rest_container_registry` | Branch | — | [`rest/container_registry`](https://github.com/cataggar/azure-sdk-for-zig/tree/rest/container_registry) | `azure_sdk_core` |
| `azure_sdk_container_registry` | Branch | — | [`sdk/container_registry`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/container_registry) | `azure_sdk_core`, `azure_rest_container_registry` |
| `azure_sdk_storage_common` | Branch | — | [`sdk/storage_common`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/storage_common) | `azure_sdk_core` |
| `azure_sdk_storage_blobs` | Branch | — | [`sdk/storage_blobs`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/storage_blobs) | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_queues` | Branch | — | [`sdk/storage_queues`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/storage_queues) | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_files_shares` | Branch | — | [`sdk/storage_files_shares`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/storage_files_shares) | `azure_sdk_core`, `azure_sdk_storage_common` |
| `azure_sdk_storage_files_datalake` | Branch | — | [`sdk/storage_files_datalake`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/storage_files_datalake) | `azure_sdk_core`, `azure_sdk_storage_common`, `azure_sdk_storage_blobs` |
| `azure_sdk_keyvault` | Branch | — | [`sdk/keyvault`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/keyvault) | `azure_sdk_core` |
| `azure_sdk_data_tables` | Branch | — | [`sdk/data_tables`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/data_tables) | `azure_sdk_core` |
| `azure_sdk_data_cosmos` | Branch | — | [`sdk/data_cosmos`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/data_cosmos) | `azure_sdk_core` |
| `azure_sdk_data_appconfiguration` | Branch | — | [`sdk/data_appconfiguration`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/data_appconfiguration) | `azure_sdk_core` |
| `azure_sdk_attestation` | Branch | — | [`sdk/attestation`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/attestation) | `azure_sdk_core` |
| `azure_sdk_messaging_common` | Branch | — | [`sdk/messaging_common`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/messaging_common) | `azure_sdk_core` |
| `azure_sdk_eventhubs` | Branch | — | [`sdk/eventhubs`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/eventhubs) | `azure_sdk_core`, `azure_sdk_messaging_common`, `azure_sdk_storage_blobs` |
| `azure_sdk_servicebus` | Branch | — | [`sdk/servicebus`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/servicebus) | `azure_sdk_core`, `azure_sdk_messaging_common` |
| `azure_sdk_kusto` | Branch | — | [`sdk/kusto`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/kusto) | `azure_sdk_core`, `azure_sdk_storage_common`, `azure_sdk_storage_blobs`, `azure_sdk_storage_queues` |

`azure_sdk_kusto` also pins the external `serde` dependency.
