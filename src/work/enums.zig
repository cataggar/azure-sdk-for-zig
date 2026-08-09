//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const PlanUserPermissions = enum {
    none,
    view,
    edit,
    delete,
    manage,
    all_permissions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .view => "view",
            .edit => "edit",
            .delete => "delete",
            .manage => "manage",
            .all_permissions => "allPermissions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "view")) return .view;
        if (std.mem.eql(u8, s, "edit")) return .edit;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "allPermissions")) return .all_permissions;
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

pub const TimelineCriteriaStatusType = enum {
    ok,
    invalid_filter_clause,
    unknown,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .ok => "ok",
            .invalid_filter_clause => "invalidFilterClause",
            .unknown => "unknown",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "ok")) return .ok;
        if (std.mem.eql(u8, s, "invalidFilterClause")) return .invalid_filter_clause;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
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

pub const TimelineIterationStatusType = enum {
    ok,
    is_overlapping,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .ok => "ok",
            .is_overlapping => "isOverlapping",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "ok")) return .ok;
        if (std.mem.eql(u8, s, "isOverlapping")) return .is_overlapping;
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

pub const TimelineTeamStatusType = enum {
    ok,
    doesnt_exist_or_access_denied,
    max_teams_exceeded,
    max_team_fields_exceeded,
    backlog_in_error,
    missing_team_field_value,
    no_iterations_exist,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .ok => "ok",
            .doesnt_exist_or_access_denied => "doesntExistOrAccessDenied",
            .max_teams_exceeded => "maxTeamsExceeded",
            .max_team_fields_exceeded => "maxTeamFieldsExceeded",
            .backlog_in_error => "backlogInError",
            .missing_team_field_value => "missingTeamFieldValue",
            .no_iterations_exist => "noIterationsExist",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "ok")) return .ok;
        if (std.mem.eql(u8, s, "doesntExistOrAccessDenied")) return .doesnt_exist_or_access_denied;
        if (std.mem.eql(u8, s, "maxTeamsExceeded")) return .max_teams_exceeded;
        if (std.mem.eql(u8, s, "maxTeamFieldsExceeded")) return .max_team_fields_exceeded;
        if (std.mem.eql(u8, s, "backlogInError")) return .backlog_in_error;
        if (std.mem.eql(u8, s, "missingTeamFieldValue")) return .missing_team_field_value;
        if (std.mem.eql(u8, s, "noIterationsExist")) return .no_iterations_exist;
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

pub const WorkItemMultilineFieldsFormat = enum {
    markdown,
    html,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .markdown => "markdown",
            .html => "html",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "markdown")) return .markdown;
        if (std.mem.eql(u8, s, "html")) return .html;
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

pub const BacklogConfigurationBugsBehavior = enum {
    off,
    as_requirements,
    as_tasks,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .off => "off",
            .as_requirements => "asRequirements",
            .as_tasks => "asTasks",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "off")) return .off;
        if (std.mem.eql(u8, s, "asRequirements")) return .as_requirements;
        if (std.mem.eql(u8, s, "asTasks")) return .as_tasks;
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

pub const BacklogLevelConfigurationType = enum {
    portfolio,
    requirement,
    task,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .portfolio => "portfolio",
            .requirement => "requirement",
            .task => "task",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "portfolio")) return .portfolio;
        if (std.mem.eql(u8, s, "requirement")) return .requirement;
        if (std.mem.eql(u8, s, "task")) return .task;
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

pub const BoardColumnColumnType = enum {
    incoming,
    in_progress,
    outgoing,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .incoming => "incoming",
            .in_progress => "inProgress",
            .outgoing => "outgoing",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "incoming")) return .incoming;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "outgoing")) return .outgoing;
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

pub const TeamIterationAttributesTimeFrame = enum {
    past,
    current,
    future,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .past => "past",
            .current => "current",
            .future => "future",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "past")) return .past;
        if (std.mem.eql(u8, s, "current")) return .current;
        if (std.mem.eql(u8, s, "future")) return .future;
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

pub const TeamSettingBugsBehavior = enum {
    off,
    as_requirements,
    as_tasks,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .off => "off",
            .as_requirements => "asRequirements",
            .as_tasks => "asTasks",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "off")) return .off;
        if (std.mem.eql(u8, s, "asRequirements")) return .as_requirements;
        if (std.mem.eql(u8, s, "asTasks")) return .as_tasks;
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

pub const TeamSettingWorkingDay = enum {
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .sunday => "sunday",
            .monday => "monday",
            .tuesday => "tuesday",
            .wednesday => "wednesday",
            .thursday => "thursday",
            .friday => "friday",
            .saturday => "saturday",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "sunday")) return .sunday;
        if (std.mem.eql(u8, s, "monday")) return .monday;
        if (std.mem.eql(u8, s, "tuesday")) return .tuesday;
        if (std.mem.eql(u8, s, "wednesday")) return .wednesday;
        if (std.mem.eql(u8, s, "thursday")) return .thursday;
        if (std.mem.eql(u8, s, "friday")) return .friday;
        if (std.mem.eql(u8, s, "saturday")) return .saturday;
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

pub const TeamSettingsPatchBugsBehavior = enum {
    off,
    as_requirements,
    as_tasks,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .off => "off",
            .as_requirements => "asRequirements",
            .as_tasks => "asTasks",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "off")) return .off;
        if (std.mem.eql(u8, s, "asRequirements")) return .as_requirements;
        if (std.mem.eql(u8, s, "asTasks")) return .as_tasks;
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

pub const TeamSettingsPatchWorkingDay = enum {
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .sunday => "sunday",
            .monday => "monday",
            .tuesday => "tuesday",
            .wednesday => "wednesday",
            .thursday => "thursday",
            .friday => "friday",
            .saturday => "saturday",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "sunday")) return .sunday;
        if (std.mem.eql(u8, s, "monday")) return .monday;
        if (std.mem.eql(u8, s, "tuesday")) return .tuesday;
        if (std.mem.eql(u8, s, "wednesday")) return .wednesday;
        if (std.mem.eql(u8, s, "thursday")) return .thursday;
        if (std.mem.eql(u8, s, "friday")) return .friday;
        if (std.mem.eql(u8, s, "saturday")) return .saturday;
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
