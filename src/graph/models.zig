//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Subject descriptor of a Graph entity
pub const GraphDescriptorResult = struct {
    links: ?ReferenceLinks = null,
    value: ?[]const u8 = null,

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

/// A collection of `GraphGroup` as returned by Azure DevOps.
pub const GraphGroupList = struct {
    count: ?i32 = null,
    value: ?[]const GraphGroup = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Graph group entity
pub const GraphGroup = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// A short phrase to help human readers disambiguate groups with similar names
    description: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Do not attempt to use this type to create a new group. This type does not contain sufficient fields to create a new group.
pub const GraphGroupCreationContext = struct {
    /// Optional: If provided, we will use this identifier for the storage key of the created group
    storage_key: ?[]const u8 = null,

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

/// A collection of `GraphMembership` as returned by Azure DevOps.
pub const GraphMembershipList = struct {
    count: ?i32 = null,
    value: ?[]const GraphMembership = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Relationship between a container and a member
pub const GraphMembership = struct {
    links: ?ReferenceLinks = null,
    container_descriptor: ?[]const u8 = null,
    member_descriptor: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Status of a Graph membership (active/inactive)
pub const GraphMembershipState = struct {
    links: ?ReferenceLinks = null,
    /// When true, the membership is active
    active: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents an abstract JSON token.
pub const JToken = struct {
    first: ?*const JToken = null,
    /// Gets a value indicating whether this token has child tokens.
    has_values: ?bool = null,
    item: ?*const JToken = null,
    last: ?*const JToken = null,
    next: ?*const JToken = null,
    /// Gets or sets the parent.
    parent: ?[]const u8 = null,
    /// Gets the path of the JSON token.
    path: ?[]const u8 = null,
    previous: ?*const JToken = null,
    root: ?*const JToken = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `GraphServicePrincipal` as returned by Azure DevOps.
pub const GraphServicePrincipalList = struct {
    count: ?i32 = null,
    value: ?[]const GraphServicePrincipal = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GraphServicePrincipal = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// The short, generally unique name for the user in the backing directory. For AAD users, this corresponds to the mail nickname, which is often but not necessarily similar to the part of the user's mail address before the @ sign. For GitHub users, this corresponds to the GitHub user handle.
    directory_alias: ?[]const u8 = null,
    /// When true, the group has been deleted in the identity provider
    is_deleted_in_origin: ?bool = null,
    /// The meta type of the user in the origin, such as 'member', 'guest', etc. See UserMetaType for the set of possible values.
    meta_type: ?[]const u8 = null,
    application_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Do not attempt to use this type to create a new service principal. Use one of the subclasses instead. This type does not contain sufficient fields to create a new service principal.
pub const GraphServicePrincipalCreationContext = struct {
    /// Optional: If provided, we will use this identifier for the storage key of the created service principal
    storage_key: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Storage key of a Graph entity
pub const GraphStorageKeyResult = struct {
    links: ?ReferenceLinks = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Batching of subjects to lookup using the Graph API
pub const GraphSubjectLookup = struct {
    lookup_keys: ?[]const GraphSubjectLookupKey = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GraphSubjectLookupKey = struct {
    descriptor: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Top-level graph entity
pub const GraphSubject = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Subject to search using the Graph API
pub const GraphSubjectQuery = struct {
    /// Search term to search for Azure Devops users or/and groups
    query: ?[]const u8 = null,
    /// Optional parameter. Specify a non-default scope (collection, project) to search for users or groups within the scope.
    scope_descriptor: ?[]const u8 = null,
    /// 'User' or 'Group' can be specified, both or either
    subject_kind: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `GraphSubject` as returned by Azure DevOps.
pub const GraphSubjectList = struct {
    count: ?i32 = null,
    value: ?[]const GraphSubject = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Avatar = struct {
    is_auto_generated: ?bool = null,
    size: ?enums.AvatarSize = null,
    time_stamp: ?[]const u8 = null,
    value: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `GraphUser` as returned by Azure DevOps.
pub const GraphUserList = struct {
    count: ?i32 = null,
    value: ?[]const GraphUser = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GraphUser = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// The short, generally unique name for the user in the backing directory. For AAD users, this corresponds to the mail nickname, which is often but not necessarily similar to the part of the user's mail address before the @ sign. For GitHub users, this corresponds to the GitHub user handle.
    directory_alias: ?[]const u8 = null,
    /// When true, the group has been deleted in the identity provider
    is_deleted_in_origin: ?bool = null,
    /// The meta type of the user in the origin, such as 'member', 'guest', etc. See UserMetaType for the set of possible values.
    meta_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Do not attempt to use this type to create a new user. Use one of the subclasses instead. This type does not contain sufficient fields to create a new user.
pub const GraphUserCreationContext = struct {
    /// Optional: If provided, we will use this identifier for the storage key of the created user
    storage_key: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Do not attempt to use this type to update user. Use one of the subclasses instead. This type does not contain sufficient fields to create a new user.
pub const GraphUserUpdateContext = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Who is the provider for this user and what is the identifier and domain that is used to uniquely identify the user.
pub const GraphProviderInfo = struct {
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AAD the tenantID of the directory.)
    domain: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex: 'aad', 'msa')
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. (For MSA this is the PUID in hex notation, for AAD this is the object id.)
    origin_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
