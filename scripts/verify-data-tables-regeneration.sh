#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REST_PACKAGE_ROOT=""

while (($#)); do
  case "$1" in
    --rest-package-root)
      REST_PACKAGE_ROOT="$2"
      shift 2
      ;;
    *)
      echo "usage: verify-data-tables-regeneration.sh --rest-package-root PATH" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REST_PACKAGE_ROOT" ]]; then
  echo "usage: verify-data-tables-regeneration.sh --rest-package-root PATH" >&2
  exit 2
fi

SCRATCH="$ROOT/.release/data_tables/regeneration"
cleanup() {
  local status=$?
  trap - EXIT
  rm -rf "$SCRATCH"
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
        if command -v shasum >/dev/null 2>&1; then
          shasum -a 256 "${file#./}"
        else
          sha256sum "${file#./}"
        fi
      done
  ) >"$output"
}

snapshot_tree "$REST_PACKAGE_ROOT" "$SCRATCH/rest.before"
dependency="$(
  cd "$ROOT"
  zig run eng/package_branch_tool.zig -- \
    dependencies azure_rest_data_tables "$REST_PACKAGE_ROOT"
)"
core_url="$(cut -f2 <<<"$dependency")"
core_hash="$(cut -f3 <<<"$dependency")"
core_commit="${core_url##*#}"

(
  cd "$ROOT/codegen/cli"
  zig build \
    --cache-dir "$SCRATCH/codegen-cache" \
    --global-cache-dir "$SCRATCH/global-cache" \
    -Ddata-tables-output="$SCRATCH/generated-rest" \
    -Dazure-sdk-core-commit="$core_commit" \
    -Dazure-sdk-core-hash="$core_hash" \
    generate-data-tables-package
)

snapshot_tree "$SCRATCH/generated-rest" "$SCRATCH/rest.after"
if ! cmp -s "$SCRATCH/rest.before" "$SCRATCH/rest.after"; then
  echo "ERROR: rest/data_tables is not deterministic; inspect generator drift." >&2
  diff -u "$SCRATCH/rest.before" "$SCRATCH/rest.after" || true
  exit 1
fi

grep -Fq ".name = .azure_rest_data_tables," \
  "$SCRATCH/generated-rest/build.zig.zon" ||
  {
    echo "ERROR: regenerated REST package name drifted" >&2
    exit 1
  }
grep -Fq 'addModule("azure_rest_data_tables"' \
  "$SCRATCH/generated-rest/build.zig" ||
  {
    echo "ERROR: regenerated REST module name drifted" >&2
    exit 1
  }

echo "Azure Tables regeneration is deterministic."
