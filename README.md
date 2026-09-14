# Azure Core HTTPX transport for Zig

**Version: 0.1.0.** Uses released Azure Core 0.4.1 and HTTPX 0.2.0.

`azure_sdk_core_httpx` implements Azure Core's buffered and streaming HTTP
transport contracts using HTTPX. It is optional: Core does not depend on HTTPX,
and WASI applications keep Core's host backend. Requires Zig 0.16.0.

## Dependencies

The manifest uses normal immutable commit URLs and actual Zig package hashes,
without local paths. Core 0.4.1 and HTTPX 0.2.0 are released. HTTPX comes only
from `cataggar/httpx.zig`; its release commit has the same complete source tree
and package hash as the qualified input.

| Package | Immutable URL | Zig package hash |
| --- | --- | --- |
| Core 0.4.1 | `git+https://github.com/cataggar/azure-sdk-for-zig.git#2c95f65be96b5ef48a50671de33e9e0926c624cb` | `azure_sdk_core-0.4.1-eFY0EpbrCgAKh2uJJ-DguKP7zx8Ywuf1UdP7HkJ_9CmI` |
| HTTPX 0.2.0 | `git+https://github.com/cataggar/httpx.zig#2d418ce2ebbd8cbb0d930e80feeac0e45560f0c9` | `httpx-0.2.0-8qj2eonLMwDuDDJxDVzoax9VY68Lb0YjT_AtwZBAbqwV` |

## Integration

Import `dependency.module("azure_sdk_core_httpx")` in your application build.
The package also exports `dependency.module("httpx")` and
`dependency.module("azure_sdk_core")`, the same module objects used internally.
Optional TLS providers must use that canonical HTTPX module or `adapter.httpx`
types, never a second HTTPX compilation or copied provider/trust ABI.
This package adds no C source or third-party native-crypto dependency, including
SymCrypt. HTTPX uses operating-system libraries for Windows/macOS trust-store
discovery; certificate cryptography still uses the selected provider.

| Public API | Contract |
| --- | --- |
| `HttpxTransport.init(allocator, io, Options)` | Creates a move-only transport owner; can fail |
| `asTransport()` | Returns a copyable, borrowed `core.http.HttpTransport` descriptor |
| `poolStats()` | Returns canonical HTTPX pool observations |
| `trailers(operation)` | Borrows canonical response trailers after EOF/finish until operation deinit; rejects foreign operations |
| `deinit()` | Closes the pool; all operations must already be deinitialized |
| `Options`, `core`, `httpx` | Configuration and the actual dependency modules |

### Verified system trust and Azure pipeline

This buffered GET example accepts an application-configured DNS-server IP.
The caller owns and must deinitialize the returned `core.http.Response`.
For repeated requests, keep these owners and the pipeline alive together
rather than rebuilding the pool per request. Add Azure authentication,
telemetry, tracing and retry policies to the pipeline as needed.

```zig
const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
const core = adapter.core;
const httpx = adapter.httpx;

pub fn get(
    allocator: std.mem.Allocator,
    io: std.Io,
    dns_server: []const u8,
    url: []const u8,
) !core.http.Response {
    _ = try httpx.Address.parseIp(dns_server, 53);
    const windows_md5 = @import("builtin").os.tag == .windows;
    var standard = httpx.StandardCryptoProvider.initWithOptions(io, allocator, .{
        .allow_md5_identifier_hash = windows_md5,
    });
    var roots = try httpx.tls.TrustContext.init(allocator, io, .{ .source = .system });
    defer roots.deinit();
    var certificate_crypto = httpx.CryptoCertificateVerifier.init(standard.provider());
    var binding = try roots.bind(&certificate_crypto, .{
        .allow_sha1_identifiers = true,
        .allow_md5_identifiers = windows_md5,
    });
    var resolver = httpx.DNSResolver.init(allocator, .{
        .dns_servers = &.{.{ .ip = dns_server }},
        .udp_timeout_ms = 2000,
        .tcp_timeout_ms = 2000,
    });
    defer resolver.deinit();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{
            .tls_crypto_provider = standard.provider(),
            .tls_certificate_crypto = &certificate_crypto,
            .server_authentication = .{ .verify = .{ .provider = binding.provider() } },
            .tls_trust_limits = .{},
            .dns_resolver = &resolver,
            .timeouts = httpx.Timeouts.uniform(10_000),
        },
        .operation = .{ .require_interruptible_dns = true },
    });
    defer transport.deinit();
    var azure_crypto = core.crypto.StdCryptoProvider.init(io);
    var pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(transport.asTransport(), azure_crypto.asProvider()),
        &.{},
    );
    var request = core.http.Request.init(allocator, .GET, url);
    defer request.deinit();
    return pipeline.send(&request);
}
```

