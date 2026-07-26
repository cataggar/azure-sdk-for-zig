#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$(mktemp -d)"
trap 'rm -rf "$BIN_DIR"' EXIT
zig build-exe "$ROOT/eng/release/main.zig" -femit-bin="$BIN_DIR/package-release" >/dev/null
exec "$BIN_DIR/package-release" "$@"
