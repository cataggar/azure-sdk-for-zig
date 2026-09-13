# App Configuration reference OTLP JSON / Collector fixture

This tooling fixture covers part of [#144](https://github.com/cataggar/azure-sdk-for-zig/issues/144):
an **actual released service operation**, through Core's mock HTTP transport,
the reference JSON writer, and (only when explicitly requested) an official
OpenTelemetry Collector. It does not implement a production OTLP/HTTP exporter
([deferred #456](https://github.com/cataggar/azure-sdk-for-zig/issues/456)).
The separate Storage Blobs example is not part of this fixture.

## Offline by default

From the repository root:

```bash
zig build otlp-collector-fixture-test --summary all
cd eng/fixtures/otlp_collector_interop
zig build
zig build run
```

`run` writes one unmodified reference OTLP JSON request to stdout and the mock
operation / captured `traceparent` to stderr. No sockets, Azure credentials,
curl, Collector, containers, or cloud backend are involved. As with other Zig
consumers, first-time dependency resolution needs the pinned packages available
in Zig's package cache; after restoration, execution and tests are offline.
The root `test` step includes only these offline tests, never `interop.sh`.
The historical Core 0.1.2 consumer remains separate and unchanged.

The manifest pins App Configuration **0.3.1** at
`7efda6d0d658ab29cad8cd1c811be4608df8ee9a` and Core **0.4.1** at
`2c95f65be96b5ef48a50671de33e9e0926c624cb`, with their released package hashes.
The build asserts one canonical Core module identity with the service client.
No branch source or local dependency override is used.

`fixture.zig` constructs `ConfigurationClient` with an instrumented pipeline,
calls `getSetting`, checks the actual mock URL/method/result and captured W3C
headers, then calls `forceFlush` and `shutdown`. Provider, exporter, writer,
scratch storage, transport, crypto backend, clock and borrowed configuration
all outlive the operation. The default parent, scope name/version and Azure
namespace are explicit. A fixture-only clock/random-byte override makes the
single span reproducible; **never use these deterministic IDs as production
randomness**.

Assertions cover one client span, wire trace/span IDs, parent, tracestate,
sampled flag, nanosecond times, `service.name`, scope, `GET`, numeric HTTP status
200 and server port 8443, safe host and namespace. Private key/label, response
value and URL/query are absent. Provider counters prove no drops or export/
propagation failures. Negative tests reject missing/changed/duplicate Collector
output and nonzero rejected spans, warning messages or invalid protocol JSON.
These offline verifier tests are **not themselves interoperability evidence**.

## Explicit real Collector validation (Linux only)

Prerequisites: Zig 0.16.0, Bash, GNU `timeout`, standard Linux utilities and readable
`/proc/<child>/fd` and `/proc/<child>/net/tcp`. Supply an **absolute path** to the
official core-distribution `otelcol` executable from release archive **v0.120.0**.
That official archive **reports binary version 0.120.1**, matching the pinned
distribution manifest; the script explicitly checks that reported version.

```bash
bash eng/fixtures/otlp_collector_interop/interop.sh /absolute/path/to/otelcol
# Preserve the run's local request, captured header, response, log and output:
bash eng/fixtures/otlp_collector_interop/interop.sh /absolute/path/to/otelcol --keep-output
```

The script never installs tools. A missing optional tool fails this explicit
command with setup guidance, without changing ordinary builds or CI.
It starts its own attached Collector child with the checked-in configuration,
binds **127.0.0.1 on an OS-assigned port**, and disables Collector self-metrics.
No gRPC receiver, external exporter, extensions or cloud destinations are
enabled. The file exporter writes only to the exclusive ignored
`.interop/run-<pid>-<random>` directory.

Before any HTTP traffic, the script identifies a loopback listening socket
owned by the exact child PID, then checks receiver responsiveness. Failure to
acquire/identify that socket aborts without probing unrelated local services.
The separately built pure-Zig `collector_http.zig` tool accepts only a port on
fixed loopback, disables TLS, ignores proxy environment and does not follow
redirects. Its explicit `post` command sends the unchanged `request.json` bytes
as `application/json`. It is **test tooling**, not a hidden SDK exporter, and is
not part of the default executable. curl is not needed.
No payload rewriting or massaging occurs. The runner requires HTTP 200, parses
the protocol response (no rejected spans or warning message), shuts down the
child, and verifies the Collector's JSON file against the same captured wire
header and complete expected span semantics. HTTP success alone is insufficient.
The Collector can omit protobuf-default zero fields when reserializing; the
verifier compares typed semantics, not JSON property order or byte equality.

A local Linux arm64 validation of the Core 0.4.1 / App Configuration 0.3.1 pair
with the checksum-verified archive returned
HTTP 405 for readiness, HTTP 200 for the unchanged request and
`{"partialSuccess":{}}`. Its file output contained exactly the child span
`1112131415161718` in trace `0af7651916cd43dd8448eb211c80319c`, matching the
mock service's captured
`00-0af7651916cd43dd8448eb211c80319c-1112131415161718-01`.
All resource/scope/parent/HTTP assertions passed, and the Collector logged
`Shutdown complete.` This is real Collector evidence, separate from the
offline verifier tests; subsequent runs should independently reproduce it.

Startup, HTTP calls, output waits, shutdown and file sizes are bounded. Only the
owned child PID is signalled/reaped. Exact run files are removed unless
`--keep-output` was requested; no user-provided output directory is overwritten.
Linux `/proc` listener ownership checks deliberately make this opt-in harness
Linux-only; the offline Zig fixture does not have that restriction.

### Reproducible optional tool setup

Only perform setup if the explicit interop command fails because the optional
Collector is missing. The following uses the GitHub CLI (`gh`), installs no
system service and uses a new
ignored directory; `mkdir` deliberately fails rather than overwriting a prior
tool installation. Run from the repository root, choose your Linux architecture:

```bash
cd eng/fixtures/otlp_collector_interop
mkdir -p .interop
mkdir .interop/otelcol-0.120.0
cd .interop/otelcol-0.120.0
arch=arm64 # use amd64 on x86-64
gh release download v0.120.0 --repo open-telemetry/opentelemetry-collector-releases \
  --pattern "otelcol_0.120.0_linux_${arch}.tar.gz" --dir .
case "$arch" in
  arm64) checksum=e263709687345384de47f0c7ba7f58fd1cb8d2f99d56a07cdf6ab518b0d70949 ;;
  amd64) checksum=542120312dd55a68239aef9e28a8516ff5024e92c9b58679511c0adcf4511694 ;;
  *) exit 1 ;;
esac
printf '%s  %s\n' "$checksum" "otelcol_0.120.0_linux_${arch}.tar.gz" | sha256sum --check -
tar -xzf "otelcol_0.120.0_linux_${arch}.tar.gz" otelcol
./otelcol --version # otelcol version 0.120.1
# Pass "$(pwd)/otelcol" to interop.sh from the repository root.
```

Archive hashes are from the official
[v0.120.0 release checksums](https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.120.0/opentelemetry-collector-releases_otelcol_checksums.txt).
The pinned configuration was selected from the official
[distribution manifest](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/v0.120.0/distributions/otelcol/manifest.yaml),
[OTLP receiver HTTP/JSON docs](https://github.com/open-telemetry/opentelemetry-collector/blob/v0.120.0/receiver/otlpreceiver/README.md),
[file exporter JSON/flush docs](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.120.1/exporter/fileexporter/README.md)
and [self-telemetry configuration](https://github.com/open-telemetry/opentelemetry-collector/blob/v0.120.0/service/telemetry/config.go).
File export is version-sensitive; a different Collector version is intentionally
not silently accepted.

This proves the reference writer's local protocol interoperability, not
production networking, retries, authentication, batching/delivery reliability,
per-attempt spans (#457), full stream-lifetime spans (#458), or per-call service
client context (#465). It does not by itself close the original issue.
