# azure_sdk_storage_common

Shared Azure Storage authentication and SAS primitives:

- `StorageSharedKeyCredential`
- `SasBuilder`
- complete service-issued SAS helpers

Version: `0.4.1` (`storage_common.version`, derived from the package manifest).
Release branch: `sdk/storage_common`. The package pins the published pure-Zig
`azure_sdk_core` 0.4.1 release.

Cryptographic operations require an explicit `core.crypto.CryptoProvider`.
Pipeline integrations should pass `runtime.crypto`; there is no implicit
standard-provider fallback. Shared-key credentials own decoded key material
and must be deinitialized:

```zig
var credential = try storage_common.StorageSharedKeyCredential.init(
    allocator,
    account_name,
    encoded_account_key,
);
defer credential.deinit();
try credential.signRequest(&request, runtime.crypto);

const content_md5 = try storage_common.contentMd5(
    allocator,
    runtime.crypto,
    body,
);
defer allocator.free(content_md5);

const account_sas = try (storage_common.SasBuilder{
    .account_name = account_name,
    .permissions = "rl",
    .services = "b",
    .resource_types = "sco",
    .start = optional_start,
    .expiry = expiry,
    .ip = optional_ip,
    .protocol = "https",
    .encryption_scope = optional_encryption_scope,
}).sign(allocator, runtime.crypto, encoded_account_key);
defer allocator.free(account_sas);
```

Credential-free SAS sends likewise take a `core.http.HttpRuntime`, ensuring
request IDs and transport behavior use the caller's configured providers.
SAS query values, including Base64 signatures, are percent-encoded.

## Optional SAS request tracing

`sas.send(runtime, request, body)` remains available and uninstrumented.
`sas.sendWithOptions(runtime, request, body, options)` adds
`sas.SendOptions.instrumentation: ?core.tracing.InstrumentationOptions`, defaulting
to `null`. Both use the same empty-policy pipeline implementation.

Service clients can forward **only tracing configuration**, not their credential
policies or an entire caller pipeline:

```zig
const outcome = try storage_common.sas.sendWithOptions(
    runtime,
    &request,
    body,
    .{ .instrumentation = caller_instrumentation },
);
```

For example, a Blob client supplies the following Core configuration through
`caller_instrumentation`; Queue and Kusto callers supply their own package scope
and version instead:

```zig
const caller_instrumentation: core.tracing.InstrumentationOptions = .{
    .provider = provider.asProvider(),
    .scope_name = "azure_sdk_storage_blobs",
    .scope_version = service_package_version,
    .namespace = "Microsoft.Storage",
    .parent_context = optional_parent,
};
```

Core requires `provider` and `scope_name`. This helper forwards all fields
unchanged; it does not replace the service scope with Storage Common's identity.
Tracing configuration does not belong in `HttpRuntime`. The helper also does not
set a `User-Agent`; caller-supplied service user agents remain unchanged.

The provider, exporter, runtime contexts, and configuration strings must have
stable addresses/lifetimes as required by Core. Borrowed configuration and parent
tracestate must remain live through the call. Core's `ExportingTracerProvider`
copies retained span data, so the request, upload reader, temporary pipeline, and
configuration strings may be released after the call, before explicit export.
Keep the provider and exporter alive until the application is finished with them;
custom providers/exporters must follow Core's ownership contracts.

- Dispatch remains non-retrying and disallows redirects, even for replayable
  bodies. No credential policy is accepted or added.
- One logical client span ends when `open` returns response headers. Subsequent
  response-body draining is **not** included in its duration or error status.
- Existing outcomes are unchanged: a received 2xx is accepted; other received
  statuses are rejected; opening failure after backend entry is `unknown`.
  Pre-dispatch failures are returned as errors. Backend entry does not prove the
  server received the request. A later body-drain failure cannot change a known
  accepted/rejected status.
- Built-in telemetry excludes URL paths/queries (including SAS signatures),
  request/response bodies, authorization, cookies, and arbitrary headers. Only
  Core's safe HTTP attributes and explicit caller instrumentation metadata are
  recorded. Caller-provided metadata/tracestate should never contain secrets.
- Incoming caller trace headers are restored after dispatch. Disabled/default
  instrumentation leaves trace headers untouched and creates no spans.
- Telemetry allocation/drop failures do not replace service outcomes. Inspect
  `provider.stats()` for propagation errors and dropped spans.
- There are no hidden workers, environment discovery, collector connections, or
  automatic export/flush/shutdown. The application explicitly calls `drain`,
  `forceFlush`, and `shutdown` and handles their telemetry errors separately.
  Exporters that use HTTP must suppress instrumentation or use an uninstrumented
  pipeline to avoid export recursion.

`sas_tracing_test.zig` is a mock-only composition example and regression suite
using the published Core provider and OTLP-JSON writer. It checks W3C propagation,
caller scope/default-parent preservation, delayed export after storage is
released, inert defaults, secret exclusion, bounded queues, allocation failures,
and unchanged service outcomes. It requires no Azure credentials or collector.

Core 0.4.0 changes `Request.headers` to the owned `RequestHeaders` collection.
This package uses the unchanged `setHeader`/`getHeader` and read-only iteration
APIs; no manual request-header memory management is needed. Consumers using raw
request-map mutation should consult Core's `http/request_headers.md` migration
guide.

## Tests

```bash
zig build test --summary all
zig build test -Doptimize=ReleaseSafe --summary all
zig fmt --check root.zig sas.zig sas_tracing_test.zig build.zig build.zig.zon
```
