# Azure Core HTTPX transport for Zig

**Unpublished source preparation, provisional version 0.1.0.** This optional
package implements Azure Core's HTTP transport interface using HTTPX. It does
not add HTTPX to Core or complete issue #413. The package branch is
`sdk/core_httpx`; the coordinator has completed registration and sealed
bootstrap. The adapter implementation remains draft and unreleased.

## Development dependencies

The combined source checkpoint uses these immutable commits and actual Zig
package hashes:

| Package | Commit | Status |
| --- | --- | --- |
| `azure_sdk_core` | `2c95f65be96b5ef48a50671de33e9e0926c624cb` | Published Core 0.4.1 |
| `httpx` | `b2c6814c2a8a2b6b861314b259434a43b1f08f16` | Composed ABI 2, Windows policy and server-I/O development input; not a release |

HTTPX comes from **`cataggar/httpx.zig`**. The portable development manifest has
no local dependency paths. Earlier isolated qualification used a clearly
marked, **unpublishable** local override for exact candidate
`ff720540b759dbf28c15eea385b2a6598e04f201`. Its computed source hash is
`httpx-0.1.9-8qj2egVUMQCgd4IR8e6ja3QqjWj_R5IzqG21IB8wNMBS`.
This candidate is not a released/final HTTPX dependency. Neither its local path
nor an invented release pin may be published. The coordinator must supply the
reviewed, qualified immutable release URL and hash. Core 0.4.1 is released.
The combined corrected-input qualification below uses normal immutable URLs
and independently verified hashes in a separate development-selector commit.
This checkpoint selects the composed ABI 2, Windows profile and context-aware
server-I/O input with hash
`httpx-0.2.0-8qj2eonLMwDuDDJxDVzoax9VY68Lb0YjT_AtwZBAbqwV`, independently
confirmed by normal immutable URL resolution. The public probe and system-trust
example explicitly enable Windows-only identifier permissions as documented
below; library defaults remain unchanged.
The HTTPX pin remains a development input, not an approved publication pin.

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

Default validation is entirely offline:

