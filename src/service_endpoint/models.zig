//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Represents an endpoint which may be used by an orchestration job.
pub const ServiceEndpoint = struct {
    administrators_group: ?IdentityRef = null,
    authorization: ?EndpointAuthorization = null,
    created_by: ?IdentityRef = null,
    /// Gets or sets the date, when the Service endpoint has been created.
    creation_date: ?[]const u8 = null,
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the description of endpoint.
    description: ?[]const u8 = null,
    /// This is a deprecated field.
    group_scope_id: ?[]const u8 = null,
    /// Gets or sets the identifier of this endpoint.
    id: ?[]const u8 = null,
    /// Whether service endpoint is disabled or not.
    is_disabled: ?bool = null,
    /// Indicates whether service endpoint is outdated or not.
    is_outdated: ?bool = null,
    /// EndPoint state indicator
    is_ready: ?bool = null,
    /// Indicates whether service endpoint is shared with other projects or not.
    is_shared: ?bool = null,
    /// Gets or sets the date, when the Service endpoint has been modified.
    modification_date: ?[]const u8 = null,
    modified_by: ?IdentityRef = null,
    /// Gets the project-specific friendly name of the endpoint, as defined in the name field of ServiceEndpointProjectReferences.
    name: ?[]const u8 = null,
    operation_status: ?JObject = null,
    /// Owner of the endpoint Supported values are 'library', 'agentcloud'
    owner: ?[]const u8 = null,
    readers_group: ?IdentityRef = null,
    /// All other project references where the service endpoint is shared.
    service_endpoint_project_references: ?[]const ServiceEndpointProjectReference = null,
    /// Service Tree ID
    service_management_reference: ?[]const u8 = null,
    /// Gets or sets the type of the endpoint.
    type: ?[]const u8 = null,
    /// Gets or sets the url of the endpoint.
    url: ?[]const u8 = null,

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

/// Represents the authorization used for service endpoint.
pub const EndpointAuthorization = struct {
    /// Gets or sets the parameters for the selected authorization scheme.
    parameters: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the scheme used for service endpoint authentication.
    scheme: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a JSON object.
pub const JObject = struct {
    item: ?JToken = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an abstract JSON token.
pub const JToken = struct {
    first: ?*const JToken = null,
    /// Gets a value indicating whether this token has child tokens.
    has_values: ?bool = null,
    item: ?*const JToken = null,
    last: ?*const JToken = null,
    next: ?*const JToken = null,
    /// Gets or sets the parent.
    parent: ?[]const u8 = null,
    /// Gets the path of the JSON token.
    path: ?[]const u8 = null,
    previous: ?*const JToken = null,
    root: ?*const JToken = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServiceEndpointProjectReference = struct {
    /// Gets or sets description of the service endpoint.
    description: ?[]const u8 = null,
    /// Gets or sets name of the service endpoint.
    name: ?[]const u8 = null,
    project_reference: ?ProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProjectReference = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ServiceEndpoint` as returned by Azure DevOps.
pub const ServiceEndpointList = struct {
    count: ?i32 = null,
    value: ?[]const ServiceEndpoint = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specify the properties for refreshing the endpoint authentication object being queried
pub const RefreshAuthenticationParameters = struct {
    /// EndpointId which needs new authentication params
    endpoint_id: ?[]const u8 = null,
    /// Scope of the token requested. For GitHub marketplace apps, scope contains repository Ids
    scope: ?[]const i32 = null,
    /// The requested endpoint authentication should be valid for _ minutes. Authentication params will not be refreshed if the token contained in endpoint already has active token.
    token_validity_in_minutes: ?i16 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ServiceEndpointType` as returned by Azure DevOps.
pub const ServiceEndpointTypeList = struct {
    count: ?i32 = null,
    value: ?[]const ServiceEndpointType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents type of the service endpoint.
pub const ServiceEndpointType = struct {
    /// Authentication scheme of service endpoint type.
    authentication_schemes: ?[]const ServiceEndpointAuthenticationScheme = null,
    /// Data sources of service endpoint type.
    data_sources: ?[]const DataSource = null,
    /// Dependency data of service endpoint type.
    dependency_data: ?[]const DependencyData = null,
    /// Gets or sets the description of service endpoint type.
    description: ?[]const u8 = null,
    /// Gets or sets the display name of service endpoint type.
    display_name: ?[]const u8 = null,
    endpoint_url: ?EndpointUrl = null,
    help_link: ?HelpLink = null,
    /// Gets or sets the help text shown at the endpoint create dialog.
    help_mark_down: ?[]const u8 = null,
    /// Gets or sets the icon url of service endpoint type.
    icon_url: ?[]const u8 = null,
    /// Input descriptor of service endpoint type.
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets or sets visibility parameter for the list of endpoint types.
    is_hidden: ?bool = null,
    /// Gets or sets the name of service endpoint type.
    name: ?[]const u8 = null,
    /// Trusted hosts of a service endpoint type.
    trusted_hosts: ?[]const []const u8 = null,
    /// Gets or sets the ui contribution id of service endpoint type.
    ui_contribution_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the authentication scheme used to authenticate the endpoint.
pub const ServiceEndpointAuthenticationScheme = struct {
    /// Gets or sets the authorization headers of service endpoint authentication scheme.
    authorization_headers: ?[]const AuthorizationHeader = null,
    /// Gets or sets the Authorization url required to authenticate using OAuth2
    authorization_url: ?[]const u8 = null,
    /// Gets or sets the certificates of service endpoint authentication scheme.
    client_certificates: ?[]const ClientCertificate = null,
    /// Gets or sets the data source bindings of the endpoint.
    data_source_bindings: ?[]const DataSourceBinding = null,
    /// Gets or sets the display name for the service endpoint authentication scheme.
    display_name: ?[]const u8 = null,
    /// Gets or sets the input descriptors for the service endpoint authentication scheme.
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets or sets the properties of service endpoint authentication scheme.
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets whether this auth scheme requires OAuth2 configuration or not.
    requires_o_auth2_configuration: ?bool = null,
    /// Gets or sets the scheme for service endpoint authentication.
    scheme: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the header of the REST request.
pub const AuthorizationHeader = struct {
    /// Gets or sets the name of authorization header.
    name: ?[]const u8 = null,
    /// Gets or sets the value of authorization header.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specifies the client certificate to be used for the endpoint request.
pub const ClientCertificate = struct {
    /// Gets or sets the value of client certificate.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the data source binding of the endpoint.
pub const DataSourceBinding = struct {
    /// Pagination format supported by this data source(ContinuationToken/SkipTop).
    callback_context_template: ?[]const u8 = null,
    /// Subsequent calls needed?
    callback_required_template: ?[]const u8 = null,
    /// Gets or sets the name of the data source.
    data_source_name: ?[]const u8 = null,
    /// Gets or sets the endpoint Id.
    endpoint_id: ?[]const u8 = null,
    /// Gets or sets the url of the service endpoint.
    endpoint_url: ?[]const u8 = null,
    /// Gets or sets the authorization headers.
    headers: ?[]const AuthorizationHeader = null,
    /// Defines the initial value of the query params
    initial_context_template: ?[]const u8 = null,
    /// Gets or sets the parameters for the data source.
    parameters: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets http request body
    request_content: ?[]const u8 = null,
    /// Gets or sets http request verb
    request_verb: ?[]const u8 = null,
    /// Gets or sets the result selector.
    result_selector: ?[]const u8 = null,
    /// Gets or sets the result template.
    result_template: ?[]const u8 = null,
    /// Gets or sets the target of the data source.
    target: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
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

/// Specifies the data sources for this endpoint.
pub const DataSource = struct {
    authentication_scheme: ?AuthenticationSchemeReference = null,
    /// Gets or sets the pagination format supported by this data source(ContinuationToken/SkipTop).
    callback_context_template: ?[]const u8 = null,
    /// Gets or sets the template to check if subsequent call is needed.
    callback_required_template: ?[]const u8 = null,
    /// Gets or sets the endpoint url of the data source.
    endpoint_url: ?[]const u8 = null,
    /// Gets or sets the authorization headers of the request.
    headers: ?[]const AuthorizationHeader = null,
    /// Gets or sets the initial value of the query params.
    initial_context_template: ?[]const u8 = null,
    /// Gets or sets the name of the data source.
    name: ?[]const u8 = null,
    /// Gets or sets the request content of the endpoint request.
    request_content: ?[]const u8 = null,
    /// Gets or sets the request method of the endpoint request.
    request_verb: ?[]const u8 = null,
    /// Gets or sets the resource url of the endpoint request.
    resource_url: ?[]const u8 = null,
    /// Gets or sets the result selector to filter the response of the endpoint request.
    result_selector: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specifies the authentication scheme to be used for authentication.
pub const AuthenticationSchemeReference = struct {
    /// Gets or sets the key and value of the fields used for authentication.
    inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the type of authentication scheme of an endpoint.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the dependency data for the endpoint inputs.
pub const DependencyData = struct {
    /// Gets or sets the category of dependency data.
    input: ?[]const u8 = null,
    /// Gets or sets the key-value pair to specify properties and their values.
    map: ?[]const DependencyDataMap = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DependencyDataMap = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents url of the service endpoint.
pub const EndpointUrl = struct {
    depends_on: ?DependsOn = null,
    /// Gets or sets the display name of service endpoint url.
    display_name: ?[]const u8 = null,
    /// Gets or sets the format of the url.
    format: ?[]const u8 = null,
    /// Gets or sets the help text of service endpoint url.
    help_text: ?[]const u8 = null,
    /// Gets or sets the visibility of service endpoint url.
    is_visible: ?[]const u8 = null,
    /// Gets or sets the value of service endpoint url.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the inputs on which any given input is dependent.
pub const DependsOn = struct {
    /// Gets or sets the ID of the field on which URL's value is dependent.
    input: ?[]const u8 = null,
    /// Gets or sets key-value pair containing other's field value and corresponding url value.
    map: ?[]const DependencyBinding = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the details of the input on which a given input is dependent.
pub const DependencyBinding = struct {
    /// Gets or sets the value of the field on which url is dependent.
    key: ?[]const u8 = null,
    /// Gets or sets the corresponding value of url.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specifies the public url of the help documentation.
pub const HelpLink = struct {
    /// Gets or sets the help text.
    text: ?[]const u8 = null,
    /// Gets or sets the public url of the help documentation.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ServiceEndpointExecutionRecord` as returned by Azure DevOps.
pub const ServiceEndpointExecutionRecordList = struct {
    count: ?i32 = null,
    value: ?[]const ServiceEndpointExecutionRecord = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the details of service endpoint execution.
pub const ServiceEndpointExecutionRecord = struct {
    data: ?ServiceEndpointExecutionData = null,
    /// Gets the Id of service endpoint.
    endpoint_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents service endpoint execution data.
pub const ServiceEndpointExecutionData = struct {
    definition: ?ServiceEndpointExecutionOwner = null,
    /// Gets the finish time of service endpoint execution.
    finish_time: ?[]const u8 = null,
    /// Gets the Id of service endpoint execution data.
    id: ?i64 = null,
    owner: ?ServiceEndpointExecutionOwner = null,
    /// Gets the additional details about the instance that used the service endpoint.
    owner_details: ?[]const u8 = null,
    /// Gets the plan type of service endpoint execution data.
    plan_type: ?[]const u8 = null,
    /// Gets the result of service endpoint execution.
    result: ?enums.ServiceEndpointExecutionDataResult = null,
    /// Gets the start time of service endpoint execution.
    start_time: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents execution owner of the service endpoint.
pub const ServiceEndpointExecutionOwner = struct {
    links: ?ReferenceLinks = null,
    /// Gets or sets the Id of service endpoint execution owner.
    id: ?i32 = null,
    /// Gets or sets the name of service endpoint execution owner.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};
