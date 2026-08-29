# azure_sdk_data_cosmos

Azure Cosmos DB clients:

- `CosmosClient`
- `DatabaseClient`
- `ContainerClient`

Release branch: `sdk/data_cosmos`. The package depends on
`azure_sdk_core` and `serde`. Version `0.2.0` uses Core's canonical
`HttpRuntime`.

Construct `CosmosClient` with an allocator, borrowed token credential, and
`core.http.HttpRuntime`, then call `deinit`. Database and container clients
borrow the parent client's heap-stable pipeline state and must not outlive it.
The runtime's transport and crypto backend contexts are also borrowed.

## Development

```bash
zig build test --summary all
```
