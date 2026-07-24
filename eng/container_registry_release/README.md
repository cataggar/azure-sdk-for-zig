# Container Registry package releases

Both Container Registry packages are branch-owned. Release the generated REST
package before the handwritten SDK package:

```bash
scripts/package-branch-release.sh verify azure_rest_container_registry
scripts/package-branch-release.sh publish azure_rest_container_registry
scripts/package-branch-release.sh publish azure_rest_container_registry --execute

scripts/package-branch-release.sh verify azure_sdk_container_registry
scripts/package-branch-release.sh publish azure_sdk_container_registry
scripts/package-branch-release.sh publish azure_sdk_container_registry --execute
```

Merge and tag the REST change first, then update the SDK package branch to pin
that exact REST release commit and Zig package hash. Release tooling validates
the immutable pin but does not rewrite the SDK branch.

`scripts/container-registry-release.sh` remains as a compatibility wrapper for
`verify`, `publish-rest`, and `publish-sdk`. The old prepare commands now fail
because branch-owned releases tag an already reviewed branch tip.

See [Releasing packages](../../doc/releasing-packages.md) for branch
validation, version, dependency, and tag behavior.
