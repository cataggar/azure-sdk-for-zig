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
  seal-inputs --reset-id ID [--source COMMIT] [--output DIR] [--remote REMOTE]
  build-candidates [--package NAME|--example NAME] [--source COMMIT] [--output DIR] [--remote REMOTE]
  verify-candidates [--package NAME|--example NAME] [--output DIR]
  publish-candidates [--output DIR] [--remote REMOTE]
  archive|cutover|verify-remote|rollback [--manifest PATH] [--execute]

archive, cutover, verify-remote, and rollback are sealed-manifest operations.
They remain preview-only until Phase 2 produces the reviewed ref manifest.
EOF
}

history_tool() {
  (cd "$ROOT" && zig run eng/package_history_tool.zig -- "$@")
}

branch_tool() {
  (cd "$ROOT" && zig run eng/package_branch_tool.zig -- "$@")
}

manifest_tool() {
  (cd "$ROOT" && zig run eng/candidate_manifest_tool.zig -- "$@")
}

remote_url() {
  git -C "$ROOT" remote get-url "$1"
}

zig_url_from_remote() {
  local url="$1"
  case "$url" in
    https://*|http://*)
      printf 'git+%s\n' "$url"
      ;;
    git@github.com:*)
      url="${url#git@github.com:}"
      printf 'git+https://github.com/%s\n' "$url"
      ;;
    *)
      echo "unsupported Zig dependency remote URL: $url" >&2
      exit 1
      ;;
  esac
}

sealed_zig_remote_url() {
  zig_url_from_remote "$(cat "$1/remote-url")"
}

github_repository() {
  local url
  url="$(remote_url "$1")"
  case "$url" in
    https://github.com/*|http://github.com/*)
      url="${url#*github.com/}"
      ;;
    git@github.com:*)
      url="${url#git@github.com:}"
      ;;
    *)
      echo "ruleset capture requires a GitHub remote: $url" >&2
      exit 1
      ;;
  esac
  printf '%s\n' "${url%.git}"
}

sealed_value() {
  local output="$1"
  local key="$2"
  awk -F '\t' -v key="$key" '$1 == key { print $2 }' \
    "$output/sealed-inputs.tsv"
}

sealed_inputs_digest() {
  shasum -a 256 "$1/sealed-inputs.tsv" | awk '{ print $1 }'
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

write_commit_artifacts() {
  local repository="$1"
  local commit="$2"
  local candidate_dir="$3"
  local prefix="$4"
  git -C "$repository" archive "$commit" |
    shasum -a 256 |
    awk '{ print $1 }' >"$candidate_dir/$prefix-tree.sha256"
  git -C "$repository" archive --format=tar.gz \
    --output="$candidate_dir/$prefix-package.tar.gz" "$commit"
}

write_final_artifacts() {
  local repository="$1"
  local commit="$2"
  local candidate_dir="$3"
  printf '%s\n' "$commit" >"$candidate_dir/candidate-commit"
  write_commit_artifacts "$repository" "$commit" "$candidate_dir" final
  cp "$candidate_dir/final-package.tar.gz" "$candidate_dir/package.tar.gz"
  zig fetch \
    --global-cache-dir "$candidate_dir/zig-global-cache" \
    "$candidate_dir/package.tar.gz" >"$candidate_dir/package-hash"
  rm -rf "$candidate_dir/zig-global-cache"
}

main_owned_pin() {
  local dependency="$1"
  local branch="$2"
  local output="$3"
  local commit url hash_file hash
  commit="$(
    awk -v ref="refs/heads/$branch" \
      '$2 == ref { print $1 }' \
      "$output/refs-before.tsv"
  )"
  [[ -n "$commit" ]] || {
    echo "sealed ref is missing for main-owned dependency: $branch" >&2
    exit 1
  }
  url="$(sealed_zig_remote_url "$output")#$commit"
  mkdir -p "$output/dependency-pins"
  hash_file="$output/dependency-pins/$dependency-$commit.hash"
  if [[ ! -s "$hash_file" ]]; then
    zig fetch \
      --global-cache-dir "$output/dependency-zig-cache" \
      "$url" >"$hash_file"
  fi
  hash="$(cat "$hash_file")"
  printf '%s\t%s\t%s\n' "$dependency" "$url" "$hash"
}

