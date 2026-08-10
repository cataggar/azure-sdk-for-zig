//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const NotificationEventFieldTypeSubscriptionFieldType = union(enum) {
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
    team_project,
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
        .team_project = "teamProject",
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

pub const NotificationAdminSettingsDefaultGroupDeliveryPreference = union(enum) {
    no_delivery,
    each_member,
    unrecognized: []const u8,

    const wire_names = .{
        .no_delivery = "noDelivery",
        .each_member = "eachMember",
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

pub const NotificationAdminSettingsUpdateParametersDefaultGroupDeliveryPreference = union(enum) {
    no_delivery,
    each_member,
    unrecognized: []const u8,

    const wire_names = .{
        .no_delivery = "noDelivery",
        .each_member = "eachMember",
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

pub const NotificationSubscriberDeliveryPreference = union(enum) {
    no_delivery,
    preferred_email_address,
    each_member,
    use_default,
    unrecognized: []const u8,

    const wire_names = .{
        .no_delivery = "noDelivery",
        .preferred_email_address = "preferredEmailAddress",
        .each_member = "eachMember",
        .use_default = "useDefault",
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

pub const NotificationSubscriberFlags = union(enum) {
    none,
    delivery_preferences_editable,
    supports_preferred_email_address_delivery,
    supports_each_member_delivery,
    supports_no_delivery,
    is_user,
    is_group,
    is_team,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .delivery_preferences_editable = "deliveryPreferencesEditable",
        .supports_preferred_email_address_delivery = "supportsPreferredEmailAddressDelivery",
        .supports_each_member_delivery = "supportsEachMemberDelivery",
        .supports_no_delivery = "supportsNoDelivery",
        .is_user = "isUser",
        .is_group = "isGroup",
        .is_team = "isTeam",
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

pub const NotificationSubscriberUpdateParametersDeliveryPreference = union(enum) {
    no_delivery,
    preferred_email_address,
    each_member,
    use_default,
    unrecognized: []const u8,

    const wire_names = .{
        .no_delivery = "noDelivery",
        .preferred_email_address = "preferredEmailAddress",
        .each_member = "eachMember",
        .use_default = "useDefault",
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

pub const SubscriptionQueryConditionFlags = union(enum) {
    none,
    group_subscription,
    contributed_subscription,
    can_opt_out,
    team_subscription,
    one_actor_matches,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .group_subscription = "groupSubscription",
        .contributed_subscription = "contributedSubscription",
        .can_opt_out = "canOptOut",
        .team_subscription = "teamSubscription",
        .one_actor_matches = "oneActorMatches",
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

pub const SubscriptionQueryQueryFlags = union(enum) {
    none,
    include_invalid_subscriptions,
    include_deleted_subscriptions,
    include_filter_details,
    always_return_basic_information,
    include_system_subscriptions,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .include_invalid_subscriptions = "includeInvalidSubscriptions",
        .include_deleted_subscriptions = "includeDeletedSubscriptions",
        .include_filter_details = "includeFilterDetails",
        .always_return_basic_information = "alwaysReturnBasicInformation",
        .include_system_subscriptions = "includeSystemSubscriptions",
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

pub const NotificationSubscriptionFlags = union(enum) {
    none,
    group_subscription,
    contributed_subscription,
    can_opt_out,
    team_subscription,
    one_actor_matches,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .group_subscription = "groupSubscription",
        .contributed_subscription = "contributedSubscription",
        .can_opt_out = "canOptOut",
        .team_subscription = "teamSubscription",
        .one_actor_matches = "oneActorMatches",
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

pub const NotificationSubscriptionPermissions = union(enum) {
    none,
    view,
    edit,
    delete,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .view = "view",
        .edit = "edit",
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

pub const NotificationSubscriptionStatus = union(enum) {
    jailed_by_notifications_volume,
    pending_deletion,
    disabled_argument_exception,
    disabled_project_invalid,
    disabled_missing_permissions,
    disabled_from_probation,
    disabled_inactive_identity,
    disabled_message_queue_not_supported,
    disabled_missing_identity,
    disabled_invalid_role_expression,
    disabled_invalid_path_clause,
    disabled_as_duplicate_of_default,
    disabled_by_admin,
    disabled,
    enabled,
    enabled_on_probation,
    unrecognized: []const u8,

    const wire_names = .{
        .jailed_by_notifications_volume = "jailedByNotificationsVolume",
        .pending_deletion = "pendingDeletion",
        .disabled_argument_exception = "disabledArgumentException",
        .disabled_project_invalid = "disabledProjectInvalid",
        .disabled_missing_permissions = "disabledMissingPermissions",
        .disabled_from_probation = "disabledFromProbation",
        .disabled_inactive_identity = "disabledInactiveIdentity",
        .disabled_message_queue_not_supported = "disabledMessageQueueNotSupported",
        .disabled_missing_identity = "disabledMissingIdentity",
        .disabled_invalid_role_expression = "disabledInvalidRoleExpression",
        .disabled_invalid_path_clause = "disabledInvalidPathClause",
        .disabled_as_duplicate_of_default = "disabledAsDuplicateOfDefault",
        .disabled_by_admin = "disabledByAdmin",
        .disabled = "disabled",
        .enabled = "enabled",
        .enabled_on_probation = "enabledOnProbation",
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

pub const ListRequestQueryFlags = enum {
    none,
    include_invalid_subscriptions,
    include_deleted_subscriptions,
    include_filter_details,
    always_return_basic_information,
    include_system_subscriptions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .include_invalid_subscriptions => "includeInvalidSubscriptions",
            .include_deleted_subscriptions => "includeDeletedSubscriptions",
            .include_filter_details => "includeFilterDetails",
            .always_return_basic_information => "alwaysReturnBasicInformation",
            .include_system_subscriptions => "includeSystemSubscriptions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "includeInvalidSubscriptions")) return .include_invalid_subscriptions;
        if (std.mem.eql(u8, s, "includeDeletedSubscriptions")) return .include_deleted_subscriptions;
        if (std.mem.eql(u8, s, "includeFilterDetails")) return .include_filter_details;
        if (std.mem.eql(u8, s, "alwaysReturnBasicInformation")) return .always_return_basic_information;
        if (std.mem.eql(u8, s, "includeSystemSubscriptions")) return .include_system_subscriptions;
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

pub const GetRequestQueryFlags = enum {
    none,
    include_invalid_subscriptions,
    include_deleted_subscriptions,
    include_filter_details,
    always_return_basic_information,
    include_system_subscriptions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .include_invalid_subscriptions => "includeInvalidSubscriptions",
            .include_deleted_subscriptions => "includeDeletedSubscriptions",
            .include_filter_details => "includeFilterDetails",
            .always_return_basic_information => "alwaysReturnBasicInformation",
            .include_system_subscriptions => "includeSystemSubscriptions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "includeInvalidSubscriptions")) return .include_invalid_subscriptions;
        if (std.mem.eql(u8, s, "includeDeletedSubscriptions")) return .include_deleted_subscriptions;
        if (std.mem.eql(u8, s, "includeFilterDetails")) return .include_filter_details;
        if (std.mem.eql(u8, s, "alwaysReturnBasicInformation")) return .always_return_basic_information;
        if (std.mem.eql(u8, s, "includeSystemSubscriptions")) return .include_system_subscriptions;
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

pub const NotificationSubscriptionUpdateParametersStatus = union(enum) {
    jailed_by_notifications_volume,
    pending_deletion,
    disabled_argument_exception,
    disabled_project_invalid,
    disabled_missing_permissions,
    disabled_from_probation,
    disabled_inactive_identity,
    disabled_message_queue_not_supported,
    disabled_missing_identity,
    disabled_invalid_role_expression,
    disabled_invalid_path_clause,
    disabled_as_duplicate_of_default,
    disabled_by_admin,
    disabled,
    enabled,
    enabled_on_probation,
    unrecognized: []const u8,

    const wire_names = .{
        .jailed_by_notifications_volume = "jailedByNotificationsVolume",
        .pending_deletion = "pendingDeletion",
        .disabled_argument_exception = "disabledArgumentException",
        .disabled_project_invalid = "disabledProjectInvalid",
        .disabled_missing_permissions = "disabledMissingPermissions",
        .disabled_from_probation = "disabledFromProbation",
        .disabled_inactive_identity = "disabledInactiveIdentity",
        .disabled_message_queue_not_supported = "disabledMessageQueueNotSupported",
        .disabled_missing_identity = "disabledMissingIdentity",
        .disabled_invalid_role_expression = "disabledInvalidRoleExpression",
        .disabled_invalid_path_clause = "disabledInvalidPathClause",
        .disabled_as_duplicate_of_default = "disabledAsDuplicateOfDefault",
        .disabled_by_admin = "disabledByAdmin",
        .disabled = "disabled",
        .enabled = "enabled",
        .enabled_on_probation = "enabledOnProbation",
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

pub const NotificationSubscriptionTemplateType = union(enum) {
    user,
    team,
    both,
    none,
    unrecognized: []const u8,

    const wire_names = .{
        .user = "user",
        .team = "team",
        .both = "both",
        .none = "none",
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
