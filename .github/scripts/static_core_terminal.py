"""One Windows ARM64 static ReleaseSafe Core observation, never qualification."""

import argparse
import ctypes
from ctypes import wintypes
import datetime
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import threading
import time

BASE = "b30a03ca047f53677fb12a66ba46a0b5459129af"
PARENT = "9263896361f7db00cea0023e81526076840e8483"
SDK = "21b2bd41afa768fc2895041d8176fe06de9ccde6"
WRAPPER = "9b3c94a2a4e0d98e055f0d908e11e1d7031b9a4b"
NATIVE = "286762b7730e2b780678f5ab11fef2b1bad639e0"
ARCHIVE_SHA = "68659eb5f1e4eb1437a722f1dd889c5a322c9954607f5edcf337bc3684a75a7e"
SEED = "0xeb0a6db2"
ALLOWED = {
    ".github/workflows/windows-arm64-static-core-evidence.yml",
    ".github/scripts/static_core_terminal.py",
    ".github/scripts/tests/test_static_core_terminal.py",
    "static_core_evidence.zig",
}
TARGET = "aarch64-windows-msvc"
LIBRARIES = ("lib/symcrypt_plus_NoCIL.lib", "lib/symcrypt_static_NoCIL.lib")
LOG_LIMIT = 8 * 1024 * 1024
ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGS = ROOT / ".agent-scratch/static-core-terminal-evidence"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def read_command(command):
    return subprocess.check_output(
        command, cwd=ROOT, text=True, encoding="utf-8", timeout=30
    ).strip()


def git(path, *args):
    return read_command(["git", "-C", str(path), *args])


def digest(path):
    with pathlib.Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def allowed_diff(changes):
    require(
        set(changes.splitlines()) == {f"A\t{path}" for path in ALLOWED},
        "Evidence must add exactly the four allowlisted files; production tree changed",
    )


def source_guard():
    expected = os.environ["EXPECTED_SHA"]
    require(re.fullmatch(r"[0-9a-f]{40}", expected), "Missing exact evidence SHA")
    require(os.environ["GITHUB_REF"] == "refs/heads/fleet/416-static-core-terminal-evidence",
            "Wrong evidence branch")
    require(os.environ["GITHUB_EVENT_NAME"] == "push", "Only branch-scoped pushes are supported")
    require(expected == os.environ["GITHUB_SHA"] == git(ROOT, "rev-parse", "HEAD"),
            "Source/event SHA mismatch")
    require(git(ROOT, "rev-list", "--parents", "-n", "1", "HEAD").split() == [expected, PARENT],
            "Evidence must directly continue the reviewed 926 diagnostic")
    allowed_diff(git(ROOT, "diff", "--name-status", "--no-renames", BASE, "HEAD"))
    require(not git(ROOT, "status", "--porcelain", "--untracked-files=no"),
            "Tracked evidence/production files changed")
    extras = git(ROOT, "ls-files", "--others", "--exclude-standard").splitlines()
    require(all(
        path == ".tools/zig-x86_64-windows-0.16.0.zip"
        or path.startswith(".tools/zig-x86_64/zig-x86_64-windows-0.16.0/")
        for path in extras
    ), "Unexpected untracked source files")
    return {"source": expected, "baseline": BASE, "production_tree": "unchanged"}


def repository_guard(path, commit):
    require(git(path, "rev-parse", "HEAD") == commit, f"Wrong checkout: {path.name}")
    require(not git(path, "status", "--porcelain"), f"Dirty checkout: {path.name}")


