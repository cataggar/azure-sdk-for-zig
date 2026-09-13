# azure_sdk_storage_blobs

Azure Blob Storage clients, including `BlobClient`, `BlobContainerClient`, and
the complete-SAS `SasBlobClient`.

Version: **0.4.0**. Release branch: `sdk/storage_blobs`. The package pins
published `azure_sdk_core` **0.4.0** and `azure_sdk_storage_common` **0.4.0**,
plus `serde`. `blobs.version` and `blobs.user_agent_prefix` follow the manifest.
The user-agent prefix is available for a caller-owned `TelemetryPolicy`; clients
do not add a user-agent policy implicitly.

Clients take a caller-built `core.http.HttpPipeline`. The pipeline copies its
`HttpRuntime` descriptors by value while borrowing the transport, crypto,
policy, and credential contexts; those contexts must outlive the client and
all derived clients and open operations. The package does not install a
standard crypto fallback.

`SasBlobClient.init` accepts the same runtime directly and uses Storage
Common's credential-isolated SAS sender; it never attaches the caller's
credential policies.

See [`sas.zig`](sas.zig) for complete-SAS transfer sources and outcome semantics.

## Opt-in tracing

Configure the canonical pipeline before constructing generated or handwritten
clients. The complete configuration is copied into derived clients, pagers,
convenience status requests, and buffered upload/download helpers:

```zig
var pipeline = core.http.HttpPipeline.init(runtime, &policies);
const instrumentation: core.tracing.InstrumentationOptions = .{
    .provider = provider.asProvider(),
    .scope_name = "azure_sdk_storage_blobs",
    .scope_version = blobs.version,
    .namespace = "Microsoft.Storage",
    .parent_context = optional_parent,
};
pipeline.setInstrumentation(instrumentation);
var container = blobs.BlobContainerClient.init(pipeline, .{
    .endpoint = endpoint,
    .container_name = container_name,
});
var blob = container.getBlobClient(blob_name);
```

For complete-SAS clients, preserve the existing constructor and configure tracing
only; no credential policy or caller pipeline can enter this path:

```zig
var sas_client = try blobs.SasBlobClient.init(allocator, complete_sas_url, runtime);
defer sas_client.deinit();
sas_client.setInstrumentation(instrumentation);
// sas_client.setInstrumentation(null) disables subsequent tracing.
```

`CompleteSasBlobClient` is the same type and supports the same setter. Every
single upload, staged block, block-list commit, and unknown-length block stream
uses Storage Common's `sendWithOptions`. Caller scope, version, namespace, and
default parent are forwarded unchanged, including when the owning service is
Kusto rather than Blob Storage. SAS dispatch never gains retries, redirects,
credential policies, or automatic reader rewinds.

Provider/exporter/backend contexts must stay at stable addresses. Instrumentation
strings and parent tracestate are borrowed and must outlive all clients/pagers
using them; changing the original pipeline does not reconfigure existing copies.
Owning SAS clients and pagers must not be shallow-copied and deinitialized twice.
Core's concrete provider owns completed span data, so clients, request storage,
and configuration strings can be released before explicit export once their
operations have ended. Clients never drain, flush, or shut down the provider.

Defaults are inert. Configured instrumentation emits one logical HTTP span per
request, not one span around a multi-block upload or whole listing. Buffered
`send` covers the HTTP response; streaming `open` (used by SAS) ends at response
headers and excludes subsequent body-drain errors. Local validation, result
parsing, and download-writer failures are outside an already-completed HTTP span.
SAS accepted/rejected/unknown/incomplete outcomes remain unchanged; telemetry
allocation failures, bounded-queue drops, and explicit exporter errors do not
replace service outcomes. Inspect provider counters and handle export management
errors separately.

Built-in spans omit paths, SAS query/signatures, bodies, authorization, cookies,
and arbitrary headers. Do not put secrets in explicit scope/namespace/tracestate
metadata. There is no environment discovery, automatic export, worker, or
collector connection. HTTP exporters must use suppression or an uninstrumented
pipeline. Production OTLP transport, per-attempt spans, full streaming lifetimes,
and per-call service-client parent APIs remain separate follow-ups.

### Runnable mock-first example

```bash
zig build tracing-mock
```

[`examples/tracing_mock.zig`](examples/tracing_mock.zig) runs actual
`BlobContainerClient.create` and derived Blob upload calls through `MockTransport`.
It writes versioned OTLP JSON to stdout, with W3C wire IDs checked against the
exported spans by its test. It explicitly configures bounded span storage and
calls `forceFlush(1000)` / `shutdown(1000)` after the clients leave scope.
Budgets are cooperative, not promises to interrupt an arbitrary blocking writer.
No token, network access, Azure account, or collector is needed.

Core 0.4 uses owned `RequestHeaders`; this package uses compatible
`setHeader`/`getHeader` and read-only iteration. Applications mutating raw request
maps should follow Core's `http/request_headers.md` migration guide.

## Blob metadata

`BlobContainerClient` and its `BlobClient` (from `container_client.zig`) send
one `x-ms-meta-{name}` header per entry, which is the format the service
expects, and read the same headers back into an ordered `Metadata` map. The
generated client in `src/clients.zig` models metadata as a single opaque
`x-ms-meta` header and cannot round-trip it; use these clients when metadata
matters.

Metadata names must be valid C# identifiers. Anything else is rejected with
`error.InvalidMetadataName` before a request is sent. Azure lowercases names on
the wire, so `Metadata.get` is case-insensitive.

```zig
var crypto_provider = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto_provider.asProvider(),
);
var auth_policy = core.http.BearerTokenAuthPolicy.init(
    allocator,
    credential,
    blobs.auth_scopes,
);
defer auth_policy.deinit();
var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
const pipeline = core.http.HttpPipeline.init(runtime, &policies);

var container = blobs.BlobContainerClient.init(pipeline, .{
    .endpoint = "https://myaccount.blob.core.windows.net",
    .container_name = "checkpoints",
});

var blob = container.getBlobClient("ns/hub/$Default/checkpoint/0");
const result = try blob.uploadConditional(allocator, "", .{
    .metadata = &.{
        .{ .name = "sequencenumber", .value = "42" },
        .{ .name = "offset", .value = "100" },
    },
    .if_none_match = "*",
});
defer result.deinit(allocator);

const properties = try blob.getProperties(allocator);
defer properties.deinit(allocator);
const sequence_number = properties.metadata.get("sequencenumber");
```

```bash
zig build test --summary all
zig build test -Doptimize=ReleaseSafe --summary all
zig build examples
zig build tracing-mock
zig build complete-sas-upload -- <blob-sas-url> <file>
```

`test` executes mock tests and compiles examples; it does not run live examples.
