#!/usr/bin/env python3
"""Build a checksum-pinned CLI test peer; never link it into the SDK."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import tarfile
import urllib.request


VERSION = "3.5.5"
URL = "https://github.com/openssl/openssl/releases/download/openssl-3.5.5/openssl-3.5.5.tar.gz"
SHA256 = "b28c91532a8b65a1f983b4c28b7488174e4a01008e29ce8e69bd789f28bc2a89"
TARGETS = {
    "x86_64-linux-gnu": "linux-x86_64",
    "aarch64-linux-gnu": "linux-aarch64",
    "x86_64-windows-msvc": "VC-WIN64A",
    "aarch64-windows-msvc": "VC-WIN64-ARM",
}
CONFIG = "[req]\ndistinguished_name = test_identity\n[test_identity]\n"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def version(executable):
    result = subprocess.run(
        [str(executable), "version"], check=True, capture_output=True, text=True, timeout=15
    ).stdout.strip()
    if result.split()[:2] != ["OpenSSL", VERSION]:
        raise RuntimeError("expected pinned OpenSSL " + VERSION + ", found " + result)
    if "(Library:" in result and "(Library: OpenSSL " + VERSION + " " not in result:
        raise RuntimeError("OpenSSL reference library version differs: " + result)
    print(result, flush=True)
    return result


def require(command):
    found = shutil.which(command)
    if found is None:
        raise RuntimeError("missing reference-build prerequisite: " + command)
    return found


def windows_toolchain(path, target):
    if path is None:
        raise RuntimeError("Windows reference builds require prepare_openssl_windows.ps1 toolset selection")
    with path.open("rb") as source:
        data = source.read(128 * 1024 + 1)
    if len(data) > 128 * 1024:
        raise RuntimeError("Windows toolchain metadata exceeds its size budget")
    metadata = json.loads(data)
    architecture = {"aarch64-windows-msvc": "arm64", "x86_64-windows-msvc": "x64"}[target]
    if (metadata["policy"] != "installed-msvc-14.44-no-fallback"
            or not re.fullmatch(r"14\.44\.\d+(?:\.\d+)?", metadata["toolset_version"])
            or metadata["host_architecture"] != architecture
            or metadata["target_architecture"] != architecture):
        raise RuntimeError("Unexpected Windows reference toolset or architecture")
    toolset = pathlib.Path(metadata["toolset_directory"])
    if (toolset.name != metadata["toolset_version"]
            or not metadata["windows_sdk_version"] or not metadata["ucrt_version"]):
        raise RuntimeError("Windows toolset directory or SDK identity is inconsistent")
    binary_directory = toolset / "bin" / ("Host" + architecture) / architecture
    for key, command, prefix in (
        ("compiler", "cl", "19.44."),
        ("linker", "link", "14.44."),
        ("librarian", "lib", "14.44."),
        ("make", "nmake", "14.44."),
    ):
        tool = metadata[key]
        actual = pathlib.Path(require(command))
        if (not actual.samefile(binary_directory / (command + ".exe"))
                or not actual.samefile(tool["executable"])
                or not tool["file_version"].startswith(prefix)
                or digest(actual) != tool["sha256"]):
            raise RuntimeError("Selected Windows reference tool differs from verified metadata: " + command)
    for name, expected in (("CC", "cl"), ("LD", "link"), ("AR", "lib")):
        override = os.environ.get(name)
        if override and override not in (expected, expected + ".exe"):
            raise RuntimeError("External " + name + " override conflicts with the pinned reference toolchain")
    return metadata


def build(target, toolchain_path=None):
    windows = target.endswith("-windows-msvc")
    if windows != (os.name == "nt"):
        raise RuntimeError("reference must execute on its native CI operating system")
    toolchain = windows_toolchain(toolchain_path, target) if windows else None
    if not windows and toolchain_path is not None:
        raise RuntimeError("Windows toolchain metadata cannot be used for a non-Windows reference")
    perl = require("perl")
    make = require("nmake" if windows else "make")
    subprocess.run(
        [perl, "-MFindBin", "-MFile::Spec::Functions", "-MIPC::Cmd", "-e", "1"],
        check=True, timeout=15,
    )
    directory = pathlib.Path(".openssl-reference")
    directory.mkdir(exist_ok=False)
    scratch = directory / "scratch"
    scratch.mkdir()
    environment = os.environ.copy()
    for name in ("TMPDIR", "TEMP", "TMP"):
        environment[name] = str(scratch.resolve())
    archive = directory / ("openssl-" + VERSION + ".tar.gz")
    with urllib.request.urlopen(URL, timeout=60) as response, archive.open("wb") as output:
        total = 0
        while chunk := response.read(1024 * 1024):
            total += len(chunk)
            if total > 128 * 1024 * 1024:
                raise RuntimeError("OpenSSL reference archive exceeds download budget")
            output.write(chunk)
    if digest(archive) != SHA256:
        raise RuntimeError("OpenSSL reference archive SHA-256 mismatch")
    with tarfile.open(archive) as source:
        source.extractall(directory, filter="data")
    source = directory / ("openssl-" + VERSION)
    options = ["no-shared", "no-tests", "no-asm", "no-module"]
    subprocess.run(
        [perl, "Configure", TARGETS[target], *options,
         "--prefix=" + str((directory / "install").resolve())],
        cwd=source, env=environment, check=True, timeout=120,
    )
    command = [make, "/nologo", "build_sw"] if windows else [make, "-j2", "build_sw"]
    subprocess.run(command, cwd=source, env=environment, check=True, timeout=2400)
    executable = source / "apps" / ("openssl.exe" if windows else "openssl")
    actual = version(executable.resolve())
    if toolchain is not None and windows_toolchain(toolchain_path, target) != toolchain:
        raise RuntimeError("Windows reference toolchain metadata changed during the build")
    configuration = directory / "openssl.cnf"
    configuration.write_text(CONFIG, encoding="utf-8")
    provenance = {
        "purpose": "independent CLI test peer, not SDK linkage or FIPS qualification",
        "version": actual,
        "target": target,
        "source_url": URL,
        "source_sha256": SHA256,
        "configure_target": TARGETS[target],
        "configure_options": options,
        "executable_sha256": digest(executable),
    }
    if toolchain is not None:
        provenance["toolchain"] = toolchain
    (directory / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(provenance, indent=2), flush=True)
    with open(os.environ["GITHUB_PATH"], "a", encoding="utf-8") as output:
        output.write(str(executable.parent.resolve()) + "\n")
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
        output.write("OPENSSL_CONF=" + str(configuration.resolve()) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=TARGETS)
    parser.add_argument("--check-existing", type=pathlib.Path)
    parser.add_argument("--windows-toolchain", type=pathlib.Path)
    args = parser.parse_args()
    if args.check_existing is not None:
        version(args.check_existing)
    elif args.target is not None:
        build(args.target, args.windows_toolchain)
    else:
        parser.error("--target or --check-existing is required")


if __name__ == "__main__":
    main()
