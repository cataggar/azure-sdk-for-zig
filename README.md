# azure_sdk_storage_common

Shared Azure Storage authentication and SAS primitives:

- `StorageSharedKeyCredential`
- `SasBuilder`
- complete service-issued SAS helpers

Release branch: `sdk/storage_common`. The package depends on
`azure_sdk_core` and starts at `0.1.0`.

Cryptographic operations require an explicit `core.crypto.CryptoProvider`.
Pipeline integrations should pass `runtime.crypto`; there is no implicit
standard-provider fallback. Shared-key credentials own decoded key material
and must be deinitialized:

```zig
var credential = try storage_common.StorageSharedKeyCredential.init(
    allocator,
    account_name,
    encoded_account_key,
);
defer credential.deinit();
try credential.signRequest(&request, runtime.crypto);

const content_md5 = try storage_common.contentMd5(
    allocator,
    runtime.crypto,
    body,
);
defer allocator.free(content_md5);
```

Credential-free SAS sends likewise take a `core.http.HttpRuntime`, ensuring
request IDs and transport behavior use the caller's configured providers.

```bash
zig build test --summary all
```
