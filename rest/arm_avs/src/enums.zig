//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unknown` variant.

const std = @import("std");

/// The intended executor of the operation; as in Resource Based Access Control (RBAC) and audit logs UX. Default value is "user,system"
pub const Origin = union(enum) {
    user,
    system,
    @"user,system",
    unknown: []const u8,
};

/// Extensible enum. Indicates the action type. "Internal" refers to actions that are for internal only APIs.
pub const ActionType = union(enum) {
    internal,
    unknown: []const u8,
};

/// Addon type
pub const AddonType = union(enum) {
    srm,
    vr,
    hcx,
    arc,
    unknown: []const u8,
};

/// Addon provisioning state
pub const AddonProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    cancelled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// The kind of entity that created the resource.
pub const createdByType = union(enum) {
    user,
    application,
    managed_identity,
    key,
    unknown: []const u8,
};

/// The provisioning state of a resource type.
pub const ResourceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// Express Route Circuit Authorization provisioning state
pub const ExpressRouteAuthorizationProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unknown: []const u8,
};

/// cloud link provisioning state
pub const CloudLinkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// Cloud Link status
pub const CloudLinkStatus = union(enum) {
    active,
    building,
    deleting,
    failed,
    disconnected,
    unknown: []const u8,
};

/// Cluster provisioning state
pub const ClusterProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    cancelled,
    deleting,
    updating,
    unknown: []const u8,
};

/// This field is required to be implemented by the Resource Provider if the service has more than one tier, but is not required on a PUT.
pub const SkuTier = enum {
    free,
    basic,
    standard,
    premium,
};

/// datastore provisioning state
pub const DatastoreProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    cancelled,
    pending,
    creating,
    updating,
    deleting,
    unknown: []const u8,
};

/// mount option
pub const MountOptionEnum = union(enum) {
    mount,
    attach,
    unknown: []const u8,
};

/// datastore status
pub const DatastoreStatus = union(enum) {
    // NOTE: emitter bug — the spec has an enum value `Unknown` that
    // collides with the open-union sentinel `unknown: []const u8`. Until
    // the emitter learns to disambiguate, rename the explicit variant.
    unknown_value,
    accessible,
    inaccessible,
    attached,
    detached,
    lost_communication,
    dead_or_error,
    unknown: []const u8,
};

/// Global Reach Connection provisioning state
pub const GlobalReachConnectionProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unknown: []const u8,
};

/// Global Reach Connection status
pub const GlobalReachConnectionStatus = union(enum) {
    connected,
    connecting,
    disconnected,
    unknown: []const u8,
};

/// HCX Enterprise Site provisioning state
pub const HcxEnterpriseSiteProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// HCX Enterprise Site status
pub const HcxEnterpriseSiteStatus = union(enum) {
    available,
    consumed,
    deactivated,
    deleted,
    unknown: []const u8,
};

/// The kind of host.
pub const HostKind = union(enum) {
    general,
    specialized,
    unknown: []const u8,
};

/// provisioning state of the host
pub const HostProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// The reason for host maintenance.
pub const HostMaintenance = union(enum) {
    replacement,
    upgrade,
    unknown: []const u8,
};

/// private cloud provisioning state
pub const IscsiPathProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    pending,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// The kind of license.
pub const LicenseKind = union(enum) {
    vmware_firewall,
    unknown: []const u8,
};

/// provisioning state of the license
pub const LicenseProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// The name of the license.
pub const LicenseName = union(enum) {
    vmware_firewall,
    unknown: []const u8,
};

/// trial status
pub const TrialStatus = union(enum) {
    trial_available,
    trial_used,
    trial_disabled,
    unknown: []const u8,
};

/// quota enabled
pub const QuotaEnabled = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// Customer presentable maintenance state
pub const MaintenanceStateName = union(enum) {
    not_scheduled,
    scheduled,
    in_progress,
    success,
    failed,
    canceled,
    unknown: []const u8,
};

/// status filter for the maintenance
pub const MaintenanceStatusFilter = union(enum) {
    active,
    inactive,
    unknown: []const u8,
};

