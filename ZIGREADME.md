# Azure SDK for Zig

Pure Zig implementation of the Azure SDK with **zero C dependencies**.

**40 source files · ~6,800 lines · 106 tests · Zig 0.15.2+**

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

```bash
zig build           # compile SDK + example
zig build test      # run all 106 tests
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
| `http.StdHttpTransport` | HTTP client via `std.http.Client` |
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
| `xml` | XML pull-parser helpers (via zig-xml) |
| `errors` | Azure error JSON parsing |
| `lro` | Long-running operation poller (poll until Succeeded/Failed) |

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
| `azure_attestation` | `AttestationClient` |
| `azure_messaging_eventhubs` | `ProducerClient`, `ConsumerClient` |

### Infrastructure
| Package | Description |
|---------|-------------|
| `azure_core_amqp` | AMQP 1.0 via azure-uamqp-zig |
| `azure_core_tracing` | `Span`, `Tracer`, `NoopTracer` |
| `azure_core_testing` | `PlaybackTransport` for recorded HTTP replay |
| `azure_core_perf` | `benchmark()` harness with timing stats |

## Dependency Replacements

Every C/C++ dependency from the original SDK has been replaced:

| C++ Dependency | Zig Replacement |
|----------------|-----------------|
| libcurl / WinHTTP | `std.http.Client` |
| OpenSSL (TLS) | `std.crypto.tls.Client` |
| OpenSSL (crypto) | `std.crypto.hash`, `std.crypto.auth.hmac` |
| bcrypt (Windows) | `std.crypto.hash` |
| libxml2 | [zig-xml](https://github.com/cataggar/zig-xml) |
| azure-uamqp-c | [azure-uamqp-zig](https://github.com/cataggar/azure-uamqp-zig) |
| nlohmann/json | `std.json` |
| gzip/deflate/zstd | `std.compress.flate`, `std.compress.zstd` |
| CMake + vcpkg | `build.zig` |
| Google Test | `std.testing` |

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

## License

MIT — see [LICENSE.txt](LICENSE.txt).
