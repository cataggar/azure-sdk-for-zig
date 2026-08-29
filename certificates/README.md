# Key Vault `certificates` namespace

Azure Key Vault Certificates client exposing `CertificateClient`.

The client is exposed through `azure_sdk_keyvault.certificates` and versions
with the [`azure_sdk_keyvault`](../README.md) package.

Construction requires a caller-selected `core.http.HttpRuntime`. Its backend
contexts and the credential are borrowed and must outlive the client and its
pagers. Callers must serialize all operations sharing the client's pipeline
state. Continuation URLs are restricted to the original HTTPS vault origin.
