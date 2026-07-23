# Releasing packages

Package releases follow the
[Package Branch Model](package-branch-model.md). The registry at
`eng/packages.zig` is authoritative for package names, versions, source roots,
release branches, direct dependencies, declared files, generators, tests,
examples, and live-test skip commands.

## Commands

Run every command from a clean commit checked out on the `main` branch. The
local `HEAD` must exactly equal the publication remote's fetched
`refs/heads/main`; unpushed, behind, or diverged local commits are rejected.

```bash
scripts/package-release.sh verify <package>
scripts/package-release.sh prepare <package>
scripts/package-release.sh publish <package> --dry-run
scripts/package-release.sh publish <package>
```

For a non-`origin` remote, use the same remote for preparation and publication:

```bash
PACKAGE_RELEASE_REMOTE=upstream \
  scripts/package-release.sh prepare <package>
scripts/package-release.sh publish <package> --dry-run --remote upstream
scripts/package-release.sh publish <package> --remote upstream
```

A named Git remote must resolve to exactly one fetch URL and exactly one push
URL. If it has a separate `pushurl`, both URLs must identify the same
repository. Different protocols for the same host/path are accepted; multiple
destinations or different repositories are rejected before staging. The sealed
validated URLs, not the mutable remote name, are used for release fetch, push,
and post-push verification. Embedded HTTP credentials and passwords in any
network URL are rejected; normal SSH usernames remain supported.

Effective Git `url.*.insteadOf` and `url.*.pushInsteadOf` configuration is
forbidden, including repository, global, system, and environment-injected
configuration. Git can chain and reapply these rewrites after validation, so
the engine refuses to resolve or use a publication remote while any rule is
active.

Run the complete offline regression suite with:

```bash
scripts/package-release.sh self-test
```

The self-test uses only local source repositories and bare remotes. It requires
Zig, Git, Bash, and Python 3, but no GitHub or Azure access.

The manual `Package release verification` workflow runs the same verify,
prepare, and publish dry-run sequence on hosted runners. Generated
`azure_rest_arm_avs` and `azure_rest_keyvault_secrets` releases must be
verified locally because their regeneration requires the sibling
`azure-rest-api-specs` checkout and the composed TypeSpec emitter.

## Verification and preparation

`verify` requires the named source branch `main` and checks the registry
identity, strict release SemVer, manifest
fingerprint, non-empty minimum Zig version, dependencies and `.paths`, required
README/license/build files, tracked source provenance, forbidden artifacts,
symlinks, and package commands. Package
commands run from a disposable worktree of the recorded source commit so local
path dependencies retain their workspace layout without mutating the source
checkout. Package, example, live-test, and regeneration commands receive an
isolated home/config directory and a strict environment allowlist; ambient
Azure, Kusto, service, credential, proxy, and shell configuration variables are
not inherited. When the registry declares a regeneration command, it also runs
in a disposable worktree with repository-local temporary storage and external
Zig caches, then requires byte-identical output.

On `main`, every internal dependency `.path` must resolve exactly to that
dependency's registry `source_path`. Merely naming an existing directory is not
sufficient. This workspace-only check is not applied to isolated release
stages, whose internal dependencies must instead be immutable URL/hash pins.
Manifest `.paths` entries must be actual string entries; quoted paths inside
`//` comments do not declare package content.

`prepare` repeats the source checks and creates:

```text
.release/packages/<package>/stage/
.release/packages/<package>/stage-manifest.json
```

Only the registry's declared publish paths are copied from the recorded source
commit. Every direct internal dependency is resolved from its release branch,
validated against its package-scoped tag, archived, and hashed with
`zig fetch`. Its local `.path` dependency is replaced with:

```zig
.dependency_name = .{
    .url = "git+https://example/repository#<40-character-commit>",
    .hash = "<zig-package-hash>",
},
```

External URL/hash dependency blocks are not changed. The staged package is
tested from a disposable copy; caches and build outputs never enter the stage.

The adjacent JSON seal records:

- source ref, commit, and fetched publication-remote `main` commit;
- package, version, branch, and prospective tag;
- expected current package-branch tip and previous identity/version;
- exact direct dependency branches, commits, URLs, and Zig hashes;
- publication fetch URL, push URL, and normalized repository identity;
- declared top-level paths;
- every staged file's size, mode, and SHA-256;
- a digest over the complete staged tree.

Do not edit either the stage or seal. Rerun `prepare` for any change.

## Publication

`publish --dry-run` recomputes the seal, source provenance, dependency pins and
hashes, branch tip, version history, and tags. It creates and validates the
prospective commit in a disposable worktree, prints the exact parent,
dependency pins, package hash, and tag, but changes no remote refs.

`publish` performs the same checks immediately before pushing. A missing
package branch receives an orphan root commit. Every later commit must be a
direct descendant of the fetched branch tip. Git hooks are disabled for every
hook-capable release operation, including worktree checkout/switch, commit, and
push. The resulting committed tree is compared with the sealed stage for exact
paths, modes, and bytes.

Source provenance is revalidated immediately before the push. Standard Git
cannot atomically compare an unrelated, up-to-date `main` ref during a
branch/tag push: if `main` advances after push advertisement, publication still
records and reproduces the immutable sealed source commit rather than claiming
an atomic lock on `main`.

The package branch itself has an exact `--force-with-lease`: the expected value
is the sealed branch tip, or expected-absent for an initial orphan release.
This lease and the non-force refspec protect the atomic publication of:

```text
HEAD -> refs/heads/<registry-branch>
HEAD -> refs/tags/<package>/v<version>
```

The release commit is prevalidated as a direct descendant and the branch
refspec omits force. A package-branch deletion, rewind, advance, or tag
collision fails the atomic update, so the package branch and tag cannot publish
partially. Disposable worktrees, temporary branches, caches, and test copies
are removed on success and failure.

## Rejections and version rules

The engine rejects dirty, detached, non-`main`, unpushed, behind, or diverged
source; mismatched publication fetch/push repositories;
malformed/non-monotonic/reused versions; existing or moved tags; missing or
raced branch tips; missing/malformed fingerprints or minimum Zig versions;
wrong workspace dependency paths or published dependency commits/hashes, path
dependencies in a staged release, stage or seal tampering, symlinks,
undeclared staged top-level files, caches/artifacts, and missing README,
license, or build files.

Every canonical identity starts at `0.1.0`. ARM AVS and generated Key Vault
Secrets may establish their canonical `0.1.0` releases as direct descendants
of the registry-declared legacy package identities on their existing branches.
After that transition, normal strict monotonic SemVer and canonical tags apply.

Before bootstrap publication, protect `refs/tags/*/v*` against update/deletion
and `refs/heads/rest/**` plus `refs/heads/sdk/**` against force push/deletion.
