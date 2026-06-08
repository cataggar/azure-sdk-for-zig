# avs-wasi

List Microsoft.AVS private clouds from a WebAssembly **component**, running the
generated [`arm_avs`](https://github.com/cataggar/azure-sdk-for-zig) Azure SDK
client under WASI (wamr / wasmtime).

It is the WASI port of `list_private_clouds`. The native
example uses `std.http.Client` and the Azure CLI credential; neither works
inside a wasm component, so this version swaps in two pluggable pieces that
live in `azure_core`:

| Piece | Where | Replaces |
|-------|-------|----------|
| `core.wasi_http.WasiHttpTransport` | `azure_core` (PR #40) | `StdHttpTransport` — outbound HTTPS via `wasi:http/outgoing-handler@0.2.6` |
| `core.env_token.EnvTokenCredential` | `azure_core` (PR #40) | `AzureCliCredential` — bearer token from the `AZURE_TOKEN` env var |

Everything else (the pager, JSON parsing, the pipeline/auth policy) is the
unmodified SDK: it only depends on the abstract `HttpTransport` / `TokenCredential`
vtables, so this example is purely the wiring in `src/main.zig` plus packaging.

## Build

```sh
./package.sh           # zig build (wasm32-wasi) -> wabt component new
# output: zig-out/bin/avs.wasm
```

Requirements: Zig 0.16 and wabt v3+ (`ghr install cataggar/wabt`).

`wabt component new zig-out/bin/avs.core.wasm` does it all in one call:
embeds the sole WIT world from the `wit/` directory (the default when
`--wit` is omitted), auto-attaches the built-in wasi-preview1 → preview2
adapter, wraps the core into a component, and validates it. The
`<name>.core.wasm` input yields `<name>.wasm`.

## Run

Get a token + subscription id on the host:

```sh
SUB=$(grep -E '^AZURE_SUBSCRIPTION_ID=' .env | cut -d= -f2)
# Scope the token to $SUB so `az` issues it for that subscription's tenant —
# your default `az` login may be in a different tenant.
TOK=$(az account get-access-token --subscription "$SUB" \
    --resource https://management.azure.com --query accessToken -o tsv)
C=zig-out/bin/avs.wasm
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

The canonical-ABI glue (and the wamr/wasmtime align-4 vs align-8 quirk for
`wasi:http`'s `error-code` variant — see cataggar/wamr#814) lives in
`azure_core`'s `sdk/core/http/wasi_http.zig`.

