# Releasing packages

Package releases follow the policy in
[Package Branch Model](package-branch-model.md). Each published package uses an
orphan branch and an immutable package-scoped tag:

```text
branch: sdk/storage_blobs
tag:    azure_sdk_storage_blobs/v0.1.0
```

## Current transition

The generic registry is checked in at `eng/packages.zig`. The generic release
driver will be introduced after package-local builds have been extracted.
Until then, Container Registry remains the reference implementation:

```bash
scripts/container-registry-release.sh verify
scripts/container-registry-release.sh self-test
```

See [Container Registry release staging](../eng/container_registry_release/README.md)
for its exact two-stage REST/SDK workflow.

## Required release invariants

A release must:

1. Start from a clean, named `main` commit.
2. Resolve every direct internal dependency to an existing release commit and
   Zig package hash.
3. Generate a sealed stage containing only the package's declared paths.
4. Test the package and its examples from a disposable copy with external
   caches.
5. Reject path dependencies, symlinks, caches, undeclared files, stale branch
   tips, reused versions, and existing tags.
6. Create an orphan root for the first release or a direct descendant of the
   current package branch tip.
7. Atomically fast-forward the branch and create
   `<package>/v<version>`, without force.

Release branches and tags are protected from force updates and deletion before
the first package bootstrap.

## Versioning

- Every canonical package starts at `0.1.0`.
- REST package versions describe generated protocol surface changes.
- SDK package versions describe public convenience API and behavior changes.
- Versions advance independently and must be strictly greater than the
  previous release of the same package identity.
- Downstream packages pin exact commits and hashes rather than floating branch
  or tag names.
