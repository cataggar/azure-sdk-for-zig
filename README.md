# azure_sdk_core_symcrypt

Optional Microsoft SymCrypt 103.13.0 provider for
`azure_sdk_core.crypto.CryptoProvider`, with a separately enabled HTTPX TLS
primitive binding.

- Package version: `0.3.0`
- Release branch: `sdk/core_symcrypt`
- Core dependency: `azure_sdk_core` `0.4.1`
- Native wrapper dependency: `zig_symcrypt` `0.1.0`
- Supported targets: `x86_64-linux-gnu`, `aarch64-linux-gnu`,
  `x86_64-windows-msvc`, and `aarch64-windows-msvc`

This package is optional. Core-only applications do not acquire a SymCrypt or
other third-party native crypto dependency. Platform features can still link
operating-system libraries; this is not a blanket no-C-symbol guarantee.

The TLS binding pins released HTTPX 0.2.0 and Core 0.4.1. Native conformance
additionally uses the released standard SDK HTTPX adapter 0.1.0. Package
publication requires the reviewed branch tip and the native CI gates below;
a version field or prerequisite release alone does not establish qualification.

## Scope

The provider supplies secure random bytes, compatibility-only MD5, SHA-256,
HMAC-SHA256, and allocator-backed incremental SHA-256. It changes Azure SDK
hashing, integrity headers, and signing selected through `CryptoProvider`.

It **does not** replace the TLS cryptography or X.509 trust implementation
beneath `std.http.Client`. Selecting this package therefore does not make
`std.http.Client` TLS use SymCrypt.

The existing `zig_symcrypt` legacy MD5 support serves Azure Storage
compatibility and integrity paths. That availability does not grant the
separate, default-disabled TLS metadata permission described below. The SDK
provider exposes neither SHA-1 nor RSA. MD5 must not be used as a security
primitive.

## Provider API

```zig
const core_symcrypt = @import("azure_sdk_core_symcrypt");

var provider = try core_symcrypt.Provider.init();
defer provider.deinit();

const crypto_provider = provider.asProvider();
const digest = try crypto_provider.sha256("payload");
_ = digest;
```

`Provider` is single-owner and must not move after `asProvider`. Copyable Core
descriptors borrow it and are valid until `deinit`; calls after deinitialization
return `error.ProviderDeinitialized` while the owner storage remains alive.
`deinit` must not race an operation. Hash/HMAC/default random calls are
concurrent-safe. `initWithScratchAllocator` is also concurrent-safe only when
its borrowed random staging allocator supports concurrent allocation.

Incremental SHA-256 owns separate state allocated with the allocator supplied
to `CryptoProvider.sha256Init`. It remains valid if the provider is later
deinitialized, rejects update/final after finalization, and wipes both adapter
and SymCrypt state before freeing it. Call its `deinit` exactly once.

Initialization and primitive errors are returned unchanged. There is no
`std.crypto` fallback. Digest, MAC, and random results are staged so a failed
operation cannot expose partial caller output. Random staging allocation
failure is returned as `error.OutOfMemory`.

Dynamic initialization performs the recoverable SymCrypt API/minor handshake.
Static initialization follows upstream's process-global contract; a mismatched
static archive/header combination can terminate the process. Neither arbitrary
static builds nor this adapter are claims of FIPS validation.

## Build integration

A final application selects linkage and forwards exact native inputs when it
creates the package dependency:

```zig
const adapter = b.dependency("azure_sdk_core_symcrypt", .{
    .target = target,
    .optimize = optimize,
    .linkage = .dynamic, // or .static
    .symcrypt_libraries = libraries,
    .symcrypt_include_dir = include_dir,
    .symcrypt_system_include_dirs = system_include_dirs,
    .symcrypt_checked = false,
    .symcrypt_provenance = provenance,
});
root_module.addImport(
    "azure_sdk_core_symcrypt",
    adapter.module("azure_sdk_core_symcrypt"),
);
```

