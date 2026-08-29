# azure_sdk_data_appconfiguration

Azure App Configuration client exposing `ConfigurationClient`.

Release branch: `sdk/data_appconfiguration`. The package depends on
`azure_sdk_core` and `serde` and starts at `0.2.0`.

`ConfigurationClient` copies a caller-built `core.http.HttpPipeline`. The
endpoint and API version, the pipeline policy pointers, and the runtime
transport and crypto-provider contexts are borrowed. They must outlive the
client, every pager derived from it, and all operations. The package does not
install a transport or standard crypto fallback.

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
    app_configuration.auth_scopes,
);
defer auth_policy.deinit();
var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
const pipeline = core.http.HttpPipeline.init(runtime, &policies);
var client = app_configuration.ConfigurationClient.init(endpoint, pipeline, .{});
```

## Development

```bash
zig build test --summary all
```
