"""Bounded terminal execution of Windows ARM64 static Core tests."""

import argparse
import ctypes
from ctypes import wintypes
import importlib.util
import pathlib
import re
import subprocess
import sys
import threading
import time

sys.dont_write_bytecode = True

TIMEOUT = 60
CLEANUP_TIMEOUT = 5
OUTPUT_LIMIT = 1024 * 1024


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


class BasicLimits(ctypes.Structure):
    _fields_ = [
        ("process_time", ctypes.c_int64), ("job_time", ctypes.c_int64),
        ("flags", ctypes.c_uint32), ("minimum_set", ctypes.c_size_t),
        ("maximum_set", ctypes.c_size_t), ("process_count", ctypes.c_uint32),
        ("affinity", ctypes.c_size_t), ("priority", ctypes.c_uint32),
        ("scheduling", ctypes.c_uint32),
    ]


class ExtendedLimits(ctypes.Structure):
    _fields_ = [
        ("basic", BasicLimits), ("io_counters", ctypes.c_uint64 * 6),
        ("process_memory", ctypes.c_size_t), ("job_memory", ctypes.c_size_t),
        ("peak_process_memory", ctypes.c_size_t), ("peak_job_memory", ctypes.c_size_t),
    ]


class Accounting(ctypes.Structure):
    _fields_ = [
        ("times", ctypes.c_int64 * 4), ("page_faults", ctypes.c_uint32),
        ("total_processes", ctypes.c_uint32), ("active_processes", ctypes.c_uint32),
        ("terminated_processes", ctypes.c_uint32),
    ]


