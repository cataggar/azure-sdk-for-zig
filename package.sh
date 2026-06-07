#!/usr/bin/env bash
# Build the AVS "list private clouds" WASI component end-to-end.
#
#   1. zig build              -> zig-out/bin/avs-wasi.wasm   (wasm32-wasi core)
#   2. wasm-tools embed       -> embeds the WIT world
#   3. wasm-tools new --adapt -> wraps into a component (+ wasi-p1 adapter)
#
# Output: zig-out/avs-wasi.component.wasm
#
# Requires: zig 0.16, wasm-tools, and a wasi_snapshot_preview1 *command*
# adapter. Override its path with WASI_ADAPTER=/path/to/adapter.wasm.
set -euo pipefail
cd "$(dirname "$0")"

ADAPTER="${WASI_ADAPTER:-/tmp/wasi_snapshot_preview1.command.wasm}"
if [[ ! -f "$ADAPTER" ]]; then
    echo "error: wasi-preview1 command adapter not found at $ADAPTER" >&2
    echo "       set WASI_ADAPTER=/path/to/wasi_snapshot_preview1.command.wasm" >&2
    exit 1
fi

echo "==> zig build (wasm32-wasi core)"
zig build --fetch
./patch-deps.sh
zig build

CORE=zig-out/bin/avs-wasi.wasm
EMBED=zig-out/avs-wasi.embed.wasm
COMPONENT=zig-out/avs-wasi.component.wasm

echo "==> wasm-tools component embed"
wasm-tools component embed wit --world avs-wasi "$CORE" -o "$EMBED"

echo "==> wasm-tools component new (+ wasi-preview1 adapter)"
wasm-tools component new "$EMBED" --adapt "wasi_snapshot_preview1=$ADAPTER" -o "$COMPONENT"

echo "==> validate"
wasm-tools validate "$COMPONENT"

echo "OK: $COMPONENT"
