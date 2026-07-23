//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

/// The intended executor of the operation; as in Resource Based Access Control (RBAC) and audit logs UX. Default value is "user,system"
pub const Origin = union(enum) {
    user,
    system,
    @"user,system",
    unrecognized: []const u8,

    const wire_names = .{
        .user = "user",
        .system = "system",
        .@"user,system" = "user,system",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Extensible enum. Indicates the action type. "Internal" refers to actions that are for internal only APIs.
pub const ActionType = union(enum) {
    internal,
    unrecognized: []const u8,

    const wire_names = .{
        .internal = "Internal",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Addon type
pub const AddonType = union(enum) {
    srm,
    vr,
    hcx,
    arc,
    unrecognized: []const u8,

    const wire_names = .{
        .srm = "SRM",
        .vr = "VR",
        .hcx = "HCX",
        .arc = "Arc",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .cancelled = "Cancelled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The kind of entity that created the resource.
pub const createdByType = union(enum) {
    user,
    application,
    managed_identity,
    key,
    unrecognized: []const u8,

    const wire_names = .{
        .user = "User",
        .application = "Application",
        .managed_identity = "ManagedIdentity",
        .key = "Key",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The provisioning state of a resource type.
pub const ResourceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Express Route Circuit Authorization provisioning state
pub const ExpressRouteAuthorizationProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// cloud link provisioning state
pub const CloudLinkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Cloud Link status
pub const CloudLinkStatus = union(enum) {
    active,
    building,
    deleting,
    failed,
    disconnected,
    unrecognized: []const u8,

    const wire_names = .{
        .active = "Active",
        .building = "Building",
        .deleting = "Deleting",
        .failed = "Failed",
        .disconnected = "Disconnected",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Cluster provisioning state
pub const ClusterProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    cancelled,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .cancelled = "Cancelled",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .cancelled = "Cancelled",
        .pending = "Pending",
        .creating = "Creating",
        .updating = "Updating",
        .deleting = "Deleting",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// mount option
pub const MountOptionEnum = union(enum) {
    mount,
    attach,
    unrecognized: []const u8,

    const wire_names = .{
        .mount = "MOUNT",
        .attach = "ATTACH",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// datastore status
pub const DatastoreStatus = union(enum) {
    unknown,
    accessible,
    inaccessible,
    attached,
    detached,
    lost_communication,
    dead_or_error,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "Unknown",
        .accessible = "Accessible",
        .inaccessible = "Inaccessible",
        .attached = "Attached",
        .detached = "Detached",
        .lost_communication = "LostCommunication",
        .dead_or_error = "DeadOrError",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Global Reach Connection provisioning state
pub const GlobalReachConnectionProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Global Reach Connection status
pub const GlobalReachConnectionStatus = union(enum) {
    connected,
    connecting,
    disconnected,
    unrecognized: []const u8,

    const wire_names = .{
        .connected = "Connected",
        .connecting = "Connecting",
        .disconnected = "Disconnected",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// HCX Enterprise Site provisioning state
pub const HcxEnterpriseSiteProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// HCX Enterprise Site status
pub const HcxEnterpriseSiteStatus = union(enum) {
    available,
    consumed,
    deactivated,
    deleted,
    unrecognized: []const u8,

    const wire_names = .{
        .available = "Available",
        .consumed = "Consumed",
        .deactivated = "Deactivated",
        .deleted = "Deleted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The kind of host.
pub const HostKind = union(enum) {
    general,
    specialized,
    unrecognized: []const u8,

    const wire_names = .{
        .general = "General",
        .specialized = "Specialized",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// provisioning state of the host
pub const HostProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The reason for host maintenance.
pub const HostMaintenance = union(enum) {
    replacement,
    upgrade,
    unrecognized: []const u8,

    const wire_names = .{
        .replacement = "Replacement",
        .upgrade = "Upgrade",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .pending = "Pending",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The kind of license.
pub const LicenseKind = union(enum) {
    vmware_firewall,
    unrecognized: []const u8,

    const wire_names = .{
        .vmware_firewall = "VmwareFirewall",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// provisioning state of the license
pub const LicenseProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The name of the license.
pub const LicenseName = union(enum) {
    vmware_firewall,
    unrecognized: []const u8,

    const wire_names = .{
        .vmware_firewall = "VmwareFirewall",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// trial status
pub const TrialStatus = union(enum) {
    trial_available,
    trial_used,
    trial_disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .trial_available = "TrialAvailable",
        .trial_used = "TrialUsed",
        .trial_disabled = "TrialDisabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// quota enabled
pub const QuotaEnabled = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Customer presentable maintenance state
pub const MaintenanceStateName = union(enum) {
    not_scheduled,
    scheduled,
    in_progress,
    success,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .not_scheduled = "NotScheduled",
        .scheduled = "Scheduled",
        .in_progress = "InProgress",
        .success = "Success",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// status filter for the maintenance
pub const MaintenanceStatusFilter = union(enum) {
    active,
    inactive,
    unrecognized: []const u8,

    const wire_names = .{
        .active = "Active",
        .inactive = "Inactive",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// type of the maintenance
pub const MaintenanceType = union(enum) {
    vcsa,
    esxi,
    nsxt,
    unrecognized: []const u8,

    const wire_names = .{
        .vcsa = "VCSA",
        .esxi = "ESXI",
        .nsxt = "NSXT",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// provisioning state of the maintenance
pub const MaintenanceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Defines the type of operation
pub const MaintenanceManagementOperationKind = union(enum) {
    schedule,
    reschedule,
    maintenance_readiness_refresh,
    unrecognized: []const u8,

    const wire_names = .{
        .schedule = "Schedule",
        .reschedule = "Reschedule",
        .maintenance_readiness_refresh = "MaintenanceReadinessRefresh",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Constraints for scheduling of maintenance
pub const ScheduleOperationConstraintKind = union(enum) {
    scheduling_window,
    available_window_for_maintenance_while_schedule_operation,
    blocked_while_schedule_operation,
    unrecognized: []const u8,

    const wire_names = .{
        .scheduling_window = "SchedulingWindow",
        .available_window_for_maintenance_while_schedule_operation = "AvailableWindowForMaintenance",
        .blocked_while_schedule_operation = "Blocked",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Reason for blocking operation on maintenance
pub const BlockedDatesConstraintCategory = union(enum) {
    hi_priority_event,
    quota_exhausted,
    holiday,
    unrecognized: []const u8,

    const wire_names = .{
        .hi_priority_event = "HiPriorityEvent",
        .quota_exhausted = "QuotaExhausted",
        .holiday = "Holiday",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Constraints for rescheduling of maintenance
pub const RescheduleOperationConstraintKind = union(enum) {
    available_window_for_maintenance_while_reschedule_operation,
    blocked_while_reschedule_operation,
    unrecognized: []const u8,

    const wire_names = .{
        .available_window_for_maintenance_while_reschedule_operation = "AvailableWindowForMaintenance",
        .blocked_while_reschedule_operation = "Blocked",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The status of an MaintenanceReadinessRefresh operation
pub const MaintenanceReadinessRefreshOperationStatus = union(enum) {
    in_progress,
    not_started,
    failed,
    not_applicable,
    unrecognized: []const u8,

    const wire_names = .{
        .in_progress = "InProgress",
        .not_started = "NotStarted",
        .failed = "Failed",
        .not_applicable = "NotApplicable",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Defines the type of maintenance readiness check
pub const MaintenanceCheckType = union(enum) {
    precheck,
    preflight,
    unrecognized: []const u8,

    const wire_names = .{
        .precheck = "Precheck",
        .preflight = "Preflight",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Defines the readiness status of maintenance
pub const MaintenanceReadinessStatus = union(enum) {
    ready,
    not_ready,
    data_not_available,
    not_applicable,
    unrecognized: []const u8,

    const wire_names = .{
        .ready = "Ready",
        .not_ready = "NotReady",
        .data_not_available = "DataNotAvailable",
        .not_applicable = "NotApplicable",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Placement Policy type
pub const PlacementPolicyType = union(enum) {
    vm_vm,
    vm_host,
    unrecognized: []const u8,

    const wire_names = .{
        .vm_vm = "VmVm",
        .vm_host = "VmHost",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Placement Policy state
pub const PlacementPolicyState = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Placement Policy provisioning state
pub const PlacementPolicyProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Affinity type
pub const AffinityType = union(enum) {
    affinity,
    anti_affinity,
    unrecognized: []const u8,

    const wire_names = .{
        .affinity = "Affinity",
        .anti_affinity = "AntiAffinity",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Affinity Strength
pub const AffinityStrength = union(enum) {
    should,
    must,
    unrecognized: []const u8,

    const wire_names = .{
        .should = "Should",
        .must = "Must",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Azure Hybrid Benefit type
pub const AzureHybridBenefitType = union(enum) {
    sql_host,
    none,
    unrecognized: []const u8,

    const wire_names = .{
        .sql_host = "SqlHost",
        .none = "None",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether internet is enabled or disabled
pub const InternetEnum = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether SSL is enabled or disabled
pub const SslEnum = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether the private clouds is available in a single zone or two zones
pub const AvailabilityStrategy = union(enum) {
    single_zone,
    dual_zone,
    unrecognized: []const u8,

    const wire_names = .{
        .single_zone = "SingleZone",
        .dual_zone = "DualZone",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether encryption is enabled or disabled
pub const EncryptionState = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether the the encryption key is connected or access denied
pub const EncryptionKeyStatus = union(enum) {
    connected,
    access_denied,
    unrecognized: []const u8,

    const wire_names = .{
        .connected = "Connected",
        .access_denied = "AccessDenied",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Whether the encryption version is fixed or auto-detected
pub const EncryptionVersionType = union(enum) {
    fixed,
    auto_detected,
    unrecognized: []const u8,

    const wire_names = .{
        .fixed = "Fixed",
        .auto_detected = "AutoDetected",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .cancelled = "Cancelled",
        .pending = "Pending",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// NSX public IP quota raised
pub const NsxPublicIpQuotaRaisedEnum = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The type of DNS zone.
pub const DnsZoneType = union(enum) {
    public,
    private,
    unrecognized: []const u8,

    const wire_names = .{
        .public = "Public",
        .private = "Private",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The kind of license.
pub const VcfLicenseKind = union(enum) {
    vcf5,
    unrecognized: []const u8,

    const wire_names = .{
        .vcf5 = "vcf5",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Type of managed service identity (either system assigned, or none).
pub const SystemAssignedServiceIdentityType = union(enum) {
    none,
    system_assigned,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "None",
        .system_assigned = "SystemAssigned",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// provisioned network provisioning state
pub const ProvisionedNetworkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .esx_management = "esxManagement",
        .esx_replication = "esxReplication",
        .hcx_management = "hcxManagement",
        .hcx_uplink = "hcxUplink",
        .vcenter_management = "vcenterManagement",
        .vmotion = "vmotion",
        .vsan = "vsan",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Pure Storage Policy Based Management policy provisioning state
pub const PureStoragePolicyProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// A script cmdlet provisioning state
pub const ScriptCmdletProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Specifies whether a script cmdlet is intended to be invoked only through automation or visible to customers
pub const ScriptCmdletAudience = union(enum) {
    automation,
    any,
    unrecognized: []const u8,

    const wire_names = .{
        .automation = "Automation",
        .any = "Any",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Script Parameter types
pub const ScriptParameterTypes = union(enum) {
    string,
    secure_string,
    credential,
    int,
    bool,
    float,
    unrecognized: []const u8,

    const wire_names = .{
        .string = "String",
        .secure_string = "SecureString",
        .credential = "Credential",
        .int = "Int",
        .bool = "Bool",
        .float = "Float",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Visibility Parameter
pub const VisibilityParameterEnum = union(enum) {
    visible,
    hidden,
    unrecognized: []const u8,

    const wire_names = .{
        .visible = "Visible",
        .hidden = "Hidden",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Optional Param
pub const OptionalParamEnum = union(enum) {
    optional,
    required,
    unrecognized: []const u8,

    const wire_names = .{
        .optional = "Optional",
        .required = "Required",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// script execution parameter type
pub const ScriptExecutionParameterType = union(enum) {
    value,
    secure_value,
    credential,
    unrecognized: []const u8,

    const wire_names = .{
        .value = "Value",
        .secure_value = "SecureValue",
        .credential = "Credential",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .pending = "Pending",
        .running = "Running",
        .cancelling = "Cancelling",
        .cancelled = "Cancelled",
        .deleting = "Deleting",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Script Output Stream type
pub const ScriptOutputStreamType = union(enum) {
    information,
    warning,
    output,
    @"error",
    unrecognized: []const u8,

    const wire_names = .{
        .information = "Information",
        .warning = "Warning",
        .output = "Output",
        .@"error" = "Error",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Script Package provisioning state
pub const ScriptPackageProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Describes the type of resource the SKU applies to.
pub const ResourceSkuResourceType = union(enum) {
    private_clouds,
    @"private_clouds/clusters",
    unrecognized: []const u8,

    const wire_names = .{
        .private_clouds = "privateClouds",
        .@"private_clouds/clusters" = "privateClouds/clusters",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Describes the kind of SKU restrictions that can exist
pub const ResourceSkuRestrictionsType = union(enum) {
    location,
    zone,
    unrecognized: []const u8,

    const wire_names = .{
        .location = "Location",
        .zone = "Zone",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Describes the reason for SKU restriction.
pub const ResourceSkuRestrictionsReasonCode = union(enum) {
    quota_id,
    not_available_for_subscription,
    unrecognized: []const u8,

    const wire_names = .{
        .quota_id = "QuotaId",
        .not_available_for_subscription = "NotAvailableForSubscription",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Virtual Machine provisioning state
pub const VirtualMachineProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Virtual Machine Restrict Movement state
pub const VirtualMachineRestrictMovementState = union(enum) {
    enabled,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "Enabled",
        .disabled = "Disabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// base Workload Network provisioning state
pub const WorkloadNetworkProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Type of DHCP: SERVER or RELAY.
pub const DhcpTypeEnum = union(enum) {
    server,
    relay,
    unrecognized: []const u8,

    const wire_names = .{
        .server = "SERVER",
        .relay = "RELAY",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network DHCP provisioning state
pub const WorkloadNetworkDhcpProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// DNS service log level
pub const DnsServiceLogLevelEnum = union(enum) {
    debug,
    info,
    warning,
    @"error",
    fatal,
    unrecognized: []const u8,

    const wire_names = .{
        .debug = "DEBUG",
        .info = "INFO",
        .warning = "WARNING",
        .@"error" = "ERROR",
        .fatal = "FATAL",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// DNS service status
pub const DnsServiceStatusEnum = union(enum) {
    success,
    failure,
    unrecognized: []const u8,

    const wire_names = .{
        .success = "SUCCESS",
        .failure = "FAILURE",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network DNS Service provisioning state
pub const WorkloadNetworkDnsServiceProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network DNS Zone provisioning state
pub const WorkloadNetworkDnsZoneProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Port Mirroring Direction
pub const PortMirroringDirectionEnum = union(enum) {
    ingress,
    egress,
    bidirectional,
    unrecognized: []const u8,

    const wire_names = .{
        .ingress = "INGRESS",
        .egress = "EGRESS",
        .bidirectional = "BIDIRECTIONAL",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Port Mirroring status
pub const PortMirroringStatusEnum = union(enum) {
    success,
    failure,
    unrecognized: []const u8,

    const wire_names = .{
        .success = "SUCCESS",
        .failure = "FAILURE",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network Port Mirroring provisioning state
pub const WorkloadNetworkPortMirroringProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network Public IP provisioning state
pub const WorkloadNetworkPublicIPProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Segment status
pub const SegmentStatusEnum = union(enum) {
    success,
    failure,
    unrecognized: []const u8,

    const wire_names = .{
        .success = "SUCCESS",
        .failure = "FAILURE",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network Segment provisioning state
pub const WorkloadNetworkSegmentProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// VM type
pub const VMTypeEnum = union(enum) {
    regular,
    edge,
    service,
    unrecognized: []const u8,

    const wire_names = .{
        .regular = "REGULAR",
        .edge = "EDGE",
        .service = "SERVICE",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// VM group status
pub const VMGroupStatusEnum = union(enum) {
    success,
    failure,
    unrecognized: []const u8,

    const wire_names = .{
        .success = "SUCCESS",
        .failure = "FAILURE",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Workload Network VM Group provisioning state
pub const WorkloadNetworkVMGroupProvisioningState = union(enum) {
    succeeded,
    failed,
    canceled,
    building,
    deleting,
    updating,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "Succeeded",
        .failed = "Failed",
        .canceled = "Canceled",
        .building = "Building",
        .deleting = "Deleting",
        .updating = "Updating",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// Azure VMware Solution API versions.
pub const Versions = enum {
    v2023_09_01,
    v2024_09_01,
    v2025_09_01,
};
