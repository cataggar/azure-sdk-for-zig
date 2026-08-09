//! Generated service clients.

const std = @import("std");
const serde = @import("serde");
const core = @import("azure_sdk_core");
const models = @import("models.zig");
const enums = @import("enums.zig");

// Keep raw-body ownership behind one helper so the generated shape can
// adopt the core streaming response API without changing status/header logic.
fn bufferRawResponseBody(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    return allocator.dupe(u8, body);
}

fn responseStatusExpected(status: u16, expected: []const u16) bool {
    if (expected.len == 0) return status >= 200 and status < 300;
    for (expected) |value| {
        if (status == value) return true;
    }
    return false;
}
const default_endpoint = "https://dev.azure.com";
const default_api_version = "7.2-preview";
const auth_scopes: []const []const u8 = &.{"{endpoint}/.default"};

pub const GitClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    allocator: std.mem.Allocator,
    auth_policy: ?*core.pipeline.BearerTokenAuthPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,

    pub const InitOptions = struct {
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        endpoint: []const u8 = default_endpoint,
        api_version: []const u8 = default_api_version,
    };

    pub const PipelineOptions = struct {
        endpoint: []const u8 = default_endpoint,
        api_version: []const u8 = default_api_version,
    };

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !GitClient {
        const auth_policy = try allocator.create(core.pipeline.BearerTokenAuthPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = core.pipeline.BearerTokenAuthPolicy.init(
            allocator,
            options.credential,
            auth_scopes,
        );

        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = auth_policy.asPolicy();

        return .{
            .allocator = allocator,
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .auth_policy = auth_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = .{
                .policies = policy_ptrs,
                .transport_impl = options.transport,
            },
        };
    }
    pub fn initWithPipeline(
        allocator: std.mem.Allocator,
        pipeline: core.pipeline.HttpPipeline,
        options: PipelineOptions,
    ) GitClient {
        return .{
            .allocator = allocator,
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .auth_policy = null,
            .policy_ptrs = &.{},
            .pipeline = pipeline,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.auth_policy) |auth_policy| {
            auth_policy.deinit();
            self.allocator.destroy(auth_policy);
            self.allocator.free(self.policy_ptrs);
        }
    }

    pub fn repositories(self: *@This()) Repositories {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn refsFavorites(self: *@This()) RefsFavorites {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn refsFavoritesForProject(self: *@This()) RefsFavoritesForProject {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn policyConfigurations(self: *@This()) PolicyConfigurations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequests(self: *@This()) PullRequests {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn annotatedTags(self: *@This()) AnnotatedTags {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn blobs(self: *@This()) Blobs {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn cherryPicks(self: *@This()) CherryPicks {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn commits(self: *@This()) Commits {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn statuses(self: *@This()) Statuses {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn diffs(self: *@This()) Diffs {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn importRequests(self: *@This()) ImportRequests {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn items(self: *@This()) Items {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestQuery(self: *@This()) PullRequestQuery {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestAttachments(self: *@This()) PullRequestAttachments {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestCommits(self: *@This()) PullRequestCommits {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestIterations(self: *@This()) PullRequestIterations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestIterationChanges(self: *@This()) PullRequestIterationChanges {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestIterationStatuses(self: *@This()) PullRequestIterationStatuses {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestLabels(self: *@This()) PullRequestLabels {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestProperties(self: *@This()) PullRequestProperties {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestReviewers(self: *@This()) PullRequestReviewers {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestShare(self: *@This()) PullRequestShare {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestStatuses(self: *@This()) PullRequestStatuses {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestThreads(self: *@This()) PullRequestThreads {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestThreadComments(self: *@This()) PullRequestThreadComments {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestCommentLikes(self: *@This()) PullRequestCommentLikes {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pullRequestWorkItems(self: *@This()) PullRequestWorkItems {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pushes(self: *@This()) Pushes {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn refs(self: *@This()) Refs {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn reverts(self: *@This()) Reverts {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn stats(self: *@This()) Stats {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn suggestions(self: *@This()) Suggestions {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn trees(self: *@This()) Trees {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn mergeBases(self: *@This()) MergeBases {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn forks(self: *@This()) Forks {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn merges(self: *@This()) Merges {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const Repositories = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve deleted git repositories.
    pub fn getDeletedRepositories(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8) ![]const models.GitDeletedRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/deletedrepositories", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.getDeletedRepositories", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitDeletedRepository, alloc, resp.body);
    }
    /// Retrieve soft-deleted git repositories from the recycle bin.
    pub fn getRecycleBinRepositories(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8) ![]const models.GitDeletedRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/recycleBin/repositories", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.getRecycleBinRepositories", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitDeletedRepository, alloc, resp.body);
    }
    /// Destroy (hard delete) a soft-deleted Git repository.
    pub fn deleteRepositoryFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/recycleBin/repositories/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.deleteRepositoryFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Recover a soft-deleted Git repository. Recently deleted repositories go into a soft-delete state for a period of time before they are hard deleted and become unrecoverable.
    pub fn restoreRepositoryFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, body: models.GitRecycleBinRepositoryDetails) !models.GitRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/recycleBin/repositories/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.restoreRepositoryFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRepository, alloc, resp.body);
    }
    /// Retrieve git repositories.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, include_links: ?bool, include_all_urls: ?bool, include_hidden: ?bool) ![]const models.GitRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_all_urls) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAllUrls={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_hidden) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeHidden={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRepository, alloc, resp.body);
    }
    /// Create a git repository in a team project.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, source_ref: ?[]const u8, body: models.GitRepositoryCreateOptions) !models.GitRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (source_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}sourceRef={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{201})) {
            core.pager.logHttpError("Repositories.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRepository, alloc, resp.body);
    }
    /// Delete a git repository
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Retrieve a git repository.
    pub fn getRepository(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8) !models.GitRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.getRepository", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRepository, alloc, resp.body);
    }
    /// Updates the Git repository with either a new repo name or a new default branch.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, body: models.GitRepository) !models.GitRepository {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Repositories.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRepository, alloc, resp.body);
    }
};

pub const RefsFavorites = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Gets the refs favorites for a repo and an identity.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: ?[]const u8, identity_id: ?[]const u8) ![]const models.GitRefFavorite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/favorites/refs", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}repositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (identity_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}identityId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("RefsFavorites.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRefFavorite, alloc, resp.body);
    }
    /// Creates a ref favorite
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.GitRefFavorite) !models.GitRefFavorite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/favorites/refs", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("RefsFavorites.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRefFavorite, alloc, resp.body);
    }
    /// Deletes the refs favorite specified
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, favorite_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, favorite_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/favorites/refs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("RefsFavorites.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Gets the refs favorite for a favorite Id.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, favorite_id: i32) !models.GitRefFavorite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, favorite_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/favorites/refs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("RefsFavorites.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRefFavorite, alloc, resp.body);
    }
};

pub const RefsFavoritesForProject = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, identity_id: ?[]const u8) ![]const models.GitRefFavorite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/favorites/refsForProject", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (identity_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}identityId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("RefsFavoritesForProject.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRefFavorite, alloc, resp.body);
    }
};

pub const PolicyConfigurations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                x_ms_continuationtoken: ?[]const u8 = null,
            },
            body: []const models.PolicyConfiguration,
        },
    };
    /// Retrieve a list of policy configurations by a given set of scope/filtering criteria. Azure Repos uses two types of policies to protect your code: **Repository policies (push policies)** check every push to your repository. They validate things like file size limits, path restrictions, or commit requirements. When someone pushes code that violates these rules, the push gets rejected - no matter which branch they're pushing to. **Branch policies (PR policies)** protect specific branches by requiring pull requests. When you set a branch policy on `main`, for example, nobody can push directly to `main` anymore. They must create a pull request instead, which can then require reviews, builds, or other checks to pass first. ## How Policies Work with Your Project Structure Both types of policies can be defined at different levels in your project hierarchy. A policy defined at the project level affects all repositories in that project. A policy defined at the repository level affects just that repository. A branch policy can even be defined at the project level to protect all branches with the same name - like protecting all `main` branches across your entire project with one policy. ### Branch Patterns and Wildcards Branches in Git follow a folder-like structure. You might have branches like: - `refs/heads/main` - `refs/heads/releases/1.0.0` - `refs/heads/releases/2.0.0` - `refs/heads/features/new-login` You can create policies for specific branches or for groups of branches using wildcards. When you create a policy for `refs/heads/releases/*`, it protects all branches in the `releases` 'folder' - both the ones that exist now and any new release branches you create later. This pattern matching works recursively, so `refs/heads/releases/*` also covers branches like `refs/heads/releases/v1/hotfix`. This helps you set up consistent protection without creating the same policy over and over. For example, you can require two reviewers for all release branches with just one policy. ## Understanding Policy Inheritance When you query for policies, this endpoint shows you what policies are actually enforcing rules at your specified scope. This includes policies inherited from higher levels. For example, if you query for policies on a specific branch, you get: - Branch policies for that exact branch - Branch policies with wildcards that match your branch - Repository policies for that repo - Any applicable project-level policies Everything that protects that branch shows up in your results. ## How to Query for Policies The `repositoryId` and `refName` parameters let you focus on specific parts of your project. Here's what you get with different combinations: **Both `repositoryId` and `refName` specified:** - When `refName` is a specific branch name: You see all policies affecting that specific branch. This includes exact branch policies, wildcard branch policies that match, repository policies for that repo, and any project-level policies. - When `refName` is `~all`: You see every policy that affects any branch in that repository. This special value gives you the same results as if you called this API once for every single branch in the repo and then combined all the results (removing duplicates). You get all branch-specific policies, all wildcard policies, all repository policies, and all inherited project-level policies that apply to this repository. This helps you see the complete picture of what protects all your branches without making multiple API calls. **Only `repositoryId` specified:** You see policies that apply to the repository as a whole - repository policies and inherited project-level repository policies. Branch policies aren't included because they don't affect the whole repository. **Neither parameter specified:** You see only project-level repository policies. Branch policies defined at the project level aren't included, even though they exist at the project level. This happens because branch policies need a branch context to be meaningful - without specifying a repository or branch name, the API only returns policies that apply to repositories as a whole. **Only `refName` specified:** You see project-level branch policies for branches with that name (like all `main` branch policies defined at project level), plus project-level repository policies. You can add the `policyType` parameter to filter for a specific type of policy, such as 'Minimum number of reviewers' or 'File size restriction'. This parameter accepts the policy type ID and filters the results to show only that specific policy type. ## Common Scenarios - **'What protects my main branch?'** - Use `repositoryId` + `refName=refs/heads/main` - **'What protects all my release branches?'** - Use `repositoryId` + `refName=refs/heads/releases/*` - **'Show me every policy that affects any branch in this repository'** - Use `repositoryId` + `refName=~all` - **'What repository policies apply to this repo?'** - Use `repositoryId` only - **'What file size limits apply to this repository?'** - Use `repositoryId` with the `policyType` for file size restrictions - **'What project-wide repository policies do we have?'** - Don't specify `repositoryId` or `refName` - **'Which policies apply to develop branches across all repositories?'** - Use `refName=refs/heads/develop`
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: ?[]const u8, ref_name: ?[]const u8, policy_type: ?[]const u8, @"$top": ?i32, continuation_token: ?[]const u8) !GetResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/policy/configurations", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}repositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}refName={s}", .{ sep, enc });
            has_query = true;
        }
        if (policy_type) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}policyType={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_5 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_5);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_5 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-continuationtoken")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice([]const models.PolicyConfiguration, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .x_ms_continuationtoken = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("PolicyConfigurations.get", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const PullRequests = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve all pull requests matching a specified criteria. Please note that description field will be truncated up to 400 symbols in the result.
    pub fn getPullRequestsByProject(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, search_criteria_creator_id: ?[]const u8, search_criteria_include_links: ?bool, search_criteria_labels: ?[]const []const u8, search_criteria_max_time: ?[]const u8, search_criteria_min_time: ?[]const u8, @"search_criteria.query_time_range_type": ?enums.GetPullRequestsByProjectRequestSearchCriteriaQueryTimeRangeType, search_criteria_repository_id: ?[]const u8, search_criteria_reviewer_id: ?[]const u8, search_criteria_source_ref_name: ?[]const u8, search_criteria_source_repository_id: ?[]const u8, @"search_criteria.status": ?enums.GetPullRequestsByProjectRequestSearchCriteriaStatus, @"search_criteria.tags_filter_operator": ?enums.GetPullRequestsByProjectRequestSearchCriteriaTagsFilterOperator, search_criteria_target_ref_name: ?[]const u8, search_criteria_title: ?[]const u8, max_comment_length: ?i32, @"$skip": ?i32, @"$top": ?i32) ![]const models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/pullrequests", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (search_criteria_creator_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.creatorId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}searchCriteria.includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (search_criteria_labels) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item);
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}searchCriteria.labels={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (search_criteria_max_time) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.maxTime={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_min_time) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.minTime={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.query_time_range_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.queryTimeRangeType={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.repositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_reviewer_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.reviewerId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_source_ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.sourceRefName={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_source_repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.sourceRepositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.status") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.status={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.tags_filter_operator") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.tagsFilterOperator={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_target_ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.targetRefName={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_title) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.title={s}", .{ sep, enc });
            has_query = true;
        }
        if (max_comment_length) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxCommentLength={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_17 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_17);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_17 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.getPullRequestsByProject", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequest, alloc, resp.body);
    }
    /// Retrieve a pull request.
    pub fn getPullRequestById(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, pull_request_id: i32, project: []const u8) !models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/pullrequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.getPullRequestById", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequest, alloc, resp.body);
    }
    /// Retrieve all pull requests matching a specified criteria. Please note that description field will be truncated up to 400 symbols in the result.
    pub fn getPullRequests(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, search_criteria_creator_id: ?[]const u8, search_criteria_include_links: ?bool, search_criteria_labels: ?[]const []const u8, search_criteria_max_time: ?[]const u8, search_criteria_min_time: ?[]const u8, @"search_criteria.query_time_range_type": ?enums.GetPullRequestsRequestSearchCriteriaQueryTimeRangeType, search_criteria_repository_id: ?[]const u8, search_criteria_reviewer_id: ?[]const u8, search_criteria_source_ref_name: ?[]const u8, search_criteria_source_repository_id: ?[]const u8, @"search_criteria.status": ?enums.GetPullRequestsRequestSearchCriteriaStatus, @"search_criteria.tags_filter_operator": ?enums.GetPullRequestsRequestSearchCriteriaTagsFilterOperator, search_criteria_target_ref_name: ?[]const u8, search_criteria_title: ?[]const u8, max_comment_length: ?i32, @"$skip": ?i32, @"$top": ?i32) ![]const models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullrequests", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (search_criteria_creator_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.creatorId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}searchCriteria.includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (search_criteria_labels) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item);
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}searchCriteria.labels={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (search_criteria_max_time) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.maxTime={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_min_time) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.minTime={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.query_time_range_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.queryTimeRangeType={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.repositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_reviewer_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.reviewerId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_source_ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.sourceRefName={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_source_repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.sourceRepositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.status") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.status={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"search_criteria.tags_filter_operator") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.tagsFilterOperator={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_target_ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.targetRefName={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_title) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.title={s}", .{ sep, enc });
            has_query = true;
        }
        if (max_comment_length) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxCommentLength={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_17 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_17);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_17 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.getPullRequests", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequest, alloc, resp.body);
    }
    /// Create a pull request.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, supports_iterations: ?bool, body: models.GitPullRequest) !models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullrequests", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (supports_iterations) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}supportsIterations={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequest, alloc, resp.body);
    }
    /// Retrieve a pull request.
    pub fn getPullRequest(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, max_comment_length: ?i32, @"$skip": ?i32, @"$top": ?i32, include_commits: ?bool, include_work_item_refs: ?bool) !models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullrequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (max_comment_length) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxCommentLength={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_commits) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeCommits={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_work_item_refs) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeWorkItemRefs={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_5 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_5);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_5 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.getPullRequest", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequest, alloc, resp.body);
    }
    /// Update a pull request These are the properties that can be updated with the API: - Status - Title - Description (up to 4000 characters) - CompletionOptions - MergeOptions - AutoCompleteSetBy.Id - TargetRefName (when the PR retargeting feature is enabled) Attempting to update other properties outside of this list will either cause the server to throw an `InvalidArgumentValueException`, or to silently ignore the update.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.GitPullRequest) !models.GitPullRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullrequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequests.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequest, alloc, resp.body);
    }
};

pub const AnnotatedTags = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Create an annotated tag. Repositories have both a name and an identifier. Identifiers are globally unique, but several projects may contain a repository of the same name. You don't need to include the project if you specify a repository by ID. However, if you specify a repository by name, you must also specify the project (by name or ID).
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, body: models.GitAnnotatedTag) !models.GitAnnotatedTag {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/annotatedtags", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("AnnotatedTags.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitAnnotatedTag, alloc, resp.body);
    }
    /// Get an annotated tag. Repositories have both a name and an identifier. Identifiers are globally unique, but several projects may contain a repository of the same name. You don't need to include the project if you specify a repository by ID. However, if you specify a repository by name, you must also specify the project (by name or ID).
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, object_id: []const u8) !models.GitAnnotatedTag {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, object_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/annotatedtags/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("AnnotatedTags.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitAnnotatedTag, alloc, resp.body);
    }
};

