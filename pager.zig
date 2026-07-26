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
        return .{
            .allocator = allocator,
            .protocol = owned_protocol,
            .options = list_options,
            .continuation_token = if (list_options.continuation_token) |token|
                try allocator.dupe(u8, token)
            else
                null,
        };
    }

    pub fn deinit(self: *TablePager) void {
        if (self.current) |*page| page.deinit();
        if (self.continuation_token) |token| self.allocator.free(token);
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
    var table_pager = try TablePager.init(allocator, &protocol, .{});
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
