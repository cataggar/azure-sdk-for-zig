//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

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

pub const ConsumerAuthenticationType = enum {
    none,
    o_auth,
    external,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .o_auth => "oAuth",
            .external => "external",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "oAuth")) return .o_auth;
        if (std.mem.eql(u8, s, "external")) return .external;
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

pub const SubscriptionStatus = enum {
    enabled,
    on_probation,
    disabled_by_user,
    disabled_by_system,
    disabled_by_inactive_identity,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .enabled => "enabled",
            .on_probation => "onProbation",
            .disabled_by_user => "disabledByUser",
            .disabled_by_system => "disabledBySystem",
            .disabled_by_inactive_identity => "disabledByInactiveIdentity",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "onProbation")) return .on_probation;
        if (std.mem.eql(u8, s, "disabledByUser")) return .disabled_by_user;
        if (std.mem.eql(u8, s, "disabledBySystem")) return .disabled_by_system;
        if (std.mem.eql(u8, s, "disabledByInactiveIdentity")) return .disabled_by_inactive_identity;
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

pub const NotificationResult = enum {
    pending,
    succeeded,
    failed,
    filtered,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .succeeded => "succeeded",
            .failed => "failed",
            .filtered => "filtered",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "filtered")) return .filtered;
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

pub const NotificationStatus = enum {
    queued,
    processing,
    request_in_progress,
    queued_for_retry,
    completed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .processing => "processing",
            .request_in_progress => "requestInProgress",
            .queued_for_retry => "queuedForRetry",
            .completed => "completed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "processing")) return .processing;
        if (std.mem.eql(u8, s, "requestInProgress")) return .request_in_progress;
        if (std.mem.eql(u8, s, "queuedForRetry")) return .queued_for_retry;
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

pub const NotificationsQueryResultType = enum {
    pending,
    succeeded,
    failed,
    filtered,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .succeeded => "succeeded",
            .failed => "failed",
            .filtered => "filtered",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "filtered")) return .filtered;
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

pub const NotificationsQueryStatus = enum {
    queued,
    processing,
    request_in_progress,
    queued_for_retry,
    completed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .processing => "processing",
            .request_in_progress => "requestInProgress",
            .queued_for_retry => "queuedForRetry",
            .completed => "completed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "processing")) return .processing;
        if (std.mem.eql(u8, s, "requestInProgress")) return .request_in_progress;
        if (std.mem.eql(u8, s, "queuedForRetry")) return .queued_for_retry;
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

pub const NotificationResultsSummaryDetailResult = enum {
    pending,
    succeeded,
    failed,
    filtered,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .succeeded => "succeeded",
            .failed => "failed",
            .filtered => "filtered",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "filtered")) return .filtered;
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

pub const ListRequestStatus = enum {
    queued,
    processing,
    request_in_progress,
    queued_for_retry,
    completed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .processing => "processing",
            .request_in_progress => "requestInProgress",
            .queued_for_retry => "queuedForRetry",
            .completed => "completed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "processing")) return .processing;
        if (std.mem.eql(u8, s, "requestInProgress")) return .request_in_progress;
        if (std.mem.eql(u8, s, "queuedForRetry")) return .queued_for_retry;
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

pub const ListRequestResult = enum {
    pending,
    succeeded,
    failed,
    filtered,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .succeeded => "succeeded",
            .failed => "failed",
            .filtered => "filtered",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "filtered")) return .filtered;
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

pub const InputFilterConditionOperator = enum {
    equals,
    not_equals,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .equals => "equals",
            .not_equals => "notEquals",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "equals")) return .equals;
        if (std.mem.eql(u8, s, "notEquals")) return .not_equals;
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
