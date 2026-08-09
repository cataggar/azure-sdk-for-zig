//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const AuditActionInfoCategory = enum {
    unknown,
    modify,
    remove,
    create,
    access,
    execute,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .modify => "modify",
            .remove => "remove",
            .create => "create",
            .access => "access",
            .execute => "execute",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "modify")) return .modify;
        if (std.mem.eql(u8, s, "remove")) return .remove;
        if (std.mem.eql(u8, s, "create")) return .create;
        if (std.mem.eql(u8, s, "access")) return .access;
        if (std.mem.eql(u8, s, "execute")) return .execute;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const DecoratedAuditLogEntryCategory = enum {
    unknown,
    modify,
    remove,
    create,
    access,
    execute,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .modify => "modify",
            .remove => "remove",
            .create => "create",
            .access => "access",
            .execute => "execute",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "modify")) return .modify;
        if (std.mem.eql(u8, s, "remove")) return .remove;
        if (std.mem.eql(u8, s, "create")) return .create;
        if (std.mem.eql(u8, s, "access")) return .access;
        if (std.mem.eql(u8, s, "execute")) return .execute;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const DecoratedAuditLogEntryScopeType = enum {
    unknown,
    deployment,
    enterprise,
    organization,
    project,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .deployment => "deployment",
            .enterprise => "enterprise",
            .organization => "organization",
            .project => "project",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "deployment")) return .deployment;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
        if (std.mem.eql(u8, s, "organization")) return .organization;
        if (std.mem.eql(u8, s, "project")) return .project;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const AuditStreamStatus = enum {
    unknown,
    enabled,
    disabled_by_user,
    disabled_by_system,
    deleted,
    backfilling,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .enabled => "enabled",
            .disabled_by_user => "disabledByUser",
            .disabled_by_system => "disabledBySystem",
            .deleted => "deleted",
            .backfilling => "backfilling",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "disabledByUser")) return .disabled_by_user;
        if (std.mem.eql(u8, s, "disabledBySystem")) return .disabled_by_system;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "backfilling")) return .backfilling;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const UpdateStatusRequestStatus = enum {
    unknown,
    enabled,
    disabled_by_user,
    disabled_by_system,
    deleted,
    backfilling,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .enabled => "enabled",
            .disabled_by_user => "disabledByUser",
            .disabled_by_system => "disabledBySystem",
            .deleted => "deleted",
            .backfilling => "backfilling",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "disabledByUser")) return .disabled_by_user;
        if (std.mem.eql(u8, s, "disabledBySystem")) return .disabled_by_system;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "backfilling")) return .backfilling;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ServiceApiVersions = enum {
    v7_2_preview,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .v7_2_preview => "7.2-preview",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "7.2-preview")) return .v7_2_preview;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};
