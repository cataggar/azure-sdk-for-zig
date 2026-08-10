//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `Favorite` as returned by Azure DevOps.
pub const FavoriteList = struct {
    count: ?i32 = null,
    value: ?[]const Favorite = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Implementation of Favorite contract following modern storage
pub const Favorite = struct {
    links: ?ReferenceLinks = null,
    /// ID of the favorited artifact, unique in context of this artifact type.
    artifact_id: ?[]const u8 = null,
    /// Indicates if the artifact described by this favorite could not be located.
    artifact_is_deleted: ?bool = null,
    /// Last known name of the artifact.
    artifact_name: ?[]const u8 = null,
    artifact_properties: ?ArtifactProperties = null,
    artifact_scope: ?ArtifactScope = null,
    /// Type of artifact.
    artifact_type: ?[]const u8 = null,
    /// Date and time this Favorite was created on server.
    creation_date: ?[]const u8 = null,
    /// Unique Id of the favorite item, defined by server at creation time.
    id: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    /// Fully-Qualified link to this Resource
    url: ?[]const u8 = null,

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

pub const ArtifactProperties = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the scope a favorited Artifact resides in. e.g. A team project.
pub const ArtifactScope = struct {
    /// The identifier of the scope the artifact resides in. For a TFS Project, this refers to the Project GUID string. For a Collection, marked this property with an empty string.
    id: ?[]const u8 = null,
    /// Name of the artifact scope (e.g. Project Name) Note: This property is a read-only extension over the stored favorite model. This value cannot be overridden on writes.
    name: ?[]const u8 = null,
    /// Type of scope the favorite artifact resides in. Known scopes include 'Project' or 'Collection'
    type: ?[]const u8 = null,

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

pub const FavoriteCreateParameters = struct {
    artifact_id: ?[]const u8 = null,
    artifact_name: ?[]const u8 = null,
    artifact_properties: ?ArtifactProperties = null,
    artifact_scope: ?ArtifactScope = null,
    artifact_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
