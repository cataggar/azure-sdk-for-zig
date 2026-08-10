//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const WikiV2Type = union(enum) {
    project_wiki,
    code_wiki,
    unrecognized: []const u8,

    const wire_names = .{
        .project_wiki = "projectWiki",
        .code_wiki = "codeWiki",
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

pub const GitVersionDescriptorVersionOptions = union(enum) {
    none,
    previous_change,
    first_parent,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .previous_change = "previousChange",
        .first_parent = "firstParent",
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

pub const GitVersionDescriptorVersionType = union(enum) {
    branch,
    tag,
    commit,
    unrecognized: []const u8,

    const wire_names = .{
        .branch = "branch",
        .tag = "tag",
        .commit = "commit",
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

pub const CreateRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const CreateRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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

pub const CreateRequestVersionDescriptorVersionOptions1 = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const CreateRequestVersionDescriptorVersionType1 = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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

pub const DeletePageRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const DeletePageRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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

pub const GetPageRequestRecursionLevel = enum {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .one_level => "oneLevel",
            .one_level_plus_nested_empty_folders => "oneLevelPlusNestedEmptyFolders",
            .full => "full",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "oneLevel")) return .one_level;
        if (std.mem.eql(u8, s, "oneLevelPlusNestedEmptyFolders")) return .one_level_plus_nested_empty_folders;
        if (std.mem.eql(u8, s, "full")) return .full;
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

pub const GetPageRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const GetPageRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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

pub const CreateOrUpdateRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const CreateOrUpdateRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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

pub const GetPageByIdRequestRecursionLevel = enum {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .one_level => "oneLevel",
            .one_level_plus_nested_empty_folders => "oneLevelPlusNestedEmptyFolders",
            .full => "full",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "oneLevel")) return .one_level;
        if (std.mem.eql(u8, s, "oneLevelPlusNestedEmptyFolders")) return .one_level_plus_nested_empty_folders;
        if (std.mem.eql(u8, s, "full")) return .full;
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

pub const GetRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
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

pub const GetRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
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
