//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const GetRequestActionFilter = enum {
    none,
    manage,
    use,
    view,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
            .view => "view",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
        if (std.mem.eql(u8, s, "view")) return .view;
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

pub const InputDescriptorInputMode = enum {
    none,
    text_box,
    password_box,
    combo,
    radio_buttons,
    check_box,
    text_area,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .text_box => "textBox",
            .password_box => "passwordBox",
            .combo => "combo",
            .radio_buttons => "radioButtons",
            .check_box => "checkBox",
            .text_area => "textArea",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "textBox")) return .text_box;
        if (std.mem.eql(u8, s, "passwordBox")) return .password_box;
        if (std.mem.eql(u8, s, "combo")) return .combo;
        if (std.mem.eql(u8, s, "radioButtons")) return .radio_buttons;
        if (std.mem.eql(u8, s, "checkBox")) return .check_box;
        if (std.mem.eql(u8, s, "textArea")) return .text_area;
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

pub const InputValidationDataType = enum {
    none,
    string,
    number,
    boolean,
    guid,
    uri,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .string => "string",
            .number => "number",
            .boolean => "boolean",
            .guid => "guid",
            .uri => "uri",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "number")) return .number;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "guid")) return .guid;
        if (std.mem.eql(u8, s, "uri")) return .uri;
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

pub const ServiceEndpointExecutionDataResult = enum {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .succeeded => "succeeded",
            .succeeded_with_issues => "succeededWithIssues",
            .failed => "failed",
            .canceled => "canceled",
            .skipped => "skipped",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "succeededWithIssues")) return .succeeded_with_issues;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
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
