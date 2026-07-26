//! Header-continuation table and entity pagers.
//!
//! A page owns its values until the next page is requested or the pager is
//! deinitialized, whichever occurs first.

const std = @import("std");
const core = @import("azure_sdk_core");
const options = @import("options.zig");
const protocol_client = @import("protocol_client.zig");
const responses = @import("responses.zig");

pub const ListTablesPage = responses.SdkResponse(protocol_client.QueryTablesResponse);

pub const TablePager = struct {
    allocator: std.mem.Allocator,
    /// Owns immutable endpoint/version configuration while borrowing the
    /// parent client's heap-stable pipeline. The parent must outlive this pager.
    protocol: protocol_client.ProtocolClient,
    /// Owns option strings and policy-pointer storage. Policy objects remain
    /// borrowed and must outlive the pager.
    options: options.ListTablesOptions,
    continuation_token: ?[]u8,
    current: ?ListTablesPage = null,
    done: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        protocol: *protocol_client.ProtocolClient,
        list_options: options.ListTablesOptions,
    ) !TablePager {
        if (list_options.top) |top| {
            if (top <= 0) return error.InvalidTop;
        }
        var owned_protocol = try protocol.clone(allocator);
        errdefer owned_protocol.deinit();
        var owned_options = try copyListOptions(allocator, list_options);
        errdefer deinitListOptions(allocator, &owned_options);
        const continuation_token = if (list_options.continuation_token) |token|
            try allocator.dupe(u8, token)
        else
            null;
        errdefer if (continuation_token) |token| allocator.free(token);
        return .{
            .allocator = allocator,
            .protocol = owned_protocol,
            .options = owned_options,
            .continuation_token = continuation_token,
        };
    }

    pub fn deinit(self: *TablePager) void {
        if (self.current) |*page| page.deinit();
        if (self.continuation_token) |token| self.allocator.free(token);
        deinitListOptions(self.allocator, &self.options);
        self.protocol.deinit();
        self.* = undefined;
    }

    /// Returns a page borrowed from this pager, or `null` after the final
    /// continuation. The returned page stays valid until a later successful
    /// call to `nextPage` or `deinit`.
    pub fn nextPage(
        self: *TablePager,
    ) !responses.TableResult(?*const ListTablesPage) {
        if (self.done) return .{ .success = null };

        var query = self.options;
        query.continuation_token = self.continuation_token;
        const result = try self.protocol.queryTables(self.allocator, query);
        switch (result) {
            .failure => |failure| return .{ .failure = failure },
            .success => |fetched_page| {
                var page = fetched_page;
                errdefer page.deinit();
                const next_token = try continuationFromPage(self.allocator, &page);
                errdefer if (next_token) |token| self.allocator.free(token);

                if (self.current) |*old_page| old_page.deinit();
                self.current = page;
                if (self.continuation_token) |old_token| self.allocator.free(old_token);
                self.continuation_token = next_token;
                self.done = next_token == null;
                return .{ .success = &self.current.? };
            },
        }
    }

    pub fn next(
        self: *TablePager,
    ) !?*const ListTablesPage {
        return responses.unwrapListTables(
            ?*const ListTablesPage,
            try self.nextPage(),
        );
    }
};

fn copyListOptions(
    allocator: std.mem.Allocator,
    source: options.ListTablesOptions,
) !options.ListTablesOptions {
    var result: options.ListTablesOptions = .{
        .protocol = .{
            .metadata = null,
            .client_request_id = null,
            .timeout = source.protocol.timeout,
            .operation_timeout_ms = source.protocol.operation_timeout_ms,
            .policies = &.{},
        },
        .top = source.top,
        .select = null,
        .filter = null,
        .continuation_token = null,
    };
    errdefer deinitListOptions(allocator, &result);

    if (source.select) |value| result.select = try allocator.dupe(u8, value);
    if (source.filter) |value| result.filter = try allocator.dupe(u8, value);
    if (source.protocol.client_request_id) |value|
        result.protocol.client_request_id = try allocator.dupe(u8, value);
    if (source.protocol.metadata) |metadata| {
        result.protocol.metadata = switch (metadata) {
            .unrecognized => |value| .{ .unrecognized = try allocator.dupe(u8, value) },
            else => metadata,
        };
    }
    if (source.protocol.policies.len > 0)
        result.protocol.policies = try allocator.dupe(
            *core.pipeline.HttpPolicy,
            source.protocol.policies,
        );
    return result;
}

