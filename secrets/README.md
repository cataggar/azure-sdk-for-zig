# Key Vault `secrets` namespace

Handwritten Azure Key Vault Secrets client exposing `SecretClient` through
`azure_sdk_keyvault.secrets`.

The namespace is part of the versioned
[`azure_sdk_keyvault`](../README.md) package and is distinct from the generated
[`azure_rest_keyvault_secrets`](https://github.com/cataggar/azure-sdk-for-zig/tree/main/rest/keyvault_secrets)
package.

Construction requires a caller-selected `core.http.HttpRuntime`. Its backend
contexts and the credential are borrowed and must outlive the client and its
pagers.
