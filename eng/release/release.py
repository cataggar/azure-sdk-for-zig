#!/usr/bin/env python3
"""Registry-driven package release preparation and publication."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import stat
import subprocess
import sys
import tarfile
import time
from urllib.parse import unquote, urlsplit

from registry import Package, RegistryError, load as load_registry
import zon


class ReleaseError(RuntimeError):
    pass


@dataclass(frozen=True)
class RemoteIdentity:
    fetch_url: str
    push_url: str
    repository: str
    zig_url: str


FORBIDDEN_PARTS = {
    ".git",
    ".release",
    ".zig-cache",
    "__pycache__",
    "zig-cache",
    "zig-out",
    "zig-pkg",
}
REQUIRED_PATHS = {"build.zig", "build.zig.zon", "README.md", "LICENSE.txt"}
COMMIT_RE = re.compile(r"[0-9a-f]{40}\Z")


def run(
    args: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    check: bool = True,
    input_data: bytes | None = None,
) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(
        args,
        cwd=cwd,
        env=env,
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode:
        detail = result.stderr.decode(errors="replace").strip()
        command = " ".join(args)
        raise ReleaseError(f"command failed ({command}): {detail}")
    return result


def git(root: Path, *args: str, check: bool = True) -> str:
    result = run(
        ["git", "-C", str(root), *args],
        cwd=root.parent,
        check=check,
    )
    return result.stdout.decode().strip()


def safe_remove(path: Path, allowed_root: Path) -> None:
    if not path.exists() and not path.is_symlink():
        return
    resolved_parent = path.parent.resolve()
    allowed = allowed_root.resolve()
    if resolved_parent != allowed and allowed not in resolved_parent.parents:
        raise ReleaseError(f"refusing to remove path outside release root: {path}")
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def remote_ref(remote: str, ref: str, cwd: Path) -> str | None:
    output = git(cwd, "ls-remote", remote, ref)
    if not output:
        return None
    rows = [line.split() for line in output.splitlines()]
    exact = [commit for commit, name in rows if name == ref]
    return exact[0] if exact else None


def remote_tag_commit(remote: str, tag: str, cwd: Path) -> str | None:
    ref = f"refs/tags/{tag}"
    output = git(cwd, "ls-remote", remote, ref, f"{ref}^{{}}")
    if not output:
        return None
    rows = {name: commit for commit, name in (line.split() for line in output.splitlines())}
    return rows.get(f"{ref}^{{}}") or rows.get(ref)


def _remote_urls(root: Path, remote: str, *, push: bool) -> list[str] | None:
    args = ["git", "remote", "get-url"]
    if push:
        args.append("--push")
    args.append("--all")
    args.append(remote)
    result = run(args, cwd=root, check=False)
    if result.returncode:
        return None
    return [
        line
        for line in result.stdout.decode().splitlines()
        if line
    ]


def _reject_url_rewrites(root: Path) -> None:
    result = run(
        [
            "git",
            "config",
            "--show-origin",
            "--show-scope",
            "--get-regexp",
            r"^url\..*\.(insteadof|pushinsteadof)$",
        ],
        cwd=root,
        check=False,
    )
    if result.returncode == 0 and result.stdout:
        raise ReleaseError(
            "effective Git URL rewrite configuration is not allowed for "
            "package releases; remove all url.*.insteadOf and "
            "url.*.pushInsteadOf rules"
        )
    if result.returncode not in {0, 1}:
        detail = result.stderr.decode(errors="replace").strip()
        raise ReleaseError(f"failed to inspect Git URL rewrite configuration: {detail}")


def _canonical_repository(root: Path, raw: str) -> str:
    value = raw.removeprefix("git+")
    candidate = Path(value)
    if (
        value.startswith("/")
        or value.startswith("./")
        or value.startswith("../")
        or (root / candidate).exists()
    ):
        absolute = candidate if candidate.is_absolute() else root / candidate
        return f"file:{absolute.resolve()}"

    scp = re.fullmatch(r"(?:[^@]+@)?([^:]+):(.+)", value)
    if scp and "://" not in value:
        host = scp.group(1).lower()
        path = scp.group(2).strip("/")
        if path.endswith(".git"):
            path = path[:-4]
        return f"{host}/{path}"

    parsed = urlsplit(value)
    if parsed.scheme == "file":
        return f"file:{Path(unquote(parsed.path)).resolve()}"
    if parsed.scheme not in {"git", "http", "https", "ssh"} or not parsed.hostname:
        raise ReleaseError("cannot identify publication repository URL")
    if parsed.password is not None:
        raise ReleaseError("remote URL must not contain an embedded password")
    if parsed.scheme in {"http", "https"} and parsed.username is not None:
        raise ReleaseError("remote URL must not contain embedded credentials")
    host = parsed.hostname.lower()
    default_port = {"http": 80, "https": 443, "ssh": 22}.get(parsed.scheme)
    if parsed.port and parsed.port != default_port:
        host = f"{host}:{parsed.port}"
    path = parsed.path.strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    if not path:
        raise ReleaseError("remote URL has no repository path")
    return f"{host}/{path}"


def _operation_url(root: Path, raw: str) -> str:
    value = raw.removeprefix("git+")
    candidate = Path(value)
    if (
        value.startswith("/")
        or value.startswith("./")
        or value.startswith("../")
        or (root / candidate).exists()
    ):
        absolute = candidate if candidate.is_absolute() else root / candidate
        return str(absolute.resolve())
    return raw


def resolve_remote_identity(root: Path, remote: str) -> RemoteIdentity:
    _reject_url_rewrites(root)
    fetch_urls = _remote_urls(root, remote, push=False)
    if fetch_urls is None:
        fetch_url = remote
        push_url = remote
    else:
        if len(fetch_urls) != 1:
            raise ReleaseError(
                "publication remote must have exactly one fetch URL; "
                f"found {len(fetch_urls)}"
            )
        push_urls = _remote_urls(root, remote, push=True) or []
        if len(push_urls) != 1:
            raise ReleaseError(
                "publication remote must have exactly one push URL; "
                f"found {len(push_urls)}"
            )
        fetch_url = fetch_urls[0]
        push_url = push_urls[0]

    fetch_url = _operation_url(root, fetch_url)
    push_url = _operation_url(root, push_url)
    fetch_repository = _canonical_repository(root, fetch_url)
    push_repository = _canonical_repository(root, push_url)
    if fetch_repository != push_repository:
        raise ReleaseError(
            "publication remote fetch/push repository mismatch:\n"
            f"  fetch: {fetch_url}\n"
            f"  push:  {push_url}"
        )

    raw = fetch_url
    candidate = Path(raw)
    if (
        raw.startswith("/")
        or raw.startswith("./")
        or raw.startswith("../")
        or candidate.exists()
    ):
        absolute = candidate if candidate.is_absolute() else root / candidate
        raw = absolute.resolve().as_uri()
    if raw.startswith("git+"):
        zig_url = raw
    elif raw.startswith(("https://", "http://", "ssh://", "file://")):
        zig_url = f"git+{raw}"
    elif re.fullmatch(r"[^@]+@[^:]+:.+", raw):
        user_host, path = raw.split(":", 1)
        zig_url = f"git+ssh://{user_host}/{path}"
    else:
        raise ReleaseError(f"cannot convert remote URL for Zig: {raw}")
    return RemoteIdentity(
        fetch_url=fetch_url,
        push_url=push_url,
        repository=fetch_repository,
        zig_url=zig_url,
    )


def extract_archive(
    repository: Path,
    commit: str,
    destination: Path,
    pathspec: str | None = None,
) -> None:
    safe_remove(destination, destination.parent)
    destination.mkdir(parents=True)
    command = ["git", "archive", "--format=tar", commit]
    if pathspec is not None:
        command.extend(["--", pathspec])
    archive = run(command, cwd=repository).stdout
    archive_path = destination.parent / f"{destination.name}.tar"
    archive_path.write_bytes(archive)
    try:
        with tarfile.open(archive_path, "r:") as tar:
            for member in tar.getmembers():
                path = PurePosixPath(member.name)
                if path.is_absolute() or ".." in path.parts:
                    raise ReleaseError("unsafe path in Git archive")
                if member.issym() or member.islnk():
                    raise ReleaseError(f"symlink in release archive: {member.name}")
            tar.extractall(destination, filter="data")
    finally:
        archive_path.unlink(missing_ok=True)


def copy_tree(source: Path, destination: Path, allowed_root: Path) -> None:
    safe_remove(destination, allowed_root)
    shutil.copytree(source, destination, copy_function=shutil.copy2)


def file_inventory(root: Path) -> tuple[list[dict[str, object]], str]:
    files: list[dict[str, object]] = []
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        parts = PurePosixPath(relative).parts
        if any(part in FORBIDDEN_PARTS for part in parts):
            raise ReleaseError(f"forbidden release artifact: {relative}")
        if path.is_symlink():
            raise ReleaseError(f"symlinks are not allowed: {relative}")
        if path.is_dir():
            continue
        if not path.is_file():
            raise ReleaseError(f"non-regular release file: {relative}")
        data = path.read_bytes()
        executable = bool(path.stat().st_mode & stat.S_IXUSR)
        item = {
            "path": relative,
            "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "executable": executable,
        }
        files.append(item)
        encoded = relative.encode()
        digest.update(len(encoded).to_bytes(4, "big"))
        digest.update(encoded)
        digest.update(b"\1" if executable else b"\0")
        digest.update(len(data).to_bytes(8, "big"))
        digest.update(data)
    return files, digest.hexdigest()


def validate_tree(
    root: Path,
    package: Package,
    *,
    published: bool,
    exact_top_level: bool = True,
) -> zon.Manifest:
    if not root.is_dir():
        raise ReleaseError(f"package directory does not exist: {root}")
    missing = sorted(path for path in REQUIRED_PATHS if not (root / path).is_file())
    if missing:
        raise ReleaseError(f"{package.name}: missing required files: {missing}")

    expected_top = set(package.publish_paths)
    actual_top = {path.name for path in root.iterdir()}
    if exact_top_level and actual_top != expected_top:
        raise ReleaseError(
            f"{package.name}: staged top-level entries differ: "
            f"expected {sorted(expected_top)}, got {sorted(actual_top)}"
        )
    file_inventory(root)

    text = (root / "build.zig.zon").read_text(encoding="utf-8")
    try:
        manifest = zon.parse(text)
        version = zon.parse_semver(manifest.version)
        registry_version = zon.parse_semver(package.version)
    except zon.ZonError as error:
        raise ReleaseError(f"{package.name}: {error}") from error
    if manifest.name != package.name:
        raise ReleaseError(
            f"{package.name}: manifest package name is {manifest.name}"
        )
    if version != registry_version:
        raise ReleaseError(
            f"{package.name}: manifest version {manifest.version} "
            f"does not match registry version {package.version}"
        )
    if set(manifest.paths) != expected_top or len(manifest.paths) != len(expected_top):
        raise ReleaseError(
            f"{package.name}: .paths must exactly match registry publish_paths"
        )

    expected_dependencies = set(package.dependencies) | set(
        package.external_dependencies
    )
    if set(manifest.dependencies) != expected_dependencies:
        raise ReleaseError(
            f"{package.name}: dependency keys differ: expected "
            f"{sorted(expected_dependencies)}, got {sorted(manifest.dependencies)}"
        )
    for name in package.dependencies:
        dependency = manifest.dependencies[name]
        if published:
            if dependency.path is not None:
                raise ReleaseError(f"{package.name}: published path dependency: {name}")
            if not dependency.url or not dependency.package_hash:
                raise ReleaseError(f"{package.name}: incomplete immutable pin: {name}")
        elif (
            dependency.path is None
            or dependency.url is not None
            or dependency.package_hash is not None
        ):
            raise ReleaseError(f"{package.name}: {name} must be a local path on main")
    for name in package.external_dependencies:
        dependency = manifest.dependencies[name]
        if dependency.path is not None:
            raise ReleaseError(f"{package.name}: external path dependency: {name}")
        if not dependency.url or not dependency.package_hash:
            raise ReleaseError(f"{package.name}: incomplete external dependency: {name}")
    return manifest


@dataclass(frozen=True)
class BranchState:
    commit: str | None
    previous_name: str | None
    previous_version: str | None


class Engine:
    def __init__(
        self,
        root: Path,
        *,
        remote: str = "origin",
        release_root: Path | None = None,
        registry_path: Path | None = None,
    ) -> None:
        self.root = root.resolve()
        self.remote = remote
        self.release_root = (
            release_root.resolve()
            if release_root
            else self.root / ".release" / "packages"
        )
        self.registry_path = registry_path or self.root / "eng" / "packages.zig"
        self.packages = load_registry(self.registry_path)
        self._active_worktrees: list[tuple[Path, str | None]] = []

    def package(self, name: str) -> Package:
        try:
            return self.packages[name]
        except KeyError as error:
            raise ReleaseError(f"unknown registry package: {name}") from error

    def package_root(self, package: Package) -> Path:
        return self.root / package.source_path

    @staticmethod
    def _require_main_owned(package: Package) -> None:
        if package.ownership != "main_owned":
            raise ReleaseError(
                f"{package.name}: branch-owned packages must be released from "
                "their package branch"
            )

    def _validate_source_workspace(
        self,
        package: Package,
        package_root: Path,
        workspace_root: Path,
    ) -> zon.Manifest:
        manifest = validate_tree(
            package_root,
            package,
            published=False,
            exact_top_level=False,
        )
        for dependency_name in package.dependencies:
            dependency_path = manifest.dependencies[dependency_name].path
            if dependency_path is None:
                raise ReleaseError(
                    f"{package.name}: missing local path for {dependency_name}"
                )
            dependency = self.package(dependency_name)
            path = Path(dependency_path)
            if path.is_absolute():
                raise ReleaseError(
                    f"{package.name}: dependency {dependency_name} path is absolute"
                )
            resolved = (package_root / path).resolve()
            expected = (workspace_root / dependency.source_path).resolve()
            if resolved != expected:
                raise ReleaseError(
                    f"{package.name}: dependency {dependency_name} path resolves "
                    f"to {resolved}, expected {expected}"
                )
            if not expected.is_dir():
                raise ReleaseError(
                    f"{package.name}: dependency source directory is missing: "
                    f"{expected}"
                )
        return manifest

    def stage_base(self, package: Package) -> Path:
        return self.release_root / package.name

    def stage_dir(self, package: Package) -> Path:
        return self.stage_base(package) / "stage"

    def manifest_path(self, package: Package) -> Path:
        return self.stage_base(package) / "stage-manifest.json"

    def work_dir(self, package: Package) -> Path:
        return self.stage_base(package) / "work"

    @staticmethod
    def _empty_hooks_path(work: Path) -> Path:
        hooks = work / "empty-hooks"
        hooks.mkdir(parents=True, exist_ok=True)
        return hooks

    def source_provenance(self) -> tuple[str, str, str]:
        ref = git(self.root, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
        if not ref:
            raise ReleaseError("source repository is detached")
        if ref != "main":
            raise ReleaseError(
                f"source branch must be main; found {ref}"
            )
        commit = git(self.root, "rev-parse", "HEAD")
        if not COMMIT_RE.fullmatch(commit):
            raise ReleaseError("source commit is not a full lowercase object ID")
        status = git(
            self.root,
            "status",
            "--porcelain=v1",
            "--untracked-files=all",
        )
        ignored = self.release_root.relative_to(self.root).as_posix().rstrip("/")
        dirty = []
        for line in status.splitlines():
            if not line:
                continue
            path = line[3:].rstrip("/")
            if (
                path == ignored
                or path.startswith(f"{ignored}/")
                or ignored.startswith(f"{path}/")
            ):
                continue
            dirty.append(line)
        if dirty:
            raise ReleaseError(
                "source repository is dirty:\n" + "\n".join(dirty)
            )
        if git(self.root, "rev-parse", ref) != commit:
            raise ReleaseError("named source ref does not point to HEAD")

        remote_identity = resolve_remote_identity(self.root, self.remote)
        main_ref = "refs/heads/main"
        advertised_main = remote_ref(
            remote_identity.fetch_url,
            main_ref,
            self.root,
        )
        if advertised_main is None:
            raise ReleaseError("publication remote is missing refs/heads/main")
        git(
            self.root,
            "fetch",
            "--quiet",
            "--no-tags",
            remote_identity.fetch_url,
            main_ref,
        )
        fetched_main = git(self.root, "rev-parse", "FETCH_HEAD")
        current_main = remote_ref(
            remote_identity.fetch_url,
            main_ref,
            self.root,
        )
        if fetched_main != advertised_main or current_main != fetched_main:
            raise ReleaseError("publication remote main moved while resolving provenance")
        if commit != fetched_main:
            raise ReleaseError(
                "source HEAD does not match publication remote refs/heads/main:\n"
                f"  source: {commit}\n"
                f"  remote: {fetched_main}"
            )
        return ref, commit, fetched_main

    def _clean_work(self, package: Package) -> Path:
        work = self.work_dir(package)
        safe_remove(work, self.release_root)
        work.mkdir(parents=True)
        return work

    def _command_env(self, work: Path) -> dict[str, str]:
        env: dict[str, str] = {}
        for name in (
            "PATH",
            "SystemRoot",
            "WINDIR",
            "COMSPEC",
            "PATHEXT",
            "SYSTEMDRIVE",
            "SDKROOT",
            "DEVELOPER_DIR",
            "SSL_CERT_FILE",
            "SSL_CERT_DIR",
            "NIX_SSL_CERT_FILE",
            "LANG",
            "LC_ALL",
            "LC_CTYPE",
            "TZ",
        ):
            value = os.environ.get(name)
            if value is not None:
                env[name] = value
        if "PATH" not in env:
            raise ReleaseError("PATH is required to run package commands")

        local_cache = work / "caches" / "local"
        global_cache = work / "caches" / "global"
        temp = work / "tmp"
        home = work / "home"
        xdg_config = home / ".config"
        xdg_cache = work / "caches" / "xdg"
        xdg_data = home / ".local" / "share"
        for path in (
            local_cache,
            global_cache,
            temp,
            home,
            xdg_config,
            xdg_cache,
            xdg_data,
        ):
            path.mkdir(parents=True, exist_ok=True)
        env.update(
            {
                "HOME": str(home),
                "USERPROFILE": str(home),
                "TMPDIR": str(temp),
                "TMP": str(temp),
                "TEMP": str(temp),
                "ZIG_LOCAL_CACHE_DIR": str(local_cache),
                "ZIG_GLOBAL_CACHE_DIR": str(global_cache),
                "XDG_CONFIG_HOME": str(xdg_config),
                "XDG_CACHE_HOME": str(xdg_cache),
                "XDG_DATA_HOME": str(xdg_data),
                "APPDATA": str(xdg_config),
                "LOCALAPPDATA": str(xdg_data),
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": os.devnull,
                "GIT_TERMINAL_PROMPT": "0",
            }
        )
        return env

    def _run_package_commands(self, package: Package, directory: Path, work: Path) -> None:
        env = self._command_env(work)
        commands = [
            package.test_command,
            package.examples_command,
            package.live_test_command,
        ]
        for command in commands:
            if not command:
                continue
            result = subprocess.run(
                ["bash", "-euo", "pipefail", "-c", command],
                cwd=directory,
                env=env,
            )
            if result.returncode:
                raise ReleaseError(
                    f"{package.name}: validation command failed: {command}"
                )

    def _verify_regeneration(
        self,
        package: Package,
        source_commit: str,
        work: Path,
    ) -> None:
        if not package.regeneration_command:
            return
        worktree = work / "regeneration-worktree"
        empty_hooks = self._empty_hooks_path(work)
        git(
            self.root,
            "-c",
            f"core.hooksPath={empty_hooks}",
            "worktree",
            "add",
            "--quiet",
            "--detach",
            str(worktree),
            source_commit,
        )
        self._active_worktrees.append((worktree, None))
        try:
            sibling_specs = self.root.parent / "azure-rest-api-specs"
            worktree_specs = worktree.parent / "azure-rest-api-specs"
            if sibling_specs.is_dir() and not worktree_specs.exists():
                worktree_specs.symlink_to(sibling_specs, target_is_directory=True)
            result = subprocess.run(
                ["bash", "-euo", "pipefail", "-c", package.regeneration_command],
                cwd=worktree,
                env=self._command_env(work / "regeneration"),
            )
            if result.returncode:
                raise ReleaseError(
                    f"{package.name}: regeneration command failed"
                )
            changes = git(
                worktree,
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                package.source_path,
            )
            if changes:
                raise ReleaseError(
                    f"{package.name}: regeneration is not byte-identical:\n{changes}"
                )
            self._validate_source_workspace(
                package,
                worktree / package.source_path,
                worktree,
            )
        finally:
            self._remove_worktree(worktree, None)

    def _run_source_commands(
        self,
        package: Package,
        source_commit: str,
        work: Path,
    ) -> None:
        worktree = work / "command-worktree"
        empty_hooks = self._empty_hooks_path(work)
        git(
            self.root,
            "-c",
            f"core.hooksPath={empty_hooks}",
            "worktree",
            "add",
            "--quiet",
            "--detach",
            str(worktree),
            source_commit,
        )
        self._active_worktrees.append((worktree, None))
        try:
            self._validate_source_workspace(
                package,
                worktree / package.source_path,
                worktree,
            )
            self._run_package_commands(
                package,
                worktree / package.source_path,
                work / "source-tests",
            )
            changes = git(
                worktree,
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--",
                package.source_path,
            )
            if changes:
                raise ReleaseError(
                    f"{package.name}: package commands modified source files:\n"
                    f"{changes}"
                )
        finally:
            self._remove_worktree(worktree, None)

    def verify(self, name: str, *, run_commands: bool = True) -> None:
        package = self.package(name)
        self._require_main_owned(package)
        _, source_commit, _ = self.source_provenance()
        self._validate_source_workspace(
            package,
            self.package_root(package),
            self.root,
        )
        work = self._clean_work(package)
        try:
            self._verify_regeneration(package, source_commit, work)
            if run_commands:
                self._run_source_commands(package, source_commit, work)
            self._validate_source_workspace(
                package,
                self.package_root(package),
                self.root,
            )
        finally:
            safe_remove(work, self.release_root)
        print(f"verified {package.name} at source commit {source_commit}")

    def _fetch_branch_repo(self, package: Package, work: Path) -> tuple[Path, str] | None:
        work.mkdir(parents=True, exist_ok=True)
        remote_identity = resolve_remote_identity(self.root, self.remote)
        commit = remote_ref(
            remote_identity.fetch_url,
            f"refs/heads/{package.branch}",
            self.root,
        )
        if commit is None:
            return None
        repository = work / "branch-repository"
        git(work, "init", "--quiet", str(repository))
        git(
            repository,
            "fetch",
            "--quiet",
            "--no-tags",
            remote_identity.fetch_url,
            f"refs/heads/{package.branch}",
        )
        fetched = git(repository, "rev-parse", "FETCH_HEAD")
        if fetched != commit:
            raise ReleaseError(f"{package.name}: release branch moved while fetching")
        return repository, commit

    def _show_manifest(self, repository: Path, commit: str) -> zon.Manifest:
        result = run(
            ["git", "show", f"{commit}:build.zig.zon"],
            cwd=repository,
        )
        try:
            return zon.parse(result.stdout.decode())
        except zon.ZonError as error:
            raise ReleaseError(f"published branch has malformed manifest: {error}") from error

    def inspect_branch(self, package: Package, work: Path) -> BranchState:
        fetch_url = resolve_remote_identity(
            self.root,
            self.remote,
        ).fetch_url
        fetched = self._fetch_branch_repo(package, work)
        target_version = zon.parse_semver(package.version)
        tag = f"{package.name}/v{package.version}"
        if remote_tag_commit(fetch_url, tag, self.root) is not None:
            raise ReleaseError(f"{package.name}: release tag already exists: {tag}")
        if fetched is None:
            if target_version != (0, 1, 0):
                raise ReleaseError(
                    f"{package.name}: first canonical release must be 0.1.0"
                )
            return BranchState(None, None, None)

        repository, commit = fetched
        tip_manifest = self._show_manifest(repository, commit)
        try:
            previous_version = zon.parse_semver(tip_manifest.version)
        except zon.ZonError as error:
            raise ReleaseError(
                f"{package.name}: release branch tip has malformed version"
            ) from error

        if tip_manifest.name != package.name:
            raise ReleaseError(
                f"{package.name}: release branch contains unexpected package "
                f"{tip_manifest.name}"
            )
        if target_version <= previous_version:
            raise ReleaseError(
                f"{package.name}: version {package.version} is not greater than "
                f"{tip_manifest.version}"
            )

        for history_commit in git(repository, "rev-list", commit).splitlines():
            manifest = self._show_manifest(repository, history_commit)
            if manifest.name != package.name:
                continue
            try:
                zon.parse_semver(manifest.version)
            except zon.ZonError as error:
                raise ReleaseError(
                    f"{package.name}: malformed version in release history"
                ) from error
            if manifest.version == package.version:
                raise ReleaseError(
                    f"{package.name}: version {package.version} was already used"
                )
            historical_tag = f"{package.name}/v{manifest.version}"
            tagged = remote_tag_commit(fetch_url, historical_tag, self.root)
            if tagged is None:
                raise ReleaseError(
                    f"{package.name}: historical tag is missing: {historical_tag}"
                )
            if tagged != history_commit:
                raise ReleaseError(
                    f"{package.name}: historical tag moved: {historical_tag}"
                )

        return BranchState(
            commit,
            tip_manifest.name,
            tip_manifest.version,
        )

    def _dependency_archive(
        self,
        dependency: Package,
        work: Path,
    ) -> tuple[str, str, str]:
        remote_identity = resolve_remote_identity(self.root, self.remote)
        ref = f"refs/heads/{dependency.branch}"
        commit = remote_ref(remote_identity.fetch_url, ref, self.root)
        if commit is None:
            raise ReleaseError(
                f"{dependency.name}: dependency release branch does not exist"
            )
        repository = work / f"{dependency.name}-repository"
        git(work, "init", "--quiet", str(repository))
        git(
            repository,
            "fetch",
            "--quiet",
            "--no-tags",
            remote_identity.fetch_url,
            ref,
        )
        if git(repository, "rev-parse", "FETCH_HEAD") != commit:
            raise ReleaseError(f"{dependency.name}: dependency branch moved")
        archive = work / f"{dependency.name}-archive"
        extract_archive(repository, commit, archive)
        manifest = validate_tree(archive, dependency, published=True)
        tag = f"{dependency.name}/v{manifest.version}"
        if remote_tag_commit(remote_identity.fetch_url, tag, self.root) != commit:
            raise ReleaseError(
                f"{dependency.name}: dependency tag does not match branch tip"
            )
        result = run(
            [
                "zig",
                "fetch",
                "--global-cache-dir",
                str(work / "zig-global-cache"),
                str(archive),
            ],
            cwd=work,
        )
        package_hash = result.stdout.decode().strip()
        if not package_hash.startswith(f"{dependency.name}-"):
            raise ReleaseError(
                f"{dependency.name}: Zig returned an unexpected package hash"
            )
        zig_base = remote_identity.zig_url
        url = f"{zig_base}#{commit}"
        # Zig intentionally does not support git+file URLs. Local bare remotes
        # are used only by the offline self-test; network-capable remotes get
        # an independent URL fetch/hash comparison.
        if not zig_base.startswith("git+file://"):
            url_result = run(
                [
                    "zig",
                    "fetch",
                    "--global-cache-dir",
                    str(work / "zig-global-cache"),
                    url,
                ],
                cwd=work,
            )
            url_hash = url_result.stdout.decode().strip()
            if url_hash != package_hash:
                raise ReleaseError(
                    f"{dependency.name}: remote URL hash differs from fetched archive"
                )
        return commit, package_hash, url

    def _stage_source(self, package: Package, commit: str, work: Path) -> Path:
        work.mkdir(parents=True, exist_ok=True)
        archive = work / "source-archive"
        extract_archive(self.root, commit, archive, package.source_path)
        package_source = archive / package.source_path
        validate_tree(
            package_source,
            package,
            published=False,
            exact_top_level=False,
        )

        stage = self.stage_dir(package)
        safe_remove(stage, self.release_root)
        stage.mkdir(parents=True)
        for declared in package.publish_paths:
            source = package_source / declared
            if not source.exists() or source.is_symlink():
                raise ReleaseError(
                    f"{package.name}: declared source path missing or symlinked: {declared}"
                )
            destination = stage / declared
            if source.is_dir():
                shutil.copytree(source, destination, copy_function=shutil.copy2)
            else:
                shutil.copy2(source, destination)
        validate_tree(stage, package, published=False)
        return stage

    def _reconstruct_stage(
        self,
        package: Package,
        source_commit: str,
        pins: dict[str, tuple[str, str]],
        work: Path,
    ) -> Path:
        work.mkdir(parents=True, exist_ok=True)
        archive = work / "source-archive"
        extract_archive(
            self.root,
            source_commit,
            archive,
            package.source_path,
        )
        source = archive / package.source_path
        validate_tree(
            source,
            package,
            published=False,
            exact_top_level=False,
        )
        expected = work / "expected-stage"
        expected.mkdir()
        for declared in package.publish_paths:
            source_path = source / declared
            destination = expected / declared
            if source_path.is_dir():
                shutil.copytree(source_path, destination, copy_function=shutil.copy2)
            else:
                shutil.copy2(source_path, destination)
        manifest_path = expected / "build.zig.zon"
        try:
            rewritten = zon.rewrite_internal_dependencies(
                manifest_path.read_text(encoding="utf-8"),
                pins,
            )
        except zon.ZonError as error:
            raise ReleaseError(f"{package.name}: {error}") from error
        manifest_path.write_text(rewritten, encoding="utf-8")
        validate_tree(expected, package, published=True)
        return expected

    def _run_prepared_commands(
        self,
        package: Package,
        stage: Path,
        dependency_records: list[dict[str, str]],
        dependency_work: Path,
        work: Path,
    ) -> None:
        test_root = work / "test-workspace"
        test_package = test_root / "package"
        test_root.mkdir(parents=True)
        copy_tree(stage, test_package, work)

        local_records = [
            record
            for record in dependency_records
            if record["url"].startswith("git+file://")
        ]
        if local_records:
            if len(local_records) != len(dependency_records):
                raise ReleaseError(
                    f"{package.name}: mixed local and network dependency pins"
                )
            local_paths: dict[str, str] = {}
            for record in local_records:
                name = record["name"]
                archive = dependency_work / f"{name}-archive"
                destination = test_root / "dependencies" / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(archive, destination, copy_function=shutil.copy2)
                local_paths[name] = f"../dependencies/{name}"
            manifest_path = test_package / "build.zig.zon"
            try:
                rewritten = zon.rewrite_internal_paths(
                    manifest_path.read_text(encoding="utf-8"),
                    local_paths,
                )
            except zon.ZonError as error:
                raise ReleaseError(f"{package.name}: {error}") from error
            manifest_path.write_text(rewritten, encoding="utf-8")
            validate_tree(test_package, package, published=False)

        self._run_package_commands(package, test_package, work / "stage-tests")

    def prepare(self, name: str, *, run_commands: bool = True) -> dict[str, object]:
        package = self.package(name)
        self._require_main_owned(package)
        source_ref, source_commit, remote_main_commit = self.source_provenance()
        self._validate_source_workspace(
            package,
            self.package_root(package),
            self.root,
        )
        work = self._clean_work(package)
        try:
            self._verify_regeneration(package, source_commit, work)
            branch_state = self.inspect_branch(package, work / "release-state")
            stage = self._stage_source(package, source_commit, work / "source")

            dependency_records: list[dict[str, str]] = []
            pins: dict[str, tuple[str, str]] = {}
            dependency_work = work / "dependencies"
            dependency_work.mkdir(parents=True)
            for dependency_name in package.dependencies:
                dependency = self.package(dependency_name)
                commit, package_hash, url = self._dependency_archive(
                    dependency, dependency_work
                )
                dependency_records.append(
                    {
                        "name": dependency.name,
                        "branch": dependency.branch,
                        "commit": commit,
                        "hash": package_hash,
                        "url": url,
                    }
                )
                pins[dependency.name] = (url, package_hash)

            manifest_path = stage / "build.zig.zon"
            original = manifest_path.read_text(encoding="utf-8")
            try:
                rewritten = zon.rewrite_internal_dependencies(original, pins)
            except zon.ZonError as error:
                raise ReleaseError(f"{package.name}: {error}") from error
            manifest_path.write_text(rewritten, encoding="utf-8")
            staged_manifest = validate_tree(stage, package, published=True)
            for record in dependency_records:
                dependency = staged_manifest.dependencies[record["name"]]
                if (
                    dependency.url != record["url"]
                    or dependency.package_hash != record["hash"]
                ):
                    raise ReleaseError(
                        f"{package.name}: staged dependency pin differs: "
                        f"{record['name']}"
                    )

            if run_commands:
                self._run_prepared_commands(
                    package,
                    stage,
                    dependency_records,
                    dependency_work,
                    work,
                )
            validate_tree(stage, package, published=True)

            files, content_digest = file_inventory(stage)
            remote_identity = resolve_remote_identity(self.root, self.remote)
            seal: dict[str, object] = {
                "schema": 1,
                "source": {
                    "ref": source_ref,
                    "commit": source_commit,
                    "remote_main_commit": remote_main_commit,
                },
                "package": {
                    "name": package.name,
                    "version": package.version,
                    "source_path": package.source_path,
                    "branch": package.branch,
                    "tag": f"{package.name}/v{package.version}",
                },
                "remote": {
                    "name": self.remote,
                    "fetch_url": remote_identity.fetch_url,
                    "push_url": remote_identity.push_url,
                    "repository": remote_identity.repository,
                    "zig_url": remote_identity.zig_url,
                },
                "branch": {
                    "expected_tip": branch_state.commit,
                    "previous_name": branch_state.previous_name,
                    "previous_version": branch_state.previous_version,
                },
                "dependencies": dependency_records,
                "declared_paths": list(package.publish_paths),
                "files": files,
                "content_digest": content_digest,
            }
            manifest_file = self.manifest_path(package)
            manifest_file.parent.mkdir(parents=True, exist_ok=True)
            manifest_file.write_text(
                json.dumps(seal, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
        finally:
            safe_remove(work, self.release_root)

        print(f"prepared {package.name} {package.version}")
        print(f"stage: {self.stage_dir(package)}")
        print(f"manifest: {self.manifest_path(package)}")
        return seal

    def _load_seal(self, package: Package) -> dict[str, object]:
        path = self.manifest_path(package)
        try:
            seal = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ReleaseError(f"{package.name}: missing or malformed stage seal") from error
        if seal.get("schema") != 1:
            raise ReleaseError(f"{package.name}: unsupported stage seal schema")
        return seal

    def _validate_seal(
        self,
        package: Package,
        seal: dict[str, object],
        work: Path,
    ) -> BranchState:
        stage = self.stage_dir(package)
        staged_manifest = validate_tree(stage, package, published=True)
        files, content_digest = file_inventory(stage)
        if files != seal.get("files") or content_digest != seal.get("content_digest"):
            raise ReleaseError(f"{package.name}: staged content was tampered with")
        if seal.get("declared_paths") != list(package.publish_paths):
            raise ReleaseError(f"{package.name}: sealed declared paths differ")

        package_seal = seal.get("package")
        if not isinstance(package_seal, dict) or package_seal != {
            "name": package.name,
            "version": package.version,
            "source_path": package.source_path,
            "branch": package.branch,
            "tag": f"{package.name}/v{package.version}",
        }:
            raise ReleaseError(f"{package.name}: sealed package metadata differs")

        source_ref, source_commit, remote_main_commit = self.source_provenance()
        if seal.get("source") != {
            "ref": source_ref,
            "commit": source_commit,
            "remote_main_commit": remote_main_commit,
        }:
            raise ReleaseError(f"{package.name}: source provenance changed")

        remote_identity = resolve_remote_identity(self.root, self.remote)
        remote_seal = seal.get("remote")
        expected_remote = {
            "name": self.remote,
            "fetch_url": remote_identity.fetch_url,
            "push_url": remote_identity.push_url,
            "repository": remote_identity.repository,
            "zig_url": remote_identity.zig_url,
        }
        if not isinstance(remote_seal, dict) or remote_seal != expected_remote:
            raise ReleaseError(
                f"{package.name}: publication remote identity differs from prepare"
            )

        branch_state = self.inspect_branch(package, work / "release-state")
        branch_seal = seal.get("branch")
        if (
            not isinstance(branch_seal, dict)
            or branch_state.commit != branch_seal.get("expected_tip")
            or branch_state.previous_name != branch_seal.get("previous_name")
            or branch_state.previous_version != branch_seal.get("previous_version")
        ):
            raise ReleaseError(f"{package.name}: release branch moved after prepare")

        dependency_seal = seal.get("dependencies")
        if not isinstance(dependency_seal, list):
            raise ReleaseError(f"{package.name}: malformed dependency seal")
        if [item.get("name") for item in dependency_seal if isinstance(item, dict)] != list(
            package.dependencies
        ):
            raise ReleaseError(f"{package.name}: sealed dependencies differ")
        dependency_work = work / "dependencies"
        dependency_work.mkdir(parents=True)
        pins: dict[str, tuple[str, str]] = {}
        for item in dependency_seal:
            if not isinstance(item, dict):
                raise ReleaseError(f"{package.name}: malformed dependency record")
            dependency = self.package(str(item["name"]))
            commit, package_hash, url = self._dependency_archive(
                dependency, dependency_work
            )
            expected = {
                "name": dependency.name,
                "branch": dependency.branch,
                "commit": commit,
                "hash": package_hash,
                "url": url,
            }
            if item != expected:
                raise ReleaseError(
                    f"{package.name}: dependency branch or hash changed: "
                    f"{dependency.name}"
                )
            staged = staged_manifest.dependencies[dependency.name]
            if staged.url != url or staged.package_hash != package_hash:
                raise ReleaseError(
                    f"{package.name}: staged dependency pin is wrong: "
                    f"{dependency.name}"
                )
            pins[dependency.name] = (url, package_hash)

        expected_stage = self._reconstruct_stage(
            package,
            source_commit,
            pins,
            work / "reconstructed",
        )
        expected_files, expected_digest = file_inventory(expected_stage)
        if files != expected_files or content_digest != expected_digest:
            raise ReleaseError(
                f"{package.name}: stage differs from its recorded source commit"
            )
        return branch_state

    def _verify_index(self, worktree: Path, stage: Path) -> None:
        expected_files, _ = file_inventory(stage)
        expected = {str(item["path"]): item for item in expected_files}
        raw = run(["git", "ls-files", "-s", "-z"], cwd=worktree).stdout
        actual: dict[str, tuple[str, str]] = {}
        for row in raw.split(b"\0"):
            if not row:
                continue
            metadata, path = row.decode().split("\t", 1)
            mode, object_id, stage_number = metadata.split()
            if stage_number != "0":
                raise ReleaseError(f"unmerged publication index entry: {path}")
            actual[path] = (mode, object_id)
        if set(actual) != set(expected):
            raise ReleaseError("publication index file list differs from sealed stage")
        for path, item in expected.items():
            data = run(["git", "show", f":{path}"], cwd=worktree).stdout
            source = (stage / path).read_bytes()
            if data != source:
                raise ReleaseError(f"publication index bytes differ: {path}")
            expected_mode = "100755" if item["executable"] else "100644"
            if actual[path][0] != expected_mode:
                raise ReleaseError(f"publication index mode differs: {path}")

    def _verify_commit_tree(
        self,
        worktree: Path,
        commit: str,
        stage: Path,
    ) -> None:
        expected_files, _ = file_inventory(stage)
        expected = {str(item["path"]): item for item in expected_files}
        raw = run(
            ["git", "ls-tree", "-r", "-z", commit],
            cwd=worktree,
        ).stdout
        actual: dict[str, tuple[str, str]] = {}
        for row in raw.split(b"\0"):
            if not row:
                continue
            metadata, path = row.decode().split("\t", 1)
            mode, object_type, object_id = metadata.split()
            if object_type != "blob":
                raise ReleaseError(f"non-blob publication tree entry: {path}")
            actual[path] = (mode, object_id)
        if set(actual) != set(expected):
            raise ReleaseError(
                "publication commit file list differs from sealed stage"
            )
        for path, item in expected.items():
            data = run(
                ["git", "show", f"{commit}:{path}"],
                cwd=worktree,
            ).stdout
            if data != (stage / path).read_bytes():
                raise ReleaseError(f"publication commit bytes differ: {path}")
            expected_mode = "100755" if item["executable"] else "100644"
            if actual[path][0] != expected_mode:
                raise ReleaseError(f"publication commit mode differs: {path}")

    def _atomic_push(
        self,
        worktree: Path,
        package: Package,
        tag: str,
        expected_branch_commit: str | None,
        push_url: str,
        hooks_path: Path,
    ) -> None:
        expected = expected_branch_commit or ""
        git(
            worktree,
            "-c",
            f"core.hooksPath={hooks_path}",
            "push",
            "--quiet",
            "--atomic",
            "--no-verify",
            f"--force-with-lease=refs/heads/{package.branch}:{expected}",
            push_url,
            f"HEAD:refs/heads/{package.branch}",
            f"HEAD:refs/tags/{tag}",
        )

    def _remove_worktree(self, worktree: Path, branch: str | None) -> None:
        if worktree.exists():
            git(
                self.root,
                "worktree",
                "remove",
                "--force",
                str(worktree),
                check=False,
            )
        if worktree.exists():
            safe_remove(worktree, self.release_root)
        git(
            self.root,
            "worktree",
            "prune",
            "--expire",
            "now",
            check=False,
        )
        if branch:
            git(self.root, "branch", "-D", branch, check=False)
        self._active_worktrees = [
            item for item in self._active_worktrees if item[0] != worktree
        ]

    def publish(self, name: str, *, dry_run: bool) -> str:
        package = self.package(name)
        self._require_main_owned(package)
        seal = self._load_seal(package)
        work = self._clean_work(package)
        worktree = work / "publication-worktree"
        temp_branch: str | None = None
        try:
            branch_state = self._validate_seal(package, seal, work)
            empty_hooks = self._empty_hooks_path(work)
            git(
                self.root,
                "-c",
                f"core.hooksPath={empty_hooks}",
                "worktree",
                "add",
                "--quiet",
                "--detach",
                "--no-checkout",
                str(worktree),
                "HEAD",
            )
            if branch_state.commit is None:
                temp_branch = f"package-release-{os.getpid()}-{int(time.time())}"
                git(
                    worktree,
                    "-c",
                    f"core.hooksPath={empty_hooks}",
                    "switch",
                    "--quiet",
                    "--orphan",
                    temp_branch,
                )
                if git(
                    worktree,
                    "status",
                    "--porcelain=v1",
                    "--untracked-files=all",
                ):
                    raise ReleaseError("initial orphan publication worktree is not empty")
            else:
                fetch_url = seal["remote"]["fetch_url"]
                git(
                    self.root,
                    "fetch",
                    "--quiet",
                    "--no-tags",
                    fetch_url,
                    f"refs/heads/{package.branch}",
                )
                fetched = git(self.root, "rev-parse", "FETCH_HEAD")
                if fetched != branch_state.commit:
                    raise ReleaseError("release branch moved during publication setup")
                git(
                    worktree,
                    "-c",
                    f"core.hooksPath={empty_hooks}",
                    "switch",
                    "--quiet",
                    "--detach",
                    fetched,
                )
                git(worktree, "rm", "-r", "--quiet", "--ignore-unmatch", "--", ".")
                git(worktree, "clean", "-fdx", "--", ".")
            self._active_worktrees.append((worktree, temp_branch))

            stage = self.stage_dir(package)
            for source in stage.iterdir():
                destination = worktree / source.name
                if source.is_dir():
                    shutil.copytree(source, destination, copy_function=shutil.copy2)
                else:
                    shutil.copy2(source, destination)
            git(worktree, "add", "--all", "--", ".")
            self._verify_index(worktree, stage)
            message = (
                f"{package.name}: release {package.version}\n\n"
                f"Source-Commit: {seal['source']['commit']}"
            )
            git(
                worktree,
                "-c",
                f"core.hooksPath={empty_hooks}",
                "commit",
                "--quiet",
                "--no-verify",
                "-m",
                message,
            )
            release_commit = git(worktree, "rev-parse", "HEAD")
            self._verify_commit_tree(worktree, release_commit, stage)
            parents = git(worktree, "rev-list", "--parents", "-n", "1", "HEAD").split()
            if branch_state.commit is None:
                if len(parents) != 1:
                    raise ReleaseError("initial release commit has a parent")
            elif len(parents) != 2 or parents[1] != branch_state.commit:
                raise ReleaseError("release commit is not a direct branch descendant")

            archive = work / "prospective-package"
            extract_archive(worktree, release_commit, archive)
            validate_tree(archive, package, published=True)
            result = run(
                [
                    "zig",
                    "fetch",
                    "--global-cache-dir",
                    str(work / "prospective-cache"),
                    str(archive),
                ],
                cwd=work,
            )
            release_hash = result.stdout.decode().strip()
            if not release_hash.startswith(f"{package.name}-"):
                raise ReleaseError(
                    f"{package.name}: Zig returned an unexpected release hash"
                )
            tag = f"{package.name}/v{package.version}"
            print(f"package: {package.name} {package.version}")
            print(f"branch: {package.branch}")
            print(f"parent: {branch_state.commit or '<orphan>'}")
            for dependency in seal["dependencies"]:
                print(
                    f"dependency: {dependency['name']} "
                    f"{dependency['commit']} {dependency['hash']}"
                )
            print(f"commit: {release_commit}")
            print(f"hash: {release_hash}")
            print(f"tag: {tag}")

            if not dry_run:
                # Revalidate immediately before the exact package-branch lease
                # and atomic branch/tag push.
                self._validate_seal(package, seal, work / "pre-push")
                self._atomic_push(
                    worktree,
                    package,
                    tag,
                    branch_state.commit,
                    seal["remote"]["push_url"],
                    empty_hooks,
                )
                push_url = seal["remote"]["push_url"]
                branch_remote = remote_ref(
                    push_url,
                    f"refs/heads/{package.branch}",
                    self.root,
                )
                tag_remote = remote_tag_commit(push_url, tag, self.root)
                if branch_remote != release_commit or tag_remote != release_commit:
                    raise ReleaseError("atomic publication verification failed")
                print(f"published {package.branch} and {tag} atomically")
            else:
                print("dry-run: remote refs were not changed")
            return release_commit
        finally:
            self._remove_worktree(worktree, temp_branch)
            safe_remove(work, self.release_root)

    def cleanup(self) -> None:
        for worktree, branch in reversed(self._active_worktrees):
            self._remove_worktree(worktree, branch)


def find_root() -> Path:
    root = git(Path.cwd(), "rev-parse", "--show-toplevel")
    return Path(root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="scripts/package-release.sh",
        description="Prepare and publish registry-defined Zig packages.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("verify", "prepare"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("package")
    publish = subparsers.add_parser("publish")
    publish.add_argument("package")
    publish.add_argument("--dry-run", action="store_true")
    publish.add_argument("--remote", default="origin")
    subparsers.add_parser("self-test")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    def terminate(_signum: int, _frame: object) -> None:
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGHUP, terminate)
    args = parse_args(argv)
    root = find_root()
    if args.command == "self-test":
        from self_test import run_self_test

        run_self_test(root)
        return 0
    remote = args.remote if args.command == "publish" else os.environ.get(
        "PACKAGE_RELEASE_REMOTE", "origin"
    )
    release_root = Path(
        os.environ.get(
            "PACKAGE_RELEASE_ROOT",
            str(root / ".release" / "packages"),
        )
    )
    engine = Engine(root, remote=remote, release_root=release_root)
    try:
        if args.command == "verify":
            engine.verify(args.package)
        elif args.command == "prepare":
            engine.prepare(args.package)
        elif args.command == "publish":
            engine.publish(args.package, dry_run=args.dry_run)
        else:
            raise AssertionError(args.command)
    finally:
        engine.cleanup()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (RegistryError, ReleaseError, zon.ZonError) as error:
        print(f"package-release: {error}", file=sys.stderr)
        raise SystemExit(1)
