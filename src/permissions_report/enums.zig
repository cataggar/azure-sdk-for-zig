//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const PermissionsReportReportStatus = enum {
    created,
    in_progress,
    completed_with_errors,
    completed_successfully,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .created => "created",
            .in_progress => "inProgress",
            .completed_with_errors => "completedWithErrors",
            .completed_successfully => "completedSuccessfully",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "created")) return .created;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completedWithErrors")) return .completed_with_errors;
        if (std.mem.eql(u8, s, "completedSuccessfully")) return .completed_successfully;
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

pub const PermissionsReportResourceResourceType = enum {
    repo,
    ref,
    project_git,
    release,
    tfvc,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .repo => "repo",
            .ref => "ref",
            .project_git => "projectGit",
            .release => "release",
            .tfvc => "tfvc",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "repo")) return .repo;
        if (std.mem.eql(u8, s, "ref")) return .ref;
        if (std.mem.eql(u8, s, "projectGit")) return .project_git;
        if (std.mem.eql(u8, s, "release")) return .release;
        if (std.mem.eql(u8, s, "tfvc")) return .tfvc;
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
