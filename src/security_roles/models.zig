//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const RoleAssignment = struct {
    /// Designates the role as explicitly assigned or inherited.
    access: ?enums.RoleAssignmentAccess = null,
    /// User friendly description of access assignment.
    access_display_name: ?[]const u8 = null,
    identity: ?IdentityRef = null,
    role: ?SecurityRole = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IdentityRef = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph user referenced in the 'self' entry of the IdentityRef '_links' dictionary
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Deprecated - Available in the 'avatar' entry of the IdentityRef '_links' dictionary
    image_url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph membership state referenced in the 'membershipState' entry of the GraphUser '_links' dictionary
    inactive: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsAadUserType/Descriptor.IsAadGroupType)
    is_aad_identity: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsGroupType)
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    /// Deprecated - not in use in most preexisting implementations of ToIdentityRef
    profile_url: ?[]const u8 = null,
    /// Deprecated - use Domain+PrincipalName instead
    unique_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
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

pub const SecurityRole = struct {
    /// Permissions the role is allowed.
    allow_permissions: ?i32 = null,
    /// Permissions the role is denied.
    deny_permissions: ?i32 = null,
    /// Description of user access defined by the role
    description: ?[]const u8 = null,
    /// User friendly name of the role.
    display_name: ?[]const u8 = null,
    /// Globally unique identifier for the role.
    identifier: ?[]const u8 = null,
    /// Unique name of the role in the scope.
    name: ?[]const u8 = null,
    /// Returns the id of the ParentScope.
    scope: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UserRoleAssignmentRef = struct {
    /// The name of the role assigned.
    role_name: ?[]const u8 = null,
    /// Identifier of the user given the role assignment.
    unique_name: ?[]const u8 = null,
    /// Unique id of the user given the role assignment.
    user_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
