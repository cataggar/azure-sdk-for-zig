#!/usr/bin/env bash
#
# build-component.sh — assemble the composed codegen-cli component.
#
# Steps:
#   1. `wabt component embed` — attach the component-type custom
#      section derived from wit/world.wit to the wasm32-wasi Zig
#      binary produced by `zig build`.
#   2. `wabt component new --adapt …` — wrap into a component,
#      lifting `_start` to `wasi:cli/run.run` via the preview1
#      adapter. Uses the upstream wasmtime adapter at
#      `wasi_snapshot_preview1.command.wasm` until cataggar/wabt#208
#      is fixed (the built-in adapter is missing fd_pread,
#      path_readlink, poll_oneoff).
#   3. `wabt component compose` — link our `azure:codegen/tcgc`
#      import to tcgc.wasm's matching export.
#
# Final output: `zig-out/bin/codegen-cli.composed.wasm` — a single
# component runnable as `wasmtime run --dir <spec>::/spec
# --dir <out>::/out codegen-cli.composed.wasm /spec /out …`.

set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$CLI_DIR/../.." && pwd)"

WABT="${WABT:-$REPO_ROOT/../wabt/zig-out/bin/wabt}"
ADAPTER="${PREVIEW1_ADAPTER:-/tmp/wasi_snapshot_preview1.command.wasm}"
TCGC_WASM="${TCGC_WASM:-$CLI_DIR/../tcgc-component/tcgc-nohttp.wasm}"

if [[ ! -x "$WABT" ]]; then
    echo "error: wabt not found at $WABT" >&2
    echo "  build it with: (cd $REPO_ROOT/../wabt && zig build)" >&2
    exit 1
fi

if [[ ! -f "$ADAPTER" ]]; then
    echo "downloading upstream preview1 adapter to $ADAPTER"
    curl -sSL -o "$ADAPTER" \
        https://github.com/bytecodealliance/wasmtime/releases/download/v44.0.1/wasi_snapshot_preview1.command.wasm
fi

CORE="$CLI_DIR/zig-out/bin/codegen-cli.wasm"
EMBED="$CLI_DIR/zig-out/bin/codegen-cli.embed.wasm"
COMP="$CLI_DIR/zig-out/bin/codegen-cli.comp.wasm"
OUT="$CLI_DIR/zig-out/bin/codegen-cli.composed.wasm"

if [[ ! -f "$CORE" ]]; then
    echo "error: $CORE not found; run \`zig build\` first" >&2
    exit 1
fi

echo "→ wabt component embed (-w cli) → $EMBED"
"$WABT" component embed -w cli "$CLI_DIR/wit/" "$CORE" -o "$EMBED"

echo "→ wabt component new (--adapt preview1) → $COMP"
"$WABT" component new "$EMBED" --adapt "wasi_snapshot_preview1=$ADAPTER" -o "$COMP"

if [[ ! -f "$TCGC_WASM" ]]; then
    echo "warning: $TCGC_WASM not found — stopping after \`component new\`."
    echo "          rebuild it via: (cd ../tcgc-component && npm run build)"
    echo "          composed.wasm = $COMP (with the tcgc import unresolved)"
    exit 0
fi

echo "→ wabt component compose (link tcgc.wasm, align wasi to 0.2.6) → $OUT"
"$WABT" component compose "$COMP" -d "$TCGC_WASM" --align-wasi=0.2.6 -o "$OUT"

echo "✓ $OUT  ($(stat -c %s "$OUT") bytes)"