pub const Blobs = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetBlobsZipResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const GetBlobResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: models.GitBlobRef,
        },
    };
    /// Gets one or more blobs in a zip file download.
    pub fn getBlobsZip(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, filename: ?[]const u8, body: []const []const u8) !GetBlobsZipResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/blobs", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (filename) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}filename={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/zip");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_type = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Blobs.getBlobsZip", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get a single blob. Repositories have both a name and an identifier. Identifiers are globally unique, but several projects may contain a repository of the same name. You don't need to include the project if you specify a repository by ID. However, if you specify a repository by name, you must also specify the project (by name or ID).
    pub fn getBlob(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, sha1: []const u8, project: []const u8, download: ?bool, file_name: ?[]const u8, @"$format": ?[]const u8, resolve_lfs: ?bool) !GetBlobResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, sha1);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (download) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}download={}", .{ sep, query_value });
            has_query = true;
        }
        if (file_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}fileName={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        if (resolve_lfs) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}resolveLfs={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_4 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_4);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_4 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json, application/zip, application/octet-stream");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_body = try serde.json.fromSlice(models.GitBlobRef, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_type = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Blobs.getBlob", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const CherryPicks = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve information about a cherry pick operation for a specific branch. This operation is expensive due to the underlying object structure, so this API only looks at the 1000 most recent cherry pick operations.
    pub fn getCherryPickForRefName(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, ref_name: []const u8) !models.GitCherryPick {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/cherryPicks", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, ref_name);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}refName={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("CherryPicks.getCherryPickForRefName", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCherryPick, alloc, resp.body);
    }
    /// Cherry pick a specific commit or commits that are associated to a pull request into a new branch.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, body: models.GitAsyncRefOperationParameters) !models.GitCherryPick {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/cherryPicks", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("CherryPicks.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCherryPick, alloc, resp.body);
    }
    /// Retrieve information about a cherry pick operation by cherry pick Id.
    pub fn getCherryPick(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, cherry_pick_id: i32, repository_id: []const u8) !models.GitCherryPick {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, cherry_pick_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/cherryPicks/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("CherryPicks.getCherryPick", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCherryPick, alloc, resp.body);
    }
};

