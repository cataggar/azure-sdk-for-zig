//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const GlobalPermissionRole = enum {
    custom,
    none,
    feed_creator,
    administrator,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .custom => "custom",
            .none => "none",
            .feed_creator => "feedCreator",
            .administrator => "administrator",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "feedCreator")) return .feed_creator;
        if (std.mem.eql(u8, s, "administrator")) return .administrator;
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

pub const FeedChangeChangeType = enum {
    add_or_update,
    delete,
    permanent_delete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .add_or_update => "addOrUpdate",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "addOrUpdate")) return .add_or_update;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
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

pub const FeedCapabilities = enum {
    none,
    upstream_v2,
    under_maintenance,
    default_capabilities,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .upstream_v2 => "upstreamV2",
            .under_maintenance => "underMaintenance",
            .default_capabilities => "defaultCapabilities",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "upstreamV2")) return .upstream_v2;
        if (std.mem.eql(u8, s, "underMaintenance")) return .under_maintenance;
        if (std.mem.eql(u8, s, "defaultCapabilities")) return .default_capabilities;
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

pub const UpstreamSourceStatus = enum {
    ok,
    disabled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .ok => "ok",
            .disabled => "disabled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "ok")) return .ok;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
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

pub const UpstreamSourceUpstreamSourceType = enum {
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

pub const FeedViewType = enum {
    none,
    release,
    implicit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .release => "release",
            .implicit => "implicit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "release")) return .release;
        if (std.mem.eql(u8, s, "implicit")) return .implicit;
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

pub const FeedViewVisibility = enum {
    private,
    collection,
    organization,
    aad_tenant,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .private => "private",
            .collection => "collection",
            .organization => "organization",
            .aad_tenant => "aadTenant",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "collection")) return .collection;
        if (std.mem.eql(u8, s, "organization")) return .organization;
        if (std.mem.eql(u8, s, "aadTenant")) return .aad_tenant;
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

pub const FeedPermissionRole = enum {
    custom,
    none,
    reader,
    contributor,
    administrator,
    collaborator,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .custom => "custom",
            .none => "none",
            .reader => "reader",
            .contributor => "contributor",
            .administrator => "administrator",
            .collaborator => "collaborator",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "reader")) return .reader;
        if (std.mem.eql(u8, s, "contributor")) return .contributor;
        if (std.mem.eql(u8, s, "administrator")) return .administrator;
        if (std.mem.eql(u8, s, "collaborator")) return .collaborator;
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

pub const PackageVersionChangeChangeType = enum {
    add_or_update,
    delete,
    permanent_delete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .add_or_update => "addOrUpdate",
            .delete => "delete",
            .permanent_delete => "permanentDelete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "addOrUpdate")) return .add_or_update;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "permanentDelete")) return .permanent_delete;
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

pub const GetFeedsRequestFeedRole = enum {
    custom,
    none,
    reader,
    contributor,
    administrator,
    collaborator,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .custom => "custom",
            .none => "none",
            .reader => "reader",
            .contributor => "contributor",
            .administrator => "administrator",
            .collaborator => "collaborator",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "reader")) return .reader;
        if (std.mem.eql(u8, s, "contributor")) return .contributor;
        if (std.mem.eql(u8, s, "administrator")) return .administrator;
        if (std.mem.eql(u8, s, "collaborator")) return .collaborator;
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

pub const OperationReferenceStatus = enum {
    not_set,
    queued,
    in_progress,
    cancelled,
    succeeded,
    failed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .queued => "queued",
            .in_progress => "inProgress",
            .cancelled => "cancelled",
            .succeeded => "succeeded",
            .failed => "failed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "cancelled")) return .cancelled;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
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
