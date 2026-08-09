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
const default_endpoint = "https://pkgs.dev.azure.com";
const default_api_version = "7.2-preview";
const auth_scopes: []const []const u8 = &.{"{endpoint}/.default"};

pub const ArtifactsPackageTypesClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !ArtifactsPackageTypesClient {
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
    ) ArtifactsPackageTypesClient {
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

    pub fn cargo(self: *@This()) Cargo {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn maven(self: *@This()) Maven {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn npm(self: *@This()) Npm {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn nuGet(self: *@This()) NuGet {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn python(self: *@This()) Python {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn universal(self: *@This()) Universal {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const Cargo = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get the upstreaming behavior of a package within the context of a feed
    pub fn getUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, package_name: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Cargo.getUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, package_name: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Cargo.setUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Send a package version from the feed to its paired recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Cargo.deletePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get information about a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, show_deleted: ?bool) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (show_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}showDeleted={}", .{ sep, query_value });
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
            core.pager.logHttpError("Cargo.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update state for a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Cargo.updatePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version from the feed, moving it to the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Cargo.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.CargoPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Cargo.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CargoPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version from the recycle bin to its associated feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.CargoRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Cargo.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.CargoPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/cargo/RecycleBin/packagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Cargo.updateRecycleBinPackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.CargoPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_packaging/packaging/feeds/{s}/cargo/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Cargo.updatePackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Maven = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const DownloadPackageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Get the upstreaming behavior of a package within the context of a feed
    pub fn getUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/groups/{s}/artifacts/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Maven.getUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/groups/{s}/artifacts/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Maven.setUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version from the feed and move it to the feed's recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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

        if (!responseStatusExpected(resp.status_code, &.{202})) {
            core.pager.logHttpError("Maven.deletePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8, show_deleted: ?bool) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (show_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}showDeleted={}", .{ sep, query_value });
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
            core.pager.logHttpError("Maven.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update state for a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8, body: models.PackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Maven.updatePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Permanently delete a package from a feed's recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/RecycleBin/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Maven.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8) !models.MavenPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/RecycleBin/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Maven.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.MavenPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version from the recycle bin to its associated feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, project: []const u8, body: models.MavenRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/RecycleBin/groups/{s}/artifacts/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Maven.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackages(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed: []const u8, project: []const u8, body: models.MavenPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/RecycleBin/packagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Maven.updateRecycleBinPackages", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Fulfills Maven package file download requests by either returning the URL of the requested package file or, in the case of Azure DevOps Server (OnPrem), returning the content as a stream. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn downloadPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, group_id: []const u8, artifact_id: []const u8, version: []const u8, file_name: []const u8, project: []const u8) !DownloadPackageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, group_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, artifact_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, file_name);
        defer alloc.free(encoded_path_5);
        const encoded_path_6 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_6);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/{s}/{s}/{s}/{s}/content", .{ self.endpoint, encoded_path_0, encoded_path_6, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4, encoded_path_5 });
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
        try req.setHeader("Accept", "application/octet-stream");

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
                core.pager.logHttpError("Maven.downloadPackage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.MavenPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/maven/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Maven.updatePackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Npm = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const DownloadScopedPackageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const GetScopedPackageReadmeResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const DownloadPackageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const GetPackageReadmeResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Validates whether the given upstream is valid to add as a custom upstream using the given package name.
    pub fn validateCustomPublicUpstreamSource(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.ValidateCustomPublicUpstreamSourceRequest) !models.ValidateCustomPublicUpstreamSourceResponse {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/packaging/npm/validateupstream", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("Npm.validateCustomPublicUpstreamSource", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ValidateCustomPublicUpstreamSourceResponse, alloc, resp.body);
    }
    /// Unpublish a scoped package version (such as @scope/name). The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn unpublishScopedPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.unpublishScopedPackage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get information about a scoped package version (such as @scope/name). The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getScopedPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.getScopedPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update state for an npm scoped package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateScopedPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.updateScopedPackage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Unpublish an unscoped package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn unpublishPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.unpublishPackage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get information about an unscoped package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update state for an unscoped package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.updatePackage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get the upstreaming behavior of the (scoped) package within the context of a feed
    pub fn getPackageUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/@{s}/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.getPackageUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a (scoped) package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setScopedUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/@{s}/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.setScopedUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get scoped npm package. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn downloadScopedPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !DownloadScopedPackageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/@{s}/{s}/versions/{s}/content", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
        try req.setHeader("Accept", "application/octet-stream");

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
                core.pager.logHttpError("Npm.downloadScopedPackage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get the Readme for a package version with an npm scope. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getScopedPackageReadme(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !GetScopedPackageReadmeResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/@{s}/{s}/versions/{s}/readme", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
        try req.setHeader("Accept", "text/plain");

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
                core.pager.logHttpError("Npm.getScopedPackageReadme", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get the upstreaming behavior of the (unscoped) package within the context of a feed
    pub fn getScopedPackageUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Npm.getScopedPackageUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a (scoped) package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Npm.setUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get an unscoped npm package. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn downloadPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !DownloadPackageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/{s}/versions/{s}/content", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
        try req.setHeader("Accept", "application/octet-stream");

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
                core.pager.logHttpError("Npm.downloadPackage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get the Readme for a package version that has no npm scope. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageReadme(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !GetPackageReadmeResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packages/{s}/versions/{s}/readme", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
        try req.setHeader("Accept", "text/plain");

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
                core.pager.logHttpError("Npm.getPackageReadme", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackages(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.NpmPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Npm.updatePackages", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version with an npm scope from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deleteScopedPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.deleteScopedPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a scoped package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getScopedPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8) !models.NpmPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.getScopedPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.NpmPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version with an npm scope from the recycle bin to its feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restoreScopedPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_scope: []const u8, unscoped_package_name: []const u8, package_version: []const u8, project: []const u8, body: models.NpmRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_scope);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, unscoped_package_name);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/@{s}/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Npm.restoreScopedPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version without an npm scope from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about an unscoped package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.NpmPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.NpmPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version without an npm scope from the recycle bin to its feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.NpmRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Npm.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackages(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.NpmPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/npm/RecycleBin/PackagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Npm.updateRecycleBinPackages", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const NuGet = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const DownloadPackageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Get the upstreaming behavior of a package within the context of a feed
    pub fn getUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("NuGet.getUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("NuGet.setUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Send a package version from the feed to its paired recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("NuGet.deletePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get information about a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, show_deleted: ?bool) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (show_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}showDeleted={}", .{ sep, query_value });
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
            core.pager.logHttpError("NuGet.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Set mutable state on a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("NuGet.updatePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Download a package version directly. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn downloadPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, source_protocol_version: ?[]const u8) !DownloadPackageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packages/{s}/versions/{s}/content", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (source_protocol_version) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}sourceProtocolVersion={s}", .{ sep, enc });
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
        try req.setHeader("Accept", "application/octet-stream");

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
                core.pager.logHttpError("NuGet.downloadPackage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.NuGetPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("NuGet.updatePackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version from a feed's recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("NuGet.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// View a package version's deletion/recycled status The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.NuGetPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("NuGet.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.NuGetPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version from a feed's recycle bin back into the active feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.NuGetRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("NuGet.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.NuGetPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/nuget/RecycleBin/packagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("NuGet.updateRecycleBinPackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Python = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const DownloadPackageResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Get the upstreaming behavior of a package within the context of a feed
    pub fn getUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8) !models.UpstreamingBehavior {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Python.getUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UpstreamingBehavior, alloc, resp.body);
    }
    /// Set the upstreaming behavior of a package within the context of a feed The package does not need to necessarily exist in the feed prior to setting the behavior. This assists with packages that are not yet ingested from an upstream, yet the feed owner wants to apply a specific behavior on the first ingestion.
    pub fn setUpstreamingBehavior(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, project: []const u8, body: models.UpstreamingBehavior) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/upstreaming", .{ self.endpoint, encoded_path_0, encoded_path_3, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Python.setUpstreamingBehavior", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version, moving it to the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Python.deletePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Get information about a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, show_deleted: ?bool) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (show_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}showDeleted={}", .{ sep, query_value });
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
            core.pager.logHttpError("Python.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update state for a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Python.updatePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Download a python package file directly. This API is intended for manual UI download options, not for programmatic access and scripting. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn downloadPackage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, file_name: []const u8, project: []const u8) !DownloadPackageResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, file_name);
        defer alloc.free(encoded_path_4);
        const encoded_path_5 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_5);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packages/{s}/versions/{s}/{s}/content", .{ self.endpoint, encoded_path_0, encoded_path_5, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
        try req.setHeader("Accept", "application/octet-stream");

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
                core.pager.logHttpError("Python.downloadPackage", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.PyPiPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Python.updatePackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version from the feed, moving it to the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Python.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.PyPiPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Python.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.PyPiPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version from the recycle bin to its associated feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PyPiRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Python.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.PyPiPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/pypi/RecycleBin/packagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Python.updateRecycleBinPackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Universal = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Delete a package version from a feed's recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Universal.deletePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Show information about a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, show_deleted: ?bool) !models.Package {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (show_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}showDeleted={}", .{ sep, query_value });
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
            core.pager.logHttpError("Universal.getPackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Package, alloc, resp.body);
    }
    /// Update information for a package version. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersion(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.PackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Universal.updatePackageVersion", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Update several packages from a single feed in a single request. The updates to the packages do not happen atomically. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updatePackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.UPackPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/packagesbatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Universal.updatePackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete a package version from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn deletePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Universal.deletePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get information about a package version in the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn getPackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8) !models.UPackPackageVersionDeletionState {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Universal.getPackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.UPackPackageVersionDeletionState, alloc, resp.body);
    }
    /// Restore a package version from the recycle bin to its associated feed. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn restorePackageVersionFromRecycleBin(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, package_name: []const u8, package_version: []const u8, project: []const u8, body: models.UPackRecycleBinPackageVersionDetails) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, package_name);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, package_version);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/RecycleBin/packages/{s}/versions/{s}", .{ self.endpoint, encoded_path_0, encoded_path_4, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Universal.restorePackageVersionFromRecycleBin", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Delete or restore several package versions from the recycle bin. The project parameter must be supplied if the feed was created in a project. If the feed is not associated with any project, omit the project parameter from the request.
    pub fn updateRecycleBinPackageVersions(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, feed_id: []const u8, project: []const u8, body: models.UPackPackagesBatchRequest) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, feed_id);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/packaging/feeds/{s}/upack/RecycleBin/packagesBatch", .{ self.endpoint, encoded_path_0, encoded_path_2, encoded_path_1 });
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
            core.pager.logHttpError("Universal.updateRecycleBinPackageVersions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};