```sh
zig fmt --check build.zig build.zig.zon root.zig transport.zig test_backend.zig interruption_fixture.zig tests.zig tls_qualification.zig tls_fixture_data.zig https_fixture.zig public_https.zig
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
trusted HTTPS**. The default plain-HTTP factory does not claim trusted-HTTPS
redirect capability. The opt-in trusted factory below serves actual TLS and
passes both formerly blocked shared gates with the exact corrected inputs
documented below. Interruption evidence is separately obtained from real
H2/SOCKS5 loopback connections, not these wire mocks.

CI retains the three fixed `package-test (<os>)` contexts. Every context
explicitly runs `zig build test -Dpaired-tls=true` in Debug and ReleaseSafe,
including the shared/plain-HTTP suite, the 60-case standard TLS matrix, and the
new trusted-HTTPS contracts. There is no legacy-only fallback or success
override. The current composed development pin supports this mode, but all three
contexts must pass on this combined source before platform acceptance. A
qualified HTTPX release pin is still required before publication. The shared
gate blockers below remain real
failures on the historical inputs, not on the corrected-input qualification.

The workflow executes both optimization modes even if the first fails, then
returns a failing status if either failed. Local validation executed the exact
workflow shell block with transient immutable `95b916c` input: both modes ran
all 36 tests, with the same four documented failures and final exit status 1.
The untouched `ed0` pin instead failed paired-mode setup because its canonical
test certificate module is absent; it did not silently pass the 24-test suite.
The portable CI change restores that original manifest and changes no pins.

The public Azure probe remains a separate manual build step. CI adds no live
Azure, credential, public-CA or native-provider checks. Windows currently uses
HTTPX's system Winsock ABI; no C/crypto library dependency is added.

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
remain unproved here. These interruption observations do not qualify TLS
handshake interruption or any additional native platform.

This independent conformance checkpoint passed 24/24 tests on aarch64 Linux
with Zig 0.16.0. Three additional targeted interruption runs each passed 3/3,
including the negative watchdog case. Across those repeats, token observations
were 11 ms and conservative deadline observations were 1–2 ms; every pair
reported one close, zero live operations and zero leased connections.
Windows GNU x86_64 and macOS aarch64 cross-compilation also passed, without
running or qualifying their native interruption matrices. At that historical
checkpoint (`b34e8d4c`), production adapter source and dependency pins were
unchanged from `904f1b65`.

## Paired standard TLS qualification

The isolated `ff720540` candidate supplies the actual high-level
`tls_crypto_provider`, `tls_certificate_crypto`, `server_authentication`, and
`tls_trust_limits` fields. The adapter forwards them unchanged. It now rejects
the explicit dangerous `server_authentication` variant as well as
`verify_ssl = false`: the new authentication field overrides the legacy flag
upstream, so checking only that flag would not preserve the adapter's contract.
The guard also builds with the older development API.

Example for the **paired API**, with application-owned `allocator` and `io`:

```zig
const httpx = adapter.httpx;
const allow_windows_md5_identifiers = @import("builtin").os.tag == .windows;
var standard = httpx.StandardCryptoProvider.initWithOptions(io, allocator, .{
    .allow_md5_identifier_hash = allow_windows_md5_identifiers,
});
var roots = try httpx.tls.TrustContext.init(allocator, io, .{ .source = .system });
defer roots.deinit();
var certificate_crypto = httpx.CryptoCertificateVerifier.init(standard.provider());
var binding = try roots.bind(&certificate_crypto, .{
    .allow_sha1_identifiers = true,
    .allow_md5_identifiers = allow_windows_md5_identifiers,
});
var transport = try adapter.HttpxTransport.init(allocator, io, .{
    .client = .{
        .tls_crypto_provider = standard.provider(),
        .tls_certificate_crypto = &certificate_crypto,
        .server_authentication = .{ .verify = .{ .provider = binding.provider() } },
        .tls_trust_limits = .{},
    },
});
defer transport.deinit();
```

Configure a pure-Zig resolver before using a hostname with strict DNS.
Keep **all** owners above stable until the transport and its pooled sessions
are destroyed. `roots.bind` obtains both signature verification and production
metadata hashing from the same typed certificate adapter. SHA-1 identifier
permission is distinct from backend capability and never enables SHA-1
certificate signatures. A matching erased signature handle alone cannot
authorize a different selected TLS provider.

On Windows, this system-trust example explicitly enables the independent
backend and metadata MD5 permissions required by the documented P15/P25 deny
profile. Both remain off on other platforms and in library defaults. These
identifier permissions never enable MD5 certificate signatures, HMAC, HKDF
or TLS PRF, and do not change the separate SHA-1 identifier permission.

With the exact paired dependency selected, run:

```sh
zig build test -Dpaired-tls=true -Doptimize=Debug -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
zig build test -Dpaired-tls=true -Doptimize=ReleaseSafe -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
```

At portable checkpoint `1167939aa`, both commands passed **26/26 tests on
aarch64 Linux, Zig 0.16.0**: the existing 24 adapter/shared-Core tests plus two
TLS matrix tests containing 60 cases. The extended trusted-factory gates below
are additional checks; the original matrix consists of:

* 48 cases: TLS 1.2/1.3 × H1/H2 × 12 provider/trust cases. These exercise
  buffered send and partial-read/finish reuse, a real three-certificate path,
  synthetic in-memory identifier policy, selected-provider ABI/context/vtable
  mismatch, missing provider/typed adapter, a different certificate adapter,
  independent SHA-1 policy/backend gates, metadata allocation failure,
  signature failure, and an actual path-depth limit. Concrete upstream errors,
  `transport_started`, hash-handle destruction, operation count and lease
  cleanup are asserted. Successful reuse performs two SDK requests with one
  TLS handshake and one trust-policy call, retaining all borrowed owners.
* 12 cases: TLS 1.2/1.3 × H1/H2 × explicit abort, explicit cancel, and token
  cancellation after open. Each returns to zero live operations and pooled
  connections. These are terminal cleanup checks, **not** additional blocked
  TLS phase-interruption claims.

The TLS peer observes the actual negotiated TLS version and ALPN. Its accept
and socket waits are bounded; every path joins it. The existing SOCKS5/H2
interruption pairs remain unchanged and passed again (11 ms token, 1–2 ms
deadline; one close and zero live/leased operations for every pair).

`tls_fixture_data.zig` runs the dependency's deterministic certificate
generator in a separate std-only build executable, emitting public test bytes
into the local build cache. It neither copies the trust/conformance frameworks
nor compiles another HTTPX TLS/provider ABI. The test and adapter import the
same canonical HTTPX module. `zig build -Dpaired-tls=true` also compile-checks
these optional tests. The three fixed CI context names are unchanged; their
commands now require paired tests explicitly, and therefore require the
coordinator's qualified paired dependency selection to pass.
The paired adapter/tests also cross-compiled for x86_64 Windows GNU. The
aarch64 macOS check on Linux was **blocked** by missing `Security` and
`CoreFoundation` frameworks required by the candidate's canonical platform
trust discovery. No framework stubs, policy changes or alternate validation
backend were substituted; native macOS verification remains coordinator-owned.

### Explicit public Azure HTTPS probe

This is opt-in, never part of `test` or default CI:

```sh
zig build qualify-public-https -Dpaired-tls=true -j2 \
  --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global \
  --summary all -- "$(awk '/^nameserver / {print $2; exit}' /etc/resolv.conf)"
