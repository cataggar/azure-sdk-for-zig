# azure_rest_arm_avs

Generated Azure REST client for Azure VMware Solution.

The canonical package/module name is `azure_rest_arm_avs`, released from
`rest/arm_avs` at version `0.1.0`. The current legacy manifest name is removed
during the canonical import/package rename.

This package is produced by `codegen` from the TypeSpec
specification in [`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs).
Do not edit the contents of `src/` by hand — they will be
overwritten on the next regeneration.

## Clients
- `AVSClient`
- `Operations`
- `Addons`
- `Authorizations`
- `CloudLinks`
- `Clusters`
- `Datastores`
- `GlobalReachConnections`
- `HcxEnterpriseSites`
- `Hosts`
- `IscsiPaths`
- `Licenses`
- `Locations`
- `Maintenances`
- `PlacementPolicies`
- `PrivateClouds`
- `ProvisionedNetworks`
- `PureStoragePolicies`
- `ScriptCmdlets`
- `ScriptExecutions`
- `ScriptPackages`
- `ServiceComponents`
- `Skus`
- `VirtualMachines`
- `WorkloadNetworks`

## Build

```bash
zig build
zig build test --summary all
```

The package includes generated examples documented in
[`examples/README.md`](examples/README.md).

## Regeneration

The generated `src/` tree is owned by the TypeSpec emitter:

```bash
codegen/scripts/sync.sh --force arm_avs
```

See the [code generator](../../codegen/README.md) and
[package branch model](../../doc/package-branch-model.md). The canonical
package depends directly on `azure_sdk_core` and `serde`.