def fixture_tools():
    package = ROOT / ".zig-symcrypt-ci"
    repository_guard(package, WRAPPER)
    spec = importlib.util.spec_from_file_location("pinned_fixture_manifest", package / "tools/fixture_manifest.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require_image(path, architecture):
    tools = fixture_tools()
    require(tools.inspect_binary(path) == ("pe", architecture), f"Wrong PE ISA: {path}")
    return {"path": str(path.resolve()), "sha256": tools.sha256(path), "architecture": architecture}


def completed_tests(text, names):
    count = len(names)
    rows = re.findall(r"(?m)^(\d+)/(\d+) ([^\r\n]+)\.\.\.OK\r?$", text)
    require(len(rows) == count, f"Expected {count} explicit OK records")
    for index, ((number, total, name), expected) in enumerate(zip(rows, names), 1):
        require((number, total) == (str(index), str(count)), "Missing/duplicate/out-of-order test")
        require(name.endswith(".test." + expected), f"Unexpected test identity: {name}")
    require(re.search(rf"(?m)^All {count} tests passed\.\r?$", text), "Missing all-passed summary")
    require(not re.search(r"(?i)\b(?:SKIP|skipped|FAIL|failed|leaked)\b", text),
            "Skipped, failed or leaked test in terminal output")


def test_names(path, expected_count):
    names = re.findall(r'^test "([^"]+)" \{', path.read_text(encoding="utf-8"), re.MULTILINE)
    require(len(names) == expected_count, "Production test list changed")
    return names


# Retained from the reviewed phase driver's creation-bound CIM/handle controls.
# Globally inspect ancestry only; return image/resource data only for owned PIDs.
SNAPSHOT = r"""
$ErrorActionPreference = "Stop"
$known = ConvertFrom-Json -AsHashtable $env:EVIDENCE_OWNED_PIDS
$all = @(Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId,CreationDate -OperationTimeoutSec 3)
$owned = @{}
# The caller retains the root process handle, preventing reuse of its PID even
# after exit. This also finds direct surviving children after a short root run.
$rootPid = $env:EVIDENCE_ROOT_PID
$owned[$rootPid] = [long]$known[$rootPid]
foreach ($p in $all) {
  $key = [string]$p.ProcessId
  if ($null -ne $p.CreationDate -and $known.ContainsKey($key) -and [string]($p.CreationDate.ToFileTimeUtc()) -eq [string]$known[$key]) {
    $owned[$key] = $p.CreationDate.ToFileTimeUtc()
  }
}
do {
  $changed = $false
  foreach ($p in $all) {
    $key = [string]$p.ProcessId
    $parent = [string]$p.ParentProcessId
    if ($null -ne $p.CreationDate -and !$owned.ContainsKey($key) -and $owned.ContainsKey($parent) -and $p.CreationDate.ToFileTimeUtc() -ge $owned[$parent]) {
      $owned[$key] = $p.CreationDate.ToFileTimeUtc()
      $changed = $true
    }
  }
} while ($changed)
$rows = @()
if ($owned.Count) {
  $filter = ($owned.Keys | ForEach-Object { "ProcessId = $_" }) -join " OR "
  $rows = @(foreach ($p in (Get-CimInstance Win32_Process -Filter $filter -OperationTimeoutSec 3)) {
    if ($null -ne $p.CreationDate -and $p.CreationDate.ToFileTimeUtc() -eq $owned[[string]$p.ProcessId]) {
      [pscustomobject]@{pid=$p.ProcessId; parent=$p.ParentProcessId; created=[string]($p.CreationDate.ToFileTimeUtc()); image=$p.ExecutablePath; cpu_seconds=([double]$p.KernelModeTime+[double]$p.UserModeTime)/10000000; working_set=$p.WorkingSetSize}
    }
  })
}
ConvertTo-Json -InputObject @($rows) -Compress
"""


class Evidence:
    def __init__(self, mode):
        self.events = (LOGS / f"{mode}.jsonl").open("x", encoding="utf-8", buffering=1)
        self.lock = threading.Lock()
        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        k = self.kernel
        k.GetCurrentProcess.restype = wintypes.HANDLE
        k.IsWow64Process2.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.USHORT), ctypes.POINTER(wintypes.USHORT)]
        k.IsWow64Process2.restype = wintypes.BOOL
        k.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        k.GetProcessTimes.restype = wintypes.BOOL
        k.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        k.OpenProcess.restype = wintypes.HANDLE
        k.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
        k.TerminateProcess.restype = wintypes.BOOL
        k.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        k.WaitForSingleObject.restype = wintypes.DWORD
        k.CloseHandle.argtypes = [wintypes.HANDLE]
        k.CloseHandle.restype = wintypes.BOOL
        process_machine, native_machine = wintypes.USHORT(), wintypes.USHORT()
        require(k.IsWow64Process2(k.GetCurrentProcess(), ctypes.byref(process_machine), ctypes.byref(native_machine)),
                "Cannot establish native host ISA")
        self.emit("HOST", native_machine=hex(native_machine.value), driver_machine=hex(process_machine.value),
                  global_cache=os.environ.get("ZIG_GLOBAL_CACHE_DIR"),
                  local_cache=os.environ.get("ZIG_LOCAL_CACHE_DIR"), qualification=False)
        require(native_machine.value == 0xAA64, "This diagnostic requires native Windows ARM64")
        self.zig = ROOT / ".tools/zig-x86_64/zig-x86_64-windows-0.16.0/zig.exe"

    def emit(self, event, **values):
        row = json.dumps(dict(event=event, utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), **values),
                         sort_keys=True)
        with self.lock:
            self.events.write(row + "\n")
            print(row, flush=True)

    def created(self, handle):
        values = [wintypes.FILETIME() for _ in range(4)]
        require(self.kernel.GetProcessTimes(handle, *(ctypes.byref(v) for v in values)), "Process identity unavailable")
        return str(((values[0].dwHighDateTime << 32) | values[0].dwLowDateTime) // 10 * 10)

    def snapshot(self, known, phase, timeout=8):
        environment = os.environ.copy()
        environment["EVIDENCE_OWNED_PIDS"] = json.dumps(known)
        environment["EVIDENCE_ROOT_PID"] = next(iter(known))
        rows = json.loads(subprocess.check_output(
            ["pwsh", "-NoProfile", "-NonInteractive", "-Command", SNAPSHOT],
            cwd=ROOT, env=environment, text=True, timeout=timeout,
        ))
        for row in rows:
            known[str(row["pid"])] = row["created"]
            self.emit("PROCESS", phase=phase, **row)
        require(len(known) <= 512, "Owned process identity limit exceeded")
        return rows

    def cleanup(self, process, known, phase):
        self.emit("CLEANUP_BEGIN", phase=phase, pid=process.pid)
        deadline = time.monotonic() + 90

        def remaining(limit=8):
            value = deadline - time.monotonic()
            require(value > 0, "Owned cleanup exceeded 90 seconds")
            return min(value, limit)

        if process.poll() is None:
            result = subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                capture_output=True, text=True, timeout=remaining(),
            )
            self.emit("TREE_TERMINATION", pid=process.pid, exit_code=result.returncode,
                      stdout=result.stdout, stderr=result.stderr)
            process.wait(timeout=remaining())
        for row in self.snapshot(known, phase, remaining()):
            handle = self.kernel.OpenProcess(0x101001, False, row["pid"])
            if not handle:
                require(ctypes.get_last_error() == 87, "Cannot inspect owned descendant")
                continue
            try:
                if self.created(handle) != row["created"]:
                    self.emit("PID_REUSED_NOT_KILLED", pid=row["pid"])
                    continue
                terminated = self.kernel.TerminateProcess(handle, 1)
                require(terminated or self.kernel.WaitForSingleObject(handle, 0) == 0,
                        "Cannot terminate owned descendant")
                require(self.kernel.WaitForSingleObject(handle, int(remaining(5) * 1000)) == 0,
                        "Owned descendant did not exit")
            finally:
                self.kernel.CloseHandle(handle)
        require(not self.snapshot(known, phase, remaining()), "Live owned descendants remain")
        self.emit("CLEANUP_END", phase=phase)

    def finish_children(self, process, known, phase, cleanup):
        survivors = self.snapshot(known, phase)
        if not survivors:
            return
        require(phase == "fixture-build" and process.returncode == 0,
                "Command left live owned descendants")
        # MSBuild can retain owned workers after a successful fixture build.
        self.emit("FIXTURE_HELPERS_DRAIN", phase=phase, pids=[row["pid"] for row in survivors])
        cleanup()

    def run(self, phase, command, seconds):
        command = [str(arg) for arg in command]
        self.emit("START", phase=phase, command=command, cwd=str(ROOT), seconds=seconds,
                  log_limit_per_stream=LOG_LIMIT, retries=0)
        started = time.monotonic()
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            known = {str(process.pid): self.created(wintypes.HANDLE(int(process._handle)))}
        except (OSError, RuntimeError):
            process.kill()
            process.wait(timeout=5)
            process.stdout.close()
            process.stderr.close()
            raise
        self.emit("ROOT", phase=phase, pid=process.pid, created=known[str(process.pid)])
        errors = []
        stop = threading.Event()

        def capture(pipe, stream):
            try:
                with (LOGS / f"{phase}.{stream}.log").open("xb", buffering=0) as output:
                    size = 0
                    while chunk := pipe.read1(8192):
                        output.write(chunk[:max(0, LOG_LIMIT - size)])
                        size += len(chunk)
                        if size > LOG_LIMIT and not stop.is_set():
                            errors.append(f"{stream} exceeded its persistent log limit")
                            stop.set()
            except (OSError, ValueError) as error:
                errors.append(f"Capture failed: {error}")
                stop.set()
            finally:
                pipe.close()

        def observe():
            try:
                while process.poll() is None and not stop.is_set():
                    self.snapshot(known, phase)
                    stop.wait(10)
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                errors.append(f"Process observation failed: {error}")
                stop.set()

        readers = [
            threading.Thread(target=capture, args=(process.stdout, "stdout"), daemon=True),
            threading.Thread(target=capture, args=(process.stderr, "stderr"), daemon=True),
        ]
        observer = threading.Thread(target=observe, daemon=True)
        for thread in [*readers, observer]:
            thread.start()
        passed = False
        process_elapsed = None
        cleanup_started = False

        def cleanup_once():
            nonlocal cleanup_started
            require(not cleanup_started, "Owned cleanup already attempted")
            cleanup_started = True
            self.cleanup(process, known, phase)

        try:
            while process.poll() is None:
                if time.monotonic() - started >= seconds or errors:
                    # Kill through Popen's retained process handle at the deadline,
                    # not after a potentially blocking CIM/cleanup operation.
                    process.kill()
                    require(False, f"{phase}: whole-process timeout or observation failure: {errors}")
                time.sleep(0.02)
            process_elapsed = time.monotonic() - started
            require(process_elapsed <= seconds, f"{phase}: exceeded whole-process budget")
            stop.set()
            observer.join(10)
            require(not observer.is_alive(), "Process observer did not finish")
            for thread in readers:
                thread.join(5)
                require(not thread.is_alive(), "Output pipe remained open")
            require(not errors, str(errors))
            require(process.returncode == 0, f"{phase} exited {process.returncode}")
            self.finish_children(process, known, phase, cleanup_once)
            passed = True
        finally:
            stop.set()
            observer.join(10)
            if not passed:
                self.emit("FAIL", phase=phase, elapsed=time.monotonic() - started, error=str(sys.exception()))
                if not cleanup_started:
                    cleanup_once()
            for thread in readers:
                thread.join(5)
            require(not observer.is_alive() and all(not thread.is_alive() for thread in readers),
                    "Owned observation/capture did not finish")
            self.emit("EXIT", phase=phase, exit_code=process.poll(), process_seconds=process_elapsed,
                      total_seconds=time.monotonic() - started, passed=passed)
        return (LOGS / f"{phase}.stdout.log").read_text(encoding="utf-8", errors="replace"), \
            (LOGS / f"{phase}.stderr.log").read_text(encoding="utf-8", errors="replace")

    def inputs(self, phase, native=False):
        result = source_guard()
        repository_guard(ROOT / ".sdk-httpx-conformance", SDK)
        repository_guard(ROOT / ".zig-symcrypt-ci", WRAPPER)
        repository_guard(ROOT / ".symcrypt-ci-source", NATIVE)
        require(git(ROOT / ".symcrypt-ci-source", "rev-parse", "v103.13.0^{commit}") == NATIVE,
                "Native tag differs from pinned source")
        selected = shutil.which("zig")
        require(selected and pathlib.Path(selected).samefile(self.zig), "PATH selected a different Zig compiler")
        require(pathlib.Path(os.environ["ZIG_LOCAL_CACHE_DIR"]).resolve() == (ROOT / ".zig-cache").resolve(),
                "Unexpected inherited local cache; do not relocate it for this diagnostic")
        if os.environ.get("ZIG_LIB_DIR"):
            require(pathlib.Path(os.environ["ZIG_LIB_DIR"]).resolve() == (self.zig.parent / "lib").resolve(),
                    "ZIG_LIB_DIR selects a different compiler library")
        require(digest(ROOT / ".tools/zig-x86_64-windows-0.16.0.zip") == ARCHIVE_SHA,
                "Compiler archive differs from production")
        result.update(compiler=require_image(self.zig, "x86_64"), sdk=SDK, wrapper=WRAPPER, native=NATIVE,
                      manifests={name: digest(ROOT / name) for name in
                                 ("build.zig.zon", ".sdk-httpx-conformance/build.zig.zon",
                                  ".zig-symcrypt-ci/build.zig.zon")},
                      runner_source=digest(self.zig.parent / "lib/compiler/test_runner.zig"),
                      build_runner_source=digest(self.zig.parent / "lib/std/Build/Step/Run.zig"),
                      local_cache=os.environ.get("ZIG_LOCAL_CACHE_DIR"),
                      global_cache=os.environ.get("ZIG_GLOBAL_CACHE_DIR"))
        if native:
            fixture = ROOT / ".symcrypt-ci/aarch64"
            command = ["python3", "-B", ROOT / ".zig-symcrypt-ci/tools/fixture_manifest.py",
                       "verify", "--manifest", fixture / "provenance.json", "--target", TARGET, "--linkage", "static"]
            for library in LIBRARIES:
                command += ["--library", fixture / library]
            self.run(f"{phase}-provenance", command, 60)
            files = sorted(fixture.rglob("*"))
            require(len(files) <= 256 and all(not path.is_symlink() for path in files),
                    "Unexpected fixture tree structure")
            result["fixture"] = {str(path.relative_to(fixture)): digest(path) for path in files if path.is_file()}
        self.emit("INPUTS", phase=phase, **result)
        return result


