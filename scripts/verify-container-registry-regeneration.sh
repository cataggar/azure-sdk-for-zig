#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REST_PACKAGE_ROOT=""
SDK_PACKAGE_ROOT=""

while (($#)); do
  case "$1" in
    --rest-package-root)
      REST_PACKAGE_ROOT="$2"
      shift 2
      ;;
    --sdk-package-root)
      SDK_PACKAGE_ROOT="$2"
      shift 2
      ;;
    *)
      echo "usage: verify-container-registry-regeneration.sh " \
        "--rest-package-root PATH --sdk-package-root PATH" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REST_PACKAGE_ROOT" || -z "$SDK_PACKAGE_ROOT" ]]; then
  echo "usage: verify-container-registry-regeneration.sh " \
    "--rest-package-root PATH --sdk-package-root PATH" >&2
  exit 2
fi

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
    cd "$path"
    find . -type f \
      ! -path './.git/*' \
      ! -path './.github/*' \
      ! -path './.gitattributes' \
      ! -path './.migration/*' \
      ! -path './.azure-sdk-generator' \
      ! -path '*/.zig-cache/*' \
      ! -path '*/zig-cache/*' \
      ! -path '*/zig-out/*' \
      ! -path '*/zig-pkg/*' \
      -print |
      LC_ALL=C sort |
      while IFS= read -r file; do
        shasum -a 256 "${file#./}"
      done
  ) >"$output"
}

snapshot_status() {
  local output="$1"
  (
    cd "$ROOT"
    git status --porcelain=v1 --untracked-files=all
  ) >"$output"
}

snapshot_tree "$REST_PACKAGE_ROOT" "$SCRATCH/rest.before"
snapshot_tree "$SDK_PACKAGE_ROOT" "$SCRATCH/sdk.before"
snapshot_status "$SCRATCH/status.before"

dependency="$(
  cd "$ROOT"
  zig run eng/package_branch_tool.zig -- \
    dependencies azure_rest_container_registry "$REST_PACKAGE_ROOT"
)"
core_url="$(cut -f2 <<<"$dependency")"
core_hash="$(cut -f3 <<<"$dependency")"
core_commit="${core_url##*#}"
codegen_args=(
  -Dcontainer-registry-output="$SCRATCH/generated-rest"
  -Dazure-sdk-core-commit="$core_commit"
  -Dazure-sdk-core-hash="$core_hash"
)

(
  cd "$ROOT/codegen/cli"
  zig build \
    --cache-dir "$SCRATCH/codegen-cache" \
    --global-cache-dir "$SCRATCH/global-cache" \
    "${codegen_args[@]}" \
    generate-container-registry-package
)

snapshot_tree "$SCRATCH/generated-rest" "$SCRATCH/rest.after"
snapshot_tree "$SDK_PACKAGE_ROOT" "$SCRATCH/sdk.after"
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
  exit 1
fi

grep -Fq ".name = .azure_rest_container_registry," \
  "$SCRATCH/generated-rest/build.zig.zon" ||
  {
    echo "ERROR: regenerated REST package name drifted" >&2
    exit 1
  }
grep -Fq 'addModule("azure_rest_container_registry"' \
  "$SCRATCH/generated-rest/build.zig" ||
  {
    echo "ERROR: regenerated REST module name drifted" >&2
    exit 1
  }

echo "ACR regeneration is deterministic and isolated to generator-owned REST outputs."
