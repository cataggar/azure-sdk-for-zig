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

pub const WikiClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !WikiClient {
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
    ) WikiClient {
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

    pub fn wikis(self: *@This()) Wikis {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn attachments(self: *@This()) Attachments {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pageMoves(self: *@This()) PageMoves {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pages(self: *@This()) Pages {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pageStats(self: *@This()) PageStats {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pagesBatch(self: *@This()) PagesBatch {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const Wikis = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Gets all wikis in a project or collection.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8) !models.WikiV2List {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Wikis.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiV2List, alloc, resp.body);
    }
    /// Creates the wiki resource.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.WikiCreateParametersV2) !models.WikiV2 {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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

        if (!responseStatusExpected(resp.status_code, &.{201})) {
            core.pager.logHttpError("Wikis.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiV2, alloc, resp.body);
    }
    /// Deletes the wiki corresponding to the wiki ID or wiki name provided.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, wiki_identifier: []const u8, project: []const u8) !models.WikiV2 {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Wikis.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiV2, alloc, resp.body);
    }
    /// Gets the wiki corresponding to the wiki ID or wiki name provided.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, wiki_identifier: []const u8, project: []const u8) !models.WikiV2 {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Wikis.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiV2, alloc, resp.body);
    }
    /// Updates the wiki corresponding to the wiki ID or wiki name provided using the update parameters.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, wiki_identifier: []const u8, project: []const u8, body: models.WikiUpdateParameters) !models.WikiV2 {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Wikis.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiV2, alloc, resp.body);
    }
};

pub const Attachments = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiAttachment,
        },
    };
    /// Creates an attachment in the wiki.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, name: []const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.CreateRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.CreateRequestVersionDescriptorVersionType, body: []const u8) !CreateResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, name);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}name={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
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
        const encoded_query_4 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_4);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_4 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("content-type", "application/octet-stream");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiAttachment, alloc, resp.body);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Attachments.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const PageMoves = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPageMove,
        },
    };
    /// Creates a page move operation that updates the path and order of the page as provided in the parameters.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, comment: ?[]const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.CreateRequestVersionDescriptorVersionOptions1, @"version_descriptor.version_type": ?enums.CreateRequestVersionDescriptorVersionType1, body: models.WikiPageMoveParameters) !CreateResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pagemoves", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (comment) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}comment={s}", .{ sep, enc });
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
        const encoded_query_4 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_4);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_4 });
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

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPageMove, alloc, resp.body);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("PageMoves.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Pages = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const DeletePageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
    };

    pub const GetPageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.WikiPage,
        },
    };

    pub const CreateOrUpdateResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
    };

    pub const DeletePageByIdResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
    };

    pub const GetPageByIdResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.WikiPage,
        },
    };

    pub const UpdateResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {
                e_tag: ?[]const u8 = null,
            },
            body: models.WikiPage,
        },
    };
    /// Deletes a wiki page.
    pub fn deletePage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, path: []const u8, comment: ?[]const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.DeletePageRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.DeletePageRequestVersionDescriptorVersionType) !DeletePageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, path);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}path={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (comment) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}comment={s}", .{ sep, enc });
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
        const encoded_query_5 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_5);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_5 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.deletePage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Gets metadata or content of the wiki page for the provided path. Content negotiation is done based on the `Accept` header sent in the request.
    pub fn getPage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, path: ?[]const u8, recursion_level: ?enums.GetPageRequestRecursionLevel, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.GetPageRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.GetPageRequestVersionDescriptorVersionType, include_content: ?bool) !GetPageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (path) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}path={s}", .{ sep, enc });
            has_query = true;
        }
        if (recursion_level) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}recursionLevel={s}", .{ sep, enc });
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
        if (include_content) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeContent={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_6 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_6);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_6 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "text/plain, application/json, application/zip");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .content_type = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .content_type = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.getPage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Creates or edits a wiki page.
    pub fn createOrUpdate(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, path: []const u8, version: []const u8, comment: ?[]const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.CreateOrUpdateRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.CreateOrUpdateRequestVersionDescriptorVersionType, body: models.WikiPageCreateOrUpdateParameters) !CreateOrUpdateResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, path);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}path={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (comment) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}comment={s}", .{ sep, enc });
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
        const encoded_query_5 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_5);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_5 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("version", version);
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            201 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.createOrUpdate", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes a wiki page.
    pub fn deletePageById(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, id: i32, comment: ?[]const u8) !DeletePageByIdResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (comment) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}comment={s}", .{ sep, enc });
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
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.deletePageById", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Gets metadata or content of the wiki page for the provided page id. Content negotiation is done based on the `Accept` header sent in the request.
    pub fn getPageById(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, id: i32, recursion_level: ?enums.GetPageByIdRequestRecursionLevel, include_content: ?bool) !GetPageByIdResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (recursion_level) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}recursionLevel={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_content) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeContent={}", .{ sep, query_value });
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
        try req.setHeader("Accept", "text/plain, application/json, application/zip");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .content_type = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("content-type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .content_type = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.getPageById", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Edits a wiki page.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, id: i32, version: []const u8, comment: ?[]const u8, body: models.WikiPageCreateOrUpdateParameters) !UpdateResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (comment) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}comment={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("version", version);
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            404 => {
                const response_header_0 = if (resp.getHeader("etag")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.WikiPage, alloc, resp.body);
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Pages.update", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const PageStats = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Returns page detail corresponding to Page ID.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, page_id: i32, page_views_for_days: ?i32) !models.WikiPageDetail {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, page_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pages/{s}/stats", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (page_views_for_days) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}pageViewsForDays={d}", .{ sep, query_value });
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
            core.pager.logHttpError("PageStats.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiPageDetail, alloc, resp.body);
    }
};

pub const PagesBatch = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Returns pageable list of Wiki Pages
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, wiki_identifier: []const u8, version_descriptor_version: ?[]const u8, @"version_descriptor.version_options": ?enums.GetRequestVersionDescriptorVersionOptions, @"version_descriptor.version_type": ?enums.GetRequestVersionDescriptorVersionType, body: models.WikiPagesBatchRequest) !models.WikiPageDetailList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, wiki_identifier);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/wiki/wikis/{s}/pagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
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
            core.pager.logHttpError("PagesBatch.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.WikiPageDetailList, alloc, resp.body);
    }
};
