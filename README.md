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
zig fmt --check build.zig build.zig.zon root.zig transport.zig test_backend.zig interruption_fixture.zig tests.zig
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
trusted HTTPS**. The shared factory does not claim trusted-HTTPS redirect
capability. Interruption evidence is separately obtained from real loopback
connections, not these wire mocks.

CI retains the three fixed `package-test (<os>)` contexts. There are no default
live Azure, credential, public-CA or native-provider checks. Windows currently
uses HTTPX's system Winsock ABI; no C/crypto library dependency is added.

The earlier reviewed source checkpoint had 21 passing tests on aarch64 Linux
and compile-only checks for x86_64 Windows GNU and aarch64 macOS. The WASI build
was checked to reject this adapter with host-backend guidance.

### Per-phase interruption evidence

`interruption_fixture.zig` supplies the factory's `interruptionFixtureFn` and
runs through published Core `runInterruptionContracts`. It advertises these
token/deadline pairs, orthogonal to the existing cooperative-upload grade:

| Phase | Token | Deadline | Actual blocked path and synchronization |
| --- | --- | --- | --- |
| `connect` | Yes | Yes | A loopback SOCKS5 peer receives CONNECT after method negotiation and withholds the success reply. This is native connection-establishment negotiation, not raw TCP SYN or DNS interruption. |
| `upload_write` | Yes | Yes | H2 upload exhausts flow-control credit. The peer observes a PING ACK processed by the native upload pump, without granting more credit. |
| `response_headers` | Yes | Yes | After request END_STREAM, the peer observes a PING ACK from native header reception and never supplies a response head. |
| `response_body` | Yes | Yes | An incomplete H2 body produces one byte of WINDOW_UPDATE credit and a PING ACK during a two-byte read; no END_STREAM is supplied. |
| `finish_drain` | Yes | Yes | Native finish/drain produces the same credit and PING ACK, without any application body read or peer completion. |
| `upload_read` | No | No | The borrowed reader API cannot preempt an arbitrary blocking caller callback. No detached worker or synthetic preemption is used. |

The peer's acknowledged protocol traffic proves entry before the token is
signalled or the whole-operation deadline expires. The H2 checks do not rely on
an owner-thread “about to read” flag, socket-buffer-size guesses or fixed sleeps.
Token scenarios disable native deadlines; deadline scenarios use a 500 ms
whole-operation budget with all independent phase/drain deadlines disabled.
For deadline latency, the timestamp immediately before Core dispatch plus
500 ms is an **earlier bound** on native expiry: measured latency therefore
conservatively overestimates, rather than understates, time since actual expiry.
The shared runner's 1000 ms acceptance budget is unchanged.

The controller is a scoped watchdog with bounded event waits. Every exit
shuts down the peer if needed and joins both threads. A watchdog failure is an
error, never qualifying evidence. The success path never releases the withheld
bytes: the peer must observe the interrupted client's EOF/reset exactly once.
Both owner completion and peer closure observation must meet the same 1000 ms
deadline, and reported latency includes the later of those observations.
Evidence reports that observed close count, `transport_started`, the concrete
outcome and live-operation/leased-connection counts collected after owner
cleanup. A negative watchdog test withholds the phase probe and verifies that
both threads stop/join without producing any evidence.

Run the evidence cases independently:

```sh
zig build test -Dtest-filter=interruption -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
```

The evidence test prints measured per-pair results. These fixtures establish
the listed H2/SOCKS5 paths only, not every protocol or platform combination.
H1 backpressure, direct stalled TCP connect, DNS, arbitrary upload-reader
preemption, TLS handshakes and the native Windows/macOS interruption matrix
remain unproved here. Public-CA/trusted-HTTPS qualification remains gated.

This independent conformance checkpoint passed 24/24 tests on aarch64 Linux
with Zig 0.16.0. Three additional targeted interruption runs each passed 3/3,
including the negative watchdog case. Across those repeats, token observations
were 11 ms and conservative deadline observations were 1–2 ms; every pair
reported one close, zero live operations and zero leased connections.
Windows GNU x86_64 and macOS aarch64 cross-compilation also passed, without
running or qualifying their native interruption matrices. Production adapter
source and immutable dependency pins are unchanged from the earlier checkpoint.

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
