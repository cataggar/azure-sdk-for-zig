# azure_rest_keyvault_secrets

Generated Azure REST client for Key Vault Secrets.

The canonical package/module name is `azure_rest_keyvault_secrets`, released
from `rest/keyvault_secrets` at version `0.1.0`. The current legacy manifest
name is removed during the canonical import/package rename.

This package is produced by `codegen` from the TypeSpec
specification in [`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs).
Do not edit the contents of `src/` by hand — they will be
overwritten on the next regeneration.

## Clients
- `KeyVaultClient`

## Build and regeneration

```bash
zig build test --summary all
codegen/scripts/sync.sh --force keyvault_secrets
```

See the [code generator](../../codegen/README.md) and
[package branch model](../../doc/package-branch-model.md). The canonical
package depends directly on `azure_sdk_core` and `serde`.