branch_owned_pin() {
  local dependency="$1"
  local output="$2"
  local dependency_dir="$output/candidates/$dependency"
  [[ -s "$dependency_dir/candidate-commit" &&
    -s "$dependency_dir/package-hash" &&
    -s "$dependency_dir/source-commit" ]] || {
    echo "dependency candidate must be finalized first: $dependency" >&2
    exit 1
  }
  [[ "$(cat "$dependency_dir/source-commit")" == \
    "$(cat "$output/sealed-source")" ]] || {
    echo "dependency candidate belongs to another sealed source: $dependency" >&2
    exit 1
  }
  local commit url hash
  commit="$(cat "$dependency_dir/candidate-commit")"
  url="$(sealed_zig_remote_url "$output")#$commit"
  hash="$(cat "$dependency_dir/package-hash")"
  printf '%s\t%s\t%s\n' "$dependency" "$url" "$hash"
}

write_package_pins() {
  local name="$1"
  local output="$2"
  local remote="$3"
  local pins_file="$4"
  : >"$pins_file"
  while IFS=$'\t' read -r dependency ownership branch; do
    case "$ownership" in
      main_owned)
        main_owned_pin "$dependency" "$branch" "$output" >>"$pins_file"
        ;;
      branch_owned)
        branch_owned_pin "$dependency" "$output" >>"$pins_file"
        ;;
      *)
        echo "unknown dependency ownership for $dependency: $ownership" >&2
        exit 1
        ;;
    esac
  done < <(branch_tool dependency-metadata "$name")
}

write_example_pins() {
  local name="$1"
  local output="$2"
  local remote="$3"
  local pins_file="$4"
  [[ "$name" == kusto ]] || {
    echo "unsupported filtered example candidate: $name" >&2
    exit 1
  }
  : >"$pins_file"
  main_owned_pin azure_sdk_core sdk/core "$output" >>"$pins_file"
  branch_owned_pin azure_sdk_kusto "$output" >>"$pins_file"
}

write_migration_source() {
  local kind="$1"
  local name="$2"
  local source_commit="$3"
  local path_map_digest="$4"
  local output="$5"
  local destination="$6"
  {
    printf 'target-kind\t%s\n' "$kind"
    printf 'target-name\t%s\n' "$name"
    printf 'reset-id\t%s\n' "$(cat "$output/reset-id")"
    printf 'sealed-main\t%s\n' "$source_commit"
    printf 'sealed-inputs-sha256\t%s\n' "$(sealed_inputs_digest "$output")"
    printf 'history-map-sha256\t%s\n' "$path_map_digest"
  } >"$destination"
}

write_baseline_message() {
  local kind="$1"
  local source_commit="$2"
  local path_map_digest="$3"
  local output="$4"
  local destination="$5"
  {
    printf 'Establish branch-owned %s baseline\n\n' "$kind"
    printf 'Sealed-Main: %s\n' "$source_commit"
    printf 'History-Map-SHA256: %s\n' "$path_map_digest"
    printf 'Reset-ID: %s\n' "$(cat "$output/reset-id")"
    printf 'Sealed-Inputs-SHA256: %s\n\n' "$(sealed_inputs_digest "$output")"
    printf 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>\n'
  } >"$destination"
}

commit_baseline() {
  local repository="$1"
  local source_commit="$2"
  local kind="$3"
  local path_map_digest="$4"
  local output="$5"
  local source_date message_file
  source_date="$(git -C "$ROOT" show -s --format=%aI "$source_commit")"
  message_file="$(mktemp "${TMPDIR:-/tmp}/package-history-message.XXXXXX")"
  trap 'rm -f "$message_file"' RETURN
  write_baseline_message \
    "$kind" \
    "$source_commit" \
    "$path_map_digest" \
    "$output" \
    "$message_file"
  git -C "$repository" add --all
  local parent tree commit
  parent="$(git -C "$repository" rev-parse HEAD)"
  tree="$(git -C "$repository" write-tree)"
  commit="$(
    GIT_AUTHOR_NAME="Azure SDK Migration" \
      GIT_AUTHOR_EMAIL="azure-sdk-migration@users.noreply.github.com" \
      GIT_AUTHOR_DATE="$source_date" \
      GIT_COMMITTER_NAME="Azure SDK Migration" \
      GIT_COMMITTER_EMAIL="azure-sdk-migration@users.noreply.github.com" \
      GIT_COMMITTER_DATE="$source_date" \
      git -C "$repository" commit-tree \
        "$tree" \
        -p "$parent" \
        -F "$message_file"
  )"
  git -C "$repository" update-ref \
    refs/heads/package-history-candidate \
    "$commit" \
    "$parent"
  git -C "$repository" reset --hard --quiet "$commit"
  rm -f "$message_file"
  trap - RETURN
}

