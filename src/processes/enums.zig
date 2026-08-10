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

pub const ProcessInfoCustomizationType = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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

pub const ProcessBehaviorCustomization = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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

pub const ProcessWorkItemTypeCustomization = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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

pub const PagePageType = union(enum) {
    custom,
    history,
    links,
    attachments,
    unrecognized: []const u8,

    const wire_names = .{
        .custom = "custom",
        .history = "history",
        .links = "links",
        .attachments = "attachments",
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

pub const WorkItemStateResultModelCustomizationType = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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

pub const ProcessWorkItemTypeFieldCustomization = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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

pub const ProcessWorkItemTypeFieldType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .string = "string",
        .integer = "integer",
        .date_time = "dateTime",
        .plain_text = "plainText",
        .html = "html",
        .tree_path = "treePath",
        .history = "history",
        .double = "double",
        .guid = "guid",
        .boolean = "boolean",
        .identity = "identity",
        .picklist_integer = "picklistInteger",
        .picklist_string = "picklistString",
        .picklist_double = "picklistDouble",
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

pub const RuleActionActionType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .make_required = "makeRequired",
        .make_read_only = "makeReadOnly",
        .set_default_value = "setDefaultValue",
        .set_default_from_clock = "setDefaultFromClock",
        .set_default_from_current_user = "setDefaultFromCurrentUser",
        .set_default_from_field = "setDefaultFromField",
        .copy_value = "copyValue",
        .copy_from_clock = "copyFromClock",
        .copy_from_current_user = "copyFromCurrentUser",
        .copy_from_field = "copyFromField",
        .set_value_to_empty = "setValueToEmpty",
        .copy_from_server_clock = "copyFromServerClock",
        .copy_from_server_current_user = "copyFromServerCurrentUser",
        .hide_target_field = "hideTargetField",
        .disallow_value = "disallowValue",
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

pub const RuleConditionConditionType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .when = "when",
        .when_not = "whenNot",
        .when_changed = "whenChanged",
        .when_not_changed = "whenNotChanged",
        .when_was = "whenWas",
        .when_state_changed_to = "whenStateChangedTo",
        .when_state_changed_from_and_to = "whenStateChangedFromAndTo",
        .when_work_item_is_created = "whenWorkItemIsCreated",
        .when_value_is_defined = "whenValueIsDefined",
        .when_value_is_not_defined = "whenValueIsNotDefined",
        .when_current_user_is_member_of_group = "whenCurrentUserIsMemberOfGroup",
        .when_current_user_is_not_member_of_group = "whenCurrentUserIsNotMemberOfGroup",
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

pub const ProcessRuleCustomizationType = union(enum) {
    system,
    inherited,
    custom,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .inherited = "inherited",
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
