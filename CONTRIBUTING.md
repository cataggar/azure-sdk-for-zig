# Contributing

Thanks for contributing to the Azure SDK for Zig.

## Choose the correct base branch

- Core-family changes target `main`.
- Non-Core SDK and REST changes target the package branch listed in
  [`doc/package-catalog.md`](doc/package-catalog.md).
- Generated package changes also target their package branch.

Do not add branch-owned package source back to `main`.

## Validation

For Main-owned changes:

```bash
zig build test --summary all
zig build package-check --summary all
zig build package-history-check --summary all
```

For package-branch changes:

```bash
zig fmt --check .
zig build test --summary all
```

The package branch must report:

```text
package-test (ubuntu-latest)
package-test (windows-latest)
package-test (macos-latest)
```

## Package metadata

Update `eng/packages.zig` on `main` for catalog metadata. Main-owned packages
must have a `workspace_path`; branch-owned packages must not. Historical paths
belong in `historical_source_path` and `eng/package_history_map.zig`.

Branch-owned manifests use immutable URL/hash pins for every internal
dependency. Core workspace manifests use local paths only to other Main-owned
Core packages.

## Pull requests

Keep changes focused, include tests for behavior changes, and preserve public
API compatibility unless the change explicitly justifies a break.
