# Kusto examples and live tests

This standalone project exercises the consolidated
[`azure_sdk_kusto`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/kusto)
package.

- [Data query and management scenarios](data/README.md)
- [Ingest and status scenarios](ingest/README.md)
- [Pre-split historical source](legacy/README.md)

Compile and test the project:

```bash
zig build test --summary all
zig build examples
zig build live-test
```

Run one family or every scenario:

```bash
zig build run-example -- data default-query
zig build run-example -- data progressive
zig build run-example -- ingest streaming
zig build run-example -- ingest status
zig build run-example -- all
```

The reset publishes this project on `example/kusto`. The example branch pins
immutable Core and Kusto package commits; these Main-side paths exist only
while the history-preserving candidates are prepared.

<!-- Temporary Phase 5 example-branch pull-request verification. -->
