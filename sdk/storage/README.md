# Azure Storage packages

The Storage family is split into independently versioned packages:

| Package | Purpose |
| --- | --- |
| [`azure_sdk_storage_common`](common/README.md) | Shared-key credentials, SAS construction, and complete-SAS helpers |
| [`azure_sdk_storage_blobs`](blobs/README.md) | Blob, container, and complete-SAS Blob clients |
| [`azure_sdk_storage_queues`](queues/README.md) | Queue, service, and complete-SAS Queue clients |
| [`azure_sdk_storage_files_shares`](files/shares/README.md) | Azure Files share, directory, and file clients |
| [`azure_sdk_storage_files_datalake`](files/datalake/README.md) | Data Lake filesystem and file clients |

## Complete-SAS Blob and Queue clients

`SasBlobClient` and `SasQueueClient` take an allocator, a complete
service-issued HTTPS SAS URI, and an `HttpTransport`. They never accept a
credential or caller-supplied pipeline. Existing SAS queries remain opaque and
are redacted by formatting. Requests omit `Authorization`, disable retries,
and reject redirects.

```zig
var blob = try blobs.SasBlobClient.init(allocator, blob_sas_uri, transport);
defer blob.deinit();
const upload = try blob.uploadFile("data.ndjson", .{});

var queue = try queues.SasQueueClient.init(allocator, queue_sas_uri, transport);
defer queue.deinit();
const submitted = try queue.sendMessage(ingestion_message_bytes);
```

Byte slices derive their exact size, files are checked before and after
opening, and `uploadReader` requires a supplied size. Sources are consumed
once. Uploads up to 256 MiB stream as `Put Blob`; larger uploads use 4 MiB
blocks by default. One request is capped at 5,000 MiB; blocks are capped at
100 MiB and 50,000 blocks.

Queue messages are Base64-encoded inside the Azure Queue XML envelope.
Outcomes are `.accepted`, `.rejected` after a received non-2xx status, or
`.unknown` after transport failure.

## Development

Storage modules are currently tested through the root workspace:

```bash
zig build test --summary all
```

Package-local builds are introduced in dependency order, beginning with
Storage Common.