`roots.bind` obtains certificate signature verification and production metadata
hashing from the same typed adapter. The selected TLS provider must match its
ABI, context and vtable; an erased signature handle alone cannot authorize a
different provider. All owners remain stable through pooled TLS sessions.

SHA-1 identifier permission is independent of backend capability. The example
also explicitly enables both Windows-only MD5 backend and metadata permissions
needed by HTTPX's [P15/P25 Disallowed identity profile](https://github.com/cataggar/httpx.zig/blob/2d418ce2ebbd8cbb0d930e80feeac0e45560f0c9/docs/api/standard-trust.md#documented-disallowed-deny-identities). Those MD5
permissions stay off on other platforms and in library defaults. Identifier
permissions do not enable MD5/SHA-1 certificate signatures; the MD5 opt-ins do
not enable HMAC, HKDF or TLS PRF. Unsupported platform metadata remains
fail-closed. There is no OS chain-verification fallback.

## Transport behavior

`Options.client` is a canonical `httpx.ClientConfig` copied by value;
`Options.operation` is canonical `httpx.OpenOptions` copied per attempt.
Routing, proxy/`no_proxy`, resolver, HTTP version, pool, timeouts, cancellation,
trust/provider configuration and limits are forwarded. Borrowed fields are
not deep-copied.

### Azure-owned policy and headers

Azure alone controls authentication, retries, redirects, replay, request URL,
headers and body. HTTPX retries, redirects, cookie storage/sending, User-Agent
and Accept-Encoding synthesis are disabled at both client and operation
levels, regardless of caller policy defaults. There is one `Client.open` call
per Azure attempt.

Ambient request overrides are rejected with `AzureOwnsRequestOptions`: base
URL, default headers, request compression, query/auth/range/custom-method
options, and alternate body/Expect settings. Put explicit headers on the Core
request. Disabling verification with either `verify_ssl` or the explicit
insecure `server_authentication` variant returns `TlsVerificationRequired`.

All Core methods and owned `RequestHeaders` are forwarded without mutating
the request or losing header order/duplicates. Matching Content-Length or
Transfer-Encoding is validated and emitted once; conflicting framing fails.
HTTP/1 Connection defaults are emitted once; HTTP/2 has no Connection header.
Responses retain Core's string map and owned, wire-ordered duplicate headers.

Core owns preflight checks and `transport_started`; the adapter never resets
that flag. Core's HTTPS-only redirect rules regenerate Host on every followed
redirect, preserve same-origin credentials, and strip cross-origin
Authorization, Cookie, Cookie2 and Proxy-Authorization. The original caller
request remains unchanged; HTTPX defaults cannot restore stripped credentials.

### Bodies, limits and errors

Both buffered `send` and streaming `open` use canonical `Client.open`,
incremental writes, `waitForContinue`, `finishRequest(null)`, `read` and
`finish(.{})`. Upload readers are consumed synchronously during Core `open`.
Known lengths use `u64` framing; unknown lengths use chunked upload. An early
final Expect response does not consume the upload source.

Streaming does not copy whole bodies: upload and response-reader buffers are
16 KiB each, with bounded HTTPX protocol/decoder storage. Buffered `send`
materializes its returned body once and moves owned response metadata.

| Setting | Meaning |
| --- | --- |
| `max_buffered_response` | Buffered `send` only; 16 MiB by default |
| `operation.response_limit = .{ .bytes = 0 }` | Empty response only, not unlimited |
| `operation.response_limit = .unlimited` | No operation response-size limit |
| `operation.response_limit = .inherit` | Uses `client.max_response_size`; zero there means unlimited |
| `decompression` | `.enabled` by default, matching Core's standard backend; `.disabled` returns encoded bytes |

Decompression never synthesizes Accept-Encoding or inherits HTTPX policy.
The adapter's default client sets request/response size limits to zero.
Replacing the `client` struct adopts that struct's canonical HTTPX defaults.

`operation.timeouts.request_ms` bounds the whole native operation, including
upload, response and drain. `timeout_ms` is a phase override, not a replacement
whole-operation deadline. A nonzero Core request budget can only shorten the
native budget; an explicit zero Core budget expires immediately. These are
per-dispatch budgets; Core owns logical retry/redirect budgets. Core's tracing
context is unchanged; the current native `OpenOptions` has no parent
`IoContext` field.

