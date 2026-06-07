# avs-wasi

List Microsoft.AVS private clouds from a WebAssembly **component**, running the
generated [`arm_avs`](https://github.com/cataggar/azure-sdk-for-zig) Azure SDK
client under WASI (wamr / wasmtime).

It is the WASI port of `/work/avs-smoke` (`list_private_clouds`). The native
example uses `std.http.Client` and the Azure CLI credential; neither works
inside a wasm component, so this version swaps in two small, pluggable pieces:

| Piece | File | Replaces |
|-------|------|----------|
| `WasiHttpTransport` | `src/wasi_http.zig` | `StdHttpTransport` — outbound HTTPS via `wasi:http/outgoing-handler@0.2.6` |
| `EnvTokenCredential` | `src/env_token_credential.zig` | `AzureCliCredential` — bearer token from the `AZURE_TOKEN` env var |

Everything else (the pager, JSON parsing, the pipeline/auth policy) is the
unmodified SDK: it only depends on the abstract `HttpTransport` / `TokenCredential`
vtables, so the WASI port is purely these two implementations plus packaging.

## Build

```sh
./package.sh           # zig build (wasm32-wasi) -> wasm-tools embed/new -> validate
# output: zig-out/avs-wasi.component.wasm
```

Requirements: Zig 0.16, `wasm-tools`, and a `wasi_snapshot_preview1` **command**
adapter (override its path with `WASI_ADAPTER=/path/to/adapter.wasm`).

Packaging uses `wasm-tools` rather than `wabt`: wabt's component encoder
produced an invalid component (`unknown type N: type index out of bounds`) for
this wasi:http world — see cataggar/wabt#234.

`package.sh` runs `patch-deps.sh` first — see "Upstream fix needed" below.

## Run

Get a token + subscription id on the host:

```sh
TOK=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)
SUB=$(az account show --query id -o tsv)
C=zig-out/avs-wasi.component.wasm
```

### wasmtime

```sh
wasmtime run -S http -S cli-exit-with-code \
    --env AZURE_SUBSCRIPTION_ID="$SUB" --env AZURE_TOKEN="$TOK" "$C"
```

### wamr

`wamr run` is AOT-only, and run-flags must precede the module:

```sh
wamrc run "$C"                          # AOT-compile once (-> <stem>.cwasm.json)
wamr run --allow-net 0.0.0.0/0 \
    --env AZURE_SUBSCRIPTION_ID="$SUB" --env AZURE_TOKEN="$TOK" "$C"
```

`--allow-net` is required: wamr default-denies outbound HTTP.

## How the transport works

`src/wasi_http.zig` is hand-written canonical-ABI glue (no Zig wit-bindgen
exists). It drives `wasi:http/outgoing-handler` directly:

1. `fields` + `fields.append` for request headers (skips `Host`).
2. `outgoing-request` + `set-method` / `set-scheme` / `set-authority` /
   `set-path-with-query`.
3. `outgoing-handler.handle(request, none)` → `future-incoming-response`.
4. `future.subscribe` → `pollable.block` → `future.get` for the response.
5. `incoming-response.status` + `consume` → `incoming-body.stream` →
   `input-stream.blocking-read` loop to drain the body.

`cabi_realloc` (a small reset-per-read bump arena) materializes the
host-returned body chunks into guest memory.

### Runtime ABI quirk

wamr and wasmtime disagree on the linear-memory alignment of `wasi:http`'s
`error-code` variant (it has `option<u64>` cases): wasmtime uses the canonical
align-8, wamr lays `handle`'s `result<future, error-code>` out align-4. The
transport detects which from the zero-filled ret-area after `handle` and reads
the future handle accordingly (`get`'s result is align-8 on both). See the
comments in `src/wasi_http.zig`, and cataggar/wamr#814 for the wamr-side bug.

## Upstream fix needed

`patch-deps.sh` applies a one-line `@alignCast` to the fetched
`azure_sdk` (`sdk/core/http/pipeline.zig`). `BearerTokenAuthPolicy`
reconstructs itself from its `HttpPolicy` vtable via `@fieldParentPtr`; on
wasm32 the 4-aligned fn-pointer vtable can't satisfy the struct's 8-alignment
(it has an `i64`), so the compiler rejects it. The proper fix is the same
`@alignCast` upstream in cataggar/azure-sdk-for-zig — see
[PR #39](https://github.com/cataggar/azure-sdk-for-zig/pull/39). Once that
merges, bump the `azure_sdk` pin in `build.zig.zon` and delete `patch-deps.sh`
(and its call in `package.sh`).

