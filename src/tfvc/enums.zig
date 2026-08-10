//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const TfvcChangeChangeType = union(enum) {
    none,
    add,
    edit,
    encoding,
    rename,
    delete,
    undelete,
    branch,
    merge,
    lock,
    rollback,
    source_rename,
    target_rename,
    property,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .add = "add",
        .edit = "edit",
        .encoding = "encoding",
        .rename = "rename",
        .delete = "delete",
        .undelete = "undelete",
        .branch = "branch",
        .merge = "merge",
        .lock = "lock",
        .rollback = "rollback",
        .source_rename = "sourceRename",
        .target_rename = "targetRename",
        .property = "property",
        .all = "all",
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

pub const ItemContentContentType = union(enum) {
    raw_text,
    base64encoded,
    unrecognized: []const u8,

    const wire_names = .{
        .raw_text = "rawText",
        .base64encoded = "base64Encoded",
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

pub const TfvcItemDescriptorRecursionLevel = union(enum) {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .one_level = "oneLevel",
        .one_level_plus_nested_empty_folders = "oneLevelPlusNestedEmptyFolders",
        .full = "full",
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

pub const TfvcItemDescriptorVersionOption = union(enum) {
    none,
    previous,
    use_rename,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .previous = "previous",
        .use_rename = "useRename",
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

pub const TfvcItemDescriptorVersionType = union(enum) {
    none,
    changeset,
    shelveset,
    change,
    date,
    latest,
    tip,
    merge_source,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .changeset = "changeset",
        .shelveset = "shelveset",
        .change = "change",
        .date = "date",
        .latest = "latest",
        .tip = "tip",
        .merge_source = "mergeSource",
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

pub const ListRequestRecursionLevel = enum {
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

pub const ListRequestVersionDescriptorVersionOption = enum {
    none,
    previous,
    use_rename,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous => "previous",
            .use_rename => "useRename",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previous")) return .previous;
        if (std.mem.eql(u8, s, "useRename")) return .use_rename;
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

pub const ListRequestVersionDescriptorVersionType = enum {
    none,
    changeset,
    shelveset,
    change,
    date,
    latest,
    tip,
    merge_source,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .changeset => "changeset",
            .shelveset => "shelveset",
            .change => "change",
            .date => "date",
            .latest => "latest",
            .tip => "tip",
            .merge_source => "mergeSource",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "changeset")) return .changeset;
        if (std.mem.eql(u8, s, "shelveset")) return .shelveset;
        if (std.mem.eql(u8, s, "change")) return .change;
        if (std.mem.eql(u8, s, "date")) return .date;
        if (std.mem.eql(u8, s, "latest")) return .latest;
        if (std.mem.eql(u8, s, "tip")) return .tip;
        if (std.mem.eql(u8, s, "mergeSource")) return .merge_source;
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
