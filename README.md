# Azure Tables REST for Zig

`azure_rest_data_tables` is the generated Azure Tables protocol package for
the stable **2019-02-02** TypeSpec contract. It is entirely
generator-owned; update the fixture or emitter and regenerate instead of
editing package files by hand.

## Protocol surface

The package exposes `TablesClient`, `Table`, and `Service`, covering all
14 canonical operations, JSON and XML wire models, enum values, response
headers, exact alternate statuses, and continuation headers. It preserves
the TypeSpec's OData entity records and literal-query routes.

The source contract is
[`specification/cosmos-db/data-plane/Tables/tspconfig.yaml`](https://github.com/Azure/azure-rest-api-specs/tree/0744f52a86919d243ba2225e55bdb9c87bf521a5/specification/cosmos-db/data-plane/Tables).
The directory is historical; this package has no Cosmos-specific runtime
behavior. The selected TypeSpec has no `$batch` operation.

## Build and regeneration

```bash
zig build test --summary all
```

The manifest pins `azure_sdk_core` by immutable release commit and Zig
package hash. The `.azure-sdk-generator` provenance file records the
generator revision and reproducible generation command.
