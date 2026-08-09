//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const UpstreamingBehaviorVersionsFromExternalUpstreams = enum {
    auto,
    allow_external_versions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .auto => "auto",
            .allow_external_versions => "allowExternalVersions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "auto")) return .auto;
        if (std.mem.eql(u8, s, "allowExternalVersions")) return .allow_external_versions;
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

pub const UpstreamSourceInfoSourceType = enum {
    public,
    internal,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .public => "public",
            .internal => "internal",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "public")) return .public;
        if (std.mem.eql(u8, s, "internal")) return .internal;
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

pub const JsonPatchOperationOp = enum {
    add,
    remove,
    replace,
    move,
    copy,
    @"test",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .add => "add",
            .remove => "remove",
            .replace => "replace",
            .move => "move",
            .copy => "copy",
            .@"test" => "test",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "remove")) return .remove;
        if (std.mem.eql(u8, s, "replace")) return .replace;
        if (std.mem.eql(u8, s, "move")) return .move;
        if (std.mem.eql(u8, s, "copy")) return .copy;
        if (std.mem.eql(u8, s, "test")) return .@"test";
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

pub const CargoPackagesBatchRequestOperation = enum {
    promote,
    delete,
    permanent_delete,
    restore_to_feed,
    yank,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
            .yank => "yank",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
        if (std.mem.eql(u8, s, "yank")) return .yank;
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

pub const MavenPackagesBatchRequestOperation = enum {
    promote,
    delete,
    permanent_delete,
    restore_to_feed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
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

pub const NpmPackagesBatchRequestOperation = enum {
    promote,
    deprecate,
    unpublish,
    permanent_delete,
    restore_to_feed,
    delete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .deprecate => "deprecate",
            .unpublish => "unpublish",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
            .delete => "delete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "deprecate")) return .deprecate;
        if (std.mem.eql(u8, s, "unpublish")) return .unpublish;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
        if (std.mem.eql(u8, s, "delete")) return .delete;
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

pub const NuGetPackagesBatchRequestOperation = enum {
    promote,
    list,
    delete,
    permanent_delete,
    restore_to_feed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .list => "list",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "list")) return .list;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
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

pub const PyPiPackagesBatchRequestOperation = enum {
    promote,
    delete,
    permanent_delete,
    restore_to_feed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
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

pub const UPackPackagesBatchRequestOperation = enum {
    promote,
    delete,
    permanent_delete,
    restore_to_feed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .promote => "promote",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
            .restore_to_feed => "restoreToFeed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "promote")) return .promote;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
        if (std.mem.eql(u8, s, "restoreToFeed")) return .restore_to_feed;
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
