# avs-wasi

List Microsoft.AVS private clouds from a WebAssembly **component**, running the
generated [`azure_rest_arm_avs`](https://github.com/cataggar/azure-sdk-for-zig) Azure SDK
client under WASI (wamr / wasmtime).

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

`wamr` is AOT-only. `wamrc run` AOT-compiles the component (caching the
artifact next to it) and then spawns the runtime in one step; flags after
`--` are forwarded verbatim to `wamr run`:

```sh
wamrc run "$C" -- --allow-net 0.0.0.0/0 \
    --env AZURE_SUBSCRIPTION_ID="$SUB" --env AZURE_TOKEN="$TOK"
```

`--allow-net` is required: wamr default-denies outbound HTTP. Requires wamr
≥ v3.0.0-dev.11 (`ghr install cataggar/wamr`), which added macOS aarch64
host-import trampolines and fixed `wamrc run` flag forwarding — see
cataggar/wamr#831.

The canonical-ABI glue (and the wamr/wasmtime align-4 vs align-8 quirk for
`wasi:http`'s `error-code` variant — see cataggar/wamr#814) lives in
`azure_sdk_core`'s `sdk/core/http/wasi_http.zig`.