pub const Commits = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve a list of commits associated with a particular push.
    pub fn getPushCommits(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, push_id: i32, project: []const u8, top: ?i32, skip: ?i32, include_links: ?bool) ![]const models.GitCommitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}pushId={d}", .{ if (has_query) "&" else "?", push_id });
        has_query = true;
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (skip) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_4 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_4);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_4 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Commits.getPushCommits", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitCommitRef, alloc, resp.body);
    }
    /// Retrieve a particular commit.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, commit_id: []const u8, repository_id: []const u8, project: []const u8, change_count: ?i32) !models.GitCommit {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, commit_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (change_count) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}changeCount={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Commits.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCommit, alloc, resp.body);
    }
    /// Retrieve changes for a particular commit.
    pub fn getChanges(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, commit_id: []const u8, repository_id: []const u8, project: []const u8, top: ?i32, skip: ?i32) !models.GitCommitChanges {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, commit_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits/{s}/changes", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (skip) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}skip={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Commits.getChanges", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCommitChanges, alloc, resp.body);
    }
    /// Retrieve git commits for a project matching the search criteria
    pub fn getCommitsBatch(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, @"$skip": ?i32, @"$top": ?i32, include_statuses: ?bool, body: models.GitQueryCommitsCriteria) ![]const models.GitCommitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commitsbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_statuses) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeStatuses={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Commits.getCommitsBatch", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitCommitRef, alloc, resp.body);
    }
};