/// type of the maintenance
pub const MaintenanceType = union(enum) {
    vcsa,
    esxi,
    nsxt,
    unknown: []const u8,
};

/// provisioning state of the maintenance
pub const MaintenanceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unknown: []const u8,
};

/// Defines the type of operation
pub const MaintenanceManagementOperationKind = union(enum) {
    schedule,
    reschedule,
    maintenance_readiness_refresh,
    unknown: []const u8,
};

/// Constraints for scheduling of maintenance
pub const ScheduleOperationConstraintKind = union(enum) {
    scheduling_window,
    available_window_for_maintenance_while_schedule_operation,
    blocked_while_schedule_operation,
    unknown: []const u8,
};

/// Reason for blocking operation on maintenance
pub const BlockedDatesConstraintCategory = union(enum) {
    hi_priority_event,
    quota_exhausted,
    holiday,
    unknown: []const u8,
};

/// Constraints for rescheduling of maintenance
pub const RescheduleOperationConstraintKind = union(enum) {
    available_window_for_maintenance_while_reschedule_operation,
    blocked_while_reschedule_operation,
    unknown: []const u8,
};

/// The status of an MaintenanceReadinessRefresh operation
pub const MaintenanceReadinessRefreshOperationStatus = union(enum) {
    in_progress,
    not_started,
    failed,
    not_applicable,
    unknown: []const u8,
};

/// Defines the type of maintenance readiness check
pub const MaintenanceCheckType = union(enum) {
    precheck,
    preflight,
    unknown: []const u8,
};

/// Defines the readiness status of maintenance
pub const MaintenanceReadinessStatus = union(enum) {
    ready,
    not_ready,
    data_not_available,
    not_applicable,
    unknown: []const u8,
};

/// Placement Policy type
pub const PlacementPolicyType = union(enum) {
    vm_vm,
    vm_host,
    unknown: []const u8,
};

/// Placement Policy state
pub const PlacementPolicyState = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// Placement Policy provisioning state
pub const PlacementPolicyProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Affinity type
pub const AffinityType = union(enum) {
    affinity,
    anti_affinity,
    unknown: []const u8,
};

/// Affinity Strength
pub const AffinityStrength = union(enum) {
    should,
    must,
    unknown: []const u8,
};

/// Azure Hybrid Benefit type
pub const AzureHybridBenefitType = union(enum) {
    sql_host,
    none,
    unknown: []const u8,
};

/// Whether internet is enabled or disabled
pub const InternetEnum = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// Whether SSL is enabled or disabled
pub const SslEnum = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// Whether the private clouds is available in a single zone or two zones
pub const AvailabilityStrategy = union(enum) {
    single_zone,
    dual_zone,
    unknown: []const u8,
};

/// Whether encryption is enabled or disabled
pub const EncryptionState = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// Whether the the encryption key is connected or access denied
pub const EncryptionKeyStatus = union(enum) {
    connected,
    access_denied,
    unknown: []const u8,
};

/// Whether the encryption version is fixed or auto-detected
pub const EncryptionVersionType = union(enum) {
    fixed,
    auto_detected,
    unknown: []const u8,
};

/// private cloud provisioning state
pub const PrivateCloudProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    cancelled,
    pending,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// NSX public IP quota raised
pub const NsxPublicIpQuotaRaisedEnum = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// The type of DNS zone.
pub const DnsZoneType = union(enum) {
    public,
    private,
    unknown: []const u8,
};

/// The kind of license.
pub const VcfLicenseKind = union(enum) {
    vcf5,
    unknown: []const u8,
};

/// Type of managed service identity (either system assigned, or none).
pub const SystemAssignedServiceIdentityType = union(enum) {
    none,
    system_assigned,
    unknown: []const u8,
};

/// provisioned network provisioning state
pub const ProvisionedNetworkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// The type of network provisioned.
pub const ProvisionedNetworkTypes = union(enum) {
    esx_management,
    esx_replication,
    hcx_management,
    hcx_uplink,
    vcenter_management,
    vmotion,
    vsan,
    unknown: []const u8,
};

/// Pure Storage Policy Based Management policy provisioning state
pub const PureStoragePolicyProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    deleting,
    updating,
    unknown: []const u8,
};