Options are forwarded to the pinned `zig_symcrypt` build:

- `linkage`: `dynamic` or `static`.
- `symcrypt_libraries`: ordered, repeated exact library files.
- `symcrypt_include_dir`: complete SymCrypt 103.13.0 public headers; omitted
  uses the exact headers bundled by pinned `zig_symcrypt`.
- `symcrypt_system_include_dirs`: ordered SDK/CRT paths for explicit
  cross-toolchains.
- `symcrypt_checked`: `true` only when headers and every library use the
  checked/`DBG` ABI; default `false` is FRE.
- `symcrypt_provenance`: exact fixture manifest used to verify source identity,
  target, roles/order, architecture, and SHA-256 hashes. Windows dynamic
  execution also verifies and stages the manifest-bound runtime DLL.
- `headers_only`: supported-target adapter/header compilation without native
  linkage.
- `target_can_run`: permits execution when the runner is native for the target
  but the Zig compiler process is another architecture under emulation.
- `source_only`: package and formatting checks without configuring SymCrypt;
  intended for macOS and other non-native validation hosts.

The adapter always forwards `legacy=true`,
`enable_legacy_rsa_pkcs1_encryption=false`, `enable_mlkem=false`, and
`enable_tls_x25519_mlkem768=false`. Consumers cannot broaden this adapter's
legacy surface.

## Optional HTTPX TLS binding

`enable_httpx_tls=true` additionally exports the
`azure_sdk_core_symcrypt_tls` build module. It adds only the pure-Zig HTTPX
dependency; the existing `zig_symcrypt` 0.1.0 pin, SymCrypt 103.13.0 inputs,
and native library order above are unchanged. It does not add a native
dependency to Core or HTTPX itself. The module is absent by default.

```zig
// Add .enable_httpx_tls = true to the package dependency options above.
root_module.addImport(
    "azure_sdk_core_symcrypt_tls",
    adapter.module("azure_sdk_core_symcrypt_tls"),
);
```

```zig
const symcrypt_tls = @import("azure_sdk_core_symcrypt_tls");
var tls_crypto = try symcrypt_tls.Provider.init(allocator, .{});
const tls_primitives = tls_crypto.provider();
_ = tls_primitives;
```

This descriptor implements HTTPX CryptoProvider ABI 2. Selecting SDK
`Provider.asProvider()` and selecting TLS `Provider.provider()` are independent
decisions. Neither operation changes `std.http.Client` TLS. The TLS binding
does not implement a TrustProvider, load roots, validate hostnames or validity,
or change certificate policy. Trust must be supplied independently by the
qualified HTTPX runtime.

### Primitive capabilities and ownership

| Operation | Enabled |
| --- | --- |
| Transcript hashes, clone/snapshot | SHA-256, SHA-384, SHA-512 |
| Trust metadata identifier hashes | SHA-1 and MD5 with separate explicit opt-ins below; both disabled by default |
| HMAC, HKDF extract/expand, TLS 1.2 PRF | SHA-256, SHA-384, SHA-512 |
| AEAD, detached 16-byte tags and 12-byte nonces | AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305 |
| Ephemeral agreement | X25519, P-256, P-384 |
| ECDSA sign/verify | P-256/SHA-256, P-384/SHA-384; DER signatures |
| RSA sign/verify | RSAe PKCS#1 v1.5 and PSS with SHA-256/384/512; PSS salt is exactly the digest length |

MD5/SHA-1 signatures, HMAC, HKDF and TLS PRF, Ed25519, AEGIS, ML-KEM, hybrid groups,
and restricted RSASSA-PSS keys are not advertised. Unsupported provider operations return
`UnsupportedAlgorithm`/`UnsupportedOperation`; there is no `std.crypto`
primitive fallback. TLS MD5 is raw identifier hashing only, separate from the
existing Core SDK MD5 operation.

