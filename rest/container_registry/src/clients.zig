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
const default_api_version = "2021-07-01";
const auth_scopes: []const []const u8 = &.{"https://containerregistry.azure.net/.default"};

/// Metadata API definition for the Azure Container Registry runtime
pub const ContainerRegistryClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    allocator: std.mem.Allocator,
    auth_policy: ?*core.pipeline.BearerTokenAuthPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,

    pub const InitOptions = struct {
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        endpoint: []const u8,
        api_version: []const u8 = default_api_version,
    };

    pub const PipelineOptions = struct {
        endpoint: []const u8,
        api_version: []const u8 = default_api_version,
    };

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !ContainerRegistryClient {
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
    ) ContainerRegistryClient {
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

    pub fn containerRegistry(self: *@This()) ContainerRegistry {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn containerRegistryBlob(self: *@This()) ContainerRegistryBlob {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn authentication(self: *@This()) Authentication {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const ContainerRegistry = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const CreateManifestResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                location: []const u8,
                content_length: i64,
                docker_content_digest: []const u8,
            },
            body: void,
        },
    };

    pub const DeleteManifestResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {},
            body: void,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {},
            body: void,
        },
    };

    pub const GetRepositoriesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                link: ?[]const u8 = null,
            },
            body: models.Repositories,
        },
    };

    pub const DeleteRepositoryResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {},
            body: void,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {},
            body: void,
        },
    };

    pub const GetTagsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                link: ?[]const u8 = null,
            },
            body: models.TagList,
        },
    };

    pub const DeleteTagResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {},
            body: void,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {},
            body: void,
        },
    };

    pub const GetManifestsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                link: ?[]const u8 = null,
            },
            body: models.AcrManifests,
        },
    };
    /// Tells whether this Docker Registry instance supports Docker Registry HTTP API v2
    pub fn checkDockerV2Support(self: *@This(), alloc: std.mem.Allocator) !void {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/", .{self.endpoint});
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

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ContainerRegistry.checkDockerV2Support", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get the manifest identified by `name` and `reference` where `reference` can be
    /// a tag or digest.
    pub fn getManifest(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8, accept: ?[]const u8) !models.ManifestWrapper {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/manifests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        if (accept) |value| try req.setHeader("accept", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ContainerRegistry.getManifest", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ManifestWrapper, alloc, resp.body);
    }
    /// Put the manifest identified by `name` and `reference` where `reference` can be
    /// a tag or digest.
    pub fn createManifest(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8, payload: models.Manifest) !CreateManifestResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/manifests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        try req.setHeader("Content-Type", "application/vnd.docker.distribution.manifest.v2+json");
        const body_json = try serde.json.toSlice(alloc, payload);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                        .content_length = response_header_1,
                        .docker_content_digest = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.createManifest", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Delete the manifest identified by `name` and `reference`. Note that a manifest
    /// can _only_ be deleted by `digest`.
    pub fn deleteManifest(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8) !DeleteManifestResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/manifests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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

        switch (resp.status_code) {
            202 => {
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            404 => {
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.deleteManifest", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// List repositories
    pub fn getRepositories(self: *@This(), alloc: std.mem.Allocator, last: ?[]const u8, n: ?i32) !GetRepositoriesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/_catalog", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (last) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}last={s}", .{ sep, enc });
            has_query = true;
        }
        if (n) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}n={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("Link")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.Repositories, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .link = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.getRepositories", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get repository attributes
    pub fn getProperties(self: *@This(), alloc: std.mem.Allocator, name: []const u8) !models.ContainerRepositoryProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("ContainerRegistry.getProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ContainerRepositoryProperties, alloc, resp.body);
    }
    /// Delete the repository identified by `name`
    pub fn deleteRepository(self: *@This(), alloc: std.mem.Allocator, name: []const u8) !DeleteRepositoryResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}", .{ self.endpoint, encoded_path_0 });
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

        switch (resp.status_code) {
            202 => {
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            404 => {
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.deleteRepository", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update the attribute identified by `name` where `reference` is the name of the
    /// repository.
    pub fn updateProperties(self: *@This(), alloc: std.mem.Allocator, name: []const u8, value: ?models.RepositoryChangeableAttributes) !models.ContainerRepositoryProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}", .{ self.endpoint, encoded_path_0 });
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
        if (value != null) try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (value) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ContainerRegistry.updateProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ContainerRepositoryProperties, alloc, resp.body);
    }
    /// List tags of a repository
    pub fn getTags(self: *@This(), alloc: std.mem.Allocator, name: []const u8, last: ?[]const u8, n: ?i32, orderby: ?enums.ArtifactTagOrder, digest: ?[]const u8) !GetTagsResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_tags", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (last) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}last={s}", .{ sep, enc });
            has_query = true;
        }
        if (n) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}n={d}", .{ sep, v });
            has_query = true;
        }
        if (orderby) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}orderby={s}", .{ sep, enc });
            has_query = true;
        }
        if (digest) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}digest={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("Link")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.TagList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .link = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.getTags", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get tag attributes by tag
    pub fn getTagProperties(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8) !models.ArtifactTagProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_tags/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("ContainerRegistry.getTagProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ArtifactTagProperties, alloc, resp.body);
    }
    /// Update tag attributes
    pub fn updateTagAttributes(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8, value: ?models.TagChangeableAttributes) !models.ArtifactTagProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_tags/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        if (value != null) try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (value) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ContainerRegistry.updateTagAttributes", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ArtifactTagProperties, alloc, resp.body);
    }
    /// Delete tag
    pub fn deleteTag(self: *@This(), alloc: std.mem.Allocator, name: []const u8, reference: []const u8) !DeleteTagResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, reference);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_tags/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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

        switch (resp.status_code) {
            202 => {
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            404 => {
                return .{ .status_404 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.deleteTag", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// List manifests of a repository
    pub fn getManifests(self: *@This(), alloc: std.mem.Allocator, name: []const u8, last: ?[]const u8, n: ?i32, orderby: ?enums.ArtifactManifestOrder) !GetManifestsResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_manifests", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (last) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}last={s}", .{ sep, enc });
            has_query = true;
        }
        if (n) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}n={d}", .{ sep, v });
            has_query = true;
        }
        if (orderby) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}orderby={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("Link")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_body = try serde.json.fromSlice(models.AcrManifests, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .link = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistry.getManifests", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get manifest attributes
    pub fn getManifestProperties(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8) !models.ArtifactManifestProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_manifests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("ContainerRegistry.getManifestProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ArtifactManifestProperties, alloc, resp.body);
    }
    /// Update properties of a manifest
    pub fn updateManifestProperties(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8, value: ?models.ManifestChangeableAttributes) !models.ArtifactManifestProperties {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/acr/v1/{s}/_manifests/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        if (value != null) try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (value) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("ContainerRegistry.updateManifestProperties", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ArtifactManifestProperties, alloc, resp.body);
    }
};

pub const ContainerRegistryBlob = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetBlobResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_length: i64,
                docker_content_digest: []const u8,
            },
            body: []const u8,
        },
        status_307: struct {
            status: u16 = 307,
            headers: struct {
                location: []const u8,
            },
            body: void,
        },
    };

    pub const CheckBlobExistsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_length: i64,
                docker_content_digest: []const u8,
            },
            body: void,
        },
        status_307: struct {
            status: u16 = 307,
            headers: struct {
                location: []const u8,
            },
            body: void,
        },
    };

    pub const DeleteBlobResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                docker_content_digest: []const u8,
            },
            body: void,
        },
    };

    pub const MountBlobResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                location: []const u8,
                docker_upload_uuid: []const u8,
                docker_content_digest: []const u8,
            },
            body: void,
        },
    };

    pub const GetUploadStatusResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                range: []const u8,
                docker_upload_uuid: []const u8,
            },
            body: void,
        },
    };

    pub const UploadChunkResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                location: []const u8,
                range: []const u8,
                docker_upload_uuid: []const u8,
            },
            body: void,
        },
    };

    pub const CompleteUploadResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                location: []const u8,
                range: []const u8,
                docker_content_digest: []const u8,
            },
            body: void,
        },
    };

    pub const StartUploadResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                location: []const u8,
                range: []const u8,
                docker_upload_uuid: []const u8,
            },
            body: void,
        },
    };

    pub const GetChunkResult = union(enum) {
        status_206: struct {
            status: u16 = 206,
            headers: struct {
                content_length: i64,
                content_range: []const u8,
            },
            body: []const u8,
        },
    };

    pub const CheckChunkExistsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_length: i64,
                content_range: []const u8,
            },
            body: void,
        },
    };
    /// Retrieve the blob from the registry identified by digest.
    pub fn getBlob(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8) !GetBlobResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        req.redirect_policy = .not_allowed;
        try req.setHeader("Accept", "application/octet-stream");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_length = response_header_0,
                        .docker_content_digest = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            307 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                return .{ .status_307 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.getBlob", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Same as GET, except only the headers are returned.
    pub fn checkBlobExists(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8) !CheckBlobExistsResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        var req = core.http.Request.init(alloc, .HEAD, url);
        defer req.deinit();
        req.redirect_policy = .not_allowed;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_length = response_header_0,
                        .docker_content_digest = response_header_1,
                    },
                    .body = {},
                } };
            },
            307 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                return .{ .status_307 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.checkBlobExists", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Removes an already uploaded blob.
    pub fn deleteBlob(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8) !DeleteBlobResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .docker_content_digest = response_header_0,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.deleteBlob", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Mount a blob identified by the `mount` parameter from another repository.
    pub fn mountBlob(self: *@This(), alloc: std.mem.Allocator, name: []const u8, from: []const u8, mount: []const u8) !MountBlobResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/uploads/", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, from);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}from={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const encoded_query_2 = try core.url.percentEncode(alloc, mount);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}mount={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Upload-UUID") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                        .docker_upload_uuid = response_header_1,
                        .docker_content_digest = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.mountBlob", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieve status of upload identified by uuid. The primary purpose of this
    /// endpoint is to resolve the current status of a resumable upload.
    pub fn getUploadStatus(self: *@This(), alloc: std.mem.Allocator, next_blob_uuid_link: []const u8) !GetUploadStatusResult {
        const encoded_path_0 = try core.url.expandGreedyPathValue(alloc, next_blob_uuid_link);
        defer alloc.free(encoded_path_0);
        const endpoint_uri = std.Uri.parse(self.endpoint) catch return error.InvalidUrl;
        var endpoint_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const endpoint_host = endpoint_uri.getHost(&endpoint_host_buffer) catch return error.InvalidUrl;
        const base_url = try core.url.resolveAndValidateUrl(
            alloc,
            self.endpoint,
            encoded_path_0,
            &.{endpoint_host.bytes},
        );
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

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Upload-UUID") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .range = response_header_0,
                        .docker_upload_uuid = response_header_1,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.getUploadStatus", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Upload a stream of data without completing the upload.
    pub fn uploadChunk(self: *@This(), alloc: std.mem.Allocator, next_blob_uuid_link: []const u8, value: []const u8) !UploadChunkResult {
        const encoded_path_0 = try core.url.expandGreedyPathValue(alloc, next_blob_uuid_link);
        defer alloc.free(encoded_path_0);
        const endpoint_uri = std.Uri.parse(self.endpoint) catch return error.InvalidUrl;
        var endpoint_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const endpoint_host = endpoint_uri.getHost(&endpoint_host_buffer) catch return error.InvalidUrl;
        const base_url = try core.url.resolveAndValidateUrl(
            alloc,
            self.endpoint,
            encoded_path_0,
            &.{endpoint_host.bytes},
        );
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
        try req.setHeader("Content-Type", "application/octet-stream");
        req.body = value;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Upload-UUID") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                        .range = response_header_1,
                        .docker_upload_uuid = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.uploadChunk", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Complete the upload, providing all the data in the body, if necessary. A
    /// request without a body will just complete the upload with previously uploaded
    /// content.
    pub fn completeUpload(self: *@This(), alloc: std.mem.Allocator, digest: []const u8, next_blob_uuid_link: []const u8, value: ?[]const u8) !CompleteUploadResult {
        const encoded_path_0 = try core.url.expandGreedyPathValue(alloc, next_blob_uuid_link);
        defer alloc.free(encoded_path_0);
        const endpoint_uri = std.Uri.parse(self.endpoint) catch return error.InvalidUrl;
        var endpoint_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const endpoint_host = endpoint_uri.getHost(&endpoint_host_buffer) catch return error.InvalidUrl;
        const base_url = try core.url.resolveAndValidateUrl(
            alloc,
            self.endpoint,
            encoded_path_0,
            &.{endpoint_host.bytes},
        );
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, digest);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}digest={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        if (value != null) try req.setHeader("Content-Type", "application/octet-stream");
        if (value) |body| req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Content-Digest") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                        .range = response_header_1,
                        .docker_content_digest = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.completeUpload", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Cancel outstanding upload processes, releasing associated resources. If this is
    /// not called, the unfinished uploads will eventually timeout.
    pub fn cancelUpload(self: *@This(), alloc: std.mem.Allocator, next_blob_uuid_link: []const u8) !void {
        const encoded_path_0 = try core.url.expandGreedyPathValue(alloc, next_blob_uuid_link);
        defer alloc.free(encoded_path_0);
        const endpoint_uri = std.Uri.parse(self.endpoint) catch return error.InvalidUrl;
        var endpoint_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const endpoint_host = endpoint_uri.getHost(&endpoint_host_buffer) catch return error.InvalidUrl;
        const base_url = try core.url.resolveAndValidateUrl(
            alloc,
            self.endpoint,
            encoded_path_0,
            &.{endpoint_host.bytes},
        );
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

        if (!responseStatusExpected(resp.status_code, &.{204})) {
            core.pager.logHttpError("ContainerRegistryBlob.cancelUpload", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Initiate a resumable blob upload with an empty request body.
    pub fn startUpload(self: *@This(), alloc: std.mem.Allocator, name: []const u8) !StartUploadResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/uploads/", .{ self.endpoint, encoded_path_0 });
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

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Location") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Docker-Upload-UUID") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .location = response_header_0,
                        .range = response_header_1,
                        .docker_upload_uuid = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.startUpload", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieve the blob from the registry identified by `digest`. This endpoint may
    /// also support RFC7233 compliant range requests. Support can be detected by
    /// issuing a HEAD request. If the header `Accept-Range: bytes` is returned, range
    /// requests can be used to fetch partial content.
    pub fn getChunk(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8, range: []const u8) !GetChunkResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        try req.setHeader("range", range);
        try req.setHeader("Accept", "application/octet-stream");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            206 => {
                const response_header_0 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_206 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_length = response_header_0,
                        .content_range = response_header_1,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.getChunk", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Same as GET, except only the headers are returned.
    pub fn checkChunkExists(self: *@This(), alloc: std.mem.Allocator, name: []const u8, digest: []const u8, range: []const u8) !CheckChunkExistsResult {
        const encoded_path_0 = try core.url.encodeRepositoryName(alloc, name);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, digest);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/v2/{s}/blobs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        var req = core.http.Request.init(alloc, .HEAD, url);
        defer req.deinit();
        try req.setHeader("range", range);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_length = response_header_0,
                        .content_range = response_header_1,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("ContainerRegistryBlob.checkChunkExists", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Authentication = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Exchange AAD tokens for an ACR refresh Token
    pub fn exchangeAadAccessTokenForAcrRefreshToken(self: *@This(), alloc: std.mem.Allocator, body: models.MultipartBodyParameter) !models.AcrRefreshToken {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/oauth2/exchange", .{self.endpoint});
        defer alloc.free(base_url);
        const url = base_url;
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");
        const multipart_boundary = "azure-sdk-for-zig-acr-boundary";
        var multipart_body: std.ArrayList(u8) = .empty;
        defer multipart_body.deinit(alloc);
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"grantType\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.grant_type.toWire() },
        );
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"service\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.service },
        );
        if (body.tenant) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"tenant\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        if (body.refresh_token) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"refreshToken\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        if (body.access_token) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"accessToken\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        try multipart_body.print(alloc, "--{s}--\r\n", .{multipart_boundary});
        const multipart_bytes = try multipart_body.toOwnedSlice(alloc);
        defer alloc.free(multipart_bytes);
        req.body = multipart_bytes;
        try req.setHeader("Content-Type", "multipart/form-data; boundary=azure-sdk-for-zig-acr-boundary");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Authentication.exchangeAadAccessTokenForAcrRefreshToken", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AcrRefreshToken, alloc, resp.body);
    }
    /// Exchange ACR Refresh token for an ACR Access Token
    pub fn exchangeAcrRefreshTokenForAcrAccessToken(self: *@This(), alloc: std.mem.Allocator, body: models.MultipartBodyParameter) !models.AcrAccessToken {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/oauth2/token", .{self.endpoint});
        defer alloc.free(base_url);
        const url = base_url;
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");
        const multipart_boundary = "azure-sdk-for-zig-acr-boundary";
        var multipart_body: std.ArrayList(u8) = .empty;
        defer multipart_body.deinit(alloc);
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"grantType\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.grant_type.toWire() },
        );
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"service\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.service },
        );
        if (body.tenant) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"tenant\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        if (body.refresh_token) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"refreshToken\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        if (body.access_token) |value| {
            try multipart_body.print(
                alloc,
                "--{s}\r\nContent-Disposition: form-data; name=\"accessToken\"\r\nContent-Type: text/plain\r\n\r\n{s}\r\n",
                .{ multipart_boundary, value },
            );
        }
        try multipart_body.print(alloc, "--{s}--\r\n", .{multipart_boundary});
        const multipart_bytes = try multipart_body.toOwnedSlice(alloc);
        defer alloc.free(multipart_bytes);
        req.body = multipart_bytes;
        try req.setHeader("Content-Type", "multipart/form-data; boundary=azure-sdk-for-zig-acr-boundary");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Authentication.exchangeAcrRefreshTokenForAcrAccessToken", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AcrAccessToken, alloc, resp.body);
    }
    /// Exchange Username, Password and Scope for an ACR Access Token
    pub fn getAcrAccessTokenFromLogin(self: *@This(), alloc: std.mem.Allocator, service: []const u8, scope: []const u8) !models.AcrAccessToken {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/oauth2/token", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, service);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}service={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const encoded_query_2 = try core.url.percentEncode(alloc, scope);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}scope={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Authentication.getAcrAccessTokenFromLogin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AcrAccessToken, alloc, resp.body);
    }
};