finalize_candidate() {
  local kind="$1"
  local name="$2"
  local source_commit="$3"
  local output="$4"
  local remote="$5"
  local candidate_dir="$6"
  local repository="$candidate_dir/repository"
  local pins_file="$candidate_dir/dependency-pins.tsv"
  local path_map_digest
  path_map_digest="$(
    shasum -a 256 "$candidate_dir/path-map.tsv" |
      awk '{ print $1 }'
  )"

  git -C "$repository" switch --quiet package-history-candidate
  mkdir -p "$repository/.github/workflows" "$repository/.migration"
  if [[ "$kind" == package ]]; then
    write_package_pins "$name" "$output" "$remote" "$pins_file"
    branch_tool render-ci \
      "$name" \
      "$repository/.github/workflows/package-ci.yml"
  else
    write_example_pins "$name" "$output" "$remote" "$pins_file"
    cp \
      "$ROOT/eng/package_branch_template/example-ci.yml" \
      "$repository/.github/workflows/package-ci.yml"
  fi
  manifest_tool pin "$repository" "$pins_file"
  cp "$pins_file" "$repository/.migration/dependencies.tsv"
  write_migration_source \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$path_map_digest" \
    "$output" \
    "$repository/.migration/source.tsv"
  commit_baseline \
    "$repository" \
    "$source_commit" \
    "$kind" \
    "$path_map_digest" \
    "$output"

  local candidate_commit
  candidate_commit="$(git -C "$repository" rev-parse HEAD)"
  if [[ "$kind" == package ]]; then
    branch_tool validate-tree "$name" "$repository"
  else
    manifest_tool validate "$repository"
  fi
  write_final_artifacts \
    "$repository" \
    "$candidate_commit" \
    "$candidate_dir"
}

build_candidate() {
  local kind="$1"
  local name="$2"
  local source_commit="$3"
  local output="$4"
  local remote="$5"
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

  local filtered_commit
  filtered_commit="$(git -C "$repository" rev-parse refs/heads/package-history-candidate)"
  printf '%s\n' "$kind" > "$candidate_dir/target-kind"
  printf '%s\n' "$name" > "$candidate_dir/target-name"
  printf '%s\n' "$branch" > "$candidate_dir/branch"
  printf '%s\n' "$source_commit" > "$candidate_dir/source-commit"
  printf '%s\n' "$filtered_commit" >"$candidate_dir/filtered-commit"
  cp "$repository/.git/filter-repo/commit-map" "$candidate_dir/commit-map.tsv"
  write_mapping_history \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$candidate_dir/commit-map.tsv" \
    "$candidate_dir/mapping-history.tsv"
  write_commit_artifacts \
    "$repository" \
    "$filtered_commit" \
    "$candidate_dir" \
    filtered

  local expected actual
  expected="$(mktemp -d "${TMPDIR:-/tmp}/package-history-expected.XXXXXX")"
  actual="$(mktemp -d "${TMPDIR:-/tmp}/package-history-actual.XXXXXX")"
  trap 'rm -rf "$expected" "$actual"' RETURN
  git -C "$ROOT" archive "$source_commit" "$current_root" | tar -x -C "$expected"
  git -C "$repository" archive "$filtered_commit" | tar -x -C "$actual"
  diff -qr "$expected/$current_root" "$actual" >/dev/null || {
    echo "$kind $name: filtered tip differs from $source_commit:$current_root" >&2
    exit 1
  }
  rm -rf "$expected" "$actual"
  trap - RETURN

  finalize_candidate \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$output" \
    "$remote" \
    "$candidate_dir"
  echo "$kind $name $(cat "$candidate_dir/candidate-commit")"
}

