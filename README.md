# Azure SDK for Zig

> **⚠️ Experimental** — This SDK is an experimental project built with AI assistance
> (GitHub Copilot). It was ported from the
> [Azure SDK for C++](https://github.com/Azure/azure-sdk-for-cpp) as a starting
> point, with all C/C++ dependencies replaced by pure Zig equivalents.
> This is not an official Microsoft or Azure SDK.

Pure Zig implementation of Azure service clients with **zero C dependencies**.

**53 source files · 219 tests · Zig 0.16+**

## Quick Start

```zig
const std = @import("std");
const core = @import("azure_core");
const identity = @import("azure_identity");

// Authenticate with DefaultAzureCredential (env vars, managed identity, or CLI).
var transport = core.http.StdHttpTransport.init(allocator, io);
var cred = identity.DefaultAzureCredential.init(allocator, transport.asTransport(), std.posix.environ);

// Use any service client.
var client = @import("azure_keyvault_secrets").SecretClient.init(
    "https://myvault.vault.azure.net",
    cred.asCredential(),
    transport.asTransport(),
    .{},
);
const secret = try client.getSecret(allocator, "my-secret");
```

## Build & Test

Requires [Zig 0.16.0](https://ziglang.org/download/) or later.

```bash
zig build           # compile SDK + example
zig build test      # run all 219 tests
zig build run       # run the example app
```

## Architecture

```
Service SDKs (Storage, Key Vault, Tables, Event Hubs, etc.)
    │
azure-core (Zig)
    HTTP Pipeline: RequestId → Telemetry → Logging → Retry → Auth → Decompression → Transport
    Transport: std.http.Client (TLS via std.crypto.tls)
    │
azure-identity: DefaultAzureCredential + 7 credential types
    │
azure-core-amqp: azure-uamqp-zig (pure Zig AMQP 1.0)
```

## Modules

### Core (`azure_core`)

| Module | Description |
|--------|-------------|
| `http.StdHttpTransport` | HTTP client via `std.http.Client` with response header capture |
| `http.MockTransport` | Canned responses for unit tests |
| `http.SequenceMockTransport` | Multi-response sequences for retry testing |
| `pipeline.HttpPipeline` | Ordered chain of policies → transport |
| `pipeline.TelemetryPolicy` | Injects `User-Agent` header |
| `pipeline.LoggingPolicy` | Logs requests via `std.log` |
| `pipeline.RetryPolicy` | Exponential backoff with jitter, 429/5xx retry, Retry-After |
| `pipeline.BearerTokenAuthPolicy` | `Authorization: Bearer` with token caching |
| `pipeline.RequestIdPolicy` | `x-ms-client-request-id` UUID |
| `credentials.CachedTokenCredential` | In-memory token cache with TTL |
| `base64` | Base64 + HMAC-SHA256, SHA-256, MD5 helpers |
| `url` | URL parsing, percent-encode/decode (RFC 3986) |
| `errors` | Azure error envelope parsing + `logErrorResponse` |
| `lro` | Long-running operation poller (poll until Succeeded/Failed) |
| `pager` | Generic paged-result iterator (`PipelinePager`) |

### Identity (`azure_identity`)

| Credential | Auth method |
|------------|-------------|
| `ClientSecretCredential` | OAuth 2.0 client_credentials |
| `EnvironmentCredential` | `AZURE_TENANT_ID` / `CLIENT_ID` / `CLIENT_SECRET` |
| `ManagedIdentityCredential` | Azure IMDS endpoint |
| `AzureCliCredential` | `az account get-access-token` |
| `WorkloadIdentityCredential` | Kubernetes OIDC federation |
| `ChainedTokenCredential` | First-success fallback chain |
| `DefaultAzureCredential` | Auto-discovery: Env → Workload → MI → CLI |

### Service SDKs

| Package | Clients |
|---------|---------|
| `azure_storage_blobs` | `BlobClient`, `BlobContainerClient` |
| `azure_storage_queues` | `QueueClient`, `QueueServiceClient` |
| `azure_storage_files_shares` | `ShareClient`, `ShareDirectoryClient`, `ShareFileClient` |
| `azure_storage_files_datalake` | `DataLakeFileSystemClient`, `DataLakeFileClient` |
| `azure_storage_common` | `StorageSharedKeyCredential`, `SasBuilder` |
| `azure_keyvault_secrets` | `SecretClient` |
| `azure_keyvault_keys` | `KeyClient`, `CryptographyClient` |
| `azure_keyvault_certificates` | `CertificateClient` |
| `azure_keyvault_admin` | `BackupClient`, `SettingsClient` |
| `azure_data_tables` | `TableClient`, `TableServiceClient` |
| `azure_data_appconfiguration` | `ConfigurationClient` |
| `azure_data_cosmos` | `CosmosClient`, `DatabaseClient`, `ContainerClient` |
| `azure_attestation` | `AttestationClient` |
| `azure_messaging_eventhubs` | `ProducerClient`, `ConsumerClient` |
| `azure_messaging_eventhubs_checkpointstore_blob` | Blob-backed checkpoint store |
| `azure_messaging_servicebus` | `ServiceBusSenderClient`, `ServiceBusReceiverClient`, `ServiceBusAdministrationClient` |
| `azure_kusto_data` | `KustoClient` (experimental buffered query and management support) |
| `azure_kusto_ingest` | `StreamingIngestClient` (experimental direct streaming ingestion); queued ingestion and managed queued fallback are planned, not implemented |

Kusto datasets and non-null ingestion IDs are allocator-owned; call their `deinit` methods when finished.

### Kusto authentication and connections

Create authenticated Kusto clients from a shared `KustoConnection`. This example assumes the caller already has a `*TokenCredential` named `credential` and a `*HttpTransport` named `transport`.

```zig
var builder = KustoConnectionStringBuilder.init("https://mycluster.kusto.windows.net");
_ = builder.withTokenCredential(credential);
const properties = builder.build();

const connection = try KustoConnection.init(allocator, properties, transport, .{});
defer connection.deinit();

var client = KustoClient.initWithConnection(connection, .{});
// Or: var ingest_client = StreamingIngestClient.initWithConnection(connection);
```

`KustoConnection` owns copies of its endpoint, scope, user-agent, policy, and token-cache state. It borrows the credential and transport; both must outlive the connection. Derived clients borrow the connection, require no `deinit`, and must not outlive the connection or any in-flight request.

Connections and their derived clients are not safe for concurrent use. Externally serialize all calls, including calls made through separate clients that share a connection.

The existing client constructors remain unauthenticated compatibility APIs only. Passing authentication configuration to them returns `AuthenticatedConnectionRequired`; authenticated code must use `initWithConnection`.

`withAadAppKey` is deprecated and inert for connection creation. It is rejected with `AadAppKeyAuthenticationUnsupported`; supply an `azure_core.credentials.TokenCredential` instead.

Metadata discovery is enabled by default for authenticated connections. Before acquiring a token, the connection makes an unauthenticated, no-follow `GET` request to `/v1/rest/auth/metadata` on the engine endpoint. The response provides login authority details and `KustoServiceResourceId`; the resource ID is used to derive the token scope. Only a 404 or an empty metadata response uses the public-cloud fallback. When the caller supplies a `KustoCloudInfoCache`, discovered metadata is cached for reuse.

Every initial, discovered, or explicitly configured endpoint is validated before token acquisition. Kusto accepts the current well-known public and sovereign Kusto domains by default; custom or private front-door hosts must be added as exact entries in `additional_trusted_hosts` (wildcards and suffix matches are not accepted). A malformed or untrusted endpoint is rejected before the credential is called. For Private Link, use the normal public cluster hostname and configure private DNS; do not pass a `privatelink` URL as the cluster endpoint.

Use `KustoConnectionOptions` to override discovery when needed:

```zig
const options = KustoConnectionOptions{
    .engine_endpoint = "https://mycluster.kusto.windows.net",
    .data_management_endpoint = "https://ingest-mycluster.kusto.windows.net",
    .token_scope = "https://kusto.kusto.windows.net/.default",
};
const connection = try KustoConnection.init(allocator, properties, transport, options);
```

Set `.metadata_mode = .disabled` for offline or custom bootstrap control. Trust validation still runs with discovery disabled, and the token scope defaults to the public-cloud scope unless `token_scope` is explicitly provided. Explicit endpoint and scope overrides are still subject to endpoint validation.

Metadata can expose the login authority for a sovereign or private cloud, but `TokenCredential` is an opaque credential boundary: Kusto cannot reconfigure a generic credential at runtime. Callers using those clouds must construct or configure their credential for the discovered authority themselves; do not assume that every `azure_core` credential supports runtime authority changes.

### Kusto request properties, timeouts, and retries

`ClientRequestProperties` emits object-valued `Options` and `Parameters` through structured serde values. Dynamic setters own their keys and values and require `deinit`; borrowed header strings must outlive the request.

- Typed helper areas cover timeout, truncation, progressive results, cache, consistency, resources, and security. Unknown options preserve their JSON types; raw JSON fragments are not accepted. Query parameter values must be strings or Kusto `long` values; encode other scalar types as KQL literal strings such as `datetime(...)` or `dynamic(...)`.
- Query requests default to a 4-minute server timeout and management requests to 10 minutes. Explicit server timeouts range from 1 second through 1 hour with millisecond precision; the client budget defaults to the server timeout plus 30 seconds. `no_request_timeout` requests the maximum server timeout.
- In the current synchronous buffered transport, the client timeout bounds retries and backoff only; it cannot interrupt an in-flight `std.http` request. Hard cancellation is deferred to future streaming and cancellation transport work.
- Explicit application, user, version, and request-ID headers override defaults. Results expose owned `client_request_id` and `activity_id`; dataset `deinit` frees them.
- Queries may retry; management operations and streaming ingestion remain non-retryable.

### Infrastructure

| Package | Description |
|---------|-------------|
| `azure_core_amqp` | AMQP 1.0 via azure-uamqp-zig |
| `azure_core_tracing` | `Span`, `Tracer`, `NoopTracer` |
| `azure_core_testing` | `PlaybackTransport` for recorded HTTP replay |
| `azure_core_perf` | `benchmark()` harness with timing stats |

## Dependencies

The SDK uses only the Zig standard library plus two small Zig packages:

| Purpose | Package |
|---------|---------|
| HTTP, TLS, crypto, compression | `std` (Zig standard library) |
| Typed JSON + XML (de)serialization | [serde.zig](https://github.com/cataggar/serde.zig) |
| AMQP 1.0 protocol | [azure-uamqp-zig](https://github.com/cataggar/azure-uamqp-zig) |

## Using as a Dependency

Add to your `build.zig.zon`:

```zon
.dependencies = .{
    .azure_sdk = .{
        .url = "git+https://github.com/cataggar/azure-sdk-for-zig#<commit>",
        .hash = "...",
    },
},
```

Then in `build.zig`:

```zig
const azure = b.dependency("azure_sdk", .{});
exe.root_module.addImport("azure_core", azure.module("azure_core"));
exe.root_module.addImport("azure_identity", azure.module("azure_identity"));
```

## Background

This project started as a port of the [Azure SDK for C++](https://github.com/Azure/azure-sdk-for-cpp),
preserving the same layered architecture (core → identity → service SDKs) while
replacing every C/C++ dependency with Zig standard library equivalents:

| Original (C++) | Zig Replacement |
|----------------|-----------------|
| libcurl / WinHTTP | `std.http.Client` |
| OpenSSL | `std.crypto.tls`, `std.crypto.hash`, `std.crypto.auth.hmac` |
| nlohmann/json + libxml2 | [serde.zig](https://github.com/cataggar/serde.zig) (typed schemas) |
| azure-uamqp-c | azure-uamqp-zig |
| CMake + vcpkg | `build.zig` |
| Google Test | `std.testing` |

## License

MIT — see [LICENSE.txt](LICENSE.txt).
