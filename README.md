# azure_sdk_kusto

Azure Data Explorer (Kusto) Common, Data, and Ingest APIs ship as one
independently versioned package:

| Namespace | Purpose |
| --- | --- |
| [`common`](common/README.md) | Connections, cloud discovery, shared types, and errors |
| [`data`](data/README.md) | Query, management, progressive results, KQL, and typed rows |
| [`ingest`](ingest/README.md) | Streaming, managed, and queued ingestion |

The current package version is `0.3.1`. All namespaces release together.
`kusto.version` and `kusto.user_agent_prefix` derive from the package manifest;
the default `User-Agent` and `x-ms-client-version` values use that prefix.
Dependencies pin published Core **0.4.1**, Storage Common **0.4.1**, Blobs
**0.4.1**, and Queues **0.3.1** for complete-SAS queued ingestion.

## Feature matrix

| Capability | Primary API | Result and ownership | Important constraint |
| --- | --- | --- | --- |
| Buffered query | `KustoClient.executeQueryResult` | `KustoResult(KustoResponseDataSet)`; call `deinit` | Retries received retryable query failures within the request budget |
| Typed parameters and rows | `kql.QueryParameters`, `kql.Builder`, `KustoRowDecoder` | Bindings/builders own allocations; typed rows require `deinitRow` | Runtime values are parameters, never interpolated KQL |
| Progressive query | `KustoClient.executeProgressiveQuery` | Heap-owned `ProgressiveQueryStream`; finish or abort, then `deinit` | One exclusive frame/table/row consumer |
| Management | `KustoClient.executeMgmtResult` | `KustoResult(KustoResponseDataSet)`; call `deinit` | Management commands are non-retryable |
| Direct ingestion | `StreamingIngestClient.ingestResult` | `KustoResult(IngestionResult)`; call `deinit` | At most 4 MiB raw |
| Queued ingestion | `QueuedIngestClient.ingest` | `QueuedIngestionResult`; call `deinit` | Queue acceptance is submission only |
| Managed routing | `ManagedIngestClient.ingestResult` | `KustoResult(ManagedIngestionResult)`; call `deinit` | Fallback requires replayable known-not-accepted direct failure |
| Queued status | `StatusTrackingHandle.poll` | Owned `StatusPollOutcome`; call `deinit` | Only `succeeded` is terminal success |

Kusto datasets, errors, frames, non-null ingestion IDs, status values, and
typed rows are allocator-owned according to their documented `deinit` method.
Buffered results retain raw responses and tagged V1/V2 frames, decode typed
cells, and preserve dynamic or unknown cells as raw JSON.

## Authentication and shared connections

Create authenticated clients from one owned `KustoConnection`:

```zig
const core = @import("azure_sdk_core");
const kusto = @import("azure_sdk_kusto");
const common = kusto.common;
const data = kusto.data;

var std_transport = core.http.StdHttpTransport.init(allocator, io);
var crypto_provider = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    std_transport.asTransport(),
    crypto_provider.asProvider(),
);

var builder = common.KustoConnectionStringBuilder.init(
    "https://mycluster.kusto.windows.net",
);
_ = builder.withTokenCredential(credential);

const connection = try common.KustoConnection.init(
    allocator,
    builder.build(),
    runtime,
    .{},
);
defer connection.deinit();

var client = data.KustoClient.init(connection, .{});
```

`KustoConnection` owns copies of its endpoint, scope, user-agent, policy, and
token-cache state. It copies `HttpRuntime` by value while borrowing the
credential plus the runtime's transport and crypto contexts. Those contexts
must outlive the connection, every derived client, and every open operation.
Derived clients borrow the connection, require no `deinit`, and must not
outlive it. Provider failures propagate directly; Kusto never falls back to
`std.crypto` or another transport.

Connections and derived clients are not safe for concurrent use. Externally
serialize all calls, including calls through separate clients sharing one
connection.

## Optional tracing

