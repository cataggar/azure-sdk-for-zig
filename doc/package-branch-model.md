# Package Branch Model

Azure SDK for Zig service packages are split into generated REST packages and
hand-written SDK packages. Each package can be published from an independent
orphan branch.

## Goals

- Keep TypeSpec-generated code completely regenerable.
- Keep authentication, convenience APIs, validation, retries, and other
  service-specific behavior out of generated packages.
- Allow generated REST packages and hand-written SDK packages to version and
  release independently.
- Make package names and dependency direction predictable across services.

## Branch and Package Naming

Use a snake-cased identifier derived from the package's path below `rest/` or
`sdk/`. Join nested path segments with underscores.

| Layer | Branch | Package and module name |
| --- | --- | --- |
| Generated REST | `rest/<service>` | `azure_rest_<service>` |
| Hand-written SDK | `sdk/<service>` | `azure_sdk_<service>` |

For Azure Container Registry:

| Layer | Branch | Package and module name |
| --- | --- | --- |
| Generated REST | `rest/container_registry` | `azure_rest_container_registry` |
| Hand-written SDK | `sdk/container_registry` | `azure_sdk_container_registry` |

Existing generated packages that predate this convention can retain their
current names only until their declared canonical migration. ARM AVS and Key
Vault Secrets migrate to `azure_rest_arm_avs` and
`azure_rest_keyvault_secrets`.

Shared packages follow the same rule:

| Source path | Branch | Package and module |
| --- | --- | --- |
| `sdk/core` | `sdk/core` | `azure_sdk_core` |
| `sdk/storage/blobs` | `sdk/storage_blobs` | `azure_sdk_storage_blobs` |
| `sdk/kusto/data` | `sdk/kusto_data` | `azure_sdk_kusto_data` |

The aggregate is the only exception: source `sdk/aggregate`, branch
`sdk/aggregate`, package `azure_sdk`.

Zig package names are limited to 32 characters. Public service packages may
therefore use a shorter cross-language service identity while retaining their
domain-oriented source path:

| Source | Branch | Package/module |
| --- | --- | --- |
| `sdk/messaging/eventhubs` | `sdk/eventhubs` | `azure_sdk_eventhubs` |
| `sdk/messaging/servicebus` | `sdk/servicebus` | `azure_sdk_servicebus` |

Closely related APIs may share one versioned package and use namespaces.
`azure_sdk_keyvault` exposes `secrets`, `keys`, `certificates`, and
`administration`; `azure_sdk_eventhubs` exposes
`checkpoint_store_blob`.

## Ownership Boundary

### `rest/<service>`

The REST branch is generator-owned:

- TypeSpec-generated clients, models, enums, and package metadata.
- Generated tests or fixtures when the emitter produces them.
- No hand-written authentication policies or convenience APIs.
- No manual edits that must survive regeneration.

Generator fixes belong on `main` in `codegen/` or `sdk/core/`, not as patches
inside one generated service package.

### `sdk/<service>`

The SDK branch is operator-owned:

- Public convenience clients and options.
- Challenge authentication and service-specific pipeline policies.
- Paging abstractions that are not directly represented by TypeSpec.
- Validation, digest calculation, resumable transfer, retries, and recovery.
- Service-specific error parsing.
- Samples, live tests, and compatibility documentation.

The SDK may re-export the generated package through a `protocol` namespace, but
it must not copy or fork generated source.

## Dependency Direction

Dependencies flow in one direction:

```text
azure_sdk_<service>
├── azure_rest_<service>
└── azure_sdk_core

azure_rest_<service>
└── azure_sdk_core
```

The generated REST package never depends on the service-specific SDK package.
This prevents cycles and allows consumers to choose either the protocol layer
or the higher-level SDK.

## `build.zig.zon`

The generated package uses the REST-prefixed package name:

```zig
.{
    .name = .azure_rest_container_registry,
    .version = "0.1.0",
    .dependencies = .{
        .azure_sdk_core = .{
            .url = "git+https://github.com/cataggar/azure-sdk-for-zig#<core-commit>",
            .hash = "<package-hash>",
        },
    },
}
```

The hand-written package pins both the common SDK revision and the generated
REST package revision:

```zig
.{
    .name = .azure_sdk_container_registry,
    .version = "0.1.0",
    .dependencies = .{
        .azure_sdk_core = .{
            .url = "git+https://github.com/cataggar/azure-sdk-for-zig#<core-commit>",
            .hash = "<package-hash>",
        },
        .azure_rest_container_registry = .{
            .url = "git+https://github.com/cataggar/azure-sdk-for-zig#<rest-commit>",
            .hash = "<package-hash>",
        },
    },
}
```

Relative path dependencies may be used while developing on `main`, but release
branches must pin immutable commits and Zig package hashes.

## `build.zig`

Module names match package names:

```zig
const rest_dep = b.dependency("azure_rest_container_registry", .{
    .target = target,
    .optimize = optimize,
});

const rest_mod = rest_dep.module("azure_rest_container_registry");

_ = b.addModule("azure_sdk_container_registry", .{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .imports = &.{
        .{ .name = "azure_rest_container_registry", .module = rest_mod },
    },
});
```

Public type names follow the cross-language Azure SDK names where practical,
for example `ContainerRegistryClient` and
`ContainerRegistryContentClient`.

## Generated Client Extensibility

Generated clients must support custom SDK layers without hand edits. A REST
package should provide an additive constructor or options hook that accepts a
prepared HTTP pipeline or policy set.

This allows the SDK package to provide challenge authentication or anonymous
access while keeping the REST branch generator-owned.

## Release Workflow

1. Update the TypeSpec adapter or Zig emitter on `main`.
2. Regenerate `rest/<service>` from the canonical specification.
3. Validate and publish the `rest/<service>` orphan branch.
4. Update `sdk/<service>` to pin the new REST commit and package hash.
5. Implement or adjust hand-written behavior in the SDK branch.
6. Validate and publish the `sdk/<service>` orphan branch.

A REST release does not require an SDK release unless its API or behavior
changes what the SDK consumes. An SDK release always pins the exact REST
revision used during testing.

Container Registry's REST-before-SDK sequence is documented in
[`eng/container_registry_release/README.md`](../eng/container_registry_release/README.md).
All packages use the generic release contract documented in
[`doc/releasing-packages.md`](releasing-packages.md).

## Versioning

- REST package versions describe the generated protocol surface.
- SDK package versions describe the public convenience API and behavior.
- A breaking REST change requires a REST major-version increment.
- A breaking public SDK change requires an SDK major-version increment.
- The two package versions do not need to match.
- Every canonical package begins at `0.1.0`.
- A release creates `<package>/v<version>` on the release commit.
- Versions must advance monotonically for one package identity; version tags
  are immutable.

## Repository Integration

`main` remains the development and integration branch for:

- The non-published integration workspace.
- `azure_sdk_core` and shared infrastructure source.
- The TypeSpec adapter and Zig emitter.
- Cross-package tests and local path-based development.
- Documentation of package and branch conventions.

The orphan branches are release artifacts for independently consumable service
packages.
