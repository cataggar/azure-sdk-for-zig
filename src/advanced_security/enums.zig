//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const CombinedAlertFilterCriteriaAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const CombinedAlertFilterCriteriaAlertValidityStatus = enum {
    none,
    unknown,
    active,
    inactive,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .active => "active",
            .inactive => "inactive",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "inactive")) return .inactive;
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

pub const CombinedAlertFilterCriteriaComponentType = enum {
    unknown,
    nu_get,
    npm,
    maven,
    git,
    other,
    ruby_gems,
    cargo,
    pip,
    file,
    go,
    docker_image,
    pod,
    linux,
    conda,
    docker_reference,
    vcpkg,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .nu_get => "nuGet",
            .npm => "npm",
            .maven => "maven",
            .git => "git",
            .other => "other",
            .ruby_gems => "rubyGems",
            .cargo => "cargo",
            .pip => "pip",
            .file => "file",
            .go => "go",
            .docker_image => "dockerImage",
            .pod => "pod",
            .linux => "linux",
            .conda => "conda",
            .docker_reference => "dockerReference",
            .vcpkg => "vcpkg",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "nuGet")) return .nu_get;
        if (std.mem.eql(u8, s, "npm")) return .npm;
        if (std.mem.eql(u8, s, "maven")) return .maven;
        if (std.mem.eql(u8, s, "git")) return .git;
        if (std.mem.eql(u8, s, "other")) return .other;
        if (std.mem.eql(u8, s, "rubyGems")) return .ruby_gems;
        if (std.mem.eql(u8, s, "cargo")) return .cargo;
        if (std.mem.eql(u8, s, "pip")) return .pip;
        if (std.mem.eql(u8, s, "file")) return .file;
        if (std.mem.eql(u8, s, "go")) return .go;
        if (std.mem.eql(u8, s, "dockerImage")) return .docker_image;
        if (std.mem.eql(u8, s, "pod")) return .pod;
        if (std.mem.eql(u8, s, "linux")) return .linux;
        if (std.mem.eql(u8, s, "conda")) return .conda;
        if (std.mem.eql(u8, s, "dockerReference")) return .docker_reference;
        if (std.mem.eql(u8, s, "vcpkg")) return .vcpkg;
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

pub const CombinedAlertFilterCriteriaDismissalType = enum {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .fixed => "fixed",
            .accepted_risk => "acceptedRisk",
            .false_positive => "falsePositive",
            .agreed_to_guidance => "agreedToGuidance",
            .tool_upgrade => "toolUpgrade",
            .not_distributed => "notDistributed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "acceptedRisk")) return .accepted_risk;
        if (std.mem.eql(u8, s, "falsePositive")) return .false_positive;
        if (std.mem.eql(u8, s, "agreedToGuidance")) return .agreed_to_guidance;
        if (std.mem.eql(u8, s, "toolUpgrade")) return .tool_upgrade;
        if (std.mem.eql(u8, s, "notDistributed")) return .not_distributed;
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

pub const CombinedAlertFilterCriteriaSeverity = enum {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
            .critical => "critical",
            .note => "note",
            .warning => "warning",
            .@"error" => "error",
            .undefined => "undefined",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "critical")) return .critical;
        if (std.mem.eql(u8, s, "note")) return .note;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
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

pub const CombinedAlertFilterCriteriaState = enum {
    open,
    closed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .open => "open",
            .closed => "closed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "open")) return .open;
        if (std.mem.eql(u8, s, "closed")) return .closed;
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

pub const GetAlertSummaryForOrgRequestCriteriaPeriod = enum {
    undefined,
    last24hours,
    last7days,
    last14days,
    last30days,
    last90days,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .last24hours => "last24Hours",
            .last7days => "last7Days",
            .last14days => "last14Days",
            .last30days => "last30Days",
            .last90days => "last90Days",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "last24Hours")) return .last24hours;
        if (std.mem.eql(u8, s, "last7Days")) return .last7days;
        if (std.mem.eql(u8, s, "last14Days")) return .last14days;
        if (std.mem.eql(u8, s, "last30Days")) return .last30days;
        if (std.mem.eql(u8, s, "last90Days")) return .last90days;
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