/// A script cmdlet provisioning state
pub const ScriptCmdletProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// Specifies whether a script cmdlet is intended to be invoked only through automation or visible to customers
pub const ScriptCmdletAudience = union(enum) {
    automation,
    any,
    unknown: []const u8,
};

/// Script Parameter types
pub const ScriptParameterTypes = union(enum) {
    string,
    secure_string,
    credential,
    int,
    bool,
    float,
    unknown: []const u8,
};

/// Visibility Parameter
pub const VisibilityParameterEnum = union(enum) {
    visible,
    hidden,
    unknown: []const u8,
};

/// Optional Param
pub const OptionalParamEnum = union(enum) {
    optional,
    required,
    unknown: []const u8,
};

/// script execution parameter type
pub const ScriptExecutionParameterType = union(enum) {
    value,
    secure_value,
    credential,
    unknown: []const u8,
};

/// Script Execution provisioning state
pub const ScriptExecutionProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    pending,
    running,
    cancelling,
    cancelled,
    deleting,
    unknown: []const u8,
};

/// Script Output Stream type
pub const ScriptOutputStreamType = union(enum) {
    information,
    warning,
    output,
    @"error",
    unknown: []const u8,
};

/// Script Package provisioning state
pub const ScriptPackageProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// Describes the type of resource the SKU applies to.
pub const ResourceSkuResourceType = union(enum) {
    private_clouds,
    @"private_clouds/clusters",
    unknown: []const u8,
};

/// Describes the kind of SKU restrictions that can exist
pub const ResourceSkuRestrictionsType = union(enum) {
    location,
    zone,
    unknown: []const u8,
};

/// Describes the reason for SKU restriction.
pub const ResourceSkuRestrictionsReasonCode = union(enum) {
    quota_id,
    not_available_for_subscription,
    unknown: []const u8,
};

/// Virtual Machine provisioning state
pub const VirtualMachineProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unknown: []const u8,
};

/// Virtual Machine Restrict Movement state
pub const VirtualMachineRestrictMovementState = union(enum) {
    enabled,
    disabled,
    unknown: []const u8,
};

/// base Workload Network provisioning state
pub const WorkloadNetworkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Type of DHCP: SERVER or RELAY.
pub const DhcpTypeEnum = union(enum) {
    server,
    relay,
    unknown: []const u8,
};

/// Workload Network DHCP provisioning state
pub const WorkloadNetworkDhcpProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// DNS service log level
pub const DnsServiceLogLevelEnum = union(enum) {
    debug,
    info,
    warning,
    @"error",
    fatal,
    unknown: []const u8,
};

/// DNS service status
pub const DnsServiceStatusEnum = union(enum) {
    success,
    failure,
    unknown: []const u8,
};

/// Workload Network DNS Service provisioning state
pub const WorkloadNetworkDnsServiceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Workload Network DNS Zone provisioning state
pub const WorkloadNetworkDnsZoneProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Port Mirroring Direction
pub const PortMirroringDirectionEnum = union(enum) {
    ingress,
    egress,
    bidirectional,
    unknown: []const u8,
};

/// Port Mirroring status
pub const PortMirroringStatusEnum = union(enum) {
    success,
    failure,
    unknown: []const u8,
};

/// Workload Network Port Mirroring provisioning state
pub const WorkloadNetworkPortMirroringProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Workload Network Public IP provisioning state
pub const WorkloadNetworkPublicIPProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Segment status
pub const SegmentStatusEnum = union(enum) {
    success,
    failure,
    unknown: []const u8,
};

/// Workload Network Segment provisioning state
pub const WorkloadNetworkSegmentProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// VM type
pub const VMTypeEnum = union(enum) {
    regular,
    edge,
    service,
    unknown: []const u8,
};

/// VM group status
pub const VMGroupStatusEnum = union(enum) {
    success,
    failure,
    unknown: []const u8,
};

/// Workload Network VM Group provisioning state
pub const WorkloadNetworkVMGroupProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unknown: []const u8,
};

/// Azure VMware Solution API versions.
pub const Versions = enum {
    v2023_09_01,
    v2024_09_01,
    v2025_09_01,
};
