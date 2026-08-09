//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ContributionPropertyDescriptionType = enum {
    unknown,
    string,
    uri,
    guid,
    boolean,
    integer,
    double,
    date_time,
    dictionary,
    array,
    object,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .string => "string",
            .uri => "uri",
            .guid => "guid",
            .boolean => "boolean",
            .integer => "integer",
            .double => "double",
            .date_time => "dateTime",
            .dictionary => "dictionary",
            .array => "array",
            .object => "object",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "uri")) return .uri;
        if (std.mem.eql(u8, s, "guid")) return .guid;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "integer")) return .integer;
        if (std.mem.eql(u8, s, "double")) return .double;
        if (std.mem.eql(u8, s, "dateTime")) return .date_time;
        if (std.mem.eql(u8, s, "dictionary")) return .dictionary;
        if (std.mem.eql(u8, s, "array")) return .array;
        if (std.mem.eql(u8, s, "object")) return .object;
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

pub const LicensingOverrideBehavior = enum {
    only_if_licensed,
    only_if_unlicensed,
    always_include,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .only_if_licensed => "onlyIfLicensed",
            .only_if_unlicensed => "onlyIfUnlicensed",
            .always_include => "alwaysInclude",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "onlyIfLicensed")) return .only_if_licensed;
        if (std.mem.eql(u8, s, "onlyIfUnlicensed")) return .only_if_unlicensed;
        if (std.mem.eql(u8, s, "alwaysInclude")) return .always_include;
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

pub const InstalledExtensionFlags = enum {
    built_in,
    trusted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .built_in => "builtIn",
            .trusted => "trusted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "builtIn")) return .built_in;
        if (std.mem.eql(u8, s, "trusted")) return .trusted;
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

pub const InstalledExtensionStateFlags = enum {
    none,
    disabled,
    built_in,
    multi_version,
    un_installed,
    version_check_error,
    trusted,
    @"error",
    needs_reauthorization,
    auto_upgrade_error,
    warning,
    unpublished,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .disabled => "disabled",
            .built_in => "builtIn",
            .multi_version => "multiVersion",
            .un_installed => "unInstalled",
            .version_check_error => "versionCheckError",
            .trusted => "trusted",
            .@"error" => "error",
            .needs_reauthorization => "needsReauthorization",
            .auto_upgrade_error => "autoUpgradeError",
            .warning => "warning",
            .unpublished => "unpublished",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
        if (std.mem.eql(u8, s, "builtIn")) return .built_in;
        if (std.mem.eql(u8, s, "multiVersion")) return .multi_version;
        if (std.mem.eql(u8, s, "unInstalled")) return .un_installed;
        if (std.mem.eql(u8, s, "versionCheckError")) return .version_check_error;
        if (std.mem.eql(u8, s, "trusted")) return .trusted;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "needsReauthorization")) return .needs_reauthorization;
        if (std.mem.eql(u8, s, "autoUpgradeError")) return .auto_upgrade_error;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "unpublished")) return .unpublished;
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

pub const InstalledExtensionStateIssueType = enum {
    warning,
    @"error",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .warning => "warning",
            .@"error" => "error",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
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
