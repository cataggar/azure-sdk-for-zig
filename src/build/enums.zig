//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const BuildControllerStatus = union(enum) {
    unavailable,
    available,
    offline,
    unrecognized: []const u8,

    const wire_names = .{
        .unavailable = "unavailable",
        .available = "available",
        .offline = "offline",
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

pub const ListRequestReasonFilter = enum {
    none,
    manual,
    individual_ci,
    batched_ci,
    schedule,
    schedule_forced,
    user_created,
    validate_shelveset,
    check_in_shelveset,
    pull_request,
    build_completion,
    resource_trigger,
    triggered,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .individual_ci => "individualCI",
            .batched_ci => "batchedCI",
            .schedule => "schedule",
            .schedule_forced => "scheduleForced",
            .user_created => "userCreated",
            .validate_shelveset => "validateShelveset",
            .check_in_shelveset => "checkInShelveset",
            .pull_request => "pullRequest",
            .build_completion => "buildCompletion",
            .resource_trigger => "resourceTrigger",
            .triggered => "triggered",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "individualCI")) return .individual_ci;
        if (std.mem.eql(u8, s, "batchedCI")) return .batched_ci;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "scheduleForced")) return .schedule_forced;
        if (std.mem.eql(u8, s, "userCreated")) return .user_created;
        if (std.mem.eql(u8, s, "validateShelveset")) return .validate_shelveset;
        if (std.mem.eql(u8, s, "checkInShelveset")) return .check_in_shelveset;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
        if (std.mem.eql(u8, s, "buildCompletion")) return .build_completion;
        if (std.mem.eql(u8, s, "resourceTrigger")) return .resource_trigger;
        if (std.mem.eql(u8, s, "triggered")) return .triggered;
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

pub const ListRequestStatusFilter = enum {
    none,
    in_progress,
    completed,
    cancelling,
    postponed,
    abandoned,
    not_started,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .in_progress => "inProgress",
            .completed => "completed",
            .cancelling => "cancelling",
            .postponed => "postponed",
            .abandoned => "abandoned",
            .not_started => "notStarted",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "cancelling")) return .cancelling;
        if (std.mem.eql(u8, s, "postponed")) return .postponed;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
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

