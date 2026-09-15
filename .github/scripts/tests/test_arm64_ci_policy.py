"""Checkout policy regressions; native execution is still required."""

import pathlib
import unittest


class Arm64CiPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        workflow = (
            pathlib.Path(__file__).resolve().parents[2] / "workflows/package-ci.yml"
        ).read_text(encoding="utf-8")
        cls.architecture = workflow.split("\n  architecture-test:\n", 1)[1]
        cls.windows = cls.architecture.split(
            "      - name: Validate Windows Arm64\n", 1
        )[1].split("\n      - ", 1)[0]

    def test_windows_job_and_native_phase_are_bounded(self):
        self.assertIn(
            "timeout-minutes: ${{ matrix.platform == 'windows' && 90 || 360 }}",
            self.architecture,
        )
        self.assertIn("        timeout-minutes: 60\n", self.windows)

    def test_all_native_modes_and_post_loops_keep_serial_verbose_builds(self):
        self.assertIn(
            'foreach ($optimize in @("Debug", "ReleaseSafe")) {', self.windows
        )
        commands = [
            line.strip() for line in self.windows.splitlines()
            if line.lstrip().startswith("zig build ")
        ]
        expected = []
        for targets, optimize in (
            ("test tls-test tls-paired-check tls-interop-check", '"-Doptimize=$optimize"'),
            ("example-run", "-Doptimize=ReleaseSafe"),
            ("package-consumer-check", "-Doptimize=ReleaseSafe"),
        ):
            for linkage in ("dynamic", "static"):
                expected.append(
                    f"zig build {targets} {optimize} @{linkage} -j1 --verbose --summary all"
                )
        self.assertEqual(commands, expected)


if __name__ == "__main__":
    unittest.main()