fn deinitListOptions(
    allocator: std.mem.Allocator,
    list_options: *options.ListTablesOptions,
) void {
    if (list_options.select) |value| allocator.free(value);
    if (list_options.filter) |value| allocator.free(value);
    if (list_options.protocol.client_request_id) |value| allocator.free(value);
    if (list_options.protocol.metadata) |metadata| switch (metadata) {
        .unrecognized => |value| allocator.free(value),
        else => {},
    };
    if (list_options.protocol.policies.len > 0)
        allocator.free(list_options.protocol.policies);
    list_options.* = undefined;
}

fn continuationFromPage(
    allocator: std.mem.Allocator,
    page: *const ListTablesPage,
) !?[]u8 {
    return switch (page.value) {
        .status_200 => |response| if (response.headers.next_table_name) |token|
            try allocator.dupe(u8, token)
        else
            null,
    };
}

const OptionPolicy = struct {
    calls: usize = 0,
    expected_request_id: []const u8,
    policy: core.pipeline.HttpPolicy = .{ .processFn = &process },

    fn process(
        policy: *core.pipeline.HttpPolicy,
        request: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) anyerror!core.http.Response {
        const self: *OptionPolicy = @alignCast(@fieldParentPtr("policy", policy));
        if (!std.mem.eql(
            u8,
            self.expected_request_id,
            request.getHeader("x-ms-client-request-id") orelse return error.MissingRequestId,
        )) return error.UnexpectedRequestId;
        self.calls += 1;
        if (next.len == 0) return transport.send(request);
        return next[0].process(request, next[1..], transport);
    }
};

test "table pager carries options and exact continuation bytes across pages" {
    const allocator = std.testing.allocator;
    const responses_for_pages = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"odata.metadata\":\"first\",\"value\":[{\"TableName\":\"First\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextTableName", .value = "Second table/?" },
            },
        },
        .{
            .status = 200,
            .body = "{\"odata.metadata\":\"second\",\"value\":[{\"TableName\":\"Second\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
            },
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses_for_pages);
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var protocol = try protocol_client.ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net",
        base_pipeline,
        .{},
    );
    defer protocol.deinit();

    var table_pager = try TablePager.init(allocator, &protocol, .{
        .top = 3,
        .select = "TableName",
        .filter = "TableName ge 'A'",
        .continuation_token = "Initial table/??",
        .protocol = .{
            .metadata = .full_metadata,
            .client_request_id = "list-request",
            .timeout = 40,
        },
    });
    defer table_pager.deinit();

    const first = try table_pager.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(@as(u16, 200), first.?.status);
    try std.testing.expectEqualStrings("first", switch (first.?.value) {
        .status_200 => |value| value.body.odata_metadata.?,
    });
    try std.testing.expectEqualStrings("First", switch (first.?.value) {
        .status_200 => |value| value.body.value.?[0].table_name.?,
    });
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables?$format=application%2Fjson%3Bodata%3Dfullmetadata&$top=3&$select=TableName&$filter=TableName%20ge%20%27A%27&NextTableName=Initial%20table%2F%3F%3F&timeout=40",
        transport.captured_urls[0][0..transport.captured_url_lengths[0]],
    );

    const second = try table_pager.next();
    try std.testing.expect(second != null);
    try std.testing.expectEqualStrings("second", switch (second.?.value) {
        .status_200 => |value| value.body.odata_metadata.?,
    });
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables?$format=application%2Fjson%3Bodata%3Dfullmetadata&$top=3&$select=TableName&$filter=TableName%20ge%20%27A%27&NextTableName=Second%20table%2F%3F&timeout=40",
        transport.captured_urls[1][0..transport.captured_url_lengths[1]],
    );
    try std.testing.expect((try table_pager.next()) == null);
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}

test "table pager represents each OData metadata format" {
    const allocator = std.testing.allocator;
    const cases = [_]struct {
        metadata: options.MetadataFormat,
        expected: []const u8,
    }{
        .{ .metadata = .no_metadata, .expected = "odata%3Dnometadata" },
        .{ .metadata = .minimal_metadata, .expected = "odata%3Dminimalmetadata" },
        .{ .metadata = .full_metadata, .expected = "odata%3Dfullmetadata" },
    };
    for (cases) |case| {
        var transport = core.http.MockTransport.init(
            allocator,
            200,
            "{\"value\":[{\"TableName\":\"Metadata\"}]}",
        );
        defer transport.deinit();
        transport.response_headers_list = &.{
            .{ .name = "x-ms-version", .value = "2019-02-02" },
            .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
            .{ .name = "Content-Type", .value = "application/json" },
        };
        const base_pipeline: core.pipeline.HttpPipeline = .{
            .policies = &.{},
            .transport_impl = transport.asTransport(),
        };
        var protocol = try protocol_client.ProtocolClient.init(
            allocator,
            "https://account.table.core.windows.net",
            base_pipeline,
            .{},
        );
        defer protocol.deinit();
        var table_pager = try TablePager.init(allocator, &protocol, .{
            .protocol = .{ .metadata = case.metadata },
        });
        defer table_pager.deinit();

        try std.testing.expect((try table_pager.next()) != null);
        try std.testing.expect(std.mem.indexOf(u8, transport.last_url.?, case.expected) != null);
    }
}

