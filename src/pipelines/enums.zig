//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const PipelineConfigurationType = union(enum) {
    unknown,
    yaml,
    designer_json,
    just_in_time,
    designer_hyphen_json,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .yaml = "yaml",
        .designer_json = "designerJson",
        .just_in_time = "justInTime",
        .designer_hyphen_json = "designerHyphenJson",
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

pub const CreatePipelineConfigurationParametersType = union(enum) {
    unknown,
    yaml,
    designer_json,
    just_in_time,
    designer_hyphen_json,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .yaml = "yaml",
        .designer_json = "designerJson",
        .just_in_time = "justInTime",
        .designer_hyphen_json = "designerHyphenJson",
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

pub const RepositoryType = union(enum) {
    unknown,
    git_hub,
    azure_repos_git,
    git_hub_enterprise,
    bit_bucket,
    azure_repos_git_hyphenated,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .git_hub = "gitHub",
        .azure_repos_git = "azureReposGit",
        .git_hub_enterprise = "gitHubEnterprise",
        .bit_bucket = "bitBucket",
        .azure_repos_git_hyphenated = "azureReposGitHyphenated",
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

pub const RunResult = union(enum) {
    unknown,
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .succeeded = "succeeded",
        .failed = "failed",
        .canceled = "canceled",
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

pub const RunState = union(enum) {
    unknown,
    in_progress,
    canceling,
    completed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .in_progress = "inProgress",
        .canceling = "canceling",
        .completed = "completed",
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

pub const GetRequestExpand = enum {
    none,
    signed_content,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .signed_content => "signedContent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "signedContent")) return .signed_content;
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

pub const ListRequestExpand = enum {
    none,
    signed_content,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .signed_content => "signedContent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "signedContent")) return .signed_content;
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

pub const GetRequestExpand1 = enum {
    none,
    signed_content,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .signed_content => "signedContent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "signedContent")) return .signed_content;
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
