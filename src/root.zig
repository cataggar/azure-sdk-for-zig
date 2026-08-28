//! arm-avs — generated from TypeSpec.
//!
//! Do not edit by hand. Regenerate with `codegen`.

const clients = @import("clients.zig");
pub const models = @import("models.zig");
pub const enums = @import("enums.zig");
pub const AVSClient = clients.AVSClient;
pub const Operations = clients.Operations;
pub const Addons = clients.Addons;
pub const Authorizations = clients.Authorizations;
pub const CloudLinks = clients.CloudLinks;
pub const Clusters = clients.Clusters;
pub const Datastores = clients.Datastores;
pub const GlobalReachConnections = clients.GlobalReachConnections;
pub const HcxEnterpriseSites = clients.HcxEnterpriseSites;
pub const Hosts = clients.Hosts;
pub const IscsiPaths = clients.IscsiPaths;
pub const Licenses = clients.Licenses;
pub const Locations = clients.Locations;
pub const Maintenances = clients.Maintenances;
pub const PlacementPolicies = clients.PlacementPolicies;
pub const PrivateClouds = clients.PrivateClouds;
pub const ProvisionedNetworks = clients.ProvisionedNetworks;
pub const PureStoragePolicies = clients.PureStoragePolicies;
pub const ScriptCmdlets = clients.ScriptCmdlets;
pub const ScriptExecutions = clients.ScriptExecutions;
pub const ScriptPackages = clients.ScriptPackages;
pub const ServiceComponents = clients.ServiceComponents;
pub const Skus = clients.Skus;
pub const VirtualMachines = clients.VirtualMachines;
pub const WorkloadNetworks = clients.WorkloadNetworks;

test {
    _ = @import("clients_test.zig");
}
