#!/usr/bin/env python3
"""Offline regression coverage for the package release engine."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess

from release import (
    Engine,
    ReleaseError,
    file_inventory,
    git,
    remote_ref,
    remote_tag_commit,
)


TRACING = "azure_sdk_core_tracing"
CORE = "azure_sdk_core"
ARM = "azure_rest_arm_avs"


class PackageBranchRaceEngine(Engine):
    def _atomic_push(
        self,
        worktree: Path,
        package,
        tag: str,
        expected_branch_commit: str | None,
        push_url: str,
        hooks_path: Path,
    ) -> None:
        if expected_branch_commit is None:
            raise ReleaseError(
                "self-test package branch race requires an existing branch"
            )
        git(
            self.root,
            "push",
            "--quiet",
            "--delete",
            push_url,
            f"refs/heads/{package.branch}",
        )
        super()._atomic_push(
            worktree,
            package,
            tag,
            expected_branch_commit,
            push_url,
            hooks_path,
        )


def write_registry(
    root: Path,
    *,
    tracing_version: str = "0.1.0",
    core_version: str = "0.1.0",
) -> None:
    (root / ".gitignore").write_text(".release/\n", encoding="utf-8")
    path = root / "eng" / "packages.zig"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""
const Package = struct {{}};
pub const all = [_]Package{{
    .{{
        .source_path = "sdk/core/tracing",
        .name = "{TRACING}",
        .branch = "sdk/core_tracing",
        .version = "{tracing_version}",
        .publish_paths = &.{{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        }},
        .test_command = "zig build test --summary all",
    }},
    .{{
        .source_path = "sdk/core",
        .name = "{CORE}",
        .branch = "sdk/core",
        .version = "{core_version}",
        .dependencies = &.{{"{TRACING}"}},
        .publish_paths = &.{{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        }},
        .test_command = "zig build test --summary all",
    }},
    .{{
        .source_path = "rest/arm_avs",
        .name = "{ARM}",
        .branch = "rest/arm_avs",
        .version = "0.1.0",
        .legacy_names = &.{{"arm_avs"}},
        .publish_paths = &.{{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        }},
        .test_command = "zig build test --summary all",
    }},
}};
""".lstrip(),
        encoding="utf-8",
    )


def write_package(
    root: Path,
    source_path: str,
    name: str,
    version: str,
    dependencies: tuple[tuple[str, str], ...] = (),
) -> None:
    fingerprints = {
        TRACING: "0xe8429db77ded14e7",
        CORE: "0x0fdf522a4b433c07",
        ARM: "0xa125d6afd751e975",
        "arm_avs": "0xfdf7c70ce6c5b4b4",
    }
    package = root / source_path
    package.mkdir(parents=True, exist_ok=True)
    (package / ".gitignore").write_text(
        ".zig-cache/\nzig-out/\nzig-pkg/\n", encoding="utf-8"
    )
    (package / "LICENSE.txt").write_text("fixture license\n", encoding="utf-8")
    (package / "README.md").write_text(
        f"# {name} {version}\n", encoding="utf-8"
    )
    imports = "".join(
        f'const {dependency} = @import("{dependency}");\n'
        for dependency, _ in dependencies
    )
    test_body = "\n".join(
        f"    try std.testing.expect({dependency}.release_fixture);"
        for dependency, _ in dependencies
    )
    if not test_body:
        test_body = "    try std.testing.expect(release_fixture);"
    (package / "root.zig").write_text(
        f"""const std = @import("std");
{imports}
pub const release_fixture = true;

test "release fixture" {{
    var env = try std.process.Environ.createMap(
        std.testing.environ,
        std.testing.allocator,
    );
    defer env.deinit();
    try std.testing.expect(
        env.get("AZURE_RELEASE_SELF_TEST_SENTINEL") == null,
    );
{test_body}
}}
""",
        encoding="utf-8",
    )
    dependency_build = ""
    for dependency, _ in dependencies:
        dependency_build += f"""
    const {dependency}_dependency = b.dependency("{dependency}", .{{
        .target = target,
        .optimize = optimize,
    }});
    test_module.addImport(
        "{dependency}",
        {dependency}_dependency.module("{dependency}"),
    );
"""
    (package / "build.zig").write_text(
        f"""
const std = @import("std");
pub fn build(b: *std.Build) void {{
    const target = b.standardTargetOptions(.{{}});
    const optimize = b.standardOptimizeOption(.{{}});
    _ = b.addModule("{name}", .{{
        .root_source_file = b.path("root.zig"),
    }});
    const test_module = b.createModule(.{{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    }});
{dependency_build}
    const tests = b.addTest(.{{ .root_module = test_module }});
    const test_step = b.step("test", "fixture test");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}}
""".lstrip(),
        encoding="utf-8",
    )
    dependency_text = ""
    for dependency, relative_path in dependencies:
        dependency_text += (
            f"        .{dependency} = .{{\n"
            f'            .path = "{relative_path}",\n'
            "        },\n"
        )
    (package / "build.zig.zon").write_text(
        f"""
.{{
    .name = .{name},
    .version = "{version}",
    .fingerprint = {fingerprints[name]},
    .minimum_zig_version = "0.16.0",
    .dependencies = .{{
{dependency_text}    }},
    .paths = .{{
        ".gitignore",
        "build.zig",
        "build.zig.zon",
        "root.zig",
        "README.md",
        "LICENSE.txt",
    }},
}}
""".lstrip(),
        encoding="utf-8",
    )


