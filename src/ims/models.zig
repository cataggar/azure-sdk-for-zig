//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

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
