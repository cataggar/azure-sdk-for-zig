# TypeSpec → Zig Code Generator

Generate Azure SDK packages for Zig from
[TypeSpec](https://typespec.io) specifications in
[`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs).

The architecture mirrors the Rust experiment in
[`cataggar/azure-sdk-for-rust#90`](https://github.com/cataggar/azure-sdk-for-rust/issues/90)
and [PR #92](https://github.com/cataggar/azure-sdk-for-rust/pull/92): the
TypeSpec toolchain is wrapped as a **WASI component** via
[`jco`](https://github.com/bytecodealliance/jco), and the actual code
generator is a **Zig WASI component** composed with the TypeSpec
component into a single wasm executable.

```text
   .tsp files
      │
      ▼
 ┌──────────────────────────────────────────┐
 │  tcgc.wasm                               │
 │  • @typespec/compiler                    │
 │  • @azure-tools/typespec-client-         │
 │    generator-core    (TCGC)              │
 │  • @azure-tools/typespec-azure-core      │
 │  • @azure-tools/typespec-azure-resource- │
 │    manager                               │
 │  Built once with `jco componentize`      │
 └──────────────────────────────────────────┘
      │ JSON code model (WIT contract below)
      ▼
 ┌──────────────────────────────────────────┐
 │  codegen-cli.wasm (Zig, wasm32-wasi)     │
 │  • imports tcgc#compile via Component    │
 │    Model — composed with tcgc.wasm into  │
 │    codegen-cli.composed.wasm             │
 │  • parses JSON via serde.zig             │
 │  • emits Zig source, build.zig, README   │
 │  • driver script then runs `zig fmt`     │
 └──────────────────────────────────────────┘
      │
      ▼
 git push origin rest/<service>             ← orphan branch
```

## Layout

| Path                              | Purpose                                                |
| --------------------------------- | ------------------------------------------------------ |
| `tspconfigs.yaml`                 | Tracked manifest of every tspconfig.yaml under `../azure-rest-api-specs/specification/`, with resolved `js`/`zig` package names. Regenerate via `zig build tspconfigs-update` (re-walks the specs) and `zig build tspconfigs-resolve` (refills `js`/`zig`). |
| `wit/tcgc.wit`                    | WIT contract exposed by `tcgc.wasm`.                   |
| `tcgc-component/`                 | JS wrapper componentized by `jco` into `tcgc.wasm`.    |
| `cli/`                            | Zig WASI emitter — `codegen-cli.wasm`, composed with `tcgc.wasm` and driven by `cli/scripts/run.sh`. |
| `tspconfigs/`                     | Zig tool that manages `tspconfigs.yaml` (`zig build tspconfigs-update` / `-resolve`). |
| `scripts/sync.sh`                 | Resyncs a generated REST package in a monorepo path or external package worktree; overwrites only emitter-owned files by default. |
| `fixtures/`                       | Checked-in code models and deterministic package generators used by emitter tests. |

`fixtures/container_registry.json` is the checked-in wire contract for
Container Registry API `2021-07-01`. Regenerate it from the canonical
`azure-rest-api-specs` checkout with:

```bash
cd codegen/tcgc-component
AZURE_REST_API_SPECS=/path/to/azure-rest-api-specs \
  npm run fixture:container-registry
```

Regenerate the tracked, entirely generator-owned ACR protocol package
from that fixture into a checkout of its package branch:

```bash
cd codegen/cli
zig build \
  -Dcontainer-registry-output=/path/to/rest-container-registry \
  -Dazure-sdk-core-commit=<release-commit> \
  -Dazure-sdk-core-hash=<zig-package-hash> \
  generate-container-registry-package
```

The step emits the package/module name `azure_rest_container_registry`,
including its generated contract tests. Main does not contain a generated
package tree; output always targets an external package worktree.

## Branch model

Each generated package is developed and released from its package branch:

```
rest/<service>
```

- Generated packages use the module name `azure_rest_<service>`.
- Canonical generated packages reference `azure_sdk_core` through an exact
  release commit and Zig package hash in `build.zig.zon`.
- Generator changes are submitted as pull requests whose base is the package
  branch, not `main`.

See [`../doc/package-branch-model.md`](../doc/package-branch-model.md) for the
long-term generated REST and hand-written SDK branch, package, dependency, and
release conventions.

## How to regenerate one package

```bash
# 0. (One-time, per componentize-js bump) Build a custom
#    StarlingMonkey engine that raises the SpiderMonkey GC heap cap
#    from 32 MiB to 1 GiB. The upstream cap is baked into the engine
#    wasm shipped by componentize-js and trips OOM (`mozalloc_abort`)
#    on large ARM specs (e.g. Microsoft.AVS). The script clones
#    ComponentizeJS at the matching tag, patches `engine.cpp`, and
#    drops the result at `tcgc-component/engine/...wasm`, which the
#    next step auto-detects.
#
#    Requirements: cmake (4.x), rustup, clang. Build is ~3 min on
#    Apple Silicon (downloads SpiderMonkey + OpenSSL on first run).
cd codegen/tcgc-component
scripts/build-engine.sh

# 1. Build the TCGC component (once per TypeSpec version bump).
#    `npm install` populates tcgc-component/node_modules — its
#    vendored TypeSpec packages are mounted as WASI preopens at
#    runtime (not bundled into the wasm), so the working tree must
#    keep node_modules around between builds.
npm install
npm run build         # produces tcgc-nohttp.wasm + dist/stdlib-preopens.txt

# 2. Build the Zig codegen-cli binary and compose it with tcgc.
cd ../cli
zig build
scripts/build-component.sh   # produces zig-out/bin/codegen-cli.composed.wasm

# 3. Generate a package. The wrapper script reads
#    tcgc-component/dist/stdlib-preopens.txt and constructs the right
#    set of wasmtime --dir flags for the stdlib + user spec + output.
cd ../../..
#    `--package-name` is the canonical snake_case Zig module id;
#    `--display-name` is the dash-cased human label used in README.md /
#    doc comments. The spec and display name come from tspconfigs.yaml.
codegen/cli/scripts/run.sh \
    ../azure-rest-api-specs/specification/keyvault/data-plane/Secrets \
    .tsp-generated/client/keyvault_secrets \
    --package-name azure_rest_keyvault_secrets --display-name keyvault-secrets \
    --azure-sdk-core-path ../../..
```

## How to resync a package branch

Generated package worktrees mostly own their `build.zig`,
`build.zig.zon`, `README.md`, `.gitignore`, and (occasionally)
`src/clients.zig` / `src/enums.zig` — operators wire in examples,
add deps, work around emitter bugs, etc. `src/models.zig` is the one
file the emitter currently owns end-to-end.

```bash
codegen/scripts/sync.sh \
  --output-root /path/to/package-worktree \
  --azure-sdk-core-commit <release-commit> \
  --azure-sdk-core-hash <zig-package-hash> \
  keyvault_secrets
```

External output requires an explicit Core worktree path or immutable
commit/hash pin so the generated manifest cannot accidentally contain a
monorepo-relative dependency.

Default behaviour copies `src/models.zig` only and reports every
other emitter-managed file that drifted as `SKIP <file>
(operator-managed)`. `--force` overwrites them too — use that flag
when onboarding a brand-new package.

> **Note on the engine wasm.** If step 0 is skipped, step 1 falls
> back to the bundled 32 MiB-heap engine — small specs (e.g.
> `keyvault-secrets`) still work, but larger ARM specs OOM during
> TypeSpec compilation. Override the engine location with
> `STARLINGMONKEY_ENGINE=/path/to/wasm npm run build`.

The `rest/container_registry` branch is intentionally different: every package
and source file is owned by
`fixtures/generate_container_registry_package.zig`. Use the dedicated
`generate-container-registry-package` step above rather than `sync.sh`;
do not patch its generated files manually.

The generator accepts `-Dcontainer-registry-output`, and deterministic
verification can compare separate package worktrees:

```bash
scripts/verify-container-registry-regeneration.sh \
  --rest-package-root /path/to/rest-container-registry \
  --sdk-package-root /path/to/sdk-container-registry
```

## References

- Issue:
  <https://github.com/cataggar/azure-sdk-for-rust/issues/90>
- Rust prior art PR:
  <https://github.com/cataggar/azure-sdk-for-rust/pull/92>
- TCGC API:
  <https://github.com/Azure/typespec-azure/tree/main/packages/typespec-client-generator-core>
- jco:
  <https://github.com/bytecodealliance/jco>
