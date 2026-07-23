#!/usr/bin/env python3

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "eng" / "release"))

from registry import load as load_registry  # noqa: E402
import zon  # noqa: E402


FINGERPRINT = re.compile(
    r"(?m)^\s*\.fingerprint\s*=\s*0x[0-9a-fA-F]+\s*,\s*$"
)
MINIMUM_ZIG = re.compile(
    r'(?m)^\s*\.minimum_zig_version\s*=\s*"[^"]+"\s*,\s*$'
)


def main() -> int:
    packages = load_registry(ROOT / "eng" / "packages.zig")
    for package in packages.values():
        path = ROOT / package.source_path / "build.zig.zon"
        text = path.read_text(encoding="utf-8")
        manifest = zon.parse(text)

        if manifest.name != package.name or manifest.version != package.version:
            raise RuntimeError(f"{package.name}: manifest identity differs")
        if not FINGERPRINT.search(text) or not MINIMUM_ZIG.search(text):
            raise RuntimeError(f"{package.name}: required manifest metadata is missing")
        if len(manifest.paths) != len(set(manifest.paths)):
            raise RuntimeError(f"{package.name}: duplicate .paths entry")
        if set(manifest.paths) != set(package.publish_paths):
            raise RuntimeError(f"{package.name}: .paths differ from registry")

        expected_dependencies = set(package.dependencies) | set(
            package.external_dependencies
        )
        if set(manifest.dependencies) != expected_dependencies:
            raise RuntimeError(f"{package.name}: dependency keys differ from registry")
        for name in package.dependencies:
            dependency = manifest.dependencies[name]
            if (
                dependency.path is None
                or dependency.url is not None
                or dependency.package_hash is not None
            ):
                raise RuntimeError(f"{package.name}: invalid local dependency {name}")
            dependency_path = Path(dependency.path)
            expected_path = (ROOT / packages[name].source_path).resolve()
            actual_path = (path.parent / dependency_path).resolve()
            if dependency_path.is_absolute() or actual_path != expected_path:
                raise RuntimeError(
                    f"{package.name}: local dependency {name} resolves to "
                    f"{actual_path}, expected {expected_path}"
                )
        for name in package.external_dependencies:
            dependency = manifest.dependencies[name]
            if (
                dependency.path is not None
                or not dependency.url
                or not dependency.package_hash
            ):
                raise RuntimeError(
                    f"{package.name}: invalid external dependency {name}"
                )

    print(f"package manifests structurally valid: {len(packages)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
