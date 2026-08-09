//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Defines a package search request.
pub const PackageSearchRequest = struct {
    /// Filters to be applied. Set it to null if there are no filters to be applied.
    filters: ?std.json.ArrayHashMap([]const []const u8) = null,
    /// The search text.
    search_text: ?[]const u8 = null,
    /// Options for sorting search results. If set to null, the results will be returned sorted by relevance. If more than one sort option is provided, the results are sorted in the order specified in the OrderBy.
    @"$order_by": ?[]const SortOption = null,
    /// Number of results to be skipped.
    @"$skip": ?i32 = null,
    /// Number of results to be returned.
    @"$top": ?i32 = null,
    /// Flag to opt for faceting in the result. Default behavior is false.
    include_facets: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines how to sort the result.
pub const SortOption = struct {
    /// Field name on which sorting should be done.
    field: ?[]const u8 = null,
    /// Order (ASC/DESC) in which the results should be sorted.
    sort_order: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a response item that is returned for a package search request.
pub const PackageSearchResponseContent = struct {
    /// A dictionary storing an array of <code>Filter</code> object against each facet.
    facets: ?std.json.ArrayHashMap([]const Filter) = null,
    /// Numeric code indicating any additional information: 0 - Ok, 1 - Account is being reindexed, 2 - Account indexing has not started, 3 - Invalid Request, 4 - Prefix wildcard query not supported, 5 - MultiWords with code facet not supported, 6 - Account is being onboarded, 7 - Account is being onboarded or reindexed, 8 - Top value trimmed to maxresult allowed 9 - Branches are being indexed, 10 - Faceting not enabled, 11 - Work items not accessible, 19 - Phrase queries with code type filters not supported, 20 - Wildcard queries with code type filters not supported. Any other info code is used for internal purpose.
    info_code: ?i32 = null,
    /// Total number of matched packages.
    count: ?i32 = null,
    /// List of matched packages.
    results: ?[]const PackageResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a filter bucket item representing the total matches of search result, name and id.
pub const Filter = struct {
    /// Id of the filter bucket.
    id: ?[]const u8 = null,
    /// Name of the filter bucket.
    name: ?[]const u8 = null,
    /// Count of matches in the filter bucket.
    result_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the package result that matched a package search request.
pub const PackageResult = struct {
    /// Description of the package.
    description: ?[]const u8 = null,
    /// List of feeds which contain the matching package.
    feeds: ?[]const FeedInfo = null,
    /// List of highlighted fields for the match.
    hits: ?[]const PackageHit = null,
    /// Id of the package.
    id: ?[]const u8 = null,
    /// Name of the package.
    name: ?[]const u8 = null,
    /// Type of the package.
    protocol_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of a feed.
pub const FeedInfo = struct {
    /// Id of the collection.
    collection_id: ?[]const u8 = null,
    /// Name of the collection.
    collection_name: ?[]const u8 = null,
    /// Id of the feed.
    feed_id: ?[]const u8 = null,
    /// Name of the feed.
    feed_name: ?[]const u8 = null,
    /// Latest matched version of package in this Feed.
    latest_matched_version: ?[]const u8 = null,
    /// Latest version of package in this Feed.
    latest_version: ?[]const u8 = null,
    /// Url of package in this Feed.
    package_url: ?[]const u8 = null,
    /// List of views which contain the matched package.
    views: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the matched terms in the field of the package result.
pub const PackageHit = struct {
    /// Reference name of the highlighted field.
    field_reference_name: ?[]const u8 = null,
    /// Matched/highlighted snippets of the field.
    highlights: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a code search request.
pub const CodeSearchRequest = struct {
    /// Filters to be applied. Set it to null if there are no filters to be applied.
    filters: ?std.json.ArrayHashMap([]const []const u8) = null,
    /// The search text.
    search_text: ?[]const u8 = null,
    /// Options for sorting search results. If set to null, the results will be returned sorted by relevance. If more than one sort option is provided, the results are sorted in the order specified in the OrderBy.
    @"$order_by": ?[]const SortOption = null,
    /// Number of results to be skipped.
    @"$skip": ?i32 = null,
    /// Number of results to be returned.
    @"$top": ?i32 = null,
    /// Flag to opt for faceting in the result. Default behavior is false.
    include_facets: ?bool = null,
    /// Flag to opt for including matched code snippet in the result. Default behavior is false.
    include_snippet: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a code search response item.
pub const CodeSearchResponse = struct {
    /// A dictionary storing an array of <code>Filter</code> object against each facet.
    facets: ?std.json.ArrayHashMap([]const Filter) = null,
    /// Numeric code indicating any additional information: 0 - Ok, 1 - Account is being reindexed, 2 - Account indexing has not started, 3 - Invalid Request, 4 - Prefix wildcard query not supported, 5 - MultiWords with code facet not supported, 6 - Account is being onboarded, 7 - Account is being onboarded or reindexed, 8 - Top value trimmed to maxresult allowed 9 - Branches are being indexed, 10 - Faceting not enabled, 11 - Work items not accessible, 19 - Phrase queries with code type filters not supported, 20 - Wildcard queries with code type filters not supported. Any other info code is used for internal purpose.
    info_code: ?i32 = null,
    /// Total number of matched files.
    count: ?i32 = null,
    /// List of matched files.
    results: ?[]const CodeResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the code result containing information of the searched files and its metadata.
pub const CodeResult = struct {
    collection: ?Collection = null,
    /// ContentId of the result file.
    content_id: ?[]const u8 = null,
    /// Name of the result file.
    file_name: ?[]const u8 = null,
    /// Dictionary of field to hit offsets in the result file. Key identifies the area in which hits were found, for ex: file content/file name etc.
    matches: ?std.json.ArrayHashMap([]const Hit) = null,
    /// Path at which result file is present.
    path: ?[]const u8 = null,
    project: ?Project = null,
    repository: ?Repository = null,
    /// Versions of the result file.
    versions: ?[]const Version = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of the collection.
pub const Collection = struct {
    /// Name of the collection.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the position of a piece of text in a document.
pub const Hit = struct {
    /// Gets or sets the start character offset of a piece of text.
    char_offset: ?i32 = null,
    /// Gets or sets an extract of code where the match appears. Usually it is the line where there is the match.
    code_snippet: ?[]const u8 = null,
    /// Gets or sets the column number where the match appears in the line.
    column: ?i32 = null,
    /// Gets or sets the length of a piece of text.
    length: ?i32 = null,
    /// Gets or sets the line number where the match appears in the file.
    line: ?i32 = null,
    /// Gets or sets the name of type of a piece of text.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of the project.
pub const Project = struct {
    /// Id of the project.
    id: ?[]const u8 = null,
    /// Name of the project.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of the repository.
pub const Repository = struct {
    /// Id of the repository.
    id: ?[]const u8 = null,
    /// Name of the repository.
    name: ?[]const u8 = null,
    /// Version control type of the result file.
    type: ?enums.RepositoryType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the details pertaining to a version of the result file.
pub const Version = struct {
    /// Name of the branch.
    branch_name: ?[]const u8 = null,
    /// ChangeId in the given branch associated with this match.
    change_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the repository status.
pub const RepositoryStatusResponse = struct {
    /// Repository Id.
    id: ?[]const u8 = null,
    /// List of Indexed branches info.
    indexed_branches: ?[]const BranchInfo = null,
    /// Repository Name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about the configured branch.
pub const BranchInfo = struct {
    /// Name of the indexed branch
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the TFVC repository status.
pub const TfvcRepositoryStatusResponse = struct {
    /// Repository Id.
    id: ?[]const u8 = null,
    /// List of Indexing Information for TFVC repository
    indexing_information: ?[]const BranchInfo = null,
    /// Repository Name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a wiki search request.
pub const WikiSearchRequest = struct {
    /// Filters to be applied. Set it to null if there are no filters to be applied.
    filters: ?std.json.ArrayHashMap([]const []const u8) = null,
    /// The search text.
    search_text: ?[]const u8 = null,
    /// Options for sorting search results. If set to null, the results will be returned sorted by relevance. If more than one sort option is provided, the results are sorted in the order specified in the OrderBy.
    @"$order_by": ?[]const SortOption = null,
    /// Number of results to be skipped.
    @"$skip": ?i32 = null,
    /// Number of results to be returned.
    @"$top": ?i32 = null,
    /// Flag to opt for faceting in the result. Default behavior is false.
    include_facets: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a wiki search response item.
pub const WikiSearchResponse = struct {
    /// A dictionary storing an array of <code>Filter</code> object against each facet.
    facets: ?std.json.ArrayHashMap([]const Filter) = null,
    /// Numeric code indicating any additional information: 0 - Ok, 1 - Account is being reindexed, 2 - Account indexing has not started, 3 - Invalid Request, 4 - Prefix wildcard query not supported, 5 - MultiWords with code facet not supported, 6 - Account is being onboarded, 7 - Account is being onboarded or reindexed, 8 - Top value trimmed to maxresult allowed 9 - Branches are being indexed, 10 - Faceting not enabled, 11 - Work items not accessible, 19 - Phrase queries with code type filters not supported, 20 - Wildcard queries with code type filters not supported. Any other info code is used for internal purpose.
    info_code: ?i32 = null,
    /// Total number of matched wiki documents.
    count: ?i32 = null,
    /// List of top matched wiki documents.
    results: ?[]const WikiResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the wiki result that matched a wiki search request.
pub const WikiResult = struct {
    collection: ?Collection = null,
    /// ContentId of the result file.
    content_id: ?[]const u8 = null,
    /// Name of the result file.
    file_name: ?[]const u8 = null,
    /// Highlighted snippets of fields that match the search request. The list is sorted by relevance of the snippets.
    hits: ?[]const WikiHit = null,
    /// Path at which result file is present.
    path: ?[]const u8 = null,
    project: ?ProjectReference = null,
    wiki: ?Wiki = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the matched terms in the field of the wiki result.
pub const WikiHit = struct {
    /// Reference name of the highlighted field.
    field_reference_name: ?[]const u8 = null,
    /// Matched/highlighted snippets of the field.
    highlights: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of the project.
pub const ProjectReference = struct {
    /// ID of the project.
    id: ?[]const u8 = null,
    /// Name of the project.
    name: ?[]const u8 = null,
    /// Visibility of the project.
    visibility: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the details of wiki.
pub const Wiki = struct {
    /// Id of the wiki.
    id: ?[]const u8 = null,
    /// Mapped path for the wiki.
    mapped_path: ?[]const u8 = null,
    /// Name of the wiki.
    name: ?[]const u8 = null,
    /// Version for wiki.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a work item search request.
pub const WorkItemSearchRequest = struct {
    /// Filters to be applied. Set it to null if there are no filters to be applied.
    filters: ?std.json.ArrayHashMap([]const []const u8) = null,
    /// The search text.
    search_text: ?[]const u8 = null,
    /// Options for sorting search results. If set to null, the results will be returned sorted by relevance. If more than one sort option is provided, the results are sorted in the order specified in the OrderBy.
    @"$order_by": ?[]const SortOption = null,
    /// Number of results to be skipped.
    @"$skip": ?i32 = null,
    /// Number of results to be returned.
    @"$top": ?i32 = null,
    /// Flag to opt for faceting in the result. Default behavior is false.
    include_facets: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a response item that is returned for a work item search request.
pub const WorkItemSearchResponse = struct {
    /// A dictionary storing an array of <code>Filter</code> object against each facet.
    facets: ?std.json.ArrayHashMap([]const Filter) = null,
    /// Numeric code indicating any additional information: 0 - Ok, 1 - Account is being reindexed, 2 - Account indexing has not started, 3 - Invalid Request, 4 - Prefix wildcard query not supported, 5 - MultiWords with code facet not supported, 6 - Account is being onboarded, 7 - Account is being onboarded or reindexed, 8 - Top value trimmed to maxresult allowed 9 - Branches are being indexed, 10 - Faceting not enabled, 11 - Work items not accessible, 19 - Phrase queries with code type filters not supported, 20 - Wildcard queries with code type filters not supported. Any other info code is used for internal purpose.
    info_code: ?i32 = null,
    /// Total number of matched work items.
    count: ?i32 = null,
    /// List of top matched work items.
    results: ?[]const WorkItemResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the work item result that matched a work item search request.
pub const WorkItemResult = struct {
    /// A standard set of work item fields and their values.
    fields: ?std.json.ArrayHashMap([]const u8) = null,
    /// Highlighted snippets of fields that match the search request. The list is sorted by relevance of the snippets.
    hits: ?[]const WorkItemHit = null,
    project: ?Project = null,
    /// Reference to the work item.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the matched terms in the field of the work item result.
pub const WorkItemHit = struct {
    /// Reference name of the highlighted field.
    field_reference_name: ?[]const u8 = null,
    /// Matched/highlighted snippets of the field.
    highlights: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
