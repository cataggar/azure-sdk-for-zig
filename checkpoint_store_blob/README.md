# Event Hubs `checkpoint_store_blob` namespace

Blob-backed checkpoint storage for Azure Event Hubs consumers.

The namespace is exposed through `azure_sdk_eventhubs.checkpoint_store_blob`
and versions with the [`azure_sdk_eventhubs`](../README.md) package. Its
implementation is [`checkpoint_store.zig`](../checkpoint_store.zig) on the
`sdk/eventhubs` package branch.

## Wire format

State lives in blob **metadata**, not in the blob body, so a container can be
shared with processors built on the Go and Rust Event Hubs SDKs. Blob bodies
are always empty.

| Blob | Path | Metadata |
| --- | --- | --- |
| Checkpoint | `{namespace}/{hub}/{group}/checkpoint/{partition}` | `sequencenumber`, `offset` |
| Ownership | `{namespace}/{hub}/{group}/ownership/{partition}` | `ownerid` |

`offset` is an opaque service-defined token, not a number. Event Hubs returns
non-numeric offsets under geo-disaster-recovery, so it is carried as a string.

Ownership additionally uses the blob's own `ETag` and `Last-Modified`:

- `claimOwnership` renews an existing claim with `If-Match` on the caller's
  ETag, and creates a new one with `If-None-Match: *`. A partition lost to
  another processor is omitted from the result rather than reported as an
  error.
- `listOwnership` returns the ETag needed for the next compare-and-swap and
  `last_modified_time` in Unix seconds, which load balancing uses to expire
  ownership a processor stopped renewing.
- An empty `owner_id` means a previous owner relinquished the partition. The
  service omits metadata keys with empty values, so a missing `ownerid` is
  read back as relinquished.

Slices returned by the store are allocator-owned; free them with
`freeCheckpoints` or `freeOwnerships`.

Construct `BlobContainerClient` with an `HttpPipeline` built from the
application's `HttpRuntime`. Derived checkpoint blob clients preserve that
runtime, including its SDK crypto provider. The pipeline's borrowed transport,
crypto, policy, and credential contexts must outlive the checkpoint store and
all of its operations.

## Optional HTTP tracing

Event Hubs 0.7.1 borrows the complete Blobs 0.4.1 pipeline, including optional
Core 0.4.1 instrumentation. There is no separate checkpoint-store tracing
constructor or configuration:

```zig
var pipeline = core.http.HttpPipeline.init(runtime, storage_policies);
pipeline.setInstrumentation(.{
    .provider = tracing_provider, // Caller-owned *core.tracing.TracerProvider.
    .scope_name = "my.processor.checkpoints",
    .scope_version = "1.0.0",
    .namespace = "My.CheckpointStore",
    // .parent_context = default_parent,
});
var container = blobs.BlobContainerClient.init(pipeline, .{
    .endpoint = storage_endpoint,
    .container_name = container_name,
});
var store = eh.checkpoint_store_blob.BlobCheckpointStore.init(&container);
// Supply store.asCheckpointStore() to the processor.
```

Omitting `setInstrumentation` leaves tracing disabled. When enabling it,
`provider` and `scope_name` are required; explicit scope/version, namespace,
and optional default parent are retained unchanged. `claimOwnership` and
`updateCheckpoint` derive blob clients without replacing the pipeline.
`listOwnership` and `listCheckpoints` follow the Blob listing's continuation
markers and return allocator-owned arrays, not an Event Hubs pager. Every
underlying HTTP request retains the configured pipeline.

Keep the container, provider/exporter, configuration strings, default parent
tracestate, policy/credential objects, and runtime backend contexts alive
until the store and its processor have finished all operations. This includes
the processor's final ownership relinquishment during close/deinitialization.
Keep borrowed Blob endpoint/container metadata valid too. Standard transport
and mutable policy contexts remain caller-serialized.

The caller owns flush and shutdown. The store has no provider lifecycle,
hidden worker, network exporter, or automatic export call. Ended spans may
remain queued until the caller explicitly flushes its provider. Existing
ownership conflicts, service errors, and local/provider errors retain their
original result/error behavior. AMQP messaging is not instrumented by this
option; see the [HTTP-only scope and deferred work](../README.md#optional-checkpoint-http-tracing).