def commit_all(root: Path, message: str) -> str:
    git(root, "add", "--all")
    git(root, "commit", "--quiet", "-m", message)
    return git(root, "rev-parse", "HEAD")


def push_main(source: Path, remote: str) -> None:
    git(
        source,
        "push",
        "--quiet",
        remote,
        "main:refs/heads/main",
    )


def expect_failure(
    label: str,
    action,
    expected_message: str | None = None,
) -> None:
    try:
        action()
    except ReleaseError as error:
        if expected_message and expected_message not in str(error):
            raise ReleaseError(
                f"self-test {label} returned unexpected error: {error}"
            ) from error
        return
    raise ReleaseError(f"self-test expected failure was accepted: {label}")


def assert_cleanup(engine: Engine) -> None:
    worktrees = git(engine.root, "worktree", "list", "--porcelain")
    if "/work/" in worktrees or "publication-worktree" in worktrees:
        raise ReleaseError("self-test: disposable worktree was not removed")
    if git(engine.root, "branch", "--list", "package-release-*"):
        raise ReleaseError("self-test: temporary publication branch was not removed")
    for work in engine.release_root.glob("*/work"):
        if work.exists():
            raise ReleaseError(f"self-test: work directory was not removed: {work}")


def assert_no_source_artifacts(source: Path) -> None:
    forbidden = {".zig-cache", "zig-cache", "zig-out", "zig-pkg"}
    artifacts = sorted(
        path.relative_to(source).as_posix()
        for path in source.rglob("*")
        if path.name in forbidden
    )
    if artifacts:
        raise ReleaseError(
            f"self-test: package commands mutated source checkout: {artifacts}"
        )


def update_versions(
    source: Path,
    *,
    tracing_version: str,
    core_version: str,
) -> None:
    write_registry(
        source,
        tracing_version=tracing_version,
        core_version=core_version,
    )
    write_package(
        source,
        "sdk/core/tracing",
        TRACING,
        tracing_version,
    )
    write_package(
        source,
        "sdk/core",
        CORE,
        core_version,
        ((TRACING, "tracing"),),
    )
    write_package(source, "rest/arm_avs", ARM, "0.1.0")


def push_legacy_branch(source: Path, remote: Path, scratch: Path) -> str:
    legacy = scratch / "legacy"
    legacy.mkdir(parents=True)
    git(legacy, "init", "--quiet")
    git(legacy, "config", "user.name", "Release self-test")
    git(legacy, "config", "user.email", "release-self-test@example.invalid")
    write_package(legacy, ".", "arm_avs", "9.4.0")
    commit = commit_all(legacy, "legacy package")
    git(legacy, "push", "--quiet", str(remote), f"{commit}:refs/heads/rest/arm_avs")
    return commit


