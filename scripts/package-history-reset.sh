#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_OUTPUT="$ROOT/.release/package-reset"
FILTER_REPO="${PACKAGE_HISTORY_FILTER_REPO:-git-filter-repo}"
EXPECTED_FILTER_REPO_VERSION="$(tr -d '[:space:]' < "$ROOT/eng/git-filter-repo.version")"

usage() {
  cat >&2 <<'EOF'
usage: package-history-reset.sh MODE [OPTIONS]

Modes:
  analyze
  build-candidates [--package NAME|--example NAME] [--source COMMIT] [--output DIR] [--remote REMOTE]
  verify-candidates [--package NAME|--example NAME] [--output DIR]
  archive|cutover|verify-remote|rollback [--manifest PATH] [--execute]

archive, cutover, verify-remote, and rollback are sealed-manifest operations.
They remain preview-only until Phase 2 produces the reviewed ref manifest.
EOF
}

history_tool() {
  (cd "$ROOT" && zig run eng/package_history_tool.zig -- "$@")
}

require_filter_repo() {
  if ! command -v "$FILTER_REPO" >/dev/null 2>&1 && [[ ! -x "$FILTER_REPO" ]]; then
    echo "git-filter-repo is required; expected version $EXPECTED_FILTER_REPO_VERSION" >&2
    exit 1
  fi
  local actual
  actual="$("$FILTER_REPO" --version)"
  if [[ "$actual" != "$EXPECTED_FILTER_REPO_VERSION" ]]; then
    echo "git-filter-repo version mismatch: expected $EXPECTED_FILTER_REPO_VERSION, found $actual" >&2
    exit 1
  fi
}

candidate_targets() {
  local requested_package="$1"
  local requested_example="$2"
  if [[ -n "$requested_package" && -n "$requested_example" ]]; then
    echo "--package and --example are mutually exclusive" >&2
    exit 2
  fi
  if [[ -n "$requested_package" ]]; then
    history_tool paths "$requested_package" >/dev/null
    printf 'package\t%s\n' "$requested_package"
  elif [[ -n "$requested_example" ]]; then
    history_tool example-paths "$requested_example" >/dev/null
    printf 'example\t%s\n' "$requested_example"
  else
    history_tool list | cut -f1 | awk '{ print "package\t" $0 }'
    history_tool example-list | cut -f1 | awk '{ print "example\t" $0 }'
  fi
}

target_key() {
  local kind="$1"
  local name="$2"
  if [[ "$kind" == package ]]; then
    printf '%s\n' "$name"
  else
    printf 'example-%s\n' "$name"
  fi
}

target_paths() {
  local kind="$1"
  local name="$2"
  if [[ "$kind" == package ]]; then
    history_tool paths "$name"
  else
    history_tool example-paths "$name"
  fi
}

target_branch() {
  local kind="$1"
  local name="$2"
  if [[ "$kind" == package ]]; then
    history_tool list |
      awk -F '\t' -v name="$name" '$1 == name { print $2 }'
  else
    history_tool example-list |
      awk -F '\t' -v name="$name" '$1 == name { print $2 }'
  fi
}

target_current_root() {
  local kind="$1"
  local name="$2"
  if [[ "$kind" == package ]]; then
    local root
    root="$(history_tool paths "$name" | head -1 | cut -f1)"
    printf '%s\n' "${root%/}"
  else
    history_tool example-current-root "$name"
  fi
}

write_mapping_history() {
  local kind="$1"
  local name="$2"
  local source_commit="$3"
  local commit_map="$4"
  local output="$5"
  : >"$output"
  while IFS=$'\t' read -r source destination; do
    local source_count mapped_count
    source_count="$(git -C "$ROOT" rev-list --count "$source_commit" -- "$source")"
    [[ "$source_count" -gt 0 ]] || {
      echo "$kind $name: history mapping matched no source commits: $source" >&2
      exit 1
    }
    mapped_count="$(
      git -C "$ROOT" rev-list "$source_commit" -- "$source" |
        awk '
          NR == FNR {
            if ($1 != "old" && $2 !~ /^0+$/) mapped[$1] = 1
            next
          }
          mapped[$1] { count += 1 }
          END { print count + 0 }
        ' "$commit_map" -
    )"
    [[ "$mapped_count" -gt 0 ]] || {
      echo "$kind $name: history mapping retained no commits: $source" >&2
      exit 1
    }
    printf '%s\t%s\t%s\t%s\n' \
      "$source" "$destination" "$source_count" "$mapped_count" >>"$output"
  done < <(target_paths "$kind" "$name")
}