Cancellation, timeout, framing and size errors map to Core errors. Other
concrete errors, including `OutOfMemory`, propagate unchanged.
`HttpOperation.bodyError()` exposes the first read error behind
`std.Io.Reader.ReadFailed`; later `finish` preserves it. Successful finish
drains framing/trailers before reuse. Abort/cancel, malformed framing and
partial construction failures discard or release resources.

## Ownership, concurrency and DNS

The transport is a **caller-serialized, move-only owner**. Keep its address
stable after `asTransport`; do not mutate, move or deinitialize it while
descriptors or operations use it. Multiple operations may remain open, but
all owner methods and allocator access must be serialized.

Allocator, `std.Io`, borrowed configuration strings, resolver, backend and
trust/provider owners must outlive transport deinit, including **idle pooled
TLS sessions**. Operations own request metadata after open; upload bytes/readers
are borrowed only during open. Tokens stay borrowed until operation deinit.
The Azure pipeline/runtime is copied by value, not its borrowed owners.

Only cancellation tokens may be signalled concurrently. Core cancellation is
bridged to one canonical HTTPX token by a joined per-operation monitor thread
with a 1 ms observation interval; a configured HTTPX token is also honored.
The monitor accesses stable tokens, not operation handles. `std.Io` must support
event waits/signals across those threads. Operation methods, including cancel
and deinit, are not concurrent methods.

Cancellation is checked around upload reads, but cannot preempt an arbitrary
blocking borrowed reader. Native I/O observes cancellation/deadlines under
HTTPX's contract. Strict hostname DNS requires a configured pure-Zig resolver
on **every OS**; literals and Unix routes are exempt. HTTPX checks the final
proxy/`no_proxy` route. Adapter defaults enable strict DNS; when replacing
`operation`, explicitly set `require_interruptible_dns = true`. Cancellation
of a non-strict detached native DNS worker is not advertised.

## Platforms and conformance

Native HTTP/1.1 and HTTP/2 are supported. Public HTTP/3 is rejected. Unix plus
HTTP/2 or TLS is explicitly rejected, never rerouted to TCP or downgraded.
WASI builds intentionally reject this package with Core host-backend guidance.
Windows uses the system Winsock ABI, not an added C transport library.

Default tests are offline. CI also requires the opt-in paired standard TLS
suite in Debug and ReleaseSafe; neither mode can silently fall back to plain
HTTP. The workflow runs both modes even if one fails, then reports failure if
either failed. The public Azure probe is never part of these commands.

```sh
zig fmt --check build.zig build.zig.zon root.zig transport.zig test_backend.zig interruption_fixture.zig tests.zig tls_qualification.zig tls_fixture_data.zig https_fixture.zig public_https.zig
zig build test --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
zig build test -Dpaired-tls=true -Doptimize=Debug -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
zig build test -Dpaired-tls=true -Doptimize=ReleaseSafe -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
```

`zig build -Dpaired-tls=true` compiles without running the tests.
Use `-Dtest-filter='trusted HTTPS'` or `-Dtest-filter='paired standard TLS'`
to select those contracts. The published Core conformance module and
std-only certificate generator are reused, not copied or compiled into a
second HTTPX ABI.

