//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const BuildControllerStatus = enum {
    unavailable,
    available,
    offline,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unavailable => "unavailable",
            .available => "available",
            .offline => "offline",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unavailable")) return .unavailable;
        if (std.mem.eql(u8, s, "available")) return .available;
        if (std.mem.eql(u8, s, "offline")) return .offline;
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

pub const TeamProjectReferenceState = enum {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .deleting => "deleting",
            .new => "new",
            .well_formed => "wellFormed",
            .create_pending => "createPending",
            .all => "all",
            .unchanged => "unchanged",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "wellFormed")) return .well_formed;
        if (std.mem.eql(u8, s, "createPending")) return .create_pending;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "unchanged")) return .unchanged;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
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

pub const TeamProjectReferenceVisibility = enum {
    private,
    public,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .private => "private",
            .public => "public",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "public")) return .public;
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

pub const DefinitionReferenceQueueStatus = enum {
    enabled,
    paused,
    disabled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .enabled => "enabled",
            .paused => "paused",
            .disabled => "disabled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
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

pub const DefinitionReferenceType = enum {
    xaml,
    build,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .xaml => "xaml",
            .build => "build",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "xaml")) return .xaml;
        if (std.mem.eql(u8, s, "build")) return .build;
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

pub const BuildPriority = enum {
    low,
    below_normal,
    normal,
    above_normal,
    high,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .low => "low",
            .below_normal => "belowNormal",
            .normal => "normal",
            .above_normal => "aboveNormal",
            .high => "high",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "low")) return .low;
        if (std.mem.eql(u8, s, "belowNormal")) return .below_normal;
        if (std.mem.eql(u8, s, "normal")) return .normal;
        if (std.mem.eql(u8, s, "aboveNormal")) return .above_normal;
        if (std.mem.eql(u8, s, "high")) return .high;
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

pub const BuildQueueOptions = enum {
    none,
    do_not_run,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .do_not_run => "doNotRun",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "doNotRun")) return .do_not_run;
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

pub const BuildReason = enum {
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

pub const BuildResult = enum {
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

pub const BuildStatus = enum {
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

pub const BuildRequestValidationResultResult = enum {
    ok,
    warning,
    @"error",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .ok => "ok",
            .warning => "warning",
            .@"error" => "error",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "ok")) return .ok;
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

pub const UpdateStageParametersState = enum {
    cancel,
    retry,
    run,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .cancel => "cancel",
            .retry => "retry",
            .run => "run",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "cancel")) return .cancel;
        if (std.mem.eql(u8, s, "retry")) return .retry;
        if (std.mem.eql(u8, s, "run")) return .run;
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

pub const IssueType = enum {
    @"error",
    warning,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "warning")) return .warning;
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

pub const TimelineRecordResult = enum {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .succeeded => "succeeded",
            .succeeded_with_issues => "succeededWithIssues",
            .failed => "failed",
            .canceled => "canceled",
            .skipped => "skipped",
            .abandoned => "abandoned",
            .manually_queued => "manuallyQueued",
            .dependent_on_manual_queue => "dependentOnManualQueue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "succeededWithIssues")) return .succeeded_with_issues;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "manuallyQueued")) return .manually_queued;
        if (std.mem.eql(u8, s, "dependentOnManualQueue")) return .dependent_on_manual_queue;
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

pub const TimelineRecordState = enum {
    pending,
    in_progress,
    completed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "inProgress",
            .completed => "completed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
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

pub const BuildDefinitionReferenceQuality = enum {
    definition,
    draft,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .definition => "definition",
            .draft => "draft",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "definition")) return .definition;
        if (std.mem.eql(u8, s, "draft")) return .draft;
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

pub const BuildDefinitionJobAuthorizationScope = enum {
    project_collection,
    project,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .project_collection => "projectCollection",
            .project => "project",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "projectCollection")) return .project_collection;
        if (std.mem.eql(u8, s, "project")) return .project;
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

pub const BuildTriggerTriggerType = enum {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .continuous_integration => "continuousIntegration",
            .batched_continuous_integration => "batchedContinuousIntegration",
            .schedule => "schedule",
            .gated_check_in => "gatedCheckIn",
            .batched_gated_check_in => "batchedGatedCheckIn",
            .pull_request => "pullRequest",
            .build_completion => "buildCompletion",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "batchedContinuousIntegration")) return .batched_continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "gatedCheckIn")) return .gated_check_in;
        if (std.mem.eql(u8, s, "batchedGatedCheckIn")) return .batched_gated_check_in;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
        if (std.mem.eql(u8, s, "buildCompletion")) return .build_completion;
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

pub const BuildDefinitionRevisionChangeType = enum {
    add,
    update,
    delete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .add => "add",
            .update => "update",
            .delete => "delete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "update")) return .update;
        if (std.mem.eql(u8, s, "delete")) return .delete;
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

pub const BuildOptionInputDefinitionType = enum {
    string,
    boolean,
    string_list,
    radio,
    pick_list,
    multi_line,
    branch_filter,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .string => "string",
            .boolean => "boolean",
            .string_list => "stringList",
            .radio => "radio",
            .pick_list => "pickList",
            .multi_line => "multiLine",
            .branch_filter => "branchFilter",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "stringList")) return .string_list;
        if (std.mem.eql(u8, s, "radio")) return .radio;
        if (std.mem.eql(u8, s, "pickList")) return .pick_list;
        if (std.mem.eql(u8, s, "multiLine")) return .multi_line;
        if (std.mem.eql(u8, s, "branchFilter")) return .branch_filter;
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

pub const SupportedTriggerSupportedCapability = enum {
    unsupported,
    supported,
    required,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unsupported => "unsupported",
            .supported => "supported",
            .required => "required",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unsupported")) return .unsupported;
        if (std.mem.eql(u8, s, "supported")) return .supported;
        if (std.mem.eql(u8, s, "required")) return .required;
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

pub const SupportedTriggerType = enum {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .continuous_integration => "continuousIntegration",
            .batched_continuous_integration => "batchedContinuousIntegration",
            .schedule => "schedule",
            .gated_check_in => "gatedCheckIn",
            .batched_gated_check_in => "batchedGatedCheckIn",
            .pull_request => "pullRequest",
            .build_completion => "buildCompletion",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "batchedContinuousIntegration")) return .batched_continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "gatedCheckIn")) return .gated_check_in;
        if (std.mem.eql(u8, s, "batchedGatedCheckIn")) return .batched_gated_check_in;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
        if (std.mem.eql(u8, s, "buildCompletion")) return .build_completion;
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

pub const RepositoryWebhookType = enum {
    none,
    continuous_integration,
    batched_continuous_integration,
    schedule,
    gated_check_in,
    batched_gated_check_in,
    pull_request,
    build_completion,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .continuous_integration => "continuousIntegration",
            .batched_continuous_integration => "batchedContinuousIntegration",
            .schedule => "schedule",
            .gated_check_in => "gatedCheckIn",
            .batched_gated_check_in => "batchedGatedCheckIn",
            .pull_request => "pullRequest",
            .build_completion => "buildCompletion",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "batchedContinuousIntegration")) return .batched_continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "gatedCheckIn")) return .gated_check_in;
        if (std.mem.eql(u8, s, "batchedGatedCheckIn")) return .batched_gated_check_in;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
        if (std.mem.eql(u8, s, "buildCompletion")) return .build_completion;
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
