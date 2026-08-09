//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const WidgetTypesResponse = struct {
    links: ?ReferenceLinks = null,
    uri: ?[]const u8 = null,
    widget_types: ?[]const WidgetMetadata = null,

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

/// Contribution based information describing Dashboard Widgets.
pub const WidgetMetadata = struct {
    /// Sizes supported by the Widget.
    allowed_sizes: ?[]const WidgetSize = null,
    /// Opt-in boolean that indicates if the widget requires the Analytics Service to function. Widgets requiring the analytics service are hidden from the catalog if the Analytics Service is not available.
    analytics_service_required: ?bool = null,
    /// Resource for an icon in the widget catalog.
    catalog_icon_url: ?[]const u8 = null,
    /// Opt-in URL string pointing at widget information. Defaults to extension marketplace URL if omitted
    catalog_info_url: ?[]const u8 = null,
    /// The id of the underlying contribution defining the supplied Widget custom configuration UI. Null if custom configuration UI is not available.
    configuration_contribution_id: ?[]const u8 = null,
    /// The relative id of the underlying contribution defining the supplied Widget custom configuration UI. Null if custom configuration UI is not available.
    configuration_contribution_relative_id: ?[]const u8 = null,
    /// Indicates if the widget requires configuration before being added to dashboard.
    configuration_required: ?bool = null,
    /// Uri for the widget content to be loaded from .
    content_uri: ?[]const u8 = null,
    /// The id of the underlying contribution defining the supplied Widget.
    contribution_id: ?[]const u8 = null,
    /// Optional default settings to be copied into widget settings.
    default_settings: ?[]const u8 = null,
    /// Summary information describing the widget.
    description: ?[]const u8 = null,
    /// Widgets can be disabled by the app store. We'll need to gracefully handle for: - persistence (Allow) - Requests (Tag as disabled, and provide context)
    is_enabled: ?bool = null,
    /// Opt-out boolean that indicates if the widget supports widget name/title configuration. Widgets ignoring the name should set it to false in the manifest.
    is_name_configurable: ?bool = null,
    /// Opt-out boolean indicating if the widget is hidden from the catalog. Commonly, this is used to allow developers to disable creation of a deprecated widget. A widget must have a functional default state, or have a configuration experience, in order to be visible from the catalog.
    is_visible_from_catalog: ?bool = null,
    /// Keywords associated with this widget, non-filterable and invisible
    keywords: ?[]const []const u8 = null,
    lightbox_options: ?LightboxOptions = null,
    /// Resource for a loading placeholder image on dashboard
    loading_image_url: ?[]const u8 = null,
    /// User facing name of the widget type. Each widget must use a unique value here.
    name: ?[]const u8 = null,
    /// Publisher Name of this kind of widget.
    publisher_name: ?[]const u8 = null,
    /// Data contract required for the widget to function and to work in its container.
    supported_scopes: ?[]const enums.WidgetMetadataSupportedScope = null,
    /// Tags associated with this widget, visible on each widget and filterable.
    tags: ?[]const []const u8 = null,
    /// Contribution target IDs
    targets: ?[]const []const u8 = null,
    /// Deprecated: locally unique developer-facing id of this kind of widget. ContributionId provides a globally unique identifier for widget types.
    type_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WidgetSize = struct {
    /// The Width of the widget, expressed in dashboard grid columns.
    column_span: ?i32 = null,
    /// The height of the widget, expressed in dashboard grid rows.
    row_span: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Lightbox configuration
pub const LightboxOptions = struct {
    /// Height of desired lightbox, in pixels
    height: ?i32 = null,
    /// True to allow lightbox resizing, false to disallow lightbox resizing, defaults to false.
    resizable: ?bool = null,
    /// Width of desired lightbox, in pixels
    width: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WidgetMetadataResponse = struct {
    uri: ?[]const u8 = null,
    widget_metadata: ?WidgetMetadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Model of a Dashboard.
pub const Dashboard = struct {
    links: ?ReferenceLinks = null,
    /// Entity to which the dashboard is scoped.
    dashboard_scope: ?enums.DashboardDashboardScope = null,
    /// Description of the dashboard.
    description: ?[]const u8 = null,
    /// Server defined version tracking value, used for edit collision detection.
    e_tag: ?[]const u8 = null,
    /// Dashboard Global Parameters Config
    global_parameters_config: ?[]const u8 = null,
    /// ID of the group for a dashboard. For team-scoped dashboards, this is the unique identifier for the team associated with the dashboard. For project-scoped dashboards this property is empty.
    group_id: ?[]const u8 = null,
    /// ID of the Dashboard. Provided by service at creation time.
    id: ?[]const u8 = null,
    /// Dashboard Last Accessed Date.
    last_accessed_date: ?[]const u8 = null,
    /// Id of the person who modified Dashboard.
    modified_by: ?[]const u8 = null,
    /// Dashboard's last modified date.
    modified_date: ?[]const u8 = null,
    /// Name of the Dashboard.
    name: ?[]const u8 = null,
    /// ID of the owner for a dashboard. For team-scoped dashboards, this is the unique identifier for the team associated with the dashboard. For project-scoped dashboards, this is the unique identifier for the user identity associated with the dashboard.
    owner_id: ?[]const u8 = null,
    /// Position of the dashboard, within a dashboard group. If unset at creation time, position is decided by the service.
    position: ?i32 = null,
    /// Interval for client to automatically refresh the dashboard. Expressed in minutes.
    refresh_interval: ?i32 = null,
    url: ?[]const u8 = null,
    /// The set of Widgets on the dashboard.
    widgets: ?[]const Widget = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Widget data
pub const Widget = struct {
    links: ?ReferenceLinks = null,
    /// Refers to the allowed sizes for the widget. This gets populated when user wants to configure the widget
    allowed_sizes: ?[]const WidgetSize = null,
    /// Read-Only Property from Dashboard Service. Indicates if settings are blocked for the current user.
    are_settings_blocked_for_user: ?bool = null,
    /// Refers to unique identifier of a feature artifact. Used for pinning+unpinning a specific artifact.
    artifact_id: ?[]const u8 = null,
    configuration_contribution_id: ?[]const u8 = null,
    configuration_contribution_relative_id: ?[]const u8 = null,
    content_uri: ?[]const u8 = null,
    /// The id of the underlying contribution defining the supplied Widget Configuration.
    contribution_id: ?[]const u8 = null,
    dashboard: ?Dashboard = null,
    e_tag: ?[]const u8 = null,
    id: ?[]const u8 = null,
    is_enabled: ?bool = null,
    is_name_configurable: ?bool = null,
    lightbox_options: ?LightboxOptions = null,
    loading_image_url: ?[]const u8 = null,
    name: ?[]const u8 = null,
    position: ?WidgetPosition = null,
    settings: ?[]const u8 = null,
    settings_version: ?SemanticVersion = null,
    size: ?WidgetSize = null,
    type_id: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const WidgetPosition = struct {
    column: ?i32 = null,
    row: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// versioning for an artifact as described at: http://semver.org/, of the form major.minor.patch.
pub const SemanticVersion = struct {
    /// Major version when you make incompatible API changes
    major: ?i32 = null,
    /// Minor version when you add functionality in a backwards-compatible manner
    minor: ?i32 = null,
    /// Patch version when you make backwards-compatible bug fixes
    patch: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a list of dashboards associated to an owner. Currently, teams own dashboard groups.
pub const DashboardGroup = struct {
    links: ?ReferenceLinks = null,
    /// A list of Dashboards held by the Dashboard Group
    dashboard_entries: ?[]const DashboardGroupEntry = null,
    /// Deprecated: The old permission model describing the level of permissions for the current team. Pre-M125.
    permission: ?enums.DashboardGroupPermission = null,
    /// A permissions bit mask describing the security permissions of the current team for dashboards. When this permission is the value None, use GroupMemberPermission. Permissions are evaluated based on the presence of a value other than None, else the GroupMemberPermission will be saved.
    team_dashboard_permission: ?enums.DashboardGroupTeamDashboardPermission = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Dashboard group entry, wrapping around Dashboard (needed?)
pub const DashboardGroupEntry = struct {
    links: ?ReferenceLinks = null,
    /// Entity to which the dashboard is scoped.
    dashboard_scope: ?enums.DashboardDashboardScope = null,
    /// Description of the dashboard.
    description: ?[]const u8 = null,
    /// Server defined version tracking value, used for edit collision detection.
    e_tag: ?[]const u8 = null,
    /// Dashboard Global Parameters Config
    global_parameters_config: ?[]const u8 = null,
    /// ID of the group for a dashboard. For team-scoped dashboards, this is the unique identifier for the team associated with the dashboard. For project-scoped dashboards this property is empty.
    group_id: ?[]const u8 = null,
    /// ID of the Dashboard. Provided by service at creation time.
    id: ?[]const u8 = null,
    /// Dashboard Last Accessed Date.
    last_accessed_date: ?[]const u8 = null,
    /// Id of the person who modified Dashboard.
    modified_by: ?[]const u8 = null,
    /// Dashboard's last modified date.
    modified_date: ?[]const u8 = null,
    /// Name of the Dashboard.
    name: ?[]const u8 = null,
    /// ID of the owner for a dashboard. For team-scoped dashboards, this is the unique identifier for the team associated with the dashboard. For project-scoped dashboards, this is the unique identifier for the user identity associated with the dashboard.
    owner_id: ?[]const u8 = null,
    /// Position of the dashboard, within a dashboard group. If unset at creation time, position is decided by the service.
    position: ?i32 = null,
    /// Interval for client to automatically refresh the dashboard. Expressed in minutes.
    refresh_interval: ?i32 = null,
    url: ?[]const u8 = null,
    /// The set of Widgets on the dashboard.
    widgets: ?[]const Widget = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};