def common_options():
    fixture = ROOT / ".symcrypt-ci/aarch64"
    return [
        "-Doptimize=ReleaseSafe", "-Denable_httpx_tls=true",
        f"-Dhttpx_adapter_source={ROOT / '.sdk-httpx-conformance'}",
        f"-Dtarget={TARGET}", "-Dtarget_can_run=true", "-Dlinkage=static",
        f"-Dsymcrypt_include_dir={ROOT / '.zig-symcrypt-ci/vendor/symcrypt/include'}",
        f"-Dsymcrypt_provenance={fixture / 'provenance.json'}",
        *(f"-Dsymcrypt_libraries={fixture / library}" for library in LIBRARIES),
    ]


def receipt(artifact):
    source_guard()
    path = pathlib.Path(artifact).resolve(strict=True)
    cache = pathlib.Path(os.environ.get("ZIG_LOCAL_CACHE_DIR", ROOT / ".zig-cache")).resolve()
    require(path.is_relative_to(cache), "Emitted artifact is outside the unchanged local cache")
    require(path.name == "test.exe", "Unexpected Core artifact basename")
    result = dict(artifact=require_image(path, "aarch64"), source=os.environ["GITHUB_SHA"], baseline=BASE,
                  label="NEW diagnostic build receipt; cache reuse possible; original byte identity unproven",
                  origin="production test-compile Step.Compile.getEmittedBin()",
                  options=common_options(), seed=SEED, cwd=str(ROOT),
                  build_command=json.loads((LOGS / "compile-command.json").read_text(encoding="utf-8")))
    write_json(LOGS / "core-artifact.json", result)
    print(json.dumps(result, sort_keys=True), flush=True)


