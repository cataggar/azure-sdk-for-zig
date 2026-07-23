# Container Registry package releases

Container Registry now uses the registry-driven release engine. Release the
generated REST package before the handwritten SDK package:

```bash
scripts/package-release.sh verify azure_rest_container_registry
scripts/package-release.sh prepare azure_rest_container_registry
scripts/package-release.sh publish azure_rest_container_registry --dry-run
scripts/package-release.sh publish azure_rest_container_registry

scripts/package-release.sh verify azure_sdk_container_registry
scripts/package-release.sh prepare azure_sdk_container_registry
scripts/package-release.sh publish azure_sdk_container_registry --dry-run
scripts/package-release.sh publish azure_sdk_container_registry
```

The SDK preparation resolves the current `rest/container_registry` branch tip,
computes its Zig package hash, and rewrites the local REST and Core dependencies
to immutable Git commit/hash pins. Inspect
`.release/packages/azure_sdk_container_registry/stage-manifest.json` before
publication.

`scripts/container-registry-release.sh` remains as a compatibility wrapper for
the old `prepare-rest`, `prepare-sdk`, `publish-rest`, and `publish-sdk`
commands. Fixed Container Registry pin metadata is obsolete; all identities,
paths, commands, and direct dependencies come from `eng/packages.zig`.

See [Releasing packages](../../doc/releasing-packages.md) for stage sealing,
validation, version, remote, and cleanup behavior.
