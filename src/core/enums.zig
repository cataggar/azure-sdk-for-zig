//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ProcessType = enum {
    system,
    custom,
    inherited,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .custom => "custom",
            .inherited => "inherited",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const ListRequestStateFilter = enum {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .deleting => "deleting",
            .new => "new",
            .well_formed => "wellFormed",
            .create_pending => "createPending",
            .all => "all",
            .unchanged => "unchanged",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "wellFormed")) return .well_formed;
        if (std.mem.eql(u8, s, "createPending")) return .create_pending;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "unchanged")) return .unchanged;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
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

pub const TeamProjectReferenceState = enum {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .deleting => "deleting",
            .new => "new",
            .well_formed => "wellFormed",
            .create_pending => "createPending",
            .all => "all",
            .unchanged => "unchanged",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "wellFormed")) return .well_formed;
        if (std.mem.eql(u8, s, "createPending")) return .create_pending;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "unchanged")) return .unchanged;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
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

pub const TeamProjectReferenceVisibility = enum {
    private,
    public,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .private => "private",
            .public => "public",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "public")) return .public;
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