def run_self_test(repository_root: Path) -> None:
    test_root = repository_root / ".release" / "package-release-self-test"
    if test_root.exists():
        shutil.rmtree(test_root)
    test_root.mkdir(parents=True)
    source = test_root / "source"
    remote = test_root / "remote.git"
    other_remote = test_root / "other-remote.git"
    publication_remote = "publication"
    release_root = source / ".release" / "packages"
    source.mkdir()
    git(source, "init", "--quiet")
    git(source, "config", "user.name", "Release self-test")
    git(source, "config", "user.email", "release-self-test@example.invalid")
    git(source, "branch", "-M", "main")
    git(test_root, "init", "--quiet", "--bare", str(remote))
    git(test_root, "init", "--quiet", "--bare", str(other_remote))
    git(source, "remote", "add", publication_remote, str(remote))

    sentinel = "AZURE_RELEASE_SELF_TEST_SENTINEL"
    previous_sentinel = os.environ.get(sentinel)
    os.environ[sentinel] = "must-not-reach-package-commands"
    try:
        update_versions(source, tracing_version="0.1.0", core_version="0.1.0")
        initial_source = commit_all(source, "initial source")
        push_main(source, publication_remote)

        (source / "local-only.txt").write_text("unpushed\n", encoding="utf-8")
        commit_all(source, "unpushed local main")
        remote_main = subprocess.run(
            [
                "git",
                "commit-tree",
                git(source, "rev-parse", f"{initial_source}^{{tree}}"),
                "-p",
                initial_source,
            ],
            cwd=source,
            input=b"remote main divergence\n",
            stdout=subprocess.PIPE,
            check=True,
        ).stdout.decode().strip()
        git(
            source,
            "push",
            "--quiet",
            publication_remote,
            f"{remote_main}:refs/heads/main",
        )

        engine = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure(
            "unpushed/diverged local main",
            lambda: engine.verify(TRACING),
            "source HEAD does not match publication remote refs/heads/main",
        )
        git(source, "reset", "--quiet", "--hard", remote_main)

        git(
            source,
            "remote",
            "set-url",
            "--push",
            publication_remote,
            str(other_remote),
        )
        expect_failure(
            "mismatched remote push repository",
            lambda: engine.verify(TRACING),
            "publication remote fetch/push repository mismatch",
        )
        git(
            source,
            "remote",
            "set-url",
            "--push",
            publication_remote,
            str(remote),
        )

        git(
            source,
            "remote",
            "set-url",
            "--add",
            "--push",
            publication_remote,
            str(other_remote),
        )
        expect_failure(
            "multiple remote push URLs",
            lambda: engine.prepare(TRACING),
            "publication remote must have exactly one push URL; found 2",
        )
        if remote_ref(str(remote), "refs/heads/sdk/core_tracing", source) is not None:
            raise ReleaseError("self-test: multiple push URLs published a branch")
        if remote_tag_commit(str(remote), f"{TRACING}/v0.1.0", source) is not None:
            raise ReleaseError("self-test: multiple push URLs published a tag")
        git(
            source,
            "config",
            "--unset-all",
            f"remote.{publication_remote}.pushurl",
        )
        git(
            source,
            "config",
            "--add",
            f"remote.{publication_remote}.pushurl",
            str(remote),
        )

        credential_url = "ssh://release-user:release-password@example.invalid/repo.git"
        git(
            source,
            "remote",
            "set-url",
            publication_remote,
            credential_url,
        )
        git(
            source,
            "remote",
            "set-url",
            "--push",
            publication_remote,
            credential_url,
        )
        expect_failure(
            "password-bearing SSH remote",
            lambda: engine.verify(TRACING),
            "remote URL must not contain an embedded password",
        )
        git(
            source,
            "remote",
            "set-url",
            publication_remote,
            str(remote),
        )
        git(
            source,
            "remote",
            "set-url",
            "--push",
            publication_remote,
            str(remote),
        )

        git(
            source,
            "config",
            "--add",
            "url.rewrite-one:.insteadOf",
            "release-alias:",
        )
        git(
            source,
            "config",
            "--add",
            "url.https://rewrite-two.invalid/.insteadOf",
            "rewrite-one:",
        )
        git(
            source,
            "remote",
            "set-url",
            publication_remote,
            "release-alias:repository",
        )
        expect_failure(
            "chained Git URL rewrites",
            lambda: engine.prepare(TRACING),
            "effective Git URL rewrite configuration is not allowed",
        )
        if remote_ref(str(remote), "refs/heads/sdk/core_tracing", source) is not None:
            raise ReleaseError("self-test: URL rewrites published a branch")
        git(
            source,
            "remote",
            "set-url",
            publication_remote,
            str(remote),
        )
        git(source, "config", "--unset-all", "url.rewrite-one:.insteadOf")
        git(
            source,
            "config",
            "--unset-all",
            "url.https://rewrite-two.invalid/.insteadOf",
        )

        git(source, "switch", "--quiet", "-c", "feature-release")
        expect_failure(
            "feature branch source provenance",
            lambda: engine.verify(TRACING),
            "source branch must be main; found feature-release",
        )
        git(source, "switch", "--quiet", "main")

        hook_marker = source / ".git" / "release-hook-ran"
        pre_commit = source / ".git" / "hooks" / "pre-commit"
        post_commit = source / ".git" / "hooks" / "post-commit"
        post_checkout = source / ".git" / "hooks" / "post-checkout"
        pre_push = source / ".git" / "hooks" / "pre-push"
        pre_commit.write_text(
            f"""#!/bin/sh
set -eu
printf 'release hook ran\n' > "{hook_marker}"
if [ -f README.md ]; then
    printf 'hook tampering\n' >> README.md
    git add README.md
fi
""",
            encoding="utf-8",
        )
        pre_commit.chmod(0o755)
        post_commit.write_text(
            f"""#!/bin/sh
set -eu
printf 'release post-commit hook ran\n' > "{hook_marker}"
""",
            encoding="utf-8",
        )
        post_commit.chmod(0o755)
        post_checkout.write_text(
            f"""#!/bin/sh
set -eu
printf 'release post-checkout hook ran\n' > "{hook_marker}"
if [ -f README.md ]; then
    printf 'checkout hook tampering\n' >> README.md
    git add README.md
fi
""",
            encoding="utf-8",
        )
        post_checkout.chmod(0o755)
        pre_push.write_text(
            f"""#!/bin/sh
set -eu
printf 'release pre-push hook ran\n' > "{hook_marker}"
main="$(git --git-dir="{remote}" rev-parse refs/heads/main)"
git --git-dir="{remote}" update-ref refs/heads/hook-side-effect "$main"
""",
            encoding="utf-8",
        )
        pre_push.chmod(0o755)

        engine.verify(TRACING)
        engine.verify(CORE)
        assert_cleanup(engine)
        assert_no_source_artifacts(source)
        if hook_marker.exists():
            raise ReleaseError("self-test: verification executed Git hooks")

        engine.prepare(TRACING)
        tracing_v1 = engine.publish(TRACING, dry_run=False)
        if remote_ref(str(remote), "refs/heads/sdk/core_tracing", source) != tracing_v1:
            raise ReleaseError("self-test: initial branch publication failed")
        if remote_tag_commit(str(remote), f"{TRACING}/v0.1.0", source) != tracing_v1:
            raise ReleaseError("self-test: initial tag publication failed")
        if len(git(source, "rev-list", "--parents", "-n", "1", tracing_v1).split()) != 1:
            raise ReleaseError("self-test: initial release was not orphaned")

        engine.prepare(CORE)
        seal = json.loads(engine.manifest_path(engine.package(CORE)).read_text())
        if seal["source"]["remote_main_commit"] != git(source, "rev-parse", "HEAD"):
            raise ReleaseError("self-test: remote main provenance was not sealed")
        dependency = seal["dependencies"][0]
        if dependency["commit"] != tracing_v1 or not dependency["hash"].startswith(
            f"{TRACING}-"
        ):
            raise ReleaseError("self-test: dependency commit/hash resolution failed")
        core_v1 = engine.publish(CORE, dry_run=False)
        if hook_marker.exists():
            raise ReleaseError("self-test: release publication executed Git hooks")
        if remote_ref(str(remote), "refs/heads/hook-side-effect", source) is not None:
            raise ReleaseError("self-test: pre-push hook changed the remote")
        pre_commit.unlink()
        post_commit.unlink()
        post_checkout.unlink()
        pre_push.unlink()

        tracing_manifest = source / "sdk/core/tracing/build.zig.zon"
        valid_tracing_manifest = tracing_manifest.read_text(encoding="utf-8")
        tracing_manifest.write_text(
            "\n".join(
                line
                for line in valid_tracing_manifest.splitlines()
                if not line.strip().startswith(".fingerprint =")
            )
            + "\n",
            encoding="utf-8",
        )
        commit_all(source, "missing package fingerprint")
        push_main(source, publication_remote)
        missing_fingerprint = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure(
            "missing package fingerprint",
            lambda: missing_fingerprint.prepare(TRACING),
            "missing or malformed .fingerprint",
        )
        assert_cleanup(missing_fingerprint)

        tracing_manifest.write_text(
            valid_tracing_manifest.replace(
                '.minimum_zig_version = "0.16.0",',
                '.minimum_zig_version = "",',
            ),
            encoding="utf-8",
        )
        commit_all(source, "empty minimum Zig version")
        push_main(source, publication_remote)
        empty_minimum_zig = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure(
            "empty minimum Zig version",
            lambda: empty_minimum_zig.prepare(TRACING),
            ".minimum_zig_version must not be empty",
        )
        assert_cleanup(empty_minimum_zig)

        update_versions(source, tracing_version="0.1.0", core_version="0.1.0")
        tracing_manifest.write_text(
            tracing_manifest.read_text(encoding="utf-8").replace(
                '        "README.md",',
                '        // "README.md",',
            ),
            encoding="utf-8",
        )
        commit_all(source, "commented-out required package path")
        push_main(source, publication_remote)
        commented_path = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure(
            "commented-out required package path",
            lambda: commented_path.verify(TRACING),
            ".paths must exactly match registry publish_paths",
        )
        assert_cleanup(commented_path)

        update_versions(source, tracing_version="0.1.0", core_version="0.1.0")
        core_manifest = source / "sdk/core/build.zig.zon"
        core_manifest.write_text(
            core_manifest.read_text(encoding="utf-8").replace(
                '.path = "tracing",',
                '.path = "../../rest/arm_avs",',
            ),
            encoding="utf-8",
        )
        commit_all(source, "wrong internal dependency path")
        push_main(source, publication_remote)
        wrong_dependency_path = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure(
            "wrong internal dependency path",
            lambda: wrong_dependency_path.verify(CORE),
            f"dependency {TRACING} path resolves to",
        )
        assert_cleanup(wrong_dependency_path)

        update_versions(source, tracing_version="0.2.0", core_version="0.1.0")
        commit_all(source, "tracing 0.2.0 source")
        push_main(source, publication_remote)
        engine = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        engine.prepare(TRACING)
        dry_run_commit = engine.publish(TRACING, dry_run=True)
        if remote_ref(str(remote), "refs/heads/sdk/core_tracing", source) != tracing_v1:
            raise ReleaseError("self-test: dry-run changed the remote branch")
        tracing_v2 = engine.publish(TRACING, dry_run=False)
        if git(source, "rev-parse", f"{tracing_v2}^") != tracing_v1:
            raise ReleaseError("self-test: second release is not a direct descendant")
        if dry_run_commit == tracing_v1:
            raise ReleaseError("self-test: dry-run did not create a prospective commit")

        update_versions(source, tracing_version="1.0", core_version="0.1.0")
        commit_all(source, "malformed version")
        push_main(source, publication_remote)
        malformed = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure("malformed version", lambda: malformed.prepare(TRACING))
        assert_cleanup(malformed)

        update_versions(source, tracing_version="0.1.5", core_version="0.1.0")
        commit_all(source, "non-monotonic version")
        push_main(source, publication_remote)
        non_monotonic = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure("non-monotonic version", lambda: non_monotonic.prepare(TRACING))
        assert_cleanup(non_monotonic)

        update_versions(source, tracing_version="0.2.0", core_version="0.1.0")
        commit_all(source, "reused version")
        push_main(source, publication_remote)
        reused = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure("reused version", lambda: reused.prepare(TRACING))
        assert_cleanup(reused)

        update_versions(source, tracing_version="0.2.0", core_version="0.2.0")
        commit_all(source, "core 0.2.0 source")
        push_main(source, publication_remote)
        engine = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        engine.prepare(CORE)
        core_package = engine.package(CORE)
        current_seal = json.loads(engine.manifest_path(core_package).read_text())
        correct_hash = current_seal["dependencies"][0]["hash"]
        staged_zon = engine.stage_dir(core_package) / "build.zig.zon"
        staged_zon.write_text(
            staged_zon.read_text().replace(
                correct_hash,
                f"{TRACING}-0.0.0-wrong",
            ).replace(current_seal["dependencies"][0]["commit"], core_v1)
        )
        files, digest = file_inventory(engine.stage_dir(core_package))
        current_seal["files"] = files
        current_seal["content_digest"] = digest
        engine.manifest_path(core_package).write_text(
            json.dumps(current_seal, indent=2, sort_keys=True) + "\n"
        )
        expect_failure(
            "wrong dependency commit/hash",
            lambda: engine.publish(CORE, dry_run=True),
        )
        assert_cleanup(engine)

        engine.prepare(CORE)
        (engine.stage_dir(core_package) / "README.md").write_text("tampered\n")
        expect_failure("tampered stage", lambda: engine.publish(CORE, dry_run=True))
        assert_cleanup(engine)

        engine.prepare(CORE)
        old_core_tip = remote_ref(str(remote), "refs/heads/sdk/core", source)
        moved_tree = git(source, "rev-parse", f"{old_core_tip}^{{tree}}")
        moved_commit = subprocess.run(
            ["git", "commit-tree", moved_tree, "-p", old_core_tip],
            cwd=source,
            input=b"concurrent release\n",
            stdout=subprocess.PIPE,
            check=True,
        ).stdout.decode().strip()
        git(
            source,
            "push",
            "--quiet",
            str(remote),
            f"{moved_commit}:refs/heads/sdk/core",
        )
        expect_failure("branch movement", lambda: engine.publish(CORE, dry_run=True))
        assert_cleanup(engine)
        git(
            source,
            "push",
            "--quiet",
            "--force",
            str(remote),
            f"{old_core_tip}:refs/heads/sdk/core",
        )

        tracing_tag = f"refs/tags/{TRACING}/v0.2.0"
        git(source, "push", "--quiet", "--delete", str(remote), tracing_tag)
        git(
            source,
            "push",
            "--quiet",
            str(remote),
            f"{core_v1}:{tracing_tag}",
        )
        moved_tag = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        expect_failure("moved tag", lambda: moved_tag.prepare(CORE))
        assert_cleanup(moved_tag)
        git(source, "push", "--quiet", "--delete", str(remote), tracing_tag)
        git(
            source,
            "push",
            "--quiet",
            str(remote),
            f"{tracing_v2}:{tracing_tag}",
        )

        package_race = PackageBranchRaceEngine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        package_race.prepare(CORE)
        branch_before = remote_ref(str(remote), "refs/heads/sdk/core", source)
        if branch_before is None:
            raise ReleaseError("self-test: package branch is missing before race")
        target_tag = f"{CORE}/v0.2.0"
        expect_failure(
            "package branch deletion before atomic push",
            lambda: package_race.publish(CORE, dry_run=False),
        )
        if remote_ref(str(remote), "refs/heads/sdk/core", source) is not None:
            raise ReleaseError("self-test: package branch race was not injected")
        if remote_tag_commit(str(remote), target_tag, source) is not None:
            raise ReleaseError("self-test: package branch race created the tag")
        assert_cleanup(package_race)
        git(
            source,
            "push",
            "--quiet",
            publication_remote,
            f"{branch_before}:refs/heads/sdk/core",
        )

        engine = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        engine.prepare(CORE)
        colliding_tag = f"refs/tags/{CORE}/v0.2.0"
        git(
            source,
            "push",
            "--quiet",
            str(remote),
            f"{tracing_v2}:{colliding_tag}",
        )
        branch_before = remote_ref(str(remote), "refs/heads/sdk/core", source)
        expect_failure("tag collision", lambda: engine.publish(CORE, dry_run=False))
        if remote_ref(str(remote), "refs/heads/sdk/core", source) != branch_before:
            raise ReleaseError("self-test: failed atomic push changed the branch")
        assert_cleanup(engine)
        git(source, "push", "--quiet", "--delete", str(remote), colliding_tag)

        push_legacy_branch(source, remote, test_root)
        legacy_engine = Engine(
            source,
            remote=publication_remote,
            release_root=release_root,
        )
        legacy_engine.prepare(ARM)
        legacy_commit = legacy_engine.publish(ARM, dry_run=False)
        if git(source, "rev-parse", f"{legacy_commit}^") == "":
            raise ReleaseError("self-test: legacy transition lost branch ancestry")
        if remote_tag_commit(str(remote), f"{ARM}/v0.1.0", source) != legacy_commit:
            raise ReleaseError("self-test: legacy canonical tag was not created")
        assert_cleanup(legacy_engine)
        assert_no_source_artifacts(source)

        print(
            "release self-test passed: initial and descendant releases, "
            "dependency pins/paths, comment-aware manifest paths, manifest "
            "metadata and SemVer/reuse rejection, tamper/wrong-pin detection, "
            "disabled checkout/commit/push hooks, remote-main provenance, "
            "exact package-branch leases, isolated command environment, URL "
            "rewrite and single-destination remote checks, disposable Zig "
            "verification, branch/tag races, legacy transition, cleanup, and "
            "atomic local publication"
        )
    finally:
        if previous_sentinel is None:
            os.environ.pop(sentinel, None)
        else:
            os.environ[sentinel] = previous_sentinel
        if source.exists():
            subprocess.run(
                ["git", "worktree", "prune"],
                cwd=source,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        shutil.rmtree(test_root, ignore_errors=True)
