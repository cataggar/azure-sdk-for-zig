//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const CombinedAlertFilterCriteriaAlertType = union(enum) {
    unknown,
    dependency,
    secret,
    code,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .dependency = "dependency",
        .secret = "secret",
        .code = "code",
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

pub const CombinedAlertFilterCriteriaAlertValidityStatus = union(enum) {
    none,
    unknown,
    active,
    inactive,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .active = "active",
        .inactive = "inactive",
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

pub const CombinedAlertFilterCriteriaComponentType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .nu_get = "nuGet",
        .npm = "npm",
        .maven = "maven",
        .git = "git",
        .other = "other",
        .ruby_gems = "rubyGems",
        .cargo = "cargo",
        .pip = "pip",
        .file = "file",
        .go = "go",
        .docker_image = "dockerImage",
        .pod = "pod",
        .linux = "linux",
        .conda = "conda",
        .docker_reference = "dockerReference",
        .vcpkg = "vcpkg",
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

pub const CombinedAlertFilterCriteriaDismissalType = union(enum) {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .fixed = "fixed",
        .accepted_risk = "acceptedRisk",
        .false_positive = "falsePositive",
        .agreed_to_guidance = "agreedToGuidance",
        .tool_upgrade = "toolUpgrade",
        .not_distributed = "notDistributed",
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

pub const CombinedAlertFilterCriteriaSeverity = union(enum) {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,
    unrecognized: []const u8,

    const wire_names = .{
        .low = "low",
        .medium = "medium",
        .high = "high",
        .critical = "critical",
        .note = "note",
        .warning = "warning",
        .@"error" = "error",
        .undefined = "undefined",
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

pub const CombinedAlertFilterCriteriaState = union(enum) {
    open,
    closed,
    unrecognized: []const u8,

    const wire_names = .{
        .open = "open",
        .closed = "closed",
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

pub const DashboardAlertAlertType = union(enum) {
    unknown,
    dependency,
    secret,
    code,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .dependency = "dependency",
        .secret = "secret",
        .code = "code",
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

pub const DashboardAlertSeverity = union(enum) {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,
    unrecognized: []const u8,

    const wire_names = .{
        .low = "low",
        .medium = "medium",
        .high = "high",
        .critical = "critical",
        .note = "note",
        .warning = "warning",
        .@"error" = "error",
        .undefined = "undefined",
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

pub const DashboardAlertState = union(enum) {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .dismissed = "dismissed",
        .fixed = "fixed",
        .auto_dismissed = "autoDismissed",
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

pub const DashboardAlertValidityStatus = union(enum) {
    none,
    unknown,
    active,
    inactive,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .active = "active",
        .inactive = "inactive",
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

pub const AlertAlertType = union(enum) {
    unknown,
    dependency,
    secret,
    code,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .dependency = "dependency",
        .secret = "secret",
        .code = "code",
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

pub const AlertConfidence = union(enum) {
    high,
    other,
    unrecognized: []const u8,

    const wire_names = .{
        .high = "high",
        .other = "other",
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

pub const DismissalDismissalType = union(enum) {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .fixed = "fixed",
        .accepted_risk = "acceptedRisk",
        .false_positive = "falsePositive",
        .agreed_to_guidance = "agreedToGuidance",
        .tool_upgrade = "toolUpgrade",
        .not_distributed = "notDistributed",
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

pub const LogicalLocationKind = union(enum) {
    unknown,
    root_dependency,
    component,
    vulnerable_dependency,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .root_dependency = "rootDependency",
        .component = "component",
        .vulnerable_dependency = "vulnerableDependency",
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

pub const LicenseState = union(enum) {
    unknown,
    not_harvested,
    harvested,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .not_harvested = "notHarvested",
        .harvested = "harvested",
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

pub const LicenseType = union(enum) {
    unknown,
    permissive,
    weak_copyleft,
    strong_copyleft,
    network_copyleft,
    other,
    no_assertion,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .permissive = "permissive",
        .weak_copyleft = "weakCopyleft",
        .strong_copyleft = "strongCopyleft",
        .network_copyleft = "networkCopyleft",
        .other = "other",
        .no_assertion = "noAssertion",
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

pub const AlertSeverity = union(enum) {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,
    unrecognized: []const u8,

    const wire_names = .{
        .low = "low",
        .medium = "medium",
        .high = "high",
        .critical = "critical",
        .note = "note",
        .warning = "warning",
        .@"error" = "error",
        .undefined = "undefined",
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

pub const AlertState = union(enum) {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .dismissed = "dismissed",
        .fixed = "fixed",
        .auto_dismissed = "autoDismissed",
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

pub const ValidationFingerprintValidityResult = union(enum) {
    none,
    exploitable,
    not_exploitable,
    inconclusive,
    validation_not_supported,
    transient_error,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .exploitable = "exploitable",
        .not_exploitable = "notExploitable",
        .inconclusive = "inconclusive",
        .validation_not_supported = "validationNotSupported",
        .transient_error = "transientError",
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

pub const AlertValidityInfoValidityStatus = union(enum) {
    none,
    unknown,
    active,
    inactive,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .active = "active",
        .inactive = "inactive",
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

pub const AlertStateUpdateDismissedReason = union(enum) {
    unknown,
    fixed,
    accepted_risk,
    false_positive,
    agreed_to_guidance,
    tool_upgrade,
    not_distributed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .fixed = "fixed",
        .accepted_risk = "acceptedRisk",
        .false_positive = "falsePositive",
        .agreed_to_guidance = "agreedToGuidance",
        .tool_upgrade = "toolUpgrade",
        .not_distributed = "notDistributed",
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

pub const AlertStateUpdateState = union(enum) {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .dismissed = "dismissed",
        .fixed = "fixed",
        .auto_dismissed = "autoDismissed",
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

pub const AnalysisConfigurationAnalysisConfigurationType = union(enum) {
    default,
    ado_pipeline,
    unrecognized: []const u8,

    const wire_names = .{
        .default = "default",
        .ado_pipeline = "adoPipeline",
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

pub const DependencyComponentType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .nu_get = "nuGet",
        .npm = "npm",
        .maven = "maven",
        .git = "git",
        .other = "other",
        .ruby_gems = "rubyGems",
        .cargo = "cargo",
        .pip = "pip",
        .file = "file",
        .go = "go",
        .docker_image = "dockerImage",
        .pod = "pod",
        .linux = "linux",
        .conda = "conda",
        .docker_reference = "dockerReference",
        .vcpkg = "vcpkg",
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

pub const ResultResultType = union(enum) {
    unknown,
    dependency,
    version_control,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .dependency = "dependency",
        .version_control = "versionControl",
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

pub const ResultSeverity = union(enum) {
    low,
    medium,
    high,
    critical,
    note,
    warning,
    @"error",
    undefined,
    unrecognized: []const u8,

    const wire_names = .{
        .low = "low",
        .medium = "medium",
        .high = "high",
        .critical = "critical",
        .note = "note",
        .warning = "warning",
        .@"error" = "error",
        .undefined = "undefined",
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

pub const AnalysisResultState = union(enum) {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .dismissed = "dismissed",
        .fixed = "fixed",
        .auto_dismissed = "autoDismissed",
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

pub const AlertAnalysisInstanceState = union(enum) {
    unknown,
    active,
    dismissed,
    fixed,
    auto_dismissed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .dismissed = "dismissed",
        .fixed = "fixed",
        .auto_dismissed = "autoDismissed",
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

pub const MetadataOp = union(enum) {
    none,
    add,
    remove,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .add = "add",
        .remove = "remove",
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

pub const AlertMetadataBatchRequestErrorPolicy = union(enum) {
    fail,
    omit,
    unrecognized: []const u8,

    const wire_names = .{
        .fail = "fail",
        .omit = "omit",
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

pub const AlertBatchRequestAlertType = union(enum) {
    unknown,
    dependency,
    secret,
    code,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .dependency = "dependency",
        .secret = "secret",
        .code = "code",
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
