# azure_sdk_core

Core HTTP, authentication, error, paging, long-running-operation, URL, crypto,
and utility infrastructure for the Azure SDK for Zig.

The canonical package/module name is `azure_sdk_core`, released from
`sdk/core`. Identity remains part of this package. The current breaking
provider/streaming release line is `0.3.0`.

## Core surface

| API | Purpose |
| --- | --- |
| `http.StdHttpTransport` | Streaming HTTP via `std.http.Client` with gzip, deflate, and zstd response decoding |
| `http.MockTransport` | Canned buffered and streaming responses for tests |
| `http.SequenceMockTransport` | Ordered responses for retry tests |
| `http.HttpRuntime` | Selected HTTP transport and SDK crypto provider |
| `http.HttpPipeline` | Policies followed by one runtime |
| `http.TelemetryPolicy` | Adds `User-Agent` |
| `http.LoggingPolicy` | Logs requests through `std.log` |
| `http.RetryPolicy` | Bounded exponential backoff, jitter, and `Retry-After` |
| `http.BearerTokenAuthPolicy` | Bearer authentication with token caching |
| `http.RequestIdPolicy` | Adds an `x-ms-client-request-id` UUID |
| `crypto.CryptoProvider` | Pluggable random, MD5, SHA-256, and HMAC-SHA256 operations |
| `crypto.StdCryptoProvider` | Pure-Zig provider backed by `std.Io` and `std.crypto` |
| `credentials.CachedTokenCredential` | In-memory token cache with expiry |
| `base64` | Provider-backed HMAC-SHA256, SHA-256, and integrity-only MD5 helpers |
| `url` | URL parsing and RFC 3986 percent encoding |
| `errors` | Azure error-envelope parsing |
| `lro` | Long-running-operation polling |
| `pager` | Generic `PipelinePager` |
| `tracing` | Span and attribute plumbing |
| `perf` | Wall-clock and allocation benchmark harness |

`HttpTransport.open` and `HttpPipeline.open` return a heap-backed,
single-owner `HttpOperation`. Consume its reader and call `finish` to drain for
connection reuse, or `abort`/`cancel` to close early. Always call `deinit`;
it aborts an active operation. Streaming request preparation runs once and
does not replay a consumed reader.