EC private imports accept canonical raw scalars, SEC1, and unencrypted PKCS#8
with matching curve identifiers. Included EC public points must match the
imported scalar. RSA imports accept unencrypted two-prime PKCS#1/PKCS#8;
SymCrypt reconstructs and validates private keys from `(n,e,d)` instead of
trusting encoded CRT values. RSA public keys use PKCS#1 DER. Native RSA limits
are 2048–16384 bits. Encrypted keys and additional PKCS#8 attributes are not
accepted.

The descriptor borrows its nonmoving owner. Keep that owner and its
thread-safe scratch allocator alive until configurations, sessions, and every
owning handle have been released. Do not mutate the owner while borrowed.
There is no owner resource to deinitialize
and no process-global SymCrypt shutdown. Each mutable hash/private-key handle
is single-owner, single-threaded, and allocated with the supplied handle
allocator. Imports copy secrets into native-owned storage; native destructors
and adapter cleanup wipe secret state. Separate handles and stateless calls
may run concurrently against one borrowed provider.

`Options.max_scratch_bytes` defaults to 64 KiB and bounds concatenated AEAD
AAD, HKDF info, PRF seed, and key encodings; this is not a total native-memory
quota. Hash/HMAC parts stream without
concatenating the transcript. Native library limits and HTTPX ABI preflight
checks also apply. Allocation failures return `OutOfMemory`; native failures
are explicitly mapped into HTTPX's finite provider error categories. Version,
initialization, FIPS, hardware, and unknown failures never select another
provider. Initialization still exposes the original `symcrypt.InitError`.

HTTPX's facade wipes callback outputs on operational failure. In particular,
tag failure returns `AuthenticationFailed` and wipes the entire plaintext
destination, including exact in-place ciphertext. Rejected preflight input
does not invoke a primitive; partial overlaps are not supported.

### Opt-in SHA-1 trust identifiers

Some Windows trust metadata identifies a certificate with a raw SHA-1 digest.
Deployments that explicitly permit those identifier forms can enable the
existing hash operations without enabling SHA-1 security algorithms:

```zig
var tls_crypto = try symcrypt_tls.Provider.init(allocator, .{
    .allow_sha1_identifier_hash = true,
});
```

The default is `false`: SHA-1 is not advertised and creation returns
`UnsupportedAlgorithm` before allocating state. Opt-in enables only raw hash
create/update/snapshot/clone/destruction through the already-pinned SymCrypt
primitive. SHA-1 certificate/TLS signatures, HMAC, HKDF and PRF remain
unsupported, including direct callbacks. Neither the Core SDK hash ABI nor its
compatibility MD5 operation changes. Enabling SHA-1 does not enable MD5.

Raw hashing does not establish trust: a fingerprint match alone never grants
anchor status. The trust-policy binding must pair identifier hashing and
signature verification from the **same selected provider**, and independently
permit the metadata form; missing algorithms or unsupported policy forms must
fail closed, never select stdlib, Crypt32 or native-chain fallback. Trust
request/vtable layouts remain unchanged. The provider descriptor now
declares ABI 2 because raw MD5 adds a new hash tag and semantic contract.

Keep the borrowed provider, policy binding and roots alive at stable addresses
through their configurations and pooled TLS sessions. Each digest uses
independent caller-allocated hash state, with cloned/snapshot state wiped and
released on all paths; shared provider use requires a concurrent-safe allocator.
SHA-1 snapshot buffers must be exactly 20 bytes. Operational callback failures
clear output and return the exact provider error; ABI preflight rejections leave
output unchanged at the facade. Direct native snapshots reject incorrect
lengths and clear their output. A policy-digest helper promising cleared output
on every failure must also clear its own preflight-error output. Identifier support does
not replace canonical certificate/key checks or per-request current-time policy.

### Independent ABI 2 MD5 metadata permission

