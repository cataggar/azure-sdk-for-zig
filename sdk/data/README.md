# Azure Data packages

| Package | Clients |
| --- | --- |
| [`azure_sdk_data_tables`](tables/README.md) | `TableClient`, `TableServiceClient` |
| [`azure_sdk_data_cosmos`](cosmos/README.md) | `CosmosClient`, `DatabaseClient`, `ContainerClient` |
| [`azure_sdk_data_appconfiguration`](appconfiguration/README.md) | `ConfigurationClient` |

Each package starts at `0.1.0` and is released independently.

## Development

Each Data package builds independently from its package directory:

```bash
cd sdk/data/tables && zig build test --summary all
cd ../cosmos && zig build test --summary all
cd ../appconfiguration && zig build test --summary all
```