pub const Statuses = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get statuses associated with the Git commit.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, commit_id: []const u8, repository_id: []const u8, project: []const u8, top: ?i32, skip: ?i32, latest_only: ?bool) ![]const models.GitStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, commit_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (skip) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (latest_only) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}latestOnly={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Statuses.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitStatus, alloc, resp.body);
    }
    /// Create Git commit status.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, commit_id: []const u8, repository_id: []const u8, project: []const u8, body: models.GitStatus) !models.GitStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, commit_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Statuses.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitStatus, alloc, resp.body);
    }
};

pub const Diffs = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Find the closest common commit (the merge base) between base and target commits, and get the diff between either the base and target commits or common and target commits.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, diff_common_commit: ?bool, @"$top": ?i32, @"$skip": ?i32, base_version: ?[]const u8, base_version_options: ?enums.GetRequestBaseVersionOptions, base_version_type: ?enums.GetRequestBaseVersionType, target_version: ?[]const u8, target_version_options: ?enums.GetRequestTargetVersionOptions, target_version_type: ?enums.GetRequestTargetVersionType) !models.GitCommitDiffs {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/diffs/commits", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (diff_common_commit) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}diffCommonCommit={}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (base_version) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersion={s}", .{ sep, enc });
            has_query = true;
        }
        if (base_version_options) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersionOptions={s}", .{ sep, enc });
            has_query = true;
        }
        if (base_version_type) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersionType={s}", .{ sep, enc });
            has_query = true;
        }
        if (target_version) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}targetVersion={s}", .{ sep, enc });
            has_query = true;
        }
        if (target_version_options) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}targetVersionOptions={s}", .{ sep, enc });
            has_query = true;
        }
        if (target_version_type) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}targetVersionType={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_9 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_9);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_9 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Diffs.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitCommitDiffs, alloc, resp.body);
    }
};