```zig
var tls_crypto = try symcrypt_tls.Provider.init(allocator, .{
    .allow_md5_identifier_hash = true, // false by default
});
var certificate_crypto = httpx.CryptoCertificateVerifier.init(tls_crypto.provider());
const metadata = certificate_crypto.metadataHasher(.{
    .allow_md5_identifiers = true, // independent, also false by default
});
```

Both permissions are required. Core MD5 availability, Core deployment options,
native-conformance approval, or the SHA-1 opt-in do not grant either permission.
The ABI 2 provider advertises raw MD5 at hash tag `4` / capability bit `0x10`
only when its own option is enabled. MD5 uses the already-pinned SymCrypt hash
context, requires exactly 16 output bytes, and supports incremental updates,
independent clone/snapshot state, transfer, and wiped destruction. No new C
binding, native library, or fallback is introduced. MD5 is never a transcript,
certificate-signature, HMAC, HKDF or PRF permission: wrappers, direct vtable
callbacks and both native MAC-selection branches reject it, including empty
outputs and forged all-bits capability masks.

The selected HTTPX adapter captures one of four metadata callback ceilings:
none, SHA-1, MD5, or both. Widening a copied descriptor's public options cannot
widen the callback's captured permissions; narrowing the options still applies
at `hash`. Direct callbacks retain their captured gates, exact sizing and
all-error clearing. Allocation/partial creation, update, snapshot and clone
failures release owned hash state without provider substitution. Keep the
borrowed owner and adapter immutable at stable addresses. Exact selected
provider ABI/context/vtable pairing still applies; another adapter over the
same provider is not the same bound handle.

ABI 1 compatibility is implemented by the HTTPX consumer boundary, not by
relabeling an old native provider. The reviewed canonical/runtime harness is
retained. This metadata primitive does not implement Windows property/domain
matching, create anchor trust, authorize unsupported signatures, or replace
canonical policy. Those platform/composition gates remain separately owned.

### Qualification boundary

The immutable HTTPX dependency records the released lightweight `v0.2.0` tip
`2d418ce2ebbd8cbb0d930e80feeac0e45560f0c9`, paired with released Core 0.4.1
`2c95f65be96b5ef48a50671de33e9e0926c624cb`. Its full URLs/hashes are in the
manifest. Complete native SDK qualification requires the native matrix below.
`httpx_source` is an explicit local development
override for the HTTPX source root, valid only with `enable_httpx_tls=true`; it is not a
replacement release pin.

Primitive vectors alone do **not** establish TLS interoperability. The opt-in
`tls-interop-check` target exercises real TLS 1.2/1.3 client handshakes and
application records against independent OpenSSL servers. It requires a
provider-routed HTTPX client, Python 3, OpenSSL 3.5, and verified native inputs:

```bash
zig build tls-interop-check -Denable_httpx_tls=true \
  [linkage and fixture options] --summary all
```

The checked-in harness generates local root/intermediate CAs, short-lived
P-256/P-384/RSA leaf identities, an unrelated root, and genuinely expired or
not-yet-valid leaves. Servers listen
only on loopback ephemeral ports. Processes are bounded and terminated, and
generated private keys/certificates are removed even on failure. Logs remain
under the ignored `.agent-scratch/tls-interop` directory.

Both standard and SymCrypt providers use the actual canonical Options-based
`TrustContext` and `roots.bind`, a three-certificate path, and a synthetic
SHA-1 fingerprint restriction. Roots are explicit local test authorities, not
operating-system or public-CA trust. Verification is never disabled and
fingerprint membership never grants anchor status.
The observer permits only the selected AEAD/group, checks actual dispatch,
drains bounded HTTP responses, and injects exact failures into every used
handshake primitive and application AEAD. It rejects successful fallback or
retried provider/trust failures. HTTPX currently maps provider
`AuthenticationFailed` to `TlsBadRecordMac` during handshakes and
`TlsDecryptError` for application records; primitive errors remain unchanged
at the provider boundary. The canonical trust engine maps an injected
certificate signature failure to `TlsCertificateSignatureInvalid`.

