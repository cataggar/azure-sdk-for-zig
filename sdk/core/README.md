# azure_sdk_core

Core HTTP, authentication, error, paging, long-running-operation, URL, crypto,
and utility infrastructure for the Azure SDK for Zig.

The canonical package/module name is `azure_sdk_core`, released from
`sdk/core`. During the migration this source is still composed by the root
workspace; the canonical import rename and package-local build land in the
next dependency-layer PRs.

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
| `DefaultAzureCredential` | Environment, workload identity, managed identity, then Azure CLI |

## Related packages

- [Tracing](tracing/README.md)
- [Testing](testing/README.md)
- [Performance](perf/README.md)
- [AMQP](amqp/README.md)

## Development

Until extraction completes, run Core tests through the workspace:

```bash
zig build test --summary all
```

The independent package will depend on `serde` and
`azure_sdk_core_tracing`. See the
[package model](../../doc/package-branch-model.md).
