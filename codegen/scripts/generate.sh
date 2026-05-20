#!/usr/bin/env bash
#
# generate.sh — produce a Zig client package from a TypeSpec spec.
#
# Usage:
#
#   codegen/scripts/generate.sh \
#       <abs-path-to-tspconfig.yaml-or-spec-dir> \
#       [--kind client] \
#       [--package-name <name>] \
#       [--out <dir>] \
#       [--wasi <path/to/tcgc.wasm>]
#
# Two execution modes:
#
#  • Node-bridge (default) — drives the JS adapter at
#    codegen/tcgc-component/src/index.js. Works today for any
#    TypeSpec spec the JS adapter handles.
#
#  • WASI host (`--wasi <wasm>`) — drives the Zig codegen binary's
#    `--tsp` mode, which loads the wasm component through the wamr
#    Component Model runtime. Requires that `<wasm>` was produced by
#    `jco componentize`. Only the stub component (`stub.js`) builds
#    today; full TCGC componentization is tracked separately.
#
# The orphan-branch publish flow (`git worktree add --orphan
# <kind>/<package_name>`) is intentionally separated from this script
# so the same generator can be used for local one-off generations.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEGEN_DIR="$REPO_ROOT/codegen"
COMPONENT_DIR="$CODEGEN_DIR/tcgc-component"
BIN_DIR="$CODEGEN_DIR/codegen"

spec_input=""
kind="client"
package_name=""
out_dir=""
use_wasi=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kind)         kind="$2"; shift 2 ;;
        --package-name) package_name="$2"; shift 2 ;;
        --out)          out_dir="$2"; shift 2 ;;
        --wasi)         use_wasi="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,22p' "$0"
            exit 0
            ;;
        -*)
            echo "unknown flag: $1" >&2
            exit 2
            ;;
        *)
            spec_input="$1"
            shift
            ;;
    esac
done

if [[ -z "$spec_input" ]]; then
    echo "usage: $0 <spec-path> [--kind client] [--package-name <name>] [--out <dir>]" >&2
    exit 2
fi

if [[ "$kind" != "client" ]]; then
    echo "only --kind client is supported in this milestone" >&2
    exit 2
fi

# Resolve the spec directory: if a tspconfig.yaml or .tsp file was
# passed, work on its parent directory.
if [[ -f "$spec_input" ]]; then
    spec_dir="$(dirname "$spec_input")"
else
    spec_dir="$spec_input"
fi
spec_dir="$(cd "$spec_dir" && pwd)"

if [[ -z "$package_name" ]]; then
    # Derive a default package name from the last spec-dir segment:
    # `Secrets` → `azure_secrets`. The real `--package-name` should be
    # passed explicitly for any non-trivial spec.
    base="$(basename "$spec_dir")"
    package_name="azure_$(echo "$base" | tr 'A-Z.-' 'a-z__')"
fi

if [[ -z "$out_dir" ]]; then
    out_dir="$REPO_ROOT/.tsp-generated/${kind}/${package_name}"
fi

mkdir -p "$out_dir"

# Step 2 — build the Zig codegen binary if needed.
if [[ ! -x "$BIN_DIR/zig-out/bin/codegen" ]]; then
    echo "→ building codegen"
    (cd "$BIN_DIR" && zig build)
fi

if [[ -n "$use_wasi" ]]; then
    # WASI-host mode: feed tcgc.wasm directly to the codegen binary.
    if [[ ! -f "$use_wasi" ]]; then
        echo "wasm component not found: $use_wasi" >&2
        exit 1
    fi
    echo "→ running WASI host on $spec_dir using $use_wasi"
    "$BIN_DIR/zig-out/bin/codegen" \
        --tsp "$spec_dir" \
        --wasm "$use_wasi" \
        --out "$out_dir" \
        --package-name "$package_name"
else
    # Node-bridge mode: run the JS adapter, then the Zig emitter.
    json_path="$(mktemp -t code-model-XXXXXX.json)"
    trap 'rm -f "$json_path"' EXIT

    echo "→ running TCGC adapter on $spec_dir"
    (
        cd "$COMPONENT_DIR"
        if [[ ! -d node_modules ]]; then npm install --no-audit --no-fund >/dev/null; fi
        node src/index.js "$spec_dir" "{\"package-name\":\"$package_name\"}" >"$json_path"
    )

    echo "→ emitting to $out_dir"
    "$BIN_DIR/zig-out/bin/codegen" \
        --from-json "$json_path" \
        --out "$out_dir" \
        --package-name "$package_name"
fi

# Step 3 — zig fmt.
echo "→ formatting"
zig fmt "$out_dir" >/dev/null

echo "✓ generated $package_name → $out_dir"
