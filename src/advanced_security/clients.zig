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
const default_endpoint = "https://advsec.dev.azure.com";
const default_api_version = "7.2-preview";
const auth_scopes: []const []const u8 = &.{"{endpoint}/.default"};

pub const AdvancedSecurityClient = struct {
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

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !AdvancedSecurityClient {
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
    ) AdvancedSecurityClient {
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

    pub fn filtersSettings(self: *@This()) FiltersSettings {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn summaryDashboard(self: *@This()) SummaryDashboard {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn alerts(self: *@This()) Alerts {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn instances(self: *@This()) Instances {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn metadata2(self: *@This()) Metadata2 {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn metadataBatch(self: *@This()) MetadataBatch {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn alertsBatch(self: *@This()) AlertsBatch {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn analysis(self: *@This()) Analysis {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pipelineAnalyses(self: *@This()) PipelineAnalyses {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pipelineAnalysis(self: *@This()) PipelineAnalysis {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn orgEnablement(self: *@This()) OrgEnablement {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn meterUsageOperations(self: *@This()) MeterUsageOperations {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn orgMeterUsageEstimate(self: *@This()) OrgMeterUsageEstimate {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn projectEnablement(self: *@This()) ProjectEnablement {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn projectMeterUsageEstimate(self: *@This()) ProjectMeterUsageEstimate {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn repoEnablement(self: *@This()) RepoEnablement {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn repoMeterUsageEstimate(self: *@This()) RepoMeterUsageEstimate {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const FiltersSettings = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Gets all advanced filters for the organization.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, include_deleted: ?bool, keywords: ?[]const u8) !models.AdvancedFilterList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/filtersSettings/alertsbatch", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_deleted) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeDeleted={}", .{ sep, query_value });
            has_query = true;
        }
        if (keywords) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}keywords={s}", .{ sep, enc });
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
            core.pager.logHttpError("FiltersSettings.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AdvancedFilterList, alloc, resp.body);
    }
    /// Creates a new advanced filter for the organization.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.AdvancedFilterCreate) !models.AdvancedFilter {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/filtersSettings/alertsbatch", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("FiltersSettings.create", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AdvancedFilter, alloc, resp.body);
    }
    /// Deletes an advanced filter.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, filter_id: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, filter_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/filtersSettings/alertsbatch/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("FiltersSettings.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Gets a specific advanced filter by its ID.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, filter_id: []const u8) !models.AdvancedFilter {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, filter_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/filtersSettings/alertsbatch/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("FiltersSettings.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AdvancedFilter, alloc, resp.body);
    }
    /// Updates an advanced filter. Only the name can be updated.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, filter_id: []const u8, body: models.AdvancedFilterUpdate) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, filter_id);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/filtersSettings/alertsbatch/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("FiltersSettings.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const SummaryDashboard = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const ListResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                x_ms_continuationtoken: ?[]const u8 = null,
            },
            body: models.DashboardAlertList,
        },
    };
    /// Get Alert summary by severity for the org
    pub fn getAlertSummaryForOrg(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, criteria_alert_types: ?[]const []const u8, criteria_keywords: ?[]const u8, @"criteria.period": ?enums.GetAlertSummaryForOrgRequestCriteriaPeriod, criteria_projects: ?[]const []const u8, criteria_severities: ?[]const []const u8) !models.OrgAlertSummary {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/summary/alerts", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (criteria_alert_types) |items| {
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
                try url_buf.print(alloc, "{s}criteria.alertTypes={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_keywords) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.keywords={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"criteria.period") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.period={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_projects) |items| {
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
                try url_buf.print(alloc, "{s}criteria.projects={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_severities) |items| {
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
                try url_buf.print(alloc, "{s}criteria.severities={s}", .{ sep, enc });
                has_query = true;
            }
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
            core.pager.logHttpError("SummaryDashboard.getAlertSummaryForOrg", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OrgAlertSummary, alloc, resp.body);
    }
    /// Get Combined Alerts for the org
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, @"criteria.alert_type": ?enums.ListRequestCriteriaAlertType, @"criteria.alert_validity_status": ?enums.ListRequestCriteriaAlertValidityStatus, criteria_component_names: ?[]const []const u8, criteria_component_types: ?[]const []const u8, criteria_dismissal_types: ?[]const []const u8, criteria_fixed_date_end: ?[]const u8, criteria_fixed_date_start: ?[]const u8, criteria_introduced_date_end: ?[]const u8, criteria_introduced_date_start: ?[]const u8, criteria_keywords: ?[]const u8, criteria_projects: ?[]const []const u8, criteria_repositories: ?[]const []const u8, criteria_repository_ids: ?[]const []const u8, criteria_rule_names: ?[]const []const u8, criteria_secret_types: ?[]const []const u8, criteria_severities: ?[]const []const u8, @"criteria.state": ?enums.ListRequestCriteriaState, criteria_tool_names: ?[]const []const u8, top: ?i32, continuation_token: ?[]const u8) !ListResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/summary/alertsbatch", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"criteria.alert_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.alertType={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"criteria.alert_validity_status") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.alertValidityStatus={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_component_names) |items| {
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
                try url_buf.print(alloc, "{s}criteria.componentNames={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_component_types) |items| {
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
                try url_buf.print(alloc, "{s}criteria.componentTypes={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_dismissal_types) |items| {
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
                try url_buf.print(alloc, "{s}criteria.dismissalTypes={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_fixed_date_end) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.fixedDateEnd={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_fixed_date_start) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.fixedDateStart={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_introduced_date_end) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.introducedDateEnd={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_introduced_date_start) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.introducedDateStart={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_keywords) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.keywords={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_projects) |items| {
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
                try url_buf.print(alloc, "{s}criteria.projects={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_repositories) |items| {
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
                try url_buf.print(alloc, "{s}criteria.repositories={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_repository_ids) |items| {
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
                try url_buf.print(alloc, "{s}criteria.repositoryIds={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_rule_names) |items| {
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
                try url_buf.print(alloc, "{s}criteria.ruleNames={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_secret_types) |items| {
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
                try url_buf.print(alloc, "{s}criteria.secretTypes={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_severities) |items| {
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
                try url_buf.print(alloc, "{s}criteria.severities={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (@"criteria.state") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.state={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_tool_names) |items| {
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
                try url_buf.print(alloc, "{s}criteria.toolNames={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_20 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_20);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_20 });
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
                const response_body = try serde.json.fromSlice(models.DashboardAlertList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .x_ms_continuationtoken = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("SummaryDashboard.list", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get Enablement summary for the org
    pub fn getEnablementSummaryForOrg(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, criteria_keywords: ?[]const u8, criteria_projects: ?[]const []const u8, criteria_states_any_tool: ?bool, criteria_states_code_alerts: ?bool, criteria_states_code_pr_alerts: ?bool, criteria_states_dependency_alerts: ?bool, criteria_states_dependency_pr_alerts: ?bool, criteria_states_push_protection: ?bool, criteria_states_secret_alerts: ?bool) !models.OrgEnablementSummary {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/reporting/summary/enablement", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (criteria_keywords) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.keywords={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_projects) |items| {
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
                try url_buf.print(alloc, "{s}criteria.projects={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_states_any_tool) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.anyTool={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_code_alerts) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.codeAlerts={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_code_pr_alerts) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.codePRAlerts={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_dependency_alerts) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.dependencyAlerts={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_dependency_pr_alerts) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.dependencyPRAlerts={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_push_protection) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.pushProtection={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_states_secret_alerts) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.states.secretAlerts={}", .{ sep, query_value });
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
            core.pager.logHttpError("SummaryDashboard.getEnablementSummaryForOrg", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OrgEnablementSummary, alloc, resp.body);
    }
};

pub const Alerts = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const ListResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                x_ms_continuationtoken: ?[]const u8 = null,
            },
            body: models.AlertList,
        },
    };
    /// Get alerts for a repository
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, top: ?i32, order_by: ?[]const u8, criteria_alert_ids: ?[]const i64, @"criteria.alert_type": ?enums.ListRequestCriteriaAlertType, criteria_confidence_levels: ?[]const []const u8, criteria_dependency_name: ?[]const u8, criteria_from_date: ?[]const u8, criteria_has_linked_work_items: ?bool, criteria_is_triaged: ?bool, criteria_keywords: ?[]const u8, criteria_license_name: ?[]const u8, criteria_modified_since: ?[]const u8, criteria_only_default_branch: ?bool, criteria_phase_id: ?[]const u8, criteria_phase_name: ?[]const u8, criteria_pipeline_id: ?i32, criteria_pipeline_name: ?[]const u8, criteria_ref: ?[]const u8, criteria_rule_id: ?[]const u8, criteria_rule_name: ?[]const u8, criteria_severities: ?[]const []const u8, criteria_states: ?[]const []const u8, criteria_to_date: ?[]const u8, criteria_tool_name: ?[]const u8, criteria_validity: ?[]const []const u8, expand: ?enums.ListRequestExpand, continuation_token: ?[]const u8) !ListResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
        if (order_by) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}orderBy={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_alert_ids) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.print(alloc, "{d}", .{item});
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}criteria.alertIds={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (@"criteria.alert_type") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.alertType={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_confidence_levels) |items| {
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
                try url_buf.print(alloc, "{s}criteria.confidenceLevels={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_dependency_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.dependencyName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_from_date) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.fromDate={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_has_linked_work_items) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.hasLinkedWorkItems={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_is_triaged) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.isTriaged={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_keywords) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.keywords={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_license_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.licenseName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_modified_since) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.modifiedSince={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_only_default_branch) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.onlyDefaultBranch={}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_phase_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.phaseId={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_phase_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.phaseName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_pipeline_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}criteria.pipelineId={d}", .{ sep, query_value });
            has_query = true;
        }
        if (criteria_pipeline_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.pipelineName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.ref={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_rule_id) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.ruleId={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_rule_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.ruleName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_severities) |items| {
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
                try url_buf.print(alloc, "{s}criteria.severities={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_states) |items| {
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
                try url_buf.print(alloc, "{s}criteria.states={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (criteria_to_date) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.toDate={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_tool_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}criteria.toolName={s}", .{ sep, enc });
            has_query = true;
        }
        if (criteria_validity) |items| {
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
                try url_buf.print(alloc, "{s}criteria.validity={s}", .{ sep, enc });
                has_query = true;
            }
        }
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
        const encoded_query_27 = try core.url.percentEncode(alloc, self.api_version);
        defer alloc.free(encoded_query_27);
        try url_buf.print(alloc, "{s}api-version={s}", .{ if (has_query) "&" else "?", encoded_query_27 });
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
                const response_body = try serde.json.fromSlice(models.AlertList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .x_ms_continuationtoken = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Alerts.list", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Get an alert.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, alert_id: i64, repository: []const u8, ref: ?[]const u8, expand: ?enums.GetRequestExpand) !models.Alert {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, alert_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}ref={s}", .{ sep, enc });
            has_query = true;
        }
        if (expand) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}expand={s}", .{ sep, enc });
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
            core.pager.logHttpError("Alerts.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Alert, alloc, resp.body);
    }
    /// Update the status of an alert
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, alert_id: i64, repository: []const u8, body: models.AlertStateUpdate) !models.Alert {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, alert_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
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
            core.pager.logHttpError("Alerts.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.Alert, alloc, resp.body);
    }
};

pub const Instances = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get instances of an alert on a branch specified with @ref. If @ref is not provided, return instances of an alert on default branch(if the alert exist in default branch) or latest affected branch.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, alert_id: i64, repository: []const u8, ref: ?[]const u8) !models.AlertAnalysisInstanceList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, alert_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts/{s}/instances", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (ref) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}ref={s}", .{ sep, enc });
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
            core.pager.logHttpError("Instances.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AlertAnalysisInstanceList, alloc, resp.body);
    }
};

pub const Metadata2 = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get an alert metadata.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, alert_id: i64, repository: []const u8) !models.AlertMetadata {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, alert_id);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts/{s}/metadata", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_3, encoded_path_2 });
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
            core.pager.logHttpError("Metadata2.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AlertMetadata, alloc, resp.body);
    }
};

pub const MetadataBatch = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get alerts metadata.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, body: models.AlertMetadataBatchRequest) !models.AlertMetadataList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/alerts/metadatabatch", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("MetadataBatch.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AlertMetadataList, alloc, resp.body);
    }
};

pub const AlertsBatch = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get alerts by alert IDs Currently supports fetching secret alerts only.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, body: models.AlertBatchRequest) !models.AlertList {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/AlertsBatch", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("AlertsBatch.list", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.AlertList, alloc, resp.body);
    }
};

pub const Analysis = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const ListResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                x_ms_continuationtoken: ?[]const u8 = null,
            },
            body: models.BranchList,
        },
    };
    /// Returns the branches for which analysis results were submitted.
    pub fn list(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, alert_type: enums.ListRequestAlertType, continuation_token: ?[]const u8, branch_name_contains: ?[]const u8, top: ?i32, include_pull_request_branches: ?bool) !ListResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/filters/branches", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, alert_type.toWire());
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}alertType={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (continuation_token) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}continuationToken={s}", .{ sep, enc });
            has_query = true;
        }
        if (branch_name_contains) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}branchNameContains={s}", .{ sep, enc });
            has_query = true;
        }
        if (top) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (include_pull_request_branches) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includePullRequestBranches={}", .{ sep, query_value });
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
                const response_body = try serde.json.fromSlice(models.BranchList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .x_ms_continuationtoken = response_header_0,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Analysis.list", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const PipelineAnalyses = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Soft-deletes analysis data for all pipelines in a repository, cleaning up the associated Advanced Security alerts.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/pipelineAnalyses", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("PipelineAnalyses.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const PipelineAnalysis = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Soft-deletes analysis data for a specific pipeline, cleaning up the associated Advanced Security alerts.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, ado_pipeline_id: i32) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const encoded_path_3 = try core.url.encodePathSegment(alloc, ado_pipeline_id);
        defer alloc.free(encoded_path_3);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/alert/repositories/{s}/pipelineAnalysis/{s}", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2, encoded_path_3 });
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
            core.pager.logHttpError("PipelineAnalysis.delete", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const OrgEnablement = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get the current status of Advanced Security for the organization
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, include_all_properties: ?bool) !models.OrgEnablementSettings {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/management/enablement", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_all_properties) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAllProperties={}", .{ sep, query_value });
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
            core.pager.logHttpError("OrgEnablement.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.OrgEnablementSettings, alloc, resp.body);
    }
    /// Update the status of Advanced Security for the organization
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, body: models.OrgEnablementSettings) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/management/enablement", .{ self.endpoint, encoded_path_0 });
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
            core.pager.logHttpError("OrgEnablement.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const MeterUsageOperations = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get commiters used when calculating billing information.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, plan: enums.GetRequestPlan, billing_date: ?[]const u8) !models.MeterUsageForPlan {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/management/meterusage/default", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, plan.toWire());
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}plan={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (billing_date) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}billingDate={s}", .{ sep, enc });
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
            core.pager.logHttpError("MeterUsageOperations.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.MeterUsageForPlan, alloc, resp.body);
    }
};

