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

pub const TestPlanClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !TestPlanClient {
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
    ) TestPlanClient {
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

    pub fn testSuites(self: *@This()) TestSuites {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn configurations(self: *@This()) Configurations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testPlans(self: *@This()) TestPlans {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn suiteTestCase(self: *@This()) SuiteTestCase {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testPointOperations(self: *@This()) TestPointOperations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testPlanClone(self: *@This()) TestPlanClone {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testPlanRecycleBin(self: *@This()) TestPlanRecycleBin {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testSuiteRecycleBinOperations(self: *@This()) TestSuiteRecycleBinOperations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testSuiteEntry(self: *@This()) TestSuiteEntry {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn testSuiteClone(self: *@This()) TestSuiteClone {
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

    pub fn testCaseClone(self: *@This()) TestCaseClone {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn variables(self: *@This()) Variables {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const TestSuites = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Find the list of all test suites in which a given test case is present. This is helpful if you need to find out which test suites are using a test case, when you need to make changes to a test case.
    pub fn getSuitesByTestCaseId(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, test_case_id: i32) ![]const models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/testplan/suites", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}testCaseId={d}", .{ if (has_query) "&" else "?", test_case_id });
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
            core.pager.logHttpError("TestSuites.getSuitesByTestCaseId", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestSuite, alloc, resp.body);
    }
    /// Get test suites for plan.
    pub fn getTestSuitesForPlan(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, expand: ?enums.GetTestSuitesForPlanRequestExpand, continuation_token: ?[]const u8, as_tree_view: ?bool) ![]const models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/suites", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}expand={s}", .{ sep, enc });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (as_tree_view) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}asTreeView={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestSuites.getTestSuitesForPlan", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestSuite, alloc, resp.body);
    }
    /// Create test suite.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, body: models.TestSuiteCreateParams) !models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/suites", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestSuites.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestSuite, alloc, resp.body);
    }
    /// Delete test suite.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/suites/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("TestSuites.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get test suite by suite id.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, expand: ?enums.GetRequestExpand) !models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/suites/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}expand={s}", .{ sep, enc });
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
            core.pager.logHttpError("TestSuites.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestSuite, alloc, resp.body);
    }
    /// Update test suite.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, body: models.TestSuiteUpdateParams) !models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/suites/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
        return try serde.json.fromSlice(models.TestSuite, alloc, resp.body);
    }
};

pub const Configurations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Delete a test configuration by its ID.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_configuartion_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/configurations", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}testConfiguartionId={d}", .{ if (has_query) "&" else "?", test_configuartion_id });
        has_query = true;
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
            core.pager.logHttpError("Configurations.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a list of test configurations.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, continuation_token: ?[]const u8) ![]const models.TestConfiguration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/configurations", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
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
            core.pager.logHttpError("Configurations.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestConfiguration, alloc, resp.body);
    }
    /// Update a test configuration by its ID.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_configuartion_id: i32, body: models.TestConfigurationCreateUpdateParameters) !models.TestConfiguration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/configurations", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        try url_buf.print(alloc, "{s}testConfiguartionId={d}", .{ if (has_query) "&" else "?", test_configuartion_id });
        has_query = true;
        const encoded_query_1 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
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
            core.pager.logHttpError("Configurations.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestConfiguration, alloc, resp.body);
    }
    /// Create a test configuration.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.TestConfigurationCreateUpdateParameters) !models.TestConfiguration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/configurations", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Configurations.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestConfiguration, alloc, resp.body);
    }
    /// Get a test configuration
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_configuration_id: i32) !models.TestConfiguration {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, test_configuration_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/configurations/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Configurations.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestConfiguration, alloc, resp.body);
    }
};

pub const TestPlans = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test plans
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, owner: ?[]const u8, continuation_token: ?[]const u8, include_plan_details: ?bool, filter_active_plans: ?bool) ![]const models.TestPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/plans", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (owner) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}owner={s}", .{ sep, enc });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (include_plan_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includePlanDetails={}", .{ sep, query_value });
            has_query = true;
        }
        if (filter_active_plans) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}filterActivePlans={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestPlans.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPlan, alloc, resp.body);
    }
    /// Create a test plan.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.TestPlanCreateParams) !models.TestPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/plans", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("TestPlans.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestPlan, alloc, resp.body);
    }
    /// Delete a test plan.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/plans/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestPlans.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a test plan by Id.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32) !models.TestPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/plans/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestPlans.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestPlan, alloc, resp.body);
    }
    /// Update a test plan.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, body: models.TestPlanUpdateParams) !models.TestPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/plans/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestPlans.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestPlan, alloc, resp.body);
    }
};

