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

pub const TestClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !TestClient {
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
    ) TestClient {
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

    pub fn codeCoverage(self: *@This()) CodeCoverage {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn points(self: *@This()) Points {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testSuites(self: *@This()) TestSuites {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn resultRetentionSettingsOperations(self: *@This()) ResultRetentionSettingsOperations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testHistory(self: *@This()) TestHistory {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn runs(self: *@This()) Runs {
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

    pub fn results(self: *@This()) Results {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn iterations(self: *@This()) Iterations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testCases(self: *@This()) TestCases {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn session(self: *@This()) Session {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const CodeCoverage = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get code coverage data for a build.
    pub fn getBuildCodeCoverage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, build_id: i32, flags: i32) ![]const models.BuildCoverage {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/codecoverage", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}buildId={d}", .{ if (has_query) "&" else "?", build_id });
        has_query = true;
        try url_buf.print(alloc, "{s}flags={d}", .{ if (has_query) "&" else "?", flags });
        has_query = true;
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
            core.pager.logHttpError("CodeCoverage.getBuildCodeCoverage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.BuildCoverage, alloc, resp.body);
    }
    /// Get code coverage data for a test run
    pub fn getTestRunCodeCoverage(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, flags: i32) ![]const models.TestRunCoverage {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/codecoverage", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}flags={d}", .{ if (has_query) "&" else "?", flags });
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
            core.pager.logHttpError("CodeCoverage.getTestRunCodeCoverage", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestRunCoverage, alloc, resp.body);
    }
};

pub const Points = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test points.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, wit_fields: ?[]const u8, configuration_id: ?[]const u8, test_case_id: ?[]const u8, test_point_ids: ?[]const u8, include_point_details: ?bool, @"$skip": ?i32, @"$top": ?i32) ![]const models.TestPoint {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/Suites/{s}/points", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (wit_fields) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}witFields={s}", .{ sep, enc });
            has_query = true;
        }
        if (configuration_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}configurationId={s}", .{ sep, enc });
            has_query = true;
        }
        if (test_case_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}testCaseId={s}", .{ sep, enc });
            has_query = true;
        }
        if (test_point_ids) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}testPointIds={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_point_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includePointDetails={}", .{ sep, query_value });
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
        const encoded_query_7 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_7);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_7 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("Points.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPoint, alloc, resp.body);
    }
    /// Get a test point.
    pub fn getPoint(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, point_ids: i32, wit_fields: ?[]const u8) !models.TestPoint {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, point_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/Suites/{s}/points/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (wit_fields) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}witFields={s}", .{ sep, enc });
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
            core.pager.logHttpError("Points.getPoint", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestPoint, alloc, resp.body);
    }
    /// Update test points.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, point_ids: []const u8, body: models.PointUpdateModel) ![]const models.TestPoint {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, point_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/Suites/{s}/points/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("Points.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPoint, alloc, resp.body);
    }
    /// Get test points using query.
    pub fn getPointsByQuery(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, @"$skip": ?i32, @"$top": ?i32, body: models.TestPointsQuery) !models.TestPointsQuery {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/points", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
        const encoded_query_2 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_2);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_2 });
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
            core.pager.logHttpError("Points.getPointsByQuery", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestPointsQuery, alloc, resp.body);
    }
};

