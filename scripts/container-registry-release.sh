#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METADATA="$ROOT/eng/container_registry_release/metadata.sh"
STAGE_ROOT="$ROOT/.release/container_registry"
# shellcheck source=/dev/null
source "$METADATA"

usage() {
  cat <<'EOF'
Usage:
  scripts/container-registry-release.sh hash-check
  scripts/container-registry-release.sh verify
  scripts/container-registry-release.sh dry-run
  scripts/container-registry-release.sh prepare-rest
  scripts/container-registry-release.sh prepare-sdk <rest-commit> [rest-hash]

All generated files stay under ignored .release/container_registry. No branch,
tag, commit, or remote ref is created or changed.
EOF
}

fetch_hash() {
  zig fetch "$1"
}

check_hash() {
  local url="$1"
  local expected="$2"
  local actual
  actual="$(fetch_hash "$url")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'package hash mismatch\n  URL:      %s\n  expected: %s\n  actual:   %s\n' \
      "$url" "$expected" "$actual" >&2
    exit 1
  fi
}

validate_identity() {
  local directory="$1"
  local package="$2"
  python3 - "$directory" "$package" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
package = sys.argv[2]
zon = (root / "build.zig.zon").read_text()
build = (root / "build.zig").read_text()
if not re.search(rf"\.name\s*=\s*\.{re.escape(package)}\s*,", zon):
    raise SystemExit(f"{root}: build.zig.zon package name is not {package}")
if f'addModule("{package}"' not in build:
    raise SystemExit(f"{root}: build.zig module name is not {package}")
if package == "azure_sdk_container_registry":
    if '.azure_rest_container_registry = .{' not in zon:
        raise SystemExit(f"{root}: missing azure_rest_container_registry dependency")
    if 'module("azure_rest_container_registry")' not in build:
        raise SystemExit(f"{root}: missing azure_rest_container_registry module import")
print(f"verified package/module identity: {package}")
PY
}

generate_rest() {
  local output="$1"
  rm -rf "$output"
  mkdir -p "$(dirname "$output")"
  (
    cd "$ROOT/codegen/cli"
    zig build generate-container-registry-package \
      -Dcontainer-registry-output="$output" \
      -Dazure-core-commit="$AZURE_SDK_COMMIT" \
      -Dazure-core-hash="$AZURE_SDK_HASH"
  )
}

stage_sdk() {
  local output="$1"
  local rest_mode="$2"
  local rest_commit="${3:-}"
  local rest_hash="${4:-}"
  rm -rf "$output"
  mkdir -p "$output"
  cp \
    "$ROOT/sdk/container_registry/build.zig" \
    "$ROOT/sdk/container_registry/build.zig.zon" \
    "$ROOT/sdk/container_registry/README.md" \
    "$output/"
  cp -R \
    "$ROOT/sdk/container_registry/src" \
    "$ROOT/sdk/container_registry/examples" \
    "$ROOT/sdk/container_registry/live_tests" \
    "$output/"
  python3 - "$output/build.zig.zon" "$rest_mode" \
    "$AZURE_SDK_URL" "$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH" \
    "$rest_commit" "$rest_hash" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
mode, sdk_url, sdk_commit, sdk_hash, rest_commit, rest_hash = sys.argv[2:]
text = path.read_text()
sdk_old = '''        .azure_sdk = .{
            .path = "../..",
        },'''
sdk_new = f'''        .azure_sdk = .{{
            .url = "{sdk_url}#{sdk_commit}",
            .hash = "{sdk_hash}",
        }},'''
if text.count(sdk_old) != 1:
    raise SystemExit(f"{path}: expected one local azure_sdk dependency")
text = text.replace(sdk_old, sdk_new)

rest_old = '''        .azure_rest_container_registry = .{
            .path = "../../rest/container_registry",
        },'''
if mode == "local":
    rest_new = '''        .azure_rest_container_registry = .{
            .path = "../rest",
        },'''
elif mode == "published":
    if not rest_commit or not rest_hash:
        raise SystemExit("published REST staging requires commit and hash")
    rest_new = f'''        .azure_rest_container_registry = .{{
            .url = "{sdk_url}#{rest_commit}",
            .hash = "{rest_hash}",
        }},'''
else:
    raise SystemExit(f"unknown REST dependency mode: {mode}")
if text.count(rest_old) != 1:
    raise SystemExit(f"{path}: expected one local REST dependency")
path.write_text(text.replace(rest_old, rest_new))
PY
}

test_rest() {
  local directory="$1"
  validate_identity "$directory" "$REST_PACKAGE"
  (cd "$directory" && zig build test --summary all)
}

test_sdk() {
  local directory="$1"
  validate_identity "$directory" "$SDK_PACKAGE"
  (
    cd "$directory"
    zig build test --summary all
    zig build examples
    env \
      -u AZURE_CONTAINER_REGISTRY_LIVE_TESTS \
      -u AZURE_CONTAINER_REGISTRY_ENDPOINT \
      -u AZURE_CONTAINER_REGISTRY_LIVE_TEST_RUN_ID \
      -u AZURE_CONTAINER_REGISTRY_LIVE_TEST_REPOSITORY_PREFIX \
      zig build live-test --summary all
  )
}

verify_local_stage() {
  local stage="$STAGE_ROOT/verify"
  rm -rf "$stage"
  mkdir -p "$stage"
  check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
  generate_rest "$stage/rest"
  stage_sdk "$stage/sdk" local
  test_rest "$stage/rest"
  test_sdk "$stage/sdk"
  printf 'release dry-run verified at %s\n' "$stage"
}

command="${1:-}"
case "$command" in
  hash-check)
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    printf 'verified immutable azure_sdk pin %s\n' "$AZURE_SDK_COMMIT"
    ;;
  verify|dry-run)
    verify_local_stage
    ;;
  prepare-rest)
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    output="$STAGE_ROOT/publish/rest"
    generate_rest "$output"
    test_rest "$output"
    printf 'REST release package ready: %s\n' "$output"
    printf 'Publish it first to %s, then prepare the SDK with that commit.\n' \
      "$REST_BRANCH"
    ;;
  prepare-sdk)
    rest_commit="${2:-}"
    if [[ ! "$rest_commit" =~ ^[0-9a-f]{40}$ ]]; then
      printf 'prepare-sdk requires a full 40-character REST commit ID\n' >&2
      exit 1
    fi
    rest_url="$AZURE_SDK_URL#$rest_commit"
    computed_hash="$(fetch_hash "$rest_url")"
    supplied_hash="${3:-$computed_hash}"
    if [[ "$computed_hash" != "$supplied_hash" ]]; then
      printf 'REST package hash mismatch\n  computed: %s\n  supplied: %s\n' \
        "$computed_hash" "$supplied_hash" >&2
      exit 1
    fi
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    output="$STAGE_ROOT/publish/sdk"
    stage_sdk "$output" published "$rest_commit" "$computed_hash"
    test_sdk "$output"
    printf 'SDK release package ready: %s\n' "$output"
    printf 'Pinned REST commit: %s\nPinned REST hash: %s\n' \
      "$rest_commit" "$computed_hash"
    ;;
  *)
    usage
    exit 2
    ;;
esac