verify_candidate() {
  local kind="$1"
  local name="$2"
  local output="$3"
  local remote="$4"
  local key
  key="$(target_key "$kind" "$name")"
  local candidate_dir="$output/candidates/$key"
  local repository="$candidate_dir/repository"
  [[ -f "$candidate_dir/candidate-commit" &&
    -f "$candidate_dir/filtered-commit" &&
    -d "$repository/.git" ]] || {
    echo "$kind $name: candidate is missing" >&2
    exit 1
  }
  local commit filtered_commit
  commit="$(cat "$candidate_dir/candidate-commit")"
  filtered_commit="$(cat "$candidate_dir/filtered-commit")"
  [[ "$(git -C "$repository" rev-parse refs/heads/package-history-candidate)" == "$commit" ]]
  [[ "$(git -C "$repository" rev-parse HEAD)" == "$commit" ]]
  [[ -z "$(git -C "$repository" status --porcelain=v1 --untracked-files=all)" ]]
  git -C "$repository" fsck --no-progress >/dev/null
  git -C "$repository" cat-file -e "$commit^{tree}"
  git -C "$repository" cat-file -e "$filtered_commit^{tree}"
  [[ -s "$candidate_dir/commit-map.tsv" && -s "$candidate_dir/path-map.tsv" ]]
  [[ -s "$candidate_dir/mapping-history.tsv" ]]
  [[ -s "$candidate_dir/filtered-tree.sha256" ]]
  [[ -s "$candidate_dir/filtered-package.tar.gz" ]]
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
  local filtered_tree_digest
  filtered_tree_digest="$(
    git -C "$repository" archive "$filtered_commit" |
      shasum -a 256 |
      awk '{ print $1 }'
  )"
  [[ "$filtered_tree_digest" == \
    "$(cat "$candidate_dir/filtered-tree.sha256")" ]]
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
  local source_tree filtered_tree
  source_tree="$(mktemp -d "${TMPDIR:-/tmp}/package-history-source.XXXXXX")"
  filtered_tree="$(mktemp -d "${TMPDIR:-/tmp}/package-history-filtered.XXXXXX")"
  git -C "$ROOT" archive "$source_commit" "$current_root" |
    tar -x -C "$source_tree"
  git -C "$repository" archive "$filtered_commit" | tar -x -C "$filtered_tree"
  diff -qr "$source_tree/$current_root" "$filtered_tree" >/dev/null

  local expected_pins
  expected_pins="$(mktemp "${TMPDIR:-/tmp}/package-history-pins.XXXXXX")"
  if [[ "$kind" == package ]]; then
    write_package_pins "$name" "$output" "$remote" "$expected_pins"
    branch_tool validate-tree "$name" "$repository"
  else
    write_example_pins "$name" "$output" "$remote" "$expected_pins"
    manifest_tool validate "$repository"
  fi
  cmp -s "$expected_pins" "$repository/.migration/dependencies.tsv"
  cmp -s \
    "$candidate_dir/dependency-pins.tsv" \
    "$repository/.migration/dependencies.tsv"

  local expected_baseline actual_baseline path_map_digest
  expected_baseline="$(
    mktemp -d "${TMPDIR:-/tmp}/package-history-expected-baseline.XXXXXX"
  )"
  actual_baseline="$(
    mktemp -d "${TMPDIR:-/tmp}/package-history-actual-baseline.XXXXXX"
  )"
  git -C "$repository" archive "$filtered_commit" | tar -x -C "$expected_baseline"
  manifest_tool pin "$expected_baseline" "$expected_pins"
  mkdir -p \
    "$expected_baseline/.github/workflows" \
    "$expected_baseline/.migration"
  if [[ "$kind" == package ]]; then
    branch_tool render-ci \
      "$name" \
      "$expected_baseline/.github/workflows/package-ci.yml"
  else
    cp \
      "$ROOT/eng/package_branch_template/example-ci.yml" \
      "$expected_baseline/.github/workflows/package-ci.yml"
  fi
  cp "$expected_pins" "$expected_baseline/.migration/dependencies.tsv"
  path_map_digest="$(
    shasum -a 256 "$candidate_dir/path-map.tsv" |
      awk '{ print $1 }'
  )"
  write_migration_source \
    "$kind" \
    "$name" \
    "$source_commit" \
    "$path_map_digest" \
    "$output" \
    "$expected_baseline/.migration/source.tsv"
  git -C "$repository" archive "$commit" | tar -x -C "$actual_baseline"
  diff -qr "$expected_baseline" "$actual_baseline" >/dev/null || {
    echo "$kind $name: final baseline tree is not reproducible" >&2
    exit 1
  }

  [[ "$(git -C "$repository" rev-parse "$commit^")" == "$filtered_commit" ]]
  local source_date message_file expected_commit
  source_date="$(git -C "$ROOT" show -s --format=%aI "$source_commit")"
  message_file="$(mktemp "${TMPDIR:-/tmp}/package-history-message.XXXXXX")"
  write_baseline_message \
    "$kind" \
    "$source_commit" \
    "$path_map_digest" \
    "$output" \
    "$message_file"
  expected_commit="$(
    GIT_AUTHOR_NAME="Azure SDK Migration" \
      GIT_AUTHOR_EMAIL="azure-sdk-migration@users.noreply.github.com" \
      GIT_AUTHOR_DATE="$source_date" \
      GIT_COMMITTER_NAME="Azure SDK Migration" \
      GIT_COMMITTER_EMAIL="azure-sdk-migration@users.noreply.github.com" \
      GIT_COMMITTER_DATE="$source_date" \
      git -C "$repository" commit-tree \
        "$(git -C "$repository" rev-parse "$commit^{tree}")" \
        -p "$filtered_commit" \
        -F "$message_file"
  )"
  [[ "$expected_commit" == "$commit" ]] || {
    echo "$kind $name: final baseline commit is not deterministic" >&2
    exit 1
  }

  rm -rf "$source_tree" "$filtered_tree" "$expected_baseline" "$actual_baseline"
  rm -f "$expected_pins" "$message_file"
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

