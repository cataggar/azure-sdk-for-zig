# Development

Use Zig 0.16.0 or later.

## Main-owned Core work

Core-family changes are developed normally against `main`:

```bash
zig build
zig build test --summary all
zig build package-check --summary all
zig build package-history-check --summary all
zig fmt --check sdk/ examples/ codegen/ eng/ build.zig
```

Root package tests intentionally run only the five Main-owned Core packages.
The catalog and history checks still cover all 25 registered package
identities.

## Branch-owned package work

Fetch the package branch and create a feature branch from it:

```bash
git fetch origin sdk/storage_blobs
git switch --create feature/storage-retry FETCH_HEAD
zig build test --summary all
```

Open the pull request with `sdk/storage_blobs` as its base. Do not merge
branch-owned package source into `main`.

Validate the published branch from a `main` checkout with:

```bash
scripts/package-branch-release.sh verify azure_sdk_storage_blobs
```

Package manifests must pin internal dependencies by immutable URL and hash.
Workspace-local `.path` dependencies are valid only among Main-owned Core
packages.

## History reconstruction

Inspect reviewed mappings:

```bash
scripts/package-history-reset.sh analyze
```

Seal one source commit, then build and verify candidates in dependency order:

```bash
scripts/package-history-reset.sh seal-inputs \
  --reset-id package-reset-YYYY-MM-DD

PACKAGE_HISTORY_FILTER_REPO=/path/to/pinned/git-filter-repo \
  scripts/package-history-reset.sh build-candidates \
  --package azure_sdk_storage_common

scripts/package-history-reset.sh verify-candidates \
  --package azure_sdk_storage_common
```

Candidate output is written under `.release/package-reset` by default and is
not source code to commit to `main`. After every candidate is finalized and
reviewed, `publish-candidates` pushes the set atomically under
`migration/<reset-id>/...`; it does not change production package refs.

## Generated package work

TypeSpec-generated packages can target an external package worktree:

```bash
codegen/scripts/sync.sh \
  --output-root /path/to/keyvault-package \
  --azure-sdk-core-commit <commit> \
  --azure-sdk-core-hash <hash> \
  keyvault_secrets
```

Container Registry determinism can compare independent package worktrees:

```bash
scripts/verify-container-registry-regeneration.sh \
  --rest-package-root /path/to/rest-container-registry \
  --sdk-package-root /path/to/sdk-container-registry
```

## Before opening a pull request

Run the smallest relevant package test first, then the ownership-appropriate
checks above. CI enforces formatting and the three fixed package-branch check
contexts.