pub const SuiteTestCase = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Removes test cases from a suite based on the list of test case Ids provided. This API can be used to remove a larger number of test cases.
    pub fn removeTestCasesListFromSuite(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_ids: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestCase", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, test_ids);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}testIds={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
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
            core.pager.logHttpError("SuiteTestCase.removeTestCasesListFromSuite", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get Test Case List return those test cases which have all the configuration Ids as mentioned in the optional parameter. If configuration Ids is null, it return all the test cases
    pub fn getTestCaseList(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_ids: ?[]const u8, configuration_ids: ?[]const u8, wit_fields: ?[]const u8, continuation_token: ?[]const u8, return_identity_ref: ?bool, expand: ?bool, exclude_flags: ?enums.GetTestCaseListRequestExcludeFlags, is_recursive: ?bool) ![]const models.TestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestCase", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (test_ids) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}testIds={s}", .{ sep, enc });
            has_query = true;
        }
        if (configuration_ids) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}configurationIds={s}", .{ sep, enc });
            has_query = true;
        }
        if (wit_fields) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}witFields={s}", .{ sep, enc });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (return_identity_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}returnIdentityRef={}", .{ sep, query_value });
            has_query = true;
        }
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}expand={}", .{ sep, query_value });
            has_query = true;
        }
        if (exclude_flags) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}excludeFlags={s}", .{ sep, enc });
            has_query = true;
        }
        if (is_recursive) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}isRecursive={}", .{ sep, query_value });
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
            core.pager.logHttpError("SuiteTestCase.getTestCaseList", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCase, alloc, resp.body);
    }
    /// Update the configurations for test cases
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, body: []const models.SuiteTestCaseCreateUpdateParameters) ![]const models.TestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestCase", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("SuiteTestCase.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCase, alloc, resp.body);
    }
    /// Add test cases to a suite with specified configurations
    pub fn add(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, body: []const models.SuiteTestCaseCreateUpdateParameters) ![]const models.TestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestCase", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("SuiteTestCase.add", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCase, alloc, resp.body);
    }
    /// Get a particular Test Case from a Suite.
    pub fn getTestCase(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, test_case_id: []const u8, wit_fields: ?[]const u8, return_identity_ref: ?bool) ![]const models.TestCase {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const encoded_path_4 = try core.url.encodePathSegment(alloc, test_case_id);
        defer alloc.free(encoded_path_4);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestCase/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3, encoded_path_4 });
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
        if (return_identity_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}returnIdentityRef={}", .{ sep, query_value });
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
            core.pager.logHttpError("SuiteTestCase.getTestCase", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestCase, alloc, resp.body);
    }
};

pub const TestPointOperations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a particular Test Point from a suite.
    pub fn getPoints(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, point_id: []const u8, return_identity_ref: ?bool, include_point_details: ?bool) ![]const models.TestPoint {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestPoint", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, point_id);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}pointId={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (return_identity_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}returnIdentityRef={}", .{ sep, query_value });
            has_query = true;
        }
        if (include_point_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includePointDetails={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestPointOperations.getPoints", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPoint, alloc, resp.body);
    }
    /// Update Test Points. This is used to Reset test point to active, update the outcome of a test point or update the tester of a test point
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, suite_id: i32, include_point_details: ?bool, return_identity_ref: ?bool, body: []const models.TestPointUpdateParams) ![]const models.TestPoint {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/{s}/Suites/{s}/TestPoint", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_point_details) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includePointDetails={}", .{ sep, query_value });
            has_query = true;
        }
        if (return_identity_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}returnIdentityRef={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestPointOperations.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPoint, alloc, resp.body);
    }
};

pub const TestPlanClone = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Clone test plan
    pub fn cloneTestPlan(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, deep_clone: ?bool, body: models.CloneTestPlanParams) !models.CloneTestPlanOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/CloneOperation", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (deep_clone) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}deepClone={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestPlanClone.cloneTestPlan", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestPlanOperationInformation, alloc, resp.body);
    }
    /// Get clone information.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, clone_operation_id: i32) !models.CloneTestPlanOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, clone_operation_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Plans/CloneOperation/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestPlanClone.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestPlanOperationInformation, alloc, resp.body);
    }
};

