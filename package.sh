#!/usr/bin/env bash
# Build the AVS "list private clouds" WASI component end-to-end.
#
#   1. zig build            -> zig-out/bin/avs-wasi.wasm   (wasm32-wasi core)
#   2. wabt component embed -> embeds the WIT world
#   3. wabt component new   -> wraps into a component (built-in wasi-p1 adapter)
#   4. wabt module validate -> validates the component
#
# Output: zig-out/avs-wasi.component.wasm
#
# Requires: zig 0.16 and wabt v3+ (install via ghr: `ghr install cataggar/wabt`).
# wabt's `component new` auto-attaches a built-in wasi_snapshot_preview1
# adapter, so no external adapter file is needed. To override (e.g. to use a
# different adapter), set WASI_ADAPTER=/path/to/adapter.wasm.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> zig build (wasm32-wasi core)"
zig build --fetch
zig build

CORE=zig-out/bin/avs-wasi.wasm
EMBED=zig-out/avs-wasi.embed.wasm
COMPONENT=zig-out/avs-wasi.component.wasm

echo "==> wabt component embed"
wabt component embed --world avs-wasi -o "$EMBED" wit "$CORE"

echo "==> wabt component new"
if [[ -n "${WASI_ADAPTER:-}" ]]; then
    wabt component new --adapt "wasi_snapshot_preview1=$WASI_ADAPTER" -o "$COMPONENT" "$EMBED"
else
    wabt component new -o "$COMPONENT" "$EMBED"
fi

echo "==> wabt module validate"
wabt module validate "$COMPONENT"

echo "OK: $COMPONENT"
