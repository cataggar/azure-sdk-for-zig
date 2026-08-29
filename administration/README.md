# Key Vault `administration` namespace

Azure Key Vault administration clients:

- `BackupClient`
- `SettingsClient`

These clients are exposed through `azure_sdk_keyvault.administration` and
version with the [`azure_sdk_keyvault`](../README.md) package. The old
`azure_sdk_keyvault` module receives no alias.

Both clients require a caller-selected `core.http.HttpRuntime`. Its backend
contexts and the credential are borrowed and must outlive the client, pagers,
and polling operations. Callers must serialize all operations sharing a
client's pipeline state.
