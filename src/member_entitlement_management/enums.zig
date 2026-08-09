//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const AccessLevelAccountLicenseType = enum {
    none,
    early_adopter,
    express,
    professional,
    advanced,
    stakeholder,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .early_adopter => "earlyAdopter",
            .express => "express",
            .professional => "professional",
            .advanced => "advanced",
            .stakeholder => "stakeholder",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "earlyAdopter")) return .early_adopter;
        if (std.mem.eql(u8, s, "express")) return .express;
        if (std.mem.eql(u8, s, "professional")) return .professional;
        if (std.mem.eql(u8, s, "advanced")) return .advanced;
        if (std.mem.eql(u8, s, "stakeholder")) return .stakeholder;
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

pub const AccessLevelAssignmentSource = enum {
    none,
    unknown,
    group_rule,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .group_rule => "groupRule",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "groupRule")) return .group_rule;
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

pub const AccessLevelGitHubLicenseType = enum {
    none,
    enterprise,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .enterprise => "enterprise",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
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

pub const AccessLevelLicensingSource = enum {
    none,
    account,
    msdn,
    profile,
    auto,
    trial,
    git_hub,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .account => "account",
            .msdn => "msdn",
            .profile => "profile",
            .auto => "auto",
            .trial => "trial",
            .git_hub => "gitHub",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "account")) return .account;
        if (std.mem.eql(u8, s, "msdn")) return .msdn;
        if (std.mem.eql(u8, s, "profile")) return .profile;
        if (std.mem.eql(u8, s, "auto")) return .auto;
        if (std.mem.eql(u8, s, "trial")) return .trial;
        if (std.mem.eql(u8, s, "gitHub")) return .git_hub;
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

pub const AccessLevelMsdnLicenseType = enum {
    none,
    eligible,
    professional,
    platforms,
    test_professional,
    premium,
    ultimate,
    enterprise,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .eligible => "eligible",
            .professional => "professional",
            .platforms => "platforms",
            .test_professional => "testProfessional",
            .premium => "premium",
            .ultimate => "ultimate",
            .enterprise => "enterprise",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "eligible")) return .eligible;
        if (std.mem.eql(u8, s, "professional")) return .professional;
        if (std.mem.eql(u8, s, "platforms")) return .platforms;
        if (std.mem.eql(u8, s, "testProfessional")) return .test_professional;
        if (std.mem.eql(u8, s, "premium")) return .premium;
        if (std.mem.eql(u8, s, "ultimate")) return .ultimate;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
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

pub const AccessLevelStatus = enum {
    none,
    active,
    disabled,
    deleted,
    pending,
    expired,
    pending_disabled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .active => "active",
            .disabled => "disabled",
            .deleted => "deleted",
            .pending => "pending",
            .expired => "expired",
            .pending_disabled => "pendingDisabled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "expired")) return .expired;
        if (std.mem.eql(u8, s, "pendingDisabled")) return .pending_disabled;
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

pub const ProjectEntitlementAssignmentSource = enum {
    none,
    unknown,
    group_rule,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .group_rule => "groupRule",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "groupRule")) return .group_rule;
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

pub const GroupGroupType = enum {
    project_stakeholder,
    project_reader,
    project_contributor,
    project_administrator,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .project_stakeholder => "projectStakeholder",
            .project_reader => "projectReader",
            .project_contributor => "projectContributor",
            .project_administrator => "projectAdministrator",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "projectStakeholder")) return .project_stakeholder;
        if (std.mem.eql(u8, s, "projectReader")) return .project_reader;
        if (std.mem.eql(u8, s, "projectContributor")) return .project_contributor;
        if (std.mem.eql(u8, s, "projectAdministrator")) return .project_administrator;
        if (std.mem.eql(u8, s, "custom")) return .custom;
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

pub const ProjectEntitlementProjectPermissionInherited = enum {
    not_set,
    not_inherited,
    inherited,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .not_inherited => "notInherited",
            .inherited => "inherited",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "notInherited")) return .not_inherited;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const GroupEntitlementStatus = enum {
    apply_pending,
    applied,
    incompatible,
    unable_to_apply,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .apply_pending => "applyPending",
            .applied => "applied",
            .incompatible => "incompatible",
            .unable_to_apply => "unableToApply",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "applyPending")) return .apply_pending;
        if (std.mem.eql(u8, s, "applied")) return .applied;
        if (std.mem.eql(u8, s, "incompatible")) return .incompatible;
        if (std.mem.eql(u8, s, "unableToApply")) return .unable_to_apply;
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

pub const GroupEntitlementOperationReferenceStatus = enum {
    not_set,
    queued,
    in_progress,
    cancelled,
    succeeded,
    failed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .queued => "queued",
            .in_progress => "inProgress",
            .cancelled => "cancelled",
            .succeeded => "succeeded",
            .failed => "failed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "cancelled")) return .cancelled;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
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

pub const LicenseSummaryDataAccountLicenseType = enum {
    none,
    early_adopter,
    express,
    professional,
    advanced,
    stakeholder,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .early_adopter => "earlyAdopter",
            .express => "express",
            .professional => "professional",
            .advanced => "advanced",
            .stakeholder => "stakeholder",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "earlyAdopter")) return .early_adopter;
        if (std.mem.eql(u8, s, "express")) return .express;
        if (std.mem.eql(u8, s, "professional")) return .professional;
        if (std.mem.eql(u8, s, "advanced")) return .advanced;
        if (std.mem.eql(u8, s, "stakeholder")) return .stakeholder;
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

pub const LicenseSummaryDataGitHubLicenseType = enum {
    none,
    enterprise,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .enterprise => "enterprise",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
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

pub const LicenseSummaryDataMsdnLicenseType = enum {
    none,
    eligible,
    professional,
    platforms,
    test_professional,
    premium,
    ultimate,
    enterprise,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .eligible => "eligible",
            .professional => "professional",
            .platforms => "platforms",
            .test_professional => "testProfessional",
            .premium => "premium",
            .ultimate => "ultimate",
            .enterprise => "enterprise",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "eligible")) return .eligible;
        if (std.mem.eql(u8, s, "professional")) return .professional;
        if (std.mem.eql(u8, s, "platforms")) return .platforms;
        if (std.mem.eql(u8, s, "testProfessional")) return .test_professional;
        if (std.mem.eql(u8, s, "premium")) return .premium;
        if (std.mem.eql(u8, s, "ultimate")) return .ultimate;
        if (std.mem.eql(u8, s, "enterprise")) return .enterprise;
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

pub const LicenseSummaryDataSource = enum {
    none,
    account,
    msdn,
    profile,
    auto,
    trial,
    git_hub,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .account => "account",
            .msdn => "msdn",
            .profile => "profile",
            .auto => "auto",
            .trial => "trial",
            .git_hub => "gitHub",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "account")) return .account;
        if (std.mem.eql(u8, s, "msdn")) return .msdn;
        if (std.mem.eql(u8, s, "profile")) return .profile;
        if (std.mem.eql(u8, s, "auto")) return .auto;
        if (std.mem.eql(u8, s, "trial")) return .trial;
        if (std.mem.eql(u8, s, "gitHub")) return .git_hub;
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
