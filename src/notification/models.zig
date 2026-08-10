//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `INotificationDiagnosticLog` as returned by Azure DevOps.
pub const INotificationDiagnosticLogList = struct {
    count: ?i32 = null,
    value: ?[]const INotificationDiagnosticLog = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Abstraction interface for the diagnostic log. Primarily for deserialization.
pub const INotificationDiagnosticLog = struct {
    /// Identifier used for correlating to other diagnostics that may have been recorded elsewhere.
    activity_id: ?[]const u8 = null,
    /// Description of what subscription or notification job is being logged.
    description: ?[]const u8 = null,
    /// Time the log ended.
    end_time: ?[]const u8 = null,
    /// Unique instance identifier.
    id: ?[]const u8 = null,
    /// Type of information being logged.
    log_type: ?[]const u8 = null,
    /// List of log messages.
    messages: ?[]const NotificationDiagnosticLogMessage = null,
    /// Dictionary of log properties and settings for the job.
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// This identifier depends on the logType. For notification jobs, this will be the job Id. For subscription tracing, this will be a special root Guid with the subscription Id encoded.
    source: ?[]const u8 = null,
    /// Time the log started.
    start_time: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NotificationDiagnosticLogMessage = struct {
    /// Corresponds to .Net TraceLevel enumeration
    level: ?i32 = null,
    message: ?[]const u8 = null,
    time: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `NotificationEventType` as returned by Azure DevOps.
pub const NotificationEventTypeList = struct {
    count: ?i32 = null,
    value: ?[]const NotificationEventType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of an event type. It defines the fields, that can be used for filtering, for that event type.
pub const NotificationEventType = struct {
    category: ?NotificationEventTypeCategory = null,
    /// Gets or sets the color representing this event type. Example: rgb(128,245,211) or #fafafa
    color: ?[]const u8 = null,
    custom_subscriptions_allowed: ?bool = null,
    event_publisher: ?NotificationEventPublisher = null,
    fields: ?std.json.ArrayHashMap(NotificationEventField) = null,
    has_initiator: ?bool = null,
    /// Gets or sets the icon representing this event type. Can be a URL or a CSS class. Example: css://some-css-class
    icon: ?[]const u8 = null,
    /// Gets or sets the unique identifier of this event definition.
    id: ?[]const u8 = null,
    /// Gets or sets the name of this event definition.
    name: ?[]const u8 = null,
    roles: ?[]const NotificationEventRole = null,
    /// Gets or sets the scopes that this event type supports
    supported_scopes: ?[]const []const u8 = null,
    /// Gets or sets the rest end point to get this event type details (fields, fields types)
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a category. A category will be used by the UI to group event types
pub const NotificationEventTypeCategory = struct {
    /// Gets or sets the unique identifier of this category.
    id: ?[]const u8 = null,
    /// Gets or sets the friendly name of this category.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a notification event publisher.
pub const NotificationEventPublisher = struct {
    id: ?[]const u8 = null,
    subscription_management_info: ?SubscriptionManagement = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties needed to manage subscriptions, opt in and out of subscriptions.
pub const SubscriptionManagement = struct {
    service_instance_type: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a filterable field. A filterable field is a field in an event that can used to filter notifications for a certain event type.
pub const NotificationEventField = struct {
    field_type: ?NotificationEventFieldType = null,
    /// Gets or sets the unique identifier of this field.
    id: ?[]const u8 = null,
    /// Gets or sets the name of this field.
    name: ?[]const u8 = null,
    /// Gets or sets the path to the field in the event object. This path can be either Json Path or XPath, depending on if the event will be serialized into Json or XML
    path: ?[]const u8 = null,
    /// Gets or sets the scopes that this field supports. If not specified then the event type scopes apply.
    supported_scopes: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a field type. It describes the data type of a field, the operators it support and how to populate it in the UI
pub const NotificationEventFieldType = struct {
    /// Gets or sets the unique identifier of this field type.
    id: ?[]const u8 = null,
    operator_constraints: ?[]const OperatorConstraint = null,
    /// Gets or sets the list of operators that this type supports.
    operators: ?[]const NotificationEventFieldOperator = null,
    subscription_field_type: ?enums.NotificationEventFieldTypeSubscriptionFieldType = null,
    value: ?ValueDefinition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of an operator constraint. An operator constraint defines if some operator is available only for specific scope like a project scope.
pub const OperatorConstraint = struct {
    operator: ?[]const u8 = null,
    /// Gets or sets the list of scopes that this type supports.
    supported_scopes: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a field type. It includes a unique id for the operator and a localized string for display name
pub const NotificationEventFieldOperator = struct {
    /// Gets or sets the display name of an operator
    display_name: ?[]const u8 = null,
    /// Gets or sets the id of an operator
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of a field value definition. It has the information needed to retrieve the list of possible values for a certain field and how to handle that field values in the UI. This information includes what type of object this value represents, which property to use for UI display and which property to use for saving the subscription
pub const ValueDefinition = struct {
    /// Gets or sets the data source.
    data_source: ?[]const InputValue = null,
    /// Gets or sets the rest end point.
    end_point: ?[]const u8 = null,
    /// Gets or sets the result template.
    result_template: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about a single value for an input
pub const InputValue = struct {
    /// Any other data about this input
    data: ?std.json.ArrayHashMap(InputValueDatum) = null,
    /// The text to show for the display of this value
    display_value: ?[]const u8 = null,
    /// The value to store for this input
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputValueDatum = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of an event role. An event Role is used for role based subscription for example for a buildCompletedEvent, one role is request by field
pub const NotificationEventRole = struct {
    /// Gets or sets an Id for that role, this id is used by the event.
    id: ?[]const u8 = null,
    /// Gets or sets the Name for that role, this name is used for UI display.
    name: ?[]const u8 = null,
    /// Gets or sets whether this role can be a group or just an individual user
    supports_groups: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NotificationAdminSettings = struct {
    /// The default group delivery preference for groups in this collection
    default_group_delivery_preference: ?enums.NotificationAdminSettingsDefaultGroupDeliveryPreference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NotificationAdminSettingsUpdateParameters = struct {
    default_group_delivery_preference: ?enums.NotificationAdminSettingsUpdateParametersDefaultGroupDeliveryPreference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A subscriber is a user or group that has the potential to receive notifications.
pub const NotificationSubscriber = struct {
    /// Indicates how the subscriber should be notified by default.
    delivery_preference: ?enums.NotificationSubscriberDeliveryPreference = null,
    flags: ?enums.NotificationSubscriberFlags = null,
    /// Identifier of the subscriber.
    id: ?[]const u8 = null,
    /// Preferred email address of the subscriber. A null or empty value indicates no preferred email address has been set.
    preferred_email_address: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Updates to a subscriber. Typically used to change (or set) a preferred email address or default delivery preference.
pub const NotificationSubscriberUpdateParameters = struct {
    /// New delivery preference for the subscriber (indicates how the subscriber should be notified).
    delivery_preference: ?enums.NotificationSubscriberUpdateParametersDeliveryPreference = null,
    /// New preferred email address for the subscriber. Specify an empty string to clear the current address.
    preferred_email_address: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Notification subscriptions query input.
pub const SubscriptionQuery = struct {
    /// One or more conditions to query on. If more than 2 conditions are specified, the combined results of each condition is returned (i.e. conditions are logically OR'ed).
    conditions: ?[]const SubscriptionQueryCondition = null,
    /// Flags the refine the types of subscriptions that will be returned from the query.
    query_flags: ?enums.SubscriptionQueryQueryFlags = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Conditions a subscription must match to qualify for the query result set. Not all fields are required. A subscription must match all conditions specified in order to qualify for the result set.
pub const SubscriptionQueryCondition = struct {
    filter: ?ISubscriptionFilter = null,
    /// Flags to specify the type subscriptions to query for.
    flags: ?enums.SubscriptionQueryConditionFlags = null,
    /// Scope that matching subscriptions must have.
    scope: ?[]const u8 = null,
    /// ID of the subscriber (user or group) that matching subscriptions must be subscribed to.
    subscriber_id: ?[]const u8 = null,
    /// ID of the subscription to query for.
    subscription_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ISubscriptionFilter = struct {
    event_type: ?[]const u8 = null,
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `NotificationSubscription` as returned by Azure DevOps.
pub const NotificationSubscriptionList = struct {
    count: ?i32 = null,
    value: ?[]const NotificationSubscription = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A subscription defines criteria for matching events and how the subscription's subscriber should be notified about those events.
pub const NotificationSubscription = struct {
    links: ?ReferenceLinks = null,
    admin_settings: ?SubscriptionAdminSettings = null,
    channel: ?ISubscriptionChannel = null,
    /// Description of the subscription. Typically describes filter criteria which helps identity the subscription.
    description: ?[]const u8 = null,
    diagnostics: ?SubscriptionDiagnostics = null,
    /// Any extra properties like detailed description for different contexts, user/group contexts
    extended_properties: ?std.json.ArrayHashMap([]const u8) = null,
    filter: ?ISubscriptionFilter = null,
    /// Read-only indicators that further describe the subscription.
    flags: ?enums.NotificationSubscriptionFlags = null,
    /// Subscription identifier.
    id: ?[]const u8 = null,
    last_modified_by: ?IdentityRef = null,
    /// Date when the subscription was last modified. If the subscription has not been updated since it was created, this value will indicate when the subscription was created.
    modified_date: ?[]const u8 = null,
    /// The permissions the user have for this subscriptions.
    permissions: ?enums.NotificationSubscriptionPermissions = null,
    scope: ?SubscriptionScope = null,
    /// Status of the subscription. Typically indicates whether the subscription is enabled or not.
    status: ?enums.NotificationSubscriptionStatus = null,
    /// Message that provides more details about the status of the subscription.
    status_message: ?[]const u8 = null,
    subscriber: ?IdentityRef = null,
    /// REST API URL of the subscription.
    url: ?[]const u8 = null,
    user_settings: ?SubscriptionUserSettings = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The class to represent a collection of REST reference links.
pub const ReferenceLinks = struct {
    /// The readonly view of the links. Because Reference links are readonly, we only want to expose them as read only.
    links: ?std.json.ArrayHashMap(ReferenceLinksLink) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReferenceLinksLink = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Admin-managed settings for a group subscription.
pub const SubscriptionAdminSettings = struct {
    /// If true, members of the group subscribed to the associated subscription cannot opt (choose not to get notified)
    block_user_opt_out: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ISubscriptionChannel = struct {
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains all the diagnostics settings for a subscription.
pub const SubscriptionDiagnostics = struct {
    delivery_results: ?SubscriptionTracing = null,
    delivery_tracing: ?SubscriptionTracing = null,
    evaluation_tracing: ?SubscriptionTracing = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data controlling a single diagnostic setting for a subscription.
pub const SubscriptionTracing = struct {
    /// Indicates whether the diagnostic tracing is enabled or not.
    enabled: ?bool = null,
    /// Trace until the specified end date.
    end_date: ?[]const u8 = null,
    /// The maximum number of result details to trace.
    max_traced_entries: ?i32 = null,
    /// The date and time tracing started.
    start_date: ?[]const u8 = null,
    /// Trace until remaining count reaches 0.
    traced_entries: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IdentityRef = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph user referenced in the 'self' entry of the IdentityRef '_links' dictionary
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Deprecated - Available in the 'avatar' entry of the IdentityRef '_links' dictionary
    image_url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph membership state referenced in the 'membershipState' entry of the GraphUser '_links' dictionary
    inactive: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsAadUserType/Descriptor.IsAadGroupType)
    is_aad_identity: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsGroupType)
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    /// Deprecated - not in use in most preexisting implementations of ToIdentityRef
    profile_url: ?[]const u8 = null,
    /// Deprecated - use Domain+PrincipalName instead
    unique_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A resource, typically an account or project, in which events are published from.
pub const SubscriptionScope = struct {
    /// Required: This is the identity of the scope for the type.
    id: ?[]const u8 = null,
    /// Optional: The display name of the scope
    name: ?[]const u8 = null,
    /// Required: The event specific type of a scope.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// User-managed settings for a group subscription.
pub const SubscriptionUserSettings = struct {
    /// Indicates whether the user will receive notifications for the associated group subscription.
    opted_out: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for creating a new subscription. A subscription defines criteria for matching events and how the subscription's subscriber should be notified about those events.
pub const NotificationSubscriptionCreateParameters = struct {
    channel: ?ISubscriptionChannel = null,
    /// Brief description for the new subscription. Typically describes filter criteria which helps identity the subscription.
    description: ?[]const u8 = null,
    filter: ?ISubscriptionFilter = null,
    scope: ?SubscriptionScope = null,
    subscriber: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for updating an existing subscription. A subscription defines criteria for matching events and how the subscription's subscriber should be notified about those events. Note: only the fields to be updated should be set.
pub const NotificationSubscriptionUpdateParameters = struct {
    admin_settings: ?SubscriptionAdminSettings = null,
    channel: ?ISubscriptionChannel = null,
    /// Updated description for the subscription. Typically describes filter criteria which helps identity the subscription.
    description: ?[]const u8 = null,
    filter: ?ISubscriptionFilter = null,
    scope: ?SubscriptionScope = null,
    /// Updated status for the subscription. Typically used to enable or disable a subscription.
    status: ?enums.NotificationSubscriptionUpdateParametersStatus = null,
    /// Optional message that provides more details about the updated status.
    status_message: ?[]const u8 = null,
    user_settings: ?SubscriptionUserSettings = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `NotificationSubscriptionTemplate` as returned by Azure DevOps.
pub const NotificationSubscriptionTemplateList = struct {
    count: ?i32 = null,
    value: ?[]const NotificationSubscriptionTemplate = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NotificationSubscriptionTemplate = struct {
    description: ?[]const u8 = null,
    filter: ?ISubscriptionFilter = null,
    id: ?[]const u8 = null,
    notification_event_information: ?NotificationEventType = null,
    type: ?enums.NotificationSubscriptionTemplateType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters to update diagnostics settings for a subscription.
pub const UpdateSubscripitonDiagnosticsParameters = struct {
    delivery_results: ?UpdateSubscripitonTracingParameters = null,
    delivery_tracing: ?UpdateSubscripitonTracingParameters = null,
    evaluation_tracing: ?UpdateSubscripitonTracingParameters = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters to update a specific diagnostic setting.
pub const UpdateSubscripitonTracingParameters = struct {
    /// Indicates whether to enable to disable the diagnostic tracing.
    enabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