pub const ListRequestResultFilter = enum {
    none,
    succeeded,
    partially_succeeded,
    failed,
    canceled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .succeeded => "succeeded",
            .partially_succeeded => "partiallySucceeded",
            .failed => "failed",
            .canceled => "canceled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
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

pub const ListRequestDeletedFilter = enum {
    exclude_deleted,
    include_deleted,
    only_deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .exclude_deleted => "excludeDeleted",
            .include_deleted => "includeDeleted",
            .only_deleted => "onlyDeleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "excludeDeleted")) return .exclude_deleted;
        if (std.mem.eql(u8, s, "includeDeleted")) return .include_deleted;
        if (std.mem.eql(u8, s, "onlyDeleted")) return .only_deleted;
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

pub const ListRequestQueryOrder = enum {
    finish_time_ascending,
    finish_time_descending,
    queue_time_descending,
    queue_time_ascending,
    start_time_descending,
    start_time_ascending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .finish_time_ascending => "finishTimeAscending",
            .finish_time_descending => "finishTimeDescending",
            .queue_time_descending => "queueTimeDescending",
            .queue_time_ascending => "queueTimeAscending",
            .start_time_descending => "startTimeDescending",
            .start_time_ascending => "startTimeAscending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "finishTimeAscending")) return .finish_time_ascending;
        if (std.mem.eql(u8, s, "finishTimeDescending")) return .finish_time_descending;
        if (std.mem.eql(u8, s, "queueTimeDescending")) return .queue_time_descending;
        if (std.mem.eql(u8, s, "queueTimeAscending")) return .queue_time_ascending;
        if (std.mem.eql(u8, s, "startTimeDescending")) return .start_time_descending;
        if (std.mem.eql(u8, s, "startTimeAscending")) return .start_time_ascending;
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

pub const TeamProjectReferenceState = union(enum) {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,
    unrecognized: []const u8,

    const wire_names = .{
        .deleting = "deleting",
        .new = "new",
        .well_formed = "wellFormed",
        .create_pending = "createPending",
        .all = "all",
        .unchanged = "unchanged",
        .deleted = "deleted",
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

pub const TeamProjectReferenceVisibility = union(enum) {
    private,
    public,
    unrecognized: []const u8,

    const wire_names = .{
        .private = "private",
        .public = "public",
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

pub const DefinitionReferenceQueueStatus = union(enum) {
    enabled,
    paused,
    disabled,
    unrecognized: []const u8,

    const wire_names = .{
        .enabled = "enabled",
        .paused = "paused",
        .disabled = "disabled",
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

pub const DefinitionReferenceType = union(enum) {
    xaml,
    build,
    unrecognized: []const u8,

    const wire_names = .{
        .xaml = "xaml",
        .build = "build",
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

pub const BuildPriority = union(enum) {
    low,
    below_normal,
    normal,
    above_normal,
    high,
    unrecognized: []const u8,

    const wire_names = .{
        .low = "low",
        .below_normal = "belowNormal",
        .normal = "normal",
        .above_normal = "aboveNormal",
        .high = "high",
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

pub const BuildQueueOptions = union(enum) {
    none,
    do_not_run,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .do_not_run = "doNotRun",
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

pub const BuildReason = union(enum) {
    none,
    manual,
    individual_ci,
    batched_ci,
    schedule,
    schedule_forced,
    user_created,
    validate_shelveset,
    check_in_shelveset,
    pull_request,
    build_completion,
    resource_trigger,
    triggered,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .individual_ci = "individualCI",
        .batched_ci = "batchedCI",
        .schedule = "schedule",
        .schedule_forced = "scheduleForced",
        .user_created = "userCreated",
        .validate_shelveset = "validateShelveset",
        .check_in_shelveset = "checkInShelveset",
        .pull_request = "pullRequest",
        .build_completion = "buildCompletion",
        .resource_trigger = "resourceTrigger",
        .triggered = "triggered",
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

pub const BuildResult = union(enum) {
    none,
    succeeded,
    partially_succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .succeeded = "succeeded",
        .partially_succeeded = "partiallySucceeded",
        .failed = "failed",
        .canceled = "canceled",
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

pub const BuildStatus = union(enum) {
    none,
    in_progress,
    completed,
    cancelling,
    postponed,
    abandoned,
    not_started,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .in_progress = "inProgress",
        .completed = "completed",
        .cancelling = "cancelling",
        .postponed = "postponed",
        .abandoned = "abandoned",
        .not_started = "notStarted",
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

pub const BuildRequestValidationResultResult = union(enum) {
    ok,
    warning,
    @"error",
    unrecognized: []const u8,

    const wire_names = .{
        .ok = "ok",
        .warning = "warning",
        .@"error" = "error",
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

pub const UpdateStageParametersState = union(enum) {
    cancel,
    retry,
    run,
    unrecognized: []const u8,

    const wire_names = .{
        .cancel = "cancel",
        .retry = "retry",
        .run = "run",
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

pub const IssueType = union(enum) {
    @"error",
    warning,
    unrecognized: []const u8,

    const wire_names = .{
        .@"error" = "error",
        .warning = "warning",
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

pub const TimelineRecordResult = union(enum) {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "succeeded",
        .succeeded_with_issues = "succeededWithIssues",
        .failed = "failed",
        .canceled = "canceled",
        .skipped = "skipped",
        .abandoned = "abandoned",
        .manually_queued = "manuallyQueued",
        .dependent_on_manual_queue = "dependentOnManualQueue",
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

pub const TimelineRecordState = union(enum) {
    pending,
    in_progress,
    completed,
    unrecognized: []const u8,

    const wire_names = .{
        .pending = "pending",
        .in_progress = "inProgress",
        .completed = "completed",
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

pub const ListRequestQueryOrder1 = enum {
    none,
    last_modified_ascending,
    last_modified_descending,
    definition_name_ascending,
    definition_name_descending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .last_modified_ascending => "lastModifiedAscending",
            .last_modified_descending => "lastModifiedDescending",
            .definition_name_ascending => "definitionNameAscending",
            .definition_name_descending => "definitionNameDescending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "lastModifiedAscending")) return .last_modified_ascending;
        if (std.mem.eql(u8, s, "lastModifiedDescending")) return .last_modified_descending;
        if (std.mem.eql(u8, s, "definitionNameAscending")) return .definition_name_ascending;
        if (std.mem.eql(u8, s, "definitionNameDescending")) return .definition_name_descending;
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

pub const BuildDefinitionReferenceQuality = union(enum) {
    definition,
    draft,
    unrecognized: []const u8,

    const wire_names = .{
        .definition = "definition",
        .draft = "draft",
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

pub const BuildDefinitionJobAuthorizationScope = union(enum) {
    project_collection,
    project,
    unrecognized: []const u8,

    const wire_names = .{
        .project_collection = "projectCollection",
        .project = "project",
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

pub const BuildTriggerTriggerType = union(enum) {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .continuous_integration = "continuousIntegration",
        .batched_continuous_integration = "batchedContinuousIntegration",
        .schedule = "schedule",
        .gated_check_in = "gatedCheckIn",
        .batched_gated_check_in = "batchedGatedCheckIn",
        .pull_request = "pullRequest",
        .build_completion = "buildCompletion",
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

pub const BuildDefinitionRevisionChangeType = union(enum) {
    add,
    update,
    delete,
    unrecognized: []const u8,

    const wire_names = .{
        .add = "add",
        .update = "update",
        .delete = "delete",
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

pub const ListRequestQueryOrder2 = enum {
    none,
    folder_ascending,
    folder_descending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .folder_ascending => "folderAscending",
            .folder_descending => "folderDescending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "folderAscending")) return .folder_ascending;
        if (std.mem.eql(u8, s, "folderDescending")) return .folder_descending;
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

pub const BuildOptionInputDefinitionType = union(enum) {
    string,
    boolean,
    string_list,
    radio,
    pick_list,
    multi_line,
    branch_filter,
    unrecognized: []const u8,

    const wire_names = .{
        .string = "string",
        .boolean = "boolean",
        .string_list = "stringList",
        .radio = "radio",
        .pick_list = "pickList",
        .multi_line = "multiLine",
        .branch_filter = "branchFilter",
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

pub const SupportedTriggerSupportedCapability = union(enum) {
    unsupported,
    supported,
    required,
    unrecognized: []const u8,

    const wire_names = .{
        .unsupported = "unsupported",
        .supported = "supported",
        .required = "required",
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

pub const SupportedTriggerType = union(enum) {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .continuous_integration = "continuousIntegration",
        .batched_continuous_integration = "batchedContinuousIntegration",
        .schedule = "schedule",
        .gated_check_in = "gatedCheckIn",
        .batched_gated_check_in = "batchedGatedCheckIn",
        .pull_request = "pullRequest",
        .build_completion = "buildCompletion",
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

pub const ListRepositoriesRequestResultSet = enum {
    all,
    top,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .all => "all",
            .top => "top",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "top")) return .top;
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

pub const RepositoryWebhookType = union(enum) {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .continuous_integration = "continuousIntegration",
        .batched_continuous_integration = "batchedContinuousIntegration",
        .schedule = "schedule",
        .gated_check_in = "gatedCheckIn",
        .batched_gated_check_in = "batchedGatedCheckIn",
        .pull_request = "pullRequest",
        .build_completion = "buildCompletion",
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
