# azure_sdk_storage_files_datalake

Azure Data Lake Storage clients:

- `DataLakeFileSystemClient`
- `DataLakeFileClient`

Release branch: `sdk/storage_files_datalake`. The package depends on
`azure_sdk_core`.

## Construction and lifetime

Clients take one caller-assembled `core.http.HttpPipeline`. This keeps HTTP and
SDK crypto backend selection independent and lets callers install the
authentication or signing policies appropriate for their credential:

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto_provider = core.crypto.StdCryptoProvider.init(io);

const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto_provider.asProvider(),
);
const pipeline = core.http.HttpPipeline.init(runtime, &.{});
var filesystem = datalake.DataLakeFileSystemClient.init(pipeline, .{
    .endpoint = "https://account.dfs.core.windows.net",
    .filesystem_name = "example",
});
var file = filesystem.getFileClient("path/to/file");
```

The pipeline and runtime descriptors are copied by value. Transport and crypto
backend contexts and pipeline policy objects are borrowed; they must outlive
all clients and in-flight operations that use them. Derived file clients retain
the same transport and crypto provider selections.

```bash
zig build
zig build test --summary all
```
