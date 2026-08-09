//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const RegistrationClientType = enum {
    confidential,
    public,
    medium_trust,
    high_trust,
    full_trust,
    application,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .confidential => "confidential",
            .public => "public",
            .medium_trust => "mediumTrust",
            .high_trust => "highTrust",
            .full_trust => "fullTrust",
            .application => "application",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "confidential")) return .confidential;
        if (std.mem.eql(u8, s, "public")) return .public;
        if (std.mem.eql(u8, s, "mediumTrust")) return .medium_trust;
        if (std.mem.eql(u8, s, "highTrust")) return .high_trust;
        if (std.mem.eql(u8, s, "fullTrust")) return .full_trust;
        if (std.mem.eql(u8, s, "application")) return .application;
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