test "table pager owns list option bytes and policy pointer storage" {
    const allocator = std.testing.allocator;
    const pages = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"value\":[{\"TableName\":\"First\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextTableName", .value = "Second" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"TableName\":\"Second\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
            },
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &pages);
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var protocol = try protocol_client.ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net",
        base_pipeline,
        .{},
    );
    defer protocol.deinit();

    var select = [_]u8{ 'T', 'a', 'b', 'l', 'e', 'N', 'a', 'm', 'e' };
    var filter = [_]u8{ 'T', 'a', 'b', 'l', 'e', 'N', 'a', 'm', 'e', ' ', 'e', 'q', ' ', '\'', 'O', 'r', 'i', 'g', 'i', 'n', 'a', 'l', '\'' };
    var request_id = [_]u8{ 'o', 'r', 'i', 'g', '-', 'i', 'd' };
    var metadata = [_]u8{ 'a', 'p', 'p', 'l', 'i', 'c', 'a', 't', 'i', 'o', 'n', '/', 'j', 's', 'o', 'n', ';', 'o', 'd', 'a', 't', 'a', '=', 'c', 'u', 's', 't', 'o', 'm' };
    var applied = OptionPolicy{ .expected_request_id = "orig-id" };
    var replacement = OptionPolicy{ .expected_request_id = "orig-id" };
    var policy_ptrs = [_]*core.pipeline.HttpPolicy{&applied.policy};
    var table_pager = try TablePager.init(allocator, &protocol, .{
        .select = &select,
        .filter = &filter,
        .protocol = .{
            .metadata = .{ .unrecognized = &metadata },
            .client_request_id = &request_id,
            .policies = &policy_ptrs,
        },
    });
    defer table_pager.deinit();

    @memset(&select, 'x');
    @memset(&filter, 'x');
    @memset(&request_id, 'x');
    @memset(&metadata, 'x');
    policy_ptrs[0] = &replacement.policy;

    try std.testing.expect((try table_pager.next()) != null);
    try std.testing.expect((try table_pager.next()) != null);
    try std.testing.expectEqual(@as(usize, 2), applied.calls);
    try std.testing.expectEqual(@as(usize, 0), replacement.calls);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables?$format=application%2Fjson%3Bodata%3Dcustom&$select=TableName&$filter=TableName%20eq%20%27Original%27",
        transport.captured_urls[0][0..transport.captured_url_lengths[0]],
    );
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables?$format=application%2Fjson%3Bodata%3Dcustom&$select=TableName&$filter=TableName%20eq%20%27Original%27&NextTableName=Second",
        transport.captured_urls[1][0..transport.captured_url_lengths[1]],
    );
}

fn testPagerAllocationFailures(allocator: std.mem.Allocator) !void {
    var transport = core.http.MockTransport.init(
        allocator,
        200,
        "{\"value\":[{\"TableName\":\"Allocated\"}]}",
    );
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "x-ms-continuation-NextTableName", .value = "Continuation" },
    };
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var protocol = try protocol_client.ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net",
        base_pipeline,
        .{},
    );
    defer protocol.deinit();
    var select = [_]u8{ 'T', 'a', 'b', 'l', 'e', 'N', 'a', 'm', 'e' };
    var filter = [_]u8{ 'T', 'a', 'b', 'l', 'e', 'N', 'a', 'm', 'e' };
    var request_id = [_]u8{ 'a', 'l', 'l', 'o', 'c' };
    var metadata = [_]u8{ 'c', 'u', 's', 't', 'o', 'm' };
    var option_policy = OptionPolicy{ .expected_request_id = "alloc" };
    var policy_ptrs = [_]*core.pipeline.HttpPolicy{&option_policy.policy};
    var table_pager = try TablePager.init(allocator, &protocol, .{
        .select = &select,
        .filter = &filter,
        .continuation_token = "Initial",
        .protocol = .{
            .metadata = .{ .unrecognized = &metadata },
            .client_request_id = &request_id,
            .policies = &policy_ptrs,
        },
    });
    defer table_pager.deinit();
    try std.testing.expect((try table_pager.next()) != null);
}

test "table pager allocation failures release an unfetched page" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testPagerAllocationFailures,
        .{},
    );
}