pub const ImportRequests = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve import requests for a repository.
    pub fn query(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, include_abandoned: ?bool) ![]const models.GitImportRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/importRequests", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_abandoned) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAbandoned={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ImportRequests.query", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitImportRequest, alloc, resp.body);
    }
    /// Create an import request.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, body: models.GitImportRequest) !models.GitImportRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/importRequests", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ImportRequests.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitImportRequest, alloc, resp.body);
    }
    /// Retrieve a particular import request.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, import_request_id: i32) !models.GitImportRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, import_request_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/importRequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ImportRequests.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitImportRequest, alloc, resp.body);
    }
    /// Retry or abandon a failed import request. There can only be one active import request associated with a repository. Marking a failed import request abandoned makes it inactive.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, import_request_id: i32, body: models.GitImportRequest) !models.GitImportRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, import_request_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/importRequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ImportRequests.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitImportRequest, alloc, resp.body);
    }
};

pub const Items = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get Item Metadata and/or Content for a collection of items. The download parameter is to indicate whether the content should be available as a download or just sent as a stream in the response. Doesn't apply to zipped content which is always returned as a download.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, scope_path: ?[]const u8, recursion_level: ?enums.ListRequestRecursionLevel, include_content_metadata: ?bool, latest_processed_change: ?bool, download: ?bool, include_links: ?bool, @"$format": ?[]const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.ListRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.ListRequestVersionDescriptorVersionType, zip_for_unix: ?bool) ![]const models.GitItem {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/items", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (scope_path) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}scopePath={s}", .{ sep, enc });
            has_query = true;
        }
        if (recursion_level) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}recursionLevel={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_content_metadata) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeContentMetadata={}", .{ sep, query_value });
            has_query = true;
        }
        if (latest_processed_change) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}latestProcessedChange={}", .{ sep, query_value });
            has_query = true;
        }
        if (download) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}download={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_descriptor_version) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionDescriptor.version={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"version_descriptor.version_options") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionDescriptor.versionOptions={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"version_descriptor.version_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionDescriptor.versionType={s}", .{ sep, enc });
            has_query = true;
        }
        if (zip_for_unix) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}zipForUnix={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_11 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_11);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_11 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Items.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitItem, alloc, resp.body);
    }
    /// Retrieves a batch of items in a repo / project for a given list of paths or a long path
    pub fn getItemsBatch(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, body: models.GitItemRequestData) ![]const []const models.JsonValue {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/itemsbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Items.getItemsBatch", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const []const models.JsonValue, alloc, resp.body);
    }
};

pub const PullRequestQuery = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// This API is used to find what pull requests are related to a given commit. It can be used to either find the pull request that created a particular merge commit or it can be used to find all pull requests that have ever merged a particular commit. The input is a list of queries which each contain a list of commits. For each commit that you search against, you will get back a dictionary of commit -> pull requests.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, body: models.GitPullRequestQuery) !models.GitPullRequestQuery {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullrequestquery", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestQuery.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestQuery, alloc, resp.body);
    }
};

pub const PullRequestAttachments = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Get a list of files attached to a given pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) ![]const models.Attachment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestAttachments.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.Attachment, alloc, resp.body);
    }
    /// Delete a pull request attachment.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, file_name: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, file_name);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/attachments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_2, encoded_path_3, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestAttachments.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get the file content of a pull request attachment.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, file_name: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) !GetResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, file_name);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/attachments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_2, encoded_path_3, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/octet-stream, application/zip");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_type = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("PullRequestAttachments.get", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Attach a new file to a pull request.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, file_name: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: []const u8) !models.Attachment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, file_name);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/attachments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_2, encoded_path_3, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("content-type", "application/octet-stream");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{ 201, 202 })) {
            core.pager.logHttpError("PullRequestAttachments.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Attachment, alloc, resp.body);
    }
};

pub const PullRequestCommits = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get the commits for the specified pull request.
    pub fn getPullRequestCommits(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, @"$top": ?i32, continuation_token: ?[]const u8) ![]const models.GitCommitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/commits", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestCommits.getPullRequestCommits", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitCommitRef, alloc, resp.body);
    }
    /// Get the commits for the specified iteration of a pull request.
    pub fn getPullRequestIterationCommits(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8, top: ?i32, skip: ?i32) ![]const models.GitCommitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/commits", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (skip) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}skip={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestCommits.getPullRequestIterationCommits", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitCommitRef, alloc, resp.body);
    }
};

pub const PullRequestIterations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get the list of iterations for the specified pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, include_commits: ?bool) ![]const models.GitPullRequestIteration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_commits) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeCommits={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterations.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequestIteration, alloc, resp.body);
    }
    /// Get the specified iteration for a pull request.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8) !models.GitPullRequestIteration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterations.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestIteration, alloc, resp.body);
    }
};

pub const PullRequestIterationChanges = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve the changes made in a pull request between two iterations.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8, @"$top": ?i32, @"$skip": ?i32, @"$compare_to": ?i32) !models.GitPullRequestIterationChanges {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/changes", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$compare_to") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$compareTo={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationChanges.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestIterationChanges, alloc, resp.body);
    }
};