pub const TestSuites = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get all test cases in a suite.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32) ![]const models.SuiteTestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/suites/{s}/testcases", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("TestSuites.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SuiteTestCase, alloc, resp.body);
    }
    /// The test points associated with the test cases are removed from the test suite. The test case work item is not deleted from the system. See test cases resource to delete a test case permanently.
    pub fn removeTestCasesFromSuiteUrl(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_case_ids: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, test_case_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/suites/{s}/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("TestSuites.removeTestCasesFromSuiteUrl", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a specific test case in a test suite with test case id.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_case_ids: i32) !models.SuiteTestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, test_case_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/suites/{s}/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("TestSuites.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SuiteTestCase, alloc, resp.body);
    }
    /// Updates the properties of the test case association in a suite.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_case_ids: []const u8, body: models.SuiteTestCaseUpdateModel) ![]const models.SuiteTestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, test_case_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/suites/{s}/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
            core.pager.logHttpError("TestSuites.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SuiteTestCase, alloc, resp.body);
    }
    /// Add test cases to suite.
    pub fn add(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_case_ids: []const u8) ![]const models.SuiteTestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, test_case_ids);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Plans/{s}/suites/{s}/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!responseStatusExpected(resp.status_code, &.{200})) {
            core.pager.logHttpError("TestSuites.add", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SuiteTestCase, alloc, resp.body);
    }
};

pub const ResultRetentionSettingsOperations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get test result retention settings
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8) !models.ResultRetentionSettings {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/resultretentionsettings", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("ResultRetentionSettingsOperations.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ResultRetentionSettings, alloc, resp.body);
    }
    /// Update test result retention settings
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.ResultRetentionSettings) !models.ResultRetentionSettings {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/resultretentionsettings", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("ResultRetentionSettingsOperations.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ResultRetentionSettings, alloc, resp.body);
    }
};

pub const TestHistory = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get history of a test method using TestHistoryQuery
    pub fn query(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.TestHistoryQuery) !models.TestHistoryQuery {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Results/testhistory", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("TestHistory.query", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestHistoryQuery, alloc, resp.body);
    }
};

pub const Runs = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test runs.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, build_uri: ?[]const u8, owner: ?[]const u8, tmi_run_id: ?[]const u8, plan_id: ?i32, include_run_details: ?bool, automated: ?bool, @"$skip": ?i32, @"$top": ?i32) ![]const models.TestRun {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (build_uri) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}buildUri={s}", .{ sep, enc });
            has_query = true;
        }
        if (owner) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}owner={s}", .{ sep, enc });
            has_query = true;
        }
        if (tmi_run_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}tmiRunId={s}", .{ sep, enc });
            has_query = true;
        }
        if (plan_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}planId={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_run_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeRunDetails={}", .{ sep, query_value });
            has_query = true;
        }
        if (automated) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}automated={}", .{ sep, query_value });
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
            core.pager.logHttpError("Runs.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestRun, alloc, resp.body);
    }
    /// Create new test run.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.RunCreateModel) !models.TestRun {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Runs.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestRun, alloc, resp.body);
    }
    /// Delete a test run by its ID.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Runs.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a test run by its ID.
    pub fn getTestRunById(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, include_details: ?bool) !models.TestRun {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeDetails={}", .{ sep, query_value });
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
            core.pager.logHttpError("Runs.getTestRunById", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestRun, alloc, resp.body);
    }
    /// Update test run by its ID.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, body: models.RunUpdateModel) !models.TestRun {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Runs.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestRun, alloc, resp.body);
    }
    /// Get test run statistics , used when we want to get summary of a run by outcome.
    pub fn getTestRunStatistics(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32) !models.TestRunStatistic {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/runs/{s}/Statistics", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Runs.getTestRunStatistics", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestRunStatistic, alloc, resp.body);
    }
};

