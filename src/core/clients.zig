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

pub const CoreClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !CoreClient {
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
    ) CoreClient {
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

    pub fn processes(self: *@This()) Processes {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn projects(self: *@This()) Projects {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn avatar(self: *@This()) Avatar {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn categorizedTeams(self: *@This()) CategorizedTeams {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn teams(self: *@This()) Teams {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const Processes = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of processes.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8) ![]const models.Process {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/process/processes", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("Processes.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.Process, alloc, resp.body);
    }
    /// Get a process by ID.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, process_id: []const u8) !models.Process {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, process_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/process/processes/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Processes.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Process, alloc, resp.body);
    }
};

pub const Projects = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get all projects in the organization that the authenticated user has access to.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, state_filter: ?enums.ListRequestStateFilter, @"$top": ?i32, @"$skip": ?i32, continuation_token: ?i32, get_default_team_image_url: ?bool) ![]const models.TeamProjectReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (state_filter) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}stateFilter={s}", .{ sep, enc });
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
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}continuationToken={d}", .{ sep, query_value });
            has_query = true;
        }
        if (get_default_team_image_url) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}getDefaultTeamImageUrl={}", .{ sep, query_value });
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
            core.pager.logHttpError("Projects.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TeamProjectReference, alloc, resp.body);
    }
    /// Queues a project to be created. Use the [GetOperation](../../operations/operations/get) to periodically check for create project status.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.TeamProject) !models.OperationReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("Projects.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OperationReference, alloc, resp.body);
    }
    /// Queues a project to be deleted. Use the [GetOperation](../../operations/operations/get) to periodically check for delete project status.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8) !models.OperationReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Projects.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OperationReference, alloc, resp.body);
    }
    /// Get project with the specified id or name, optionally including capabilities.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, include_capabilities: ?bool, include_history: ?bool) !models.TeamProject {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_capabilities) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeCapabilities={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_history) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeHistory={}", .{ sep, query_value });
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
            core.pager.logHttpError("Projects.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TeamProject, alloc, resp.body);
    }
    /// Update an existing project's name, abbreviation, description, or restore a project.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, body: models.TeamProject) !models.OperationReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Projects.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OperationReference, alloc, resp.body);
    }
    /// Get a collection of team project properties.
    pub fn getProjectProperties(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, keys: ?[]const u8) ![]const models.ProjectProperty {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/properties", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (keys) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}keys={s}", .{ sep, enc });
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
            core.pager.logHttpError("Projects.getProjectProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.ProjectProperty, alloc, resp.body);
    }
    /// Create, update, and delete team project properties.
    pub fn setProjectProperties(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, body: models.JsonPatchDocument) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/properties", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Projects.setProjectProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Avatar = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Removes the avatar for the project.
    pub fn removeProjectAvatar(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/avatar", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Avatar.removeProjectAvatar", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Sets the avatar for the project.
    pub fn setProjectAvatar(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, body: models.ProjectAvatar) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/avatar", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Avatar.setProjectAvatar", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const CategorizedTeams = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Gets list of user readable teams in a project and teams user is member of (excluded from readable list).
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, @"$expand_identity": ?bool, @"$top": ?i32, @"$skip": ?i32) !models.CategorizedWebApiTeams {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/categorizedteams/", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$expand_identity") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$expandIdentity={}", .{ sep, query_value });
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
            core.pager.logHttpError("CategorizedTeams.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CategorizedWebApiTeams, alloc, resp.body);
    }
};

pub const Teams = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of teams.
    pub fn getTeams(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, @"$mine": ?bool, @"$top": ?i32, @"$skip": ?i32, @"$expand_identity": ?bool) ![]const models.WebApiTeam {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$mine") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$mine={}", .{ sep, query_value });
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
        if (@"$expand_identity") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$expandIdentity={}", .{ sep, query_value });
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
            core.pager.logHttpError("Teams.getTeams", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.WebApiTeam, alloc, resp.body);
    }
    /// Create a team in a team project. Possible failure scenarios Invalid project name/ID (project doesn't exist) 404 Invalid team name or description 400 Team already exists 400 Insufficient privileges 400
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, body: models.WebApiTeam) !models.WebApiTeam {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Teams.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WebApiTeam, alloc, resp.body);
    }
    /// Delete a team.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, team_id: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Teams.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a specific team.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, team_id: []const u8, @"$expand_identity": ?bool) !models.WebApiTeam {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$expand_identity") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$expandIdentity={}", .{ sep, query_value });
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
            core.pager.logHttpError("Teams.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WebApiTeam, alloc, resp.body);
    }
    /// Update a team's name and/or description.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, team_id: []const u8, body: models.WebApiTeam) !models.WebApiTeam {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Teams.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WebApiTeam, alloc, resp.body);
    }
    /// Get a list of members for a specific team.
    pub fn getTeamMembersWithExtendedProperties(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project_id: []const u8, team_id: []const u8, @"$top": ?i32, @"$skip": ?i32) ![]const models.TeamMember {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/projects/{s}/teams/{s}/members", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Teams.getTeamMembersWithExtendedProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TeamMember, alloc, resp.body);
    }
    /// Get a list of all teams.
    pub fn getAllTeams(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, @"$mine": ?bool, @"$top": ?i32, @"$skip": ?i32, @"$expand_identity": ?bool) ![]const models.WebApiTeam {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/teams", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$mine") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$mine={}", .{ sep, query_value });
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
        if (@"$expand_identity") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$expandIdentity={}", .{ sep, query_value });
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
            core.pager.logHttpError("Teams.getAllTeams", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.WebApiTeam, alloc, resp.body);
    }
};