pub const ListRequestCriteriaAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const ListRequestCriteriaAlertValidityStatus = enum {
    none,
    unknown,
    active,
    inactive,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .active => "active",
            .inactive => "inactive",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "inactive")) return .inactive;
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

pub const ListRequestCriteriaState = enum {
    open,
    closed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .open => "open",
            .closed => "closed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "open")) return .open;
        if (std.mem.eql(u8, s, "closed")) return .closed;
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

pub const DashboardAlertAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const DashboardAlertSeverity = enum {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
            .critical => "critical",
            .note => "note",
            .warning => "warning",
            .@"error" => "error",
            .undefined => "undefined",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "critical")) return .critical;
        if (std.mem.eql(u8, s, "note")) return .note;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
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

pub const DashboardAlertState = enum {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .dismissed => "dismissed",
            .fixed => "fixed",
            .auto_dismissed => "autoDismissed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "dismissed")) return .dismissed;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "autoDismissed")) return .auto_dismissed;
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

pub const DashboardAlertValidityStatus = enum {
    none,
    unknown,
    active,
    inactive,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .active => "active",
            .inactive => "inactive",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "inactive")) return .inactive;
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

pub const ListRequestExpand = enum {
    none,
    minimal,
    count,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .minimal => "minimal",
            .count => "count",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "minimal")) return .minimal;
        if (std.mem.eql(u8, s, "count")) return .count;
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

pub const AlertAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const AlertConfidence = enum {
    high,
    other,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .high => "high",
            .other => "other",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "other")) return .other;
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

pub const DismissalDismissalType = enum {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .fixed => "fixed",
            .accepted_risk => "acceptedRisk",
            .false_positive => "falsePositive",
            .agreed_to_guidance => "agreedToGuidance",
            .tool_upgrade => "toolUpgrade",
            .not_distributed => "notDistributed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "acceptedRisk")) return .accepted_risk;
        if (std.mem.eql(u8, s, "falsePositive")) return .false_positive;
        if (std.mem.eql(u8, s, "agreedToGuidance")) return .agreed_to_guidance;
        if (std.mem.eql(u8, s, "toolUpgrade")) return .tool_upgrade;
        if (std.mem.eql(u8, s, "notDistributed")) return .not_distributed;
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

pub const LogicalLocationKind = enum {
    unknown,
    root_dependency,
    component,
    vulnerable_dependency,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .root_dependency => "rootDependency",
            .component => "component",
            .vulnerable_dependency => "vulnerableDependency",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "rootDependency")) return .root_dependency;
        if (std.mem.eql(u8, s, "component")) return .component;
        if (std.mem.eql(u8, s, "vulnerableDependency")) return .vulnerable_dependency;
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

pub const LicenseState = enum {
    unknown,
    not_harvested,
    harvested,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .not_harvested => "notHarvested",
            .harvested => "harvested",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "notHarvested")) return .not_harvested;
        if (std.mem.eql(u8, s, "harvested")) return .harvested;
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

pub const LicenseType = enum {
    unknown,
    permissive,
    weak_copyleft,
    strong_copyleft,
    network_copyleft,
    other,
    no_assertion,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .permissive => "permissive",
            .weak_copyleft => "weakCopyleft",
            .strong_copyleft => "strongCopyleft",
            .network_copyleft => "networkCopyleft",
            .other => "other",
            .no_assertion => "noAssertion",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "permissive")) return .permissive;
        if (std.mem.eql(u8, s, "weakCopyleft")) return .weak_copyleft;
        if (std.mem.eql(u8, s, "strongCopyleft")) return .strong_copyleft;
        if (std.mem.eql(u8, s, "networkCopyleft")) return .network_copyleft;
        if (std.mem.eql(u8, s, "other")) return .other;
        if (std.mem.eql(u8, s, "noAssertion")) return .no_assertion;
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

