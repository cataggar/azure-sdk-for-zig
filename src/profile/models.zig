//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A user profile.
pub const Profile = struct {
    application_container: ?AttributesContainer = null,
    /// The core attributes of this profile.
    core_attributes: ?std.json.ArrayHashMap(CoreProfileAttribute) = null,
    /// The maximum revision number of any attribute.
    core_revision: ?i32 = null,
    /// The unique identifier of the profile.
    id: ?[]const u8 = null,
    /// The current state of the profile.
    profile_state: ?enums.ProfileProfileState = null,
    /// The maximum revision number of any attribute.
    revision: ?i32 = null,
    /// The time at which this profile was last changed.
    time_stamp: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Stores a set of named profile attributes.
pub const AttributesContainer = struct {
    /// The attributes stored by the container.
    attributes: ?std.json.ArrayHashMap(ProfileAttribute) = null,
    /// The name of the container.
    container_name: ?[]const u8 = null,
    /// The maximum revision number of any attribute within the container.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A named object associated with a profile.
pub const ProfileAttribute = struct {
    descriptor: ?AttributeDescriptor = null,
    /// The revision number of the attribute.
    revision: ?i32 = null,
    /// The time the attribute was last changed.
    time_stamp: ?[]const u8 = null,
    /// The value of the attribute.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Identifies an attribute with a name and a container.
pub const AttributeDescriptor = struct {
    /// The name of the attribute.
    attribute_name: ?[]const u8 = null,
    /// The container the attribute resides in.
    container_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A profile attribute which always has a value for each profile.
pub const CoreProfileAttribute = struct {
    descriptor: ?AttributeDescriptor = null,
    /// The revision number of the attribute.
    revision: ?i32 = null,
    /// The time the attribute was last changed.
    time_stamp: ?[]const u8 = null,
    /// The value of the attribute.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
