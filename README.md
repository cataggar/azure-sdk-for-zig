# azure_sdk_core_symcrypt

Optional Microsoft SymCrypt 103.13.0 provider for
`azure_sdk_core.crypto.CryptoProvider`, with a separately enabled HTTPX TLS
primitive binding.

- Package version: `0.2.0`
- Release branch: `sdk/core_symcrypt`
- Core dependency: `azure_sdk_core` `0.4.0`
- Native wrapper dependency: `zig_symcrypt` `0.1.0`
- Supported targets: `x86_64-linux-gnu`, `aarch64-linux-gnu`,
  `x86_64-windows-msvc`, and `aarch64-windows-msvc`

This package is optional. Applications that use only `azure_sdk_core` do not
compile or link any C or SymCrypt symbols.

## Scope

The provider supplies secure random bytes, compatibility-only MD5, SHA-256,
HMAC-SHA256, and allocator-backed incremental SHA-256. It changes Azure SDK
hashing, integrity headers, and signing selected through `CryptoProvider`.

It **does not** replace the TLS cryptography or X.509 trust implementation
beneath `std.http.Client`. Selecting this package therefore does not make
`std.http.Client` TLS use SymCrypt.

MD5 is enabled in `zig_symcrypt` only because Azure Storage compatibility and
integrity paths require it. The SDK provider exposes neither SHA-1 nor RSA.
MD5 must not be used as a security primitive.

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

This descriptor implements HTTPX CryptoProvider ABI v1. Selecting SDK
`Provider.asProvider()` and selecting TLS `Provider.provider()` are independent
decisions. Neither operation changes `std.http.Client` TLS. The TLS binding
does not implement a TrustProvider, load roots, validate hostnames or validity,
or change certificate policy. Trust must be supplied independently by the
qualified HTTPX runtime.

### Primitive capabilities and ownership

| Operation | Enabled |
| --- | --- |
| Transcript hashes, clone/snapshot | SHA-256, SHA-384, SHA-512 |
| HMAC, HKDF extract/expand, TLS 1.2 PRF | SHA-256, SHA-384, SHA-512 |
| AEAD, detached 16-byte tags and 12-byte nonces | AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305 |
| Ephemeral agreement | X25519, P-256, P-384 |
| ECDSA sign/verify | P-256/SHA-256, P-384/SHA-384; DER signatures |
| RSA sign/verify | RSAe PKCS#1 v1.5 and PSS with SHA-256/384/512; PSS salt is exactly the digest length |

SHA-1, Ed25519, AEGIS, ML-KEM, hybrid groups, and restricted RSASSA-PSS keys
are not advertised. Unsupported provider operations return
`UnsupportedAlgorithm`/`UnsupportedOperation`; there is no `std.crypto`
primitive fallback. Legacy MD5 remains confined to the existing SDK provider,
not the TLS provider.

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

### Qualification boundary

The immutable HTTPX dependency currently records the published ABI foundation
`2257fcdd28fb0e1bbd7da33350846d522d29d034`, not a qualified end-to-end
SymCrypt TLS runtime. `httpx_source` is an explicit local development override
for the HTTPX source root, valid only with `enable_httpx_tls=true`; it is not a
replacement release pin.

Primitive vectors, independent AEAD/key/signature checks, and fault-injection
tests do **not** establish TLS interoperability. Before claiming HTTPX/SymCrypt
TLS support or closing the integration gate, qualify and pin the completed
HTTPX provider-injection runtime, then run independent-server TLS 1.2 and
TLS 1.3 handshakes/records for every advertised suite and group. Repeat trusted,
untrusted, expired, and hostname-mismatch outcomes with unchanged TrustProvider
policy, and inject provider failures into real handshakes and records to prove
there is no fallback. Repeat dynamic/static Linux/Windows and Arm64 execution;
header-only compilation is not native matrix evidence.

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

Build-only and source checks:

```bash
zig build test-compile [linkage and fixture options] --summary all
zig build headers-check -Dheaders_only=true [header options]
zig build source-check -Dsource_only=true
zig build package-check -Dsource_only=true --summary all
```

macOS and all unlisted native targets fail with a diagnostic naming the four
supported triples. They can still run `source-check` and `package-check` with
`-Dsource_only=true`.

Package CI builds SymCrypt from Microsoft tag `v103.13.0`, commit
`286762b7730e2b780678f5ab11fef2b1bad639e0`, with the pinned Jitterentropy
gitlink. It uses the released `zig_symcrypt` fixture builders and provenance
verification rather than downloading opaque native binaries.
