# azure_sdk_storage_queues

Azure Queue Storage clients, including `QueueClient`, `QueueServiceClient`, and
the complete-SAS `SasQueueClient`.

Release branch: `sdk/storage_queues`. The package depends on
`azure_sdk_core`, `azure_sdk_storage_common`, and `serde` and starts at
`0.2.0`.

All clients use Core's canonical HTTP runtime. `QueueClient` and
`QueueServiceClient` copy a caller-built `core.http.HttpPipeline`;
`SasQueueClient` copies a `core.http.HttpRuntime`. The pipeline policy pointers
and runtime transport/crypto contexts are borrowed and must outlive the clients
and their operations.

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto_provider = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto_provider.asProvider(),
);
var auth_policy = core.http.BearerTokenAuthPolicy.init(
    allocator,
    credential,
    queues.auth_scopes,
);
defer auth_policy.deinit();
var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
const pipeline = core.http.HttpPipeline.init(runtime, &policies);
var client = queues.QueueServiceClient.init(endpoint, pipeline);
```

See the
[Storage overview](https://github.com/cataggar/azure-sdk-for-zig/blob/main/sdk/storage/README.md)
for complete-SAS message behavior.

```bash
zig build test --summary all
zig build examples
zig build complete-sas-message -- <queue-sas-url> <message>
```
