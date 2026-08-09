//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const RequestStatus = enum {
    none,
    created,
    sealed,
    unavailable,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .created => "created",
            .sealed => "sealed",
            .unavailable => "unavailable",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "created")) return .created;
        if (std.mem.eql(u8, s, "sealed")) return .sealed;
        if (std.mem.eql(u8, s, "unavailable")) return .unavailable;
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

pub const DebugEntryCreateBatchCreateBehavior = enum {
    throw_if_exists,
    skip_if_exists,
    overwrite_if_exists,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .throw_if_exists => "throwIfExists",
            .skip_if_exists => "skipIfExists",
            .overwrite_if_exists => "overwriteIfExists",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "throwIfExists")) return .throw_if_exists;
        if (std.mem.eql(u8, s, "skipIfExists")) return .skip_if_exists;
        if (std.mem.eql(u8, s, "overwriteIfExists")) return .overwrite_if_exists;
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

pub const DebugEntryInformationLevel = enum {
    none,
    binary,
    publics,
    trace_format_present,
    type_info,
    line_numbers,
    global_symbols,
    private,
    source_indexed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .binary => "binary",
            .publics => "publics",
            .trace_format_present => "traceFormatPresent",
            .type_info => "typeInfo",
            .line_numbers => "lineNumbers",
            .global_symbols => "globalSymbols",
            .private => "private",
            .source_indexed => "sourceIndexed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "binary")) return .binary;
        if (std.mem.eql(u8, s, "publics")) return .publics;
        if (std.mem.eql(u8, s, "traceFormatPresent")) return .trace_format_present;
        if (std.mem.eql(u8, s, "typeInfo")) return .type_info;
        if (std.mem.eql(u8, s, "lineNumbers")) return .line_numbers;
        if (std.mem.eql(u8, s, "globalSymbols")) return .global_symbols;
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "sourceIndexed")) return .source_indexed;
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

pub const DebugEntryStatus = enum {
    none,
    created,
    blob_missing,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .created => "created",
            .blob_missing => "blobMissing",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "created")) return .created;
        if (std.mem.eql(u8, s, "blobMissing")) return .blob_missing;
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
