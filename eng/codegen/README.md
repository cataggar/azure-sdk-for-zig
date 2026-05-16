# TypeSpec → Zig Code Generator

Generate Azure SDK packages for Zig from
[TypeSpec](https://typespec.io) specifications in
[`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs).

The architecture mirrors the Rust experiment in
[`cataggar/azure-sdk-for-rust#90`](https://github.com/cataggar/azure-sdk-for-rust/issues/90)
and [PR #92](https://github.com/cataggar/azure-sdk-for-rust/pull/92): the
TypeSpec toolchain is wrapped as a **WASI component** via
[`jco`](https://github.com/bytecodealliance/jco), and the actual code
generator is a **native Zig binary** that hosts the component.

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
 │  codegen (native Zig)                    │
 │  • loads tcgc.wasm via wamr              │
 │  • parses JSON via serde.zig             │
 │  • emits Zig source, build.zig, README   │
 │  • runs `zig fmt`                        │
 └──────────────────────────────────────────┘
      │
      ▼
 git push origin client/<package_name>      ← orphan branch
```

## Layout

| Path                              | Purpose                                                |
| --------------------------------- | ------------------------------------------------------ |
| `typespec-packages.txt`           | Inventory: 564 `tspconfig.yaml` repo-relative paths.   |
| `wit/tcgc.wit`                    | WIT contract exposed by `tcgc.wasm`.                   |
| `tcgc-component/`                 | JS wrapper componentized by `jco` into `tcgc.wasm`.    |
| `codegen/`                        | Zig source for the host + emitter binary.              |
| `scripts/`                        | Generation / regeneration shell helpers.               |
| `fixtures/`                       | Small JSON code-model fixtures used by emitter tests.  |

## Branch model

Each generated package lives on its own **orphan branch**:

```
<kind>/<package_name>
```

- `<kind>` ∈ `client` (current), `server` (future), `component` (future).
- `<package_name>` is the snake_case Zig module name, e.g.
  `azure_security_keyvault_secrets`, `azure_resourcemanager_vmware`.
- The orphan branch references `azure_core` (and friends) from `main`
  through a pinned git URL+hash in `build.zig.zon`.

See `../../../../session-state/.../plan.md` (committed for the PR) for the
full plan, naming rules, and phased rollout.

## How to regenerate one package

```bash
# 1. Build the TCGC component (once per TypeSpec version bump).
cd eng/codegen/tcgc-component
npm install
npm run build         # produces tcgc.wasm

# 2. Build the Zig codegen binary.
cd ../codegen
zig build

# 3. Generate a package onto an orphan branch.
cd ../../..
eng/codegen/scripts/generate.sh \
    ../azure-rest-api-specs/specification/keyvault/data-plane/Secrets/tspconfig.yaml \
    --kind client
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
- wamr (Zig component runtime used as host):
  <https://github.com/cataggar/wamr>
