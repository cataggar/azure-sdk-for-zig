//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const StatusSummaryHealth = enum {
    unknown,
    unhealthy,
    degraded,
    advisory,
    healthy,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .unhealthy => "unhealthy",
            .degraded => "degraded",
            .advisory => "advisory",
            .healthy => "healthy",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "unhealthy")) return .unhealthy;
        if (std.mem.eql(u8, s, "degraded")) return .degraded;
        if (std.mem.eql(u8, s, "advisory")) return .advisory;
        if (std.mem.eql(u8, s, "healthy")) return .healthy;
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

pub const GeographyWithHealthHealth = enum {
    unknown,
    unhealthy,
    degraded,
    advisory,
    healthy,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .unhealthy => "unhealthy",
            .degraded => "degraded",
            .advisory => "advisory",
            .healthy => "healthy",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "unhealthy")) return .unhealthy;
        if (std.mem.eql(u8, s, "degraded")) return .degraded;
        if (std.mem.eql(u8, s, "advisory")) return .advisory;
        if (std.mem.eql(u8, s, "healthy")) return .healthy;
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
