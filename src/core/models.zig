//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const Process = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    description: ?[]const u8 = null,
    id: ?[]const u8 = null,
    is_default: ?bool = null,
    type: ?enums.ProcessType = null,

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

/// Represents a shallow reference to a TeamProject.
pub const TeamProjectReference = struct {
    /// Project abbreviation.
    abbreviation: ?[]const u8 = null,
    /// Url to default team identity image.
    default_team_image_url: ?[]const u8 = null,
    /// The project's description (if any).
    description: ?[]const u8 = null,
    /// Project identifier.
    id: ?[]const u8 = null,
    /// Project last update time.
    last_update_time: ?[]const u8 = null,
    /// Project name.
    name: ?[]const u8 = null,
    /// Project revision.
    revision: ?i64 = null,
    /// Project state.
    state: ?enums.TeamProjectReferenceState = null,
    /// Url to the full version of the object.
    url: ?[]const u8 = null,
    /// Project visibility.
    visibility: ?enums.TeamProjectReferenceVisibility = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a Team Project object.
pub const TeamProject = struct {
    /// Project abbreviation.
    abbreviation: ?[]const u8 = null,
    /// Url to default team identity image.
    default_team_image_url: ?[]const u8 = null,
    /// The project's description (if any).
    description: ?[]const u8 = null,
    /// Project identifier.
    id: ?[]const u8 = null,
    /// Project last update time.
    last_update_time: ?[]const u8 = null,
    /// Project name.
    name: ?[]const u8 = null,
    /// Project revision.
    revision: ?i64 = null,
    /// Project state.
    state: ?enums.TeamProjectReferenceState = null,
    /// Url to the full version of the object.
    url: ?[]const u8 = null,
    /// Project visibility.
    visibility: ?enums.TeamProjectReferenceVisibility = null,
    links: ?ReferenceLinks = null,
    /// Set of capabilities this project has (such as process template & version control).
    capabilities: ?std.json.ArrayHashMap(std.json.ArrayHashMap([]const u8)) = null,
    default_team: ?WebApiTeamRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const WebApiTeamRef = struct {
    /// Team (Identity) Guid. A Team Foundation ID.
    id: ?[]const u8 = null,
    /// Team name
    name: ?[]const u8 = null,
    /// Team REST API Url
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference for an async operation.
pub const OperationReference = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.OperationReferenceStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A named value associated with a project.
pub const ProjectProperty = struct {
    /// The name of the property.
    name: ?[]const u8 = null,
    /// The value of the property.
    value: ?ProjectPropertyValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProjectPropertyValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains the image data for project avatar.
pub const ProjectAvatar = struct {
    /// The avatar image represented as a byte array.
    image: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CategorizedWebApiTeams = struct {
    /// Teams that the user is a member of.
    my_teams: ?[]const WebApiTeam = null,
    /// Teams that the user can read but is not member of.
    other_readable_teams: ?[]const WebApiTeam = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WebApiTeam = struct {
    /// Team (Identity) Guid. A Team Foundation ID.
    id: ?[]const u8 = null,
    /// Team name
    name: ?[]const u8 = null,
    /// Team REST API Url
    url: ?[]const u8 = null,
    /// Team description
    description: ?[]const u8 = null,
    identity: ?Identity = null,
    /// Identity REST API Url to this team
    identity_url: ?[]const u8 = null,
    project_id: ?[]const u8 = null,
    project_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Identity = struct {
    /// The custom display name for the identity (if any). Setting this property to an empty string will clear the existing custom display name. Setting this property to null will not affect the existing persisted value (since null values do not get sent over the wire or to the database)
    custom_display_name: ?[]const u8 = null,
    descriptor: ?IdentityDescriptor = null,
    /// Identity Identifier. Also called Storage Key, or VSID
    id: ?[]const u8 = null,
    /// True if the identity has a membership in any Azure Devops group in the organization.
    is_active: ?bool = null,
    /// True if the identity is a group.
    is_container: ?bool = null,
    master_id: ?[]const u8 = null,
    /// Id of the members of the identity (groups only).
    member_ids: ?[]const []const u8 = null,
    member_of: ?[]const IdentityDescriptor = null,
    members: ?[]const IdentityDescriptor = null,
    meta_type_id: ?i32 = null,
    properties: ?PropertiesCollection = null,
    /// The display name for the identity as specified by the source identity provider.
    provider_display_name: ?[]const u8 = null,
    resource_version: ?i32 = null,
    social_descriptor: ?[]const u8 = null,
    /// Subject descriptor of a Graph entity.
    subject_descriptor: ?[]const u8 = null,
    unique_user_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An Identity descriptor is a wrapper for the identity type (Windows SID, Passport) along with a unique identifier such as the SID or PUID.
pub const IdentityDescriptor = struct {
    /// The unique identifier for this identity, not exceeding 256 chars, which will be persisted.
    identifier: ?[]const u8 = null,
    /// Type of descriptor (for example, Windows, Passport, etc.).
    identity_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class represents a property bag as a collection of key-value pairs. Values of all primitive types (any type with a `TypeCode != TypeCode.Object`) except for `DBNull` are accepted. Values of type Byte[], Int32, Double, DateType and String preserve their type, other primitives are retuned as a String. Byte[] expected as base64 encoded string.
pub const PropertiesCollection = struct {
    /// The count of properties in the collection.
    count: ?i32 = null,
    item: ?PropertiesCollectionItem = null,
    /// The set of keys in the collection.
    keys: ?[]const []const u8 = null,
    /// The set of values in the collection.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PropertiesCollectionItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TeamMember = struct {
    identity: ?IdentityRef = null,
    is_team_admin: ?bool = null,

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
