//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ListRequestExpand = enum {
    none,
    projects,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .projects => "projects",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "projects")) return .projects;
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

pub const ProcessInfoCustomizationType = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const GetRequestExpand = enum {
    none,
    projects,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .projects => "projects",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "projects")) return .projects;
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

pub const ListRequestExpand1 = enum {
    none,
    fields,
    combined_fields,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .fields => "fields",
            .combined_fields => "combinedFields",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "combinedFields")) return .combined_fields;
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

pub const ProcessBehaviorCustomization = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const GetRequestExpand1 = enum {
    none,
    fields,
    combined_fields,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .fields => "fields",
            .combined_fields => "combinedFields",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "combinedFields")) return .combined_fields;
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

pub const ListRequestExpand2 = enum {
    none,
    states,
    behaviors,
    layout,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .states => "states",
            .behaviors => "behaviors",
            .layout => "layout",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "states")) return .states;
        if (std.mem.eql(u8, s, "behaviors")) return .behaviors;
        if (std.mem.eql(u8, s, "layout")) return .layout;
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

pub const ProcessWorkItemTypeCustomization = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const PagePageType = enum {
    custom,
    history,
    links,
    attachments,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .custom => "custom",
            .history => "history",
            .links => "links",
            .attachments => "attachments",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "history")) return .history;
        if (std.mem.eql(u8, s, "links")) return .links;
        if (std.mem.eql(u8, s, "attachments")) return .attachments;
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

pub const WorkItemStateResultModelCustomizationType = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const GetRequestExpand2 = enum {
    none,
    states,
    behaviors,
    layout,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .states => "states",
            .behaviors => "behaviors",
            .layout => "layout",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "states")) return .states;
        if (std.mem.eql(u8, s, "behaviors")) return .behaviors;
        if (std.mem.eql(u8, s, "layout")) return .layout;
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

pub const ProcessWorkItemTypeFieldCustomization = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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

pub const ProcessWorkItemTypeFieldType = enum {
    string,
    integer,
    date_time,
    plain_text,
    html,
    tree_path,
    history,
    double,
    guid,
    boolean,
    identity,
    picklist_integer,
    picklist_string,
    picklist_double,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .string => "string",
            .integer => "integer",
            .date_time => "dateTime",
            .plain_text => "plainText",
            .html => "html",
            .tree_path => "treePath",
            .history => "history",
            .double => "double",
            .guid => "guid",
            .boolean => "boolean",
            .identity => "identity",
            .picklist_integer => "picklistInteger",
            .picklist_string => "picklistString",
            .picklist_double => "picklistDouble",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "integer")) return .integer;
        if (std.mem.eql(u8, s, "dateTime")) return .date_time;
        if (std.mem.eql(u8, s, "plainText")) return .plain_text;
        if (std.mem.eql(u8, s, "html")) return .html;
        if (std.mem.eql(u8, s, "treePath")) return .tree_path;
        if (std.mem.eql(u8, s, "history")) return .history;
        if (std.mem.eql(u8, s, "double")) return .double;
        if (std.mem.eql(u8, s, "guid")) return .guid;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "identity")) return .identity;
        if (std.mem.eql(u8, s, "picklistInteger")) return .picklist_integer;
        if (std.mem.eql(u8, s, "picklistString")) return .picklist_string;
        if (std.mem.eql(u8, s, "picklistDouble")) return .picklist_double;
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

pub const GetRequestExpand3 = enum {
    none,
    allowed_values,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .allowed_values => "allowedValues",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "allowedValues")) return .allowed_values;
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