seal_inputs() {
  local reset_id="$1"
  local source_commit="$2"
  local output="$3"
  local remote="$4"
  [[ "$reset_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
    echo "invalid reset ID: $reset_id" >&2
    exit 1
  }
  require_sealed_source "$remote" "$source_commit"
  source_commit="$(git -C "$ROOT" rev-parse "$source_commit^{commit}")"
  mkdir -p "$output"
  [[ -z "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
    echo "seal output must be empty: $output" >&2
    exit 1
  }
  local seal_dir
  seal_dir="$(mktemp -d "$output/.seal.XXXXXX")"
  trap 'rm -rf "$seal_dir"' RETURN
  printf '%s\n' "$reset_id" >"$seal_dir/reset-id"
  printf '%s\n' "$source_commit" >"$seal_dir/sealed-source"
  remote_url "$remote" >"$seal_dir/remote-url"
  git -C "$ROOT" ls-remote --heads --tags "$remote" |
    sort >"$seal_dir/refs-before.tsv"

  local expected_absent=(
    refs/heads/sdk/kusto
    refs/heads/example/kusto
    refs/tags/azure_sdk_kusto/v0.1.0
  )
  : >"$seal_dir/expected-absent-refs"
  local ref
  for ref in "${expected_absent[@]}"; do
    if awk -v ref="$ref" '$2 == ref { found = 1 } END { exit !found }' \
      "$seal_dir/refs-before.tsv"
    then
      echo "expected remote ref is already present: $ref" >&2
      exit 1
    fi
    printf '%s\n' "$ref" >>"$seal_dir/expected-absent-refs"
  done
  if awk -v prefix="refs/heads/migration/$reset_id/" \
    'index($2, prefix) == 1 { found = 1 } END { exit !found }' \
    "$seal_dir/refs-before.tsv"
  then
    echo "reset ID already has remote candidate refs: $reset_id" >&2
    exit 1
  fi

  {
    printf 'azure_sdk_kusto\t'
    history_tool paths azure_sdk_kusto | shasum -a 256 | awk '{ print $1 }'
    printf 'example-kusto\t'
    history_tool example-paths kusto | shasum -a 256 | awk '{ print $1 }'
  } >"$seal_dir/history-map-digests.tsv"

  command -v gh >/dev/null 2>&1 || {
    echo "gh is required to capture repository rulesets" >&2
    exit 1
  }
  local repository
  repository="$(github_repository "$remote")"
  mkdir -p "$seal_dir/rulesets"
  : >"$seal_dir/rulesets.tsv"
  local ruleset_count=0
  while IFS= read -r ruleset_id; do
    [[ -n "$ruleset_id" ]] || continue
    local ruleset_file="$seal_dir/rulesets/$ruleset_id.json"
    gh api "repos/$repository/rulesets/$ruleset_id" >"$ruleset_file"
    printf '%s\t%s\n' \
      "$ruleset_id" \
      "$(shasum -a 256 "$ruleset_file" | awk '{ print $1 }')" \
      >>"$seal_dir/rulesets.tsv"
    ruleset_count=$((ruleset_count + 1))
  done < <(
    gh api "repos/$repository/rulesets" \
      --paginate \
      --jq '.[] | select(.enforcement == "active") | .id'
  )
  [[ "$ruleset_count" -eq 2 ]] || {
    echo "expected two active branch/tag rulesets, found $ruleset_count" >&2
    exit 1
  }

  {
    printf 'reset-id\t%s\n' "$reset_id"
    printf 'sealed-main\t%s\n' "$source_commit"
    printf 'remote\t%s\n' "$(remote_url "$remote")"
    printf 'refs-before-sha256\t%s\n' \
      "$(shasum -a 256 "$seal_dir/refs-before.tsv" | awk '{ print $1 }')"
    printf 'rulesets-sha256\t%s\n' \
      "$(shasum -a 256 "$seal_dir/rulesets.tsv" | awk '{ print $1 }')"
    printf 'history-maps-sha256\t%s\n' \
      "$(shasum -a 256 "$seal_dir/history-map-digests.tsv" | awk '{ print $1 }')"
  } >"$seal_dir/sealed-inputs.tsv"
  cp -R "$seal_dir/." "$output/"
  printf '%s\n' \
    "$(shasum -a 256 "$output/sealed-inputs.tsv" | awk '{ print $1 }')" \
    >"$output/sealed.complete"
  rm -rf "$seal_dir"
  trap - RETURN
  echo "sealed $reset_id at $source_commit"
}

require_sealed_output() {
  local output="$1"
  local source_commit="$2"
  local remote="$3"
  [[ -s "$output/reset-id" &&
    -s "$output/sealed-source" &&
    -s "$output/remote-url" &&
    -s "$output/refs-before.tsv" &&
    -s "$output/rulesets.tsv" &&
    -s "$output/history-map-digests.tsv" &&
    -s "$output/sealed-inputs.tsv" &&
    -s "$output/sealed.complete" ]] || {
    echo "sealed inputs are missing from $output" >&2
    exit 1
  }
  [[ "$(cat "$output/sealed.complete")" == \
    "$(shasum -a 256 "$output/sealed-inputs.tsv" | awk '{ print $1 }')" ]] || {
    echo "sealed input completion digest does not match" >&2
    exit 1
  }
  [[ "$(cat "$output/sealed-source")" == "$source_commit" ]] || {
    echo "candidate source does not match sealed inputs" >&2
    exit 1
  }
  [[ "$(cat "$output/reset-id")" == "$(sealed_value "$output" reset-id)" ]] || {
    echo "reset ID does not match sealed inputs" >&2
    exit 1
  }
  [[ "$(cat "$output/sealed-source")" == \
    "$(sealed_value "$output" sealed-main)" ]] || {
    echo "sealed source file does not match sealed inputs" >&2
    exit 1
  }
  [[ "$(cat "$output/remote-url")" == "$(remote_url "$remote")" ]] || {
    echo "publication remote URL changed after sealing" >&2
    exit 1
  }
  [[ "$(cat "$output/remote-url")" == "$(sealed_value "$output" remote)" ]] || {
    echo "remote URL file does not match sealed inputs" >&2
    exit 1
  }

  local reset_id all_current_refs current_refs current_namespace expected_namespace
  reset_id="$(cat "$output/reset-id")"
  all_current_refs="$(mktemp "${TMPDIR:-/tmp}/package-history-all-refs.XXXXXX")"
  current_refs="$(mktemp "${TMPDIR:-/tmp}/package-history-refs.XXXXXX")"
  current_namespace="$(
    mktemp "${TMPDIR:-/tmp}/package-history-namespace.XXXXXX"
  )"
  expected_namespace="$(
    mktemp "${TMPDIR:-/tmp}/package-history-expected-namespace.XXXXXX"
  )"
  trap 'rm -f "$all_current_refs" "$current_refs" "$current_namespace" "$expected_namespace"' RETURN
  git -C "$ROOT" ls-remote --heads --tags "$remote" |
    sort >"$all_current_refs"
  awk -v prefix="refs/heads/migration/$reset_id/" \
    'index($2, prefix) != 1' "$all_current_refs" >"$current_refs"
  cmp -s "$output/refs-before.tsv" "$current_refs" || {
    echo "remote refs changed after sealing" >&2
    exit 1
  }
  awk -v prefix="refs/heads/migration/$reset_id/" \
    'index($2, prefix) == 1 { print $2 "\t" $1 }' \
    "$all_current_refs" |
    sort >"$current_namespace"

  local candidate_manifest=""
  local candidate_manifest_marker=""
  local candidate_manifest_pending=false
  if [[ -s "$output/migration-manifest.tsv" ]]; then
    candidate_manifest="$output/migration-manifest.tsv"
    candidate_manifest_marker="$output/migration.complete"
  elif [[ -s "$output/migration-manifest.pending.tsv" ]]; then
    candidate_manifest="$output/migration-manifest.pending.tsv"
    candidate_manifest_marker="$output/migration-manifest.pending.complete"
    candidate_manifest_pending=true
  fi
  if [[ -n "$candidate_manifest" ]]; then
    [[ -s "$candidate_manifest_marker" &&
      "$(cat "$candidate_manifest_marker")" == \
        "$(shasum -a 256 "$candidate_manifest" | awk '{ print $1 }')" ]] || {
      echo "candidate manifest completion digest does not match" >&2
      exit 1
    }
    awk -F '\t' '$1 == "candidate" { print $4 "\t" $5 }' \
      "$candidate_manifest" |
      sort >"$expected_namespace"
  else
    : >"$expected_namespace"
  fi
  if $candidate_manifest_pending && [[ ! -s "$current_namespace" ]]; then
    :
  else
    cmp -s "$current_namespace" "$expected_namespace" || {
      echo "migration ref namespace does not match the sealed candidate manifest" >&2
      exit 1
    }
  fi

  rm -f \
    "$all_current_refs" \
    "$current_refs" \
    "$current_namespace" \
    "$expected_namespace"
  trap - RETURN

  local expected
  expected="$(
    awk -F '\t' '$1 == "refs-before-sha256" { print $2 }' \
      "$output/sealed-inputs.tsv"
  )"
  [[ "$expected" == \
    "$(shasum -a 256 "$output/refs-before.tsv" | awk '{ print $1 }')" ]]
  expected="$(
    awk -F '\t' '$1 == "rulesets-sha256" { print $2 }' \
      "$output/sealed-inputs.tsv"
  )"
  [[ "$expected" == \
    "$(shasum -a 256 "$output/rulesets.tsv" | awk '{ print $1 }')" ]]
  expected="$(
    awk -F '\t' '$1 == "history-maps-sha256" { print $2 }' \
      "$output/sealed-inputs.tsv"
  )"
  [[ "$expected" == \
    "$(shasum -a 256 "$output/history-map-digests.tsv" | awk '{ print $1 }')" ]]

  local repository
  repository="$(github_repository "$remote")"
  local current_ruleset_ids sealed_ruleset_ids
  current_ruleset_ids="$(
    mktemp "${TMPDIR:-/tmp}/package-history-ruleset-ids.XXXXXX"
  )"
  sealed_ruleset_ids="$(
    mktemp "${TMPDIR:-/tmp}/package-history-sealed-ruleset-ids.XXXXXX"
  )"
  gh api "repos/$repository/rulesets" \
    --paginate \
    --jq '.[] | select(.enforcement == "active") | .id' |
    sort >"$current_ruleset_ids"
  cut -f1 "$output/rulesets.tsv" | sort >"$sealed_ruleset_ids"
  cmp -s "$current_ruleset_ids" "$sealed_ruleset_ids" || {
    rm -f "$current_ruleset_ids" "$sealed_ruleset_ids"
    echo "active ruleset set changed after sealing" >&2
    exit 1
  }
  rm -f "$current_ruleset_ids" "$sealed_ruleset_ids"
  while IFS=$'\t' read -r ruleset_id ruleset_digest; do
    local current_ruleset
    current_ruleset="$(mktemp "${TMPDIR:-/tmp}/package-history-ruleset.XXXXXX")"
    gh api "repos/$repository/rulesets/$ruleset_id" >"$current_ruleset"
    [[ "$ruleset_digest" == \
      "$(shasum -a 256 "$current_ruleset" | awk '{ print $1 }')" ]] || {
      rm -f "$current_ruleset"
      echo "ruleset changed after sealing: $ruleset_id" >&2
      exit 1
    }
    rm -f "$current_ruleset"
  done <"$output/rulesets.tsv"
}