The independent matrix covers **42 authenticated SymCrypt combinations**, the
same 42 standard-provider controls, and 212 combined trust/provider-negative
cases per linkage/optimization combination.
All three AEADs and X25519/P-256/P-384 are covered; TLS 1.2 ECDSA combinations
respect certificate-curve compatibility and matching signature hashes.
The probe uses a checking allocator and requires clean teardown.

The separate `tls-paired-check` target exercises native **client and server**
providers through public `connectClient`, current `Client.open` H1/H2, and
optionally Azure Core's actual HTTPX transport. Each route performs two
requests on one connection, checks quiescent leases/operations and observes
native TLS 1.3 KeyUpdate. This canonical matrix uses P-256/AES-128-GCM; the
independent OpenSSL matrix above covers the wider client suite/group set.

The two paired tests contain 84 connection scenarios without the SDK adapter,
or 140 with it, plus direct metadata conformance. They check both independent
SHA-1 gates, all-error output clearing, exact digest lengths, callback and
allocation failures, hash destruction, canonical path/fingerprint failures,
current request time, and exact adapter/provider provenance. Different
contexts of the same backend and identical callback tables at different
addresses are rejected despite equal capabilities and the correct A binding
handle. Neither SHA-1 signatures nor MAC/KDF/PRF capabilities are enabled.

```bash
zig build tls-paired-check tls-interop-check -Denable_httpx_tls=true \
  -Dhttpx_adapter_source=/absolute/path/to/released-sdk-httpx \
  [linkage and fixture options] --summary all
```

`httpx_adapter_source` is an optional source integration for conformance, not
a runtime manifest dependency. CI requires the released SDK checkout described
below and supplies it with the **same HTTPX and Core module instances**,
without changing Core's default dependency. Omitting it runs only the 84-case
native pairing, not the full 140-case SDK matrix. The deterministic
certificate generator is copied by the build from the selected HTTPX
`src/tls/trust_fixtures.zig`; it imports only `std`, not another HTTPX module.

Example paired session composition:

```zig
var certificate_crypto = httpx.CryptoCertificateVerifier.init(tls_crypto.provider());
var bound = try roots.bind(&certificate_crypto, .{
    .allow_sha1_identifiers = true,
});
var session = httpx.tls.TLSSession.init(.{
    .allocator = allocator,
    .crypto_provider = tls_crypto.provider(),
    .certificate_crypto = &certificate_crypto,
    .server_authentication = .{ .verify = .{
        .provider = bound.provider(),
    } },
});
defer session.deinit();
session.attachSocket(&socket);
try session.handshake("service.example");
```

The native owner must separately enable `allow_sha1_identifier_hash` when this
metadata policy is needed. These explicit-authority cases do not establish
Windows CTL/system-store behavior, public-CA interoperability, mutual
authentication or wider server/KeyUpdate suite coverage. Platform trust remains
HTTPX policy, not a native-provider or operating-system chain-verifier fallback.
Header-only compilation is not native execution evidence.

The existing `conformance` publication path contains the harness and its
release-input checker; the optional binding is published under `tls`.
`.github/scripts` contains checkout-only CI tooling, not an SDK runtime dependency.

### Native CI release gates

`package-ci.yml` preserves the three fixed `package-test` contexts and the two
Arm64 architecture jobs. Its required matrix is:

| Target | Runner | Required execution |
| --- | --- | --- |
| `x86_64-linux-gnu` | `ubuntu-24.04` | Dynamic/static, Debug/ReleaseSafe |
| `aarch64-linux-gnu` | `ubuntu-24.04-arm` | Dynamic/static, Debug/ReleaseSafe |
| `x86_64-windows-msvc` | `windows-2025` | Dynamic/static, Debug/ReleaseSafe |
| `aarch64-windows-msvc` | `windows-11-vs2026-arm` | Dynamic/static, Debug/ReleaseSafe |
| macOS | `macos-latest` | Source/package checks and explicit unsupported-native diagnostic only |

