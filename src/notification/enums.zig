//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const NotificationEventFieldTypeSubscriptionFieldType = enum {
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
            .team_project => "teamProject",
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
        if (std.mem.eql(u8, s, "teamProject")) return .team_project;
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

pub const NotificationAdminSettingsDefaultGroupDeliveryPreference = enum {
    no_delivery,
    each_member,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .no_delivery => "noDelivery",
            .each_member => "eachMember",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "noDelivery")) return .no_delivery;
        if (std.mem.eql(u8, s, "eachMember")) return .each_member;
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

pub const NotificationAdminSettingsUpdateParametersDefaultGroupDeliveryPreference = enum {
    no_delivery,
    each_member,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .no_delivery => "noDelivery",
            .each_member => "eachMember",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "noDelivery")) return .no_delivery;
        if (std.mem.eql(u8, s, "eachMember")) return .each_member;
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

pub const NotificationSubscriberDeliveryPreference = enum {
    no_delivery,
    preferred_email_address,
    each_member,
    use_default,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .no_delivery => "noDelivery",
            .preferred_email_address => "preferredEmailAddress",
            .each_member => "eachMember",
            .use_default => "useDefault",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "noDelivery")) return .no_delivery;
        if (std.mem.eql(u8, s, "preferredEmailAddress")) return .preferred_email_address;
        if (std.mem.eql(u8, s, "eachMember")) return .each_member;
        if (std.mem.eql(u8, s, "useDefault")) return .use_default;
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

pub const NotificationSubscriberFlags = enum {
    none,
    delivery_preferences_editable,
    supports_preferred_email_address_delivery,
    supports_each_member_delivery,
    supports_no_delivery,
    is_user,
    is_group,
    is_team,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .delivery_preferences_editable => "deliveryPreferencesEditable",
            .supports_preferred_email_address_delivery => "supportsPreferredEmailAddressDelivery",
            .supports_each_member_delivery => "supportsEachMemberDelivery",
            .supports_no_delivery => "supportsNoDelivery",
            .is_user => "isUser",
            .is_group => "isGroup",
            .is_team => "isTeam",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "deliveryPreferencesEditable")) return .delivery_preferences_editable;
        if (std.mem.eql(u8, s, "supportsPreferredEmailAddressDelivery")) return .supports_preferred_email_address_delivery;
        if (std.mem.eql(u8, s, "supportsEachMemberDelivery")) return .supports_each_member_delivery;
        if (std.mem.eql(u8, s, "supportsNoDelivery")) return .supports_no_delivery;
        if (std.mem.eql(u8, s, "isUser")) return .is_user;
        if (std.mem.eql(u8, s, "isGroup")) return .is_group;
        if (std.mem.eql(u8, s, "isTeam")) return .is_team;
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

pub const NotificationSubscriberUpdateParametersDeliveryPreference = enum {
    no_delivery,
    preferred_email_address,
    each_member,
    use_default,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .no_delivery => "noDelivery",
            .preferred_email_address => "preferredEmailAddress",
            .each_member => "eachMember",
            .use_default => "useDefault",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "noDelivery")) return .no_delivery;
        if (std.mem.eql(u8, s, "preferredEmailAddress")) return .preferred_email_address;
        if (std.mem.eql(u8, s, "eachMember")) return .each_member;
        if (std.mem.eql(u8, s, "useDefault")) return .use_default;
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

pub const SubscriptionQueryConditionFlags = enum {
    none,
    group_subscription,
    contributed_subscription,
    can_opt_out,
    team_subscription,
    one_actor_matches,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .group_subscription => "groupSubscription",
            .contributed_subscription => "contributedSubscription",
            .can_opt_out => "canOptOut",
            .team_subscription => "teamSubscription",
            .one_actor_matches => "oneActorMatches",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "groupSubscription")) return .group_subscription;
        if (std.mem.eql(u8, s, "contributedSubscription")) return .contributed_subscription;
        if (std.mem.eql(u8, s, "canOptOut")) return .can_opt_out;
        if (std.mem.eql(u8, s, "teamSubscription")) return .team_subscription;
        if (std.mem.eql(u8, s, "oneActorMatches")) return .one_actor_matches;
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

pub const SubscriptionQueryQueryFlags = enum {
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

pub const NotificationSubscriptionFlags = enum {
    none,
    group_subscription,
    contributed_subscription,
    can_opt_out,
    team_subscription,
    one_actor_matches,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .group_subscription => "groupSubscription",
            .contributed_subscription => "contributedSubscription",
            .can_opt_out => "canOptOut",
            .team_subscription => "teamSubscription",
            .one_actor_matches => "oneActorMatches",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "groupSubscription")) return .group_subscription;
        if (std.mem.eql(u8, s, "contributedSubscription")) return .contributed_subscription;
        if (std.mem.eql(u8, s, "canOptOut")) return .can_opt_out;
        if (std.mem.eql(u8, s, "teamSubscription")) return .team_subscription;
        if (std.mem.eql(u8, s, "oneActorMatches")) return .one_actor_matches;
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