build_candidate() {
  local kind="$1"
  local name="$2"
  local source_commit="$3"
  local output="$4"
  local branch candidate_dir repository current_root key
  branch="$(target_branch "$kind" "$name")"
  [[ -n "$branch" ]] || {
    echo "unknown history target: $kind $name" >&2
    exit 1
  }
  current_root="$(target_current_root "$kind" "$name")"
  key="$(target_key "$kind" "$name")"
  candidate_dir="$output/candidates/$key"
  repository="$candidate_dir/repository"

  rm -rf "$candidate_dir"
  mkdir -p "$candidate_dir"
  git clone --quiet --no-local --no-checkout "$ROOT" "$repository"
  git -C "$repository" switch --quiet --detach "$source_commit"
  git -C "$repository" branch package-history-candidate

  local -a filter_args
  filter_args=(--force --refs refs/heads/package-history-candidate)
  while IFS=$'\t' read -r source destination; do
    filter_args+=(--path "$source" --path-rename "$source:$destination")
  done < <(target_paths "$kind" "$name" | tee "$candidate_dir/path-map.tsv")
  "$FILTER_REPO" "${filter_args[@]}" --source "$repository" --target "$repository"

  local candidate_commit
  candidate_commit="$(git -C "$repository" rev-parse refs/heads/package-history-candidate)"
  printf '%s\n' "$kind" > "$candidate_dir/target-kind"
  printf '%s\n' "$name" > "$candidate_dir/target-name"
  printf '%s\n' "$branch" > "$candidate_dir/branch"
  printf '%s\n' "$source_commit" > "$candidate_dir/source-commit"
  printf '%s\n' "$candidate_commit" > "$candidate_dir/candidate-commit"
  cp "$repository/.git/filter-repo/commit-map" "$candidate_dir/commit-map.tsv"
  write_mapping_history \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$candidate_dir/commit-map.tsv" \
    "$candidate_dir/mapping-history.tsv"
  git -C "$repository" archive "$candidate_commit" |
    shasum -a 256 |
    awk '{ print $1 }' >"$candidate_dir/final-tree.sha256"
  git -C "$repository" archive --format=tar.gz \
    --output="$candidate_dir/package.tar.gz" "$candidate_commit"
  zig fetch \
    --global-cache-dir "$candidate_dir/zig-global-cache" \
    "$candidate_dir/package.tar.gz" >"$candidate_dir/package-hash"
  rm -rf "$candidate_dir/zig-global-cache"

  local expected actual
  expected="$(mktemp -d "${TMPDIR:-/tmp}/package-history-expected.XXXXXX")"
  actual="$(mktemp -d "${TMPDIR:-/tmp}/package-history-actual.XXXXXX")"
  trap 'rm -rf "$expected" "$actual"' RETURN
  git -C "$ROOT" archive "$source_commit" "$current_root" | tar -x -C "$expected"
  git -C "$repository" archive "$candidate_commit" | tar -x -C "$actual"
  diff -qr "$expected/$current_root" "$actual" >/dev/null || {
    echo "$kind $name: filtered tip differs from $source_commit:$current_root" >&2
    exit 1
  }
  rm -rf "$expected" "$actual"
  trap - RETURN

  echo "$kind $name $candidate_commit"
}

