#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/container-registry-release.sh"
METADATA="$ROOT/eng/container_registry_release/metadata.sh"
# shellcheck source=/dev/null
source "$METADATA"

STAGE_ROOT="${CONTAINER_REGISTRY_RELEASE_ROOT:-$ROOT/.release/container_registry}"
WORK_ROOT="$STAGE_ROOT/work"
ACTIVE_REPO=""
ACTIVE_WORKTREE=""
ACTIVE_BRANCH=""
SELF_TEST_ROOT=""
PUBLISHED_COMMIT=""
REMOVE_CODEGEN_ZIG_PKG=0
ROOT_ZIG_PKG_EXISTED=0
if [[ -e "$ROOT/zig-pkg" ]]; then
  ROOT_ZIG_PKG_EXISTED=1
fi

cleanup_active_publication() {
  set +e
  if [[ -n "$ACTIVE_REPO" && -n "$ACTIVE_WORKTREE" ]]; then
    git -C "$ACTIVE_REPO" worktree remove --force "$ACTIVE_WORKTREE" \
      >/dev/null 2>&1
    case "$ACTIVE_WORKTREE" in
      "$STAGE_ROOT"/worktrees/*|"$SELF_TEST_ROOT"/worktrees/*)
        rm -rf "$ACTIVE_WORKTREE"
        ;;
    esac
  fi
  if [[ -n "$ACTIVE_REPO" && -n "$ACTIVE_BRANCH" ]]; then
    git -C "$ACTIVE_REPO" branch -D "$ACTIVE_BRANCH" >/dev/null 2>&1
  fi
  ACTIVE_REPO=""
  ACTIVE_WORKTREE=""
  ACTIVE_BRANCH=""
  set -e
}

cleanup_on_exit() {
  local status=$?
  trap - EXIT INT TERM HUP
  cleanup_active_publication
  if [[ "$REMOVE_CODEGEN_ZIG_PKG" == 1 ]]; then
    rm -rf "$ROOT/codegen/cli/zig-pkg"
  fi
  if [[ "$ROOT_ZIG_PKG_EXISTED" == 0 ]]; then
    rm -rf "$ROOT/zig-pkg"
  fi
  if [[ -n "$SELF_TEST_ROOT" ]]; then
    case "$SELF_TEST_ROOT" in
      "$STAGE_ROOT"/self-test) rm -rf "$SELF_TEST_ROOT" ;;
    esac
  fi
  exit "$status"
}
trap cleanup_on_exit EXIT INT TERM HUP

usage() {
  cat <<'EOF'
Usage:
  scripts/container-registry-release.sh hash-check
  scripts/container-registry-release.sh verify
  scripts/container-registry-release.sh dry-run
  scripts/container-registry-release.sh prepare-rest
  scripts/container-registry-release.sh prepare-sdk <rest-commit> [rest-hash]
  scripts/container-registry-release.sh publish-rest [--dry-run] [--remote <remote>]
  scripts/container-registry-release.sh publish-sdk [--dry-run] [--remote <remote>]
  scripts/container-registry-release.sh self-test

Preparation stages only declared package files. Builds and fetch caches use
disposable work directories outside package stages. Publication creates an
initial orphan commit only when the release branch is absent; later releases
create normal descendant commits and push without force. --dry-run creates and
validates the prospective commit but does not push it.
EOF
}

reset_work() {
  rm -rf "$WORK_ROOT"
  mkdir -p "$WORK_ROOT"
}

fetch_hash() {
  local source="$1"
  mkdir -p "$WORK_ROOT/fetch-cwd" "$WORK_ROOT/global-cache"
  (
    cd "$WORK_ROOT/fetch-cwd"
    zig fetch --global-cache-dir "$WORK_ROOT/global-cache" "$source"
  )
}

check_hash() {
  local url="$1"
  local expected="$2"
  local actual
  actual="$(fetch_hash "$url")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'package hash mismatch\n  expected: %s\n  actual:   %s\n' \
      "$expected" "$actual" >&2
    return 1
  fi
}

validate_package() {
  local directory="$1"
  local package="$2"
  python3 - "$directory" "$package" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
package = sys.argv[2]
for path in root.rglob("*"):
    if path.is_symlink():
        raise SystemExit(f"{root}: symlinks are not allowed in release packages")
zon_path = root / "build.zig.zon"
build_path = root / "build.zig"
if not zon_path.is_file() or not build_path.is_file():
    raise SystemExit(f"{root}: package root is missing build.zig or build.zig.zon")

zon = zon_path.read_text()
build = build_path.read_text()
if not re.search(rf"(?m)^\s*\.name\s*=\s*\.{re.escape(package)}\s*,\s*$", zon):
    raise SystemExit(f"{root}: build.zig.zon package name is not {package}")
if not re.search(r"(?m)^\s*\.version\s*=\s*\"[^\"]+\"\s*,\s*$", zon):
    raise SystemExit(f"{root}: build.zig.zon is missing version")
if not re.search(r"(?m)^\s*\.fingerprint\s*=\s*0x[0-9a-fA-F]+\s*,\s*$", zon):
    raise SystemExit(f"{root}: build.zig.zon is missing fingerprint")
if not re.search(r"(?m)^\s*\.minimum_zig_version\s*=\s*\"[^\"]+\"\s*,\s*$", zon):
    raise SystemExit(f"{root}: build.zig.zon is missing minimum_zig_version")
if f'addModule("{package}"' not in build:
    raise SystemExit(f"{root}: build.zig module name is not {package}")

paths_match = re.search(r"(?ms)^\s*\.paths\s*=\s*\.\{(.*?)^\s*\},\s*$", zon)
if not paths_match:
    raise SystemExit(f"{root}: build.zig.zon is missing .paths")
declared = set(re.findall(r'"([^"]+)"', paths_match.group(1)))
expected = {
    ".gitignore",
    "build.zig",
    "build.zig.zon",
    "LICENSE.txt",
    "README.md",
    "src",
}
if package == "azure_sdk_container_registry":
    expected.update({".gitignore", "examples", "live_tests"})
if declared != expected:
    raise SystemExit(
        f"{root}: declared package paths differ: "
        f"expected {sorted(expected)}, got {sorted(declared)}"
    )

for entry in declared:
    if not (root / entry).exists() and not (root / entry).is_symlink():
        raise SystemExit(f"{root}: declared package path is missing: {entry}")

for path in root.rglob("*"):
    relative = path.relative_to(root)
    if any(part in {".git", ".zig-cache", "zig-pkg", "zig-out", ".release"}
           for part in relative.parts):
        raise SystemExit(f"{root}: forbidden release artifact: {relative}")
    if path.is_dir():
        continue
    first = relative.parts[0]
    if first not in declared:
        raise SystemExit(f"{root}: undeclared package file: {relative}")

top_level = {path.name for path in root.iterdir()}
if top_level != declared:
    raise SystemExit(
        f"{root}: staged top-level entries differ: "
        f"expected {sorted(declared)}, got {sorted(top_level)}"
    )
print(f"verified declared package content: {package}", file=sys.stderr)
PY
}

validate_rest_archive() {
  local directory="$1"
  validate_package "$directory" "$REST_PACKAGE"
  python3 - "$directory/build.zig.zon" \
    "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
expected_sdk_url, expected_sdk_hash = sys.argv[2:]
text = path.read_text()

dependencies = re.search(
    r"(?ms)^\s*\.dependencies\s*=\s*\.\{(.*?)^\s*\},\s*^\s*\.paths",
    text,
)
if not dependencies:
    raise SystemExit(f"{path}: missing dependencies block")
block = dependencies.group(1)
names = set(re.findall(r"(?m)^\s{8}\.([A-Za-z0-9_]+)\s*=\s*\.\{\s*$", block))
if names != {"azure_sdk", "serde"}:
    raise SystemExit(
        f"{path}: expected azure_sdk and serde dependencies, got {sorted(names)}"
    )
if re.search(r"(?m)^\s*\.path\s*=", block):
    raise SystemExit(f"{path}: published REST package contains a path dependency")

sdk = re.search(
    r"(?ms)^\s{8}\.azure_sdk\s*=\s*\.\{(.*?)^\s{8}\},\s*$",
    block,
)
if not sdk:
    raise SystemExit(f"{path}: malformed azure_sdk dependency")
sdk_block = sdk.group(1)
url = re.search(r'(?m)^\s*\.url\s*=\s*"([^"]+)"\s*,\s*$', sdk_block)
package_hash = re.search(
    r'(?m)^\s*\.hash\s*=\s*"([^"]+)"\s*,\s*$',
    sdk_block,
)
if not url or url.group(1) != expected_sdk_url:
    raise SystemExit(f"{path}: azure_sdk URL/commit pin differs")
if not package_hash or package_hash.group(1) != expected_sdk_hash:
    raise SystemExit(f"{path}: azure_sdk package hash differs")
PY
}

stage_sdk() {
  local output="$1"
  local rest_mode="$2"
  local rest_commit="${3:-}"
  local rest_hash="${4:-}"
  rm -rf "$output"
  mkdir -p "$output"

  python3 - "$ROOT" "$output" <<'PY'
from pathlib import Path
import os
import shutil
import subprocess
import sys

root = Path(sys.argv[1])
output = Path(sys.argv[2])
subtree = Path("sdk/container_registry")
declared = {
    ".gitignore",
    "LICENSE.txt",
    "README.md",
    "build.zig",
    "build.zig.zon",
    "examples",
    "live_tests",
    "src",
}
raw = subprocess.check_output(
    ["git", "-C", str(root), "ls-files", "-z", "--", str(subtree)]
)
files = [Path(item.decode()) for item in raw.split(b"\0") if item]
if not files:
    raise SystemExit("no tracked SDK package files found")
for tracked in files:
    relative = tracked.relative_to(subtree)
    if relative.parts[0] not in declared:
        raise SystemExit(f"tracked but undeclared SDK package file: {relative}")
    source = root / tracked
    target = output / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        target.symlink_to(os.readlink(source))
    elif source.is_file():
        shutil.copy2(source, target)
    else:
        raise SystemExit(f"tracked SDK package file is missing: {tracked}")
PY

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
  validate_package "$output" "$SDK_PACKAGE"
}

generate_rest() {
  local output="$1"
  if [[ ! -e "$ROOT/codegen/cli/zig-pkg" ]]; then
    REMOVE_CODEGEN_ZIG_PKG=1
  fi
  rm -rf "$output"
  mkdir -p "$(dirname "$output")" "$WORK_ROOT/codegen-cache" \
    "$WORK_ROOT/global-cache"
  (
    cd "$ROOT/codegen/cli"
    zig build \
      --cache-dir "$WORK_ROOT/codegen-cache" \
      --global-cache-dir "$WORK_ROOT/global-cache" \
      generate-container-registry-package \
      -Dcontainer-registry-output="$output" \
      -Dazure-core-commit="$AZURE_SDK_COMMIT" \
      -Dazure-core-hash="$AZURE_SDK_HASH"
  )
  if [[ "$REMOVE_CODEGEN_ZIG_PKG" == 1 ]]; then
    rm -rf "$ROOT/codegen/cli/zig-pkg"
    REMOVE_CODEGEN_ZIG_PKG=0
  fi
  validate_rest_archive "$output"
}

copy_declared_stage() {
  local source="$1"
  local destination="$2"
  rm -rf "$destination"
  mkdir -p "$destination"
  (
    cd "$source"
    tar -cf - .
  ) | (
    cd "$destination"
    tar -xf -
  )
}

install_declared_stage() {
  local source="$1"
  local worktree="$2"
  (
    cd "$source"
    tar -cf - .
  ) | (
    cd "$worktree"
    tar -xf -
  )
}

zig_build() {
  local directory="$1"
  local cache_name="$2"
  shift 2
  mkdir -p "$WORK_ROOT/caches/$cache_name/local" \
    "$WORK_ROOT/caches/global"
  (
    cd "$directory"
    zig build \
      --cache-dir "$WORK_ROOT/caches/$cache_name/local" \
      --global-cache-dir "$WORK_ROOT/caches/global" \
      "$@"
  )
}

test_rest() {
  local directory="$1"
  validate_package "$directory" "$REST_PACKAGE"
  zig_build "$directory" rest test --summary all
}

test_sdk() {
  local directory="$1"
  validate_package "$directory" "$SDK_PACKAGE"
  zig_build "$directory" sdk-test test --summary all
  zig_build "$directory" sdk-examples examples
  (
    unset AZURE_CONTAINER_REGISTRY_LIVE_TESTS
    unset AZURE_CONTAINER_REGISTRY_ENDPOINT
    unset AZURE_CONTAINER_REGISTRY_LIVE_TEST_RUN_ID
    unset AZURE_CONTAINER_REGISTRY_LIVE_TEST_REPOSITORY_PREFIX
    zig_build "$directory" sdk-live live-test --summary all
  )
}

test_local_stages() {
  local rest_stage="$1"
  local sdk_stage="$2"
  local test_root="$WORK_ROOT/test-packages"
  copy_declared_stage "$rest_stage" "$test_root/rest"
  copy_declared_stage "$sdk_stage" "$test_root/sdk"
  test_rest "$test_root/rest"
  test_sdk "$test_root/sdk"
  rm -rf "$test_root" "$WORK_ROOT/caches"
  validate_rest_archive "$rest_stage"
  validate_package "$sdk_stage" "$SDK_PACKAGE"
}

test_published_sdk_stage() {
  local sdk_stage="$1"
  local test_root="$WORK_ROOT/test-packages"
  copy_declared_stage "$sdk_stage" "$test_root/sdk"
  test_sdk "$test_root/sdk"
  rm -rf "$test_root" "$WORK_ROOT/caches"
  validate_package "$sdk_stage" "$SDK_PACKAGE"
}

remote_ref_commit() {
  local git_url="$1"
  local branch="$2"
  local result
  result="$(git ls-remote "$git_url" "refs/heads/$branch")"
  if [[ -z "$result" ]]; then
    printf 'remote release branch does not exist: %s\n' "$branch" >&2
    return 1
  fi
  printf '%s\n' "$result" | awk 'NR == 1 { print $1 }'
}

resolve_rest_package() {
  local requested_commit="$1"
  local archive_output="$2"
  local verify_url_hash="${3:-1}"
  local remote_commit
  remote_commit="$(remote_ref_commit "$AZURE_SDK_GIT_URL" "$REST_BRANCH")"
  if [[ "$requested_commit" != "$remote_commit" ]]; then
    printf 'REST commit must equal remote refs/heads/%s\n' "$REST_BRANCH" >&2
    printf '  requested: %s\n  remote:    %s\n' \
      "$requested_commit" "$remote_commit" >&2
    return 1
  fi

  local fetch_repo="$WORK_ROOT/fetched-rest-repo"
  rm -rf "$fetch_repo" "$archive_output"
  mkdir -p "$archive_output"
  git init --quiet "$fetch_repo"
  git -C "$fetch_repo" fetch --quiet --depth=1 \
    "$AZURE_SDK_GIT_URL" "refs/heads/$REST_BRANCH"
  local fetched_commit
  fetched_commit="$(git -C "$fetch_repo" rev-parse FETCH_HEAD)"
  if [[ "$fetched_commit" != "$requested_commit" ]]; then
    printf 'fetched REST branch changed during validation\n' >&2
    return 1
  fi
  git -C "$fetch_repo" archive "$fetched_commit" | tar -x -C "$archive_output"
  validate_rest_archive "$archive_output"

  local archive_hash
  archive_hash="$(fetch_hash "$archive_output")"
  if [[ "$verify_url_hash" == 1 ]]; then
    local url_hash
    url_hash="$(fetch_hash "$AZURE_SDK_URL#$requested_commit")"
    if [[ "$archive_hash" != "$url_hash" ]]; then
      printf 'REST archive hash differs from immutable Git URL hash\n' >&2
      return 1
    fi
  fi
  printf '%s\n' "$archive_hash"
}

verify_local_stage() {
  local stage="$STAGE_ROOT/verify"
  reset_work
  rm -rf "$stage"
  mkdir -p "$stage"
  check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
  generate_rest "$stage/rest"
  stage_sdk "$stage/sdk" local
  test_local_stages "$stage/rest" "$stage/sdk"
  rm -rf "$WORK_ROOT"
  printf 'release dry-run verified at %s\n' "$stage"
}

verify_index_matches_stage() {
  local repository="$1"
  local stage="$2"
  python3 - "$repository" "$stage" <<'PY'
from pathlib import Path
import os
import subprocess
import sys

repository = Path(sys.argv[1])
stage = Path(sys.argv[2])
stage_files = {}
for path in stage.rglob("*"):
    if path.is_dir():
        continue
    relative = path.relative_to(stage).as_posix()
    stage_files[relative] = (
        os.readlink(path).encode() if path.is_symlink() else path.read_bytes()
    )

raw = subprocess.check_output(
    ["git", "-C", str(repository), "ls-files", "-z"]
)
tracked = {item.decode() for item in raw.split(b"\0") if item}
if tracked != set(stage_files):
    raise SystemExit(
        "publication index differs from declared stage: "
        f"stage={sorted(stage_files)}, index={sorted(tracked)}"
    )
for relative, expected in stage_files.items():
    actual = subprocess.check_output(
        ["git", "-C", str(repository), "show", f":{relative}"]
    )
    if actual != expected:
        raise SystemExit(f"publication index bytes differ: {relative}")
PY
}

package_name_from_zon() {
  local zon="$1"
  python3 - "$zon" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
match = re.search(r"(?m)^\s*\.name\s*=\s*\.([A-Za-z0-9_]+)\s*,\s*$", text)
if not match:
    raise SystemExit("package name missing")
print(match.group(1))
PY
}

publish_stage() {
  local repository="$1"
  local stage="$2"
  local branch="$3"
  local message="$4"
  local remote="$5"
  local dry_run="$6"
  local existing_commit=""
  local temp_branch=""
  local package=""

  case "$branch" in
    "$REST_BRANCH") package="$REST_PACKAGE" ;;
    "$SDK_BRANCH") package="$SDK_PACKAGE" ;;
    *) package="$(package_name_from_zon "$stage/build.zig.zon")" ;;
  esac
  validate_package "$stage" "$package"

  existing_commit="$(
    git -C "$repository" ls-remote "$remote" "refs/heads/$branch" |
      awk 'NR == 1 { print $1 }'
  )"
  ACTIVE_REPO="$repository"
  ACTIVE_WORKTREE="$STAGE_ROOT/worktrees/$(printf '%s' "$branch" | tr / _)-$$"
  mkdir -p "$(dirname "$ACTIVE_WORKTREE")"
  git -C "$repository" worktree add --detach --no-checkout \
    "$ACTIVE_WORKTREE" HEAD >/dev/null

  if [[ -z "$existing_commit" ]]; then
    temp_branch="container-registry-release-$$"
    ACTIVE_BRANCH="$temp_branch"
    git -C "$ACTIVE_WORKTREE" switch --orphan "$temp_branch" >/dev/null
    if [[ -n "$(git -C "$ACTIVE_WORKTREE" status --porcelain --untracked-files=all)" ]]; then
      printf 'new orphan publication worktree is not empty\n' >&2
      return 1
    fi
  else
    git -C "$ACTIVE_WORKTREE" fetch --quiet "$remote" "refs/heads/$branch"
    if [[ "$(git -C "$ACTIVE_WORKTREE" rev-parse FETCH_HEAD)" != "$existing_commit" ]]; then
      printf 'release branch changed during publication setup\n' >&2
      return 1
    fi
    git -C "$ACTIVE_WORKTREE" switch --detach FETCH_HEAD >/dev/null
    git -C "$ACTIVE_WORKTREE" rm -r --ignore-unmatch -- . >/dev/null
    git -C "$ACTIVE_WORKTREE" clean -fdx -- . >/dev/null
  fi

  install_declared_stage "$stage" "$ACTIVE_WORKTREE"
  git -C "$ACTIVE_WORKTREE" add --all -- .
  verify_index_matches_stage "$ACTIVE_WORKTREE" "$stage"
  git -C "$ACTIVE_WORKTREE" commit --quiet -m "$message"
  PUBLISHED_COMMIT="$(git -C "$ACTIVE_WORKTREE" rev-parse HEAD)"

  if [[ -z "$existing_commit" ]]; then
    if [[ "$(git -C "$ACTIVE_WORKTREE" rev-list --parents -n 1 HEAD | awk '{print NF}')" != 1 ]]; then
      printf 'initial release commit unexpectedly has a parent\n' >&2
      return 1
    fi
  elif [[ "$(git -C "$ACTIVE_WORKTREE" rev-parse HEAD^)" != "$existing_commit" ]]; then
    printf 'subsequent release commit is not a descendant of the remote tip\n' >&2
    return 1
  fi

  if [[ "$dry_run" == 1 ]]; then
    printf 'dry-run release commit validated: %s\n' "$PUBLISHED_COMMIT"
  else
    git -C "$ACTIVE_WORKTREE" push --quiet "$remote" \
      "HEAD:refs/heads/$branch"
    printf 'published %s at %s\n' "$branch" "$PUBLISHED_COMMIT"
  fi
  cleanup_active_publication
}

parse_publish_args() {
  PUBLISH_DRY_RUN=0
  PUBLISH_REMOTE=origin
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        PUBLISH_DRY_RUN=1
        ;;
      --remote)
        shift
        if [[ $# -eq 0 ]]; then
          printf '%s\n' '--remote requires a value' >&2
          return 2
        fi
        PUBLISH_REMOTE="$1"
        ;;
      *)
        printf 'unknown publication option: %s\n' "$1" >&2
        return 2
        ;;
    esac
    shift
  done
}

write_fixture_package() {
  local directory="$1"
  local package="$2"
  local sdk_url="${3:-}"
  local sdk_hash="${4:-}"
  local fingerprint="0x1234567890abcdef"
  case "$package" in
    azure_sdk) fingerprint="0x27c178e4bf582df6" ;;
    azure_rest_container_registry) fingerprint="0x5dd0e10aa1e38a93" ;;
    wrong_rest_package) fingerprint="0xb618af810095b2e1" ;;
  esac
  rm -rf "$directory"
  mkdir -p "$directory/src"
  printf '.zig-cache/\nzig-out/\nzig-pkg/\n' >"$directory/.gitignore"
  cp "$ROOT/LICENSE.txt" "$directory/LICENSE.txt"
  printf '# fixture %s\n' "$package" >"$directory/README.md"
  printf 'pub const fixture = true;\n' >"$directory/src/root.zig"
  cat >"$directory/build.zig" <<EOF
const std = @import("std");
pub fn build(b: *std.Build) void {
    _ = b.addModule("$package", .{ .root_source_file = b.path("src/root.zig") });
}
EOF
  if [[ "$package" == "$REST_PACKAGE" ]]; then
    cat >"$directory/build.zig.zon" <<EOF
.{
    .name = .$package,
    .version = "0.1.0",
    .fingerprint = $fingerprint,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{
        .azure_sdk = .{
            .url = "$sdk_url",
            .hash = "$sdk_hash",
        },
        .serde = .{
            .url = "git+https://github.com/cataggar/serde.zig#7012f58c7ddf490125852e1d22006b552a1693c7",
            .hash = "serde-1.0.1-1DszT-e9DABp6u1PoDvGFzeGaST2hRp2KGtGn_CkIl0J",
        },
    },
    .paths = .{
        ".gitignore",
        "build.zig",
        "build.zig.zon",
        "src",
        "README.md",
        "LICENSE.txt",
    },
}
EOF
  else
    cat >"$directory/build.zig.zon" <<EOF
.{
    .name = .$package,
    .version = "0.1.0",
    .fingerprint = $fingerprint,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{},
    .paths = .{
        ".gitignore",
        "build.zig",
        "build.zig.zon",
        "src",
        "README.md",
        "LICENSE.txt",
    },
}
EOF
  fi
}

run_self_test() {
  reset_work
  SELF_TEST_ROOT="$STAGE_ROOT/self-test"
  rm -rf "$SELF_TEST_ROOT"
  mkdir -p "$SELF_TEST_ROOT"
  local source_repo="$SELF_TEST_ROOT/source"
  local bare_remote="$SELF_TEST_ROOT/remote.git"
  local package_dir="$source_repo/package"
  local fixture_stage="$SELF_TEST_ROOT/stage"
  local main_commit
  local bad_commit
  local good_commit
  local main_hash
  local resolved_hash
  local fixture_sdk_url="git+https://example.invalid/azure-sdk-for-zig"

  git init --quiet "$source_repo"
  git -C "$source_repo" config user.name "Container Registry release test"
  git -C "$source_repo" config user.email "release-test@example.invalid"
  write_fixture_package "$package_dir" azure_sdk
  cp -R "$package_dir/." "$source_repo/"
  rm -rf "$package_dir"
  git -C "$source_repo" add --all
  git -C "$source_repo" commit --quiet -m "main fixture"
  git -C "$source_repo" branch -M main
  main_commit="$(git -C "$source_repo" rev-parse HEAD)"

  git init --bare --quiet "$bare_remote"
  git -C "$source_repo" push --quiet "$bare_remote" \
    "main:refs/heads/main"
  mkdir -p "$SELF_TEST_ROOT/main-archive"
  git -C "$source_repo" archive "$main_commit" |
    tar -x -C "$SELF_TEST_ROOT/main-archive"
  main_hash="$(
    cd "$SELF_TEST_ROOT"
    zig fetch --global-cache-dir "$SELF_TEST_ROOT/cache" main-archive
  )"

  git -C "$source_repo" switch -c rest-fixture >/dev/null
  write_fixture_package "$package_dir" wrong_rest_package
  cp -R "$package_dir/." "$source_repo/"
  rm -rf "$package_dir"
  git -C "$source_repo" add --all
  git -C "$source_repo" commit --quiet -m "mismatched REST fixture"
  bad_commit="$(git -C "$source_repo" rev-parse HEAD)"
  git -C "$source_repo" push --quiet "$bare_remote" \
    "HEAD:refs/heads/$REST_BRANCH"

  if env \
    AZURE_SDK_GIT_URL="$bare_remote" \
    AZURE_SDK_URL="$fixture_sdk_url" \
    AZURE_SDK_COMMIT="$main_commit" \
    AZURE_SDK_HASH="$main_hash" \
    CONTAINER_REGISTRY_RELEASE_SKIP_URL_HASH_CHECK=1 \
    CONTAINER_REGISTRY_RELEASE_ROOT="$SELF_TEST_ROOT/main-negative" \
    "$SCRIPT" _resolve-rest "$main_commit" >/dev/null 2>&1
  then
    printf 'self-test: main commit was accepted as REST release\n' >&2
    return 1
  fi
  if env \
    AZURE_SDK_GIT_URL="$bare_remote" \
    AZURE_SDK_URL="$fixture_sdk_url" \
    AZURE_SDK_COMMIT="$main_commit" \
    AZURE_SDK_HASH="$main_hash" \
    CONTAINER_REGISTRY_RELEASE_SKIP_URL_HASH_CHECK=1 \
    CONTAINER_REGISTRY_RELEASE_ROOT="$SELF_TEST_ROOT/package-negative" \
    "$SCRIPT" _resolve-rest "$bad_commit" >/dev/null 2>&1
  then
    printf 'self-test: mismatched REST package was accepted\n' >&2
    return 1
  fi

  write_fixture_package \
    "$package_dir" "$REST_PACKAGE" \
    "$fixture_sdk_url#$main_commit" "$main_hash"
  cp -R "$package_dir/." "$source_repo/"
  rm -rf "$package_dir"
  git -C "$source_repo" add --all
  git -C "$source_repo" commit --quiet -m "valid REST fixture"
  good_commit="$(git -C "$source_repo" rev-parse HEAD)"
  git -C "$source_repo" push --quiet "$bare_remote" \
    "HEAD:refs/heads/$REST_BRANCH"
  resolved_hash="$(env \
    AZURE_SDK_GIT_URL="$bare_remote" \
    AZURE_SDK_URL="$fixture_sdk_url" \
    AZURE_SDK_COMMIT="$main_commit" \
    AZURE_SDK_HASH="$main_hash" \
    CONTAINER_REGISTRY_RELEASE_SKIP_URL_HASH_CHECK=1 \
    CONTAINER_REGISTRY_RELEASE_ROOT="$SELF_TEST_ROOT/package-positive" \
    "$SCRIPT" _resolve-rest "$good_commit")"
  case "$resolved_hash" in
    "$REST_PACKAGE"-*) ;;
    *)
      printf 'self-test: exact REST archive did not produce a package hash\n' >&2
      return 1
      ;;
  esac

  rm -rf "$fixture_stage"
  mkdir -p "$fixture_stage"
  git -C "$source_repo" archive HEAD | tar -x -C "$fixture_stage"
  validate_package "$fixture_stage" "$REST_PACKAGE"

  local publication_branch="test/container_registry"
  local initial_commit
  local subsequent_commit
  publish_stage \
    "$source_repo" "$fixture_stage" "$publication_branch" \
    "initial fixture publication" "$bare_remote" 1
  initial_commit="$PUBLISHED_COMMIT"
  if [[ "$(git -C "$source_repo" rev-list --parents -n 1 "$initial_commit" | awk '{print NF}')" != 1 ]]; then
    printf 'self-test: initial dry-run publication was not orphaned\n' >&2
    return 1
  fi
  git -C "$source_repo" push --quiet "$bare_remote" \
    "$initial_commit:refs/heads/$publication_branch"

  printf '# fixture %s v2\n' "$REST_PACKAGE" >"$fixture_stage/README.md"
  publish_stage \
    "$source_repo" "$fixture_stage" "$publication_branch" \
    "subsequent fixture publication" "$bare_remote" 1
  subsequent_commit="$PUBLISHED_COMMIT"
  if [[ "$(git -C "$source_repo" rev-parse "$subsequent_commit^")" != "$initial_commit" ]]; then
    printf 'self-test: subsequent dry-run was not a descendant\n' >&2
    return 1
  fi
  if [[ "$(remote_ref_commit "$bare_remote" "$publication_branch")" != "$initial_commit" ]]; then
    printf 'self-test: dry-run unexpectedly changed the remote\n' >&2
    return 1
  fi

  publish_stage \
    "$source_repo" "$fixture_stage" "$publication_branch" \
    "subsequent fixture publication" "$bare_remote" 0
  if [[ "$(git -C "$source_repo" rev-parse "$PUBLISHED_COMMIT^")" != "$initial_commit" ]]; then
    printf 'self-test: local fast-forward publication parent differs\n' >&2
    return 1
  fi
  if [[ "$(remote_ref_commit "$bare_remote" "$publication_branch")" != "$PUBLISHED_COMMIT" ]]; then
    printf 'self-test: local fast-forward publication did not update remote\n' >&2
    return 1
  fi
  if git -C "$source_repo" branch --list 'container-registry-release-*' |
      grep -q .
  then
    printf 'self-test: temporary publication branch was not removed\n' >&2
    return 1
  fi

  rm -rf "$SELF_TEST_ROOT"
  SELF_TEST_ROOT=""
  rm -rf "$WORK_ROOT"
  printf '%s\n' \
    'release self-test passed: exact REST ref/package rejection, initial and subsequent dry-runs, cleanup, and local fast-forward push'
}

command="${1:-}"
case "$command" in
  hash-check)
    reset_work
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    rm -rf "$WORK_ROOT"
    printf 'verified immutable azure_sdk pin %s\n' "$AZURE_SDK_COMMIT"
    ;;
  verify|dry-run)
    verify_local_stage
    ;;
  prepare-rest)
    reset_work
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    output="$STAGE_ROOT/publish/rest"
    generate_rest "$output"
    copy_declared_stage "$output" "$WORK_ROOT/test-packages/rest"
    test_rest "$WORK_ROOT/test-packages/rest"
    rm -rf "$WORK_ROOT/test-packages" "$WORK_ROOT/caches"
    validate_rest_archive "$output"
    rm -rf "$WORK_ROOT"
    printf 'REST release package ready: %s\n' "$output"
    printf 'Publish it with: %s publish-rest\n' "$SCRIPT"
    ;;
  prepare-sdk)
    rest_commit="${2:-}"
    if [[ ! "$rest_commit" =~ ^[0-9a-f]{40}$ ]]; then
      printf 'prepare-sdk requires a full lowercase 40-character REST commit ID\n' >&2
      exit 1
    fi
    reset_work
    rest_archive="$WORK_ROOT/rest-archive"
    computed_hash="$(resolve_rest_package "$rest_commit" "$rest_archive")"
    supplied_hash="${3:-$computed_hash}"
    if [[ "$computed_hash" != "$supplied_hash" ]]; then
      printf 'REST package hash mismatch\n  computed: %s\n  supplied: %s\n' \
        "$computed_hash" "$supplied_hash" >&2
      exit 1
    fi
    check_hash "$AZURE_SDK_URL#$AZURE_SDK_COMMIT" "$AZURE_SDK_HASH"
    output="$STAGE_ROOT/publish/sdk"
    stage_sdk "$output" published "$rest_commit" "$computed_hash"
    test_published_sdk_stage "$output"
    rm -rf "$WORK_ROOT"
    printf 'SDK release package ready: %s\n' "$output"
    printf 'Pinned REST commit: %s\nPinned REST hash: %s\n' \
      "$rest_commit" "$computed_hash"
    printf 'Publish it with: %s publish-sdk\n' "$SCRIPT"
    ;;
  publish-rest)
    parse_publish_args "$@"
    validate_rest_archive "$STAGE_ROOT/publish/rest"
    publish_stage \
      "$ROOT" "$STAGE_ROOT/publish/rest" "$REST_BRANCH" \
      "rest/container_registry: release generated package" \
      "$PUBLISH_REMOTE" "$PUBLISH_DRY_RUN"
    ;;
  publish-sdk)
    parse_publish_args "$@"
    validate_package "$STAGE_ROOT/publish/sdk" "$SDK_PACKAGE"
    publish_stage \
      "$ROOT" "$STAGE_ROOT/publish/sdk" "$SDK_BRANCH" \
      "sdk/container_registry: release package" \
      "$PUBLISH_REMOTE" "$PUBLISH_DRY_RUN"
    ;;
  self-test)
    run_self_test
    ;;
  _resolve-rest)
    rest_commit="${2:-}"
    if [[ ! "$rest_commit" =~ ^[0-9a-f]{40}$ ]]; then
      exit 1
    fi
    reset_work
    verify_url_hash=1
    if [[ "${CONTAINER_REGISTRY_RELEASE_SKIP_URL_HASH_CHECK:-0}" == 1 ]]; then
      verify_url_hash=0
    fi
    resolve_rest_package \
      "$rest_commit" "$WORK_ROOT/rest-archive" "$verify_url_hash"
    ;;
  *)
    usage
    exit 2
    ;;
esac
