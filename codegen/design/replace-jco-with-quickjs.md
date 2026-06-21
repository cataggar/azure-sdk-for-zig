# Design: replace `jco` with QuickJS for the TypeSpec codegen toolchain

**Status:** draft / design review. The runtime feasibility spikes (S1–S5)
below are all complete and passing; no host code is implemented yet
(Phases 1–4 are the remaining work).

## Goal

Run the **TypeSpec / TCGC code-model API from Zig** without `jco`,
componentize-js, StarlingMonkey, the WebAssembly Component Model, or
`wasmtime`. Instead, embed the **Zig-ported QuickJS**
([`cataggar/quickjs-zig`](https://github.com/cataggar/quickjs-zig))
directly in the Zig host so the TypeSpec compiler runs *in-process*, and
AOT-compile the JS bundle to QuickJS bytecode with `qjsc`.

> The task that motivated this was framed as "quickjs + zigar". Spike S5
> determined **zigar does not fit** — it is a JS-hosts-Zig (N-API/V8)
> toolkit, the inverse of what is needed — so the design uses
> **quickjs only**, with the narrow Zig↔JS boundary hand-rolled against
> `quickjs.h`.

## What `jco` does today (the thing being replaced)

In `codegen/tcgc-component/`:

1. `esbuild` bundles `@typespec/compiler` + TCGC + Azure libs ->
   `dist/bundled.js` (single ESM module).
2. `jco componentize` snapshots that JS into a SpiderMonkey
   (StarlingMonkey) engine -> `tcgc.wasm`, a **WASM Component** exporting
   `azure:codegen/tcgc#compile(string,string) -> result<string,string>`
   (see `wit/component.wit`).
3. A **custom StarlingMonkey engine** must be built to raise the GC heap
   cap 32 MiB -> 1 GiB or large ARM specs OOM (`scripts/build-engine.sh`).
4. Zig `codegen-cli.wasm` imports `tcgc#compile` via the Component Model
   (`cli/src/tcgc_import.zig`), composed with `tcgc.wasm` ->
   `codegen-cli.composed.wasm`, run under **wasmtime** with WASI preopens
   for stdlib + `/spec` + output.

Pain points: custom engine build, `wabt` component embed/compose, WASI
preopen juggling, wasmtime dependency, the 32 MiB heap workaround, and the
known issue that WAMR cannot run the composed component (only wasmtime
can).

## Proposed architecture

**Decision (locked): native Zig binary only.** No WASI, no wasmtime, no
Component Model, no StarlingMonkey anywhere in the pipeline. The host links
QuickJS as a static library and runs the TypeSpec JS in-process, servicing
all file I/O directly from the native OS filesystem.

```
  .tsp files
     │
     ▼
 ┌─────────────────────────────────────────────┐
 │  Native Zig binary                           │
 │  ├─ libquickjs (quickjs-zig, static)         │
 │  ├─ embedded QuickJS bytecode of bundled.js  │  ← qjsc AOT
 │  │    (@typespec/compiler + TCGC + azure)    │
 │  ├─ host shims (Zig): file I/O, globals,      │
 │  │    microtask/promise pump                  │
 │  └─ tcgc.zig: compile(projectPath, opts)      │
 │         -> JSON code model (string)           │
 └─────────────────────────────────────────────┘
     │ JSON code model
     ▼
  existing Zig emitter (cli/) -> Zig source
```

### Role of each tool

- **quickjs-zig** — the JS engine, embedded in Zig. Zig is the host and
  drives JS through the QuickJS C/Zig API (`JS_Eval`, `JS_Call`,
  `JS_NewStringLen`, `JS_ToCString`, `JS_ExecutePendingJob`, …). Its
  `build.zig` already builds `qjs` + `qjsc` and uses `qjsc` to codegen
  `repl.c`, so the AOT-embed pattern is proven.
- **qjsc** — AOT compiler. `qjsc -c` turns `dist/bundled.js` into QuickJS
  **bytecode** baked into the Zig binary. ("Ahead-of-time" here = parse
  done at build time + no JS source shipped, **not** native codegen — see
  the performance section.)
- **zigar** — evaluated and **not used** (see S5).

### Reused unchanged

- The `esbuild` bundle step (`scripts/build-component.mjs` bundling logic).
- TypeSpec/TCGC `node_modules` at *build* time only.
- `src/index.js` emitter logic and the `WasiHost`/`CompilerHost`
  abstraction — keep the JS, but rename it (no longer "Wasi") and re-point
  its leaf I/O from WASI preopens to Zig host functions that read the
  **native filesystem** directly (baked virtualFs for stdlib + real paths
  for the user's spec/output dirs — no preopen flags to construct).

## Feasibility spikes

All spikes were run against `quickjs-zig`'s `qjs`/`qjsc` and the real
`tcgc-component` bundle. Reproduction artifacts are under
[`spikes/`](./spikes): `demo_harness.mjs` (small inline service),
`avs_harness.mjs` (the large ARM spec), and `host_polyfills.js` (the
missing-global shims, which become the production Zig host shims).

| Spike | Question | Result |
| --- | --- | --- |
| **S1** | Does the TCGC bundle run on QuickJS at all? | ✅ runs end-to-end |
| **S2** | Does `qjsc` AOT-compile the bundle? | ✅ 1.27 MB bytecode, valid native exe |
| **S3** | Does async `compile()` resolve? | ✅ QuickJS drains its own job queue |
| **S4** | Memory on large ARM specs (AVS)? | ✅ no OOM (~297 MiB); ⚠️ JIT-less perf |
| **S5** | Can zigar provide the Zig↔JS bridge? | ❌ no — hand-roll `quickjs.h` glue |

### Pre-flight: language feature probe

`quickjs-zig`'s `qjs` supports everything TypeSpec/TCGC needs:

- ✅ **Unicode-property regex** `\p{L}` — the exact feature
  (js-tokens / @babel/code-frame) that forced a StarlingMonkey stub.
- ✅ async/await, top-level await (module mode), named capture groups,
  lookbehind, BigInt, WeakRef, Proxy, FinalizationRegistry, performance.
- ❌ Missing globals needing shims: `structuredClone`, `queueMicrotask`,
  `TextEncoder`/`TextDecoder`, `URL`, `crypto.subtle`. All are small
  JS/Zig polyfills.

### S1 + S3 — full TypeSpec + TCGC runs end-to-end

Built `dist/bundled.js` (2.35 MB esbuild bundle) and drove the WIT export
`compile(projectPath, emitterOptions)` under `qjs` against a small inline
TypeSpec service. **The full TypeSpec compiler + TCGC `createSdkContext`
ran to completion and returned the JSON code model (4219 bytes)** — the
same artifact `jco`'s `tcgc.wasm` produces. The async `compile()` resolved
(QuickJS drained its own job queue). Concrete requirements discovered:

1. **Large stack required.** QuickJS uses the C stack for JS recursion, so
   the deeply recursive Ajv schema compile + TypeSpec checker overflow the
   default ~256 KB limit. Needed `--stack-size ~400 MB` **and** a raised OS
   stack (`ulimit -s 524288`). *Host implication:* run QuickJS on a
   dedicated thread with a large stack and call `JS_SetMaxStackSize`
   accordingly. (400 MB was a generous upper bound, not a measured floor —
   tune later.)
2. **Host globals to shim** (confirmed by hitting each in turn):
   `TextEncoder`/`TextDecoder`, `queueMicrotask`, `structuredClone`, and
   `crypto.subtle.digest("SHA-256", …)` (TCGC's
   `computeCrossLanguageVersion`). All trivial in Zig
   (`std.crypto.hash.sha2.Sha256`, `std.unicode`); see
   `spikes/host_polyfills.js`.
3. **Host FS surface:** serve the TypeSpec stdlib `.tsp` + `package.json`
   from the dirs in `dist/stdlib-preopens.txt` (101 files) plus the user
   spec via the existing inline `__spec_files` map. Zig reads these from
   the real filesystem (no WASI).
4. **Build note:** the bundle needs `@typespec/openapi`, `@typespec/streams`,
   `@typespec/xml` present in `node_modules` (currently only transitive),
   and `npm install --legacy-peer-deps` due to upstream `@typespec/openapi`
   1.13 peer drift against the pinned 1.12 line.

### S2 — AOT bytecode compiles, links, runs

- `qjsc -c -m -s` compiled the 2.35 MB `dist/bundled.js` to **1.27 MB of
  QuickJS bytecode in 1.4 s** (build-time cost, paid once).
- `qjsc -e -m -s -S 400000000` generated a C `main` (uses quickjs-libc
  `js_std_*` helpers; embeds `JS_SetMaxStackSize(rt, 400 MB)`).
- Linked with `zig cc` against `quickjs-zig`'s `libquickjs.a` into a
  **14 MB self-contained native executable**. (The shipped `libquickjs.a`
  was built with UBSan refs — link the AOT exe with `-fsanitize=undefined`,
  or rebuild the lib `ReleaseFast`.)
- Running it instantiates the **entire bundle from bytecode in 134 ms**
  vs **1.64 s** interpreting the source — **~12× faster cold start**, parse
  cost eliminated. (Module top-level init only; calling `compile()` from
  the AOT exe is Phase 2.)

### S4 — no OOM on large specs; performance is the real trade-off

Compiled real specs from `azure-rest-api-specs` under `qjs` (peak RSS via
`getrusage(RUSAGE_CHILDREN)`):

| Spec | .tsp files | compile | peak RSS | model |
| --- | --- | --- | --- | --- |
| keyvault-secrets (data-plane) | 5 | 15.7 s | 71 MiB | 58 KB, 1 client |
| Microsoft.AVS (ARM) | 36 | 113 s | 297 MiB | 790 KB, 25 clients |

- **Memory: PASS.** AVS — the exact spec that OOM'd StarlingMonkey at its
  baked 32 MiB GC cap — compiles cleanly at ~297 MiB. QuickJS has no such
  cap (`malloc limit: -1`), so the custom 1 GiB engine build is *entirely
  eliminated*.
- **Performance: the caveat.** QuickJS is **interpreter-only (no JIT)**, so
  TypeSpec/TCGC compilation runs ~10× slower than Node/V8: ~16 s for a
  small spec, ~113 s for a large ARM spec. AOT bytecode (S2) removes only
  the ~1.5 s parse, *not* execution cost — runtime is interpreter-bound.

#### Profile of the AVS 113 s (`perf`, 59,701 samples)

C-level self-time, grouped:

| Category | Share | Symbols |
| --- | ---: | --- |
| Interpreter dispatch | ~34% | `JS_CallInternal` |
| Property / shape ops | ~13% | `get_shape_prop`, `JS_GetPropertyInternal`, `add_property`, `JS_NewObjectFromShape` |
| Reference counting | ~11% | `JS_DupValue`, `JS_FreeValue`, `__js_rc`, `free_object` |
| Allocation | ~8% | `__js_malloc/free/realloc`, arena |
| Cycle GC | ~3% | `mark_children`, `gc_*` |
| Map / atoms / closures / C-calls | rest | `map_find_record`, `__JS_AtomToValue`, `js_call_c_function` |

Not hotspots: **regex ≈ 0.5%** (the StarlingMonkey-breaking Unicode regex
is irrelevant to perf); the SHA-256/TextEncoder polyfills = **0%**; **no
single TCGC pass dominates**. The cost is broad, fundamental interpreter +
dynamic-dispatch + refcount/alloc overhead on TypeSpec's object-heavy work
(~1.3 M objects, 95 K Maps): **no algorithmic low-hanging fruit, and a
realistic baseline JIT would yield only ~1.2–1.4×** (it attacks the ~34 %
dispatch but still calls into the ~50 %+ runtime primitives). Cheap host
knobs (GC threshold, interrupt-poll interval) buy only ~1–3 % combined.

#### Performance decision: accept it

Ship the QuickJS interpreter and rely on codegen being an **offline,
embarrassingly-parallel CI batch** — once per package per TypeSpec bump,
not interactive. Per-spec latency (~16 s small, ~113 s large) is
acceptable; parallelize across packages in CI if total wall-clock matters.
Revisit only if interactive/low-latency codegen becomes a hard requirement
(the one reason would be to keep a JIT'd engine — i.e. SpiderMonkey — at
the cost of the OOM/engine-build/Component-Model baggage we are removing).

### S5 — zigar does not fit; hand-roll the QuickJS glue

zigar's architecture is **JS-hosts-Zig**: a JS engine (V8/Node, JSC/Bun,
or a browser) is the top-level host, and Zig is the guest, reached either
as a native addon over **N-API** (`node-zigar-addon/src/napi.zig` →
`@cInclude("node_api.h")`, `napi_create_string_utf8`,
`napi_call_function`, …) or as Wasm via a bundler. `zigar-runtime/src/*`
is all **JavaScript** that marshals Zig memory layouts into JS objects.

That is the **opposite** of what this project needs (Zig as host, QuickJS
embedded as guest), and zigar has **no QuickJS support** — its bridge is
hard-wired to N-API/V8. Reusing it would mean embedding Node, defeating
the entire point (tiny in-process engine, no Node/wasmtime).

**Verdict: drop zigar.** The boundary is a single
`compile(projectPath, emitterOptions) -> result<string,string>`; the host
shims (FS-backed `CompilerHost`, global polyfills, microtask pump) are
likewise narrow. All of it is hand-rolled directly against `quickjs.h`,
whose required surface is confirmed present in `quickjs-zig`:

- Marshal in/out: `JS_NewStringLen`, `JS_ToCStringLen`, `JS_GetPropertyStr`.
- Call + drive: `JS_Call`, `JS_ExecutePendingJob` (promise pump),
  `JS_IsException`.
- Register host fns + shims: `JS_NewCFunction`, `JS_SetPropertyStr`.
- Boot AOT bytecode + stack: `JS_ReadObject`, `JS_EvalFunction`,
  `JS_SetMaxStackSize`.

Estimated glue: ~30–50 lines of Zig for `compile()`, plus the host-fn
registrations. (As `quickjs-zig` ports more of QuickJS to Zig, this glue
can move from `@cImport` to native Zig calls, but the C ABI works today.)

## Phased implementation (remaining work)

- **Phase 1** — Host shims: Zig-backed `CompilerHost` leaf I/O (baked
  stdlib virtualFs + real FS for the user spec) + the missing-global
  polyfills; get keyvault-secrets JSON via an interpreted `qjs`-style
  harness driven from Zig.
- **Phase 2** — Embed: `qjsc` the bundle -> bytecode array; new Zig `tcgc`
  module exposing `compile()` that boots a `JSContext`, registers host
  fns, runs the bytecode module, calls the export, pumps jobs, returns the
  string. Replaces the Component-Model import in `cli/src/tcgc_import.zig`
  with an in-process call.
- **Phase 3** — Wire into `codegen-cli`: drop wasmtime / wabt / jco /
  StarlingMonkey from the build + docs; single native binary.
- **Phase 4** — Parity: run the full package set incl. AVS; diff JSON
  models byte-for-byte vs current `jco` output; perf/mem benchmarks;
  update `codegen/README.md`.

## Decisions

1. ✅ **Target**: native Zig binary only. No WASI/wasmtime/Component Model
   output.
2. ✅ **zigar**: not used (S5). The Zig↔JS boundary is hand-rolled against
   `quickjs.h`.
3. ✅ **Performance**: accept the JIT-less interpreter; codegen is an
   offline, parallelizable CI batch.
