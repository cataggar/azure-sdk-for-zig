//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `InstalledExtension` as returned by Azure DevOps.
pub const InstalledExtensionList = struct {
    count: ?i32 = null,
    value: ?[]const InstalledExtension = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a VSTS extension along with its installation state
pub const InstalledExtension = struct {
    /// Uri used as base for other relative uri's defined in extension
    base_uri: ?[]const u8 = null,
    /// List of shared constraints defined by this extension
    constraints: ?[]const ContributionConstraint = null,
    /// List of contributions made by this extension
    contributions: ?[]const Contribution = null,
    /// List of contribution types defined by this extension
    contribution_types: ?[]const ContributionType = null,
    /// List of explicit demands required by this extension
    demands: ?[]const []const u8 = null,
    event_callbacks: ?ExtensionEventCallbackCollection = null,
    /// Secondary location that can be used as base for other relative uri's defined in extension
    fallback_base_uri: ?[]const u8 = null,
    /// Language Culture Name set by the Gallery
    language: ?[]const u8 = null,
    licensing: ?ExtensionLicensing = null,
    /// Version of the extension manifest format/content
    manifest_version: ?f64 = null,
    /// Marketplace uri used as base for other relative uris defined in extension. Uri might be the same as BaseUri.
    marketplace_base_uri: ?[]const u8 = null,
    /// Default user claims applied to all contributions (except the ones which have been specified restrictedTo explicitly) to control the visibility of a contribution.
    restricted_to: ?[]const []const u8 = null,
    /// List of all oauth scopes required by this extension
    scopes: ?[]const []const u8 = null,
    /// The ServiceInstanceType(Guid) of the VSTS service that must be available to an account in order for the extension to be installed
    service_instance_type: ?[]const u8 = null,
    /// The friendly extension id for this extension - unique for a given publisher.
    extension_id: ?[]const u8 = null,
    /// The display name of the extension.
    extension_name: ?[]const u8 = null,
    /// This is the set of files available from the extension.
    files: ?[]const ExtensionFile = null,
    /// Extension flags relevant to contribution consumers
    flags: ?enums.InstalledExtensionFlags = null,
    install_state: ?InstalledExtensionState = null,
    /// This represents the date/time the extensions was last updated in the gallery. This doesnt mean this version was updated the value represents changes to any and all versions of the extension.
    last_published: ?[]const u8 = null,
    /// Unique id of the publisher of this extension
    publisher_id: ?[]const u8 = null,
    /// The display name of the publisher
    publisher_name: ?[]const u8 = null,
    /// Unique id for this extension (the same id is used for all versions of a single extension)
    registration_id: ?[]const u8 = null,
    /// Version of this extension
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Specifies a constraint that can be used to dynamically include/exclude a given contribution
pub const ContributionConstraint = struct {
    /// An optional property that can be specified to group constraints together. All constraints within a group are AND'd together (all must be evaluate to True in order for the contribution to be included). Different groups of constraints are OR'd (only one group needs to evaluate to True for the contribution to be included).
    group: ?i32 = null,
    /// Fully qualified identifier of a shared constraint
    id: ?[]const u8 = null,
    /// If true, negate the result of the filter (include the contribution if the applied filter returns false instead of true)
    inverse: ?bool = null,
    /// Name of the IContributionFilter plugin
    name: ?[]const u8 = null,
    properties: ?JObject = null,
    /// Constraints can be optionally be applied to one or more of the relationships defined in the contribution. If no relationships are defined then all relationships are associated with the constraint. This means the default behaviour will eliminate the contribution from the tree completely if the constraint is applied.
    relationships: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a JSON object.
pub const JObject = struct {
    item: ?[]const u8 = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An individual contribution made by an extension
pub const Contribution = struct {
    /// Description of the contribution/type
    description: ?[]const u8 = null,
    /// Fully qualified identifier of the contribution/type
    id: ?[]const u8 = null,
    /// VisibleTo can be used to restrict whom can reference a given contribution/type. This value should be a list of publishers or extensions access is restricted too. Examples: 'ms' - Means only the 'ms' publisher can reference this. 'ms.vss-web' - Means only the 'vss-web' extension from the 'ms' publisher can reference this.
    visible_to: ?[]const []const u8 = null,
    /// List of constraints (filters) that should be applied to the availability of this contribution
    constraints: ?[]const ContributionConstraint = null,
    /// Includes is a set of contributions that should have this contribution included in their targets list.
    includes: ?[]const []const u8 = null,
    properties: ?JObject = null,
    /// List of demanded claims in order for the user to see this contribution (like anonymous, public, member...).
    restricted_to: ?[]const []const u8 = null,
    /// The ids of the contribution(s) that this contribution targets. (parent contributions)
    targets: ?[]const []const u8 = null,
    /// Id of the Contribution Type
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A contribution type, given by a json schema
pub const ContributionType = struct {
    /// Description of the contribution/type
    description: ?[]const u8 = null,
    /// Fully qualified identifier of the contribution/type
    id: ?[]const u8 = null,
    /// VisibleTo can be used to restrict whom can reference a given contribution/type. This value should be a list of publishers or extensions access is restricted too. Examples: 'ms' - Means only the 'ms' publisher can reference this. 'ms.vss-web' - Means only the 'vss-web' extension from the 'ms' publisher can reference this.
    visible_to: ?[]const []const u8 = null,
    /// Controls whether or not contributions of this type have the type indexed for queries. This allows clients to find all extensions that have a contribution of this type. NOTE: Only TrustedPartners are allowed to specify indexed contribution types.
    indexed: ?bool = null,
    /// Friendly name of the contribution/type
    name: ?[]const u8 = null,
    /// Describes the allowed properties for this contribution type
    properties: ?std.json.ArrayHashMap(ContributionPropertyDescription) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Description about a property of a contribution type
pub const ContributionPropertyDescription = struct {
    /// Description of the property
    description: ?[]const u8 = null,
    /// Name of the property
    name: ?[]const u8 = null,
    /// True if this property is required
    required: ?bool = null,
    /// The type of value used for this property
    type: ?enums.ContributionPropertyDescriptionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Collection of event callbacks - endpoints called when particular extension events occur.
pub const ExtensionEventCallbackCollection = struct {
    post_disable: ?ExtensionEventCallback = null,
    post_enable: ?ExtensionEventCallback = null,
    post_install: ?ExtensionEventCallback = null,
    post_uninstall: ?ExtensionEventCallback = null,
    post_update: ?ExtensionEventCallback = null,
    pre_install: ?ExtensionEventCallback = null,
    version_check: ?ExtensionEventCallback = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Base class for an event callback for an extension
pub const ExtensionEventCallback = struct {
    /// The uri of the endpoint that is hit when an event occurs
    uri: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// How an extension should handle including contributions based on licensing
pub const ExtensionLicensing = struct {
    /// A list of contributions which deviate from the default licensing behavior
    overrides: ?[]const LicensingOverride = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Maps a contribution to a licensing behavior
pub const LicensingOverride = struct {
    /// How the inclusion of this contribution should change based on licensing
    behavior: ?enums.LicensingOverrideBehavior = null,
    /// Fully qualified contribution id which we want to define licensing behavior for
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ExtensionFile = struct {
    asset_type: ?[]const u8 = null,
    language: ?[]const u8 = null,
    source: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The state of an installed extension
pub const InstalledExtensionState = struct {
    /// States of an installed extension
    flags: ?enums.InstalledExtensionStateFlags = null,
    /// List of installation issues
    installation_issues: ?[]const InstalledExtensionStateIssue = null,
    /// The time at which this installation was last updated
    last_updated: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an installation issue
pub const InstalledExtensionStateIssue = struct {
    /// The error message
    message: ?[]const u8 = null,
    /// Source of the installation issue, for example 'Demands'
    source: ?[]const u8 = null,
    /// Installation issue type (Warning, Error)
    type: ?enums.InstalledExtensionStateIssueType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