class WindowsJob:
    def __init__(self):
        require(sys.platform == "win32", "Core terminal execution requires Windows ARM64")
        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        signatures = {
            "GetCurrentProcess": (wintypes.HANDLE, []),
            "IsWow64Process2": (wintypes.BOOL, [wintypes.HANDLE, ctypes.POINTER(wintypes.USHORT), ctypes.POINTER(wintypes.USHORT)]),
            "CreateJobObjectW": (wintypes.HANDLE, [ctypes.c_void_p, wintypes.LPCWSTR]),
            "SetInformationJobObject": (wintypes.BOOL, [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]),
            "QueryInformationJobObject": (wintypes.BOOL, [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p]),
            "OpenProcess": (wintypes.HANDLE, [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]),
            "AssignProcessToJobObject": (wintypes.BOOL, [wintypes.HANDLE, wintypes.HANDLE]),
            "TerminateJobObject": (wintypes.BOOL, [wintypes.HANDLE, wintypes.UINT]),
            "CloseHandle": (wintypes.BOOL, [wintypes.HANDLE]),
        }
        for name, (result, arguments) in signatures.items():
            function = getattr(self.kernel, name)
            function.restype, function.argtypes = result, arguments
        process_machine, native_machine = wintypes.USHORT(), wintypes.USHORT()
        self.check(self.kernel.IsWow64Process2(self.kernel.GetCurrentProcess(),
                                             ctypes.byref(process_machine), ctypes.byref(native_machine)))
        require(native_machine.value == 0xAA64, "Native host is not Windows ARM64")
        self.handle = self.kernel.CreateJobObjectW(None, None)
        self.check(self.handle)
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
        try:
            self.check(self.kernel.SetInformationJobObject(self.handle, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
        except OSError:
            self.check(self.kernel.CloseHandle(self.handle))
            raise

    @staticmethod
    def check(result):
        if not result:
            raise ctypes.WinError(ctypes.get_last_error())

    def assign(self, process):
        # The gated Popen process still owns its PID; it cannot start the test yet.
        handle = self.kernel.OpenProcess(0x101, False, process.pid)  # SET_QUOTA | TERMINATE
        self.check(handle)
        try:
            self.check(self.kernel.AssignProcessToJobObject(self.handle, handle))
        finally:
            self.check(self.kernel.CloseHandle(handle))

    def empty(self):
        accounting = Accounting()
        self.check(self.kernel.QueryInformationJobObject(
            self.handle, 1, ctypes.byref(accounting), ctypes.sizeof(accounting), None,
        ))
        return accounting.active_processes == 0

    def close(self):
        try:
            self.check(self.kernel.TerminateJobObject(self.handle, 1))
            deadline = time.monotonic() + CLEANUP_TIMEOUT
            while not self.empty():
                require(time.monotonic() < deadline, "Owned Core process cleanup timed out")
                time.sleep(0.01)
        finally:
            self.check(self.kernel.CloseHandle(self.handle))


def expected_tests():
    source = pathlib.Path(__file__).resolve().parent.parent / "root.zig"
    names = re.findall(r'^test "([^"]+)" \{', source.read_text(encoding="utf-8"), re.MULTILINE)
    require(len(names) == 10, "Expected the ten production Core cases")
    return names


def validate_output(output, names):
    require(len(names) == 10, "Expected ten Core test identities")
    text = output.decode("utf-8", errors="replace")
    rows = re.findall(r"(?m)^(\d+)/10 ([^\r\n]+)\.\.\.OK\r?$", text)
    require(len(rows) == 10, "Core output lacks ten explicit OK records")
    for index, ((number, name), expected) in enumerate(zip(rows, names), 1):
        require(number == str(index) and name.endswith(".test." + expected),
                "Core output has missing, duplicated, reordered or unexpected cases")
    require(re.search(r"(?m)^All 10 tests passed\.\r?$", text), "Core all-passed summary is missing")
    require(not re.search(r"(?i)\b(?:SKIP|skipped|failed|leaked)\b|errors were logged", text),
            "Core output reports skipped tests, failures, leaks or logged errors")


def run(command):
    output = bytearray()
    errors = []
    reader = None
    process = None
    job = WindowsJob()
    deadline = time.monotonic() + TIMEOUT
    try:
        # Membership precedes the gate: all subsequent test descendants inherit
        # this private job, including if the launcher is externally cancelled.
        process = subprocess.Popen(
            [sys.executable, "-B", str(pathlib.Path(__file__).resolve()), "--worker", *command],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        job.assign(process)

        def collect():
            try:
                while chunk := process.stdout.read1(8192):
                    remaining = OUTPUT_LIMIT - len(output)
                    output.extend(chunk[:remaining])
                    if len(chunk) > remaining:
                        errors.append("Core output exceeded 1 MiB")
                        return
            except OSError as error:
                errors.append(f"Cannot read Core output: {error}")

        reader = threading.Thread(target=collect, daemon=True)
        reader.start()
        process.stdin.write(b"G")
        process.stdin.close()
        while process.poll() is None:
            require(time.monotonic() < deadline, "Core terminal execution timed out after 60 seconds")
            require(not errors, "; ".join(errors))
            time.sleep(0.02)
        require(time.monotonic() <= deadline, "Core terminal execution exceeded 60 seconds")
        reader.join(max(0, min(CLEANUP_TIMEOUT, deadline - time.monotonic())))
        require(not reader.is_alive(), "Core output remained open after process exit")
        require(time.monotonic() <= deadline, "Core terminal output exceeded the execution deadline")
        require(not errors, "; ".join(errors))
        require(process.returncode == 0, f"Core terminal process exited {process.returncode}")
        require(job.empty(), "Core terminal execution left owned descendant processes")
        return bytes(output)
    finally:
        try:
            job.close()
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=CLEANUP_TIMEOUT)
                process.stdin.close()
                if reader is not None:
                    reader.join(CLEANUP_TIMEOUT)
                if reader is None or not reader.is_alive():
                    process.stdout.close()
                require(reader is None or not reader.is_alive(), "Core output cleanup did not finish")
            sys.stderr.buffer.write(output)
            sys.stderr.buffer.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--fixture-tools", required=True, type=pathlib.Path)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--seed", required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"0x[0-9a-fA-F]{1,8}", args.seed), "Expected the build's u32 hexadecimal seed")
    spec = importlib.util.spec_from_file_location("fixture_manifest", args.fixture_tools)
    tools = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tools)
    executable = args.executable.resolve(strict=True)
    require(tools.inspect_binary(executable) == ("pe", "aarch64"), "Core executable is not an ARM64 PE image")
    names = expected_tests()
    command = [str(executable), f"--cache-dir={args.cache_dir}", f"--seed={args.seed}"]
    print(f"Core terminal execution (60s, static Windows ARM64): {subprocess.list2cmdline(command)}", flush=True)
    validate_output(run(command), names)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--worker"]:
        require(sys.stdin.buffer.read(1) == b"G", "Core worker was not assigned to its job")
        sys.exit(subprocess.call(sys.argv[2:], stdin=subprocess.DEVNULL, timeout=TIMEOUT))
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Core terminal failure: {error}", file=sys.stderr)
        sys.exit(1)