[SDK CI run 34870976350](https://github.com/cataggar/azure-sdk-for-zig/actions/runs/34870976350)
passed **38/38 tests in each mode** in all three fixed contexts:
`package-test (ubuntu-latest)`, `package-test (windows-latest)` and
`package-test (macos-latest)`. That run executed accepted SDK source
`cbda8daa26d928b96990fb3c0d84b078d654e2a9` with the same HTTPX source tree and
package hash as the released dependency selected here.

Coverage includes the 24 adapter/shared-Core tests and 14 paired tests:
48 TLS 1.2/1.3 x H1/H2 provider/trust cases plus 12 terminal abort/cancel/token
cases, real three-certificate paths, selected-provider identity, independent
SHA-1 gates, OOM/signature errors, path depth, output cleanup and pooled owners.
Synthetic SHA-1 metadata uses restriction-only `.constraints` /
`.certificate_der` entries with explicit 20-byte identifiers, not AuthRoot
grants or Windows Disallowed aliases; it enables no MD5.

The trusted HTTPS factory directly runs Core's pipeline, raw transport and
allocation-failure suites over verified TLS 1.2/1.3 HTTP/1.1 loopback peers.
It checks real same/cross-origin credentials, Host regeneration, Azure-owned
retry/redirect counts, invalid destination rejection before sending HTTP,
and **33,554,689 bytes each direction within a 2,097,152-byte adapter allocation
budget**. Test-owned CA and DNS avoid public fixtures and OS trust changes.
HTTP/2 HTTPS redirect coverage is not claimed.

### Fixture cancellation scope

`https_fixture.Owner.create` owns the test provider, typed binding, CA, DNS and
server; `owner.factory()` returns Core's `BackendFactory`. Deinitialize every
backend before its owner. Each backend's stable shutdown token is OR-composed
with optional borrowed `Options.parent_context`; parent owners must outlive it.
Context-aware server handshake and application I/O retain 2 s logical budgets,
clamped to earlier parent deadlines without resets across partial progress.
Stopping signals the token and joins; only the worker closes its socket.
Expected single requests finish naturally under a bounded join before request
capture. Normal close-notify retains HTTPX's control-alert timeout path;
cancellable control-alert transmission is not claimed.

The native Windows CI above measured these times in microseconds; every case
joined and became quiescent without weakening the 1 s acceptance bound:

| Case | Debug | ReleaseSafe |
| --- | ---: | ---: |
| Idle shutdown | 417 | 580 |
| Incomplete handshake shutdown | 16,502 | 12,183 |
| Partial-record shutdown | 887 | 12,150 |
| Ancestor cancellation | 2,239 | 15,672 |
| 500 ms parent request deadline | 516,491 | 512,873 |

These are fixture cleanup/parent-context results, **not** general SDK
blocked-TLS interruption capabilities.

### Per-phase SDK interruption scope

Recorded blocked-I/O evidence remains Linux-scoped: token and whole-operation
deadline interruption of SOCKS5 CONNECT-reply wait, H2 upload flow-control
wait, response-head wait, response-body read and finish/drain. Peer-observed
protocol acknowledgements establish entry; both owner completion and peer
EOF/reset must meet the unchanged 1 s bound, with one close and no live/leased
operations. A bounded joined watchdog fails rather than manufacturing evidence.

```sh
zig build test -Dtest-filter=interruption -j2 --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global --summary all
```

This does not establish arbitrary upload-reader preemption, H1 backpressure,
stalled raw TCP SYN, DNS or client TLS-handshake interruption, or a general
Windows/macOS interruption matrix. CI loopback success does not qualify
SymCrypt, another native provider, FIPS, every architecture or OS version,
or public-CA/platform combinations.

## Manual public Azure HTTPS probe

The sole argument is a configured DNS-server IP for the pure-Zig resolver.
This Linux example reads existing resolver configuration without changing it:

```sh
zig build qualify-public-https -Dpaired-tls=true -j2 \
  --cache-dir .zig-cache/local --global-cache-dir .zig-cache/global \
  --summary all -- "$(awk '/^nameserver / {print $2; exit}' /etc/resolv.conf)"
```

The probe makes unauthenticated `GET https://management.azure.com/` using
HTTP/1.1 only, `HTTPX.StandardCryptoProvider` and canonical system roots.
It offers no H2 ALPN and follows no proxy, cookies, retries or redirects.
Certificate/path/hostname verification is required, with exactly one
successful verification and zero live operations/connections after finish.
It logs no payload, credentials or certificate material, installs no roots,
mutates no stores and uses no verification bypass or OS chain fallback.
Windows-only MD5 identifier opt-ins follow the example above.

Bounds: 64 KiB response, 10 s whole operation, 5 s connect/read/write phases,
2 s DNS attempts, 16 peer certificates, 256 KiB per certificate, 1 MiB chain,
path depth 8 and 64 candidate attempts. Both modes received verified HTTP 400
on aarch64 Linux with the source-identical composed HTTPX input. That is HTTPS
acceptance, not Azure API success. Core does not expose negotiated TLS version,
so none is asserted for this endpoint. No native Windows/macOS public-endpoint,
public-H2 or native-provider qualification follows from that observation.

## Source and package contents

Source belongs to the `sdk/core_httpx` package branch, not `main`; `main`
contains shared tooling and package metadata only. The 13 archive paths in
`build.zig.zon` are:

```text
build.zig                  build.zig.zon           root.zig
transport.zig              tests.zig               test_backend.zig
interruption_fixture.zig   tls_qualification.zig   https_fixture.zig
tls_fixture_data.zig       public_https.zig        README.md
LICENSE.txt
```

Earlier preparation failures and qualification records remain in Git history
and session logs; they are not current API guidance or new release claims.
