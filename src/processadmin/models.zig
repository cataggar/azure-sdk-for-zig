//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Describes an admin behavior for a process.
pub const AdminBehavior = struct {
    /// Is the behavior abstract (i.e. can not be associated with any work item type).
    abstract: ?bool = null,
    /// The color associated with the behavior.
    color: ?[]const u8 = null,
    /// Indicates if the behavior is custom.
    custom: ?bool = null,
    /// The description of the behavior.
    description: ?[]const u8 = null,
    /// List of behavior fields.
    fields: ?[]const AdminBehaviorField = null,
    /// Behavior ID.
    id: ?[]const u8 = null,
    /// Parent behavior reference.
    inherits: ?[]const u8 = null,
    /// The behavior name.
    name: ?[]const u8 = null,
    /// Is the behavior overrides a behavior from system process.
    overriden: ?bool = null,
    /// The rank.
    rank: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes an admin behavior field.
pub const AdminBehaviorField = struct {
    /// The behavior field identifier.
    behavior_field_id: ?[]const u8 = null,
    /// The behavior ID.
    id: ?[]const u8 = null,
    /// The behavior name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the result of a Process Import request.
pub const ProcessImportResult = struct {
    check_existence_result: ?CheckTemplateExistenceResult = null,
    /// Help URL.
    help_url: ?[]const u8 = null,
    /// ID of the import operation.
    id: ?[]const u8 = null,
    /// Whether this imported process is new.
    is_new: ?bool = null,
    /// The promote job identifier.
    promote_job_id: ?[]const u8 = null,
    /// The list of validation results.
    validation_results: ?[]const ValidationIssue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes result of a check template existence request.
pub const CheckTemplateExistenceResult = struct {
    /// Indicates whether a template exists.
    does_template_exist: ?bool = null,
    /// The name of the existing template.
    existing_template_name: ?[]const u8 = null,
    /// The existing template type identifier.
    existing_template_type_id: ?[]const u8 = null,
    /// The name of the requested template.
    requested_template_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ValidationIssue = struct {
    description: ?[]const u8 = null,
    file: ?[]const u8 = null,
    help_link: ?[]const u8 = null,
    issue_type: ?enums.ValidationIssueIssueType = null,
    line: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes result of process operation promote.
pub const ProcessPromoteStatus = struct {
    /// Number of projects for which promote is complete.
    complete: ?i32 = null,
    /// ID of the promote operation.
    id: ?[]const u8 = null,
    /// The error message associated with the promote operation. The string will be empty if there are no errors.
    message: ?[]const u8 = null,
    /// Number of projects for which promote is pending.
    pending: ?i32 = null,
    /// The remaining retries.
    remaining_retries: ?i32 = null,
    /// True if promote finished all the projects successfully. False if still in progress or any project promote failed.
    successful: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
