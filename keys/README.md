# Key Vault `keys` namespace

Azure Key Vault Keys clients:

- `KeyClient`
- `CryptographyClient`

These clients are exposed through `azure_sdk_keyvault.keys` and version with
the [`azure_sdk_keyvault`](../README.md) package.

`KeyClient.getCryptographyClient` returns a derived client that borrows the
parent's authenticated pipeline and selected transport/crypto providers. The
derived client must be deinitialized before its parent, and callers must
serialize all parent, derived-client, and pager operations sharing that
pipeline state. `CryptographyClient` sends digests to the Key Vault service;
it does not replace runtime cryptography or transport TLS.
