//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const AccessLevelAccountLicenseType = union(enum) {
    none,
    early_adopter,
    express,
    professional,
    advanced,
    stakeholder,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .early_adopter = "earlyAdopter",
        .express = "express",
        .professional = "professional",
        .advanced = "advanced",
        .stakeholder = "stakeholder",
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

pub const AccessLevelAssignmentSource = union(enum) {
    none,
    unknown,
    group_rule,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .group_rule = "groupRule",
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

pub const AccessLevelGitHubLicenseType = union(enum) {
    none,
    enterprise,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .enterprise = "enterprise",
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

pub const AccessLevelLicensingSource = union(enum) {
    none,
    account,
    msdn,
    profile,
    auto,
    trial,
    git_hub,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .account = "account",
        .msdn = "msdn",
        .profile = "profile",
        .auto = "auto",
        .trial = "trial",
        .git_hub = "gitHub",
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

pub const AccessLevelMsdnLicenseType = union(enum) {
    none,
    eligible,
    professional,
    platforms,
    test_professional,
    premium,
    ultimate,
    enterprise,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .eligible = "eligible",
        .professional = "professional",
        .platforms = "platforms",
        .test_professional = "testProfessional",
        .premium = "premium",
        .ultimate = "ultimate",
        .enterprise = "enterprise",
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

pub const AccessLevelStatus = union(enum) {
    none,
    active,
    disabled,
    deleted,
    pending,
    expired,
    pending_disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .active = "active",
        .disabled = "disabled",
        .deleted = "deleted",
        .pending = "pending",
        .expired = "expired",
        .pending_disabled = "pendingDisabled",
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

pub const ProjectEntitlementAssignmentSource = union(enum) {
    none,
    unknown,
    group_rule,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .group_rule = "groupRule",
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

pub const GroupGroupType = union(enum) {
    project_stakeholder,
    project_reader,
    project_contributor,
    project_administrator,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .project_stakeholder = "projectStakeholder",
        .project_reader = "projectReader",
        .project_contributor = "projectContributor",
        .project_administrator = "projectAdministrator",
        .custom = "custom",
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

pub const ProjectEntitlementProjectPermissionInherited = union(enum) {
    not_set,
    not_inherited,
    inherited,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .not_inherited = "notInherited",
        .inherited = "inherited",
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

pub const GroupEntitlementStatus = union(enum) {
    apply_pending,
    applied,
    incompatible,
    unable_to_apply,
    unrecognized: []const u8,

    const wire_names = .{
        .apply_pending = "applyPending",
        .applied = "applied",
        .incompatible = "incompatible",
        .unable_to_apply = "unableToApply",
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

pub const AddRequestRuleOption = enum {
    apply_group_rule,
    test_apply_group_rule,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .apply_group_rule => "applyGroupRule",
            .test_apply_group_rule => "testApplyGroupRule",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "applyGroupRule")) return .apply_group_rule;
        if (std.mem.eql(u8, s, "testApplyGroupRule")) return .test_apply_group_rule;
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

pub const GroupEntitlementOperationReferenceStatus = union(enum) {
    not_set,
    queued,
    in_progress,
    cancelled,
    succeeded,
    failed,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .queued = "queued",
        .in_progress = "inProgress",
        .cancelled = "cancelled",
        .succeeded = "succeeded",
        .failed = "failed",
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

pub const DeleteRequestRuleOption = enum {
    apply_group_rule,
    test_apply_group_rule,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .apply_group_rule => "applyGroupRule",
            .test_apply_group_rule => "testApplyGroupRule",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "applyGroupRule")) return .apply_group_rule;
        if (std.mem.eql(u8, s, "testApplyGroupRule")) return .test_apply_group_rule;
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

pub const UpdateRequestRuleOption = enum {
    apply_group_rule,
    test_apply_group_rule,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .apply_group_rule => "applyGroupRule",
            .test_apply_group_rule => "testApplyGroupRule",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "applyGroupRule")) return .apply_group_rule;
        if (std.mem.eql(u8, s, "testApplyGroupRule")) return .test_apply_group_rule;
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

pub const SearchMemberEntitlementsRequestSelect = enum {
    license,
    extensions,
    projects,
    group_rules,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .license => "license",
            .extensions => "extensions",
            .projects => "projects",
            .group_rules => "groupRules",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "license")) return .license;
        if (std.mem.eql(u8, s, "extensions")) return .extensions;
        if (std.mem.eql(u8, s, "projects")) return .projects;
        if (std.mem.eql(u8, s, "groupRules")) return .group_rules;
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

pub const SearchUserEntitlementsRequestSelect = enum {
    license,
    extensions,
    projects,
    group_rules,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .license => "license",
            .extensions => "extensions",
            .projects => "projects",
            .group_rules => "groupRules",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "license")) return .license;
        if (std.mem.eql(u8, s, "extensions")) return .extensions;
        if (std.mem.eql(u8, s, "projects")) return .projects;
        if (std.mem.eql(u8, s, "groupRules")) return .group_rules;
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

pub const LicenseSummaryDataAccountLicenseType = union(enum) {
    none,
    early_adopter,
    express,
    professional,
    advanced,
    stakeholder,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .early_adopter = "earlyAdopter",
        .express = "express",
        .professional = "professional",
        .advanced = "advanced",
        .stakeholder = "stakeholder",
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

pub const LicenseSummaryDataGitHubLicenseType = union(enum) {
    none,
    enterprise,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .enterprise = "enterprise",
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

pub const LicenseSummaryDataMsdnLicenseType = union(enum) {
    none,
    eligible,
    professional,
    platforms,
    test_professional,
    premium,
    ultimate,
    enterprise,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .eligible = "eligible",
        .professional = "professional",
        .platforms = "platforms",
        .test_professional = "testProfessional",
        .premium = "premium",
        .ultimate = "ultimate",
        .enterprise = "enterprise",
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

pub const LicenseSummaryDataSource = union(enum) {
    none,
    account,
    msdn,
    profile,
    auto,
    trial,
    git_hub,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .account = "account",
        .msdn = "msdn",
        .profile = "profile",
        .auto = "auto",
        .trial = "trial",
        .git_hub = "gitHub",
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