pub const AlertSeverity = enum {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
            .critical => "critical",
            .note => "note",
            .warning => "warning",
            .@"error" => "error",
            .undefined => "undefined",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "critical")) return .critical;
        if (std.mem.eql(u8, s, "note")) return .note;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
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

pub const AlertState = enum {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .dismissed => "dismissed",
            .fixed => "fixed",
            .auto_dismissed => "autoDismissed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "dismissed")) return .dismissed;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "autoDismissed")) return .auto_dismissed;
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

pub const ValidationFingerprintValidityResult = enum {
    none,
    exploitable,
    not_exploitable,
    inconclusive,
    validation_not_supported,
    transient_error,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .exploitable => "exploitable",
            .not_exploitable => "notExploitable",
            .inconclusive => "inconclusive",
            .validation_not_supported => "validationNotSupported",
            .transient_error => "transientError",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "exploitable")) return .exploitable;
        if (std.mem.eql(u8, s, "notExploitable")) return .not_exploitable;
        if (std.mem.eql(u8, s, "inconclusive")) return .inconclusive;
        if (std.mem.eql(u8, s, "validationNotSupported")) return .validation_not_supported;
        if (std.mem.eql(u8, s, "transientError")) return .transient_error;
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

pub const AlertValidityInfoValidityStatus = enum {
    none,
    unknown,
    active,
    inactive,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .active => "active",
            .inactive => "inactive",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "inactive")) return .inactive;
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

pub const GetRequestExpand = enum {
    none,
    validation_fingerprint,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .validation_fingerprint => "validationFingerprint",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "validationFingerprint")) return .validation_fingerprint;
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

pub const AlertStateUpdateDismissedReason = enum {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .fixed => "fixed",
            .accepted_risk => "acceptedRisk",
            .false_positive => "falsePositive",
            .agreed_to_guidance => "agreedToGuidance",
            .tool_upgrade => "toolUpgrade",
            .not_distributed => "notDistributed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "acceptedRisk")) return .accepted_risk;
        if (std.mem.eql(u8, s, "falsePositive")) return .false_positive;
        if (std.mem.eql(u8, s, "agreedToGuidance")) return .agreed_to_guidance;
        if (std.mem.eql(u8, s, "toolUpgrade")) return .tool_upgrade;
        if (std.mem.eql(u8, s, "notDistributed")) return .not_distributed;
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

pub const AlertStateUpdateState = enum {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .dismissed => "dismissed",
            .fixed => "fixed",
            .auto_dismissed => "autoDismissed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "dismissed")) return .dismissed;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "autoDismissed")) return .auto_dismissed;
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

pub const AnalysisConfigurationAnalysisConfigurationType = enum {
    default,
    ado_pipeline,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .default => "default",
            .ado_pipeline => "adoPipeline",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "default")) return .default;
        if (std.mem.eql(u8, s, "adoPipeline")) return .ado_pipeline;
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

pub const DependencyComponentType = enum {
    unknown,
    nu_get,
    npm,
    maven,
    git,
    other,
    ruby_gems,
    cargo,
    pip,
    file,
    go,
    docker_image,
    pod,
    linux,
    conda,
    docker_reference,
    vcpkg,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .nu_get => "nuGet",
            .npm => "npm",
            .maven => "maven",
            .git => "git",
            .other => "other",
            .ruby_gems => "rubyGems",
            .cargo => "cargo",
            .pip => "pip",
            .file => "file",
            .go => "go",
            .docker_image => "dockerImage",
            .pod => "pod",
            .linux => "linux",
            .conda => "conda",
            .docker_reference => "dockerReference",
            .vcpkg => "vcpkg",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "nuGet")) return .nu_get;
        if (std.mem.eql(u8, s, "npm")) return .npm;
        if (std.mem.eql(u8, s, "maven")) return .maven;
        if (std.mem.eql(u8, s, "git")) return .git;
        if (std.mem.eql(u8, s, "other")) return .other;
        if (std.mem.eql(u8, s, "rubyGems")) return .ruby_gems;
        if (std.mem.eql(u8, s, "cargo")) return .cargo;
        if (std.mem.eql(u8, s, "pip")) return .pip;
        if (std.mem.eql(u8, s, "file")) return .file;
        if (std.mem.eql(u8, s, "go")) return .go;
        if (std.mem.eql(u8, s, "dockerImage")) return .docker_image;
        if (std.mem.eql(u8, s, "pod")) return .pod;
        if (std.mem.eql(u8, s, "linux")) return .linux;
        if (std.mem.eql(u8, s, "conda")) return .conda;
        if (std.mem.eql(u8, s, "dockerReference")) return .docker_reference;
        if (std.mem.eql(u8, s, "vcpkg")) return .vcpkg;
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