def preflight(evidence):
    before = evidence.inputs("preflight-before")
    deadline = time.monotonic() + 7 * 60

    def run(name, args, limit):
        remaining = deadline - time.monotonic()
        require(remaining > 0, "Preflight cumulative seven-minute budget exceeded")
        return evidence.run(name, args, min(limit, remaining))

    stdout, _ = run("compiler-version", [evidence.zig, "version"], 30)
    require(stdout.strip() == "0.16.0", "Wrong selected compiler version")
    tests = LOGS / "ci-inputs-tests.exe"
    checker = LOGS / "ci-inputs-check.exe"
    run("guard-compile", [evidence.zig, "test", "conformance/ci_inputs.zig",
                         "--test-no-exec", f"-femit-bin={tests}"], 360)
    evidence.emit("GUARD_IMAGE", **require_image(tests, "x86_64"), native_sdk_proof=False)
    stdout, stderr = run("guard-run", [tests], 60)
    completed_tests(stdout + stderr, test_names(ROOT / "conformance/ci_inputs.zig", 4))
    run("checker-compile", [evidence.zig, "build-exe", "conformance/ci_inputs.zig",
                           f"-femit-bin={checker}"], 360)
    evidence.emit("CHECKER_IMAGE", **require_image(checker, "x86_64"), native_sdk_proof=False)
    run("coherence", [checker, "build.zig.zon", ".sdk-httpx-conformance/build.zig.zon",
                      SDK, git(ROOT / ".sdk-httpx-conformance", "rev-parse", "HEAD")], 60)
    stdout, _ = run("released-sdk-tag", [
        "git", "ls-remote", "--refs", "--tags", "https://github.com/cataggar/azure-sdk-for-zig.git",
        "refs/tags/azure_sdk_core_httpx/v0.1.0",
    ], 60)
    require(stdout.strip() == f"{SDK}\trefs/tags/azure_sdk_core_httpx/v0.1.0",
            "SDK input is not the exact published lightweight release")
    after = evidence.inputs("preflight-after")
    require(after == before, "Inputs changed during preflight")
    write_json(LOGS / "preflight-inputs.json", after)