pub const TestPlanRecycleBin = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of deleted test plans
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, continuation_token: ?[]const u8) ![]const models.TestPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/recycleBin/testplan", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
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
            core.pager.logHttpError("TestPlanRecycleBin.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestPlan, alloc, resp.body);
    }
    /// Restores the deleted test plan
    pub fn restoreDeletedTestPlan(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, body: models.TestPlanAndSuiteRestoreModel) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/recycleBin/testplan/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestPlanRecycleBin.restoreDeletedTestPlan", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const TestSuiteRecycleBinOperations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get Deleted Test Suites for a Test Plan.
    pub fn getDeletedTestSuitesForPlan(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan_id: i32, expand: ?enums.GetDeletedTestSuitesForPlanRequestExpand, continuation_token: ?[]const u8, as_tree_view: ?bool) ![]const models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, plan_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/recycleBin/TestPlan/{s}/testsuite", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}expand={s}", .{ sep, enc });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (as_tree_view) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}asTreeView={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestSuiteRecycleBinOperations.getDeletedTestSuitesForPlan", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestSuite, alloc, resp.body);
    }
    /// Get Deleted Test Suites within a Project.
    pub fn getDeletedTestSuitesForProject(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, expand: ?enums.GetDeletedTestSuitesForProjectRequestExpand, continuation_token: ?[]const u8, as_tree_view: ?bool) ![]const models.TestSuite {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/recycleBin/testsuite", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}expand={s}", .{ sep, enc });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (as_tree_view) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}asTreeView={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestSuiteRecycleBinOperations.getDeletedTestSuitesForProject", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestSuite, alloc, resp.body);
    }
    /// Restores the deleted test suite
    pub fn restoreDeletedTestSuite(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, suite_id: i32, body: models.TestPlanAndSuiteRestoreModel) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/recycleBin/testsuite/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestSuiteRecycleBinOperations.restoreDeletedTestSuite", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const TestSuiteEntry = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test suite entries in the test suite.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, suite_id: i32, suite_entry_type: ?enums.ListRequestSuiteEntryType) ![]const models.SuiteEntry {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/suiteentry/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (suite_entry_type) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}suiteEntryType={s}", .{ sep, enc });
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
            core.pager.logHttpError("TestSuiteEntry.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SuiteEntry, alloc, resp.body);
    }
    /// Reorder test suite entries in the test suite.
    pub fn reorderSuiteEntries(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, suite_id: i32, body: []const models.SuiteEntryUpdateParams) ![]const models.SuiteEntry {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, suite_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/suiteentry/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestSuiteEntry.reorderSuiteEntries", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.SuiteEntry, alloc, resp.body);
    }
};

pub const TestSuiteClone = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Clone test suite
    pub fn cloneTestSuite(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, deep_clone: ?bool, body: models.CloneTestSuiteParams) !models.CloneTestSuiteOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Suites/CloneOperation", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (deep_clone) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}deepClone={}", .{ sep, query_value });
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
            core.pager.logHttpError("TestSuiteClone.cloneTestSuite", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestSuiteOperationInformation, alloc, resp.body);
    }
    /// Get clone information.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, clone_operation_id: i32) !models.CloneTestSuiteOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, clone_operation_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/Suites/CloneOperation/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestSuiteClone.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestSuiteOperationInformation, alloc, resp.body);
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
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/testcases/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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

pub const TestCaseClone = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn cloneTestCase(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.CloneTestCaseParams) !models.CloneTestCaseOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/TestCases/CloneTestCaseOperation", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("TestCaseClone.cloneTestCase", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestCaseOperationInformation, alloc, resp.body);
    }
    /// Get clone information.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, clone_operation_id: i32) !models.CloneTestCaseOperationInformation {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, clone_operation_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/TestCases/CloneTestCaseOperation/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("TestCaseClone.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.CloneTestCaseOperationInformation, alloc, resp.body);
    }
};

pub const Variables = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get a list of test variables.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, continuation_token: ?[]const u8) ![]const models.TestVariable {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/variables", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
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
            core.pager.logHttpError("Variables.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice([]const models.TestVariable, alloc, resp.body);
    }
    /// Create a test variable.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.TestVariableCreateUpdateParameters) !models.TestVariable {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/variables", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("Variables.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestVariable, alloc, resp.body);
    }
    /// Delete a test variable by its ID.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_variable_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, test_variable_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/variables/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Variables.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Get a test variable by its ID.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_variable_id: i32) !models.TestVariable {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, test_variable_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/variables/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Variables.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestVariable, alloc, resp.body);
    }
    /// Update a test variable by its ID.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, test_variable_id: i32, body: models.TestVariableCreateUpdateParameters) !models.TestVariable {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, test_variable_id);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/testplan/variables/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("Variables.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.TestVariable, alloc, resp.body);
    }
};
