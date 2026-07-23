# Azure SDK aggregate package

Package `azure_sdk` provides one dependency that exports every canonical Azure
SDK for Zig module. Consumers still import modules by their canonical names,
for example:

```zig
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");
```

Choose either this aggregate package or direct dependencies on the individual
packages an application uses. Do not combine aggregate and direct instances of
the same package in one build, because that can create duplicate Zig source
owners.

The aggregate intentionally exposes no legacy module names. See the
[package catalog](https://github.com/cataggar/azure-sdk-for-zig/blob/main/doc/package-catalog.md)
for the complete canonical module list.

## Development

```bash
zig build test --summary all
```
