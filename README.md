# azure_sdk_storage_queues

Azure Queue Storage clients, including `QueueClient`, `QueueServiceClient`, and
the complete-SAS `SasQueueClient`.

Version: **0.3.0**. Release branch: `sdk/storage_queues`. The package pins
published `azure_sdk_core` **0.4.0** and `azure_sdk_storage_common` **0.4.0**,
plus `serde`. `queues.version` and `queues.user_agent_prefix` follow the manifest.
The prefix is available for a caller-owned `TelemetryPolicy`; clients do not
install a user-agent policy implicitly.

All clients use Core's canonical HTTP runtime. `QueueClient` and
`QueueServiceClient` copy a caller-built `core.http.HttpPipeline`;
`SasQueueClient` copies a `core.http.HttpRuntime`. The pipeline policy pointers
and runtime transport/crypto contexts are borrowed and must outlive the clients
and their operations.

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto_provider = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto_provider.asProvider(),
);
var auth_policy = core.http.BearerTokenAuthPolicy.init(
    allocator,
    credential,
    queues.auth_scopes,
);
defer auth_policy.deinit();
var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
const pipeline = core.http.HttpPipeline.init(runtime, &policies);
var client = queues.QueueServiceClient.init(endpoint, pipeline);
```

See [`sas.zig`](sas.zig) for complete-SAS message encoding and outcome semantics.

## Opt-in tracing

Configure the canonical pipeline before constructing ordinary service or queue
clients. Derived queue clients and copied pipelines preserve all instrumentation
fields; changing the original pipeline does not reconfigure existing copies:

```zig
var pipeline = core.http.HttpPipeline.init(runtime, &policies);
const instrumentation: core.tracing.InstrumentationOptions = .{
    .provider = provider.asProvider(),
    .scope_name = "azure_sdk_storage_queues",
    .scope_version = queues.version,
    .namespace = "Microsoft.Storage",
    .parent_context = optional_parent,
};
pipeline.setInstrumentation(instrumentation);
var service = queues.QueueServiceClient.init(endpoint, pipeline);
var queue = service.getQueueClient(queue_name);
```

Complete-SAS clients retain their existing constructor and accept tracing only:

```zig
var sas_client = try queues.SasQueueClient.init(allocator, complete_sas_url, runtime);
defer sas_client.deinit();
sas_client.setInstrumentation(instrumentation);
// sas_client.setInstrumentation(null) disables subsequent tracing.
```

`CompleteSasQueueClient` is the same type. It forwards caller scope, version,
namespace and default parent unchanged to Storage Common's `sendWithOptions`.
A Kusto caller may therefore retain its own service scope. No arbitrary caller
pipeline or credential policies are accepted. SAS sends stay non-retrying and
no-redirect; only HTTP 201 is an accepted Queue message outcome.

Defaults are inert. Providers/exporters/backend contexts must stay at stable
addresses, and instrumentation strings and parent tracestate must outlive all
clients using them. Owning SAS clients must not be shallow-copied and deinitialized
twice. Core's concrete provider owns completed span data, so clients, request
storage, and configuration strings can be released before explicit export once
their operations have ended. Clients never drain, flush, or shut down providers.

There is one logical HTTP span per request, not a full service-method lifetime.
SAS uses `open`: the span ends at response headers, before body draining.
Post-header drain failures cannot change an accepted/rejected outcome or the
completed span. Non-201 2xx Queue responses remain protocol rejections even
though the HTTP span has no HTTP error status. Pre-dispatch validation/allocation
failures dispatch nothing; failures after backend entry remain `unknown`, which
does not prove the server received the request. Ordinary result parsing occurs
after the HTTP span, too.

Built-in spans exclude paths, query/SAS signatures, message bodies, pop receipts,
authorization, cookies, and arbitrary headers. Explicit metadata/tracestate must
not contain secrets. Telemetry allocation errors and bounded drops cannot replace
service outcomes: inspect provider counters and handle explicit `drain`,
`forceFlush`, and `shutdown` errors separately. There is no automatic export,
worker, environment discovery, or collector traffic; HTTP exporters must suppress
tracing or use an uninstrumented pipeline.

`tracing_test.zig` exercises real mock service/direct/derived Queue operations,
wire/span correlation, delayed export, inert defaults, SAS outcome boundaries,
and allocator/exporter failures without Azure credentials or collector access.
The Storage Blobs package additionally provides a runnable `tracing-mock`
reference-writer example. Full streaming lifetimes, per-attempt spans, production
OTLP transport, and per-call service-client parent APIs remain separate work.

Core 0.4 uses owned `RequestHeaders`; this package uses compatible
`setHeader`/`getHeader` APIs. Applications mutating raw request maps should follow
Core's `http/request_headers.md` migration guide.

```bash
zig build test --summary all
zig build test -Doptimize=ReleaseSafe --summary all
zig build examples
zig build complete-sas-message -- <queue-sas-url> <message>
```

`test` executes mock tests and compiles the live SAS example without running it.
