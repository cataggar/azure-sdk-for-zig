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

pub const SecurityClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !SecurityClient {
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
    ) SecurityClient {
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

    pub fn accessControlEntries(self: *@This()) AccessControlEntries {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn accessControlLists(self: *@This()) AccessControlLists {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn permissions(self: *@This()) Permissions {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn securityNamespaces(self: *@This()) SecurityNamespaces {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const AccessControlEntries = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const RemoveAccessControlEntriesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {},
            body: []const u8,
        },
    };
    /// Remove the specified ACEs from the ACL belonging to the specified token.
    pub fn removeAccessControlEntries(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, token: ?[]const u8, descriptors: ?[]const u8) !RemoveAccessControlEntriesResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/accesscontrolentries/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}token={s}", .{ sep, enc });
            has_query = true;
        }
        if (descriptors) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}descriptors={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "text/plain");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("AccessControlEntries.removeAccessControlEntries", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Add or update ACEs in the ACL for the provided token. The request body contains the target token, a list of [ACEs](https://docs.microsoft.com/en-us/rest/api/azure/devops/security/access-control-entries/set-access-control-entries?#accesscontrolentry) and a optional merge parameter. In the case of a collision (by identity descriptor) with an existing ACE in the ACL, the 'merge' parameter determines the behavior. If set, the existing ACE has its allow and deny merged with the incoming ACE's allow and deny. If unset, the existing ACE is displaced. For optimal performance and reliability, it is strongly recommended to batch multiple ACEs in a single request rather than sending individual requests. Batching requests improves efficiency, reduces overhead, and helps ensure successful completion of your operations.
    pub fn setAccessControlEntries(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, body: models.JObject) ![]const models.AccessControlEntry {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/accesscontrolentries/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0 });
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
            core.pager.logHttpError("AccessControlEntries.setAccessControlEntries", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.AccessControlEntry, alloc, resp.body);
    }
};

pub const AccessControlLists = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const RemoveAccessControlListsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {},
            body: []const u8,
        },
    };
    /// Remove access control lists under the specfied security namespace.
    pub fn removeAccessControlLists(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, tokens: ?[]const u8, recurse: ?bool) !RemoveAccessControlListsResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/accesscontrollists/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (tokens) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}tokens={s}", .{ sep, enc });
            has_query = true;
        }
        if (recurse) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}recurse={}", .{ sep, query_value });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "text/plain");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("AccessControlLists.removeAccessControlLists", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Return a list of access control lists for the specified security namespace and token. All ACLs in the security namespace will be retrieved if no optional parameters are provided. Note that the response will include all project IDs, including projects the current user does not have access to.
    pub fn query(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, token: ?[]const u8, descriptors: ?[]const u8, include_extended_info: ?bool, recurse: ?bool) ![]const models.AccessControlList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/accesscontrollists/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}token={s}", .{ sep, enc });
            has_query = true;
        }
        if (descriptors) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}descriptors={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_extended_info) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeExtendedInfo={}", .{ sep, query_value });
            has_query = true;
        }
        if (recurse) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}recurse={}", .{ sep, query_value });
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
            core.pager.logHttpError("AccessControlLists.query", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.AccessControlList, alloc, resp.body);
    }
    /// Create or update one or more access control lists. All data that currently exists for the ACLs supplied will be overwritten.
    pub fn setAccessControlLists(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, body: models.VssJsonCollectionWrapper) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/accesscontrollists/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0 });
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
            core.pager.logHttpError("AccessControlLists.setAccessControlLists", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Permissions = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Removes the specified permissions on a security token for a user or group.
    pub fn removePermission(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, descriptor: []const u8, organization: []const u8, permissions: i32, token: ?[]const u8) !models.AccessControlEntry {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, permissions);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/permissions/{s}/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, descriptor);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}descriptor={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}token={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Permissions.removePermission", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AccessControlEntry, alloc, resp.body);
    }
    /// Evaluates whether the caller has the specified permissions on the specified set of security tokens.
    pub fn hasPermissions(self: *@This(), alloc: std.mem.Allocator, security_namespace_id: []const u8, organization: []const u8, permissions: i32, tokens: ?[]const u8, always_allow_administrators: ?bool, delimiter: ?[]const u8) ![]const bool {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, permissions);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/permissions/{s}/{s}", .{ self.endpoint, encoded_path_1, encoded_path_0, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (tokens) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}tokens={s}", .{ sep, enc });
            has_query = true;
        }
        if (always_allow_administrators) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}alwaysAllowAdministrators={}", .{ sep, query_value });
            has_query = true;
        }
        if (delimiter) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}delimiter={s}", .{ sep, enc });
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
            core.pager.logHttpError("Permissions.hasPermissions", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const bool, alloc, resp.body);
    }
    /// Evaluates multiple permissions for the calling user. Note: This method does not aggregate the results, nor does it short-circuit if one of the permissions evaluates to false.
    pub fn hasPermissionsBatch(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.PermissionEvaluationBatch) !models.PermissionEvaluationBatch {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/security/permissionevaluationbatch", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("Permissions.hasPermissionsBatch", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.PermissionEvaluationBatch, alloc, resp.body);
    }
};

pub const SecurityNamespaces = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// List all security namespaces or just the specified namespace.
    pub fn query(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, security_namespace_id: []const u8, local_only: ?bool) ![]const models.SecurityNamespaceDescription {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, security_namespace_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/securitynamespaces/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (local_only) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}localOnly={}", .{ sep, query_value });
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
            core.pager.logHttpError("SecurityNamespaces.query", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SecurityNamespaceDescription, alloc, resp.body);
    }
};
