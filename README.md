# Azure Core HTTPX transport for Zig

**Unpublished source preparation, provisional version 0.1.0.** This optional
package implements Azure Core's HTTP transport interface using HTTPX. It does
not add HTTPX to Core, register a new package, bootstrap a package branch, or
complete issue #413. The intended package branch is `sdk/core_httpx`.

## Development dependencies

The manifest pins immutable commits and their actual Zig package hashes:

| Package | Commit | Status |
| --- | --- | --- |
| `azure_sdk_core` | `be32073994f37422f2f6b5e9255d208b1284de85` | Published Core 0.4.0 |
| `httpx` | `ed0e91f7a5d110151d9876bf2e172ead78729475` | Canonical operation API development input; not a qualified final release |

HTTPX comes from **`cataggar/httpx.zig`**. The development manifest contains no
local dependency paths. Its HTTPX pin must be replaced with the coordinator's
reviewed, qualified immutable release before publication.

## Integration

Import the `azure_sdk_core_httpx` build module. Its public API is:

* `HttpxTransport.init(allocator, io, Options) !HttpxTransport`
* `asTransport() core.http.HttpTransport` — a copyable borrowed descriptor
* `poolStats()` — canonical HTTPX pool observations
* `trailers(operation)` — optional borrowed canonical HTTPX response trailers,
  after EOF/finish and before operation deinit; rejects foreign operations
* `deinit()` — closes the pool and releases the transport
* `core` and `httpx` — the actual dependency modules, not duplicate ABI types

The build also exports `dependency.module("httpx")` and
`dependency.module("azure_sdk_core")`. A future optional TLS provider must import
this **same HTTPX module object**, or use `adapter.httpx` types. Do not compile a
second HTTPX root or recreate its provider/trust types. This package has no
dependency on SymCrypt or another native crypto library.

Given application-owned `allocator`, `io`, stable `client_config` and crypto
provider:

```zig
const adapter = @import("azure_sdk_core_httpx");
const core = adapter.core;

var transport = try adapter.HttpxTransport.init(allocator, io, .{
    .client = client_config,
    .operation = .{ .require_interruptible_dns = true },
});
defer transport.deinit();

const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto_provider.asProvider(),
);
var pipeline = core.http.HttpPipeline.init(runtime, &.{});
// Add Azure authentication, tracing, telemetry and retry policies as needed.
// Every returned HttpOperation must be deinitialized before transport.deinit().
```

### Configuration and policy ownership

`Options.client` accepts the canonical `httpx.ClientConfig` by value.
`Options.operation` accepts canonical `httpx.OpenOptions` defaults for each
dispatch. Routing, proxy/`no_proxy`, DNS resolver, HTTP version, connection pool,
timeouts, response limits and native cancellation options are forwarded.
Borrowed fields are not deep-copied.

Azure alone supplies the request URL, headers, body, authentication, redirects,
replays and retry counts. HTTPX retries, redirects, cookie storage/sending,
User-Agent and Accept-Encoding synthesis are disabled at both client and
operation levels, regardless of caller policy defaults. Request defaults that
could restore stripped credentials or alter signed bytes are **rejected**:
base URL, default headers, request compression, query/auth/range/custom-method
overrides and alternate body/Expect settings. Put explicit headers on the Core
request. Matching framing headers are validated then emitted once by HTTPX.
HTTP/1 Connection defaults are emitted once; HTTP/2 has no Connection header.

Response content decoding is explicitly transport-owned, matching Core's
standard backend, not inherited from HTTPX policy. `Options.decompression`
defaults to `.enabled`; choose `.disabled` for encoded bytes. No
Accept-Encoding is implicitly added. Core's owned `RequestHeaders` are
iterated without mutation. Responses retain the Core string map and an owned,
wire-ordered duplicate-header collection.

The adapter never resets `transport_started`; Core sets it at dispatch and
handles preflight cancellation, redirect validation, credential stripping and
replay. HTTPX receives one canonical `Client.open` call per Azure attempt.
Redirects remain subject to Core's HTTPS-only redirect rules.

### Streaming, limits and errors

Both buffered `send` and incremental `open` use canonical `Client.open`,
incremental writes, `waitForContinue`, `finishRequest(null)`, `read` and
`finish(.{})`. Upload sources are consumed synchronously during Core `open`.
Known lengths use `u64` framing, unknown lengths use chunked upload. A final
Expect response does not consume the upload source.

Bodies are never duplicated wholesale for streaming. The upload adapter uses a
16 KiB buffer, the response reader has 16 KiB storage, and HTTPX owns bounded
protocol/decoder buffers. `send` materializes its returned body once and moves
response metadata into the Core response.

`max_buffered_response` applies only to `send` (16 MiB by default).
`operation.response_limit` remains effective for streaming and buffered calls:
`.bytes = 0` permits an empty response only; `.unlimited` removes that limit;
`.inherit` uses HTTPX `client.max_response_size`, where zero means unlimited.
The default adapter client sets request/response size limits to zero. Supplying
a replacement `client` struct adopts that struct's canonical HTTPX defaults.