```

The sole argument is a configured DNS-server IP for HTTPX's pure-Zig resolver;
the shell example reads Linux resolver configuration without changing it.
The endpoint is fixed to unauthenticated `GET https://management.azure.com/`.
HTTP/1.1 is selected, with no H2 ALPN offer, proxy, cookies, retry or redirect
following. The standard selected provider and canonical system-root binding
perform certificate/path/hostname verification. The probe also requires
exactly one successful canonical verification for `management.azure.com` and
zero live operations/connections after bounded finish. It never logs bodies,
credentials or certificate material, installs roots, alters stores, disables
verification or uses OS chain-validation fallback.

The aarch64 Linux run against `ff720540` received **HTTP 400**, with 114 strict
system anchors accepted and 7 unsupported anchors skipped. This is a verified
HTTPS response, not a successful Azure API operation. Limits: 64 KiB response,
10 s whole operation, 5 s connect/read/write phases, 2 s DNS attempts, 16 peer
certificates, 256 KiB per certificate, 1 MiB chain, depth 8 and 64 candidate
attempts. No payload or credentials were logged. Core does not expose the
negotiated TLS version; this public result does not assert one. This single
standard-backend endpoint observation is not the native/platform/public-H2
qualification matrix.

With the composed `b2c6814` HTTPX development input and released Core 0.4.1,
the current probe also received a verified HTTP 400 on aarch64 Linux in both
Debug and ReleaseSafe. Each invocation required exactly one successful
canonical handshake and finished with zero live operations/connections.
The Windows-only MD5 identifier opt-ins stayed off on Linux. This does not
claim a native Windows public-endpoint result or a completed adapter release.

## Trusted HTTPS shared factory — corrected-input qualification

`https_fixture.Owner.create(allocator, io, options)` creates stable, test-owned
standard-provider, typed certificate adapter, `roots.bind` binding, private
test-CA, TLS server and pure-Zig DNS owners. `owner.factory()` is the released
Core `BackendFactory`, with `https_redirects = true`. Call `owner.deinit()`
only after every created backend has been deinitialized.

This fixture serves actual `https://api.example.test:<loopback-port>/...`
requests. Its loopback-only DNS responder resolves the two reserved test names
without public resolvers or OS DNS workers. Certificate/path/DNS-name
verification remains enabled, using the existing generated three-certificate
chain and exactly one custom test trust anchor. The standard provider is
selected through the same canonical HTTPX module and typed binding as the
previous TLS matrix. No Core API, HTTPX source, native provider, OS trust store,
or production adapter code was changed.

The factory uses Core's response-script/captured-request types and invokes the
published `runPipelineContracts`, `runRawTransportContracts`, and
`runBackendAllocationFailureContracts` directly. It does not copy the shared
test framework or fabricate request observations. `std.http.Server` parses
the decrypted HTTP/1.1 requests; only a bounded body prefix and incremental
hash are retained. Metadata and responses are observed at real TLS peers.
HTTP/2 redirect qualification is not claimed by this HTTP/1.1 fixture.

Listeners poll at 20 ms; peer logical reads/writes retain 2 s budgets. The SDK
operation budget is 10 s; strict DNS uses the owned resolver with 1 s attempts.
Each backend owns a stable shutdown token and canonical `IoContext`, composing
that token with the optional borrowed `Options.parent_context`. The parent and
its owners must remain stable through backend/owner destruction. Local,
external and ancestor cancellation states are OR-composed; the earliest
parent deadline always clamps the local budget.

The handshake uses `tls.acceptServerWithIo`: each 2 s budget covers a whole
handshake-message operation across records and partial progress. All `TlsIo`
application reads use `Connection.readWithContext`; writes use
`writeAllWithContext`. A read gets one child deadline, and a writer drain shares
one deadline across its buffered data, vector parts, splats and TLS fragments.
Polling or partial progress does not restart that deadline. The budget does
not cover an entire 32 MiB transfer. Concrete application I/O failures are
retained rather than lost behind `ReadFailed`/`WriteFailed`.

