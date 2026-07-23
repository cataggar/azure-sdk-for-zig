# Development

## Requirements

- Zig 0.16.0 or later
- No C runtime dependencies are required by the SDK

## Workspace commands

```bash
zig build
zig build test --summary all
zig build run
zig fmt sdk/ rest/ examples/ codegen/ eng/ build.zig
zig fmt --check sdk/ rest/ examples/ codegen/ eng/ build.zig
```

The root package is the non-published `azure_sdk_workspace`. It orchestrates
the registry-ordered package suite and consumes public modules through direct
package dependencies.

## Package metadata

`eng/packages.zig` is the authoritative catalog for package names, source
roots, dependency order, release branches, versions, tests, examples, and
regeneration commands.

```bash
zig build package-check
zig build package-list
zig build package-graph
zig build package-ci-matrix
zig build package-sync
zig build docs-check
zig build regeneration-check
zig build release-self-test
```

`package-check` validates the catalog, root package index, package build and
test metadata, documentation, license copies, and manifests.
`package-sync` synchronizes package license copies and the name/version fields
of independently buildable local manifests.

## Package-local development

Every package listed by `zig build package-list` can be tested from its own
directory:

```bash
cd rest/container_registry
zig build test --summary all
```

The workspace uses relative path dependencies until release staging replaces
them with immutable Git commits and Zig package hashes.

## Live tests

Live tests are explicit and skip successfully when their required environment
is absent. See the owning package documentation before enabling them:

- [Container Registry](../sdk/container_registry/README.md)
- [Kusto examples and live tests](../examples/kusto/README.md)
