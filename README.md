# azure_sdk_core

Core HTTP, authentication, error, paging, long-running-operation, URL, crypto,
and utility infrastructure for the Azure SDK for Zig.

The canonical package/module name is `azure_sdk_core`, released from
`sdk/core`. Identity remains part of this package.

## Core surface

| API | Purpose |
| --- | --- |
| `http.StdHttpTransport` | Streaming HTTP via `std.http.Client` with gzip, deflate, and zstd response decoding |
| `http.MockTransport` | Canned buffered and streaming responses for tests |
| `http.SequenceMockTransport` | Ordered responses for retry tests |
| `pipeline.HttpPipeline` | Policies followed by one transport |
| `pipeline.TelemetryPolicy` | Adds `User-Agent` |
| `pipeline.LoggingPolicy` | Logs requests through `std.log` |
| `pipeline.RetryPolicy` | Bounded exponential backoff, jitter, and `Retry-After` |
| `pipeline.BearerTokenAuthPolicy` | Bearer authentication with token caching |
| `pipeline.RequestIdPolicy` | Adds an `x-ms-client-request-id` UUID |
| `credentials.CachedTokenCredential` | In-memory token cache with expiry |
| `base64` | Base64, HMAC-SHA256, SHA-256, and MD5 helpers |
| `url` | URL parsing and RFC 3986 percent encoding |
| `errors` | Azure error-envelope parsing |
| `lro` | Long-running-operation polling |
| `pager` | Generic `PipelinePager` |

`HttpTransport.open` and `HttpPipeline.open` return a heap-backed,
single-owner `HttpOperation`. Consume its reader and call `finish` to drain for
connection reuse, or `abort`/`cancel` to close early. Always call `deinit`;
it aborts an active operation. Streaming request preparation runs once and
does not replay a consumed reader.

## Identity

Identity remains part of `azure_sdk_core` and is available through
`core.identity`.

| Credential | Authentication source |
| --- | --- |
| `ClientSecretCredential` | OAuth 2.0 client credentials |
| `EnvironmentCredential` | `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET` |
| `ManagedIdentityCredential` | Azure Instance Metadata Service |
| `AzureCliCredential` | `az account get-access-token` |
| `WorkloadIdentityCredential` | Kubernetes OIDC federation |
| `ChainedTokenCredential` | First successful credential |
| `DefaultAzureCredential` | A chain selected by `AZURE_TOKEN_CREDENTIALS` |

### `AZURE_TOKEN_CREDENTIALS`

`DefaultAzureCredential` builds its chain from `AZURE_TOKEN_CREDENTIALS`.

| Value | Chain |
| --- | --- |
| unset | `EnvironmentCredential`, `WorkloadIdentityCredential`, `AzureCliCredential`, `AzureDeveloperCliCredential` |
| `prod` | `EnvironmentCredential`, `WorkloadIdentityCredential`, `ManagedIdentityCredential` |
| `dev` | `AzureCliCredential`, `AzureDeveloperCliCredential` |
| a credential name | just that credential |

Values are matched ignoring ASCII case and surrounding whitespace; any other
value fails with `error.UnknownTokenCredentialSelection`. A selected credential
whose configuration is absent is left out of the chain, and a selection that
leaves the chain empty fails with `error.NoCredentialConfigured`.

`ManagedIdentityCredential` probes the Instance Metadata Service at
`169.254.169.254`, which is unroutable outside Azure and stalls every token
request until the connection times out. It is therefore never in the default
chain. Set `AZURE_TOKEN_CREDENTIALS=prod` on deployed services, or name the
credential directly, to use it.

## Related packages

- [Tracing](https://github.com/cataggar/azure-sdk-for-zig/tree/main/sdk/core/tracing)
- [Testing](https://github.com/cataggar/azure-sdk-for-zig/tree/main/sdk/core/testing)
- [Performance](https://github.com/cataggar/azure-sdk-for-zig/tree/main/sdk/core/perf)
- [AMQP](https://github.com/cataggar/azure-sdk-for-zig/tree/main/sdk/core/amqp)

## Development

```bash
zig build test --summary all
```

The package depends on `serde` and `azure_sdk_core_tracing`. See the
[package model](https://github.com/cataggar/azure-sdk-for-zig/blob/main/doc/package-branch-model.md).
