# Azure Container Registry REST for Zig

`azure_rest_container_registry` is the generated protocol package for
Azure Container Registry data-plane API version **2021-07-01**.
It is produced from the checked-in TypeSpec code model and is entirely
generator-owned. Do not edit this package by hand; change the emitter or
fixture and regenerate it instead.

## Protocol surface

The generated clients expose all 29 stable operations through:

- `ContainerRegistryClient`
- `ContainerRegistry`
- `ContainerRegistryBlob`
- `Authentication`

This layer preserves raw protocol request/response types and status
unions. It does not add challenge authentication, safe continuation
validation, digest verification, transfer replay, or domain ownership
helpers. Use `azure_sdk_container_registry` for those behaviors.

The generated `initWithPipeline` constructor is the protocol escape
hatch for callers that need custom policies or operations not surfaced
by the hand-written package. The supplied pipeline and transport are
borrowed and must outlive every generated client and active operation.
Generated result fields follow their declared allocator ownership; free
or deinitialize every owned body/header/model value shown by the type.

## Media types

The REST package transports caller-provided media types. The hand-written
package has first-class upload support for OCI image manifests and Docker
schema-2 manifests and accepts OCI image/index, Docker schema-2
manifest/list/config, ORAS artifact manifest, and wildcard manifest
responses.

## Build and regeneration

```bash
zig build test --summary all
(cd ../../codegen/cli && zig build generate-container-registry-package)
../../scripts/verify-container-registry-regeneration.sh
```

Local development uses the repository-relative `azure_sdk` dependency.
Release staging replaces it with the immutable commit/hash recorded in
`eng/container_registry_release/metadata.sh`; see
`doc/package-branch-model.md`.
