# Examples

Examples are owned by the package or package family they demonstrate. They use
environment variables rather than embedded endpoints or credentials and avoid
printing authorization headers, service-issued SAS URIs, or payloads.

- [Kusto examples and live tests](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto)
- [Container Registry examples](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/container_registry#examples)
- [ARM AVS generated examples](https://github.com/cataggar/azure-sdk-for-zig/tree/example/arm_avs)

The current workspace example commands are documented in
[`doc/development.md`](../doc/development.md).

The package reset moved the staged Kusto project to the standalone
[`example/kusto`](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto)
branch. That branch owns its project history and consumes the
`azure_sdk_kusto` module's `common`, `data`, and `ingest` namespaces; it has no
release tag.
