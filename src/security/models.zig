//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Represents a JSON object.
pub const JObject = struct {
    item: ?[]const u8 = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class for encapsulating the allowed and denied permissions for a given IdentityDescriptor.
pub const AccessControlEntry = struct {
    /// The set of permission bits that represent the actions that the associated descriptor is allowed to perform.
    allow: ?i32 = null,
    /// The set of permission bits that represent the actions that the associated descriptor is not allowed to perform.
    deny: ?i32 = null,
    descriptor: ?IdentityDescriptor = null,
    extended_info: ?AceExtendedInformation = null,

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

/// Holds the inherited and effective permission information for a given AccessControlEntry.
pub const AceExtendedInformation = struct {
    /// This is the combination of all of the explicit and inherited permissions for this identity on this token. These are the permissions used when determining if a given user has permission to perform an action.
    effective_allow: ?i32 = null,
    /// This is the combination of all of the explicit and inherited permissions for this identity on this token. These are the permissions used when determining if a given user has permission to perform an action.
    effective_deny: ?i32 = null,
    /// These are the permissions that are inherited for this identity on this token. If the token does not inherit permissions this will be 0. Note that any permissions that have been explicitly set on this token for this identity, or any groups that this identity is a part of, are not included here.
    inherited_allow: ?i32 = null,
    /// These are the permissions that are inherited for this identity on this token. If the token does not inherit permissions this will be 0. Note that any permissions that have been explicitly set on this token for this identity, or any groups that this identity is a part of, are not included here.
    inherited_deny: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The AccessControlList class is meant to associate a set of AccessControlEntries with a security token and its inheritance settings.
pub const AccessControlList = struct {
    /// Storage of permissions keyed on the identity the permission is for.
    aces_dictionary: ?std.json.ArrayHashMap(AccessControlEntry) = null,
    /// True if this ACL holds ACEs that have extended information.
    include_extended_info: ?bool = null,
    /// True if the given token inherits permissions from parents.
    inherit_permissions: ?bool = null,
    /// The token that this AccessControlList is for.
    token: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This class is used to serialize collections as a single JSON object on the wire.
pub const VssJsonCollectionWrapper = struct {
    /// The number of serialized items.
    count: ?i32 = null,
    /// The serialized item.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a set of evaluated permissions.
pub const PermissionEvaluationBatch = struct {
    /// True if members of the Administrators group should always pass the security check.
    always_allow_administrators: ?bool = null,
    /// Array of permission evaluations to evaluate.
    evaluations: ?[]const PermissionEvaluation = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an evaluated permission.
pub const PermissionEvaluation = struct {
    /// Permission bit for this evaluated permission.
    permissions: ?i32 = null,
    /// Security namespace identifier for this evaluated permission.
    security_namespace_id: ?[]const u8 = null,
    /// Security namespace-specific token for this evaluated permission.
    token: ?[]const u8 = null,
    /// Permission evaluation value.
    value: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class for describing the details of a TeamFoundationSecurityNamespace.
pub const SecurityNamespaceDescription = struct {
    /// The list of actions that this Security Namespace is responsible for securing.
    actions: ?[]const ActionDefinition = null,
    /// This is the dataspace category that describes where the security information for this SecurityNamespace should be stored.
    dataspace_category: ?[]const u8 = null,
    /// This localized name for this namespace.
    display_name: ?[]const u8 = null,
    /// If the security tokens this namespace will be operating on need to be split on certain character lengths to determine its elements, that length should be specified here. If not, this value will be -1.
    element_length: ?i32 = null,
    /// This is the type of the extension that should be loaded from the plugins directory for extending this security namespace.
    extension_type: ?[]const u8 = null,
    /// If true, the security namespace is remotable, allowing another service to proxy the namespace.
    is_remotable: ?bool = null,
    /// This non-localized for this namespace.
    name: ?[]const u8 = null,
    /// The unique identifier for this namespace.
    namespace_id: ?[]const u8 = null,
    /// The permission bits needed by a user in order to read security data on the Security Namespace.
    read_permission: ?i32 = null,
    /// If the security tokens this namespace will be operating on need to be split on certain characters to determine its elements that character should be specified here. If not, this value will be the null character.
    separator_value: ?[]const u8 = null,
    /// Used to send information about the structure of the security namespace over the web service.
    structure_value: ?i32 = null,
    /// The bits reserved by system store
    system_bit_mask: ?i32 = null,
    /// If true, the security service will expect an ISecurityDataspaceTokenTranslator plugin to exist for this namespace
    use_token_translator: ?bool = null,
    /// The permission bits needed by a user in order to modify security data on the Security Namespace.
    write_permission: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ActionDefinition = struct {
    /// The bit mask integer for this action. Must be a power of 2.
    bit: ?i32 = null,
    /// The localized display name for this action.
    display_name: ?[]const u8 = null,
    /// The non-localized name for this action.
    name: ?[]const u8 = null,
    /// The namespace that this action belongs to. This will only be used for reading from the database.
    namespace_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
