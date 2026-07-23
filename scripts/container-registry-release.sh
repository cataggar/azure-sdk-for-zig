#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERIC="$ROOT/scripts/package-release.sh"
REST_PACKAGE="azure_rest_container_registry"
SDK_PACKAGE="azure_sdk_container_registry"
STAGE_ROOT="${PACKAGE_RELEASE_ROOT:-$ROOT/.release/packages}"

usage() {
  cat <<'EOF'
Container Registry compatibility wrapper

Preferred commands:
  scripts/package-release.sh verify azure_rest_container_registry
  scripts/package-release.sh prepare azure_rest_container_registry
  scripts/package-release.sh publish azure_rest_container_registry --dry-run
  scripts/package-release.sh publish azure_rest_container_registry
  scripts/package-release.sh verify azure_sdk_container_registry
  scripts/package-release.sh prepare azure_sdk_container_registry
  scripts/package-release.sh publish azure_sdk_container_registry --dry-run
  scripts/package-release.sh publish azure_sdk_container_registry

Legacy aliases retained:
  verify | dry-run
  prepare-rest
  prepare-sdk [rest-commit [rest-hash]]
  publish-rest [--dry-run] [--remote <remote>]
  publish-sdk [--dry-run] [--remote <remote>]
  self-test
EOF
}

check_requested_rest_pin() {
  local requested_commit="${1:-}"
  local requested_hash="${2:-}"
  [[ -z "$requested_commit" ]] && return
  python3 - \
    "$STAGE_ROOT/$SDK_PACKAGE/stage-manifest.json" \
    "$requested_commit" "$requested_hash" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text())
pin = next(
    dependency
    for dependency in manifest["dependencies"]
    if dependency["name"] == "azure_rest_container_registry"
)
if pin["commit"] != sys.argv[2]:
    raise SystemExit(
        f"requested REST commit {sys.argv[2]} differs from resolved {pin['commit']}"
    )
if sys.argv[3] and pin["hash"] != sys.argv[3]:
    raise SystemExit(
        f"requested REST hash {sys.argv[3]} differs from resolved {pin['hash']}"
    )
PY
}

command="${1:-}"
case "$command" in
  verify|dry-run)
    "$GENERIC" verify "$REST_PACKAGE"
    "$GENERIC" verify "$SDK_PACKAGE"
    ;;
  prepare-rest)
    "$GENERIC" prepare "$REST_PACKAGE"
    ;;
  prepare-sdk)
    "$GENERIC" prepare "$SDK_PACKAGE"
    check_requested_rest_pin "${2:-}" "${3:-}"
    ;;
  publish-rest)
    shift
    exec "$GENERIC" publish "$REST_PACKAGE" "$@"
    ;;
  publish-sdk)
    shift
    exec "$GENERIC" publish "$SDK_PACKAGE" "$@"
    ;;
  self-test)
    exec "$GENERIC" self-test
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    printf 'unknown legacy Container Registry release command: %s\n' "$command" >&2
    usage >&2
    exit 2
    ;;
esac
