# Development

Use Zig 0.16.0 or later.

## Main-owned Core work

Core-family changes are developed normally against `main`:

```bash
zig build
zig build test --summary all
zig build package-check --summary all
zig build package-history-check --summary all
zig fmt --check sdk/core/ codegen/ eng/ build.zig
```

Root package tests intentionally run only the five Main-owned Core packages.
The catalog and history checks still cover all 23 registered package
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

## Reset history tooling

The reviewed mappings remain available for provenance:

```bash
scripts/package-history-reset.sh analyze
```

The completed cutover is recorded in
[`package-reset-2026-07-24.md`](package-reset-2026-07-24.md). Candidate
reconstruction requires the sealed pre-cleanup Main commit recorded there;
current `main` intentionally contains no branch-owned source.

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