pub const NotificationSubscriptionPermissions = enum {
    none,
    view,
    edit,
    delete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .view => "view",
            .edit => "edit",
            .delete => "delete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "view")) return .view;
        if (std.mem.eql(u8, s, "edit")) return .edit;
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

pub const NotificationSubscriptionStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .jailed_by_notifications_volume => "jailedByNotificationsVolume",
            .pending_deletion => "pendingDeletion",
            .disabled_argument_exception => "disabledArgumentException",
            .disabled_project_invalid => "disabledProjectInvalid",
            .disabled_missing_permissions => "disabledMissingPermissions",
            .disabled_from_probation => "disabledFromProbation",
            .disabled_inactive_identity => "disabledInactiveIdentity",
            .disabled_message_queue_not_supported => "disabledMessageQueueNotSupported",
            .disabled_missing_identity => "disabledMissingIdentity",
            .disabled_invalid_role_expression => "disabledInvalidRoleExpression",
            .disabled_invalid_path_clause => "disabledInvalidPathClause",
            .disabled_as_duplicate_of_default => "disabledAsDuplicateOfDefault",
            .disabled_by_admin => "disabledByAdmin",
            .disabled => "disabled",
            .enabled => "enabled",
            .enabled_on_probation => "enabledOnProbation",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "jailedByNotificationsVolume")) return .jailed_by_notifications_volume;
        if (std.mem.eql(u8, s, "pendingDeletion")) return .pending_deletion;
        if (std.mem.eql(u8, s, "disabledArgumentException")) return .disabled_argument_exception;
        if (std.mem.eql(u8, s, "disabledProjectInvalid")) return .disabled_project_invalid;
        if (std.mem.eql(u8, s, "disabledMissingPermissions")) return .disabled_missing_permissions;
        if (std.mem.eql(u8, s, "disabledFromProbation")) return .disabled_from_probation;
        if (std.mem.eql(u8, s, "disabledInactiveIdentity")) return .disabled_inactive_identity;
        if (std.mem.eql(u8, s, "disabledMessageQueueNotSupported")) return .disabled_message_queue_not_supported;
        if (std.mem.eql(u8, s, "disabledMissingIdentity")) return .disabled_missing_identity;
        if (std.mem.eql(u8, s, "disabledInvalidRoleExpression")) return .disabled_invalid_role_expression;
        if (std.mem.eql(u8, s, "disabledInvalidPathClause")) return .disabled_invalid_path_clause;
        if (std.mem.eql(u8, s, "disabledAsDuplicateOfDefault")) return .disabled_as_duplicate_of_default;
        if (std.mem.eql(u8, s, "disabledByAdmin")) return .disabled_by_admin;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "enabledOnProbation")) return .enabled_on_probation;
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

pub const NotificationSubscriptionUpdateParametersStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .jailed_by_notifications_volume => "jailedByNotificationsVolume",
            .pending_deletion => "pendingDeletion",
            .disabled_argument_exception => "disabledArgumentException",
            .disabled_project_invalid => "disabledProjectInvalid",
            .disabled_missing_permissions => "disabledMissingPermissions",
            .disabled_from_probation => "disabledFromProbation",
            .disabled_inactive_identity => "disabledInactiveIdentity",
            .disabled_message_queue_not_supported => "disabledMessageQueueNotSupported",
            .disabled_missing_identity => "disabledMissingIdentity",
            .disabled_invalid_role_expression => "disabledInvalidRoleExpression",
            .disabled_invalid_path_clause => "disabledInvalidPathClause",
            .disabled_as_duplicate_of_default => "disabledAsDuplicateOfDefault",
            .disabled_by_admin => "disabledByAdmin",
            .disabled => "disabled",
            .enabled => "enabled",
            .enabled_on_probation => "enabledOnProbation",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "jailedByNotificationsVolume")) return .jailed_by_notifications_volume;
        if (std.mem.eql(u8, s, "pendingDeletion")) return .pending_deletion;
        if (std.mem.eql(u8, s, "disabledArgumentException")) return .disabled_argument_exception;
        if (std.mem.eql(u8, s, "disabledProjectInvalid")) return .disabled_project_invalid;
        if (std.mem.eql(u8, s, "disabledMissingPermissions")) return .disabled_missing_permissions;
        if (std.mem.eql(u8, s, "disabledFromProbation")) return .disabled_from_probation;
        if (std.mem.eql(u8, s, "disabledInactiveIdentity")) return .disabled_inactive_identity;
        if (std.mem.eql(u8, s, "disabledMessageQueueNotSupported")) return .disabled_message_queue_not_supported;
        if (std.mem.eql(u8, s, "disabledMissingIdentity")) return .disabled_missing_identity;
        if (std.mem.eql(u8, s, "disabledInvalidRoleExpression")) return .disabled_invalid_role_expression;
        if (std.mem.eql(u8, s, "disabledInvalidPathClause")) return .disabled_invalid_path_clause;
        if (std.mem.eql(u8, s, "disabledAsDuplicateOfDefault")) return .disabled_as_duplicate_of_default;
        if (std.mem.eql(u8, s, "disabledByAdmin")) return .disabled_by_admin;
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "enabledOnProbation")) return .enabled_on_probation;
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

pub const NotificationSubscriptionTemplateType = enum {
    user,
    team,
    both,
    none,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .user => "user",
            .team => "team",
            .both => "both",
            .none => "none",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "user")) return .user;
        if (std.mem.eql(u8, s, "team")) return .team;
        if (std.mem.eql(u8, s, "both")) return .both;
        if (std.mem.eql(u8, s, "none")) return .none;
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