pub const ResultResultType = enum {
    unknown,
    dependency,
    version_control,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .version_control => "versionControl",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "versionControl")) return .version_control;
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

pub const ResultSeverity = enum {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
            .critical => "critical",
            .note => "note",
            .warning => "warning",
            .@"error" => "error",
            .undefined => "undefined",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "medium")) return .medium;
        if (std.mem.eql(u8, s, "high")) return .high;
        if (std.mem.eql(u8, s, "critical")) return .critical;
        if (std.mem.eql(u8, s, "note")) return .note;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
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

pub const AnalysisResultState = enum {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .dismissed => "dismissed",
            .fixed => "fixed",
            .auto_dismissed => "autoDismissed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "dismissed")) return .dismissed;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "autoDismissed")) return .auto_dismissed;
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

pub const AlertAnalysisInstanceState = enum {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .dismissed => "dismissed",
            .fixed => "fixed",
            .auto_dismissed => "autoDismissed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "dismissed")) return .dismissed;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "autoDismissed")) return .auto_dismissed;
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

pub const MetadataOp = enum {
    none,
    add,
    remove,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .add => "add",
            .remove => "remove",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "remove")) return .remove;
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

pub const AlertMetadataBatchRequestErrorPolicy = enum {
    fail,
    omit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .fail => "fail",
            .omit => "omit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "fail")) return .fail;
        if (std.mem.eql(u8, s, "omit")) return .omit;
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

pub const AlertBatchRequestAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const ListRequestAlertType = enum {
    unknown,
    dependency,
    secret,
    code,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .dependency => "dependency",
            .secret => "secret",
            .code => "code",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "dependency")) return .dependency;
        if (std.mem.eql(u8, s, "secret")) return .secret;
        if (std.mem.eql(u8, s, "code")) return .code;
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

pub const GetRequestPlan = enum {
    code_security,
    secret_protection,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .code_security => "codeSecurity",
            .secret_protection => "secretProtection",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "codeSecurity")) return .code_security;
        if (std.mem.eql(u8, s, "secretProtection")) return .secret_protection;
        if (std.mem.eql(u8, s, "all")) return .all;
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

pub const GetRequestPlan1 = enum {
    code_security,
    secret_protection,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .code_security => "codeSecurity",
            .secret_protection => "secretProtection",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "codeSecurity")) return .code_security;
        if (std.mem.eql(u8, s, "secretProtection")) return .secret_protection;
        if (std.mem.eql(u8, s, "all")) return .all;
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

pub const GetRequestPlan2 = enum {
    code_security,
    secret_protection,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .code_security => "codeSecurity",
            .secret_protection => "secretProtection",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "codeSecurity")) return .code_security;
        if (std.mem.eql(u8, s, "secretProtection")) return .secret_protection;
        if (std.mem.eql(u8, s, "all")) return .all;
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

pub const GetRequestPlan3 = enum {
    code_security,
    secret_protection,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .code_security => "codeSecurity",
            .secret_protection => "secretProtection",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "codeSecurity")) return .code_security;
        if (std.mem.eql(u8, s, "secretProtection")) return .secret_protection;
        if (std.mem.eql(u8, s, "all")) return .all;
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
