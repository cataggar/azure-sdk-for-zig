# Kusto Ingest namespace

Kusto direct streaming, managed routing, queued ingestion, resource discovery,
and queued status tracking.

Import it from the consolidated package:

```zig
const ingest = @import("azure_sdk_kusto").ingest;
```

## Direct streaming ingestion

`StreamingIngestClient.ingestResult` accepts borrowed bytes, a local file, a
borrowed one-shot `std.Io.Reader`, a replay-reader factory, or an existing Blob
URI. Files/readers stream through `HttpPipeline.open`; they are not loaded
entirely into memory. Direct ingestion is limited to 4 MiB uncompressed.

```zig
const ingest = @import("azure_sdk_kusto").ingest;
var client = ingest.StreamingIngestClient.initWithConnection(connection);
var result = try client.ingestFromFileResult(
    allocator,
    .{ .database = "db", .table = "events" },
    "events.ndjson",
    .{ .format = .json, .mapping_name = "EventsMapping" },
);
defer result.deinit(allocator);
```

Raw sources use incremental request gzip by default. URI sources use the
protocol's `sourceKind=uri` body and require `.compression = .none`.
JSON, MultiJSON, and Avro require a named mapping.

One-shot readers are never retried. Replayable sources may retry only after a
received retryable non-2xx response. A received failure is
`.known_not_accepted`; upload/transport failure after transport entry is
`.unknown` and is never replayed.

## Managed ingestion

`ManagedIngestClient.ingestResult` chooses streaming or queued ingestion and
returns which route was used. The queued result retains resource attempts and
an optional `StatusTrackingHandle`.

One secure nonzero UUID is shared across routes. Direct streaming is selected
only for supported formats at or below
`managed_streaming_threshold_bytes` (4 MiB by default). Queued-only properties,
known-large sources, unsupported formats, and Blob URIs without known raw size
go directly to Queue.

An unknown-size one-shot reader is classified with at most `threshold + 1`
bytes. Small readers become replayable bytes; larger readers are queued through
a bounded prefix-plus-tail reader without reopening the source.

Fallback occurs only after the final retryable, received,
known-not-accepted direct failure and only for a replayable source. Permanent,
cancelled, and ambiguous failures never queue.

## Resource discovery

`ResourceManager` executes non-retryable authenticated management commands to
discover ingestion resources and identity tokens. It owns immutable deep-copy
snapshot leases, classifies queue/blob/table resources, honors SAS expiry and
safety skew, and never formats SAS URIs or authorization contexts.

Refreshes execute outside the cache lock. Concurrent use requires a
thread-safe allocator, executor, and clock; otherwise externally serialize.
Transient refresh failures may serve an expired snapshot only while its SAS
resources remain actually valid.

Use `default_resource_database` (`"NetDefaultDB"`) unless the service
environment requires another management database.

## Queued ingestion

Queued ingestion selects a temporary complete-SAS Blob container and
secured-ready Queue. Existing Blob URIs are queued without upload. Other
sources are compressed where appropriate, block-uploaded through the
complete-SAS Blob client, then posted through the complete-SAS Queue client.
Storage requests never carry Kusto bearer authorization.

```zig
var executor = ingest.DataManagementCommandExecutor.initWithConnection(connection);
var io_thread = std.Io.Threaded.init_single_threaded;
var manager = try ingest.ResourceManager.init(
    allocator,
    io_thread.io(),
    executor.asExecutor(),
    ingest.default_resource_database,
    .{},
);
defer manager.deinit();

var client = ingest.QueuedIngestClient.initWithConnectionAndResourceManager(
    connection,
    &manager,
);
var submission = try client.ingest(
    allocator,
    .{ .database = "db", .table = "events" },
    .{ .file = "events.ndjson" },
    .{ .format = .json, .mapping_name = "EventsMapping" },
);
defer submission.deinit(allocator);
```

Outcomes distinguish `.queue_accepted`, `.queue_rejected`, `.queue_unknown`,
and `.pre_queue_failed`. Queue acceptance is submission, not completed
ingestion. Blob failover requires a replayable source. A received Queue
rejection may try another queue after one accepted Blob upload; an ambiguous
Queue POST is never retried.

Queued source IDs are nonzero canonical lowercase UUIDs. Table reporting
creates the `Pending` Azure Table entity before Queue submission. Only a known
accepted Queue POST exposes an owned tracking handle.

## Status polling

Transfer the accepted result's tracking handle and poll the complete-SAS
status table:

```zig
if (submission.takeTracking()) |owned| {
    var tracking = owned;
    defer tracking.deinit();
    var outcome = try tracking.poll(
        allocator,
        .{ .timeout_ms = 5 * 60 * 1_000 },
    );
    defer outcome.deinit(allocator);
}
```

Polling retries idempotent transient/ambiguous GETs within its explicit
budget. Authentication, permanent HTTP, and malformed-entity failures stop
polling without becoming ingestion failures. The handle borrows its transport,
is single-owner, and is not concurrency-safe.

Use `.failures_and_successes` reporting when terminal success must be observed.
`.queue_accepted` alone is never terminal success.

## Compressed and one-shot sources

Local `.gz` and `.zip` files are uploaded unchanged for automatic or `.none`
compression and omit `RawDataSize` unless `raw_size` supplies it. `.gzip`
deliberately recompresses. Existing Blob URIs are queued as-is.

One-shot readers may omit a raw size and use bounded block streaming. They
remain single-consumption sources: rejected, incomplete, or ambiguous Blob
uploads are not reopened.

## Examples and development

See the
[Ingest examples](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto/ingest)
for streaming, queued, managed, and status-tracking scenarios.

```bash
zig build test --summary all
```
