# azure_sdk_storage_files_shares

Azure Files clients:

- `ShareServiceClient`
- `ShareClient`
- `ShareDirectoryClient`
- `ShareFileClient`

Release branch: `sdk/storage_files_shares`. The package depends on
`azure_sdk_core` 0.3.0. Version 0.2.0 uses the breaking `HttpRuntime` API.

Construct a Core `HttpRuntime` with independently selected HTTP transport and
crypto providers, place it in an `HttpPipeline`, and pass that pipeline to a
client constructor:

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto.asProvider(),
);
const pipeline = core.http.HttpPipeline.init(runtime, &.{});

var service = ShareServiceClient.init(
    pipeline,
    "https://myaccount.file.core.windows.net",
    .{},
);
var share = service.getShareClient("myshare");
var directory = share.getDirectoryClient("documents");
var file = directory.getFileClient("readme.txt");
```

Clients and pipelines copy the runtime descriptors by value but borrow the
transport and crypto provider contexts. Those contexts, the pipeline policy
storage, and all endpoint/name/option strings must outlive the clients and any
operations using them. Backend thread-safety and caller-serialization
requirements continue to apply.

The legacy credential-plus-transport `ShareClient.init` signature is removed.
Service, share, directory, and file clients each have one pipeline-based
constructor; derived clients preserve the complete runtime, including its
crypto provider.

```bash
zig build test --summary all
```
