//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Permissions for feed service-wide operations such as the creation of new feeds.
pub const GlobalPermission = struct {
    identity_descriptor: ?IdentityDescriptor = null,
    /// IdentityId corresponding to the IdentityDescriptor
    identity_id: ?[]const u8 = null,
    /// Role associated with the Identity.
    role: ?enums.GlobalPermissionRole = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An Identity descriptor is a wrapper for the identity type (Windows SID, Passport) along with a unique identifier such as the SID or PUID.
pub const IdentityDescriptor = struct {
    /// The unique identifier for this identity, not exceeding 256 chars, which will be persisted.
    identifier: ?[]const u8 = null,
    /// Type of descriptor (for example, Windows, Passport, etc.).
    identity_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A result set containing the feed changes for the range that was requested.
pub const FeedChangesResponse = struct {
    links: ?ReferenceLinks = null,
    /// The number of changes in this set.
    count: ?i32 = null,
    /// A container that encapsulates the state of the feed after a create, update, or delete.
    feed_changes: ?[]const FeedChange = null,
    /// When iterating through the log of changes this value indicates the value that should be used for the next continuation token.
    next_feed_continuation_token: ?i64 = null,

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

/// A container that encapsulates the state of the feed after a create, update, or delete.
pub const FeedChange = struct {
    /// The type of operation.
    change_type: ?enums.FeedChangeChangeType = null,
    feed: ?Feed = null,
    /// A token that identifies the next change in the log of changes.
    feed_continuation_token: ?i64 = null,
    /// A token that identifies the latest package change for this feed. This can be used to quickly determine if there have been any changes to packages in a specific feed.
    latest_package_continuation_token: ?i64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A container for artifacts.
pub const Feed = struct {
    /// Supported capabilities of a feed.
    capabilities: ?enums.FeedCapabilities = null,
    /// This will either be the feed GUID or the feed GUID and view GUID depending on how the feed was accessed.
    fully_qualified_id: ?[]const u8 = null,
    /// Full name of the view, in feed@view format.
    fully_qualified_name: ?[]const u8 = null,
    /// A GUID that uniquely identifies this feed.
    id: ?[]const u8 = null,
    /// If false, the feed is disabled and cannot be interacted with
    is_enabled: ?bool = null,
    /// If set, all packages in the feed are immutable. It is important to note that feed views are immutable; therefore, this flag will always be set for views.
    is_read_only: ?bool = null,
    /// A name for the feed. feed names must follow these rules: <list type='bullet'><item><description> Must not exceed 64 characters </description></item><item><description> Must not contain whitespaces </description></item><item><description> Must not start with an underscore or a period </description></item><item><description> Must not end with a period </description></item><item><description> Must not contain any of the following illegal characters: <![CDATA[ @, ~, ;, {, }, , +, =, <, >, |, /, , ?, :, &, $, *, ', #, [, ] ]]></description></item></list>
    name: ?[]const u8 = null,
    project: ?ProjectReference = null,
    /// This should always be true. Setting to false will override all sources in UpstreamSources.
    upstream_enabled: ?bool = null,
    /// A list of sources that this feed will fetch packages from. An empty list indicates that this feed will not search any additional sources for packages.
    upstream_sources: ?[]const UpstreamSource = null,
    view: ?FeedView = null,
    /// View Id.
    view_id: ?[]const u8 = null,
    /// View name.
    view_name: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// If set, this feed supports generation of package badges.
    badges_enabled: ?bool = null,
    /// The view that the feed administrator has indicated is the default experience for readers.
    default_view_id: ?[]const u8 = null,
    /// The date that this feed was deleted.
    deleted_date: ?[]const u8 = null,
    /// A description for the feed. Descriptions must not exceed 255 characters.
    description: ?[]const u8 = null,
    /// If set, the feed will hide all deleted/unpublished versions
    hide_deleted_package_versions: ?bool = null,
    /// The date that this feed was permanently deleted.
    permanent_deleted_date: ?[]const u8 = null,
    /// Explicit permissions for the feed.
    permissions: ?[]const FeedPermission = null,
    /// The date that this feed is scheduled to be permanently deleted.
    scheduled_permanent_delete_date: ?[]const u8 = null,
    /// If set, time that the UpstreamEnabled property was changed. Will be null if UpstreamEnabled was never changed after Feed creation.
    upstream_enabled_changed_date: ?[]const u8 = null,
    /// The URL of the base feed in GUID form.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ProjectReference = struct {
    /// Gets or sets id of the project.
    id: ?[]const u8 = null,
    /// Gets or sets name of the project.
    name: ?[]const u8 = null,
    /// Gets or sets visibility of the project.
    visibility: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Upstream source definition, including its Identity, package type, and other associated information.
pub const UpstreamSource = struct {
    /// UTC date that this upstream was deleted.
    deleted_date: ?[]const u8 = null,
    /// Locator for connecting to the upstream source in a user friendly format, that may potentially change over time
    display_location: ?[]const u8 = null,
    /// Identity of the upstream source.
    id: ?[]const u8 = null,
    /// For an internal upstream type, track the Azure DevOps organization that contains it.
    internal_upstream_collection_id: ?[]const u8 = null,
    /// For an internal upstream type, track the feed id being referenced.
    internal_upstream_feed_id: ?[]const u8 = null,
    /// For an internal upstream type, track the project of the feed being referenced.
    internal_upstream_project_id: ?[]const u8 = null,
    /// For an internal upstream type, track the view of the feed being referenced.
    internal_upstream_view_id: ?[]const u8 = null,
    /// Consistent locator for connecting to the upstream source.
    location: ?[]const u8 = null,
    /// Display name.
    name: ?[]const u8 = null,
    /// Package type associated with the upstream source.
    protocol: ?[]const u8 = null,
    /// The identity of the service endpoint that holds credentials to use when accessing the upstream.
    service_endpoint_id: ?[]const u8 = null,
    /// Specifies the projectId of the Service Endpoint.
    service_endpoint_project_id: ?[]const u8 = null,
    /// Specifies the status of the upstream.
    status: ?enums.UpstreamSourceStatus = null,
    /// Provides a human-readable reason for the status of the upstream.
    status_details: ?[]const UpstreamStatusDetail = null,
    /// Source type, such as Public or Internal.
    upstream_source_type: ?enums.UpstreamSourceUpstreamSourceType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpstreamStatusDetail = struct {
    /// Provides a human-readable reason for the status of the upstream.
    reason: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A view on top of a feed.
pub const FeedView = struct {
    links: ?ReferenceLinks = null,
    /// Id of the view.
    id: ?[]const u8 = null,
    /// Name of the view.
    name: ?[]const u8 = null,
    /// Type of view.
    type: ?enums.FeedViewType = null,
    /// Url of the view.
    url: ?[]const u8 = null,
    /// Visibility status of the view.
    visibility: ?enums.FeedViewVisibility = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Permissions for a feed.
pub const FeedPermission = struct {
    /// Display name for the identity.
    display_name: ?[]const u8 = null,
    identity_descriptor: ?IdentityDescriptor = null,
    /// Id of the identity associated with this role.
    identity_id: ?[]const u8 = null,
    /// Boolean indicating whether the role is inherited or set directly.
    is_inherited_role: ?bool = null,
    /// The role for this identity on a feed.
    role: ?enums.FeedPermissionRole = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A set of change operations to a feed's packages.
pub const PackageChangesResponse = struct {
    links: ?ReferenceLinks = null,
    /// Number of changes in this batch.
    count: ?i32 = null,
    /// Token that should be used in future calls for this feed to retrieve new changes.
    next_package_continuation_token: ?i64 = null,
    /// List of changes.
    package_changes: ?[]const PackageChange = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A single change to a feed's packages.
pub const PackageChange = struct {
    package: ?Package = null,
    package_version_change: ?PackageVersionChange = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A package, which is a container for one or more package versions.
pub const Package = struct {
    links: ?ReferenceLinks = null,
    /// Id of the package.
    id: ?[]const u8 = null,
    /// Used for legacy scenarios and may be removed in future versions.
    is_cached: ?bool = null,
    /// The display name of the package.
    name: ?[]const u8 = null,
    /// The normalized name representing the identity of this package within its package type.
    normalized_name: ?[]const u8 = null,
    /// Type of the package.
    protocol_type: ?[]const u8 = null,
    /// [Obsolete] - this field is unused and will be removed in a future release.
    star_count: ?i32 = null,
    /// Url for this package.
    url: ?[]const u8 = null,
    /// All versions for this package within its feed.
    versions: ?[]const MinimalPackageVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Core data about any package, including its id and version information and basic state.
pub const MinimalPackageVersion = struct {
    /// Upstream source this package was ingested from.
    direct_upstream_source_id: ?[]const u8 = null,
    /// Id for the package.
    id: ?[]const u8 = null,
    /// [Obsolete] Used for legacy scenarios and may be removed in future versions.
    is_cached_version: ?bool = null,
    /// True if this package has been deleted.
    is_deleted: ?bool = null,
    /// True if this is the latest version of the package by package type sort order.
    is_latest: ?bool = null,
    /// (NuGet and Cargo Only) True if this package is listed.
    is_listed: ?bool = null,
    /// Normalized version using normalization rules specific to a package type.
    normalized_version: ?[]const u8 = null,
    /// Package description.
    package_description: ?[]const u8 = null,
    /// UTC Date the package was published to the service.
    publish_date: ?[]const u8 = null,
    /// Internal storage id.
    storage_id: ?[]const u8 = null,
    /// Display version.
    version: ?[]const u8 = null,
    /// List of views containing this package version.
    views: ?[]const FeedView = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A change to a single package version.
pub const PackageVersionChange = struct {
    /// The type of change that was performed.
    change_type: ?enums.PackageVersionChangeChangeType = null,
    /// Token marker for this change, allowing the caller to send this value back to the service and receive changes beyond this one.
    continuation_token: ?i64 = null,
    package_version: ?PackageVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A specific version of a package.
pub const PackageVersion = struct {
    /// Upstream source this package was ingested from.
    direct_upstream_source_id: ?[]const u8 = null,
    /// Id for the package.
    id: ?[]const u8 = null,
    /// [Obsolete] Used for legacy scenarios and may be removed in future versions.
    is_cached_version: ?bool = null,
    /// True if this package has been deleted.
    is_deleted: ?bool = null,
    /// True if this is the latest version of the package by package type sort order.
    is_latest: ?bool = null,
    /// (NuGet and Cargo Only) True if this package is listed.
    is_listed: ?bool = null,
    /// Normalized version using normalization rules specific to a package type.
    normalized_version: ?[]const u8 = null,
    /// Package description.
    package_description: ?[]const u8 = null,
    /// UTC Date the package was published to the service.
    publish_date: ?[]const u8 = null,
    /// Internal storage id.
    storage_id: ?[]const u8 = null,
    /// Display version.
    version: ?[]const u8 = null,
    /// List of views containing this package version.
    views: ?[]const FeedView = null,
    links: ?ReferenceLinks = null,
    /// Package version author.
    author: ?[]const u8 = null,
    /// UTC date that this package version was deleted.
    deleted_date: ?[]const u8 = null,
    /// List of dependencies for this package version.
    dependencies: ?[]const PackageDependency = null,
    /// Package version description.
    description: ?[]const u8 = null,
    /// Files associated with this package version, only relevant for multi-file package types.
    files: ?[]const PackageFile = null,
    /// Other versions of this package.
    other_versions: ?[]const MinimalPackageVersion = null,
    protocol_metadata: ?ProtocolMetadata = null,
    /// List of upstream sources through which a package version moved to land in this feed.
    source_chain: ?[]const UpstreamSource = null,
    /// Package version summary.
    summary: ?[]const u8 = null,
    /// Package version tags.
    tags: ?[]const []const u8 = null,
    /// Package version url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A dependency on another package version.
pub const PackageDependency = struct {
    /// Dependency package group (an optional classification within some package types).
    group: ?[]const u8 = null,
    /// Dependency package name.
    package_name: ?[]const u8 = null,
    /// Dependency package version range.
    version_range: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A package file for a specific package version, only relevant to package types that contain multiple files per version.
pub const PackageFile = struct {
    /// Hierarchical representation of files.
    children: ?[]const PackageFile = null,
    /// File name.
    name: ?[]const u8 = null,
    protocol_metadata: ?ProtocolMetadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Extended metadata for a specific package type.
pub const ProtocolMetadata = struct {
    /// Extended metadata for a specific package type, formatted to the associated schema version definition.
    data: ?ProtocolMetadataData = null,
    /// Schema version.
    schema_version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProtocolMetadataData = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Update a feed definition with these new values.
pub const FeedUpdate = struct {
    /// If set, the feed will allow upload of packages that exist on the upstream
    allow_upstream_name_conflict: ?bool = null,
    /// If set, this feed supports generation of package badges.
    badges_enabled: ?bool = null,
    /// The view that the feed administrator has indicated is the default experience for readers.
    default_view_id: ?[]const u8 = null,
    /// A description for the feed. Descriptions must not exceed 255 characters.
    description: ?[]const u8 = null,
    /// If set, feed will hide all deleted/unpublished versions
    hide_deleted_package_versions: ?bool = null,
    /// A GUID that uniquely identifies this feed.
    id: ?[]const u8 = null,
    /// If true, enable the feed. If false, disable the feed. If null, do not enable or disable the feed in this request. When enabling or disabling a feed, no other changes to the feed are allowed in the same request.
    is_enabled: ?bool = null,
    /// A name for the feed. feed names must follow these rules: <list type='bullet'><item><description> Must not exceed 64 characters </description></item><item><description> Must not contain whitespaces </description></item><item><description> Must not start with an underscore or a period </description></item><item><description> Must not end with a period </description></item><item><description> Must not contain any of the following illegal characters: <![CDATA[ @, ~, ;, {, }, , +, =, <, >, |, /, , ?, :, &, $, *, ', #, [, ] ]]></description></item></list>
    name: ?[]const u8 = null,
    /// If set, the feed can proxy packages from an upstream feed
    upstream_enabled: ?bool = null,
    /// A list of sources that this feed will fetch packages from. An empty list indicates that this feed will not search any additional sources for packages.
    upstream_sources: ?[]const UpstreamSource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Query to get package metrics
pub const PackageMetricsQuery = struct {
    /// List of package ids
    package_ids: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// All metrics for a certain package id
pub const PackageMetrics = struct {
    /// Total count of downloads per package id.
    download_count: ?f64 = null,
    /// Number of downloads per unique user per package id.
    download_unique_users: ?f64 = null,
    /// UTC date and time when package was last downloaded.
    last_downloaded: ?[]const u8 = null,
    /// Package id.
    package_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Query to get package version metrics
pub const PackageVersionMetricsQuery = struct {
    /// List of package version ids
    package_version_ids: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// All metrics for a certain package version id
pub const PackageVersionMetrics = struct {
    /// Total count of downloads per package version id.
    download_count: ?f64 = null,
    /// Number of downloads per unique user per package version id.
    download_unique_users: ?f64 = null,
    /// UTC date and time when package version was last downloaded.
    last_downloaded: ?[]const u8 = null,
    /// Package id.
    package_id: ?[]const u8 = null,
    /// Package version id.
    package_version_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Provenance for a published package version
pub const PackageVersionProvenance = struct {
    /// Name or Id of the feed.
    feed_id: ?[]const u8 = null,
    /// Id of the package (GUID Id, not name).
    package_id: ?[]const u8 = null,
    /// Id of the package version (GUID Id, not name).
    package_version_id: ?[]const u8 = null,
    provenance: ?Provenance = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data about the origin of a published package
pub const Provenance = struct {
    /// Other provenance data.
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// Type of provenance source, for example 'InternalBuild', 'InternalRelease'
    provenance_source: ?[]const u8 = null,
    /// Identity of user that published the package
    publisher_user_identity: ?[]const u8 = null,
    /// HTTP User-Agent used when pushing the package.
    user_agent: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference for an async operation.
pub const OperationReference = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.OperationReferenceStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A single package version within the recycle bin.
pub const RecycleBinPackageVersion = struct {
    /// Upstream source this package was ingested from.
    direct_upstream_source_id: ?[]const u8 = null,
    /// Id for the package.
    id: ?[]const u8 = null,
    /// [Obsolete] Used for legacy scenarios and may be removed in future versions.
    is_cached_version: ?bool = null,
    /// True if this package has been deleted.
    is_deleted: ?bool = null,
    /// True if this is the latest version of the package by package type sort order.
    is_latest: ?bool = null,
    /// (NuGet and Cargo Only) True if this package is listed.
    is_listed: ?bool = null,
    /// Normalized version using normalization rules specific to a package type.
    normalized_version: ?[]const u8 = null,
    /// Package description.
    package_description: ?[]const u8 = null,
    /// UTC Date the package was published to the service.
    publish_date: ?[]const u8 = null,
    /// Internal storage id.
    storage_id: ?[]const u8 = null,
    /// Display version.
    version: ?[]const u8 = null,
    /// List of views containing this package version.
    views: ?[]const FeedView = null,
    links: ?ReferenceLinks = null,
    /// Package version author.
    author: ?[]const u8 = null,
    /// UTC date that this package version was deleted.
    deleted_date: ?[]const u8 = null,
    /// List of dependencies for this package version.
    dependencies: ?[]const PackageDependency = null,
    /// Package version description.
    description: ?[]const u8 = null,
    /// Files associated with this package version, only relevant for multi-file package types.
    files: ?[]const PackageFile = null,
    /// Other versions of this package.
    other_versions: ?[]const MinimalPackageVersion = null,
    protocol_metadata: ?ProtocolMetadata = null,
    /// List of upstream sources through which a package version moved to land in this feed.
    source_chain: ?[]const UpstreamSource = null,
    /// Package version summary.
    summary: ?[]const u8 = null,
    /// Package version tags.
    tags: ?[]const []const u8 = null,
    /// Package version url.
    url: ?[]const u8 = null,
    /// UTC date on which the package will automatically be removed from the recycle bin and permanently deleted.
    scheduled_permanent_delete_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Retention policy settings.
pub const FeedRetentionPolicy = struct {
    /// This attribute is deprecated and is not honoured by retention
    age_limit_in_days: ?i32 = null,
    /// Maximum versions to preserve per package and package type.
    count_limit: ?i32 = null,
    /// Number of days to preserve a package version after its latest download.
    days_to_keep_recently_downloaded_packages: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SessionRequest = struct {
    /// Generic property bag to store data about the session
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// The feed name or id for the session
    feed: ?[]const u8 = null,
    /// The type of session If a known value is provided, the Data dictionary will be validated for the presence of properties required by that type
    source: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SessionResponse = struct {
    /// The unique identifier for the session
    session_id: ?[]const u8 = null,
    /// The name for the session
    session_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
