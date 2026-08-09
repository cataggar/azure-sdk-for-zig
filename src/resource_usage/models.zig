//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Represents usage data that includes a count and a limit for a specific aspect.
pub const Usage = struct {
    /// Gets the current count or usage.
    count: ?i32 = null,
    /// Gets the maximum limit or capacity.
    limit: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