pub const Attachments = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const GetTestRunAttachmentZipResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const GetTestResultAttachmentZipResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Get list of test run attachments reference.
    pub fn getTestRunAttachments(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32) ![]const models.TestAttachment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Attachments.getTestRunAttachments", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestAttachment, alloc, resp.body);
    }
    /// Attach a file to a test run.
    pub fn createTestRunAttachment(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, body: models.TestAttachmentRequestModel) !models.TestAttachmentReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Attachments.createTestRunAttachment", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestAttachmentReference, alloc, resp.body);
    }
    /// Download a test run attachment by its ID.
    pub fn getTestRunAttachmentZip(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, attachment_id: i32) !GetTestRunAttachmentZipResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, attachment_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/attachments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
                core.pager.logHttpError("Attachments.getTestRunAttachmentZip", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get list of test result attachments reference.
    pub fn getTestResultAttachments(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32) ![]const models.TestAttachment {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/Results/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Attachments.getTestResultAttachments", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestAttachment, alloc, resp.body);
    }
    /// Attach a file to a test result.
    pub fn createTestResultAttachment(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32, body: models.TestAttachmentRequestModel) !models.TestAttachmentReference {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/Results/{s}/attachments", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("Attachments.createTestResultAttachment", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestAttachmentReference, alloc, resp.body);
    }
    /// Download a test result attachment by its ID.
    pub fn getTestResultAttachmentZip(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32, attachment_id: i32) !GetTestResultAttachmentZipResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, attachment_id);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/Results/{s}/attachments/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
                core.pager.logHttpError("Attachments.getTestResultAttachmentZip", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Results = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get test results for a test run.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, details_to_include: ?enums.ListRequestDetailsToInclude, @"$skip": ?i32, @"$top": ?i32, outcomes: ?[]const u8) ![]const models.TestCaseResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/results", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (details_to_include) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}detailsToInclude={s}", .{ sep, enc });
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
        if (outcomes) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}outcomes={s}", .{ sep, enc });
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
            core.pager.logHttpError("Results.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCaseResult, alloc, resp.body);
    }
    /// Update test results in a test run.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, body: []const models.TestCaseResult) ![]const models.TestCaseResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/results", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Results.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCaseResult, alloc, resp.body);
    }
    /// Add test results to a test run.
    pub fn add(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, body: []const models.TestCaseResult) ![]const models.TestCaseResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/results", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Results.add", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCaseResult, alloc, resp.body);
    }
    /// Get a test result for a test run.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32, details_to_include: ?enums.GetRequestDetailsToInclude) !models.TestCaseResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/results/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (details_to_include) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}detailsToInclude={s}", .{ sep, enc });
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
            core.pager.logHttpError("Results.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestCaseResult, alloc, resp.body);
    }
};

pub const Iterations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get iterations for a result
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32, include_action_results: ?bool) ![]const models.TestIterationDetailsModel {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/Results/{s}/iterations", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_action_results) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeActionResults={}", .{ sep, query_value });
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
            core.pager.logHttpError("Iterations.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestIterationDetailsModel, alloc, resp.body);
    }
    /// Get iteration for a result
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, run_id: i32, test_case_result_id: i32, iteration_id: i32, include_action_results: ?bool) !models.TestIterationDetailsModel {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, run_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, test_case_result_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, iteration_id);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/Runs/{s}/Results/{s}/iterations/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_action_results) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeActionResults={}", .{ sep, query_value });
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
            core.pager.logHttpError("Iterations.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestIterationDetailsModel, alloc, resp.body);
    }
};

pub const TestCases = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Delete a test case.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_case_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, test_case_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/test/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestCases.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const Session = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test sessions
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, team: []const u8, period: ?i32, all_sessions: ?bool, include_all_properties: ?bool, source: ?enums.ListRequestSource, include_only_completed_sessions: ?bool) ![]const models.TestSession {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/{s}/_apis/test/session", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (period) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}period={d}", .{ sep, query_value });
            has_query = true;
        }
        if (all_sessions) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}allSessions={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_all_properties) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAllProperties={}", .{ sep, query_value });
            has_query = true;
        }
        if (source) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}source={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_only_completed_sessions) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeOnlyCompletedSessions={}", .{ sep, query_value });
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
            core.pager.logHttpError("Session.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestSession, alloc, resp.body);
    }
    /// Update a test session
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, team: []const u8, body: models.TestSession) !models.TestSession {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/{s}/_apis/test/session", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Session.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestSession, alloc, resp.body);
    }
    /// Create a test session
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, team: []const u8, body: models.TestSession) !models.TestSession {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, team);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/{s}/_apis/test/session", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Session.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestSession, alloc, resp.body);
    }
};
