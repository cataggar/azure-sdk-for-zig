//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Contains information about the progress or result of an async operation.
pub const Operation = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.OperationStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Detailed messaged about the status of an operation.
    detailed_message: ?[]const u8 = null,
    /// Result message for an operation.
    result_message: ?[]const u8 = null,
    result_url: ?OperationResultReference = null,

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

pub const OperationResultReference = struct {
    /// URL to the operation result.
    result_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