pub const OrgMeterUsageEstimate = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Estimate the pushers that would be added to the customer's usage if Advanced Security was enabled for this organization.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, plan: ?enums.GetRequestPlan1) !models.MeterUsageEstimate {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/_apis/management/meterUsageEstimate/default", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (plan) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}plan={s}", .{ sep, enc });
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
            core.pager.logHttpError("OrgMeterUsageEstimate.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.MeterUsageEstimate, alloc, resp.body);
    }
};

pub const ProjectEnablement = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Get the current status of Advanced Security for a project
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, include_all_properties: ?bool) !models.ProjectEnablementSettings {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/enablement", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_all_properties) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAllProperties={}", .{ sep, query_value });
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
            core.pager.logHttpError("ProjectEnablement.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.ProjectEnablementSettings, alloc, resp.body);
    }
    /// Update the status of Advanced Security for the project
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, body: models.ProjectEnablementSettings) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/enablement", .{ self.endpoint, encoded_path_0, encoded_path_1 });
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
            core.pager.logHttpError("ProjectEnablement.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const ProjectMeterUsageEstimate = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Estimate the pushers that would be added to the customer's usage if Advanced Security was enabled for this project.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, plan: ?enums.GetRequestPlan2) !models.MeterUsageEstimate {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/meterUsageEstimate/default", .{ self.endpoint, encoded_path_0, encoded_path_1 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (plan) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}plan={s}", .{ sep, enc });
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
            core.pager.logHttpError("ProjectMeterUsageEstimate.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.MeterUsageEstimate, alloc, resp.body);
    }
};

