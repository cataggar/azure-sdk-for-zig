"""Portable policy checks; no Windows tools or native libraries are executed."""
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "reference", pathlib.Path(__file__).resolve().parents[1] / "prepare_openssl.py"
)
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ToolchainTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.path = self.root / "metadata.json"

    def metadata(self, architecture="arm64"):
        directory = self.root / "14.44.35207"
        binaries = directory / "bin" / ("Host" + architecture) / architecture
        binaries.mkdir(parents=True)
        data = dict(
            policy="installed-msvc-14.44-no-fallback",
            toolset_version=directory.name,
            toolset_directory=str(directory),
            host_architecture=architecture,
            target_architecture=architecture,
            windows_sdk_version="10.0.26100.0",
            ucrt_version="10.0.26100.0",
        )
        self.tools = {}
        for key, name, version in (
            ("compiler", "cl", "19.44.35228.0"),
            ("linker", "link", "14.44.35228.0"),
            ("librarian", "lib", "14.44.35228.0"),
            ("make", "nmake", "14.44.35228.0"),
        ):
            path = binaries / (name + ".exe")
            path.write_bytes(("fixture-" + name).encode())
            self.tools[name] = str(path)
            data[key] = dict(
                executable=str(path), product="test fixture",
                file_version=version, sha256=reference.digest(path),
            )
        return data

    def validate(self, data, target="aarch64-windows-msvc", environment=None):
        self.path.write_text(json.dumps(data))
        with patch.object(reference.shutil, "which", side_effect=lambda name: self.tools.get(name)):
            with patch.dict(reference.os.environ, environment or {}, clear=True):
                return reference.windows_toolchain(self.path, target)

    def test_arm64_exact_paths_versions_and_hashes(self):
        data = self.metadata()
        self.assertEqual(self.validate(data), data)

    def test_x64_uses_the_same_explicit_family_policy(self):
        data = self.metadata("x64")
        self.assertEqual(self.validate(data, "x86_64-windows-msvc"), data)

    def test_missing_selection_metadata_fails(self):
        with self.assertRaisesRegex(RuntimeError, "toolset selection"):
            reference.windows_toolchain(None, "aarch64-windows-msvc")

    def test_newer_default_toolset_is_rejected(self):
        data = self.metadata()
        data["toolset_version"] = "14.51.36231"
        with self.assertRaisesRegex(RuntimeError, "toolset or architecture"):
            self.validate(data)

    def test_wrong_host_architecture_is_rejected(self):
        data = self.metadata()
        data["host_architecture"] = "x64"
        with self.assertRaisesRegex(RuntimeError, "toolset or architecture"):
            self.validate(data)

    def test_missing_sdk_identity_is_rejected(self):
        data = self.metadata()
        data["windows_sdk_version"] = ""
        with self.assertRaisesRegex(RuntimeError, "SDK identity"):
            self.validate(data)

    def test_compiler_family_mismatch_is_rejected(self):
        data = self.metadata()
        data["compiler"]["file_version"] = "19.51.36256.0"
        with self.assertRaisesRegex(RuntimeError, "verified metadata"):
            self.validate(data)

    def test_changed_linker_digest_is_rejected(self):
        data = self.metadata()
        pathlib.Path(self.tools["link"]).write_bytes(b"changed")
        with self.assertRaisesRegex(RuntimeError, "verified metadata"):
            self.validate(data)

    def test_path_shadowing_is_rejected(self):
        data = self.metadata()
        shadow = self.root / "cl.exe"
        shadow.write_bytes(b"shadow")
        self.tools["cl"] = str(shadow)
        with self.assertRaisesRegex(RuntimeError, "verified metadata"):
            self.validate(data)

    def test_external_compiler_override_is_rejected(self):
        data = self.metadata()
        with self.assertRaisesRegex(RuntimeError, "External CC override"):
            self.validate(data, environment={"CC": "clang-cl"})

    def test_metadata_size_budget(self):
        self.path.write_bytes(b"x" * (128 * 1024 + 1))
        with self.assertRaisesRegex(RuntimeError, "size budget"):
            reference.windows_toolchain(self.path, "aarch64-windows-msvc")


if __name__ == "__main__":
    unittest.main()
