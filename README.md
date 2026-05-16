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
| `azure_kusto_data` | `KustoClient` (queries + management) |
| `azure_kusto_ingest` | `StreamingIngestClient`, `QueuedIngestClient`, `ManagedIngestClient` |

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
