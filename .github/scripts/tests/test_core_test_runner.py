"""Portable policy/outcome tests; Windows containment requires native CI."""

import ctypes
import importlib.util
import io
import pathlib
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "core_runner", pathlib.Path(__file__).resolve().parents[3] / "conformance/run_core_tests.py"
)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class CoreRunnerTests(unittest.TestCase):
    def output(self):
        names = runner.expected_tests()
        text = "".join(f"{index}/10 root.test.{name}...OK\n" for index, name in enumerate(names, 1))
        return (text + "All 10 tests passed.\n").encode(), names

    def test_complete_output_accepts_lf_and_crlf(self):
        output, names = self.output()
        runner.validate_output(output, names)
        runner.validate_output(output.replace(b"\n", b"\r\n"), names)

    def test_missing_empty_or_summary_only_output_fails(self):
        _, names = self.output()
        for output in (b"", b"All 10 tests passed.\n", b"10/10 root.test.other...OK\n"):
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                runner.validate_output(output, names)

    def test_skip_leak_logged_error_and_wrong_case_fail(self):
        output, names = self.output()
        for changed in (
            output.replace(b"...OK", b"...SKIP", 1),
            output + b"1 tests leaked memory.\n",
            output + b"1 errors were logged.\n",
            output + b"1 skipped.\n",
            output.replace(b"1/10", b"2/10", 1),
            output.replace(b"root.test.Core", b"root.test.NotCore", 1),
            output.replace(b"All 10 tests passed.\n", b""),
        ):
            with self.subTest(output=changed), self.assertRaises(RuntimeError):
                runner.validate_output(changed, names)

    def exercise(self, output, code=0, hanging=False, survivors=False, assignment_failure=False, cleanup_failure=False):
        events = []

        class Gate(io.BytesIO):
            def write(self, data):
                events.append("gate")
                return super().write(data)

        class Process:
            pid = 42

            def __init__(self):
                self.stdin = Gate()
                self.stdout = io.BytesIO(output)
                self.returncode = None if hanging else code

            def poll(self):
                return self.returncode

            def kill(self):
                events.append("kill")
                self.returncode = 1

            def wait(self, timeout):
                events.append(("wait", timeout))
                return self.returncode

        process = Process()

        class Job:
            def assign(self, child):
                self.child = child
                events.append("assign")
                if assignment_failure:
                    raise OSError("assignment failed")

            def empty(self):
                return not survivors

            def close(self):
                events.append("job-close")
                if process.returncode is None and not assignment_failure:
                    process.returncode = 1
                if cleanup_failure:
                    raise OSError("cleanup failed")

        stderr = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
        clock = [0, 61] if hanging else [0, 1, 1, 1]
        with patch.object(runner, "WindowsJob", Job), patch.object(runner.subprocess, "Popen", return_value=process) as spawn, \
                patch.object(runner.time, "monotonic", side_effect=clock), patch.object(runner.sys, "stderr", stderr):
            try:
                result = runner.run(["test.exe", "--cache-dir=.zig-cache", "--seed=0x123"])
                return result, events, spawn.call_args
            finally:
                self.assertIn("job-close", events)
                self.assertIn(("wait", runner.CLEANUP_TIMEOUT), events)
                if "gate" in events:
                    self.assertLess(events.index("assign"), events.index("gate"))
                if assignment_failure:
                    self.assertNotIn("gate", events)
                    self.assertIn("kill", events)

    def test_one_gated_execution_preserves_arguments(self):
        output, _ = self.output()
        result, events, call = self.exercise(output)
        self.assertEqual(result, output)
        self.assertEqual(events.count("gate"), 1)
        self.assertEqual(call.args[0][-3:], ["test.exe", "--cache-dir=.zig-cache", "--seed=0x123"])
        self.assertNotIn("--listen=-", call.args[0])
        self.assertNotIn("cwd", call.kwargs)

    def test_nonzero_exit_never_accepts_all_passed_text(self):
        output, _ = self.output()
        with self.assertRaisesRegex(RuntimeError, "exited 7"):
            self.exercise(output, code=7)

    def test_timeout_fails_and_cleans_up_without_retry(self):
        with self.assertRaisesRegex(RuntimeError, "timed out after 60"):
            self.exercise(b"1/10 root.test.first...", hanging=True)

    def test_output_limit_fails(self):
        with patch.object(runner, "OUTPUT_LIMIT", 32):
            with self.assertRaisesRegex(RuntimeError, "output exceeded"):
                self.exercise(b"x" * 33)

    def test_survivors_fail_even_after_exit_zero(self):
        output, _ = self.output()
        with self.assertRaisesRegex(RuntimeError, "descendant"):
            self.exercise(output, survivors=True)

    def test_assignment_failure_cannot_open_the_gate(self):
        with self.assertRaisesRegex(OSError, "assignment failed"):
            self.exercise(b"", hanging=True, assignment_failure=True)

    def test_cleanup_failure_cannot_report_success(self):
        output, _ = self.output()
        with self.assertRaisesRegex(OSError, "cleanup failed"):
            self.exercise(output, cleanup_failure=True)

    def test_windows_job_64_bit_layout(self):
        if ctypes.sizeof(ctypes.c_void_p) == 8:
            self.assertEqual(ctypes.sizeof(runner.BasicLimits), 64)
            self.assertEqual(ctypes.sizeof(runner.ExtendedLimits), 144)
            self.assertEqual(ctypes.sizeof(runner.Accounting), 48)

    def test_non_windows_has_no_fallback(self):
        with patch.object(runner.sys, "platform", "linux"):
            with self.assertRaisesRegex(RuntimeError, "requires Windows ARM64"):
                runner.WindowsJob()


if __name__ == "__main__":
    unittest.main()