Configure tracing on the shared connection's existing options. The complete
Core configuration is passed unchanged to both the unauthenticated discovery
pipeline and the canonical authenticated query/management/streaming pipeline:

```zig
const instrumentation: core.tracing.InstrumentationOptions = .{
    .provider = provider.asProvider(),
    .scope_name = "azure_sdk_kusto",
    .scope_version = kusto.version,
    .namespace = "Microsoft.Kusto",
    .parent_context = optional_parent,
};
const connection = try common.KustoConnection.init(
    allocator,
    builder.build(),
    runtime,
    .{ .instrumentation = instrumentation },
);
defer connection.deinit();
```

`provider` and `scope_name` are required when instrumentation is enabled.
`null` is the default and is inert: no spans, trace header injection, exporter
calls, workers, or environment discovery. Tracing is not stored in `HttpRuntime`.
Existing constructors and credential/trust/retry boundaries remain unchanged.
A cloud-cache hit does not send or trace another discovery request.

Queued clients snapshot the connection's tracing configuration at construction.
An explicit `QueuedIngestClient.Options.instrumentation` overrides that snapshot
for Storage operations, or supplies tracing when only a runtime/resource manager
is used. `QueuedIngestClient.setInstrumentation(options)` changes subsequent
Storage requests; `null` disables them. It does not reconfigure a connection's
Kusto requests or already-issued handles. Managed clients use the connection
for streaming and the queued snapshot for Storage, so configure the connection
before deriving clients.

Every queued Blob/Queue client receives **only** this tracing configuration via
the published Storage setters. Status entity writes and fresh status-read
pipelines use the same options. Caller scope, version, namespace and default
parent are never replaced with Storage defaults. No Kusto credentials, arbitrary
caller policies, generic retries, or redirect following enter these SAS paths.
Existing bounded resource failover/polling decisions remain the Kusto layer's
responsibility.

### Ownership and status handles

Instrumentation options are copied by value, but their provider, scope/version/
namespace strings, and parent tracestate remain borrowed. Keep providers,
exporters and runtime backend contexts at stable addresses. Those values and
metadata strings must outlive **every** client and retained status handle using
them, not merely the initiating connection. Unlike the connection's endpoint,
token-scope and user-agent copies, tracing metadata is not connection-owned.

`takeTracking()` still transfers an independently owned handle that can be used
after the initiating client, result, resource manager and connection have been
destroyed. Its copied tracing options do not retain the connection or its policy
objects. The external runtime/provider/metadata borrows must remain valid.
`StatusTrackingHandle.setInstrumentation(options)` updates future status reads/
writes only; `null` disables them. Handles are single-owner; do not shallow-copy
and deinitialize them twice.

Core's concrete provider owns completed span data. Once all borrowers have
finished, request/response/client/configuration storage may be released before
explicit export. Kusto never drains, flushes, shuts down or owns the provider.
Applications manage bounded `drain`/`forceFlush`/`shutdown` calls and handle their
errors separately from service outcomes. Inspect counters for dropped spans and
propagation errors. HTTP exporters must suppress instrumentation or use an
uninstrumented pipeline to prevent export recursion.

### Span boundaries and data

The MVP is one logical HTTP span per pipeline request, not a span around the
entire multi-request ingestion or polling workflow. Query retries inside Core's
retry policy share that HTTP span. Existing Kusto-level failover or streaming
retry requests each enter the pipeline normally; no per-attempt span API is added.
Buffered HTTP responses end at `send` return. Progressive queries, streaming
ingestion and SAS `open` spans end at response headers, before subsequent reads,
draining or result parsing. Later body/parse/cancellation errors do not rewrite
an already-ended span. Full streaming lifetimes remain separate work.

Built-in attributes omit KQL, databases/table paths, ingestion payloads, SAS
queries, queue envelopes, identity tokens, authorization/cookies and arbitrary
headers. Explicit metadata/tracestate must not contain secrets. Structured
Kusto results, storage accepted/rejected/unknown classifications, and
pre-dispatch failures remain unchanged when telemetry drops or export fails.

