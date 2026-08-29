# azure_sdk_keyvault

One independently versioned Key Vault package with four namespaces:

| Namespace | Clients |
| --- | --- |
| [`secrets`](secrets/README.md) | `SecretClient` |
| [`keys`](keys/README.md) | `KeyClient`, `CryptographyClient` |
| [`certificates`](certificates/README.md) | `CertificateClient` |
| [`administration`](administration/README.md) | `BackupClient`, `SettingsClient` |

- Source: `sdk/keyvault`
- Release branch: `sdk/keyvault`
- Current version: `0.2.0`
- Dependencies: `azure_sdk_core` and `serde`

All clients require an explicit `core.http.HttpRuntime`, so applications select
the HTTP transport and SDK crypto provider independently:

```zig
const core = @import("azure_sdk_core");
const keyvault = @import("azure_sdk_keyvault");

var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto.asProvider(),
);

var client = try keyvault.secrets.SecretClient.init(
    allocator,
    "https://my-vault.vault.azure.net",
    credential,
    runtime,
    .{},
);
defer client.deinit();
```

Runtime descriptors are copied by value while their transport and crypto
contexts are borrowed. Credentials and policy contexts are borrowed too. They
must outlive every client, derived cryptography client, pager, and in-flight
operation that uses them. Keep a parent `KeyClient` alive until clients
returned by `getCryptographyClient` and all of its pagers are deinitialized.
The package installs no fallback crypto provider.

`keys.CryptographyClient` performs Key Vault service-side cryptography: its
`sign` operation sends a caller-provided digest as a REST payload. It does not
hash that payload locally and is separate from both SDK runtime cryptography
and the transport's TLS implementation.

The handwritten Secrets namespace is separate from the generated
[`azure_rest_keyvault_secrets`](https://github.com/cataggar/azure-sdk-for-zig/tree/main/rest/keyvault_secrets)
protocol package.

## Development

```bash
zig build test --summary all
```
