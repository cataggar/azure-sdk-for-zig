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
const default_endpoint = "https://vssps.dev.azure.com";
const default_api_version = "7.2-preview";
const auth_scopes: []const []const u8 = &.{"{endpoint}/.default"};

pub const TokenAdminClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !TokenAdminClient {
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
    ) TokenAdminClient {
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

    pub fn personalAccessTokens(self: *@This()) PersonalAccessTokens {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn revocationRules(self: *@This()) RevocationRules {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn revocations(self: *@This()) Revocations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const PersonalAccessTokens = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const ListResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {},
            body: models.TokenAdminPagedSessionTokens,
        },
        status_400: struct {
            status: u16 = 400,
            headers: struct {},
            body: void,
        },
        status_401: struct {
            status: u16 = 401,
            headers: struct {},
            body: void,
        },
        status_404: struct {
            status: u16 = 404,
            headers: struct {},
            body: void,
        },
    };
    /// Lists of all the session token details of the personal access tokens (PATs) for a particular user.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, subject_descriptor: []const u8, page_size: ?i32, continuation_token: ?[]const u8, is_public: ?bool) !ListResult {
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, subject_descriptor);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/tokenadmin/personalaccesstokens/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (page_size) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}pageSize={d}", .{ sep, query_value });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (is_public) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}isPublic={}", .{ sep, query_value });
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

        switch (resp.status_code) {
            200 => {
                const response_body = try serde.json.fromSlice(models.TokenAdminPagedSessionTokens, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = response_body,
                } };
            },
            400 => {
                return .{ .status_400 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            401 => {
                return .{ .status_401 = .{
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
                core.pager.logHttpError("PersonalAccessTokens.list", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const RevocationRules = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {},
            body: void,
        },
        status_400: struct {
            status: u16 = 400,
            headers: struct {},
            body: void,
        },
        status_401: struct {
            status: u16 = 401,
            headers: struct {},
            body: void,
        },
    };
    /// Creates a revocation rule to prevent the further usage of any OAuth authorizations that were created before the current point in time and which match the conditions in the rule. Not all kinds of OAuth authorizations can be revoked directly. Some, such as self-describing session tokens, must instead by revoked by creating a rule which will be evaluated and used to reject matching OAuth credentials at authentication time. Revocation rules created through this endpoint will apply to all credentials that were issued before the datetime at which the rule was created and which match one or more additional conditions.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.TokenAdminRevocationRule) !CreateResult {
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/tokenadmin/revocationrules", .{ self.endpoint, encoded_path_0 });
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

        switch (resp.status_code) {
            201 => {
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            400 => {
                return .{ .status_400 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            401 => {
                return .{ .status_401 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("RevocationRules.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Revocations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const RevokeAuthorizationsResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {},
            body: void,
        },
        status_400: struct {
            status: u16 = 400,
            headers: struct {},
            body: void,
        },
        status_401: struct {
            status: u16 = 401,
            headers: struct {},
            body: void,
        },
    };
    /// Revokes the listed OAuth authorizations.
    pub fn revokeAuthorizations(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, is_public: ?bool, body: []const models.TokenAdminRevocation) !RevokeAuthorizationsResult {
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/tokenadmin/revocations", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (is_public) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}isPublic={}", .{ sep, query_value });
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
        const body_json = try serde.json.toSlice(alloc, body);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            400 => {
                return .{ .status_400 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            401 => {
                return .{ .status_401 = .{
                    .status = resp.status_code,
                    .headers = .{},
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Revocations.revokeAuthorizations", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};
