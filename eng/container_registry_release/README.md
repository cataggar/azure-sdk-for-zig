# Container Registry release staging

`metadata.sh` records the immutable common `azure_sdk` commit and Zig package
hash used by both independently published ACR packages. The commit is
`origin/main` immediately after PR #100, which contains the complete shared
core required by the REST and hand-written packages.

The release is intentionally two-stage:

1. `scripts/container-registry-release.sh prepare-rest` regenerates
   `.release/container_registry/publish/rest` with the common SDK pin and tests
   a disposable copy independently.
2. `scripts/container-registry-release.sh publish-rest --dry-run` validates the
   prospective commit; rerun without `--dry-run` to publish it to
   `rest/container_registry`.
3. `scripts/container-registry-release.sh prepare-sdk <rest-commit>` fetches
   the current remote REST branch tip, requires exact commit equality, validates
   the archived package root/name/dependencies, computes its Zig package hash,
   writes both immutable pins into `.release/container_registry/publish/sdk`,
   and tests a disposable copy, examples, and unconfigured live-test skip.
4. Use `publish-sdk --dry-run`, then `publish-sdk`, for
   `sdk/container_registry`.

Staging copies only tracked files explicitly declared by each package's
`build.zig.zon`; generation and tests use external disposable caches. Stage
validation rejects undeclared files, `.zig-cache`, `zig-pkg`, `zig-out`, and
other publication artifacts. Publication is fail-fast and trap-cleaned:
missing branches get one initial orphan commit, while existing branches get
normal descendant commits and fast-forward pushes. Force-push is never used;
forced removal is limited to trap cleanup of the disposable worktree.

No REST hash is guessed before the REST release commit exists. `verify` (also
available as `dry-run`) mirrors both package roots without creating remote refs.
`self-test` exercises invalid main/mismatched REST commits plus initial and
subsequent publication dry-runs against an isolated local bare remote.

See `doc/package-branch-model.md` for the complete workflow.