`zig build test-tracing` runs the offline public-API integration suite using
mock HTTP, including discovery, all request classes, managed routing, actual
published Blob/Queue SAS clients, retained status polling, W3C correlation,
borrowed lifetimes, and telemetry failure isolation. It needs no Azure
credentials, network access or collector.

Core 0.4 changes request maps to owned `RequestHeaders`. This package's existing
`setHeader`/`getHeader` and read-only iteration are compatible; response and
capture-map ownership is unchanged. Applications using raw request-map mutation
should consult Core's README for the owned request-header APIs.

Data and streaming clients derive from the shared connection; queued clients
can also use a standalone runtime/resource manager.
`withAadAppKey` is deprecated and rejected with
`AadAppKeyAuthenticationUnsupported`; use an
`azure_sdk_core.credentials.TokenCredential`.

## Cloud discovery and endpoint trust

Authenticated connections perform an unauthenticated, no-follow request to
`/v1/rest/auth/metadata` before acquiring a token. The response supplies login
authority details and `KustoServiceResourceId`; the resource ID determines the
token scope. Only a 404 or empty response uses the public-cloud fallback.

Every initial, discovered, or configured endpoint is validated before token
acquisition. Public and sovereign Kusto domains are trusted by default.
Custom/private front doors require an exact `additional_trusted_hosts` entry;
wildcards and suffix matching are not accepted. For Private Link, use the
normal public cluster hostname with private DNS.

```zig
const options = common.KustoConnectionOptions{
    .engine_endpoint = "https://mycluster.kusto.windows.net",
    .data_management_endpoint = "https://ingest-mycluster.kusto.windows.net",
    .token_scope = "https://kusto.kusto.windows.net/.default",
};
```

Set `.metadata_mode = .disabled` for offline/custom bootstrap control. Trust
validation still runs. A generic `TokenCredential` cannot be reconfigured by
Kusto at runtime; sovereign/private-cloud callers must configure the
credential authority themselves.

## Compatibility migration

| Previous entry point or assumption | Migration |
| --- | --- |
| Transport-only or `initWithConnection` client constructors | Create one `KustoConnection` with `HttpRuntime`, then call the client's `init` |
| `withAadAppKey` | Supply a `TokenCredential` |
| Generic `executeQuery`, `executeMgmt`, or `execute` failures | Prefer `*Result` APIs retaining `.ok`, `.partial`, and `.err` |
| Slice/Blob ingestion compatibility wrappers | Prefer runtime-source `ingestResult`/`ingest` |
| Any string as source ID | Supply a nonzero canonical UUID or omit it for secure generation |
| Queue acceptance means completion | Request table reporting and poll a tracking handle |
| Borrowed results or implicit cleanup | Follow each owned value's `deinit` contract |

Cancellation and deadlines are best-effort boundaries between reads, retries,
and storage phases; they cannot interrupt an already-blocking system call.
Ambiguous streaming or Queue outcomes are not replayed. Complete-SAS Storage
clients never receive the Kusto bearer credential, reject redirects, and
redact SAS query values.

## References

Behavior was compared with the
[Rust](https://github.com/Azure/azure-kusto-rust),
[Go](https://github.com/Azure/azure-kusto-go), and
[Java](https://github.com/Azure/azure-kusto-java) SDKs, the
[Kusto REST API](https://learn.microsoft.com/azure/data-explorer/kusto/api/rest/),
and the
[ingestion client reference](https://learn.microsoft.com/azure/data-explorer/kusto/api/netfx/kusto-ingest-client-reference).
Zig remains stricter where replay or acceptance is ambiguous.

## Development

Build the package and all namespace tests from its root:

```bash
zig build test --summary all
zig build test-tracing --summary all
zig build test -Doptimize=ReleaseSafe --summary all
```

Runnable Data and Ingest scenarios live in the
[standalone Kusto example project](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto).
