#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH="$ROOT/.release/container_registry/regeneration"
CODEGEN_ZIG_PKG="$ROOT/codegen/cli/zig-pkg"
ZIG_PKG_EXISTED=0
if [[ -e "$CODEGEN_ZIG_PKG" ]]; then
  ZIG_PKG_EXISTED=1
fi

cleanup() {
  local status=$?
  trap - EXIT
  rm -rf "$SCRATCH"
  if [[ "$ZIG_PKG_EXISTED" == 0 ]]; then
    rm -rf "$CODEGEN_ZIG_PKG"
  fi
  exit "$status"
}
trap cleanup EXIT

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

snapshot_tree() {
  local path="$1"
  local output="$2"
  (
    cd "$ROOT"
    git ls-files --cached --others --exclude-standard -z -- "$path" |
      python3 -c '
import hashlib
from pathlib import Path
import sys

paths = sorted(filter(None, sys.stdin.buffer.read().split(b"\0")))
for raw in paths:
    path = Path(raw.decode())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    print(f"{digest}  {path.as_posix()}")
'
  ) >"$output"
}

snapshot_status() {
  local output="$1"
  (
    cd "$ROOT"
    git status --porcelain=v1 --untracked-files=all |
      python3 -c '
import sys

allowed = ("rest/container_registry/", "codegen/fixtures/container_registry.json")
for line in sys.stdin:
    path = line[3:].strip()
    if " -> " in path:
        path = path.split(" -> ", 1)[1]
    if path.startswith(allowed[0]) or path == allowed[1]:
        continue
    print(line, end="")
'
  ) >"$output"
}

snapshot_tree "rest/container_registry" "$SCRATCH/rest.before"
snapshot_tree "sdk/container_registry" "$SCRATCH/sdk.before"
snapshot_status "$SCRATCH/status.before"

(
  cd "$ROOT/codegen/cli"
  zig build \
    --cache-dir "$SCRATCH/codegen-cache" \
    --global-cache-dir "$SCRATCH/global-cache" \
    generate-container-registry-package
)

snapshot_tree "rest/container_registry" "$SCRATCH/rest.after"
snapshot_tree "sdk/container_registry" "$SCRATCH/sdk.after"
snapshot_status "$SCRATCH/status.after"

if ! cmp -s "$SCRATCH/sdk.before" "$SCRATCH/sdk.after"; then
  echo "ERROR: ACR regeneration modified handwritten sdk/container_registry files." >&2
  diff -u "$SCRATCH/sdk.before" "$SCRATCH/sdk.after" || true
  exit 1
fi
if ! cmp -s "$SCRATCH/status.before" "$SCRATCH/status.after"; then
  echo "ERROR: ACR regeneration changed files outside generator-owned REST outputs." >&2
  diff -u "$SCRATCH/status.before" "$SCRATCH/status.after" || true
  exit 1
fi
if ! cmp -s "$SCRATCH/rest.before" "$SCRATCH/rest.after"; then
  echo "ERROR: rest/container_registry is not deterministic; inspect generator drift." >&2
  diff -u "$SCRATCH/rest.before" "$SCRATCH/rest.after" || true
  (cd "$ROOT" && git --no-pager diff -- rest/container_registry) || true
  exit 1
fi

python3 - "$ROOT/rest/container_registry" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
zon = (root / "build.zig.zon").read_text()
build = (root / "build.zig").read_text()
if ".name = .azure_rest_container_registry," not in zon:
    raise SystemExit("ERROR: regenerated REST package name drifted")
if 'addModule("azure_rest_container_registry"' not in build:
    raise SystemExit("ERROR: regenerated REST module name drifted")
PY

echo "ACR regeneration is deterministic and isolated to generator-owned REST outputs."
