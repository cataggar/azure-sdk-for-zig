//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `WikiV2` as returned by Azure DevOps.
pub const WikiV2List = struct {
    count: ?i32 = null,
    value: ?[]const WikiV2 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a wiki resource.
pub const WikiV2 = struct {
    /// Folder path inside repository which is shown as Wiki. Not required for ProjectWiki type.
    mapped_path: ?[]const u8 = null,
    /// Wiki name.
    name: ?[]const u8 = null,
    /// ID of the project in which the wiki is to be created.
    project_id: ?[]const u8 = null,
    /// ID of the git repository that backs up the wiki. Not required for ProjectWiki type.
    repository_id: ?[]const u8 = null,
    /// Type of the wiki.
    type: ?enums.WikiV2Type = null,
    /// ID of the wiki.
    id: ?[]const u8 = null,
    /// Is wiki repository disabled
    is_disabled: ?bool = null,
    /// Properties of the wiki.
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// Remote web url to the wiki.
    remote_url: ?[]const u8 = null,
    /// REST url for this wiki.
    url: ?[]const u8 = null,
    /// Versions of the wiki.
    versions: ?[]const GitVersionDescriptor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitVersionDescriptor = struct {
    /// Version string identifier (name of tag/branch, SHA1 of commit)
    version: ?[]const u8 = null,
    /// Version options - Specify additional modifiers to version (e.g Previous)
    version_options: ?enums.GitVersionDescriptorVersionOptions = null,
    /// Version type (branch, tag, or commit). Determines how Id is interpreted
    version_type: ?enums.GitVersionDescriptorVersionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Wiki creation parameters.
pub const WikiCreateParametersV2 = struct {
    /// Folder path inside repository which is shown as Wiki. Not required for ProjectWiki type.
    mapped_path: ?[]const u8 = null,
    /// Wiki name.
    name: ?[]const u8 = null,
    /// ID of the project in which the wiki is to be created.
    project_id: ?[]const u8 = null,
    /// ID of the git repository that backs up the wiki. Not required for ProjectWiki type.
    repository_id: ?[]const u8 = null,
    /// Type of the wiki.
    type: ?enums.WikiV2Type = null,
    version: ?GitVersionDescriptor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Wiki update parameters.
pub const WikiUpdateParameters = struct {
    /// Name for wiki.
    name: ?[]const u8 = null,
    /// Versions of the wiki.
    versions: ?[]const GitVersionDescriptor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines properties for wiki attachment file.
pub const WikiAttachment = struct {
    /// Name of the wiki attachment file.
    name: ?[]const u8 = null,
    /// Path of the wiki attachment file.
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contract encapsulating parameters for the page move operation.
pub const WikiPageMoveParameters = struct {
    /// New order of the wiki page.
    new_order: ?i32 = null,
    /// New path of the wiki page.
    new_path: ?[]const u8 = null,
    /// Current path of the wiki page.
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request contract for Wiki Page Move.
pub const WikiPageMove = struct {
    /// New order of the wiki page.
    new_order: ?i32 = null,
    /// New path of the wiki page.
    new_path: ?[]const u8 = null,
    /// Current path of the wiki page.
    path: ?[]const u8 = null,
    page: ?WikiPage = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a page in a wiki.
pub const WikiPage = struct {
    /// Content of the wiki page.
    content: ?[]const u8 = null,
    /// Path of the git item corresponding to the wiki page stored in the backing Git repository.
    git_item_path: ?[]const u8 = null,
    /// When present, permanent identifier for the wiki page
    id: ?i32 = null,
    /// True if a page is non-conforming, i.e. 1) if the name doesn't match page naming standards. 2) if the page does not have a valid entry in the appropriate order file.
    is_non_conformant: ?bool = null,
    /// True if this page has subpages under its path.
    is_parent_page: ?bool = null,
    /// Order of the wiki page, relative to other pages in the same hierarchy level.
    order: ?i32 = null,
    /// Path of the wiki page.
    path: ?[]const u8 = null,
    /// Remote web url to the wiki page.
    remote_url: ?[]const u8 = null,
    /// List of subpages of the current page.
    sub_pages: ?[]const WikiPage = null,
    /// REST url for this wiki page.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contract encapsulating parameters for the page create or update operations.
pub const WikiPageCreateOrUpdateParameters = struct {
    /// Content of the wiki page.
    content: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a page with its metedata in a wiki.
pub const WikiPageDetail = struct {
    /// When present, permanent identifier for the wiki page
    id: ?i32 = null,
    /// Path of the wiki page.
    path: ?[]const u8 = null,
    /// Path of the wiki page.
    view_stats: ?[]const WikiPageStat = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines properties for wiki page stat.
pub const WikiPageStat = struct {
    /// the count of the stat for the Day
    count: ?i32 = null,
    /// Day of the stat
    day: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contract encapsulating parameters for the pages batch.
pub const WikiPagesBatchRequest = struct {
    /// If the list of page data returned is not complete, a continuation token to query next batch of pages is included in the response header as 'x-ms-continuationtoken'. Omit this parameter to get the first batch of Wiki Page Data.
    continuation_token: ?[]const u8 = null,
    /// last N days from the current day for which page views is to be returned. It's inclusive of current day.
    page_views_for_days: ?i32 = null,
    /// Total count of pages on a wiki to return.
    top: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WikiPageDetail` as returned by Azure DevOps.
pub const WikiPageDetailList = struct {
    count: ?i32 = null,
    value: ?[]const WikiPageDetail = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