def native_phase(evidence, mode):
    before = evidence.inputs(f"{mode}-before", native=True)
    preflight_inputs = json.loads((LOGS / "preflight-inputs.json").read_text(encoding="utf-8"))
    require({key: value for key, value in before.items() if key != "fixture"} == preflight_inputs,
            "Inputs changed since preflight")
    artifact = None
    record = None
    try:
        if mode == "compile":
            command = [evidence.zig, "build", "--build-file", "static_core_evidence.zig",
                       "static-core-receipt", *common_options(), "--seed", SEED, "--verbose", "--summary", "all"]
            write_json(LOGS / "compile-command.json", [str(arg) for arg in command])
            evidence.run("core-compile-receipt", command, 600)
            require((LOGS / "core-artifact.json").is_file(), "Compiler did not supply an artifact receipt")
            write_json(LOGS / "compiled-inputs.json", before)
        else:
            require(before == json.loads((LOGS / "compiled-inputs.json").read_text(encoding="utf-8")),
                    "Inputs changed after Core compilation")
            record = json.loads((LOGS / "core-artifact.json").read_text(encoding="utf-8"))
            artifact = pathlib.Path(record["artifact"]["path"])
            require(record["source"] == os.environ["GITHUB_SHA"] and record["baseline"] == BASE,
                    "Artifact receipt belongs to another source")
            require(record["options"] == common_options() and record["seed"] == SEED and record["cwd"] == str(ROOT),
                    "Artifact receipt options/context differ")
            require(require_image(artifact, "aarch64") == record["artifact"], "Artifact changed after compiler receipt")
            write_json(LOGS / "standalone-started.json", dict(artifact=record["artifact"], attempts=1, seconds=60))
            stdout, stderr = evidence.run("core-terminal", [
                artifact, r"--cache-dir=.\.zig-cache", f"--seed={SEED}",
            ], 60)
            completed_tests(stdout + stderr, test_names(ROOT / "root.zig", 10))
            evidence.emit("TEN_TERMINAL_CASES_PASSED", qualification=False, original_binary_identity=False)
    finally:
        if artifact is not None:
            identity = require_image(artifact, "aarch64")
            evidence.emit("POST_ARTIFACT", **identity)
            require(identity == record["artifact"], "Core artifact changed during execution")
        after = evidence.inputs(f"{mode}-after", native=True)
        require(after == before, f"Inputs changed during {mode}")
        write_json(LOGS / f"{mode}-post-inputs.json", after)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("source", "preflight", "fixtures", "compile", "terminal", "receipt"))
    parser.add_argument("artifact", nargs="?")
    args = parser.parse_args()
    os.chdir(ROOT)
    if args.mode == "source":
        write_json(LOGS / "source-start.json", dict(expected=os.environ["EXPECTED_SHA"], baseline=BASE))
        try:
            write_json(LOGS / "source.json", source_guard())
        finally:
            if sys.exception() is not None:
                write_json(LOGS / "source-failure.json", dict(error=str(sys.exception())))
        return
    if args.mode == "receipt":
        require(args.artifact is not None, "Compiler artifact argument required")
        receipt(args.artifact)
        return
    require(args.artifact is None, "Unexpected artifact argument")
    evidence = Evidence(args.mode)
    try:
        if args.mode == "preflight":
            preflight(evidence)
        elif args.mode == "fixtures":
            before = evidence.inputs("fixtures-before")
            try:
                evidence.run("fixture-build", [
                    "pwsh", "-NoProfile", "-NonInteractive", "-File",
                    ROOT / ".zig-symcrypt-ci/tools/build-windows-fixtures.ps1",
                    "-Source", ROOT / ".symcrypt-ci-source", "-Output", ROOT / ".symcrypt-ci/aarch64",
                    "-Architecture", "aarch64",
                ], 1200)
            finally:
                require(evidence.inputs("fixtures-after") == before, "Fixture builder did not restore source")
        else:
            native_phase(evidence, args.mode)
        evidence.emit("MODE_COMPLETE", mode=args.mode, qualification=False)
    finally:
        if sys.exception() is not None:
            evidence.emit("MODE_FAILED", mode=args.mode, error=str(sys.exception()), qualification=False)
        evidence.events.close()


if __name__ == "__main__":
    main()
