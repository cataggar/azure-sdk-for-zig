#!/usr/bin/env bash
# Build the AVS "list private clouds" WASI component end-to-end.
#
#   1. zig build          -> zig-out/bin/avs.core.wasm  (wasm32-wasi core)
#   2. wabt component new -> embeds the WIT world, wraps into a component
#                            (built-in wasi-preview1 adapter), and validates.
#                            A `<name>.core.wasm` input yields `<name>.wasm`.
#
# Output: zig-out/bin/avs.wasm
#
# Requires: zig 0.16 and wabt v3+ (install via ghr: `ghr install cataggar/wabt`).
# `wabt component new` embeds the sole WIT world from the `wit/` directory (the
# default when no --wit is given) and auto-attaches a built-in
# wasi_snapshot_preview1 adapter, so no separate embed step or external adapter
# file is needed.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> zig build (wasm32-wasi core)"
zig build --fetch
zig build

echo "==> wabt component new (embed + wrap + validate)"
wabt component new zig-out/bin/avs.core.wasm

echo "OK: zig-out/bin/avs.wasm"
