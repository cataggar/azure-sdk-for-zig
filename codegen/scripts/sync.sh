#!/usr/bin/env bash
#
# sync.sh — regenerate a REST package from its canonical TypeSpec spec
# into an external package-branch worktree.
#
# Usage:
#
#   codegen/scripts/sync.sh --output-root DIR <pkg>
#                                            # sync one package in an external
#                                            # package-branch worktree
#   codegen/scripts/sync.sh --force --output-root DIR <pkg>
#                                            # overwrite every emitter-managed
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
RUN_SH="$ROOT/codegen/cli/scripts/run.sh"
SPEC_ROOT="$ROOT/../azure-rest-api-specs"

# ── arg parsing ────────────────────────────────────────────────────
FORCE=0
OUTPUT_ROOT=""
AZURE_SDK_CORE_PATH=""
AZURE_SDK_CORE_COMMIT=""
AZURE_SDK_CORE_HASH=""
PKGS=()
while (($#)); do
    case "$1" in
        --force) FORCE=1 ;;
        --output-root)
            OUTPUT_ROOT="$2"
            shift
            ;;
        --azure-sdk-core-path)
            AZURE_SDK_CORE_PATH="$2"
            shift
            ;;
        --azure-sdk-core-commit)
            AZURE_SDK_CORE_COMMIT="$2"
            shift
            ;;
        --azure-sdk-core-hash)
            AZURE_SDK_CORE_HASH="$2"
            shift
            ;;
        --help|-h)
            grep -E '^# ?' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//' | sed -n '2,/^set -euo/p'
            exit 0
            ;;
        --*)
            echo "sync.sh: unknown flag: $1" >&2
            exit 2
            ;;
        *) PKGS+=("$1") ;;
    esac
    shift
done

if [[ ${#PKGS[@]} -eq 0 ]]; then
    echo "sync.sh: specify one package and --output-root" >&2
    exit 2
fi

if [[ ${#PKGS[@]} -ne 1 ]]; then
    echo "sync.sh: --output-root requires exactly one package" >&2
    exit 2
fi
if [[ -z "$OUTPUT_ROOT" ]]; then
    echo "sync.sh: Main contains no generated package source; --output-root is required" >&2
    exit 2
fi
if [[ -n "$AZURE_SDK_CORE_PATH" &&
    ( -n "$AZURE_SDK_CORE_COMMIT" || -n "$AZURE_SDK_CORE_HASH" ) ]]; then
    echo "sync.sh: use a core path or an immutable core pin, not both" >&2
    exit 2
fi
if [[ -n "$AZURE_SDK_CORE_COMMIT" || -n "$AZURE_SDK_CORE_HASH" ]]; then
    if [[ -z "$AZURE_SDK_CORE_COMMIT" || -z "$AZURE_SDK_CORE_HASH" ]]; then
        echo "sync.sh: core commit and hash must be supplied together" >&2
        exit 2
    fi
fi
if [[ -z "$AZURE_SDK_CORE_PATH" &&
    -z "$AZURE_SDK_CORE_COMMIT" ]]; then
    echo "sync.sh: external output requires an explicit core path or immutable pin" >&2
    exit 2
fi
OUTPUT_ROOT="$(cd "$(dirname "$OUTPUT_ROOT")" && pwd)/$(basename "$OUTPUT_ROOT")"

# ── resolve zig package name → spec dir via tspconfigs.yaml ────────
# Output format: "<zig_name>\t<spec_dir>" one per line.
SPEC_INDEX="$(cd "$ROOT" && zig run codegen/tspconfigs/main.zig -- list)"

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
# `src/models.zig`, `src/root.zig`, `src/clients.zig`, `src/enums.zig`,
# and `README.md` are emitter-owned end-to-end today: the emitter is the
# source of truth for the resource/enum shapes and the client tree
# (root + sub-clients + operation bodies), and it honors the dash-cased
# `--display-name` we derive from `tspconfigs.yaml#js` so root.zig and
# README.md no longer drift from operator tweaks. Other emitter-touched
# files (`build.zig`, `build.zig.zon`, `.gitignore`) still drift
# (operator-managed module wiring, .env in .gitignore, …) so they get
# the SKIP-and-warn treatment unless --force is passed.
SAFE_FILES=("src/models.zig" "src/root.zig" "src/clients.zig" "src/enums.zig" "README.md")
MANAGED_FILES=(
    "src/root.zig"
    "src/clients.zig"
    "src/clients_test.zig"
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

    pkg_dir="$OUTPUT_ROOT"
    if [[ ! -d "$pkg_dir" ]]; then
        echo "  ERROR: package output does not exist: $pkg_dir"
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
    package_name="azure_rest_$pkg"

    echo "  spec: $spec_rel"
    echo "  display: $display"
    echo "  package: $package_name"
    echo "  regen: $out_tmp"
    core_args=()
    if [[ -n "$AZURE_SDK_CORE_COMMIT" ]]; then
        core_args=(
            --azure-sdk-core-commit "$AZURE_SDK_CORE_COMMIT"
            --azure-sdk-core-hash "$AZURE_SDK_CORE_HASH"
        )
    else
        core_args=(
            --azure-sdk-core-path "${AZURE_SDK_CORE_PATH:-../../sdk/core}"
        )
    fi
    if ! "$RUN_SH" "$spec_dir" "$out_tmp" \
        --package-name "$package_name" \
        --display-name "$display" \
        "${core_args[@]}" >"$TMPROOT/$pkg.log" 2>&1; then
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
        # Seed missing files unconditionally so brand-new operator-owned
        # files (e.g. `src/clients_test.zig`) don't need `--force` on
        # first regen. SAFE_FILES are still overwritten when they
        # differ. Everything else gets the SKIP-and-warn treatment.
        if [[ ! -f "$dst" ]] || [[ "$FORCE" -eq 1 ]] || is_safe "$f"; then
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
