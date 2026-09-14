#!/usr/bin/env python3
"""Evidence for the existing CLI builder only; no SDK TLS or FIPS qualification."""

import argparse
import ctypes
import hashlib
import json
import os
import pathlib
import re
import shutil
import struct
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPERS = {
    "prepare_openssl.py": "0b169a2cc57dd9f0bd954f0da6d39950c8e8eff4d44b91ff0b5863830944543a",
    "prepare_openssl_windows.ps1": "e126229fe003a41a367cb93f7a617028852261a2c36cc002fd9310bfe02a80ea",
}
TARGETS = {
    "x86_64-linux-gnu": ("linux", "X64", 62, "linux-x86_64"),
    "aarch64-linux-gnu": ("linux", "ARM64", 183, "linux-aarch64"),
    "x86_64-windows-msvc": ("win32", "X64", 0x8664, "VC-WIN64A"),
    "aarch64-windows-msvc": ("win32", "ARM64", 0xAA64, "VC-WIN64-ARM"),
}
ARCHIVE_SHA256 = "b28c91532a8b65a1f983b4c28b7488174e4a01008e29ce8e69bd789f28bc2a89"
CONFIGURE_OPTIONS = ["no-shared", "no-tests", "no-asm", "no-module"]
SCOPE = "OpenSSL CLI builder only; not SDK TLS, interoperability, native-provider or FIPS qualification"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def native_machine(windows):
    if not windows:
        return {"x86_64": 62, "aarch64": 183}.get(os.uname().machine, 0)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.IsWow64Process2.argtypes = [
        ctypes.c_void_p, ctypes.POINTER(ctypes.c_ushort), ctypes.POINTER(ctypes.c_ushort)
    ]
    kernel.IsWow64Process2.restype = ctypes.c_int
    process, native = ctypes.c_ushort(), ctypes.c_ushort()
    require(
        kernel.IsWow64Process2(kernel.GetCurrentProcess(), ctypes.byref(process), ctypes.byref(native)),
        "cannot establish native Windows machine: " + str(ctypes.get_last_error()),
    )
    return native.value


def image_machine(path, windows):
    with path.open("rb") as stream:
        header = stream.read(64)
        require(len(header) == 64, "truncated executable")
        if not windows:
            require(header[:6] == b"\x7fELF\x02\x01", "expected little-endian ELF64 CLI")
            return struct.unpack_from("<H", header, 18)[0]
        require(header[:2] == b"MZ", "expected PE CLI")
        offset = struct.unpack_from("<I", header, 60)[0]
        require(64 <= offset <= 1024 * 1024, "invalid PE header offset")
        stream.seek(offset)
        pe = stream.read(26)
        require(len(pe) == 26 and pe[:4] == b"PE\0\0", "invalid PE signature")
        require(struct.unpack_from("<H", pe, 24)[0] == 0x20B, "expected PE32+ CLI")
        return struct.unpack_from("<H", pe, 4)[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, choices=TARGETS)
    parser.add_argument("--after-build", action="store_true")
    args = parser.parse_args()
    system, runner_arch, machine, configure_target = TARGETS[args.target]
    require(sys.platform == system, "runner operating system differs from target")
    require(os.environ["RUNNER_ARCH"] == runner_arch, "runner architecture differs from target")
    require(native_machine(system == "win32") == machine, "native OS architecture differs from target")
    expected = os.environ["EXPECTED_SOURCE_SHA"]
    require(re.fullmatch("[0-9a-f]{40}", expected), "expected_sha must be a reviewed full commit")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    require(head == expected == os.environ["GITHUB_SHA"], "dispatch/checkout differs from reviewed commit")
    require(not subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT), "source checkout is dirty")
    for name, digest in HELPERS.items():
        text = (ROOT / ".github/scripts" / name).read_bytes().replace(b"\r\n", b"\n")
        require(hashlib.sha256(text).hexdigest() == digest, "reviewed helper changed: " + name)
    evidence = {
        "scope": SCOPE, "source_sha": head, "target": args.target,
        "runner_arch": runner_arch, "native_machine": machine, "helper_sha256_lf": HELPERS,
    }
    if not args.after_build:
        print("OPENSSL_REFERENCE_PREFLIGHT " + json.dumps(evidence, sort_keys=True), flush=True)
        return
    directory = ROOT / ".openssl-reference"
    executable = directory / "openssl-3.5.5/apps" / ("openssl.exe" if system == "win32" else "openssl")
    require(image_machine(executable, system == "win32") == machine, "CLI is not the actual native target")
    selected = shutil.which("openssl")
    require(
        selected is not None and os.path.samefile(selected, executable),
        f"PATH does not select the built CLI: selected={selected!r}, expected={str(executable)!r}",
    )
    require(pathlib.Path(os.environ["OPENSSL_CONF"]).resolve() == directory / "openssl.cnf", "wrong reference configuration")
    provenance = json.loads((directory / "provenance.json").read_text(encoding="utf-8"))
    require(provenance["target"] == args.target, "provenance target differs")
    require(provenance["source_sha256"] == ARCHIVE_SHA256, "reference source digest differs")
    require(provenance["configure_target"] == configure_target, "reference configure target differs")
    require(provenance["configure_options"] == CONFIGURE_OPTIONS, "reference configure options differ")
    with executable.open("rb") as stream:
        binary_digest = hashlib.file_digest(stream, "sha256").hexdigest()
    require(provenance["executable_sha256"] == binary_digest, "built CLI differs from helper provenance")
    version = subprocess.check_output([str(executable), "version"], text=True, timeout=15).strip()
    require(version.split()[:2] == ["OpenSSL", "3.5.5"] and version == provenance["version"], "actual CLI version differs")
    evidence.update({
        "execution": "direct native CLI", "cli_machine": machine, "version": version,
        "source_sha256": ARCHIVE_SHA256, "configure_options": CONFIGURE_OPTIONS,
        "executable_sha256": binary_digest,
    })
    print("OPENSSL_REFERENCE_EVIDENCE_OK " + json.dumps(evidence, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
