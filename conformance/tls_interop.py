#!/usr/bin/env python3
"""Run independent OpenSSL servers with disposable three-certificate trust paths."""

import datetime
import os
import pathlib
import socket
import subprocess
import sys
import time


def port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def wait_ready(server, address):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if server.poll() is not None:
            raise RuntimeError("OpenSSL server exited before readiness")
        with socket.socket() as client:
            client.settimeout(0.1)
            if client.connect_ex(("127.0.0.1", address)) == 0:
                return
        time.sleep(0.05)
    raise TimeoutError("OpenSSL server did not become ready")


def authority(directory, name, parent=None):
    key = directory / (name + "-key.pem")
    certificate = directory / (name + "-cert.pem")
    der = directory / (name + "-cert.der")
    issuer = [] if parent is None else ["-CA", str(parent[1]), "-CAkey", str(parent[0])]
    subprocess.run([
        "openssl", "req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
        "-subj", "/CN=" + name, *issuer,
        "-addext", "basicConstraints=critical,CA:TRUE,pathlen:" + ("1" if parent is None else "0"),
        "-addext", "keyUsage=critical,keyCertSign,cRLSign",
        "-not_before", "20200101000000Z", "-not_after", "20350101000000Z",
        "-keyout", str(key), "-out", str(certificate),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=60)
    subprocess.run(["openssl", "x509", "-in", str(certificate), "-outform", "DER", "-out", str(der)], check=True, timeout=15)
    return key, certificate, der


def run_fixture(command, directory, algorithm, validity, root, intermediate, unrelated):
    name = algorithm + "-" + validity
    key = directory / (name + "-key.pem")
    certificate = directory / (name + "-cert.pem")
    der = directory / (name + "-cert.der")
    now = datetime.datetime.now(datetime.timezone.utc)
    intervals = {"valid": (-1, 24), "expired": (-48, -24), "future": (24, 48)}
    before, after = intervals[validity]
    timestamp = lambda hours: (now + datetime.timedelta(hours=hours)).strftime("%Y%m%d%H%M%SZ")
    key_options = ["-newkey", "rsa:2048"] if algorithm == "rsa" else [
        "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:" + {"p256": "P-256", "p384": "P-384"}[algorithm]
    ]
    servers = []
    logs = []
    try:
        subprocess.run([
            "openssl", "req", "-new", "-x509", *key_options, "-nodes",
            "-sha384" if algorithm == "p384" else "-sha256",
            "-CA", str(intermediate[1]), "-CAkey", str(intermediate[0]),
            "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
            "-addext", "basicConstraints=critical,CA:FALSE",
            "-addext", "keyUsage=critical,digitalSignature",
            "-addext", "extendedKeyUsage=serverAuth",
            "-not_before", timestamp(before), "-not_after", timestamp(after),
            "-keyout", str(key), "-out", str(certificate),
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=60)
        subprocess.run(["openssl", "x509", "-in", str(certificate), "-outform", "DER", "-out", str(der)], check=True, timeout=15)
        ports = []
        for version in ("tls1_2", "tls1_3"):
            address = port()
            log = (directory / (name + "-" + version + ".log")).open("wb")
            logs.append(log)
            signature_options = [] if algorithm == "rsa" else [
                "-sigalgs", "ecdsa_secp256r1_sha256" if algorithm == "p256" else "ecdsa_secp384r1_sha384"
            ]
            server = subprocess.Popen([
                "openssl", "s_server", "-accept", "127.0.0.1:" + str(address),
                "-" + version, "-www", "-no_cache", "-quiet",
                *signature_options,
                "-cert", str(certificate), "-key", str(key), "-cert_chain", str(intermediate[1]),
            ], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
            servers.append(server)
            wait_ready(server, address)
            ports.append(address)
        print("fixture:", name, flush=True)
        subprocess.run([
            *command, str(der.resolve()), *(str(value) for value in ports), validity,
            str(root[2].resolve()), str(unrelated[2].resolve()),
        ], check=True, timeout=180)
    finally:
        for server in servers:
            if server.poll() is None:
                server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
        for log in logs:
            log.close()
        for path in (key, certificate, der):
            path.unlink(missing_ok=True)


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: tls_interop.py [verified-native-launcher arguments ...] executable")
    directory = pathlib.Path(".agent-scratch/tls-interop") / (str(os.getpid()) + "-" + str(time.time_ns()))
    directory.mkdir(mode=0o700, parents=True, exist_ok=False)
    subprocess.run(["openssl", "version"], check=True, timeout=10)
    try:
        root = authority(directory, "Root")
        intermediate = authority(directory, "Intermediate", root)
        unrelated = authority(directory, "Unrelated")
        for algorithm in ("p256", "p384", "rsa"):
            run_fixture(sys.argv[1:], directory, algorithm, "valid", root, intermediate, unrelated)
        for validity in ("expired", "future"):
            run_fixture(sys.argv[1:], directory, "rsa", validity, root, intermediate, unrelated)
    finally:
        for path in directory.iterdir():
            if path.suffix in (".pem", ".der"):
                path.unlink()


if __name__ == "__main__":
    main()
