# Container Registry release staging

`metadata.sh` records the immutable common `azure_sdk` commit and Zig package
hash used by both independently published ACR packages. The commit is
`origin/main` immediately after PR #100, which contains the complete shared
core required by the REST and hand-written packages.

The release is intentionally two-stage:

1. `scripts/container-registry-release.sh prepare-rest` regenerates
   `.release/container_registry/publish/rest` with the common SDK pin and tests
   it independently.
2. Publish that directory to `rest/container_registry`.
3. `scripts/container-registry-release.sh prepare-sdk <rest-commit>` fetches
   the published REST commit, computes its Zig package hash, writes both
   immutable pins into `.release/container_registry/publish/sdk`, and tests
   the SDK, examples, and unconfigured live-test skip.
4. Publish the SDK directory to `sdk/container_registry`.

No REST hash is guessed before the REST orphan commit exists. `verify` (also
available as `dry-run`) uses the same generated REST package and a sibling path
dependency for the SDK, exactly mirroring the two package roots without
creating branches or tags.

See `doc/package-branch-model.md` for exact publication commands.