Every native combination runs `test tls-test tls-paired-check tls-interop-check`.
SDK transport coverage is mandatory in CI through `httpx_adapter_source`, using
the exact same Core and HTTPX module instances. Existing provenance, header,
verified Windows DLL staging, example execution and archive-consumer compilation
remain in place. Consumer compilation is not consumer execution. No native
target is silently downgraded to build-only or omitted when prerequisites fail;
Windows Arm64 uses checksum-verified x86-64 Zig under emulation on the native
Arm64 runner. That does not change the native test target or qualify the native
Arm64 Zig 0.16.0 compiler, whose observed crashes remain a separate limitation.

`SDK_HTTPX_CONFORMANCE_REF` pins the actual reviewed standard SDK 0.1.0 release
`21b2bd41afa768fc2895041d8176fe06de9ccde6`, tagged with lightweight
`azure_sdk_core_httpx/v0.1.0`. Its package hash is
`azure_sdk_core_httpx-0.1.0-NXwWetyMAgCa5-LeLhuKTpXZVUewQK-j3j9_vj375My4`.
CI checks the exact clean checkout, a lightweight `azure_sdk_core_httpx/v*`
release tag, and
identical immutable Core/HTTPX URLs and hashes in both manifests. This source
checkout introduces no runtime package cycle. The native and standard adapters
use identical released Core/HTTPX URL/hash pairs. A missing, draft, untagged,
dirty or incoherent input still fails the existing strict guards rather than
skipping conformance. Dependency coherence alone does not approve a native
release or qualify Windows trust metadata.