pub const RepoEnablement = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Determines if Code Security, Secret Protection, and their features are enabled for the repository.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, include_all_properties: ?bool) !models.RepoEnablementSettings {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/repositories/{s}/enablement", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (include_all_properties) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}includeAllProperties={}", .{ sep, query_value });
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
            core.pager.logHttpError("RepoEnablement.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.RepoEnablementSettings, alloc, resp.body);
    }
    /// Update the enablement status of Code Security and Secret Protection, along with their respective features, for a given repository.
    pub fn update(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, body: models.RepoEnablementSettings) !void {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/repositories/{s}/enablement", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
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
            core.pager.logHttpError("RepoEnablement.update", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
};

pub const RepoMeterUsageEstimate = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    /// Estimate the pushers that would be added to the customer's usage if Advanced Security was enabled for this repository.
    pub fn get(self: *@This(), alloc: std.mem.Allocator, organization: []const u8, project: []const u8, repository: []const u8, plan: ?enums.GetRequestPlan3) !models.MeterUsageEstimate {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, organization);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try core.url.encodePathSegment(alloc, project);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try core.url.encodePathSegment(alloc, repository);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}/{s}/_apis/management/repositories/{s}/meterUsageEstimate/default", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (plan) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}plan={s}", .{ sep, enc });
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
            core.pager.logHttpError("RepoMeterUsageEstimate.get", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.MeterUsageEstimate, alloc, resp.body);
    }
};
