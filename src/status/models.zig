//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const ServiceStatus = struct {
    last_updated: ?[]const u8 = null,
    status: ?StatusSummary = null,
    services: ?[]const ServiceHealth = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const StatusSummary = struct {
    health: ?enums.StatusSummaryHealth = null,
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServiceHealth = struct {
    geographies: ?[]const GeographyWithHealth = null,
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GeographyWithHealth = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    health: ?enums.GeographyWithHealthHealth = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
