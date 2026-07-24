#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERIC="$ROOT/scripts/package-release.sh"
BRANCH_RELEASE="$ROOT/scripts/package-branch-release.sh"
REST_PACKAGE="azure_rest_container_registry"
SDK_PACKAGE="azure_sdk_container_registry"

usage() {
  cat <<'EOF'
Container Registry compatibility wrapper

Preferred commands:
  scripts/package-branch-release.sh verify azure_rest_container_registry
  scripts/package-branch-release.sh publish azure_rest_container_registry
  scripts/package-branch-release.sh publish azure_rest_container_registry --execute
  scripts/package-branch-release.sh verify azure_sdk_container_registry
  scripts/package-branch-release.sh publish azure_sdk_container_registry
  scripts/package-branch-release.sh publish azure_sdk_container_registry --execute

Legacy aliases retained:
  verify | dry-run
  prepare-rest | prepare-sdk (rejected; branch packages have no prepare stage)
  publish-rest [--dry-run] [--remote <remote>]
  publish-sdk [--dry-run] [--remote <remote>]
  self-test
EOF
}

publish_compat() {
  local package="$1"
  shift
  local dry_run=false
  local execute=false
  local forwarded=()
  while (($#)); do
    case "$1" in
      --dry-run)
        dry_run=true
        ;;
      --execute)
        execute=true
        ;;
      *)
        forwarded+=("$1")
        ;;
    esac
    shift
  done
  if $dry_run && $execute; then
    echo "--dry-run cannot be combined with --execute" >&2
    exit 2
  fi
  if ! $dry_run; then
    execute=true
  fi
  if $execute; then
    forwarded+=("--execute")
  fi
  if ((${#forwarded[@]})); then
    exec "$BRANCH_RELEASE" publish "$package" "${forwarded[@]}"
  fi
  exec "$BRANCH_RELEASE" publish "$package"
}

command="${1:-}"
case "$command" in
  verify|dry-run)
    "$BRANCH_RELEASE" verify "$REST_PACKAGE"
    "$BRANCH_RELEASE" verify "$SDK_PACKAGE"
    ;;
  prepare-rest|prepare-sdk)
    echo "Container Registry packages are branch-owned and have no prepare stage." >&2
    exit 2
    ;;
  publish-rest)
    shift
    publish_compat "$REST_PACKAGE" "$@"
    ;;
  publish-sdk)
    shift
    publish_compat "$SDK_PACKAGE" "$@"
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
