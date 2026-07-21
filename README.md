# Azure SDK for Zig

> **⚠️ Experimental** — This SDK is an experimental project built with AI assistance
> (GitHub Copilot). It was ported from the
> [Azure SDK for C++](https://github.com/Azure/azure-sdk-for-cpp) as a starting
> point, with all C/C++ dependencies replaced by pure Zig equivalents.
> This is not an official Microsoft or Azure SDK.

Pure Zig implementation of Azure service clients with **zero C dependencies**.

**60 source files · 358 tests · Zig 0.16+**

## Quick Start

```zig
const std = @import("std");
const core = @import("azure_core");
const identity = @import("azure_identity");

// Authenticate with DefaultAzureCredential (env vars, managed identity, or CLI).
var transport = core.http.StdHttpTransport.init(allocator, io);
var cred = identity.DefaultAzureCredential.init(allocator, transport.asTransport(), std.posix.environ);

// Use any service client.
var client = @import("azure_keyvault_secrets").SecretClient.init(
    "https://myvault.vault.azure.net",
    cred.asCredential(),
    transport.asTransport(),
    .{},
);
const secret = try client.getSecret(allocator, "my-secret");
```

## Build & Test

Requires [Zig 0.16.0](https://ziglang.org/download/) or later.

```bash
zig build           # compile SDK + example
zig build test      # run all 219 tests
zig build run       # run the example app
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
| `azure_kusto_ingest` | `StreamingIngestClient`, `QueuedIngestClient`, and queued-ingestion resource discovery |

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
uppercase input is normalized to lowercase. Only `report_method = .queue` is
currently supported. `.table` and `.queue_and_table` are rejected locally
because status-table reporting is not implemented yet.

For local `.gz` and `.zip` files, automatic and `.none` compression upload the
existing compressed bytes unchanged, preserve that extension in the temporary
blob name, and omit `RawDataSize` unless `raw_size` supplies the original
uncompressed length. `.gzip` deliberately recompresses an input file.
Existing Blob URIs are queued as-is, so explicit `.gzip` or `.none`
compression modes are rejected rather than silently ignored.

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
