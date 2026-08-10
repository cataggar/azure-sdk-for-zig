//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `PermissionsReport` as returned by Azure DevOps.
pub const PermissionsReportList = struct {
    count: ?i32 = null,
    value: ?[]const PermissionsReport = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Detailed report of permissions for a set of groups and users over a set of security namespaces
pub const PermissionsReport = struct {
    /// Error if the report creation failed or empty if successful
    @"error": ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Name of the report which typically includes the requestor's display name
    report_name: ?[]const u8 = null,
    report_status: ?enums.PermissionsReportReportStatus = null,
    report_status_last_updated_time: ?[]const u8 = null,
    requested_time: ?[]const u8 = null,
    /// User who requested the report be created
    requestor: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Details for creating a permissions report
pub const PermissionsReportRequest = struct {
    /// List of groups and users to fetch permissions on. An empty list will fetch all groups and users in the organization
    descriptors: ?[]const []const u8 = null,
    /// Name of the report to create, make it unique
    report_name: ?[]const u8 = null,
    /// List of resources to fetch permisions on
    resources: ?[]const PermissionsReportResource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specifics of the resource for the permissions report
pub const PermissionsReportResource = struct {
    /// GUID, Name, or ref for the specified resource type
    resource_id: ?[]const u8 = null,
    /// For repo resource type, resource name is the repo name
    resource_name: ?[]const u8 = null,
    /// Specify the type of resource to report permissions on
    resource_type: ?enums.PermissionsReportResourceResourceType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class to represent a collection of REST reference links.
pub const ReferenceLinks = struct {
    /// The readonly view of the links. Because Reference links are readonly, we only want to expose them as read only.
    links: ?std.json.ArrayHashMap(ReferenceLinksLink) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReferenceLinksLink = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};