pub const PullRequestIterationStatuses = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get all the statuses associated with a pull request iteration.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8) ![]const models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationStatuses.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequestStatus, alloc, resp.body);
    }
    /// Update pull request iteration statuses collection. The only supported operation type is `remove`. This operation allows to delete multiple statuses in one call. The path of the `remove` operation should refer to the ID of the pull request status. For example `path='/1'` refers to the pull request status with ID 1.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8, body: models.JsonPatchDocument) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("content-type", "application/json-patch+json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationStatuses.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Create a pull request status on the iteration. This operation will have the same result as Create status on pull request with specified iteration ID in the request body. The only required field for the status is `Context.Name` that uniquely identifies the status. Note that `iterationId` in the request body is optional since `iterationId` can be specified in the URL. A conflict between `iterationId` in the URL and `iterationId` in the request body will result in status code 400.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, project: []const u8, body: models.GitPullRequestStatus) !models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationStatuses.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestStatus, alloc, resp.body);
    }
    /// Delete pull request iteration status. You can remove multiple statuses in one call by using Update operation.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, status_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, status_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/statuses/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationStatuses.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get the specific pull request iteration status by ID. The status ID is unique within the pull request across all iterations.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, iteration_id: i32, status_id: i32, project: []const u8) !models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, status_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/iterations/{s}/statuses/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestIterationStatuses.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestStatus, alloc, resp.body);
    }
};

pub const PullRequestLabels = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get all the labels (tags) assigned to a pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, project_id: ?[]const u8) ![]const models.WebApiTagDefinition {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/labels", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestLabels.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.WebApiTagDefinition, alloc, resp.body);
    }
    /// Create a tag (if that does not exists yet) and add that as a label (tag) for a specified pull request. The only required field is the name of the new label (tag).
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, project_id: ?[]const u8, body: models.WebApiCreateTagRequestData) !models.WebApiTagDefinition {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/labels", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestLabels.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WebApiTagDefinition, alloc, resp.body);
    }
    /// Removes a label (tag) from the set of those assigned to the pull request. The tag itself will not be deleted.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, label_id_or_name: []const u8, project: []const u8, project_id: ?[]const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, label_id_or_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/labels/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestLabels.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Retrieves a single label (tag) that has been assigned to a pull request.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, label_id_or_name: []const u8, project: []const u8, project_id: ?[]const u8) !models.WebApiTagDefinition {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, label_id_or_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/labels/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestLabels.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WebApiTagDefinition, alloc, resp.body);
    }
};

pub const PullRequestProperties = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get external properties of the pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) !models.PropertiesCollection {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/properties", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestProperties.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.PropertiesCollection, alloc, resp.body);
    }
    /// Create or update pull request external properties. The patch operation can be `add`, `replace` or `remove`. For `add` operation, the path can be empty. If the path is empty, the value must be a list of key value pairs. For `replace` operation, the path cannot be empty. If the path does not exist, the property will be added to the collection. For `remove` operation, the path cannot be empty. If the path does not exist, no action will be performed.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.JsonPatchDocument) !models.PropertiesCollection {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/properties", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("content-type", "application/json-patch+json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestProperties.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.PropertiesCollection, alloc, resp.body);
    }
};

pub const PullRequestReviewers = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve the reviewers for a pull request
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) ![]const models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.IdentityRefWithVote, alloc, resp.body);
    }
    /// Reset the votes of multiple reviewers on a pull request. NOTE: This endpoint only supports updating votes, but does not support updating required reviewers (use policy) or display names.
    pub fn updatePullRequestReviewers(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: []const models.IdentityRefWithVote) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.updatePullRequestReviewers", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Add reviewers to a pull request.
    pub fn createPullRequestReviewers(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: []const models.IdentityRef) ![]const models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.createPullRequestReviewers", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.IdentityRefWithVote, alloc, resp.body);
    }
    /// Add an unmaterialized identity to the reviewers of a pull request.
    pub fn createUnmaterializedPullRequestReviewer(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.IdentityRefWithVote) !models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.createUnmaterializedPullRequestReviewer", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.IdentityRefWithVote, alloc, resp.body);
    }
    /// Remove a reviewer from a pull request.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, reviewer_id: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, reviewer_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Retrieve information about a particular reviewer on a pull request
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, reviewer_id: []const u8, project: []const u8) !models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, reviewer_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.IdentityRefWithVote, alloc, resp.body);
    }
    /// Edit a reviewer entry. These fields are patchable: isFlagged, hasDeclined
    pub fn updatePullRequestReviewer(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, reviewer_id: []const u8, project: []const u8, body: models.IdentityRefWithVote) !models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, reviewer_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.updatePullRequestReviewer", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.IdentityRefWithVote, alloc, resp.body);
    }
    /// Add a reviewer to a pull request or cast a vote.
    pub fn createPullRequestReviewer(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, reviewer_id: []const u8, project: []const u8, body: models.IdentityRefWithVote) !models.IdentityRefWithVote {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, reviewer_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/reviewers/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestReviewers.createPullRequestReviewer", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.IdentityRefWithVote, alloc, resp.body);
    }
};

pub const PullRequestShare = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Sends an e-mail notification about a specific pull request to a set of recipients
    pub fn sharePullRequest(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.ShareNotificationContext) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/share", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestShare.sharePullRequest", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const PullRequestStatuses = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get all the statuses associated with a pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) ![]const models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestStatuses.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequestStatus, alloc, resp.body);
    }
    /// Update pull request statuses collection. The only supported operation type is `remove`. This operation allows to delete multiple statuses in one call. The path of the `remove` operation should refer to the ID of the pull request status. For example `path='/1'` refers to the pull request status with ID 1.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.JsonPatchDocument) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("content-type", "application/json-patch+json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestStatuses.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Create a pull request status. The only required field for the status is `Context.Name` that uniquely identifies the status. Note that you can specify iterationId in the request body to post the status on the iteration.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.GitPullRequestStatus) !models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/statuses", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestStatuses.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestStatus, alloc, resp.body);
    }
    /// Delete pull request status. You can remove multiple statuses in one call by using Update operation.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, status_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, status_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/statuses/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestStatuses.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get the specific pull request status by ID. The status ID is unique within the pull request across all iterations.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, status_id: i32, project: []const u8) !models.GitPullRequestStatus {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, status_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/statuses/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestStatuses.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestStatus, alloc, resp.body);
    }
};