publish_candidates() {
  local output="$1"
  local remote="$2"
  [[ -s "$output/reset-id" && -s "$output/sealed-source" ]] || {
    echo "sealed inputs are missing from $output" >&2
    exit 1
  }
  local reset_id source_commit
  reset_id="$(cat "$output/reset-id")"
  source_commit="$(cat "$output/sealed-source")"
  require_sealed_source "$remote" "$source_commit"
  require_sealed_output "$output" "$source_commit" "$remote"

  local publisher="$output/publisher"
  rm -rf "$publisher"
  git init --quiet "$publisher"
  local -a leases=()
  local -a refspecs=()
  local candidate_refs="$output/candidate-refs.tsv"
  : >"$candidate_refs"
  local present_count=0
  local absent_count=0

  shopt -s nullglob
  local candidate_dirs=("$output"/candidates/*)
  shopt -u nullglob
  [[ "${#candidate_dirs[@]}" -gt 0 ]] || {
    echo "no candidates found in $output" >&2
    exit 1
  }

  local candidate_dir
  for candidate_dir in "${candidate_dirs[@]}"; do
    [[ -s "$candidate_dir/candidate-commit" &&
      -s "$candidate_dir/branch" &&
      -s "$candidate_dir/source-commit" &&
      -d "$candidate_dir/repository/.git" ]] || {
      echo "incomplete candidate directory: $candidate_dir" >&2
      exit 1
    }
    [[ "$(cat "$candidate_dir/source-commit")" == "$source_commit" ]] || {
      echo "candidate belongs to another sealed source: $candidate_dir" >&2
      exit 1
    }
    local kind name key branch commit destination existing stage_ref
    kind="$(cat "$candidate_dir/target-kind")"
    name="$(cat "$candidate_dir/target-name")"
    verify_candidate "$kind" "$name" "$output" "$remote"
    key="$(basename "$candidate_dir")"
    branch="$(cat "$candidate_dir/branch")"
    commit="$(cat "$candidate_dir/candidate-commit")"
    destination="refs/heads/migration/$reset_id/$branch"
    existing="$(git -C "$ROOT" ls-remote "$remote" "$destination")"
    if [[ -z "$existing" ]]; then
      git -C "$publisher" fetch --quiet \
        "$candidate_dir/repository" \
        "$commit"
      stage_ref="refs/heads/stage/$key"
      git -C "$publisher" update-ref "$stage_ref" FETCH_HEAD
      leases+=("--force-with-lease=$destination:")
      refspecs+=("$stage_ref:$destination")
      absent_count=$((absent_count + 1))
    elif [[ "$(printf '%s\n' "$existing" | awk '{ print $1 }')" == "$commit" ]]; then
      present_count=$((present_count + 1))
    else
      echo "candidate ref exists at an unexpected commit: $destination" >&2
      exit 1
    fi
    printf '%s\t%s\t%s\t%s\n' \
      "$kind" \
      "$name" \
      "$destination" \
      "$commit" >>"$candidate_refs"
  done

  [[ "$present_count" -eq 0 || "$absent_count" -eq 0 ]] || {
    echo "candidate namespace is only partially published" >&2
    exit 1
  }

  local pending_manifest="$output/migration-manifest.pending.tsv"
  local pending_marker="$output/migration-manifest.pending.complete"
  {
    cat "$output/sealed-inputs.tsv"
    while IFS=$'\t' read -r kind name ref commit; do
      printf 'candidate\t%s\t%s\t%s\t%s\n' \
        "$kind" "$name" "$ref" "$commit"
    done <"$candidate_refs"
  } >"$pending_manifest"
  printf '%s\n' \
    "$(shasum -a 256 "$pending_manifest" | awk '{ print $1 }')" \
    >"$pending_marker"

  if [[ "$absent_count" -gt 0 ]]; then
    git -C "$publisher" push --atomic \
      "${leases[@]}" \
      "$(remote_url "$remote")" \
      "${refspecs[@]}"
  fi

  while IFS=$'\t' read -r kind name ref commit; do
    existing="$(git -C "$ROOT" ls-remote "$remote" "$ref")"
    [[ "$(printf '%s\n' "$existing" | awk '{ print $1 }')" == "$commit" ]] || {
      echo "published candidate ref verification failed: $ref" >&2
      exit 1
    }
  done <"$candidate_refs"
  mv "$pending_manifest" "$output/migration-manifest.tsv"
  mv "$pending_marker" "$output/migration.complete"
  echo "published ${#candidate_dirs[@]} candidate refs atomically"
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
  seal-inputs)
    reset_id=""
    source_commit="$(git -C "$ROOT" rev-parse HEAD)"
    output="$DEFAULT_OUTPUT"
    remote="origin"
    while (($#)); do
      case "$1" in
        --reset-id)
          reset_id="$2"
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
    [[ -n "$reset_id" ]] || {
      echo "seal-inputs requires --reset-id ID" >&2
      exit 2
    }
    seal_inputs "$reset_id" "$source_commit" "$output" "$remote"
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
    source_commit="$(git -C "$ROOT" rev-parse "$source_commit^{commit}")"
    require_sealed_output "$output" "$source_commit" "$remote"
    require_sealed_source "$remote" "$source_commit"
    if [[ "$mode" == build-candidates ]]; then
      require_filter_repo
      while IFS=$'\t' read -r kind name; do
        build_candidate "$kind" "$name" "$source_commit" "$output" "$remote"
      done < <(candidate_targets "$package" "$example")
    else
      while IFS=$'\t' read -r kind name; do
        verify_candidate "$kind" "$name" "$output" "$remote"
      done < <(candidate_targets "$package" "$example")
    fi
    ;;
  publish-candidates)
    output="$DEFAULT_OUTPUT"
    remote="origin"
    while (($#)); do
      case "$1" in
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
    publish_candidates "$output" "$remote"
    ;;
  archive|cutover|verify-remote|rollback)
    preview_ref_mode "$mode" "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
