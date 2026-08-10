//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `AuditActionInfo` as returned by Azure DevOps.
pub const AuditActionInfoList = struct {
    count: ?i32 = null,
    value: ?[]const AuditActionInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AuditActionInfo = struct {
    /// The action id for the event, i.e Git.CreateRepo, Project.RenameProject
    action_id: ?[]const u8 = null,
    /// Area of Azure DevOps the action occurred
    area: ?[]const u8 = null,
    /// Type of action executed
    category: ?enums.AuditActionInfoCategory = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The object returned when the audit log is queried. It contains the log and the information needed to query more audit entries.
pub const AuditLogQueryResult = struct {
    /// The continuation token to pass to get the next set of results
    continuation_token: ?[]const u8 = null,
    /// The list of audit log entries
    decorated_audit_log_entries: ?[]const DecoratedAuditLogEntry = null,
    /// True when there are more matching results to be fetched, false otherwise.
    has_more: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DecoratedAuditLogEntry = struct {
    /// The action id for the event, i.e Git.CreateRepo, Project.RenameProject
    action_id: ?[]const u8 = null,
    /// ActivityId
    activity_id: ?[]const u8 = null,
    /// The Actor's Client Id (if actor is a service principal)
    actor_client_id: ?[]const u8 = null,
    /// The Actor's CUID
    actor_cuid: ?[]const u8 = null,
    /// DisplayName of the user who initiated the action
    actor_display_name: ?[]const u8 = null,
    /// URL of Actor's Profile image
    actor_image_url: ?[]const u8 = null,
    /// The Actor's UPN
    actor_upn: ?[]const u8 = null,
    /// The Actor's User Id (if actor is a user)
    actor_user_id: ?[]const u8 = null,
    /// Area of Azure DevOps the action occurred
    area: ?[]const u8 = null,
    /// Type of authentication used by the actor
    authentication_mechanism: ?[]const u8 = null,
    /// Type of action executed
    category: ?enums.DecoratedAuditLogEntryCategory = null,
    /// DisplayName of the category
    category_display_name: ?[]const u8 = null,
    /// This allows related audit entries to be grouped together. Generally this occurs when a single action causes a cascade of audit entries. For example, project creation.
    correlation_id: ?[]const u8 = null,
    /// External data such as CUIDs, item names, etc.
    data: ?std.json.ArrayHashMap(DecoratedAuditLogEntryDatum) = null,
    /// Decorated details
    details: ?[]const u8 = null,
    /// EventId - Needs to be unique per service
    id: ?[]const u8 = null,
    /// IP Address where the event was originated
    ip_address: ?[]const u8 = null,
    /// When specified, the id of the project this event is associated to
    project_id: ?[]const u8 = null,
    /// When specified, the name of the project this event is associated to
    project_name: ?[]const u8 = null,
    /// DisplayName of the scope
    scope_display_name: ?[]const u8 = null,
    /// The organization Id (Organization is the only scope currently supported)
    scope_id: ?[]const u8 = null,
    /// The type of the scope (Organization is only scope currently supported)
    scope_type: ?enums.DecoratedAuditLogEntryScopeType = null,
    /// The time when the event occurred in UTC
    timestamp: ?[]const u8 = null,
    /// The user agent from the request
    user_agent: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .actor_cuid = "actorCUID",
            .actor_upn = "actorUPN",
        },
    };
};

pub const DecoratedAuditLogEntryDatum = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `AuditStream` as returned by Azure DevOps.
pub const AuditStreamList = struct {
    count: ?i32 = null,
    value: ?[]const AuditStream = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This class represents an audit stream
pub const AuditStream = struct {
    /// Inputs used to communicate with external service. Inputs could be url, a connection string, a token, etc.
    consumer_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Type of the consumer, i.e. splunk, azureEventHub, etc.
    consumer_type: ?[]const u8 = null,
    /// The time when the stream was created
    created_time: ?[]const u8 = null,
    /// Used to identify individual streams
    display_name: ?[]const u8 = null,
    /// Unique stream identifier
    id: ?i32 = null,
    /// Status of the stream, Enabled, Disabled
    status: ?enums.AuditStreamStatus = null,
    /// Reason for the current stream status, i.e. Disabled by the system, Invalid credentials, etc.
    status_reason: ?[]const u8 = null,
    /// The time when the stream was last updated
    updated_time: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
