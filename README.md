# azure_sdk_storage_blobs

Azure Blob Storage clients, including `BlobClient`, `BlobContainerClient`, and
the complete-SAS `SasBlobClient`.

Release branch: `sdk/storage_blobs`. The package depends on
`azure_sdk_core`, `azure_sdk_storage_common`, and `serde` and starts at
`0.1.0`.

See the
[Storage overview](https://github.com/cataggar/azure-sdk-for-zig/blob/main/sdk/storage/README.md)
for complete-SAS transfer behavior.

## Blob metadata

`BlobContainerClient` and its `BlobClient` (from `container_client.zig`) send
one `x-ms-meta-{name}` header per entry, which is the format the service
expects, and read the same headers back into an ordered `Metadata` map. The
generated client in `src/clients.zig` models metadata as a single opaque
`x-ms-meta` header and cannot round-trip it; use these clients when metadata
matters.

Metadata names must be valid C# identifiers. Anything else is rejected with
`error.InvalidMetadataName` before a request is sent. Azure lowercases names on
the wire, so `Metadata.get` is case-insensitive.

```zig
var container = try blobs.BlobContainerClient.init(allocator, .{
    .credential = credential,
    .transport = transport,
    .endpoint = "https://myaccount.blob.core.windows.net",
    .container_name = "checkpoints",
});
defer container.deinit();

var blob = container.getBlobClient("ns/hub/$Default/checkpoint/0");
const result = try blob.uploadConditional(allocator, "", .{
    .metadata = &.{
        .{ .name = "sequencenumber", .value = "42" },
        .{ .name = "offset", .value = "100" },
    },
    .if_none_match = "*",
});
defer result.deinit(allocator);

const properties = try blob.getProperties(allocator);
defer properties.deinit(allocator);
const sequence_number = properties.metadata.get("sequencenumber");
```

```bash
zig build test --summary all
zig build examples
zig build complete-sas-upload -- <blob-sas-url> <file>
```
