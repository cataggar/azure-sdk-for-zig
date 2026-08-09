//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const GetWidgetTypesRequestScope = enum {
    collection_user,
    project_team,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .collection_user => "collection_User",
            .project_team => "project_Team",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "collection_User")) return .collection_user;
        if (std.mem.eql(u8, s, "project_Team")) return .project_team;
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

pub const WidgetMetadataSupportedScope = enum {
    collection_user,
    project_team,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .collection_user => "collection_User",
            .project_team => "project_Team",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "collection_User")) return .collection_user;
        if (std.mem.eql(u8, s, "project_Team")) return .project_team;
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

pub const DashboardDashboardScope = enum {
    collection_user,
    project_team,
    project,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .collection_user => "collection_User",
            .project_team => "project_Team",
            .project => "project",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "collection_User")) return .collection_user;
        if (std.mem.eql(u8, s, "project_Team")) return .project_team;
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

pub const DashboardGroupPermission = enum {
    none,
    edit,
    manage,
    manage_permissions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .edit => "edit",
            .manage => "manage",
            .manage_permissions => "managePermissions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "edit")) return .edit;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "managePermissions")) return .manage_permissions;
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

pub const DashboardGroupTeamDashboardPermission = enum {
    none,
    read,
    create,
    edit,
    delete,
    manage_permissions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .read => "read",
            .create => "create",
            .edit => "edit",
            .delete => "delete",
            .manage_permissions => "managePermissions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "read")) return .read;
        if (std.mem.eql(u8, s, "create")) return .create;
        if (std.mem.eql(u8, s, "edit")) return .edit;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "managePermissions")) return .manage_permissions;
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
