#!/usr/bin/env bash
#
# build-engine.sh — build a custom StarlingMonkey embedding wasm for
# componentize-js with a bumped SpiderMonkey GC max-heap.
#
# The upstream `@bytecodealliance/componentize-js` ships a
# `starlingmonkey_embedding.wasm` whose SpiderMonkey context is
# created with the default 32 MiB GC heap cap:
#
#     // StarlingMonkey/runtime/engine.cpp
#     JSContext *cx = JS_NewContext(JS::DefaultHeapMaxBytes);
#
# TypeSpec compiling large Azure ARM specs (e.g. Microsoft.AVS) blows
# past that cap and aborts with `mozalloc_abort`. The cap is baked
# into the precompiled wasm — no runtime knob (env var, wasmtime
# flag, runtimeArgs) overrides it.
#
# This script clones `bytecodealliance/ComponentizeJS` at the same
# tag we depend on (matches `package.json#dependencies`), swaps the
# StarlingMonkey submodule for our fork's `bump-heap-1gib` branch
# (which raises the cap to 1 GiB — see
# https://github.com/cataggar/StarlingMonkey/pull/3), builds the
# `starlingmonkey_embedding` cmake target, and copies the result
# to `engine/starlingmonkey_embedding.wasm` next to `tcgc.wasm`.
#
# `build-component.mjs` auto-detects this file. Set
# `STARLINGMONKEY_ENGINE=/path/to/wasm` to override.
#
# Requirements: cmake (4.x), rustup, clang. First-time build is
# ~3 minutes on Apple Silicon; subsequent rebuilds skip the
# OpenSSL/SpiderMonkey download steps and finish in seconds.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${COMPONENTIZE_JS_CACHE:-$REPO_ROOT/.engine-build}"

# Pin to the same componentize-js version we depend on at runtime.
# Bump when bumping `@bytecodealliance/componentize-js` in
# `package.json`. The splicer in the runtime npm package is the one
# that consumes this engine wasm — they must agree on the embedding
# ABI, so the tag MUST match the installed npm version.
PIN="${COMPONENTIZE_JS_TAG:-0.20.0}"

# Our patched StarlingMonkey fork. The branch is rebased on top of
# the commit that `ComponentizeJS@$PIN` pins for its StarlingMonkey
# submodule; if that pin moves when bumping `$PIN`, the branch needs
# to be rebased before this script will pass the sanity check below.
STARLINGMONKEY_FORK_URL="${STARLINGMONKEY_FORK_URL:-https://github.com/cataggar/StarlingMonkey.git}"
STARLINGMONKEY_REF="${STARLINGMONKEY_REF:-bump-heap-1gib}"

OUT_DIR="$REPO_ROOT/engine"
OUT_WASM="$OUT_DIR/starlingmonkey_embedding.wasm"

mkdir -p "$OUT_DIR" "$CACHE_DIR"

# ── 1. Fetch ComponentizeJS at the pinned tag ─────────────────────
if [[ ! -d "$CACHE_DIR/ComponentizeJS/.git" ]]; then
    echo "→ clone bytecodealliance/ComponentizeJS @ $PIN"
    git clone --depth 1 --branch "$PIN" \
        https://github.com/bytecodealliance/ComponentizeJS.git \
        "$CACHE_DIR/ComponentizeJS"
fi

cd "$CACHE_DIR/ComponentizeJS"
git fetch --depth 1 origin "tag" "$PIN" 2>/dev/null \
    || git fetch --depth 1 origin "$PIN" 2>/dev/null \
    || true
git checkout -f "$PIN"

# Record the StarlingMonkey commit ComponentizeJS expects; we use
# this below to verify our fork's branch is rebased on it.
EXPECTED_SM_COMMIT="$(git ls-tree HEAD StarlingMonkey | awk '{print $3}')"
if [[ -z "$EXPECTED_SM_COMMIT" ]]; then
    echo "error: cannot determine StarlingMonkey submodule pin from ComponentizeJS@$PIN" >&2
    exit 1
fi
echo "  ComponentizeJS@$PIN pins StarlingMonkey at $EXPECTED_SM_COMMIT"

# ── 2. Clone our patched fork into the submodule path ─────────────
#
# We bypass the submodule machinery entirely so we can land on a
# branch tip rather than the pinned commit. The directory layout
# after this step matches what `git submodule update` would have
# produced — CMake/Make targets in ComponentizeJS resolve
# `StarlingMonkey/...` paths relative to the project root.
SM_DIR="StarlingMonkey"
if [[ ! -d "$SM_DIR/.git" ]]; then
    echo "→ clone $STARLINGMONKEY_FORK_URL ($STARLINGMONKEY_REF)"
    rm -rf "$SM_DIR"
    git clone --branch "$STARLINGMONKEY_REF" \
        "$STARLINGMONKEY_FORK_URL" "$SM_DIR"
else
    echo "→ refresh existing $SM_DIR checkout to $STARLINGMONKEY_REF"
    git -C "$SM_DIR" fetch origin "$STARLINGMONKEY_REF"
    git -C "$SM_DIR" checkout -f "$STARLINGMONKEY_REF"
    git -C "$SM_DIR" reset --hard "origin/$STARLINGMONKEY_REF"
fi

# Verify the fork's branch is rebased on the commit ComponentizeJS
# pins. If not, the embedding ABI may be skewed against the splicer
# and the resulting wasm will fail to compose.
if ! git -C "$SM_DIR" merge-base --is-ancestor "$EXPECTED_SM_COMMIT" HEAD; then
    echo "error: $STARLINGMONKEY_REF does not include $EXPECTED_SM_COMMIT" >&2
    echo "  ($STARLINGMONKEY_REF must be rebased on the commit that" >&2
    echo "   ComponentizeJS@$PIN pins as its StarlingMonkey submodule)" >&2
    exit 1
fi

# Initialise StarlingMonkey's own submodules (e.g. third-party WPT
# suite). `git submodule update --init --recursive` reads
# `.gitmodules` from the fork's checked-out tree.
git -C "$SM_DIR" submodule update --init --recursive --depth 1

# ── 3. Build ──────────────────────────────────────────────────────
echo "→ cmake -B build-release"
cmake -S . -B build-release -DCMAKE_BUILD_TYPE=Release

NCPU="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
echo "→ build starlingmonkey_embedding (parallel $NCPU)"
make -j"$NCPU" -C build-release starlingmonkey_embedding

cp lib/starlingmonkey_embedding.wasm "$OUT_WASM"
echo "✓ engine wasm written: $OUT_WASM ($(wc -c <"$OUT_WASM") bytes)"