HTTP construction has one explicit dependency path:

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto.asProvider(),
);
var pipeline = core.http.HttpPipeline.init(runtime, policies);
```

Transport and crypto descriptors, and therefore `HttpRuntime`, copy by value
while borrowing their backend contexts. Keep `transport` and `crypto` alive
for every pipeline, credential call, client, and open operation that uses
them. `StdHttpTransport` remains caller-serialized. Custom crypto provider
contexts must be concurrent-safe or caller-serialized. Incremental SHA-256
operations own stable allocator-backed state and must be deinitialized once.

## Adapter conformance

Core exports two test-only build modules in addition to the production
`azure_sdk_core` module:

- `azure_sdk_core_http_conformance`
- `azure_sdk_core_crypto_conformance`

Optional adapter packages import these modules from their pinned Core
dependency and invoke the public factory-based runners. They are deliberately
not imported by `root.zig`, and Core has no dependency on optional HTTP or
crypto adapters.

```zig
const core_dep = b.dependency("azure_sdk_core", .{
    .target = target,
    .optimize = optimize,
});
const http_contracts = core_dep.module("azure_sdk_core_http_conformance");
const crypto_contracts = core_dep.module("azure_sdk_core_crypto_conformance");
```

HTTP factories publish explicit capabilities for streaming, response-header
ordering, framing validation, response limits, cancellation grade,
decompression ownership, lifecycle observation, and bounded-memory
logical-large uploads. Crypto factories publish incremental-allocation and
concurrency guarantees. A skipped capability is not evidence of runtime
support.

Core CI runs the raw transport suite against `StdHttpTransport` and
`MockTransport`, the pipeline and allocation-failure suites against reusable
fakes, and the crypto suite against `StdCryptoProvider`. The standard
transport is caller-serialized; the standard SDK crypto provider supports
concurrent hash/HMAC calls. CI also archives exactly the manifest `.paths`,
fetches that archive into a separate consumer package, and resolves all three
modules through `b.dependency`; omitted package files therefore fail the
package test.

The WASI HTTP implementation separates target-neutral request adaptation from
the `wasi:http@0.2.6` host externs. Native tests use an injectable fake host for
the target-neutral seam. `zig build wasi-check` only proves that the
`wasm32-wasi` guest code builds; it does **not** claim a runtime WASI engine,
network, TLS, or trust-provider test.

## Identity

Identity remains part of `azure_sdk_core` and is available through
`core.identity`.

| Credential | Authentication source |
| --- | --- |
| `ClientSecretCredential` | OAuth 2.0 client credentials |
| `EnvironmentCredential` | `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET` |
| `ManagedIdentityCredential` | Azure Instance Metadata Service |
| `AzureCliCredential` | `az account get-access-token` |
| `WorkloadIdentityCredential` | Kubernetes OIDC federation |
| `ChainedTokenCredential` | First successful credential |
| `DefaultAzureCredential` | A chain selected by `AZURE_TOKEN_CREDENTIALS` |

### `AZURE_TOKEN_CREDENTIALS`

`DefaultAzureCredential` builds its chain from `AZURE_TOKEN_CREDENTIALS`.

| Value | Chain |
| --- | --- |
| unset | `EnvironmentCredential`, `WorkloadIdentityCredential`, `AzureCliCredential`, `AzureDeveloperCliCredential` |
| `prod` | `EnvironmentCredential`, `WorkloadIdentityCredential`, `ManagedIdentityCredential` |
| `dev` | `AzureCliCredential`, `AzureDeveloperCliCredential` |
| a credential name | just that credential |

Values are matched ignoring ASCII case and surrounding whitespace; any other
value fails with `error.UnknownTokenCredentialSelection`. A selected credential
whose configuration is absent is left out of the chain, and a selection that
leaves the chain empty fails with `error.NoCredentialConfigured`.

`ManagedIdentityCredential` probes the Instance Metadata Service at
`169.254.169.254`, which is unroutable outside Azure and stalls every token
request until the connection times out. It is therefore never in the default
chain. Set `AZURE_TOKEN_CREDENTIALS=prod` on deployed services, or name the
credential directly, to use it.

## Benchmarking

`core.perf` measures a closure against the monotonic clock and counts the
allocations it makes.

```zig
fn encodeOnce() !void { ... }

const result = core.perf.benchmark(io, "encode", 10_000, encodeOnce);
core.perf.printResult(result);
```

`benchmark` needs a `std.Io` because it reads `std.Io.Timestamp.now(io, .awake)`,
the monotonic clock that keeps running while a task sleeps. Pass the same `Io`
the code under test uses; `std.testing.io` works in tests.

To attribute allocations, run through `benchmarkAllocating`, which wraps the
allocator you hand it and reports `allocationsPerOp` and `bytesPerOp` alongside
`avgNs`:

```zig
fn encodeWith(allocator: std.mem.Allocator) !void { ... }

const result = core.perf.benchmarkAllocating(io, "encode", 10_000, gpa, encodeWith);
```

`CountingAllocator` is also usable on its own to assert an operation stays
allocation-free. It counts only events that obtain new memory: a failed
allocation, an in-place `resize`, and a `remap` that succeeds without moving
are all excluded, so the count reflects real allocation churn rather than
allocator bookkeeping.

`avgNs` and `opsPerSecond` are reciprocals — both derive from the summed
per-iteration laps. `total_ns` is wall-clock for the whole run and also
includes the harness's own timer reads, so it is always larger. Each lap costs
two clock reads, which puts a floor of roughly one clock read on `min_ns`;
give each iteration enough work to dominate it.

## Related packages

- [AMQP](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/amqp)
- [Event Hubs](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/eventhubs)
- [Service Bus](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/servicebus)
- [Testing](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/testing)

`tracing` and `perf` are namespaces of this package, not separate packages.

## Development

```bash
zig build test --summary all
zig build package-consumer-check --summary all
zig build wasi-check --summary all
```

The package depends on `serde`. See the
[package model](https://github.com/cataggar/azure-sdk-for-zig/blob/main/doc/package-branch-model.md).
