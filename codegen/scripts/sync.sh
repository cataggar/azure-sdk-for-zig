#!/usr/bin/env bash
#
# sync.sh — regenerate one or more `rest/<pkg>/` packages from their
# canonical TypeSpec spec and copy the regen-safe emitter output back
# into the tracked tree.
#
# Usage:
#
#   codegen/scripts/sync.sh                  # sync every existing rest/<pkg>/
#   codegen/scripts/sync.sh <pkg>...         # sync only these packages
#   codegen/scripts/sync.sh --force <pkg>... # overwrite every emitter-managed
#                                            #   file, including ones that
#                                            #   normally need operator review
#                                            #   (build.zig, .gitignore, …).
#                                            #   Use when onboarding a fresh
#                                            #   package.
#
# By default the helper only overwrites `src/models.zig`. Every other
# emitter-managed file (`src/clients.zig`, `src/enums.zig`,
# `src/root.zig`, `build.zig`, `build.zig.zon`, `README.md`,
# `.gitignore`) is compared byte-wise:
#
#   * identical                → silent
#   * differs from regen output → printed as `  SKIP <file> (operator-managed)`
#
# Hand-managed files outside that list (e.g. `examples/`, `.env`) are
# never touched.
#
# Spec paths come from `codegen/tspconfigs.yaml`. Packages must have a
# non-empty `zig:` field there. Add new entries by running
# `zig build tspconfigs-update`.
#
# Prerequisite: the wasm component already built (`codegen/cli/zig-out/
# bin/codegen-cli.composed.wasm`). The driver `cli/scripts/run.sh`
# expects `../azure-rest-api-specs/` to be a sibling of the repo root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REST_DIR="$ROOT/rest"
TSPCFG="$ROOT/codegen/tspconfigs.yaml"
RUN_SH="$ROOT/codegen/cli/scripts/run.sh"
SPEC_ROOT="$ROOT/../azure-rest-api-specs"

# ── arg parsing ────────────────────────────────────────────────────
FORCE=0
PKGS=()
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --help|-h)
            grep -E '^# ?' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//' | sed -n '2,/^set -euo/p'
            exit 0
            ;;
        --*)
            echo "sync.sh: unknown flag: $arg" >&2
            exit 2
            ;;
        *) PKGS+=("$arg") ;;
    esac
done