Native jobs build the independent **CLI test reference** from
[OpenSSL 3.5.5's official archive](https://github.com/openssl/openssl/releases/download/openssl-3.5.5/openssl-3.5.5.tar.gz),
requiring SHA-256
`b28c91532a8b65a1f983b4c28b7488174e4a01008e29ce8e69bd789f28bc2a89`.
The helper requires Python 3.12+, a complete Perl distribution with its standard
modules, and Make/a C compiler on Linux or the matching native MSVC/nmake
environment on Windows. Missing tools, download/hash/version failures, or
non-runnable targets fail the job. It uses `no-shared no-tests no-asm no-module`,
checks executable/library version, and writes and logs source/configuration/
executable-digest provenance in `.openssl-reference/provenance.json`.
The Windows reference helper explicitly selects an installed **MSVC 14.44**
servicing toolset for both native architectures, with no fallback to a newer
Visual Studio default and no automatic installation. It verifies the selected
compiler, linker, librarian and nmake paths/versions/hashes and records them,
the exact toolset and SDK/UCRT versions in the reference provenance. This
reference-only compatibility selection does not change Zig or SymCrypt builds;
successful full native interoperability qualification remains required.
The generated minimal `OPENSSL_CONF` applies only to the disposable test peer.
OpenSSL is neither linked into the SDK nor a fallback provider or a FIPS
qualification claim.

The released-input source at `64c2ea2be944caf0bc2e2eccd41272a5f7179fe3`
completed the full local Linux Arm64 matrix with the released SDK checkout and
the actual built OpenSSL 3.5.5 reference. Every dynamic/static and
Debug/ReleaseSafe combination ran all four mandatory targets: 21 build steps,
44 tests, 140 SDK-enabled paired connections, 84 authenticated OpenSSL sessions
and 212 trust/provider negatives passed per configuration. Both ReleaseSafe
archive consumers compiled. These local results do not stand in for Linux x64,
Windows x64 or Windows Arm64 execution.

The ABI 2 tests retain independent backend/policy flags, captured ceilings,
direct keyed-operation rejection, allocation/partial-failure wiping, cloning,
concurrency and exact provenance. Synthetic SHA-1 restrictions use the generic
constraints family, certificate-DER domain and explicit 20-byte identifier
length; they neither grant trust nor relax permissions.

The released-source/hash-coherence guard, mixed `.path` rejection and all
mandatory native commands remain enforced. Main publication metadata must
match the reviewed package branch before a new lightweight release tag is
created. Neither a successful CLI-builder run nor native-only pairing replaces
the full SDK/OpenSSL matrix.

This binding and its algorithm list make no FIPS-validation claim. In
particular, availability of ChaCha20-Poly1305 or a successful native integrity
check does not establish approved-mode operation.

```bash
zig build tls-test -Denable_httpx_tls=true [linkage and fixture options] --summary all
zig build tls-test-compile -Denable_httpx_tls=true [linkage and fixture options]
zig build headers-check -Denable_httpx_tls=true -Dheaders_only=true [header options]
zig build package-consumer-check -Denable_httpx_tls=true [linkage and fixture options]
```

### Exact library order

Linux dynamic:

1. `libsymcrypt_plus.a`
2. `libsymcrypt.so` or its exact versioned file

Linux static:

1. `libsymcrypt_plus.a`
2. `libsymcrypt_posixusermode.a`
3. `libsymcrypt_common.a`
4. `libsymcrypt_mlkem.a`

Windows dynamic:

1. `symcrypt_plus_NoCIL.lib`
2. import library for `symcrypt_zig_103_13.dll` (never pass the DLL as a link
   input)

Windows static:

1. `symcrypt_plus_NoCIL.lib`
2. `symcrypt_static_NoCIL.lib`

Linux dynamic applications must provide the exact SONAME through an
application rpath or controlled loader configuration. Windows dynamic
applications must verify and place the exact manifest-bound
`symcrypt_zig_103_13.dll` beside the executable.

## Validation

Native commands require exact libraries and provenance:

```bash
zig build provenance-check [linkage and fixture options]
zig build test [linkage and fixture options] --summary all
zig build example-run [linkage and fixture options]
zig build package-consumer-check [linkage and fixture options]
```

For **Windows ARM64 static Core tests only**, in both Debug and ReleaseSafe,
`zig build test` runs the same compiled test artifact through the published
`conformance/run_core_tests.py` launcher instead of Zig's test-server protocol.
It retains the build's seed, cache directory and working directory, and requires
native Windows ARM64, an ARM64 PE image, the existing static provenance gate,
all ten named completed cases, zero skips and exit zero. TLS, paired, example,
consumer and all other Core execution paths are unchanged.

Python remains required for native conformance. The launcher allows one
60-second whole-launch interval, including a gated worker's startup, and buffers
at most 1 MiB of non-TTY output, replayed on completion or failure. A private
Windows Job Object owns the worker, Core process and descendants before the
Core executable can start. Timeout, output overflow, containment/cleanup errors,
surviving descendants, leaks and logged errors fail; there is no retry or
unbounded fallback. Cleanup has a separate five-second job deadline and bounded
worker/output waits. No SymCrypt DLL is staged for this static path.

This narrow execution policy follows a successful native standalone observation;
it does not establish an IPC-only cause for earlier runner stalls or identity
with an earlier executable. Final-head native matrix and post-loop
examples/consumer acceptance remain mandatory.

Build-only and source checks:

```bash
zig build test-compile [linkage and fixture options] --summary all
zig build headers-check -Dheaders_only=true [header options]
zig build source-check -Dsource_only=true
zig build package-check -Dsource_only=true --summary all
```

`source-check` also runs the build's platform/linkage selection regression.
Portable launcher regressions use the existing Python unittest runner in CI;
they do not substitute for native Windows execution.

macOS and all unlisted native targets fail with a diagnostic naming the four
supported triples. They can still run `source-check` and `package-check` with
`-Dsource_only=true`.

Package CI builds SymCrypt from Microsoft tag `v103.13.0`, commit
`286762b7730e2b780678f5ab11fef2b1bad639e0`, with the pinned Jitterentropy
gitlink. It uses the released `zig_symcrypt` fixture builders and provenance
verification rather than downloading opaque native binaries.