pub const RuleActionActionType = enum {
    make_required,
    make_read_only,
    set_default_value,
    set_default_from_clock,
    set_default_from_current_user,
    set_default_from_field,
    copy_value,
    copy_from_clock,
    copy_from_current_user,
    copy_from_field,
    set_value_to_empty,
    copy_from_server_clock,
    copy_from_server_current_user,
    hide_target_field,
    disallow_value,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .make_required => "makeRequired",
            .make_read_only => "makeReadOnly",
            .set_default_value => "setDefaultValue",
            .set_default_from_clock => "setDefaultFromClock",
            .set_default_from_current_user => "setDefaultFromCurrentUser",
            .set_default_from_field => "setDefaultFromField",
            .copy_value => "copyValue",
            .copy_from_clock => "copyFromClock",
            .copy_from_current_user => "copyFromCurrentUser",
            .copy_from_field => "copyFromField",
            .set_value_to_empty => "setValueToEmpty",
            .copy_from_server_clock => "copyFromServerClock",
            .copy_from_server_current_user => "copyFromServerCurrentUser",
            .hide_target_field => "hideTargetField",
            .disallow_value => "disallowValue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "makeRequired")) return .make_required;
        if (std.mem.eql(u8, s, "makeReadOnly")) return .make_read_only;
        if (std.mem.eql(u8, s, "setDefaultValue")) return .set_default_value;
        if (std.mem.eql(u8, s, "setDefaultFromClock")) return .set_default_from_clock;
        if (std.mem.eql(u8, s, "setDefaultFromCurrentUser")) return .set_default_from_current_user;
        if (std.mem.eql(u8, s, "setDefaultFromField")) return .set_default_from_field;
        if (std.mem.eql(u8, s, "copyValue")) return .copy_value;
        if (std.mem.eql(u8, s, "copyFromClock")) return .copy_from_clock;
        if (std.mem.eql(u8, s, "copyFromCurrentUser")) return .copy_from_current_user;
        if (std.mem.eql(u8, s, "copyFromField")) return .copy_from_field;
        if (std.mem.eql(u8, s, "setValueToEmpty")) return .set_value_to_empty;
        if (std.mem.eql(u8, s, "copyFromServerClock")) return .copy_from_server_clock;
        if (std.mem.eql(u8, s, "copyFromServerCurrentUser")) return .copy_from_server_current_user;
        if (std.mem.eql(u8, s, "hideTargetField")) return .hide_target_field;
        if (std.mem.eql(u8, s, "disallowValue")) return .disallow_value;
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

pub const RuleConditionConditionType = enum {
    when,
    when_not,
    when_changed,
    when_not_changed,
    when_was,
    when_state_changed_to,
    when_state_changed_from_and_to,
    when_work_item_is_created,
    when_value_is_defined,
    when_value_is_not_defined,
    when_current_user_is_member_of_group,
    when_current_user_is_not_member_of_group,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .when => "when",
            .when_not => "whenNot",
            .when_changed => "whenChanged",
            .when_not_changed => "whenNotChanged",
            .when_was => "whenWas",
            .when_state_changed_to => "whenStateChangedTo",
            .when_state_changed_from_and_to => "whenStateChangedFromAndTo",
            .when_work_item_is_created => "whenWorkItemIsCreated",
            .when_value_is_defined => "whenValueIsDefined",
            .when_value_is_not_defined => "whenValueIsNotDefined",
            .when_current_user_is_member_of_group => "whenCurrentUserIsMemberOfGroup",
            .when_current_user_is_not_member_of_group => "whenCurrentUserIsNotMemberOfGroup",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "when")) return .when;
        if (std.mem.eql(u8, s, "whenNot")) return .when_not;
        if (std.mem.eql(u8, s, "whenChanged")) return .when_changed;
        if (std.mem.eql(u8, s, "whenNotChanged")) return .when_not_changed;
        if (std.mem.eql(u8, s, "whenWas")) return .when_was;
        if (std.mem.eql(u8, s, "whenStateChangedTo")) return .when_state_changed_to;
        if (std.mem.eql(u8, s, "whenStateChangedFromAndTo")) return .when_state_changed_from_and_to;
        if (std.mem.eql(u8, s, "whenWorkItemIsCreated")) return .when_work_item_is_created;
        if (std.mem.eql(u8, s, "whenValueIsDefined")) return .when_value_is_defined;
        if (std.mem.eql(u8, s, "whenValueIsNotDefined")) return .when_value_is_not_defined;
        if (std.mem.eql(u8, s, "whenCurrentUserIsMemberOfGroup")) return .when_current_user_is_member_of_group;
        if (std.mem.eql(u8, s, "whenCurrentUserIsNotMemberOfGroup")) return .when_current_user_is_not_member_of_group;
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

pub const ProcessRuleCustomizationType = enum {
    system,
    inherited,
    custom,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .inherited => "inherited",
            .custom => "custom",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "inherited")) return .inherited;
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