Stopping only signals the shutdown token and joins the worker; it neither
shuts down/closes a socket off-thread nor calls `NtCancelSynchronousIoFile`.
Only the worker clears/closes its socket, before TLS/provider/trust owners
are destroyed. Normal TLS close-notify remains HTTPX's existing control-alert
path with the configured socket timeout; cancellable control-alert sending
is not claimed here. As in Core's factory, a one-request `finish` first allows
bounded natural completion so queued early-abort request metadata is captured.
No-request/scripted shutdown still cancels directly; join failures always
perform cancellation and join before returning an error.

The shutdown test retains the 1 s bound and joined/quiescent assertions for
idle, incomplete-handshake and partial-record peers, with the caller's socket
still open. Additional real-loopback cases exercise ancestor cancellation
while both external tokens are false, and a 500 ms parent request deadline
clamping a partial record's 2 s read budget. These are fixture cleanup checks,
**not** new SDK blocked-TLS interruption capabilities.

### Context-aware fixture integration results

Before composition, with exact `9c487bfc060c14df3d337d614ff4772eee45c0cd` and unchanged released
Core 0.4.1, the targeted fixture selector passed **3/3** in Debug and ReleaseSafe.
After the request-completion corrections, the full paired commands passed
**38/38** in both modes on aarch64 Linux, Zig 0.16.0: the original 36 tests plus
the two parent-context regressions. The original 60 TLS cases, shared Host/EOF
contracts and both 33,554,689-byte directions within the 2,097,152-byte adapter
budget remain passing. Formatting and Windows x86_64 compile-only checks also
passed in both modes.

An earlier full ReleaseSafe run failed the unchanged wide-length assertion:
expected `4295032833`, observed an empty Content-Length. Cancelling before
joining the expected one-request peer could discard queued request headers.
Matching Core's natural-join contract fixed this ordering; the independently
unused same-origin destination now correctly declares `expect_request = false`
while retaining its zero-request assertion. Intermediate failures remain in
the qualification logs; no shared assertion was weakened.

Frozen `86a8e169` previously failed native Windows in both modes: its
incomplete-handshake shutdown took 2,001,580/1,986,357 microseconds and the NT
cancellation request returned `NOT_FOUND`. Its partial-record phase was never
reached. Native Windows execution of this replacement is still required;
cross-compilation and Linux timings do not establish a Windows pass.

### Historical combined Core 0.4.1 / HTTPX `80e2` results

Unchanged reviewed portable source
`b24e2270ec0d2d1d0b796356b1c68481d10676db` was qualified in a new isolated
worktree with selector-only commit
`55d933f3ab707b13b6f74a0c831c35cf4aa45620`. Both dependencies resolved normally
from their full immutable URLs; no local package paths or duplicate modules
were used:

| Input | Immutable URL | Independently verified Zig hash |
| --- | --- | --- |
| Core 0.4.1 merged input | `git+https://github.com/cataggar/azure-sdk-for-zig.git#2c95f65be96b5ef48a50671de33e9e0926c624cb` | `azure_sdk_core-0.4.1-eFY0EpbrCgAKh2uJJ-DguKP7zx8Ywuf1UdP7HkJ_9CmI` |
| HTTPX development input | `git+https://github.com/cataggar/httpx.zig#80e2cbb6976d65a0349976ab82301b1eb9c27b51` | `httpx-0.1.9-8qj2evcNMgBRYXXcklYYayJOyJmP51lzXn0xylUhlicH` |

The full paired commands above each passed **36/36 tests, 8/8 build steps,
exit status 0** on aarch64 Linux with Zig 0.16.0, in **Debug and ReleaseSafe**.
Each mode ran once, without retries or filters. Formatting also passed.
No adapter, fixture, build, workflow or shared-conformance source was changed.

Both complete shared pipeline and raw-transport suites now pass for TLS 1.2
and TLS 1.3; no further failure appeared after the earlier Host/EOF assertions.
Each pipeline suite asserts 22 actual requests, TLS handshakes and canonical
verifications, zero rejected verifications/live backends, and one custom
anchor. Core still regenerates Host on every followed redirect while retaining
the original caller request; same-origin credential preservation, cross-origin
stripping and Azure-owned retry/redirect counts remain covered.

The original 60 provider/trust/cleanup cases, all five backend allocation
scenarios, and both 33,554,689-byte upload/download checks within the
2,097,152-byte adapter budget also pass. The existing ten SOCKS5/H2 interruption
pairs remain Linux-scoped: token latency 11 ms, deadline latency 1–2 ms,
`transport_started = true`, one observed close and zero live/leased operations.
No new blocked-TLS or native-platform interruption claim follows.