if [[ ${#PKGS[@]} -eq 0 ]]; then
    # Default: every existing rest/<pkg>/.
    shopt -s nullglob
    for d in "$REST_DIR"/*/; do
        PKGS+=("$(basename "$d")")
    done
    shopt -u nullglob
    if [[ ${#PKGS[@]} -eq 0 ]]; then
        echo "sync.sh: no packages found under rest/ and none specified" >&2
        exit 1
    fi
fi

# ── resolve zig package name → spec dir via tspconfigs.yaml ────────
# Output format: "<zig_name>\t<spec_dir>" one per line.
SPEC_INDEX="$(python3 - "$TSPCFG" <<'PY'
import os, re, sys

path = sys.argv[1]
with open(path, "r") as fh:
    text = fh.read()

# Minimal parser for the tspconfigs.yaml shape:
#   "specification/.../tspconfig.yaml":
#     js: "..."
#     zig: "..."
spec = None
js = zig = None
out = []

def display_from_js(js_value: str, zig_value: str) -> str:
    """Strip a leading @scope/ from `js` to get the dash-cased label
    (e.g. `@azure/arm-avs` → `arm-avs`). Falls back to the snake-cased
    `zig` value when `js` is empty (data-plane Foundry packages, etc.)
    so the emitter still gets a non-empty display name.
    """
    if not js_value:
        return zig_value
    if js_value.startswith("@"):
        slash = js_value.find("/")
        if slash >= 0:
            return js_value[slash + 1:]
    return js_value

def flush():
    if spec and zig:
        spec_dir = os.path.dirname(spec)
        display = display_from_js(js or "", zig)
        out.append(f"{zig}\t{spec_dir}\t{display}")

for raw in text.splitlines():
    line = raw.rstrip()
    if not line:
        continue
    if not line.startswith(" "):
        flush()
        m = re.match(r'^"(.*)":\s*$', line)
        spec = m.group(1) if m else None
        js = zig = None
        continue
    m = re.match(r'\s+(\w+):\s*"(.*)"\s*$', line)
    if not m:
        continue
    k, v = m.group(1), m.group(2)
    if k == "js":
        js = v
    elif k == "zig":
        zig = v if v else None

flush()

print("\n".join(out))
PY
)"

lookup_spec_dir() {
    local pkg="$1"
    local entry
    entry="$(printf '%s\n' "$SPEC_INDEX" | awk -F'\t' -v p="$pkg" '$1==p {print $2; exit}')"
    if [[ -z "$entry" ]]; then
        return 1
    fi
    printf '%s' "$entry"
}

lookup_display_name() {
    local pkg="$1"
    local entry
    entry="$(printf '%s\n' "$SPEC_INDEX" | awk -F'\t' -v p="$pkg" '$1==p {print $3; exit}')"
    if [[ -z "$entry" ]]; then
        # Shouldn't happen if lookup_spec_dir already succeeded, but be
        # defensive: fall back to the snake-cased package name.
        printf '%s' "$pkg"
        return
    fi
    printf '%s' "$entry"
}

# ── per-file sync policy ───────────────────────────────────────────
#
# `src/models.zig`, `src/root.zig`, and `README.md` are emitter-owned
# end-to-end today: models.zig because the emitter is the source of
# truth for the resource/enum shapes, and root.zig + README.md because
# the emitter honors the dash-cased `--display-name` we derive from
# `tspconfigs.yaml#js` and writes the same label operators used to set
# by hand. Other emitter-touched files still drift from operator
# tweaks (sub-clients in clients.zig, dash-cased addModule keys in
# build.zig.zon, .env in .gitignore, …) so they get the SKIP-and-warn
# treatment unless --force is passed.
SAFE_FILES=("src/models.zig" "src/root.zig" "README.md")
MANAGED_FILES=(
    "src/root.zig"
    "src/clients.zig"
    "src/enums.zig"
    "src/models.zig"
    "build.zig"
    "build.zig.zon"
    "README.md"
    ".gitignore"
)

is_safe() {
    local f="$1"
    for s in "${SAFE_FILES[@]}"; do [[ "$f" == "$s" ]] && return 0; done
    return 1
}

# ── temp dir cleanup ───────────────────────────────────────────────
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# ── main loop ──────────────────────────────────────────────────────
EXIT_CODE=0
for pkg in "${PKGS[@]}"; do
    echo "── $pkg ──────────────────────────────────────"

    pkg_dir="$REST_DIR/$pkg"
    if [[ ! -d "$pkg_dir" ]]; then
        echo "  ERROR: rest/$pkg/ does not exist (use --force to onboard a new package, after creating the dir)"
        EXIT_CODE=1
        continue
    fi

    spec_rel="$(lookup_spec_dir "$pkg" || true)"
    if [[ -z "$spec_rel" ]]; then
        echo "  ERROR: no entry for '$pkg' in tspconfigs.yaml (expected a row with zig: \"$pkg\")"
        EXIT_CODE=1
        continue
    fi
    spec_dir="$SPEC_ROOT/$spec_rel"
    if [[ ! -d "$spec_dir" ]]; then
        echo "  ERROR: spec dir not found: $spec_dir"
        EXIT_CODE=1
        continue
    fi

    out_tmp="$TMPROOT/$pkg"
    mkdir -p "$out_tmp"

    display="$(lookup_display_name "$pkg")"

    echo "  spec: $spec_rel"
    echo "  display: $display"
    echo "  regen: $out_tmp"
    if ! "$RUN_SH" "$spec_dir" "$out_tmp" --package-name "$pkg" --display-name "$display" >"$TMPROOT/$pkg.log" 2>&1; then
        echo "  ERROR: emitter failed; see $TMPROOT/$pkg.log"
        tail -20 "$TMPROOT/$pkg.log" | sed 's/^/    /'
        EXIT_CODE=1
        continue
    fi

    copied=0
    skipped=0
    for f in "${MANAGED_FILES[@]}"; do
        src="$out_tmp/$f"
        dst="$pkg_dir/$f"
        [[ -f "$src" ]] || continue
        if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
            continue
        fi
        if [[ "$FORCE" -eq 1 ]] || is_safe "$f"; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            echo "  COPY $f"
            copied=$((copied + 1))
        else
            echo "  SKIP $f (operator-managed; pass --force to overwrite)"
            skipped=$((skipped + 1))
        fi
    done
    echo "  → $copied copied, $skipped skipped"
done

exit $EXIT_CODE