verify_candidate() {
  local kind="$1"
  local name="$2"
  local output="$3"
  local key
  key="$(target_key "$kind" "$name")"
  local candidate_dir="$output/candidates/$key"
  local repository="$candidate_dir/repository"
  [[ -f "$candidate_dir/candidate-commit" && -d "$repository/.git" ]] || {
    echo "$kind $name: candidate is missing" >&2
    exit 1
  }
  local commit
  commit="$(cat "$candidate_dir/candidate-commit")"
  [[ "$(git -C "$repository" rev-parse refs/heads/package-history-candidate)" == "$commit" ]]
  git -C "$repository" fsck --no-progress >/dev/null
  git -C "$repository" cat-file -e "$commit^{tree}"
  [[ -s "$candidate_dir/commit-map.tsv" && -s "$candidate_dir/path-map.tsv" ]]
  [[ -s "$candidate_dir/mapping-history.tsv" ]]
  [[ -s "$candidate_dir/final-tree.sha256" && -s "$candidate_dir/package-hash" ]]
  [[ -s "$candidate_dir/package.tar.gz" ]]
  local current_map current_history source_commit recorded_branch expected_branch current_root
  current_map="$(mktemp "${TMPDIR:-/tmp}/package-history-map.XXXXXX")"
  current_history="$(mktemp "${TMPDIR:-/tmp}/package-history-counts.XXXXXX")"
  trap 'rm -f "$current_map" "$current_history"' RETURN
  target_paths "$kind" "$name" | cat >"$current_map"
  cmp -s "$candidate_dir/path-map.tsv" "$current_map"
  [[ "$(cat "$candidate_dir/target-kind")" == "$kind" ]]
  [[ "$(cat "$candidate_dir/target-name")" == "$name" ]]
  expected_branch="$(target_branch "$kind" "$name")"
  recorded_branch="$(cat "$candidate_dir/branch")"
  [[ -n "$expected_branch" && "$recorded_branch" == "$expected_branch" ]]
  source_commit="$(cat "$candidate_dir/source-commit")"
  git -C "$ROOT" cat-file -e "$source_commit^{commit}"
  write_mapping_history \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$candidate_dir/commit-map.tsv" \
    "$current_history"
  cmp -s "$candidate_dir/mapping-history.tsv" "$current_history"
  local tree_digest
  tree_digest="$(
    git -C "$repository" archive "$commit" |
      shasum -a 256 |
      awk '{ print $1 }'
  )"
  [[ "$tree_digest" == "$(cat "$candidate_dir/final-tree.sha256")" ]]
  local verify_archive verify_cache actual_hash
  verify_archive="$(mktemp "${TMPDIR:-/tmp}/package-history-archive.XXXXXX.tar.gz")"
  verify_cache="$(mktemp -d "${TMPDIR:-/tmp}/package-history-zig-cache.XXXXXX")"
  trap 'rm -f "$verify_archive"; rm -rf "$verify_cache"' RETURN
  git -C "$repository" archive --format=tar.gz \
    --output="$verify_archive" "$commit"
  cmp -s "$candidate_dir/package.tar.gz" "$verify_archive"
  actual_hash="$(zig fetch --global-cache-dir "$verify_cache" "$verify_archive")"
  [[ "$actual_hash" == "$(cat "$candidate_dir/package-hash")" ]]
  current_root="$(target_current_root "$kind" "$name")"
  local expected_tree actual_tree
  expected_tree="$(mktemp -d "${TMPDIR:-/tmp}/package-history-expected.XXXXXX")"
  actual_tree="$(mktemp -d "${TMPDIR:-/tmp}/package-history-actual.XXXXXX")"
  git -C "$ROOT" archive "$source_commit" "$current_root" |
    tar -x -C "$expected_tree"
  git -C "$repository" archive "$commit" | tar -x -C "$actual_tree"
  diff -qr "$expected_tree/$current_root" "$actual_tree" >/dev/null
  rm -rf "$expected_tree" "$actual_tree"
  rm -f "$verify_archive"
  rm -rf "$verify_cache"
  rm -f "$current_map" "$current_history"
  trap - RETURN
  echo "$kind $name $commit"
}

