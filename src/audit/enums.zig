//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const AuditActionInfoCategory = union(enum) {
    unknown,
    modify,
    remove,
    create,
    access,
    execute,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .modify = "modify",
        .remove = "remove",
        .create = "create",
        .access = "access",
        .execute = "execute",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const DecoratedAuditLogEntryCategory = union(enum) {
    unknown,
    modify,
    remove,
    create,
    access,
    execute,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .modify = "modify",
        .remove = "remove",
        .create = "create",
        .access = "access",
        .execute = "execute",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const DecoratedAuditLogEntryScopeType = union(enum) {
    unknown,
    deployment,
    enterprise,
    organization,
    project,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .deployment = "deployment",
        .enterprise = "enterprise",
        .organization = "organization",
        .project = "project",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AuditStreamStatus = union(enum) {
    unknown,
    enabled,
    disabled_by_user,
    disabled_by_system,
    deleted,
    backfilling,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .enabled = "enabled",
        .disabled_by_user = "disabledByUser",
        .disabled_by_system = "disabledBySystem",
        .deleted = "deleted",
        .backfilling = "backfilling",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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
