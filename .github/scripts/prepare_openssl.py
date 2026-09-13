#!/usr/bin/env python3
"""Build a checksum-pinned CLI test peer; never link it into the SDK."""

import argparse
import hashlib
import json
import os
import pathlib
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


def build(target):
    windows = target.endswith("-windows-msvc")
    if windows != (os.name == "nt"):
        raise RuntimeError("reference must execute on its native CI operating system")
    perl = require("perl")
    make = require("nmake" if windows else "make")
    subprocess.run(
        [perl, "-MFindBin", "-MFile::Spec::Functions", "-MIPC::Cmd", "-e", "1"],
        check=True, timeout=15,
    )
    if windows:
        require("cl")
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
    args = parser.parse_args()
    if args.check_existing is not None:
        version(args.check_existing)
    elif args.target is not None:
        build(args.target)
    else:
        parser.error("--target or --check-existing is required")


if __name__ == "__main__":
    main()
