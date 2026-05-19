#!/usr/bin/env bash
#
# run.sh — drive `codegen-cli.composed.wasm` under wasmtime with the
# right WASI preopens.
#
# Usage:
#
#   eng/codegen/cli/scripts/run.sh <spec-dir> <out-dir> [extra args…]
#
# Mounts:
#
#   <spec-dir> → /spec        user TypeSpec spec
#   <out-dir>  → /out         where the generator writes Zig source
#   each line of                ╮
#     tcgc-component/dist/      │ vendored TypeSpec package roots — the
#     stdlib-preopens.txt       │ Zig host walks these to populate
#                               │ `virtualFsSources` at runtime, so the
#                               ╯ wasm no longer carries stdlib `.tsp`.
#
# Extra positional / flag args after <out-dir> are passed through to
# the codegen-cli binary (e.g. `--package-name keyvault-secrets`).

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: $0 <spec-dir> <out-dir> [extra args…]" >&2
    exit 2
fi

SPEC_DIR="$(cd "$1" && pwd)"; shift
OUT_DIR="$1"; shift
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WASM="$CLI_DIR/zig-out/bin/codegen-cli.composed.wasm"
MANIFEST="$CLI_DIR/../tcgc-component/dist/stdlib-preopens.txt"

if [[ ! -f "$WASM" ]]; then
    echo "error: composed wasm not found at $WASM" >&2
    echo "  rebuild via: (cd $CLI_DIR && zig build && scripts/build-component.sh)" >&2
    exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
    echo "error: stdlib manifest not found at $MANIFEST" >&2
    echo "  rebuild via: (cd $CLI_DIR/../tcgc-component && npm install && npm run build)" >&2
    exit 1
fi

dir_args=(
    --dir "$SPEC_DIR::/spec"
    --dir "$OUT_DIR::/out"
)
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    host="${line%%=*}"
    virt="${line#*=}"
    if [[ ! -d "$host" ]]; then
        echo "error: stdlib preopen missing on host: $host" >&2
        echo "  rebuild tcgc-component or run \`npm install\` first" >&2
        exit 1
    fi
    dir_args+=(--dir "$host::$virt")
done < "$MANIFEST"

exec wasmtime run -S http -W max-memory-size=4294967296 "${dir_args[@]}" "$WASM" /spec /out "$@"
