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
 git push origin <package_name>             ← orphan branch
```

## Layout

| Path                              | Purpose                                                |
| --------------------------------- | ------------------------------------------------------ |
| `tspconfigs.yaml`                 | Tracked manifest of every tspconfig.yaml under `../azure-rest-api-specs/specification/`, with resolved `js`/`zig` package names. Regenerate via `zig build tspconfigs-update` (re-walks the specs) and `zig build tspconfigs-resolve` (refills `js`/`zig`). |
| `wit/tcgc.wit`                    | WIT contract exposed by `tcgc.wasm`.                   |
| `tcgc-component/`                 | JS wrapper componentized by `jco` into `tcgc.wasm`.    |
| `cli/`                            | Zig WASI emitter — `codegen-cli.wasm`, composed with `tcgc.wasm` and driven by `cli/scripts/run.sh`. |
| `tspconfigs/`                     | Zig tool that manages `tspconfigs.yaml` (`zig build tspconfigs-update` / `-resolve`). |
| `scripts/sync.sh`                 | Resyncs `rest/<pkg>/` from the canonical spec; overwrites only `src/models.zig` by default. |
| `fixtures/`                       | Small JSON code-model fixtures used by emitter tests.  |

## Branch model

Each generated package lives on its own **orphan branch** named after
the package:

```
<package_name>
```

- `<package_name>` is the snake_case Zig module name, e.g.
  `keyvault_secrets`, `arm_keyvault` (see the `zig:` field in
  `tspconfigs.yaml`).
- The orphan branch references `azure_core` (and friends) from `main`
  through a pinned git URL+hash in `build.zig.zon`.

See `../../../../session-state/.../plan.md` (committed for the PR) for the
full plan, naming rules, and phased rollout.

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
#    `--package-name` is the snake_case Zig module id (also the orphan
#    branch suffix); `--display-name` is the dash-cased human label used
#    in README.md / doc comments. Both come from tspconfigs.yaml.
codegen/cli/scripts/run.sh \
    ../azure-rest-api-specs/specification/keyvault/data-plane/Secrets \
    .tsp-generated/client/keyvault_secrets \
    --package-name keyvault_secrets --display-name keyvault-secrets
```

## How to resync a tracked package

Tracked packages under `rest/<pkg>/` mostly own their `build.zig`,
`build.zig.zon`, `README.md`, `.gitignore`, and (occasionally)
`src/clients.zig` / `src/enums.zig` — operators wire in examples,
add deps, work around emitter bugs, etc. `src/models.zig` is the one
file the emitter currently owns end-to-end.

```bash
codegen/scripts/sync.sh                 # every existing rest/<pkg>/
codegen/scripts/sync.sh arm_avs         # one package
codegen/scripts/sync.sh --force arm_avs # also overwrite build.zig etc.
```

Default behaviour copies `src/models.zig` only and reports every
other emitter-managed file that drifted as `SKIP <file>
(operator-managed)`. `--force` overwrites them too — use that flag
when onboarding a brand-new package.

> **Note on the engine wasm.** If step 0 is skipped, step 1 falls
> back to the bundled 32 MiB-heap engine — small specs (e.g.
> `keyvault-secrets`) still work, but larger ARM specs OOM during
> TypeSpec compilation. Override the engine location with
> `STARLINGMONKEY_ENGINE=/path/to/wasm npm run build`.

## References

- Issue:
  <https://github.com/cataggar/azure-sdk-for-rust/issues/90>
- Rust prior art PR:
  <https://github.com/cataggar/azure-sdk-for-rust/pull/92>
- TCGC API:
  <https://github.com/Azure/typespec-azure/tree/main/packages/typespec-client-generator-core>
- jco:
  <https://github.com/bytecodealliance/jco>
