# Event Hubs `checkpoint_store_blob` namespace

Blob-backed checkpoint storage for Azure Event Hubs consumers.

The namespace is exposed through `azure_sdk_eventhubs.checkpoint_store_blob`
and versions with the [`azure_sdk_eventhubs`](../README.md) package. Its
implementation remains in `sdk/messaging/eventhubs/checkpoint_store.zig`.

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