pub const PullRequestThreads = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve all threads in a pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, @"$iteration": ?i32, @"$base_iteration": ?i32) ![]const models.GitPullRequestCommentThread {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$iteration") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$iteration={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$base_iteration") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$baseIteration={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreads.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPullRequestCommentThread, alloc, resp.body);
    }
    /// Create a thread in a pull request.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8, body: models.GitPullRequestCommentThread) !models.GitPullRequestCommentThread {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreads.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestCommentThread, alloc, resp.body);
    }
    /// Retrieve a thread in a pull request.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, project: []const u8, @"$iteration": ?i32, @"$base_iteration": ?i32) !models.GitPullRequestCommentThread {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$iteration") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$iteration={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$base_iteration") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$baseIteration={d}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreads.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestCommentThread, alloc, resp.body);
    }
    /// Update a thread in a pull request.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, project: []const u8, body: models.GitPullRequestCommentThread) !models.GitPullRequestCommentThread {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreads.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPullRequestCommentThread, alloc, resp.body);
    }
};

pub const PullRequestThreadComments = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve all comments associated with a specific thread in a pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, project: []const u8) ![]const models.Comment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreadComments.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.Comment, alloc, resp.body);
    }
    /// Create a comment on a specific thread in a pull request (up to 500 comments can be created per thread).
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, project: []const u8, body: models.Comment) !models.Comment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreadComments.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Comment, alloc, resp.body);
    }
    /// Delete a comment associated with a specific thread in a pull request.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreadComments.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Retrieve a comment associated with a specific thread in a pull request.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8) !models.Comment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreadComments.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Comment, alloc, resp.body);
    }
    /// Update a comment associated with a specific thread in a pull request.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8, body: models.Comment) !models.Comment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestThreadComments.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Comment, alloc, resp.body);
    }
};

pub const PullRequestCommentLikes = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Delete a like on a comment.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}/likes", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestCommentLikes.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get likes for a comment.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8) ![]const models.IdentityRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}/likes", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestCommentLikes.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.IdentityRef, alloc, resp.body);
    }
    /// Add a like on a comment.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, thread_id: i32, comment_id: i32, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, thread_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, comment_id);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/threads/{s}/comments/{s}/likes", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestCommentLikes.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const PullRequestWorkItems = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve a list of work items associated with a pull request.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, pull_request_id: i32, project: []const u8) ![]const models.ResourceRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, pull_request_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pullRequests/{s}/workitems", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("PullRequestWorkItems.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.ResourceRef, alloc, resp.body);
    }
};

pub const Pushes = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieves pushes associated with the specified repository.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, @"$skip": ?i32, @"$top": ?i32, search_criteria_from_date: ?[]const u8, search_criteria_include_links: ?bool, search_criteria_include_ref_updates: ?bool, search_criteria_pusher_id: ?[]const u8, search_criteria_ref_name: ?[]const u8, search_criteria_to_date: ?[]const u8) ![]const models.GitPush {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pushes", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$skip") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$skip={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (search_criteria_from_date) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.fromDate={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}searchCriteria.includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (search_criteria_include_ref_updates) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}searchCriteria.includeRefUpdates={}", .{ sep, query_value });
            has_query = true;
        }
        if (search_criteria_pusher_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.pusherId={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_ref_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.refName={s}", .{ sep, enc });
            has_query = true;
        }
        if (search_criteria_to_date) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}searchCriteria.toDate={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_8 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_8);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_8 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Pushes.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitPush, alloc, resp.body);
    }
    /// Push changes to the repository.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, body: models.GitPush) !models.GitPush {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pushes", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Pushes.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPush, alloc, resp.body);
    }
    /// Retrieves a particular push.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, push_id: i32, project: []const u8, include_commits: ?i32, include_ref_updates: ?bool) !models.GitPush {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, push_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/pushes/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_commits) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeCommits={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_ref_updates) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeRefUpdates={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Pushes.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitPush, alloc, resp.body);
    }
};

pub const Refs = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Queries the provided repository for its refs and returns them.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, filter: ?[]const u8, include_links: ?bool, include_statuses: ?bool, include_my_branches: ?bool, latest_statuses_only: ?bool, peel_tags: ?bool, filter_contains: ?[]const u8, @"$top": ?i32, continuation_token: ?[]const u8, include_target_branches: ?bool) ![]const models.GitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/refs", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (filter) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}filter={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_statuses) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeStatuses={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_my_branches) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeMyBranches={}", .{ sep, query_value });
            has_query = true;
        }
        if (latest_statuses_only) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}latestStatusesOnly={}", .{ sep, query_value });
            has_query = true;
        }
        if (peel_tags) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}peelTags={}", .{ sep, query_value });
            has_query = true;
        }
        if (filter_contains) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}filterContains={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_target_branches) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeTargetBranches={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_10 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_10);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_10 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Refs.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRef, alloc, resp.body);
    }
    /// Lock or Unlock a branch.
    pub fn updateRef(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, filter: []const u8, project: []const u8, project_id: ?[]const u8, body: models.GitRefUpdate) !models.GitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/refs", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, filter);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}filter={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Refs.updateRef", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRef, alloc, resp.body);
    }
    /// Creating, updating, or deleting refs(branches). Updating a ref means making it point at a different commit than it used to. You must specify both the old and new commit to avoid race conditions.
    pub fn updateRefs(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, project_id: ?[]const u8, body: []const models.GitRefUpdate) ![]const models.GitRefUpdateResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/refs", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Refs.updateRefs", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRefUpdateResult, alloc, resp.body);
    }
};