Core 0.4.1 is now released. HTTPX remains a draft, unreleased development
candidate with native-policy gates pending, not a final publication pin.
No live Azure probe, Windows/macOS runtime check, native-provider qualification
or OS trust-store mutation was performed for this combined run.

### Historical results against Core `be320739` and HTTPX `95b916c`

With the separate unpublished development selector for
`95b916c77573e70a63c73218ce5b4b371b3868eb`
(`httpx-0.1.9-8qj2elNsMQC3gzkMbgAYN5ggmNx2kKuVBHVLjYp50FcT`):

* The unchanged 24 adapter/Core tests and the earlier 60 TLS cases still pass.
* Independent real-TLS checks pass for TLS 1.2 and 1.3: same-origin credential
  preservation, cross-origin stripping of Authorization/Cookie/Cookie2/
  Proxy-Authorization, 303 POST-to-GET/body removal, original-request ownership,
  ignored ambient Set-Cookie, and exactly one Azure policy call per redirect
  chain. Each chain performs exactly two verified TLS requests.
* Both TLS versions stream **33,554,689 bytes in each direction** within the
  shared **2,097,152-byte adapter allocation budget**, despite a 1 KiB buffered
  response limit. Existing H2/SOCKS5 interruption capabilities remain unchanged.
* Core's complete five-scenario backend allocation-failure runner passes over
  TLS 1.3, retaining OutOfMemory and checking operation/connection cleanup.
* Wrong hostname, unrelated root and path-depth limits fail with their concrete
  canonical trust errors. A redirect to an invalid TLS hostname fails before
  any destination HTTP request is sent, retains `transport_started`, and
  releases both backends. No certificate-verification bypass is involved.

**This historical pair failed four tests: two underlying shared gates ×
TLS 1.2/1.3.** These failures were retained, not skipped or converted into
expected-success tests:

1. **Released Core 0.4 contradicts its shared same-origin Host assertion.**
   `http/transport.zig:isRedirectOmittedHeader` (lines 656–658 at released
   `be320739`) always removes `Host` on redirects. The shared runner at
   `conformance/http_transport.zig:1206` instead requires the same-origin
   second request to retain `conformance-origin`. The actual peer correctly
   observes the regenerated `api.example.test:<port>`. Same-origin credential
   assertions pass before this contradictory Host assertion fails. Each TLS
   version reaches 13 authenticated requests/handshakes/verifications and zero
   live backends. All seven shared native retry cases ran before this failure.
   Restoring Host in the adapter or altering observations would violate Core
   ownership and would not be a valid fixture fix.
2. **HTTPX 95b surfaces TLS close-notify instead of HTTP framing EOF.**
   A clean TLS close after a body shorter than its Content-Length reaches
   `ClientOperation.transportRead`/`readHttp1Body` as `TlsCloseNotify`, while
   Core's shared framing contract requires `HttpContentLengthTruncated`.
   The operation and connection are cleaned up. Globally relabeling a TLS
   alert in the SDK would mishandle other framing/close-delimited responses;
   HTTPX must interpret clean TLS EOF at its HTTP framing boundary.

The historical extended run reported **32/36 passing, four failing**.
Core's corrected shared Host assertion and HTTPX's authenticated clean-close
HTTP framing fix clear those failures together in the exact-input run above;
no SDK error relabeling or production Host policy change was needed.
No final release pin is approved here. Reproduce either input pair with the
ordinary commands above; target only the trusted cases using
`-Dtest-filter='trusted HTTPS'`. Portable source/documentation and development
selectors remain separate commits. The fixture added only `https_fixture.zig`
to publication paths (13 total); this documentation correction adds none.

## Publication gates still open

* Coordinator approval of a qualified HTTPX release and its final immutable
  URL/hash, paired with the already released Core 0.4.1 input.
* Parent-controlled native selected-provider and remaining public-CA Azure
  HTTPS matrix with verification enabled. The standard Linux observation
  above does not qualify SymCrypt or another native provider.
* Native Windows/macOS runtime results; cross-compilation alone is not runtime
  qualification. No native interruption capability is inferred.
* Installation of those coherent pins and successful execution of all three
  fixed package CI contexts, including the mandatory paired/trusted suites.
  Passing with the current composed development input does not make it a release.
* Coordinator acceptance, ordinary implementation merge, then tags/releases.
  Package registration/history/catalog and sealed bootstrap are already
  coordinator-completed, not work to repeat here.

No released-production, native-crypto or FIPS qualification is claimed.
