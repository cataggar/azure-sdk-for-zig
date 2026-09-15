"""Portable evidence policy checks; no Windows process or native test execution."""

import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "terminal", pathlib.Path(__file__).resolve().parents[1] / "static_core_terminal.py"
)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class TerminalEvidenceTests(unittest.TestCase):
    def output(self, count=10):
        names = [f"case {index}" for index in range(1, count + 1)]
        text = "".join(f"{index}/{count} root.test.{name}...OK\n"
                       for index, name in enumerate(names, 1))
        return text + f"All {count} tests passed.\n", names

    def test_all_ten_named_passes_are_required(self):
        text, names = self.output()
        terminal.completed_tests(text, names)
        terminal.completed_tests(text.replace("\n", "\r\n"), names)

    def test_summary_alone_is_not_enough(self):
        _, names = self.output()
        with self.assertRaisesRegex(RuntimeError, "explicit OK"):
            terminal.completed_tests("All 10 tests passed.\n", names)

    def test_skip_exit_zero_is_not_accepted(self):
        text, names = self.output()
        for changed in (text.replace("...OK", "...SKIP", 1), text + "0 failed; 1 skipped\n"):
            with self.subTest(text=changed), self.assertRaises(RuntimeError):
                terminal.completed_tests(changed, names)

    def test_missing_duplicate_and_wrong_case_are_rejected(self):
        text, names = self.output()
        for changed in (
            text.replace("1/10", "2/10", 1),
            text.replace("root.test.case 1...", "root.test.some other case...", 1),
            text.replace("All 10 tests passed.\n", ""),
            text + "1/10 root.test.case 1...OK\n",
        ):
            with self.subTest(text=changed), self.assertRaises(RuntimeError):
                terminal.completed_tests(changed, names)

    def test_leak_does_not_become_success(self):
        text, names = self.output()
        with self.assertRaisesRegex(RuntimeError, "leaked"):
            terminal.completed_tests(text + "1 tests leaked memory.\n", names)

    def test_original_root_and_guard_case_counts(self):
        terminal.test_names(terminal.ROOT / "root.zig", 10)
        terminal.test_names(terminal.ROOT / "conformance/ci_inputs.zig", 4)

    def test_only_exact_four_additions_are_allowed(self):
        valid = "\n".join(f"A\t{path}" for path in terminal.ALLOWED)
        terminal.allowed_diff(valid)
        for invalid in (valid + "\nM\tbuild.zig", valid.replace("A\t", "M\t", 1), "", valid + "\nA\textra"):
            with self.subTest(diff=invalid), self.assertRaises(RuntimeError):
                terminal.allowed_diff(invalid)

    def test_options_keep_native_static_release_safe_and_library_order(self):
        options = terminal.common_options()
        for option in ("-Doptimize=ReleaseSafe", "-Dtarget=aarch64-windows-msvc",
                       "-Dtarget_can_run=true", "-Dlinkage=static", "-Denable_httpx_tls=true"):
            self.assertIn(option, options)
        libraries = [arg.split("=", 1)[1] for arg in options if arg.startswith("-Dsymcrypt_libraries=")]
        self.assertEqual([pathlib.Path(path).name for path in libraries],
                         ["symcrypt_plus_NoCIL.lib", "symcrypt_static_NoCIL.lib"])
        self.assertNotIn("-j1", options)

    def test_receipt_uses_supplied_emitted_path_not_cache_discovery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            logs = root / "logs"
            logs.mkdir()
            artifact = root / ".zig-cache/o/receipt/test.exe"
            artifact.parent.mkdir(parents=True)
            artifact.write_bytes(b"portable receipt fixture, not an executable")
            command = ["zig", "build", "--build-file", "static_core_evidence.zig", "static-core-receipt"]
            (logs / "compile-command.json").write_text(json.dumps(command))
            identity = dict(path=str(artifact), sha256=terminal.digest(artifact), architecture="aarch64")
            with patch.object(terminal, "ROOT", root), patch.object(terminal, "LOGS", logs), \
                    patch.object(terminal, "source_guard"), patch.object(terminal, "require_image", return_value=identity), \
                    patch.dict(terminal.os.environ, {"GITHUB_SHA": "e" * 40, "ZIG_LOCAL_CACHE_DIR": str(root / ".zig-cache")}), \
                    patch("builtins.print"):
                terminal.receipt(str(artifact))
                record = json.loads((logs / "core-artifact.json").read_text())
                self.assertEqual(record["artifact"], identity)
                self.assertEqual(record["build_command"], command)
                self.assertIn("original byte identity unproven", record["label"])
                with self.assertRaises(FileExistsError):
                    terminal.receipt(str(artifact))

    def test_receipt_rejects_outside_cache_before_image_checks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            artifact = root / "test.exe"
            artifact.write_bytes(b"fixture")
            with patch.object(terminal, "ROOT", root), patch.object(terminal, "source_guard"), \
                    patch.dict(terminal.os.environ, {"ZIG_LOCAL_CACHE_DIR": str(root / ".zig-cache")}):
                with self.assertRaisesRegex(RuntimeError, "outside"):
                    terminal.receipt(str(artifact))

    def test_build_driver_keeps_production_artifact_and_has_no_execution_step(self):
        source = (terminal.ROOT / "static_core_evidence.zig").read_text()
        self.assertIn("production.build(b)", source)
        self.assertIn('get("test-compile")', source)
        self.assertIn("receipt.addFileArg(core.getEmittedBin())", source)
        self.assertNotIn("addTest(", source)
        self.assertNotIn("addRunArtifact(", source)


if __name__ == "__main__":
    unittest.main()
