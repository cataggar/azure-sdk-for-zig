# azure_sdk_storage_blobs

Azure Blob Storage clients, including `BlobClient`, `BlobContainerClient`, and
the complete-SAS `SasBlobClient`.

Release branch: `sdk/storage_blobs`. The package depends on
`azure_sdk_core`, `azure_sdk_storage_common`, and `serde` and starts at
`0.1.0`.

See the
[Storage overview](https://github.com/cataggar/azure-sdk-for-zig/blob/main/sdk/storage/README.md)
for complete-SAS transfer behavior.

```bash
zig build test --summary all
zig build examples
zig build complete-sas-upload -- <blob-sas-url> <file>
```