`operation.timeouts.request_ms` bounds the whole native operation, including
upload, response and drain. `timeout_ms` is a phase override, not a replacement
whole-operation deadline. Core's nonzero request budget can only shorten a
configured native budget; an explicit zero Core budget expires immediately.
These are per-dispatch budgets; Core owns the logical retry/redirect budget.
Core's request context is tracing context and is left unchanged. The ed0 public
OpenOptions API has no parent IoContext parameter; none is fabricated or
silently discarded here.

Concrete HTTPX cancellation, timeout, framing and size errors are mapped to
Core errors. Other errors, including `OutOfMemory`, propagate unchanged.
`HttpOperation.bodyError()` exposes the first concrete read failure hidden by
`std.Io.Reader`'s `ReadFailed`; a subsequent `finish` preserves that failure.
Successful finish drains framing/trailers before pool reuse. Abort/cancel,
malformed framing and partial construction errors release or discard resources.

### Lifetime and concurrency contract

The transport is a **caller-serialized, move-only owner**. Keep its address
stable after `asTransport`. Do not mutate internal fields, move it, or deinit it
while any descriptor or operation uses it. Distinct operations may stay open,
but all owner methods and allocator access must be serialized.

The allocator, `std.Io`, configuration strings, resolver, backend and any
provider/trust owners must outlive transport deinit. In particular, TLS owners
must stay stable through **idle pooled TLS sessions**, not just active calls.
Operations own request metadata after open returns; body bytes/readers are
borrowed only during open. The cancellation tokens remain borrowed until the
operation is deinitialized.
When Core cancellation is enabled, the supplied `std.Io` must support event
waits/signals across the owner and monitor threads.

Only cancellation **tokens** may be signalled concurrently. The Core token is
bridged to one canonical HTTPX token with a joined, per-operation monitor
thread (1 ms observation interval). A separately configured HTTPX token is
also honored. The monitor only accesses stable tokens, never operation
handles; no cancellation races a move or deinit. Core HttpOperation methods,
including cancel and deinit, are not concurrent methods.

Cancellation is checked around upload-source reads, but an arbitrary blocking
borrowed reader cannot be interrupted by this adapter. Native HTTPX socket
operations observe cancellation/deadlines according to the upstream contract.
Strict hostname DNS requires a configured pure-Zig resolver on **every OS**.
Literals and Unix routes are exempt; HTTPX checks the final proxy/`no_proxy`
route. The default operation enables strict DNS; when supplying replacement
`operation` options, set `require_interruptible_dns = true` explicitly.
Non-strict detached native DNS-worker cancellation is **not** advertised.

## Platforms and validation

Native HTTP/1.1 and HTTP/2 are supported through canonical HTTPX. Public HTTP/3
is rejected. Unix plus HTTP/2 or TLS is explicitly rejected, never rerouted or
downgraded. WASI remains on Core's existing host backend; this optional package
intentionally refuses a WASI build.

Run only offline tests:

```sh
zig fmt --check build.zig build.zig.zon root.zig transport.zig test_backend.zig tests.zig
zig build test --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
```

The package imports the **published Core conformance module**, including its
scripted server, rather than copying the conformance implementation. Coverage
includes raw transport and pipeline contracts, 32 MiB logical streaming under
a 2 MiB allocation budget, allocation failures for buffered/finish/abort/
redirect/retry, cancellation-bridge allocation cleanup, duplicate headers,
framing, decompression, explicit limits, deadlines, method mapping, lifetime,
trailers and H1/H2 loopback reuse/abort.

Synthetic wire mocks exercise credential stripping and attempt counts, **not
trusted HTTPS**. The shared factory deliberately does not claim trusted-HTTPS
redirect capability or the stronger per-phase interruption evidence matrix.
Local cancellation/timeout integration tests do not imply cancellation of
arbitrary upload readers or native DNS workers.

CI retains the three fixed `package-test (<os>)` contexts. There are no default
live Azure, credential, public-CA or native-provider checks. Windows currently
uses HTTPX's system Winsock ABI; no C/crypto library dependency is added.

Source-preparation validation with Zig 0.16.0: 21 adapter tests passed on
aarch64 Linux, including the imported shared contracts. Test executables also
cross-compiled for x86_64 Windows GNU and aarch64 macOS; they were not run there.
The WASI build was checked to reject this adapter with host-backend guidance.

## Publication gates still open

* Final upstream provider/trust configuration API, immutable qualified release
  and final package hash.
* Parent-controlled native selected-provider and public-CA Azure HTTPS matrix
  with verification enabled. `verify_ssl = false` is rejected here.
* Native Windows/macOS runtime results; cross-compilation alone is not runtime
  qualification.
* Reviewed registry/history/catalog metadata, sealed expected-absent
  new-package bootstrap, ordinary implementation review and sequential merge,
  then tags/releases.

No production, TLS-provider, native-crypto or FIPS qualification is claimed.
