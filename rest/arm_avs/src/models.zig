//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A list of REST API operations supported by an Azure Resource Provider. It contains an URL link to get the next set of results.
pub const OperationListResult = struct {
    /// The Operation items on this page
    value: []const Operation,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Details of a REST API operation, returned from the Resource Provider Operations API
pub const Operation = struct {
    /// The name of the operation, as per Resource-Based Access Control (RBAC). Examples: "Microsoft.Compute/virtualMachines/write", "Microsoft.Compute/virtualMachines/capture/action"
    name: ?[]const u8 = null,
    /// Whether the operation applies to data-plane. This is "true" for data-plane operations and "false" for Azure Resource Manager/control-plane operations.
    is_data_action: ?bool = null,
    /// Localized display information for this particular operation.
    display: ?OperationDisplay = null,
    /// The intended executor of the operation; as in Resource Based Access Control (RBAC) and audit logs UX. Default value is "user,system"
    origin: ?enums.Origin = null,
    /// Extensible enum. Indicates the action type. "Internal" refers to actions that are for internal only APIs.
    action_type: ?enums.ActionType = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Localized display information for an operation.
pub const OperationDisplay = struct {
    /// The localized friendly form of the resource provider name, e.g. "Microsoft Monitoring Insights" or "Microsoft Compute".
    provider: ?[]const u8 = null,
    /// The localized friendly name of the resource type related to this operation. E.g. "Virtual Machines" or "Job Schedule Collections".
    resource: ?[]const u8 = null,
    /// The concise, localized friendly name for the operation; suitable for dropdowns. E.g. "Create or Update Virtual Machine", "Restart Virtual Machine".
    operation: ?[]const u8 = null,
    /// The short, localized friendly description of the operation; suitable for tool tips and detailed views.
    description: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Common error response for all Azure Resource Manager APIs to return error details for failed operations.
pub const ErrorResponse = struct {
    /// The error object.
    @"error": ?ErrorDetail = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The error detail.
pub const ErrorDetail = struct {
    /// The error code.
    code: ?[]const u8 = null,
    /// The error message.
    message: ?[]const u8 = null,
    /// The error target.
    target: ?[]const u8 = null,
    /// The error details.
    details: ?[]const ErrorDetail = null,
    /// The error additional info.
    additional_info: ?[]const ErrorAdditionalInfo = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The resource management error additional info.
pub const ErrorAdditionalInfo = struct {
    /// The additional info type.
    type: ?[]const u8 = null,
    /// The additional info.
    info: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a Addon list operation.
pub const AddonList = struct {
    /// The Addon items on this page
    value: []const Addon,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An addon resource
pub const Addon = struct {
    /// The resource-specific properties for this resource.
    properties: ?AddonProperties = null,
    /// Name of the addon.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an addon
pub const AddonProperties = struct {
    /// Addon type
    addon_type: enums.AddonType,
    /// The state of the addon provisioning
    provisioning_state: ?enums.AddonProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a Site Recovery Manager (SRM) addon
pub const AddonSrmProperties = struct {
    /// The Site Recovery Manager (SRM) license
    license_key: ?[]const u8 = null,
    /// The type of private cloud addon
    addon_type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a vSphere Replication (VR) addon
pub const AddonVrProperties = struct {
    /// The vSphere Replication Server (VRS) count
    vrs_count: i32,
    /// The type of private cloud addon
    addon_type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an HCX addon
pub const AddonHcxProperties = struct {
    /// The HCX offer, example VMware MaaS Cloud Provider (Enterprise)
    offer: []const u8,
    /// The type of private cloud addon
    addon_type: []const u8,
    /// HCX management network.
    management_network: ?[]const u8 = null,
    /// HCX uplink network
    uplink_network: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an Arc addon
pub const AddonArcProperties = struct {
    /// The VMware vCenter resource ID
    v_center: ?[]const u8 = null,
    /// The type of private cloud addon
    addon_type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Metadata pertaining to creation and last modification of the resource.
pub const SystemData = struct {
    /// The identity that created the resource.
    created_by: ?[]const u8 = null,
    /// The type of identity that created the resource.
    created_by_type: ?enums.createdByType = null,
    /// The timestamp of resource creation (UTC).
    created_at: ?[]const u8 = null,
    /// The identity that last modified the resource.
    last_modified_by: ?[]const u8 = null,
    /// The type of identity that last modified the resource.
    last_modified_by_type: ?enums.createdByType = null,
    /// The timestamp of resource last modification (UTC)
    last_modified_at: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Standard Azure Resource Manager operation status response, used as the response
/// body for `GetResourceOperationStatus`.
pub const ArmOperationStatusResourceProvisioningState = struct {
    /// The operation status
    status: enums.ResourceProvisioningState,
    /// The unique identifier for the operationStatus resource
    id: []const u8,
    /// The name of the operationStatus resource
    name: ?[]const u8 = null,
    /// Operation start time
    start_time: ?[]const u8 = null,
    /// Operation complete time
    end_time: ?[]const u8 = null,
    /// The progress made toward completing the operation
    percent_complete: ?f64 = null,
    /// Errors that occurred if the operation ended with Canceled or Failed status
    @"error": ?ErrorDetail = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a ExpressRouteAuthorization list operation.
pub const ExpressRouteAuthorizationList = struct {
    /// The ExpressRouteAuthorization items on this page
    value: []const ExpressRouteAuthorization,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// ExpressRoute Circuit Authorization
pub const ExpressRouteAuthorization = struct {
    /// The resource-specific properties for this resource.
    properties: ?ExpressRouteAuthorizationProperties = null,
    /// Name of the ExpressRoute Circuit Authorization
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an ExpressRoute Circuit Authorization resource
pub const ExpressRouteAuthorizationProperties = struct {
    /// The state of the ExpressRoute Circuit Authorization provisioning
    provisioning_state: ?enums.ExpressRouteAuthorizationProvisioningState = null,
    /// The ID of the ExpressRoute Circuit Authorization
    express_route_authorization_id: ?[]const u8 = null,
    /// The key of the ExpressRoute Circuit Authorization
    express_route_authorization_key: ?[]const u8 = null,
    /// The ID of the ExpressRoute Circuit
    express_route_id: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a CloudLink list operation.
pub const CloudLinkList = struct {
    /// The CloudLink items on this page
    value: []const CloudLink,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A cloud link resource
pub const CloudLink = struct {
    /// The resource-specific properties for this resource.
    properties: ?CloudLinkProperties = null,
    /// Name of the cloud link.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a cloud link.
pub const CloudLinkProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.CloudLinkProvisioningState = null,
    /// The state of the cloud link.
    status: ?enums.CloudLinkStatus = null,
    /// Identifier of the other private cloud participating in the link.
    linked_cloud: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a Cluster list operation.
pub const ClusterList = struct {
    /// The Cluster items on this page
    value: []const Cluster,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A cluster resource
pub const Cluster = struct {
    /// The resource-specific properties for this resource.
    properties: ?ClusterProperties = null,
    /// The SKU (Stock Keeping Unit) assigned to this resource.
    sku: Sku,
    /// Name of the cluster
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a cluster
pub const ClusterProperties = struct {
    /// The cluster size
    cluster_size: ?i32 = null,
    /// The state of the cluster provisioning
    provisioning_state: ?enums.ClusterProvisioningState = null,
    /// The identity
    cluster_id: ?i32 = null,
    /// The hosts
    hosts: ?[]const []const u8 = null,
    /// Name of the vsan datastore associated with the cluster
    vsan_datastore_name: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The resource model definition representing SKU
pub const Sku = struct {
    /// The name of the SKU. Ex - P3. It is typically a letter+number code
    name: []const u8,
    /// This field is required to be implemented by the Resource Provider if the service has more than one tier, but is not required on a PUT.
    tier: ?enums.SkuTier = null,
    /// The SKU size. When the name field is the combination of tier and some other value, this would be the standalone code.
    size: ?[]const u8 = null,
    /// If the service has different generations of hardware, for the same SKU, then that can be captured here.
    family: ?[]const u8 = null,
    /// If the SKU supports scale out/in then the capacity integer should be included. If scale out/in is not possible for the resource this may be omitted.
    capacity: ?i32 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An update of a cluster resource
pub const ClusterUpdate = struct {
    /// The SKU (Stock Keeping Unit) assigned to this resource.
    sku: ?Sku = null,
    /// The properties of a cluster resource that may be updated
    properties: ?ClusterUpdateProperties = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a cluster that may be updated
pub const ClusterUpdateProperties = struct {
    /// The cluster size
    cluster_size: ?i32 = null,
    /// The hosts
    hosts: ?[]const []const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// List of all zones and associated hosts for a cluster
pub const ClusterZoneList = struct {
    /// Zone and associated hosts info
    zones: ?[]const ClusterZone = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Zone and associated hosts info
pub const ClusterZone = struct {
    /// List of hosts belonging to the availability zone in a cluster
    hosts: ?[]const []const u8 = null,
    /// Availability zone identifier
    zone: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a Datastore list operation.
pub const DatastoreList = struct {
    /// The Datastore items on this page
    value: []const Datastore,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A datastore resource
pub const Datastore = struct {
    /// The resource-specific properties for this resource.
    properties: ?DatastoreProperties = null,
    /// Name of the datastore
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a datastore
pub const DatastoreProperties = struct {
    /// The state of the datastore provisioning
    provisioning_state: ?enums.DatastoreProvisioningState = null,
    /// An Azure NetApp Files volume
    net_app_volume: ?NetAppVolume = null,
    /// An iSCSI volume
    disk_pool_volume: ?DiskPoolVolume = null,
    /// An Elastic SAN volume
    elastic_san_volume: ?ElasticSanVolume = null,
    /// A Pure Storage volume
    pure_storage_volume: ?PureStorageVolume = null,
    /// The operational status of the datastore
    status: ?enums.DatastoreStatus = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An Azure NetApp Files volume from Microsoft.NetApp provider
pub const NetAppVolume = struct {
    /// Azure resource ID of the NetApp volume
    id: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An iSCSI volume from Microsoft.StoragePool provider
pub const DiskPoolVolume = struct {
    /// Azure resource ID of the iSCSI target
    target_id: []const u8,
    /// Name of the LUN to be used for datastore
    lun_name: []const u8,
    /// Mode that describes whether the LUN has to be mounted as a datastore or
/// attached as a LUN
    mount_option: ?enums.MountOptionEnum = null,
    /// Device path
    path: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An Elastic SAN volume from Microsoft.ElasticSan provider
pub const ElasticSanVolume = struct {
    /// Azure resource ID of the Elastic SAN Volume
    target_id: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A Pure Storage volume from PureStorage.Block provider
pub const PureStorageVolume = struct {
    /// Azure resource ID of the Pure Storage Pool
    storage_pool_id: []const u8,
    /// Volume size to be used to create a Virtual Volumes (vVols) datastore
    size_gb: i32,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a GlobalReachConnection list operation.
pub const GlobalReachConnectionList = struct {
    /// The GlobalReachConnection items on this page
    value: []const GlobalReachConnection,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A global reach connection resource
pub const GlobalReachConnection = struct {
    /// The resource-specific properties for this resource.
    properties: ?GlobalReachConnectionProperties = null,
    /// Name of the global reach connection
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a global reach connection
pub const GlobalReachConnectionProperties = struct {
    /// The state of the  ExpressRoute Circuit Authorization provisioning
    provisioning_state: ?enums.GlobalReachConnectionProvisioningState = null,
    /// The network used for global reach carved out from the original network block
/// provided for the private cloud
    address_prefix: ?[]const u8 = null,
    /// Authorization key from the peer express route used for the global reach
/// connection
    authorization_key: ?[]const u8 = null,
    /// The connection status of the global reach connection
    circuit_connection_status: ?enums.GlobalReachConnectionStatus = null,
    /// Identifier of the ExpressRoute Circuit to peer with in the global reach
/// connection
    peer_express_route_circuit: ?[]const u8 = null,
    /// The ID of the Private Cloud's ExpressRoute Circuit that is participating in the
/// global reach connection
    express_route_id: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a HcxEnterpriseSite list operation.
pub const HcxEnterpriseSiteList = struct {
    /// The HcxEnterpriseSite items on this page
    value: []const HcxEnterpriseSite,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An HCX Enterprise Site resource
pub const HcxEnterpriseSite = struct {
    /// The resource-specific properties for this resource.
    properties: ?HcxEnterpriseSiteProperties = null,
    /// Name of the HCX Enterprise Site
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an HCX Enterprise Site
pub const HcxEnterpriseSiteProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.HcxEnterpriseSiteProvisioningState = null,
    /// The activation key
    activation_key: ?[]const u8 = null,
    /// The status of the HCX Enterprise Site
    status: ?enums.HcxEnterpriseSiteStatus = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a Host list operation.
pub const HostListResult = struct {
    /// The Host items on this page
    value: []const Host,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A host resource
pub const Host = struct {
    /// The resource-specific properties for this resource.
    properties: ?HostProperties = null,
    /// The availability zones.
    zones: ?[]const []const u8 = null,
    /// The SKU (Stock Keeping Unit) assigned to this resource.
    sku: ?Sku = null,
    /// The host identifier.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a host.
pub const HostProperties = struct {
    /// The kind of host
    kind: enums.HostKind,
    /// The state of the host provisioning.
    provisioning_state: ?enums.HostProvisioningState = null,
    /// Display name of the host in VMware vCenter.
    display_name: ?[]const u8 = null,
    /// vCenter managed object reference ID of the host.
    mo_ref_id: ?[]const u8 = null,
    /// Fully qualified domain name of the host.
    fqdn: ?[]const u8 = null,
    /// If provided, the host is in maintenance. The value is the reason for maintenance.
    maintenance: ?enums.HostMaintenance = null,
    fault_domain: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a general host.
pub const GeneralHostProperties = struct {
    /// The kind of host.
    kind: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a specialized host.
pub const SpecializedHostProperties = struct {
    /// The kind of host is specialized.
    kind: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a IscsiPath list operation.
pub const IscsiPathListResult = struct {
    /// The IscsiPath items on this page
    value: []const IscsiPath,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An iSCSI path resource
pub const IscsiPath = struct {
    /// The resource-specific properties for this resource.
    properties: ?IscsiPathProperties = null,
    /// Name of the iSCSI path resource
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of an iSCSI path resource
pub const IscsiPathProperties = struct {
    /// The state of the iSCSI path provisioning
    provisioning_state: ?enums.IscsiPathProvisioningState = null,
    /// CIDR Block for iSCSI path.
    network_block: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a License list operation.
pub const LicenseListResult = struct {
    /// The License items on this page
    value: []const License,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A license resource
pub const License = struct {
    /// The resource-specific properties for this resource.
    properties: ?LicenseProperties = null,
    /// Name of the license.
    name: enums.LicenseName,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a license
pub const LicenseProperties = struct {
    /// License kind
    kind: enums.LicenseKind,
    /// The state of the license provisioning
    provisioning_state: ?enums.LicenseProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a VMware Firewall license
pub const VmwareFirewallLicenseProperties = struct {
    /// License kind
    kind: []const u8,
    /// License key
    license_key: ?[]const u8 = null,
    /// Number of cores included in the license, measured per hour
    cores: i32,
    /// UTC datetime when the license expires
    end_date: []const u8,
    /// The Broadcom site ID associated with the license.
    broadcom_site_id: ?[]const u8 = null,
    /// The Broadcom contract number associated with the license.
    broadcom_contract_number: ?[]const u8 = null,
    /// Additional labels passed through for license reporting.
    labels: ?[]const Label = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A key-value pair representing a label.
pub const Label = struct {
    /// The key of the label.
    key: []const u8,
    /// The value of the label.
    value: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Subscription trial availability
pub const Trial = struct {
    /// Trial status
    status: ?enums.TrialStatus = null,
    /// Number of trial hosts available
    available_hosts: ?i32 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Subscription quotas
pub const Quota = struct {
    /// Remaining hosts quota by sku type
    hosts_remaining: ?std.json.ArrayHashMap(i32) = null,
    /// Host quota is active for current subscription
    quota_enabled: ?enums.QuotaEnabled = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a Maintenance list operation.
pub const MaintenanceListResult = struct {
    /// The Maintenance items on this page
    value: []const Maintenance,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A cluster resource
pub const Maintenance = struct {
    /// The resource-specific properties for this resource.
    properties: ?MaintenanceProperties = null,
    /// Name of the maintenance
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// properties of a maintenance
pub const MaintenanceProperties = struct {
    /// type of maintenance
    component: ?enums.MaintenanceType = null,
    /// Display name for maintenance
    display_name: ?[]const u8 = null,
    /// Cluster ID for on which maintenance will be applied. Empty if maintenance is at private cloud level
    cluster_id: ?i32 = null,
    /// Link to maintenance info
    info_link: ?[]const u8 = null,
    /// Impact on the resource during maintenance period
    impact: ?[]const u8 = null,
    /// If maintenance is scheduled by Microsoft
    scheduled_by_microsoft: ?bool = null,
    /// The state of the maintenance
    state: ?MaintenanceState = null,
    /// Scheduled maintenance start time
    scheduled_start_time: ?[]const u8 = null,
    /// Estimated time maintenance will take in minutes
    estimated_duration_in_minutes: ?i64 = null,
    /// The provisioning state
    provisioning_state: ?enums.MaintenanceProvisioningState = null,
    /// Operations on  maintenance
    operations: ?[]const MaintenanceManagementOperation = null,
    /// Indicates whether the maintenance is ready to proceed
    maintenance_readiness: ?MaintenanceReadiness = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// state of the maintenance
pub const MaintenanceState = struct {
    /// Customer presentable maintenance state
    name: ?enums.MaintenanceStateName = null,
    /// Failure/Success info
    message: ?[]const u8 = null,
    /// Time when current state started
    started_at: ?[]const u8 = null,
    /// Time when current state ended
    ended_at: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Defines operations that can be performed on maintenance
pub const MaintenanceManagementOperation = struct {
    /// The kind of operation
    kind: enums.MaintenanceManagementOperationKind,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Scheduling window constraint
pub const ScheduleOperation = struct {
    /// The kind of operation
    kind: []const u8,
    /// If scheduling is disabled
    is_disabled: ?bool = null,
    /// Reason for schedule disabled
    disabled_reason: ?[]const u8 = null,
    /// Constraints for scheduling maintenance
    constraints: ?[]const ScheduleOperationConstraint = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Defines constraints for schedule operation on maintenance
pub const ScheduleOperationConstraint = struct {
    /// The kind of operation
    kind: enums.ScheduleOperationConstraintKind,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Time window in which Customer has option to schedule maintenance
pub const SchedulingWindow = struct {
    /// The kind of constraint
    kind: []const u8,
    /// Start date time
    starts_at: []const u8,
    /// End date Time
    ends_at: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Time window in which Customer can to schedule maintenance
pub const AvailableWindowForMaintenanceWhileScheduleOperation = struct {
    /// The kind of constraint
    kind: []const u8,
    /// Start date time
    starts_at: []const u8,
    /// End date Time
    ends_at: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Time ranges blocked for scheduling maintenance
pub const BlockedWhileScheduleOperation = struct {
    /// The kind of constraint
    kind: []const u8,
    /// Category of blocked date
    category: enums.BlockedDatesConstraintCategory,
    /// Date ranges blocked for schedule
    time_ranges: ?[]const BlockedDatesConstraintTimeRange = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Blocked Time range Constraints for maintenance
pub const BlockedDatesConstraintTimeRange = struct {
    /// Start date time
    starts_at: []const u8,
    /// End date Time
    ends_at: []const u8,
    /// Reason category for blocking maintenance reschedule
    reason: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Constraints for rescheduling maintenance
pub const RescheduleOperation = struct {
    /// The kind of operation
    kind: []const u8,
    /// If rescheduling is disabled
    is_disabled: ?bool = null,
    /// Reason for reschedule disabled
    disabled_reason: ?[]const u8 = null,
    /// Constraints for rescheduling maintenance
    constraints: ?[]const RescheduleOperationConstraint = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Defines constraints for reschedule operation on maintenance
pub const RescheduleOperationConstraint = struct {
    /// The kind of operation
    kind: enums.RescheduleOperationConstraintKind,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Time window in which Customer can reschedule maintenance
pub const AvailableWindowForMaintenanceWhileRescheduleOperation = struct {
    /// The kind of constraint
    kind: []const u8,
    /// Start date time
    starts_at: []const u8,
    /// End date Time
    ends_at: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Time ranges blocked for rescheduling maintenance
pub const BlockedWhileRescheduleOperation = struct {
    /// The kind of constraint
    kind: []const u8,
    /// Category of blocked date
    category: enums.BlockedDatesConstraintCategory,
    /// Date ranges blocked for schedule
    time_ranges: ?[]const BlockedDatesConstraintTimeRange = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Refresh MaintenanceReadiness status
pub const MaintenanceReadinessRefreshOperation = struct {
    /// The kind of operation
    kind: []const u8,
    /// If maintenanceReadiness refresh is disabled
    is_disabled: ?bool = null,
    /// Reason disabling refresh for maintenanceReadiness
    disabled_reason: ?[]const u8 = null,
    /// Status of the operation
    status: ?enums.MaintenanceReadinessRefreshOperationStatus = null,
    /// Indicates if the operation was refreshed by Microsoft
    refreshed_by_microsoft: ?bool = null,
    /// Additional message about the operation
    message: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Maintenance readiness details
pub const MaintenanceReadiness = struct {
    /// The type of maintenance readiness check
    type: enums.MaintenanceCheckType,
    /// The current readiness status of maintenance
    status: enums.MaintenanceReadinessStatus,
    /// A summary message of the readiness check result
    message: ?[]const u8 = null,
    /// A list of failed checks, if any
    failed_checks: ?[]const MaintenanceFailedCheck = null,
    /// The timestamp of the last readiness update
    last_updated: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Details about a failed maintenance check
pub const MaintenanceFailedCheck = struct {
    /// The name of the failed check
    name: ?[]const u8 = null,
    /// A list of resources impacted by the failed check
    impacted_resources: ?[]const ImpactedMaintenanceResource = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Details about a resource impacted by a failed check
pub const ImpactedMaintenanceResource = struct {
    /// The ID of the impacted resource
    id: ?[]const u8 = null,
    /// A list of errors associated with the impacted resource
    errors: ?[]const ImpactedMaintenanceResourceError = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Details about an error affecting a resource
pub const ImpactedMaintenanceResourceError = struct {
    /// The error code
    error_code: ?[]const u8 = null,
    /// The name of the error
    name: ?[]const u8 = null,
    /// Additional details about the error
    details: ?[]const u8 = null,
    /// Steps to resolve the error
    resolution_steps: ?[]const []const u8 = null,
    /// Indicates whether action is required by the customer
    action_required: ?bool = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// reschedule a maintenance
pub const MaintenanceReschedule = struct {
    /// reschedule time
    reschedule_time: ?[]const u8 = null,
    /// rescheduling reason
    message: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// schedule a maintenance
pub const MaintenanceSchedule = struct {
    /// schedule time
    schedule_time: ?[]const u8 = null,
    /// scheduling message
    message: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a PlacementPolicy list operation.
pub const PlacementPoliciesList = struct {
    /// The PlacementPolicy items on this page
    value: []const PlacementPolicy,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A vSphere Distributed Resource Scheduler (DRS) placement policy
pub const PlacementPolicy = struct {
    /// The resource-specific properties for this resource.
    properties: ?PlacementPolicyProperties = null,
    /// Name of the placement policy.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Abstract placement policy properties
pub const PlacementPolicyProperties = struct {
    /// Placement Policy type
    type: enums.PlacementPolicyType,
    /// Whether the placement policy is enabled or disabled
    state: ?enums.PlacementPolicyState = null,
    /// Display name of the placement policy
    display_name: ?[]const u8 = null,
    /// The provisioning state
    provisioning_state: ?enums.PlacementPolicyProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// VM-VM placement policy properties
pub const VmPlacementPolicyProperties = struct {
    /// Virtual machine members list
    vm_members: []const []const u8,
    /// placement policy affinity type
    affinity_type: enums.AffinityType,
    /// placement policy type
    type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// VM-Host placement policy properties
pub const VmHostPlacementPolicyProperties = struct {
    /// Virtual machine members list
    vm_members: []const []const u8,
    /// Host members list
    host_members: []const []const u8,
    /// placement policy affinity type
    affinity_type: enums.AffinityType,
    /// vm-host placement policy affinity strength (should/must)
    affinity_strength: ?enums.AffinityStrength = null,
    /// placement policy azure hybrid benefit opt-in type
    azure_hybrid_benefit_type: ?enums.AzureHybridBenefitType = null,
    /// placement policy type
    type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An update of a DRS placement policy resource
pub const PlacementPolicyUpdate = struct {
    /// The properties of a placement policy resource that may be updated
    properties: ?PlacementPolicyUpdateProperties = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a placement policy resource that may be updated
pub const PlacementPolicyUpdateProperties = struct {
    /// Whether the placement policy is enabled or disabled
    state: ?enums.PlacementPolicyState = null,
    /// Virtual machine members list
    vm_members: ?[]const []const u8 = null,
    /// Host members list
    host_members: ?[]const []const u8 = null,
    /// vm-host placement policy affinity strength (should/must)
    affinity_strength: ?enums.AffinityStrength = null,
    /// placement policy azure hybrid benefit opt-in type
    azure_hybrid_benefit_type: ?enums.AzureHybridBenefitType = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a PrivateCloud list operation.
pub const PrivateCloudList = struct {
    /// The PrivateCloud items on this page
    value: []const PrivateCloud,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A private cloud resource
pub const PrivateCloud = struct {
    /// The resource-specific properties for this resource.
    properties: ?PrivateCloudProperties = null,
    /// The SKU (Stock Keeping Unit) assigned to this resource.
    sku: Sku,
    /// The managed service identities assigned to this resource.
    identity: ?SystemAssignedServiceIdentity = null,
    /// The availability zones.
    zones: ?[]const []const u8 = null,
    /// Name of the private cloud
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a private cloud resource
pub const PrivateCloudProperties = struct {
    /// The default cluster used for management
    management_cluster: ManagementCluster,
    /// Connectivity to internet is enabled or disabled
    internet: ?enums.InternetEnum = null,
    /// vCenter Single Sign On Identity Sources
    identity_sources: ?[]const IdentitySource = null,
    /// Properties describing how the cloud is distributed across availability zones
    availability: ?AvailabilityProperties = null,
    /// Customer managed key encryption, can be enabled or disabled
    encryption: ?Encryption = null,
    /// Array of additional networks noncontiguous with networkBlock. Networks must be
/// unique and non-overlapping across VNet in your subscription, on-premise, and
/// this privateCloud networkBlock attribute. Make sure the CIDR format conforms to
/// (A.B.C.D/X).
    extended_network_blocks: ?[]const []const u8 = null,
    /// The provisioning state
    provisioning_state: ?enums.PrivateCloudProvisioningState = null,
    /// An ExpressRoute Circuit
    circuit: ?Circuit = null,
    /// The endpoints
    endpoints: ?Endpoints = null,
    /// The block of addresses should be unique across VNet in your subscription as
/// well as on-premise. Make sure the CIDR format is conformed to (A.B.C.D/X) where
/// A,B,C,D are between 0 and 255, and X is between 0 and 22
    network_block: []const u8,
    /// Network used to access vCenter Server and NSX-T Manager
    management_network: ?[]const u8 = null,
    /// Used for virtual machine cold migration, cloning, and snapshot migration
    provisioning_network: ?[]const u8 = null,
    /// Used for live migration of virtual machines
    vmotion_network: ?[]const u8 = null,
    /// Optionally, set the vCenter admin password when the private cloud is created
    vcenter_password: ?[]const u8 = null,
    /// Optionally, set the NSX-T Manager password when the private cloud is created
    nsxt_password: ?[]const u8 = null,
    /// Thumbprint of the vCenter Server SSL certificate
    vcenter_certificate_thumbprint: ?[]const u8 = null,
    /// Thumbprint of the NSX-T Manager SSL certificate
    nsxt_certificate_thumbprint: ?[]const u8 = null,
    /// Array of cloud link IDs from other clouds that connect to this one
    external_cloud_links: ?[]const []const u8 = null,
    /// A secondary expressRoute circuit from a separate AZ. Only present in a
/// stretched private cloud
    secondary_circuit: ?Circuit = null,
    /// Flag to indicate whether the private cloud has the quota for provisioned NSX
/// Public IP count raised from 64 to 1024
    nsx_public_ip_quota_raised: ?enums.NsxPublicIpQuotaRaisedEnum = null,
    /// Azure resource ID of the virtual network
    virtual_network_id: ?[]const u8 = null,
    /// The type of DNS zone to use.
    dns_zone_type: ?enums.DnsZoneType = null,
    /// The private cloud license
    vcf_license: ?VcfLicense = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a management cluster
pub const ManagementCluster = struct {
    /// The cluster size
    cluster_size: ?i32 = null,
    /// The state of the cluster provisioning
    provisioning_state: ?enums.ClusterProvisioningState = null,
    /// The identity
    cluster_id: ?i32 = null,
    /// The hosts
    hosts: ?[]const []const u8 = null,
    /// Name of the vsan datastore associated with the cluster
    vsan_datastore_name: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// vCenter Single Sign On Identity Source
pub const IdentitySource = struct {
    /// The name of the identity source
    name: ?[]const u8 = null,
    /// The domain's NetBIOS name
    alias: ?[]const u8 = null,
    /// The domain's DNS name
    domain: ?[]const u8 = null,
    /// The base distinguished name for users
    base_user_dn: ?[]const u8 = null,
    /// The base distinguished name for groups
    base_group_dn: ?[]const u8 = null,
    /// Primary server URL
    primary_server: ?[]const u8 = null,
    /// Secondary server URL
    secondary_server: ?[]const u8 = null,
    /// Protect LDAP communication using SSL certificate (LDAPS)
    ssl: ?enums.SslEnum = null,
    /// The ID of an Active Directory user with a minimum of read-only access to Base
/// DN for users and group
    username: ?[]const u8 = null,
    /// The password of the Active Directory user with a minimum of read-only access to
/// Base DN for users and groups.
    password: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties describing private cloud availability zone distribution
pub const AvailabilityProperties = struct {
    /// The availability strategy for the private cloud
    strategy: ?enums.AvailabilityStrategy = null,
    /// The primary availability zone for the private cloud
    zone: ?i32 = null,
    /// The secondary availability zone for the private cloud
    secondary_zone: ?i32 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of customer managed encryption key
pub const Encryption = struct {
    /// Status of customer managed encryption key
    status: ?enums.EncryptionState = null,
    /// The key vault where the encryption key is stored
    key_vault_properties: ?EncryptionKeyVaultProperties = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An Encryption Key
pub const EncryptionKeyVaultProperties = struct {
    /// The name of the key.
    key_name: ?[]const u8 = null,
    /// The version of the key.
    key_version: ?[]const u8 = null,
    /// The auto-detected version of the key if versionType is auto-detected.
    auto_detected_key_version: ?[]const u8 = null,
    /// The URL of the vault.
    key_vault_url: ?[]const u8 = null,
    /// The state of key provided
    key_state: ?enums.EncryptionKeyStatus = null,
    /// Property of the key if user provided or auto detected
    version_type: ?enums.EncryptionVersionType = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An ExpressRoute Circuit
pub const Circuit = struct {
    /// CIDR of primary subnet
    primary_subnet: ?[]const u8 = null,
    /// CIDR of secondary subnet
    secondary_subnet: ?[]const u8 = null,
    /// Identifier of the ExpressRoute Circuit (Microsoft Colo only)
    express_route_id: ?[]const u8 = null,
    /// ExpressRoute Circuit private peering identifier
    express_route_private_peering_id: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Endpoint addresses
pub const Endpoints = struct {
    /// Endpoint FQDN for the NSX-T Data Center manager
    nsxt_manager: ?[]const u8 = null,
    /// Endpoint FQDN for Virtual Center Server Appliance
    vcsa: ?[]const u8 = null,
    /// Endpoint FQDN for the HCX Cloud Manager
    hcx_cloud_manager: ?[]const u8 = null,
    /// Endpoint IP for the NSX-T Data Center manager
    nsxt_manager_ip: ?[]const u8 = null,
    /// Endpoint IP for Virtual Center Server Appliance
    vcenter_ip: ?[]const u8 = null,
    /// Endpoint IP for the HCX Cloud Manager
    hcx_cloud_manager_ip: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A VMware Cloud Foundation license
pub const VcfLicense = struct {
    /// License kind
    kind: enums.VcfLicenseKind,
    /// The state of the license provisioning
    provisioning_state: ?enums.LicenseProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A VMware Cloud Foundation (VCF) 5.0 license
pub const Vcf5License = struct {
    /// License kind
    kind: []const u8,
    /// License key
    license_key: ?[]const u8 = null,
    /// Number of cores included in the license
    cores: i32,
    /// UTC datetime when the license expires
    end_date: []const u8,
    /// The Broadcom site ID associated with the license.
    broadcom_site_id: ?[]const u8 = null,
    /// The Broadcom contract number associated with the license.
    broadcom_contract_number: ?[]const u8 = null,
    /// Additional labels passed through for license reporting.
    labels: ?[]const Label = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Managed service identity (either system assigned, or none)
pub const SystemAssignedServiceIdentity = struct {
    /// The service principal ID of the system assigned identity. This property will only be provided for a system assigned identity.
    principal_id: ?[]const u8 = null,
    /// The tenant ID of the system assigned identity. This property will only be provided for a system assigned identity.
    tenant_id: ?[]const u8 = null,
    /// The type of managed identity assigned to this resource.
    type: enums.SystemAssignedServiceIdentityType,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An update to a private cloud resource
pub const PrivateCloudUpdate = struct {
    /// Resource tags.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// The SKU (Stock Keeping Unit) assigned to this resource.
    sku: ?Sku = null,
    /// The managed service identities assigned to this resource.
    identity: ?SystemAssignedServiceIdentity = null,
    /// The updatable properties of a private cloud resource
    properties: ?PrivateCloudUpdateProperties = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a private cloud resource that may be updated
pub const PrivateCloudUpdateProperties = struct {
    /// The default cluster used for management
    management_cluster: ?ManagementCluster = null,
    /// Connectivity to internet is enabled or disabled
    internet: ?enums.InternetEnum = null,
    /// vCenter Single Sign On Identity Sources
    identity_sources: ?[]const IdentitySource = null,
    /// Properties describing how the cloud is distributed across availability zones
    availability: ?AvailabilityProperties = null,
    /// Customer managed key encryption, can be enabled or disabled
    encryption: ?Encryption = null,
    /// Array of additional networks noncontiguous with networkBlock. Networks must be
/// unique and non-overlapping across VNet in your subscription, on-premise, and
/// this privateCloud networkBlock attribute. Make sure the CIDR format conforms to
/// (A.B.C.D/X).
    extended_network_blocks: ?[]const []const u8 = null,
    /// The type of DNS zone to use.
    dns_zone_type: ?enums.DnsZoneType = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Administrative credentials for accessing vCenter and NSX-T
pub const AdminCredentials = struct {
    /// NSX-T Manager username
    nsxt_username: ?[]const u8 = null,
    /// NSX-T Manager password
    nsxt_password: ?[]const u8 = null,
    /// vCenter admin username
    vcenter_username: ?[]const u8 = null,
    /// vCenter admin password
    vcenter_password: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a ProvisionedNetwork list operation.
pub const ProvisionedNetworkListResult = struct {
    /// The ProvisionedNetwork items on this page
    value: []const ProvisionedNetwork,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A provisioned network resource
pub const ProvisionedNetwork = struct {
    /// The resource-specific properties for this resource.
    properties: ?ProvisionedNetworkProperties = null,
    /// Name of the cloud link.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a provisioned network.
pub const ProvisionedNetworkProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.ProvisionedNetworkProvisioningState = null,
    /// The address prefixes of the provisioned network in CIDR notation.
    address_prefix: ?[]const u8 = null,
    /// The type of network provisioned.
    network_type: ?enums.ProvisionedNetworkTypes = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a PureStoragePolicy list operation.
pub const PureStoragePolicyListResult = struct {
    /// The PureStoragePolicy items on this page
    value: []const PureStoragePolicy,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An instance describing a Pure Storage Policy Based Management policy
pub const PureStoragePolicy = struct {
    /// The resource-specific properties for this resource.
    properties: ?PureStoragePolicyProperties = null,
    /// Name of the storage policy.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Properties of a Pure Storage Policy Based Management policy
pub const PureStoragePolicyProperties = struct {
    /// Definition of a Pure Storage Policy Based Management policy
    storage_policy_definition: []const u8,
    /// Azure resource ID of the Pure Storage Pool associated with the storage policy
    storage_pool_id: []const u8,
    /// The state of the Pure Storage Policy Based Management policy provisioning
    provisioning_state: ?enums.PureStoragePolicyProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a ScriptCmdlet list operation.
pub const ScriptCmdletsList = struct {
    /// The ScriptCmdlet items on this page
    value: []const ScriptCmdlet,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A cmdlet available for script execution
pub const ScriptCmdlet = struct {
    /// The resource-specific properties for this resource.
    properties: ?ScriptCmdletProperties = null,
    /// Name of the script cmdlet.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Properties of a pre-canned script
pub const ScriptCmdletProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.ScriptCmdletProvisioningState = null,
    /// Description of the scripts functionality
    description: ?[]const u8 = null,
    /// Recommended time limit for execution
    timeout: ?[]const u8 = null,
    /// Specifies whether a script cmdlet is intended to be invoked only through automation or visible to customers
    audience: ?enums.ScriptCmdletAudience = null,
    /// Parameters the script will accept
    parameters: ?[]const ScriptParameter = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An parameter that the script will accept
pub const ScriptParameter = struct {
    /// The type of parameter the script is expecting. psCredential is a
/// PSCredentialObject
    type: ?enums.ScriptParameterTypes = null,
    /// The parameter name that the script will expect a parameter value for
    name: ?[]const u8 = null,
    /// User friendly description of the parameter
    description: ?[]const u8 = null,
    /// Should this parameter be visible to arm and passed in the parameters argument
/// when executing
    visibility: ?enums.VisibilityParameterEnum = null,
    /// Is this parameter required or optional
    optional: ?enums.OptionalParamEnum = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a ScriptExecution list operation.
pub const ScriptExecutionsList = struct {
    /// The ScriptExecution items on this page
    value: []const ScriptExecution,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// An instance of a script executed by a user - custom or AVS
pub const ScriptExecution = struct {
    /// The resource-specific properties for this resource.
    properties: ?ScriptExecutionProperties = null,
    /// Name of the script cmdlet.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Properties of a user-invoked script
pub const ScriptExecutionProperties = struct {
    /// A reference to the script cmdlet resource if user is running a AVS script
    script_cmdlet_id: ?[]const u8 = null,
    /// Parameters the script will accept
    parameters: ?[]const ScriptExecutionParameter = null,
    /// Parameters that will be hidden/not visible to ARM, such as passwords and
/// credentials
    hidden_parameters: ?[]const ScriptExecutionParameter = null,
    /// Error message if the script was able to run, but if the script itself had
/// errors or powershell threw an exception
    failure_reason: ?[]const u8 = null,
    /// Time limit for execution
    timeout: []const u8,
    /// Time to live for the resource. If not provided, will be available for 60 days
    retention: ?[]const u8 = null,
    /// Time the script execution was submitted
    submitted_at: ?[]const u8 = null,
    /// Time the script execution was started
    started_at: ?[]const u8 = null,
    /// Time the script execution was finished
    finished_at: ?[]const u8 = null,
    /// The state of the script execution resource
    provisioning_state: ?enums.ScriptExecutionProvisioningState = null,
    /// Standard output stream from the powershell execution
    output: ?[]const []const u8 = null,
    /// User-defined dictionary.
    named_outputs: ?std.json.ArrayHashMap(ScriptExecutionPropertiesNamedOutput) = null,
    /// Standard information out stream from the powershell execution
    information: ?[]const []const u8 = null,
    /// Standard warning out stream from the powershell execution
    warnings: ?[]const []const u8 = null,
    /// Standard error output stream from the powershell execution
    errors: ?[]const []const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The arguments passed in to the execution
pub const ScriptExecutionParameter = struct {
    /// script execution parameter type
    type: enums.ScriptExecutionParameterType,
    /// The parameter name
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// a plain text value execution parameter
pub const ScriptSecureStringExecutionParameter = struct {
    /// A secure value for the passed parameter, not to be stored in logs
    secure_value: ?[]const u8 = null,
    /// The type of execution parameter
    type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// a plain text value execution parameter
pub const ScriptStringExecutionParameter = struct {
    /// The value for the passed parameter
    value: ?[]const u8 = null,
    /// The type of execution parameter
    type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// a powershell credential object
pub const PSCredentialExecutionParameter = struct {
    /// username for login
    username: ?[]const u8 = null,
    /// password for login
    password: ?[]const u8 = null,
    /// The type of execution parameter
    type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

pub const ScriptExecutionPropertiesNamedOutput = struct {

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a ScriptPackage list operation.
pub const ScriptPackagesList = struct {
    /// The ScriptPackage items on this page
    value: []const ScriptPackage,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Script Package resources available for execution
pub const ScriptPackage = struct {
    /// The resource-specific properties for this resource.
    properties: ?ScriptPackageProperties = null,
    /// Name of the script package.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Properties of a Script Package subresource
pub const ScriptPackageProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.ScriptPackageProvisioningState = null,
    /// User friendly description of the package
    description: ?[]const u8 = null,
    /// Module version
    version: ?[]const u8 = null,
    /// Company that created and supports the package
    company: ?[]const u8 = null,
    /// Link to support by the package vendor
    uri: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Paged collection of ResourceSku items
pub const PagedResourceSku = struct {
    /// The ResourceSku items on this page
    value: []const ResourceSku,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// A SKU for a resource.
pub const ResourceSku = struct {
    /// The type of resource the SKU applies to.
    resource_type: enums.ResourceSkuResourceType,
    /// The name of the SKU.
    name: []const u8,
    /// The tier of virtual machines in a scale set
    tier: ?[]const u8 = null,
    /// The size of the SKU.
    size: ?[]const u8 = null,
    /// The family of the SKU.
    family: ?[]const u8 = null,
    /// The set of locations that the SKU is available.
    locations: []const []const u8,
    /// A list of locations and availability zones in those locations where the SKU is available
    location_info: []const ResourceSkuLocationInfo,
    /// Name value pairs to describe the capability.
    capabilities: ?[]const ResourceSkuCapabilities = null,
    /// The restrictions of the SKU.
    restrictions: []const ResourceSkuRestrictions,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Describes an available Compute SKU Location Information.
pub const ResourceSkuLocationInfo = struct {
    /// Location of the SKU
    location: []const u8,
    /// List of availability zones where the SKU is supported.
    zones: []const []const u8,
    /// Gets details of capabilities available to a SKU in specific zones.
    zone_details: []const ResourceSkuZoneDetails,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Describes The zonal capabilities of a SKU.
pub const ResourceSkuZoneDetails = struct {
    /// Gets the set of zones that the SKU is available in with the specified capabilities.
    name: []const []const u8,
    /// A list of capabilities that are available for the SKU in the specified list of zones.
    capabilities: []const ResourceSkuCapabilities,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Describes The SKU capabilities object.
pub const ResourceSkuCapabilities = struct {
    /// The name of the SKU capability.
    name: []const u8,
    /// The value of the SKU capability.
    value: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The restrictions of the SKU.
pub const ResourceSkuRestrictions = struct {
    /// the type of restrictions.
    type: ?enums.ResourceSkuRestrictionsType = null,
    /// The value of restrictions. If the restriction type is set to location. This would be different locations where the SKU is restricted.
    values: []const []const u8,
    /// The information about the restriction where the SKU cannot be used.
    restriction_info: ResourceSkuRestrictionInfo,
    /// the reason for restriction.
    reason_code: ?enums.ResourceSkuRestrictionsReasonCode = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Describes an available Compute SKU Restriction Information.
pub const ResourceSkuRestrictionInfo = struct {
    /// Locations where the SKU is restricted
    locations: ?[]const []const u8 = null,
    /// List of availability zones where the SKU is restricted.
    zones: ?[]const []const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a VirtualMachine list operation.
pub const VirtualMachinesList = struct {
    /// The VirtualMachine items on this page
    value: []const VirtualMachine,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Virtual Machine
pub const VirtualMachine = struct {
    /// The resource-specific properties for this resource.
    properties: ?VirtualMachineProperties = null,
    /// ID of the virtual machine.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Virtual Machine Properties
pub const VirtualMachineProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.VirtualMachineProvisioningState = null,
    /// Display name of the VM.
    display_name: ?[]const u8 = null,
    /// vCenter managed object reference ID of the virtual machine
    mo_ref_id: ?[]const u8 = null,
    /// Path to virtual machine's folder starting from datacenter virtual machine folder
    folder_path: ?[]const u8 = null,
    /// Whether VM DRS-driven movement is restricted (enabled) or not (disabled)
    restrict_movement: ?enums.VirtualMachineRestrictMovementState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Set VM DRS-driven movement to restricted (enabled) or not (disabled)
pub const VirtualMachineRestrictMovement = struct {
    /// Whether VM DRS-driven movement is restricted (enabled) or not (disabled)
    restrict_movement: ?enums.VirtualMachineRestrictMovementState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Workload Network
pub const WorkloadNetwork = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkProperties = null,
    /// Name of the global reach connection
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The properties of a workload network
pub const WorkloadNetworkProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.WorkloadNetworkProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetwork list operation.
pub const WorkloadNetworkList = struct {
    /// The WorkloadNetwork items on this page
    value: []const WorkloadNetwork,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkDhcp list operation.
pub const WorkloadNetworkDhcpList = struct {
    /// The WorkloadNetworkDhcp items on this page
    value: []const WorkloadNetworkDhcp,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DHCP
pub const WorkloadNetworkDhcp = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkDhcpEntity = null,
    /// The ID of the DHCP configuration
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Base class for WorkloadNetworkDhcpServer and WorkloadNetworkDhcpRelay to
/// inherit from
pub const WorkloadNetworkDhcpEntity = struct {
    /// Type of DHCP: SERVER or RELAY.
    dhcp_type: enums.DhcpTypeEnum,
    /// Display name of the DHCP entity.
    display_name: ?[]const u8 = null,
    /// NSX Segments consuming DHCP.
    segments: ?[]const []const u8 = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkDhcpProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DHCP Server
pub const WorkloadNetworkDhcpServer = struct {
    /// DHCP Server Address.
    server_address: ?[]const u8 = null,
    /// DHCP Server Lease Time.
    lease_time: ?i64 = null,
    /// Type of DHCP: SERVER or RELAY.
    dhcp_type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DHCP Relay
pub const WorkloadNetworkDhcpRelay = struct {
    /// DHCP Relay Addresses. Max 3.
    server_addresses: ?[]const []const u8 = null,
    /// Type of DHCP: SERVER or RELAY.
    dhcp_type: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkDnsService list operation.
pub const WorkloadNetworkDnsServicesList = struct {
    /// The WorkloadNetworkDnsService items on this page
    value: []const WorkloadNetworkDnsService,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DNS Service
pub const WorkloadNetworkDnsService = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkDnsServiceProperties = null,
    /// ID of the DNS service.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DNS Service Properties
pub const WorkloadNetworkDnsServiceProperties = struct {
    /// Display name of the DNS Service.
    display_name: ?[]const u8 = null,
    /// DNS service IP of the DNS Service.
    dns_service_ip: ?[]const u8 = null,
    /// Default DNS zone of the DNS Service.
    default_dns_zone: ?[]const u8 = null,
    /// FQDN zones of the DNS Service.
    fqdn_zones: ?[]const []const u8 = null,
    /// DNS Service log level.
    log_level: ?enums.DnsServiceLogLevelEnum = null,
    /// DNS Service status.
    status: ?enums.DnsServiceStatusEnum = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkDnsServiceProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkDnsZone list operation.
pub const WorkloadNetworkDnsZonesList = struct {
    /// The WorkloadNetworkDnsZone items on this page
    value: []const WorkloadNetworkDnsZone,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DNS Zone
pub const WorkloadNetworkDnsZone = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkDnsZoneProperties = null,
    /// ID of the DNS zone.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX DNS Zone Properties
pub const WorkloadNetworkDnsZoneProperties = struct {
    /// Display name of the DNS Zone.
    display_name: ?[]const u8 = null,
    /// Domain names of the DNS Zone.
    domain: ?[]const []const u8 = null,
    /// DNS Server IP array of the DNS Zone.
    dns_server_ips: ?[]const []const u8 = null,
    /// Source IP of the DNS Zone.
    source_ip: ?[]const u8 = null,
    /// Number of DNS Services using the DNS zone.
    dns_services: ?i64 = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkDnsZoneProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkGateway list operation.
pub const WorkloadNetworkGatewayList = struct {
    /// The WorkloadNetworkGateway items on this page
    value: []const WorkloadNetworkGateway,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Gateway.
pub const WorkloadNetworkGateway = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkGatewayProperties = null,
    /// The ID of the NSX Gateway
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Properties of a NSX Gateway.
pub const WorkloadNetworkGatewayProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.WorkloadNetworkProvisioningState = null,
    /// Display name of the DHCP entity.
    display_name: ?[]const u8 = null,
    /// NSX Gateway Path.
    path: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkPortMirroring list operation.
pub const WorkloadNetworkPortMirroringList = struct {
    /// The WorkloadNetworkPortMirroring items on this page
    value: []const WorkloadNetworkPortMirroring,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Port Mirroring
pub const WorkloadNetworkPortMirroring = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkPortMirroringProperties = null,
    /// ID of the NSX port mirroring profile.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Port Mirroring Properties
pub const WorkloadNetworkPortMirroringProperties = struct {
    /// Display name of the port mirroring profile.
    display_name: ?[]const u8 = null,
    /// Direction of port mirroring profile.
    direction: ?enums.PortMirroringDirectionEnum = null,
    /// Source VM Group.
    source: ?[]const u8 = null,
    /// Destination VM Group.
    destination: ?[]const u8 = null,
    /// Port Mirroring Status.
    status: ?enums.PortMirroringStatusEnum = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkPortMirroringProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkPublicIP list operation.
pub const WorkloadNetworkPublicIPsList = struct {
    /// The WorkloadNetworkPublicIP items on this page
    value: []const WorkloadNetworkPublicIP,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Public IP Block
pub const WorkloadNetworkPublicIP = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkPublicIPProperties = null,
    /// ID of the DNS zone.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Public IP Block Properties
pub const WorkloadNetworkPublicIPProperties = struct {
    /// Display name of the Public IP Block.
    display_name: ?[]const u8 = null,
    /// Number of Public IPs requested.
    number_of_public_i_ps: ?i64 = null,
    /// CIDR Block of the Public IP Block.
    public_ip_block: ?[]const u8 = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkPublicIPProvisioningState = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkSegment list operation.
pub const WorkloadNetworkSegmentsList = struct {
    /// The WorkloadNetworkSegment items on this page
    value: []const WorkloadNetworkSegment,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Segment
pub const WorkloadNetworkSegment = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkSegmentProperties = null,
    /// The ID of the NSX Segment
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Segment Properties
pub const WorkloadNetworkSegmentProperties = struct {
    /// Display name of the segment.
    display_name: ?[]const u8 = null,
    /// Gateway which to connect segment to.
    connected_gateway: ?[]const u8 = null,
    /// Subnet which to connect segment to.
    subnet: ?WorkloadNetworkSegmentSubnet = null,
    /// Port Vif which segment is associated with.
    port_vif: ?[]const WorkloadNetworkSegmentPortVif = null,
    /// Segment status.
    status: ?enums.SegmentStatusEnum = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkSegmentProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Subnet configuration for segment
pub const WorkloadNetworkSegmentSubnet = struct {
    /// DHCP Range assigned for subnet.
    dhcp_ranges: ?[]const []const u8 = null,
    /// Gateway address.
    gateway_address: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// Ports and any VIF attached to segment.
pub const WorkloadNetworkSegmentPortVif = struct {
    /// Name of port or VIF attached to segment.
    port_name: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkVirtualMachine list operation.
pub const WorkloadNetworkVirtualMachinesList = struct {
    /// The WorkloadNetworkVirtualMachine items on this page
    value: []const WorkloadNetworkVirtualMachine,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Virtual Machine
pub const WorkloadNetworkVirtualMachine = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkVirtualMachineProperties = null,
    /// ID of the virtual machine.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX Virtual Machine Properties
pub const WorkloadNetworkVirtualMachineProperties = struct {
    /// The provisioning state of the resource.
    provisioning_state: ?enums.WorkloadNetworkProvisioningState = null,
    /// Display name of the VM.
    display_name: ?[]const u8 = null,
    /// Virtual machine type.
    vm_type: ?enums.VMTypeEnum = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// The response of a WorkloadNetworkVMGroup list operation.
pub const WorkloadNetworkVMGroupsList = struct {
    /// The WorkloadNetworkVMGroup items on this page
    value: []const WorkloadNetworkVMGroup,
    /// The link to the next page of items
    next_link: ?[]const u8 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX VM Group
pub const WorkloadNetworkVMGroup = struct {
    /// The resource-specific properties for this resource.
    properties: ?WorkloadNetworkVMGroupProperties = null,
    /// ID of the VM group.
    name: []const u8,

    pub const serde = .{ .rename_all = .camel_case };
};

/// NSX VM Group Properties
pub const WorkloadNetworkVMGroupProperties = struct {
    /// Display name of the VM group.
    display_name: ?[]const u8 = null,
    /// Virtual machine members of this group.
    members: ?[]const []const u8 = null,
    /// VM Group status.
    status: ?enums.VMGroupStatusEnum = null,
    /// The provisioning state
    provisioning_state: ?enums.WorkloadNetworkVMGroupProvisioningState = null,
    /// NSX revision number.
    revision: ?i64 = null,

    pub const serde = .{ .rename_all = .camel_case };
};

