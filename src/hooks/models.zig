//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Defines the data contract of a consumer.
pub const Consumer = struct {
    links: ?ReferenceLinks = null,
    /// Gets this consumer's actions.
    actions: ?[]const ConsumerAction = null,
    /// Gets or sets this consumer's authentication type.
    authentication_type: ?enums.ConsumerAuthenticationType = null,
    /// Gets or sets this consumer's localized description.
    description: ?[]const u8 = null,
    external_configuration: ?ExternalConfigurationDescriptor = null,
    /// Gets or sets this consumer's identifier.
    id: ?[]const u8 = null,
    /// Gets or sets this consumer's image URL, if any.
    image_url: ?[]const u8 = null,
    /// Gets or sets this consumer's information URL, if any.
    information_url: ?[]const u8 = null,
    /// Gets or sets this consumer's input descriptors.
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets or sets this consumer's localized name.
    name: ?[]const u8 = null,
    /// The url for this resource
    url: ?[]const u8 = null,

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

/// Defines the data contract of a consumer action.
pub const ConsumerAction = struct {
    links: ?ReferenceLinks = null,
    /// Gets or sets the flag indicating if resource version can be overridden when creating or editing a subscription.
    allow_resource_version_override: ?bool = null,
    /// Gets or sets the identifier of the consumer to which this action belongs.
    consumer_id: ?[]const u8 = null,
    /// Gets or sets this action's localized description.
    description: ?[]const u8 = null,
    /// Gets or sets this action's identifier.
    id: ?[]const u8 = null,
    /// Gets or sets this action's input descriptors.
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets or sets this action's localized name.
    name: ?[]const u8 = null,
    /// Gets or sets this action's supported event identifiers.
    supported_event_types: ?[]const []const u8 = null,
    /// Gets or sets this action's supported resource versions.
    supported_resource_versions: ?std.json.ArrayHashMap([]const []const u8) = null,
    /// The url for this resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Describes an input for subscriptions.
pub const InputDescriptor = struct {
    /// The ids of all inputs that the value of this input is dependent on.
    dependency_input_ids: ?[]const []const u8 = null,
    /// Description of what this input is used for
    description: ?[]const u8 = null,
    /// The group localized name to which this input belongs and can be shown as a header for the container that will include all the inputs in the group.
    group_name: ?[]const u8 = null,
    /// If true, the value information for this input is dynamic and should be fetched when the value of dependency inputs change.
    has_dynamic_value_information: ?bool = null,
    /// Identifier for the subscription input
    id: ?[]const u8 = null,
    /// Mode in which the value of this input should be entered
    input_mode: ?enums.InputDescriptorInputMode = null,
    /// Gets whether this input is confidential, such as for a password or application key
    is_confidential: ?bool = null,
    /// Localized name which can be shown as a label for the subscription input
    name: ?[]const u8 = null,
    /// Custom properties for the input which can be used by the service provider
    properties: ?std.json.ArrayHashMap(InputDescriptorProperty) = null,
    /// Underlying data type for the input value. When this value is specified, InputMode, Validation and Values are optional.
    type: ?[]const u8 = null,
    /// Gets whether this input is included in the default generated action description.
    use_in_default_description: ?bool = null,
    validation: ?InputValidation = null,
    /// A hint for input value. It can be used in the UI as the input placeholder.
    value_hint: ?[]const u8 = null,
    values: ?InputValues = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputDescriptorProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes what values are valid for a subscription input
pub const InputValidation = struct {
    /// Gets or sets the data type to validate.
    data_type: ?enums.InputValidationDataType = null,
    /// Gets or sets if this is a required field.
    is_required: ?bool = null,
    /// Gets or sets the maximum length of this descriptor.
    max_length: ?i32 = null,
    /// Gets or sets the minimum value for this descriptor.
    max_value: ?[]const u8 = null,
    /// Gets or sets the minimum length of this descriptor.
    min_length: ?i32 = null,
    /// Gets or sets the minimum value for this descriptor.
    min_value: ?[]const u8 = null,
    /// Gets or sets the pattern to validate.
    pattern: ?[]const u8 = null,
    /// Gets or sets the error on pattern mismatch.
    pattern_mismatch_error_message: ?[]const u8 = null,
    /// Gets or sets the warning on pattern mismatch.
    pattern_mismatch_warning_message: ?[]const u8 = null,
    /// Gets or sets the pattern to validate.
    warning_pattern: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about the possible/allowed values for a given subscription input
pub const InputValues = struct {
    /// The default value to use for this input
    default_value: ?[]const u8 = null,
    @"error": ?InputValuesError = null,
    /// The id of the input
    input_id: ?[]const u8 = null,
    /// Should this input be disabled
    is_disabled: ?bool = null,
    /// Should the value be restricted to one of the values in the PossibleValues (True) or are the values in PossibleValues just a suggestion (False)
    is_limited_to_possible_values: ?bool = null,
    /// Should this input be made read-only
    is_read_only: ?bool = null,
    /// Possible values that this input can take
    possible_values: ?[]const InputValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Error information related to a subscription input value.
pub const InputValuesError = struct {
    /// The error message.
    message: ?[]const u8 = null,

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

/// Describes how to configure a subscription that is managed externally.
pub const ExternalConfigurationDescriptor = struct {
    /// Url of the site to create this type of subscription.
    create_subscription_url: ?[]const u8 = null,
    /// The name of an input property that contains the URL to edit a subscription.
    edit_subscription_property_name: ?[]const u8 = null,
    /// True if the external configuration applies only to hosted.
    hosted_only: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a query for service hook notifications.
pub const NotificationsQuery = struct {
    /// The subscriptions associated with the notifications returned from the query
    associated_subscriptions: ?[]const Subscription = null,
    /// If true, we will return all notification history for the query provided; otherwise, the summary is returned.
    include_details: ?bool = null,
    /// Optional maximum date at which the notification was created
    max_created_date: ?[]const u8 = null,
    /// Optional maximum number of overall results to include
    max_results: ?i32 = null,
    /// Optional maximum number of results for each subscription. Only takes effect when a list of subscription ids is supplied in the query.
    max_results_per_subscription: ?i32 = null,
    /// Optional minimum date at which the notification was created
    min_created_date: ?[]const u8 = null,
    /// Optional publisher id to restrict the results to
    publisher_id: ?[]const u8 = null,
    /// Results from the query
    results: ?[]const Notification = null,
    /// Optional notification result type to filter results to
    result_type: ?enums.NotificationsQueryResultType = null,
    /// Optional notification status to filter results to
    status: ?enums.NotificationsQueryStatus = null,
    /// Optional list of subscription ids to restrict the results to
    subscription_ids: ?[]const []const u8 = null,
    /// Summary of notifications - the count of each result type (success, fail, ..).
    summary: ?[]const NotificationSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates an event subscription.
pub const Subscription = struct {
    links: ?ReferenceLinks = null,
    action_description: ?[]const u8 = null,
    consumer_action_id: ?[]const u8 = null,
    consumer_id: ?[]const u8 = null,
    /// Consumer input values
    consumer_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    created_by: ?IdentityRef = null,
    created_date: ?[]const u8 = null,
    event_description: ?[]const u8 = null,
    event_type: ?[]const u8 = null,
    id: ?[]const u8 = null,
    last_probation_retry_date: ?[]const u8 = null,
    /// Date of the last successful notification delivery attempt.
    last_successful_attempt_date: ?[]const u8 = null,
    modified_by: ?IdentityRef = null,
    modified_date: ?[]const u8 = null,
    probation_retries: ?[]const u8 = null,
    publisher_id: ?[]const u8 = null,
    /// Publisher input values
    publisher_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    resource_version: ?[]const u8 = null,
    status: ?enums.SubscriptionStatus = null,
    subscriber: ?IdentityRef = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
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

/// Defines the data contract of the result of processing an event for a subscription.
pub const Notification = struct {
    /// Gets or sets date and time that this result was created.
    created_date: ?[]const u8 = null,
    details: ?NotificationDetails = null,
    /// The event id associated with this notification
    event_id: ?[]const u8 = null,
    /// The notification id
    id: ?i64 = null,
    /// Gets or sets date and time that this result was last modified.
    modified_date: ?[]const u8 = null,
    /// Result of the notification
    result: ?enums.NotificationResult = null,
    /// Status of the notification
    status: ?enums.NotificationStatus = null,
    /// The subscriber Id associated with this notification. This is the last identity who touched in the subscription. In case of test notifications it can be the tester if the subscription is not created yet.
    subscriber_id: ?[]const u8 = null,
    /// The subscription id associated with this notification
    subscription_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the data contract of notification details.
pub const NotificationDetails = struct {
    /// Gets or sets the time that this notification was completed (response received from the consumer)
    completed_date: ?[]const u8 = null,
    /// Gets or sets this notification detail's consumer action identifier.
    consumer_action_id: ?[]const u8 = null,
    /// Gets or sets this notification detail's consumer identifier.
    consumer_id: ?[]const u8 = null,
    /// Gets or sets this notification detail's consumer inputs.
    consumer_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the time that this notification was dequeued for processing
    dequeued_date: ?[]const u8 = null,
    /// Gets or sets this notification detail's error detail.
    error_detail: ?[]const u8 = null,
    /// Gets or sets this notification detail's error message.
    error_message: ?[]const u8 = null,
    event: ?Event = null,
    /// Gets or sets this notification detail's event type.
    event_type: ?[]const u8 = null,
    /// Gets or sets the next delivery retry time for this notification
    next_retry_time: ?[]const u8 = null,
    /// Gets or sets the time that this notification was finished processing (just before the request is sent to the consumer)
    processed_date: ?[]const u8 = null,
    /// Gets or sets this notification detail's publisher identifier.
    publisher_id: ?[]const u8 = null,
    /// Gets or sets this notification detail's publisher inputs.
    publisher_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the time that this notification was queued (created)
    queued_date: ?[]const u8 = null,
    /// Gets or sets this notification detail's request.
    request: ?[]const u8 = null,
    /// Number of requests attempted to be sent to the consumer
    request_attempts: ?i32 = null,
    /// Duration of the request to the consumer in seconds
    request_duration: ?f64 = null,
    /// Gets or sets this notification detail's response.
    response: ?[]const u8 = null,
    /// Number of delivery retries attempted for this notification
    retry_count: ?i16 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the properties of an event.
pub const Event = struct {
    /// Gets or sets the UTC-based date and time that this event was created.
    created_date: ?[]const u8 = null,
    detailed_message: ?FormattedEventMessage = null,
    /// Gets or sets the type of this event.
    event_type: ?[]const u8 = null,
    /// Gets or sets the unique identifier of this event.
    id: ?[]const u8 = null,
    message: ?FormattedEventMessage = null,
    /// Gets or sets the identifier of the publisher that raised this event.
    publisher_id: ?[]const u8 = null,
    /// Gets or sets the data associated with this event.
    resource: ?EventResource = null,
    /// Gets or sets the resource containers.
    resource_containers: ?std.json.ArrayHashMap(ResourceContainer) = null,
    /// Gets or sets the version of the data associated with this event.
    resource_version: ?[]const u8 = null,
    session_token: ?SessionToken = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Provides different formats of an event message
pub const FormattedEventMessage = struct {
    /// Gets or sets the html format of the message
    html: ?[]const u8 = null,
    /// Gets or sets the markdown format of the message
    markdown: ?[]const u8 = null,
    /// Gets or sets the raw text of the message
    text: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const EventResource = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The base class for all resource containers, i.e. Account, Collection, Project
pub const ResourceContainer = struct {
    /// Gets or sets the container's base URL, i.e. the URL of the host (collection, application, or deployment) containing the container resource.
    base_url: ?[]const u8 = null,
    /// Gets or sets the container's specific Id.
    id: ?[]const u8 = null,
    /// Gets or sets the container's name.
    name: ?[]const u8 = null,
    /// Gets or sets the container's REST API URL.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a session token to be attached in Events for Consumer actions that need it.
pub const SessionToken = struct {
    /// The error message in case of error
    @"error": ?[]const u8 = null,
    /// The access token
    token: ?[]const u8 = null,
    /// The expiration date in UTC
    valid_to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of the notifications for a subscription.
pub const NotificationSummary = struct {
    /// The notification results for this particular subscription.
    results: ?[]const NotificationResultsSummaryDetail = null,
    /// The subscription id associated with this notification
    subscription_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of a particular result and count.
pub const NotificationResultsSummaryDetail = struct {
    /// Count of notification sent out with a matching result.
    notification_count: ?i32 = null,
    /// Result of the notification
    result: ?enums.NotificationResultsSummaryDetailResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the data contract of an event publisher.
pub const Publisher = struct {
    links: ?ReferenceLinks = null,
    /// Gets this publisher's localized description.
    description: ?[]const u8 = null,
    /// Gets this publisher's identifier.
    id: ?[]const u8 = null,
    /// Publisher-specific inputs
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets this publisher's localized name.
    name: ?[]const u8 = null,
    /// The service instance type of the first party publisher.
    service_instance_type: ?[]const u8 = null,
    /// Gets this publisher's supported event types.
    supported_events: ?[]const EventTypeDescriptor = null,
    /// The url for this resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Describes a type of event
pub const EventTypeDescriptor = struct {
    /// A localized description of the event type
    description: ?[]const u8 = null,
    /// A unique id for the event type
    id: ?[]const u8 = null,
    /// Event-specific inputs
    input_descriptors: ?[]const InputDescriptor = null,
    /// A localized friendly name for the event type
    name: ?[]const u8 = null,
    /// A unique id for the publisher of this event type
    publisher_id: ?[]const u8 = null,
    /// Supported versions for the event's resource payloads.
    supported_resource_versions: ?[]const []const u8 = null,
    /// The url for this resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputValuesQuery = struct {
    current_values: ?std.json.ArrayHashMap([]const u8) = null,
    /// The input values to return on input, and the result from the consumer on output.
    input_values: ?[]const InputValues = null,
    /// Subscription containing information about the publisher/consumer and the current input values
    resource: ?InputValuesQueryResource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputValuesQueryResource = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a query for service hook publishers.
pub const PublishersQuery = struct {
    /// Optional list of publisher ids to restrict the results to
    publisher_ids: ?[]const []const u8 = null,
    /// Filter for publisher inputs
    publisher_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Results from the query
    results: ?[]const Publisher = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a query for service hook subscriptions.
pub const SubscriptionsQuery = struct {
    /// Optional consumer action id to restrict the results to (null for any)
    consumer_action_id: ?[]const u8 = null,
    /// Optional consumer id to restrict the results to (null for any)
    consumer_id: ?[]const u8 = null,
    /// Filter for subscription consumer inputs
    consumer_input_filters: ?[]const InputFilter = null,
    /// Optional event type id to restrict the results to (null for any)
    event_type: ?[]const u8 = null,
    /// Optional publisher id to restrict the results to (null for any)
    publisher_id: ?[]const u8 = null,
    /// Filter for subscription publisher inputs
    publisher_input_filters: ?[]const InputFilter = null,
    /// Results from the query
    results: ?[]const Subscription = null,
    /// Optional subscriber filter.
    subscriber_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a filter for subscription inputs. The filter matches a set of inputs if any (one or more) of the groups evaluates to true.
pub const InputFilter = struct {
    /// Groups of input filter expressions. This filter matches a set of inputs if any (one or more) of the groups evaluates to true.
    conditions: ?[]const InputFilterCondition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An expression which can be applied to filter a list of subscription inputs
pub const InputFilterCondition = struct {
    /// Whether or not to do a case sensitive match
    case_sensitive: ?bool = null,
    /// The Id of the input to filter on
    input_id: ?[]const u8 = null,
    /// The 'expected' input value to compare with the actual input value
    input_value: ?[]const u8 = null,
    /// The operator applied between the expected and actual input value
    operator: ?enums.InputFilterConditionOperator = null,

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
