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
- Initial version: `0.1.0`
- Dependencies: `azure_sdk_core` and `serde`

The handwritten Secrets package is separate from the generated
[`azure_rest_keyvault_secrets`](../../rest/keyvault_secrets/README.md)
protocol package.