pub const Reverts = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve information about a revert operation for a specific branch.
    pub fn getRevertForRefName(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, ref_name: []const u8) !models.GitRevert {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/reverts", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, ref_name);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}refName={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Reverts.getRevertForRefName", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRevert, alloc, resp.body);
    }
    /// Starts the operation to create a new branch which reverts changes introduced by either a specific commit or commits that are associated to a pull request.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_id: []const u8, body: models.GitAsyncRefOperationParameters) !models.GitRevert {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/reverts", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Reverts.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRevert, alloc, resp.body);
    }
    /// Retrieve information about a revert operation by revert Id.
    pub fn getRevert(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, revert_id: i32, repository_id: []const u8) !models.GitRevert {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, revert_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/reverts/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Reverts.getRevert", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitRevert, alloc, resp.body);
    }
};

pub const Stats = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve statistics about all branches within a repository.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, base_version_descriptor_version: ?[]const u8, @"base_version_descriptor.version_options": ?enums.ListRequestBaseVersionDescriptorVersionOptions, @"base_version_descriptor.version_type": ?enums.ListRequestBaseVersionDescriptorVersionType) ![]const models.GitBranchStats {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/stats/branches", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (base_version_descriptor_version) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersionDescriptor.version={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"base_version_descriptor.version_options") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersionDescriptor.versionOptions={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"base_version_descriptor.version_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}baseVersionDescriptor.versionType={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Stats.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitBranchStats, alloc, resp.body);
    }
};

pub const Suggestions = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve a pull request suggestion for a particular repository or team project.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, project: []const u8, prefer_compare_branch: ?bool) ![]const models.GitSuggestion {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/suggestions", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (prefer_compare_branch) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}preferCompareBranch={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Suggestions.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitSuggestion, alloc, resp.body);
    }
};

pub const Trees = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: models.GitTreeRef,
        },
    };
    /// The Tree endpoint returns the collection of objects underneath the specified tree. Trees are folders in a Git repository. Repositories have both a name and an identifier. Identifiers are globally unique, but several projects may contain a repository of the same name. You don't need to include the project if you specify a repository by ID. However, if you specify a repository by name, you must also specify the project (by name or ID.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_id: []const u8, sha1: []const u8, project: []const u8, project_id: ?[]const u8, recursive: ?bool, file_name: ?[]const u8, @"$format": ?[]const u8) !GetResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, sha1);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/trees/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (project_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}projectId={s}", .{ sep, enc });
            has_query = true;
        }
        if (recursive) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}recursive={}", .{ sep, query_value });
            has_query = true;
        }
        if (file_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}fileName={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_4 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_4);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_4 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json, application/zip");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_body = try serde.json.fromSlice(models.GitTreeRef, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_type = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Trees.get", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const MergeBases = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Find the merge bases of two commits, optionally across forks. If otherRepositoryId is not specified, the merge bases will only be calculated within the context of the local repositoryNameOrId.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_name_or_id: []const u8, commit_id: []const u8, other_commit_id: []const u8, project: []const u8, other_collection_id: ?[]const u8, other_repository_id: ?[]const u8) ![]const models.GitCommitRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, commit_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/commits/{s}/mergebases", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, other_commit_id);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}otherCommitId={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (other_collection_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}otherCollectionId={s}", .{ sep, enc });
            has_query = true;
        }
        if (other_repository_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}otherRepositoryId={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_3 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_3);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_3 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("MergeBases.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitCommitRef, alloc, resp.body);
    }
};

pub const Forks = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Retrieve all forks of a repository in the collection.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_name_or_id: []const u8, collection_id: []const u8, project: []const u8, include_links: ?bool) ![]const models.GitRepositoryRef {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, collection_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/forks/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Forks.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitRepositoryRef, alloc, resp.body);
    }
    /// Retrieve all requested fork sync operations on this repository.
    pub fn getForkSyncRequests(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_name_or_id: []const u8, project: []const u8, include_abandoned: ?bool, include_links: ?bool) ![]const models.GitForkSyncRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/forkSyncRequests", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_abandoned) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAbandoned={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Forks.getForkSyncRequests", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.GitForkSyncRequest, alloc, resp.body);
    }
    /// Request that another repository's refs be fetched into this one. It syncs two existing forks. To create a fork, please see the <a href='https://docs.microsoft.com/en-us/rest/api/vsts/git/repositories/create?view=azure-devops-rest-5.1'> repositories endpoint</a>
    pub fn createForkSyncRequest(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_name_or_id: []const u8, project: []const u8, include_links: ?bool, body: models.GitForkSyncRequestParameters) !models.GitForkSyncRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/forkSyncRequests", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Forks.createForkSyncRequest", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitForkSyncRequest, alloc, resp.body);
    }
    /// Get a specific fork sync operation's details.
    pub fn getForkSyncRequest(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, repository_name_or_id: []const u8, fork_sync_operation_id: i32, project: []const u8, include_links: ?bool) !models.GitForkSyncRequest {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, fork_sync_operation_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/forkSyncRequests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Forks.getForkSyncRequest", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitForkSyncRequest, alloc, resp.body);
    }
};

pub const Merges = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Request a git merge operation. Currently we support merging only 2 commits.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_name_or_id: []const u8, include_links: ?bool, body: models.GitMergeParameters) !models.GitMerge {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/merges", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Merges.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitMerge, alloc, resp.body);
    }
    /// Get a specific merge operation's details.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository_name_or_id: []const u8, merge_operation_id: i32, include_links: ?bool) !models.GitMerge {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository_name_or_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, merge_operation_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/git/repositories/{s}/merges/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_links) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeLinks={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Merges.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.GitMerge, alloc, resp.body);
    }
};
