# Examples

Examples are owned by the package or package family they demonstrate. They use
environment variables rather than embedded endpoints or credentials and avoid
printing authorization headers, service-issued SAS URIs, or payloads.

- [Kusto examples and live tests](kusto/README.md), currently staged on
  `main` for history filtering
- [Container Registry examples](../sdk/container_registry/README.md#examples)
- [ARM AVS generated examples](../rest/arm_avs/examples/README.md)

The current workspace example commands are documented in
[`doc/development.md`](../doc/development.md).

At the package reset cutover, the staged Kusto project moves to the standalone
[`example/kusto`](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto)
branch. That branch owns its project history and consumes the
`azure_sdk_kusto` module's `common`, `data`, and `ingest` namespaces; it has no
release tag.
