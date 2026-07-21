# Azure SDK for Zig

> **⚠️ Experimental** — This SDK is an experimental project built with AI assistance
> (GitHub Copilot). It was ported from the
> [Azure SDK for C++](https://github.com/Azure/azure-sdk-for-cpp) as a starting
> point, with all C/C++ dependencies replaced by pure Zig equivalents.
> This is not an official Microsoft or Azure SDK.

Pure Zig implementation of Azure service clients with **zero C dependencies**.

**69 source files · 481 tests · Zig 0.16+**

## Quick Start

```zig
const std = @import("std");
const core = @import("azure_core");
const identity = core.identity;
const kusto_common = @import("azure_kusto_common");
const kusto_data = @import("azure_kusto_data");

pub fn main(init: std.process.Init) !void {
    // Authenticate with environment, workload identity, managed identity, or Azure CLI.
    var transport = core.http.StdHttpTransport.init(init.gpa, init.io);
    defer transport.deinit();
    var credential = try identity.DefaultAzureCredential.init(
        init.gpa,
        init.io,
        transport.asTransport(),
        init.environ_map,
    );
    defer credential.deinit();

    var builder = kusto_common.KustoConnectionStringBuilder.init(
        "https://mycluster.kusto.windows.net",
    );
    _ = builder.withTokenCredential(credential.asCredential());
    const connection = try kusto_common.KustoConnection.init(
        init.gpa,
        builder.build(),
        transport.asTransport(),
        .{},
    );
    defer connection.deinit();

    var client = kusto_data.KustoClient.initWithConnection(connection, .{});
    var result = try client.executeQueryResult(
        init.gpa,
        "MyDatabase",
        "print SDK='azure-sdk-for-zig'",
        null,
    );
    defer result.deinit(init.gpa);
}
```

## Build & Test

Requires [Zig 0.16.0](https://ziglang.org/download/) or later.

```bash
zig build           # compile SDK + example
zig build test      # run all tests
zig build run       # run the example app
zig build run-kusto-examples -- default-query
zig build kusto-live-test     # skips unless Kusto is configured
```

## Architecture

```
Service SDKs (Storage, Key Vault, Tables, Event Hubs, etc.)
    │
azure-core (Zig)
    HTTP Pipeline: RequestId → Telemetry → Logging → Retry → Auth → Decompression → Transport
    Transport: std.http.Client (TLS via std.crypto.tls)
    │
azure-identity: DefaultAzureCredential + 7 credential types
    │
azure-core-amqp: azure-uamqp-zig (pure Zig AMQP 1.0)
```

## Modules

### Core (`azure_core`)

| Module | Description |
|--------|-------------|
| `http.StdHttpTransport` | Buffered and bounded-memory streaming HTTP via `std.http.Client`, with incremental gzip/deflate/zstd response decoding |
| `http.MockTransport` | Canned buffered and streaming responses for unit tests |
| `http.SequenceMockTransport` | Multi-response sequences for retry testing |
| `pipeline.HttpPipeline` | Ordered chain of policies → transport |
| `pipeline.TelemetryPolicy` | Injects `User-Agent` header |
| `pipeline.LoggingPolicy` | Logs requests via `std.log` |
| `pipeline.RetryPolicy` | Exponential backoff with jitter, 429/5xx retry, Retry-After |
| `pipeline.BearerTokenAuthPolicy` | `Authorization: Bearer` with token caching |
| `pipeline.RequestIdPolicy` | `x-ms-client-request-id` UUID |
| `credentials.CachedTokenCredential` | In-memory token cache with TTL |
| `base64` | Base64 + HMAC-SHA256, SHA-256, MD5 helpers |
| `url` | URL parsing, percent-encode/decode (RFC 3986) |
| `errors` | Azure error envelope parsing + `logErrorResponse` |
| `lro` | Long-running operation poller (poll until Succeeded/Failed) |
| `pager` | Generic paged-result iterator (`PipelinePager`) |

`HttpTransport.open` and `HttpPipeline.open` return a heap-backed, single-owner `HttpOperation`. Pass a borrowed `StreamingRequestBody` with `content_length` for `Content-Length`, or omit the length for chunked upload; the source reader only needs to remain alive until `open` returns. Consume the response through `operation.reader()`, then call `finish` to drain and permit connection reuse, or `abort`/`cancel` to close without draining. Always call `deinit`; it aborts any still-active operation. Streaming policy preparation runs once and never retries a consumed reader. `CancellationToken` is checked between upload reads and cannot interrupt an already-blocking reader or socket call.

### Identity (`azure_identity`)

| Credential | Auth method |
|------------|-------------|
| `ClientSecretCredential` | OAuth 2.0 client_credentials |
| `EnvironmentCredential` | `AZURE_TENANT_ID` / `CLIENT_ID` / `CLIENT_SECRET` |
| `ManagedIdentityCredential` | Azure IMDS endpoint |
| `AzureCliCredential` | `az account get-access-token` |
| `WorkloadIdentityCredential` | Kubernetes OIDC federation |
| `ChainedTokenCredential` | First-success fallback chain |
| `DefaultAzureCredential` | Auto-discovery: Env → Workload → MI → CLI |

### Service SDKs

| Package | Clients |
|---------|---------|
| `azure_sdk_container_registry` | `ContainerRegistryClient` and `ContainerRegistryContentClient` with ACR auth, manifests, and resumable blob upload; generated APIs under `protocol` |
| `azure_storage_blobs` | `BlobClient`, `BlobContainerClient`, `SasBlobClient` |
| `azure_storage_queues` | `QueueClient`, `QueueServiceClient`, `SasQueueClient` |
| `azure_storage_files_shares` | `ShareClient`, `ShareDirectoryClient`, `ShareFileClient` |
| `azure_storage_files_datalake` | `DataLakeFileSystemClient`, `DataLakeFileClient` |
| `azure_storage_common` | `StorageSharedKeyCredential`, `SasBuilder`, complete-SAS helpers |
| `azure_keyvault_secrets` | `SecretClient` |
| `azure_keyvault_keys` | `KeyClient`, `CryptographyClient` |
| `azure_keyvault_certificates` | `CertificateClient` |
| `azure_keyvault_admin` | `BackupClient`, `SettingsClient` |
| `azure_data_tables` | `TableClient`, `TableServiceClient` |
| `azure_data_appconfiguration` | `ConfigurationClient` |
| `azure_data_cosmos` | `CosmosClient`, `DatabaseClient`, `ContainerClient` |
| `azure_attestation` | `AttestationClient` |
| `azure_messaging_eventhubs` | `ProducerClient`, `ConsumerClient` |
| `azure_messaging_eventhubs_checkpointstore_blob` | Blob-backed checkpoint store |
| `azure_messaging_servicebus` | `ServiceBusSenderClient`, `ServiceBusReceiverClient`, `ServiceBusAdministrationClient` |
| `azure_kusto_data` | `KustoClient` (experimental buffered and progressive query plus management support) |
| `azure_kusto_ingest` | `StreamingIngestClient`, `QueuedIngestClient`, `ManagedIngestClient`, and queued-ingestion resource discovery |

### Complete SAS Blob and Queue operations

`SasBlobClient` and `SasQueueClient` take an allocator, a complete
service-issued HTTPS SAS URI, and an `HttpTransport`—never a credential or a
caller-supplied pipeline. Existing SAS queries remain opaque and are redacted
by formatting. Requests have no `Authorization` header, disable retries, and
reject redirects.

```zig
var blob = try blobs.SasBlobClient.init(allocator, blob_sas_uri, transport);
defer blob.deinit();
const upload = try blob.uploadFile("data.ndjson", .{});

var queue = try queues.SasQueueClient.init(allocator, queue_sas_uri, transport);
defer queue.deinit();
const submitted = try queue.sendMessage(ingestion_message_bytes);
```

Blob sources have exact sizes: byte slices derive theirs, files are checked
before and after opening, and `uploadReader` requires a supplied size. Sources
are consumed once. Uploads up to 256 MiB stream as `Put Blob`; larger uploads
stream 4 MiB blocks by default. A single request is capped at 5,000 MiB;
blocks are capped at 100 MiB and 50,000 blocks (about 4.77 TiB total) before
an ordered block-list commit. Queue messages are Base64-encoded inside the
Azure Queue XML envelope. Outcomes are `.accepted`, `.rejected` after a
received non-2xx status, or `.unknown` after transport failure; no Kusto
resource discovery, queued-ingestion schema, retry, or status handling is
included.

Kusto datasets and non-null ingestion IDs are allocator-owned; call their `deinit` methods when finished. Buffered Kusto datasets retain the raw response and tagged `KustoFrame` slices (including unknown V2 frames), decode V1 plus normal, progressive, and fragmented V2 tables into owned `KustoValue` values (null, strings, booleans, integers, reals, and Kusto lexical types), and preserve dynamic or unknown cells as raw JSON. Progressive query events instead own one exact raw V2 frame at a time and retain only table schemas and row counts in stream state.

### Kusto feature matrix

| Capability | Primary API | Result and ownership | Important constraints |
|------------|-------------|----------------------|-----------------------|
| Buffered query | `KustoClient.executeQueryResult` | `KustoResult(KustoResponseDataSet)`; call `deinit` | Retries received retryable query failures within the request budget |
| Typed parameters and rows | `kql.QueryParameters`, `kql.Builder`, `KustoRowDecoder` | Bound properties and builders own allocations; typed rows require `deinitRow` | Runtime values are parameters, never interpolated KQL |
| Progressive query | `KustoClient.executeProgressiveQuery` | Heap-owned `ProgressiveQueryStream`; finish or abort, then `deinit` | One exclusive frame/table/row consumer; bounded frames and table state |
| Management | `KustoClient.executeMgmtResult` | `KustoResult(KustoResponseDataSet)`; call `deinit` | Management commands are deliberately non-retryable |
| Direct streaming ingestion | `StreamingIngestClient.ingestResult` | `KustoResult(IngestionResult)`; call `deinit` | At most 4 MiB raw; JSON/MultiJSON/Avro require a named mapping |
| Queued ingestion | `QueuedIngestClient.ingest` | `QueuedIngestionResult`; call `deinit` | Queue acceptance is submission only; resource discovery and complete-SAS storage are required |
| Managed routing and fallback | `ManagedIngestClient.ingestResult` | `KustoResult(ManagedIngestionResult)`; call `deinit` | Fallback occurs only after a replayable retryable known-not-accepted direct failure |
| Queued status | `StatusTrackingHandle.poll` | Owned `StatusPollOutcome`; call `deinit` | Requires table reporting; only `succeeded` is terminal success |

### Executable Kusto examples and live tests

`examples/kusto/main.zig` is one executable runner whose subcommands cover default-credential query, typed parameter query, management, progressive iteration, direct streaming ingestion, queued submission, managed routing/fallback policy, and status polling:

```bash
export KUSTO_CLUSTER_URL='https://<cluster>.<region>.kusto.windows.net'
export KUSTO_DATABASE='<database>'

zig build run-kusto-examples -- default-query
zig build run-kusto-examples -- typed-query
zig build run-kusto-examples -- management
zig build run-kusto-examples -- progressive
```

Ingestion scenarios additionally require `KUSTO_TARGET_TABLE` and `KUSTO_TARGET_MAPPING`. The default NDJSON payload contains one `Message` string field; override it with `KUSTO_INGEST_DATA` when the mapping expects another shape. `KUSTO_STATUS_TIMEOUT_MS` optionally changes the two-minute polling budget.

```bash
export KUSTO_TARGET_TABLE='<table>'
export KUSTO_TARGET_MAPPING='<json-ingestion-mapping>'

zig build run-kusto-examples -- streaming
zig build run-kusto-examples -- queued
zig build run-kusto-examples -- managed
zig build run-kusto-examples -- status
zig build run-kusto-examples -- all
```

`zig build kusto-live-test` runs the same functions serially and returns successful Zig skips when the query or ingestion environment is absent. It is an explicit step and is not part of deterministic `zig build test`. `DefaultAzureCredential` still requires one usable environment, workload-identity, managed-identity, or Azure CLI source. The managed example deterministically selects Queue with a queued-only extent tag; safely forcing a real service to return the retryable direct rejection needed for live fallback is not possible, so that exact branch remains covered by mock protocol tests.

The examples print only counts and enum outcomes. They do not print credentials, authorization headers, ingestion payloads, service-issued SAS URIs, or raw error bodies.

### Kusto authentication and connections

Create authenticated Kusto clients from a shared `KustoConnection`. This example assumes the caller already has a `*TokenCredential` named `credential` and a `*HttpTransport` named `transport`.

```zig
var builder = KustoConnectionStringBuilder.init("https://mycluster.kusto.windows.net");
_ = builder.withTokenCredential(credential);
const properties = builder.build();

const connection = try KustoConnection.init(allocator, properties, transport, .{});
defer connection.deinit();

var client = KustoClient.initWithConnection(connection, .{});
// Or: var ingest_client = StreamingIngestClient.initWithConnection(connection);
```

`KustoConnection` owns copies of its endpoint, scope, user-agent, policy, and token-cache state. It borrows the credential and transport; both must outlive the connection. Derived clients borrow the connection, require no `deinit`, and must not outlive the connection or any in-flight request.

Connections and their derived clients are not safe for concurrent use. Externally serialize all calls, including calls made through separate clients that share a connection.

The existing client constructors remain unauthenticated compatibility APIs only. Passing authentication configuration to them returns `AuthenticatedConnectionRequired`; authenticated code must use `initWithConnection`.

`withAadAppKey` is deprecated and inert for connection creation. It is rejected with `AadAppKeyAuthenticationUnsupported`; supply an `azure_core.credentials.TokenCredential` instead.

Metadata discovery is enabled by default for authenticated connections. Before acquiring a token, the connection makes an unauthenticated, no-follow `GET` request to `/v1/rest/auth/metadata` on the engine endpoint. The response provides login authority details and `KustoServiceResourceId`; the resource ID is used to derive the token scope. Only a 404 or an empty metadata response uses the public-cloud fallback. When the caller supplies a `KustoCloudInfoCache`, discovered metadata is cached for reuse.

Every initial, discovered, or explicitly configured endpoint is validated before token acquisition. Kusto accepts the current well-known public and sovereign Kusto domains by default; custom or private front-door hosts must be added as exact entries in `additional_trusted_hosts` (wildcards and suffix matches are not accepted). A malformed or untrusted endpoint is rejected before the credential is called. For Private Link, use the normal public cluster hostname and configure private DNS; do not pass a `privatelink` URL as the cluster endpoint.

Use `KustoConnectionOptions` to override discovery when needed:

```zig
const options = KustoConnectionOptions{
    .engine_endpoint = "https://mycluster.kusto.windows.net",
    .data_management_endpoint = "https://ingest-mycluster.kusto.windows.net",
    .token_scope = "https://kusto.kusto.windows.net/.default",
};
const connection = try KustoConnection.init(allocator, properties, transport, options);
```

Set `.metadata_mode = .disabled` for offline or custom bootstrap control. Trust validation still runs with discovery disabled, and the token scope defaults to the public-cloud scope unless `token_scope` is explicitly provided. Explicit endpoint and scope overrides are still subject to endpoint validation.

Metadata can expose the login authority for a sovereign or private cloud, but `TokenCredential` is an opaque credential boundary: Kusto cannot reconfigure a generic credential at runtime. Callers using those clouds must construct or configure their credential for the discovered authority themselves; do not assume that every `azure_core` credential supports runtime authority changes.

### Kusto direct streaming ingestion

`StreamingIngestClient.ingestResult` accepts a `StreamingIngestTarget` and a runtime `StreamingIngestSource`: borrowed bytes, a local file, a borrowed one-shot `std.Io.Reader`, a replay-reader factory, or an existing blob URI. Files and readers stream through `HttpPipeline.open`; they are not loaded wholly into memory. Direct streaming is limited to a 4 MiB uncompressed source.

```zig
const ingest = @import("azure_kusto_ingest");
var client = ingest.StreamingIngestClient.initWithConnection(connection);
var result = try client.ingestFromFileResult(
    allocator,
    .{ .database = "db", .table = "events" },
    "events.ndjson",
    .{ .format = .json, .mapping_name = "EventsMapping" },
);
defer result.deinit(allocator);
```

Raw sources use incremental request gzip by default; set `.compression = .none` to send an uncompressed request body. Direct URI sources use the protocol's `sourceKind=uri` JSON body and require `.compression = .none`. Direct streaming accepts CSV, TSV, SCsv, SOHsv, PSV, JSON, MultiJSON, and Avro; JSON, MultiJSON, and Avro require a named mapping. Named mappings are URL-encoded and supported; inline mappings, extent tags/`ingest_if_not_exists`, creation time, validation policy, and first-record skipping are queued-ingestion properties and fail locally before a transport call.

One-shot readers are never retried. Bytes, files, URI sources, and explicit `ReplayReaderFactory` sources may retry only after a received retryable non-2xx response, reopening the source for each attempt while retaining one logical source ID. Source-aware retries honor bounded `Retry-After` delays and otherwise use bounded exponential backoff. A received failure is `.known_not_accepted`; an upload or transport failure after transport entry is `.unknown` and is never replayed. `JsonRows(Row).ndjson` and `.mapping` provide typed serde JSON/NDJSON bytes and a named-mapping definition helper.

### Kusto managed ingestion

`ManagedIngestClient.ingestResult` accepts the same runtime source and returns `KustoResult(ManagedIngestionResult)`. Its owned result records whether `.streaming` or `.queued` was selected; the queued variant retains the full `QueuedIngestionResult`, including resource attempts and an optional `StatusTrackingHandle`. Use `takeTracking` to transfer that handle. The older slice wrappers intentionally flatten queued diagnostics and tracking for compatibility.

Managed ingestion uses one secure, canonical nonzero UUID for both routes. It streams only supported direct formats at or below `IngestOptions.managed_streaming_threshold_bytes` (4 MiB uncompressed by default). Unsupported direct formats, direct-mapping-required formats without a named mapping, precompressed local files, queued-only properties, known-large sources, and Blob URIs without a known raw size go directly to Queue. A known small Blob URI uses the direct URI protocol with request compression normalized to `.none`; queued upload compression, reporting configuration, and flush do not themselves force Queue.

For an unknown-size one-shot reader, managed ingestion reads at most `threshold + 1` bytes. A reader ending within the threshold is retained as replayable bytes. A larger reader is queued once through a bounded prefix-plus-original-tail reader, preserving the original reader's buffered state; it is not reopened after a rejected, incomplete, or ambiguous Blob upload. Direct streaming retries use `options.retry`; fallback happens only after its final retryable, received known-not-accepted failure and only for a replayable effective source. Permanent, cancelled, and ambiguous direct failures never queue. Cancellation is checked during reader classification and between setup, upload, status-table, and Queue phases, but cannot interrupt an already-blocking reader, socket, or transport call.

### Kusto queued-ingestion resource discovery

`ResourceManager` discovers service-issued resources with non-retryable,
authenticated data-management commands (`.get ingestion resources` and
`.get kusto identity token`). It owns immutable deep-copy snapshot leases,
deduplicates and classifies queue/blob/table resources, honors SAS `se`
expiration with safety skew and a separate hard-expiration boundary, and never
formats SAS URIs or authorization contexts. Expired snapshots are served only
when refresh receives a classified transient Kusto failure and the SAS has not
actually expired; malformed, local, authentication, and permanent failures
surface normally.

The manager synchronizes its cache and ranking state, but executes refreshes
outside its lock. Concurrent manager use requires a thread-safe allocator,
executor, and custom time source. Otherwise, externally serialize it.
`DataManagementCommandExecutor` borrows a `KustoConnection`, which remains
serialized-use only. `selectResource` returns an owned resource plus attempt
context; call `reportAttempt` after a later upload/post attempt to update
deterministic account ranking.

Use `default_resource_database` (`"NetDefaultDB"`) unless a service
environment requires another management database.

### Kusto queued ingestion

`QueuedIngestClient` uses a borrowed `ResourceManager` to select a temporary
Blob container and secured-ready queue. It accepts the same
`StreamingIngestSource` variants as direct ingestion: bytes, local files,
one-shot readers, replay-reader factories, and existing Blob URIs. Existing
Blob URIs are queued without uploading. Other sources are gzip-compressed for
text formats, block-uploaded through complete-SAS Blob APIs, then queued
through a complete-SAS Queue API. Storage requests never carry Kusto bearer
authorization.

```zig
const std = @import("std");

var executor = DataManagementCommandExecutor.initWithConnection(connection);
var io_thread = std.Io.Threaded.init_single_threaded;
var manager = try ResourceManager.init(
    allocator,
    io_thread.io(),
    executor.asExecutor(),
    default_resource_database,
    .{},
);
defer manager.deinit();

var client = QueuedIngestClient.initWithConnectionAndResourceManager(connection, &manager);
var submission = try client.ingest(
    allocator,
    .{ .database = "db", .table = "events" },
    .{ .file = "events.ndjson" },
    .{ .format = .json, .mapping_name = "EventsMapping" },
);
defer submission.deinit(allocator);
```

`QueuedIngestionResult.outcome` distinguishes `.queue_accepted`,
`.queue_rejected`, `.queue_unknown`, and `.pre_queue_failed`. Queue acceptance
only means the queue POST succeeded—not that Kusto finished ingestion. The
result owns its stable source ID and safe resource-attempt contexts. A
received Blob rejection may fail over only with a replayable source; after an
accepted Blob upload, a received Queue rejection can try another queue
resource even for a one-shot source. An ambiguous queue POST is never retried
to avoid duplicate ingestion. Callers borrowing a manager must keep it, its executor, transport, and any shared
`KustoConnection` alive, and serialize calls when its executor uses a
connection. `initWithConnection` creates a short-lived manager per call when
one is not injected; use `initWithConnectionAndResourceManager` to retain
resource caching and ranking across calls.

Queued source IDs are nonzero canonical UUIDs (`8-4-4-4-12` hexadecimal);
uppercase input is normalized to lowercase. `.table` and `.queue_and_table`
create the reference-compatible `Pending` Azure Table entity *before* Queue
submission, then put its service-issued complete-SAS URI and exact source-ID
partition/row keys in `IngestionStatusInTable`. The initial entity and all
tracking allocations complete before the Queue POST. Only a known accepted
Queue POST leaves an owned `StatusTrackingHandle` on the result; rejected,
unknown, and pre-Queue outcomes never expose a pollable handle.

```zig
var submission = try client.ingest(
    allocator,
    .{ .database = "db", .table = "events" },
    .{ .file = "events.ndjson" },
    .{
        .format = .json,
        .mapping_name = "EventsMapping",
        .report_level = .failures_and_successes,
        .report_method = .queue_and_table,
    },
);
defer submission.deinit(allocator);

if (submission.takeTracking()) |owned_tracking| {
    var tracking = owned_tracking;
    defer tracking.deinit();
    var polled = try tracking.poll(allocator, .{ .timeout_ms = 5 * 60 * 1_000 });
    defer polled.deinit(allocator);
    switch (polled) {
        .status => |value| switch (value.status) {
            .succeeded => {}, // terminal ingestion success
            .failed, .skipped, .partially_succeeded => {}, // terminal non-success
            .queued, .unknown => {}, // terminal queued/future service value
            .pending => unreachable,
        },
        .stopped => {}, // timeout, cancellation, or a status-resource error
    }
}
```

`QueuedIngestionResult.outcome == .queue_accepted` is never terminal
ingestion success. Polling reads only the service-issued status-table SAS
resource with no bearer authentication, retries idempotent transient/ambiguous
GETs within its explicit budget, and treats auth, other permanent HTTP, and
malformed-entity responses as non-ingestion stops. `StatusPollOptions`
configures interval, timeout, retry backoff, bounded jitter, cancellation, and
clock/sleep/random seams. The handle borrows the transport and is
single-owner—not concurrent-safe; the manager and Kusto connection need not
survive after a handle was created. `report_level = .none` deliberately
creates no handle; use `.failures_and_successes` when a terminal success must
be observed through the table.

For local `.gz` and `.zip` files, automatic and `.none` compression upload the
existing compressed bytes unchanged, preserve that extension in the temporary
blob name, and omit `RawDataSize` unless `raw_size` supplies the original
uncompressed length. `.gzip` deliberately recompresses an input file.
Existing Blob URIs are queued as-is, so explicit `.gzip` or `.none`
compression modes are rejected rather than silently ignored.

Queued one-shot readers may omit a raw size. Their temporary Blob upload uses bounded block streaming (including incremental gzip where selected), and the Queue message omits `RawDataSize`. Such readers remain single-consumption sources: a Blob rejection, incomplete upload, or ambiguous upload is not retried with a reopened reader.

### Kusto request properties, timeouts, and retries

`ClientRequestProperties` emits object-valued `Options` and `Parameters` through structured serde values. Dynamic setters own their keys and values and require `deinit`; borrowed header strings must outlive the request.

- Typed helper areas cover timeout, truncation, progressive results, cache, consistency, resources, and security. Unknown options preserve their JSON types; raw JSON fragments are not accepted. Query parameter values must be strings or Kusto `long` values; encode other scalar types as KQL literal strings such as `datetime(...)` or `dynamic(...)`.
- Query requests default to a 4-minute server timeout and management requests to 10 minutes. Explicit server timeouts range from 1 second through 1 hour with millisecond precision; the client budget defaults to the server timeout plus 30 seconds. `no_request_timeout` requests the maximum server timeout.
- Buffered client timeouts still bound retries and backoff only; they cannot interrupt an in-flight blocking `std.http` call. `ProgressiveQueryOptions.deadline_ms` is checked before and after each pull, and a supplied `CancellationToken` is checked between pulls and during open. Neither can interrupt an already-blocking reader or socket call.
- Explicit application, user, version, and request-ID headers override defaults. Results expose owned `client_request_id` and `activity_id`; dataset `deinit` frees them.
- Buffered result rows are strict about matching the declared column width by default. Set `ClientRequestProperties.setClientResultsReaderAllowVaryingRowWidths` only for services that intentionally emit uneven rows; missing cells remain absent and extra cells are preserved as unknown raw JSON.
- V2 buffered decoding requires a `DataSetHeader` first and `DataSetCompletion` last. It reconstructs progressive or fragmented `DataAppend`/`DataReplace` frames by table ID, treats row-embedded OneAPI errors as partial results, retains unknown frames, and exposes table/row iterators plus ID, kind, primary, properties, and status selectors.
- `executeProgressiveQuery` forces the V2 progressive result options, consumes one complete object from the top-level JSON array at a time, and enforces `max_frame_bytes` plus `max_table_count`. Its `ProgressiveFrame` values own exact raw JSON until `deinit`; `DataAppend` and `DataReplace` remain explicit rather than being flattened. Frame, table, and row pull adapters are exclusive. The row adapter emits one null-row `replace` reset before every replacement batch, followed by append row events, and retains table/dataset completion events so partial failures and cancellation remain visible. All row-adapter payloads are borrowed until its next call.
- Call `ProgressiveQueryStream.finish` to drain and validate the full response. Calling `deinit` without `finish` intentionally aborts without draining. `cancel` first cancels the local operation, then sends a non-retryable management `.cancel query` command targeting the original query `x-ms-client-request-id`; its management result is structured as `KustoResult(KustoResponseDataSet)`.
- Queries may retry; management operations remain non-retryable. Direct streaming disables generic pipeline retry and performs only bounded, source-aware Kusto-layer retries for explicitly replayable sources after known-not-accepted retryable HTTP responses.
- Kusto `*Result` APIs return `KustoResult(T)`: `.ok`, `.partial` (possibly unreliable decoded buffered tables plus an owned `KustoError`), or `.err`; call `deinit`. A streaming `.err` records `.known_not_accepted` for a received non-2xx response and `.unknown` with the transport cause after transport entry fails, while pre-transport credential/policy errors stay in the outer Zig error union. Permanent and partial failures are never retryable.

### Progressive Kusto queries

```zig
var opened = try client.executeProgressiveQuery(
    allocator,
    "db",
    "StormEvents | take 100",
    null,
    .{ .max_frame_bytes = 1024 * 1024, .deadline_ms = 30_000 },
);
const query_stream = switch (opened) {
    .ok => |value| value,
    .err => |*failure| {
        defer failure.deinit();
        return error.KustoQueryFailed;
    },
    .partial => unreachable,
};
defer query_stream.deinit(); // aborts if finish was not called

while (try query_stream.next()) |frame| {
    var owned = frame;
    defer owned.deinit(allocator);
    switch (owned.payload) {
        .table_fragment => |batch| {
            // `batch.action` is .append or .replace; do not flatten replaces.
            _ = batch.table.rows;
        },
        .table_completion => |completion| if (completion.failure) |failure| {
            // In-band partial failure, owned by this frame.
            _ = failure;
        },
        else => {},
    }
}
try query_stream.finish();
```

### Typed KQL and result rows

Use `azure_kusto_data.kql.QueryParameters` to declare parameter types once. Its generated `Name` enum is the only runtime value accepted by `kql.Builder.parameter`, and `bind` copies values into `ClientRequestProperties.Parameters`; values are never interpolated into CSL.

```zig
const kusto = @import("azure_kusto_data");
const Params = struct { account: []const u8, minimum: i64 };
const Binding = kusto.kql.QueryParameters(Params);

var properties = try Binding.bind(allocator, .{ .account = user_input, .minimum = 10 });
defer properties.deinit(allocator);
var query = try kusto.kql.Builder(Binding).init(allocator);
defer query.deinit();
try query.literal("StormEvents | where ");
try query.identifier("Account");
try query.literal(" == ");
try query.parameter(.account);
try query.literal(" | take ");
try query.parameter(.minimum);
var dataset = try client.executeQuery(allocator, "db", query.bytes(), properties);
defer dataset.deinit(allocator);
```

`literal` is comptime-trusted KQL. Runtime identifiers, strings, and parameter references are bracketed or escaped and UTF-8 validated; `unsafeRaw` is the only unescaped runtime path. `kql.DateTime`, `Timespan`, `Decimal`, `Guid`, and `dynamic(value)` provide explicit typed parameter values; their source slices are borrowed only while `bind` runs.

Typed result rows scan a table schema once and allocate values independent of the dataset. Call the decoder's `deinitRow` (or the typed iterator's `deinitRow`) for every successful row. `KustoDateTime`, `KustoTimespan`, `KustoDecimal`, `KustoGuid`, `KustoDynamic`, strings, and cloned `KustoValue` fields are owned decoded values.

```zig
const Row = struct { Account: []u8, Count: i64 };
const table = dataset.primaryTable().?;
const Decoder = kusto.KustoRowDecoder(Row);
const decoder = try table.rowDecoder(Row);
var row = try decoder.rowAs(&table.rows[0], allocator);
defer Decoder.deinitRow(&row, allocator);
```

### Kusto compatibility and migration

Valid legacy entry points remain for the current compatibility release, but authenticated applications should migrate now:

| Previous entry point or assumption | Current migration |
|------------------------------------|-------------------|
| `KustoClient.init`, `StreamingIngestClient.init`, `QueuedIngestClient.init`, or `ManagedIngestClient.init` with authentication fields | Create one owned `KustoConnection`, then use each client's `initWithConnection` constructor |
| `withAadAppKey` | Supply a `TokenCredential` through `withTokenCredential`; app-key connection creation returns `AadAppKeyAuthenticationUnsupported` |
| `executeQuery`, `executeMgmt`, or `execute` generic failures | Prefer the corresponding `*Result` API to retain structured `.ok`, `.partial`, and `.err` outcomes |
| `ingestFromSlice*` and `ingestFromBlob*` compatibility wrappers | Prefer runtime-source `ingestResult`/`ingest`; flattening wrappers intentionally discard queued attempts and status tracking |
| Any string as a queued or managed source ID | Supply a nonzero canonical UUID or omit it for secure generation; uppercase UUIDs normalize to lowercase |
| Queue acceptance as completed ingestion | Treat it only as submission; request table reporting and poll a transferred `StatusTrackingHandle` for terminal status |
| Borrowed response strings or implicit cleanup | Treat datasets, errors, ingestion IDs, frames, status values, and typed rows as owned according to their documented `deinit` method |

`KustoConnection` and clients derived from it are serialized-use only; externally synchronize shared calls. Cancellation and deadlines are best-effort boundaries between reads, retries, and storage phases and cannot interrupt an already-blocking system call. Unknown streaming or Queue outcomes are deliberately not replayed. Endpoint discovery accepts only trusted Kusto origins unless an exact additional host is configured. Complete-SAS Blob, Queue, and Table clients never receive the Kusto bearer credential, reject redirects, and redact SAS query values from formatting.

These compatibility wrappers are retained for one release so valid older call sites can migrate without an immediate source break. Unavoidable behavior changes remain: legacy app-key authentication is rejected, real queued submission distinguishes rejected/unknown/pre-Queue outcomes, and allocator-owned result graphs require explicit cleanup.

### Kusto parity references

Kusto behavior and protocol choices were compared against the [Rust SDK](https://github.com/Azure/azure-kusto-rust), [Go SDK](https://github.com/Azure/azure-kusto-go), [Java SDK](https://github.com/Azure/azure-kusto-java), the [Kusto REST API](https://learn.microsoft.com/azure/data-explorer/kusto/api/rest/), and the [Kusto ingestion client reference](https://learn.microsoft.com/azure/data-explorer/kusto/api/netfx/kusto-ingest-client-reference). Zig intentionally stays stricter where replay or acceptance is ambiguous.

### Infrastructure

| Package | Description |
|---------|-------------|
| `azure_core_amqp` | AMQP 1.0 via azure-uamqp-zig |
| `azure_core_tracing` | `Span`, `Tracer`, `NoopTracer` |
| `azure_core_testing` | `PlaybackTransport` for recorded HTTP replay |
| `azure_core_perf` | `benchmark()` harness with timing stats |

## Dependencies

The SDK uses only the Zig standard library plus two small Zig packages:

| Purpose | Package |
|---------|---------|
| HTTP, TLS, crypto, compression | `std` (Zig standard library) |
| Typed JSON + XML (de)serialization | [serde.zig](https://github.com/cataggar/serde.zig) |
| AMQP 1.0 protocol | [azure-uamqp-zig](https://github.com/cataggar/azure-uamqp-zig) |

## Using as a Dependency

Add to your `build.zig.zon`:

```zon
.dependencies = .{
    .azure_sdk = .{
        .url = "git+https://github.com/cataggar/azure-sdk-for-zig#<commit>",
        .hash = "...",
    },
},
```

Then in `build.zig`:

```zig
const azure = b.dependency("azure_sdk", .{});
exe.root_module.addImport("azure_core", azure.module("azure_core"));
exe.root_module.addImport("azure_identity", azure.module("azure_identity"));
```

## Background

This project started as a port of the [Azure SDK for C++](https://github.com/Azure/azure-sdk-for-cpp),
preserving the same layered architecture (core → identity → service SDKs) while
replacing every C/C++ dependency with Zig standard library equivalents:

| Original (C++) | Zig Replacement |
|----------------|-----------------|
| libcurl / WinHTTP | `std.http.Client` |
| OpenSSL | `std.crypto.tls`, `std.crypto.hash`, `std.crypto.auth.hmac` |
| nlohmann/json + libxml2 | [serde.zig](https://github.com/cataggar/serde.zig) (typed schemas) |
| azure-uamqp-c | azure-uamqp-zig |
| CMake + vcpkg | `build.zig` |
| Google Test | `std.testing` |

## License

MIT — see [LICENSE.txt](LICENSE.txt).