require_sealed_source() {
  local remote="$1"
  local source_commit="$2"
  local branch status head remote_main
  branch="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD || true)"
  [[ "$branch" == main ]] || {
    echo "history reconstruction must run from main; found ${branch:-detached}" >&2
    exit 1
  }
  [[ "$(git -C "$ROOT" rev-parse --is-shallow-repository)" == false ]] || {
    echo "history reconstruction requires a complete, non-shallow clone" >&2
    exit 1
  }
  [[ -z "$(git -C "$ROOT" config --get extensions.partialclone || true)" ]] || {
    echo "history reconstruction does not support partial clones" >&2
    exit 1
  }
  status="$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)"
  [[ -z "$status" ]] || {
    echo "history reconstruction requires a clean main worktree" >&2
    exit 1
  }
  source_commit="$(git -C "$ROOT" rev-parse "$source_commit^{commit}")"
  head="$(git -C "$ROOT" rev-parse HEAD)"
  [[ "$head" == "$source_commit" ]] || {
    echo "sealed source commit must equal local main HEAD" >&2
    exit 1
  }
  git -C "$ROOT" fetch --quiet --prune "$remote"
  remote_main="$(git -C "$ROOT" rev-parse "refs/remotes/$remote/main")"
  [[ "$remote_main" == "$source_commit" ]] || {
    echo "sealed source commit must equal $remote/main" >&2
    exit 1
  }
}

preview_ref_mode() {
  local mode="$1"
  shift
  local manifest=""
  local execute=false
  while (($#)); do
    case "$1" in
      --manifest)
        manifest="$2"
        shift 2
        ;;
      --execute)
        execute=true
        shift
        ;;
      *)
        usage
        exit 2
        ;;
    esac
  done
  [[ -n "$manifest" ]] || {
    echo "$mode requires --manifest PATH" >&2
    exit 2
  }
  [[ -f "$manifest" ]] || {
    echo "sealed migration manifest not found: $manifest" >&2
    exit 1
  }
  if $execute; then
    echo "$mode execution is locked until Phase 2 seals candidate commits and old ref hashes" >&2
    exit 1
  fi
  echo "preview $mode using sealed manifest $manifest"
}

mode="${1:-}"
[[ -n "$mode" ]] || {
  usage
  exit 2
}
shift

case "$mode" in
  analyze)
    (($# == 0)) || {
      usage
      exit 2
    }
    history_tool check
    history_tool check-current-examples
    echo "packages:"
    history_tool list | cat
    echo "examples:"
    history_tool example-list | cat
    echo "rejected similarity paths:"
    history_tool rejections | cat
    ;;
  build-candidates|verify-candidates)
    package=""
    example=""
    source_commit="$(git -C "$ROOT" rev-parse HEAD)"
    output="$DEFAULT_OUTPUT"
    remote="origin"
    while (($#)); do
      case "$1" in
        --package)
          package="$2"
          shift 2
          ;;
        --example)
          example="$2"
          shift 2
          ;;
        --source)
          source_commit="$2"
          shift 2
          ;;
        --output)
          mkdir -p "$2"
          output="$(cd "$2" && pwd)"
          shift 2
          ;;
        --remote)
          remote="$2"
          shift 2
          ;;
        *)
          usage
          exit 2
          ;;
      esac
    done
    mkdir -p "$output/candidates"
    if [[ "$mode" == build-candidates ]]; then
      require_filter_repo
      git -C "$ROOT" cat-file -e "$source_commit^{commit}"
      require_sealed_source "$remote" "$source_commit"
      while IFS=$'\t' read -r kind name; do
        build_candidate "$kind" "$name" "$source_commit" "$output"
      done < <(candidate_targets "$package" "$example")
    else
      while IFS=$'\t' read -r kind name; do
        verify_candidate "$kind" "$name" "$output"
      done < <(candidate_targets "$package" "$example")
    fi
    ;;
  archive|cutover|verify-remote|rollback)
    preview_ref_mode "$mode" "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
