# azure_sdk_kusto

Azure Data Explorer (Kusto) Common, Data, and Ingest APIs ship as one
independently versioned package:

| Namespace | Purpose |
| --- | --- |
| [`common`](common/README.md) | Connections, cloud discovery, shared types, and errors |
| [`data`](data/README.md) | Query, management, progressive results, KQL, and typed rows |
| [`ingest`](ingest/README.md) | Streaming, managed, and queued ingestion |

The package begins at `0.1.0`. All namespaces release together. Ingest uses
the Storage packages required for complete-SAS queued ingestion.

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
const kusto = @import("azure_sdk_kusto");
const common = kusto.common;
const data = kusto.data;

var builder = common.KustoConnectionStringBuilder.init(
    "https://mycluster.kusto.windows.net",
);
_ = builder.withTokenCredential(credential);

const connection = try common.KustoConnection.init(
    allocator,
    builder.build(),
    transport,
    .{},
);
defer connection.deinit();

var client = data.KustoClient.initWithConnection(connection, .{});
```

`KustoConnection` owns copies of its endpoint, scope, user-agent, policy, and
token-cache state. It borrows the credential and transport; both must outlive
the connection. Derived clients borrow the connection, require no `deinit`,
and must not outlive it.

Connections and derived clients are not safe for concurrent use. Externally
serialize all calls, including calls through separate clients sharing one
connection.

The existing client constructors remain unauthenticated compatibility APIs.
Authentication configuration passed to them returns
`AuthenticatedConnectionRequired`; authenticated code must use
`initWithConnection`. `withAadAppKey` is deprecated and rejected with
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
| Client `init` methods with authentication fields | Create one `KustoConnection`, then use `initWithConnection` |
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
```

Runnable Data and Ingest scenarios live in the
[standalone Kusto example project](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto).
