//! Header-continuation table and entity pagers.
//!
//! A page owns its values until the next page is requested or the pager is
//! deinitialized, whichever occurs first.

const std = @import("std");
const core = @import("azure_sdk_core");
const entity = @import("entity.zig");
const entity_codec = @import("entity_codec.zig");
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
        switch (metadata) {
            .unrecognized => |value| {
                const owned_value = try allocator.dupe(u8, value);
                result.protocol.metadata = .{ .unrecognized = owned_value };
            },
            else => result.protocol.metadata = metadata,
        }
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

/// A decoded query page. Its values and metadata are valid until the next
/// successful `EntityPager.nextPage` call or the pager is deinitialized.
pub fn EntityPage(comptime T: type) type {
    return struct {
        values: []T,
        status: u16,
        headers: responses.EntityHeaders,
        /// `odata.metadata` supplied by full or minimal metadata responses.
        metadata: ?[]const u8,
        raw_headers: responses.RawHeaders,
        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.allocator.destroy(self.arena);
            self.* = undefined;
        }
    };
}

/// Header-continuation pager for a table's entities.
///
/// The pager copies table name, protocol settings, all option strings, and
/// policy-pointer storage. Policy objects themselves remain borrowed and must
/// stay at heap-stable addresses for the pager lifetime. The source client
/// may be moved after construction, but its shared pipeline owner must outlive
/// the pager.
pub fn EntityPager(comptime T: type) type {
    if (T != entity.DynamicEntity) _ = entity_codec.EntityCodec(T);

    return struct {
        const Self = @This();
        const Page = EntityPage(T);

        allocator: std.mem.Allocator,
        protocol: protocol_client.ProtocolClient,
        table_name: []u8,
        options: options.QueryEntitiesOptions,
        next_partition_key: ?[]u8,
        next_row_key: ?[]u8,
        current: ?Page = null,
        done: bool = false,

        pub fn init(
            allocator: std.mem.Allocator,
            protocol: *protocol_client.ProtocolClient,
            table_name: []const u8,
            query_options: options.QueryEntitiesOptions,
        ) !Self {
            if (query_options.top) |top| if (top <= 0) return error.InvalidTop;

            var owned_protocol = try protocol.clone(allocator);
            errdefer owned_protocol.deinit();
            const owned_table_name = try allocator.dupe(u8, table_name);
            errdefer allocator.free(owned_table_name);
            var owned_options = try copyQueryEntitiesOptions(allocator, query_options);
            errdefer deinitQueryEntitiesOptions(allocator, &owned_options);
            const next_partition_key = if (query_options.next_partition_key) |value|
                try allocator.dupe(u8, value)
            else
                null;
            errdefer if (next_partition_key) |value| allocator.free(value);
            const next_row_key = if (query_options.next_row_key) |value|
                try allocator.dupe(u8, value)
            else
                null;
            errdefer if (next_row_key) |value| allocator.free(value);

            return .{
                .allocator = allocator,
                .protocol = owned_protocol,
                .table_name = owned_table_name,
                .options = owned_options,
                .next_partition_key = next_partition_key,
                .next_row_key = next_row_key,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.current) |*page| page.deinit();
            self.freeContinuation();
            deinitQueryEntitiesOptions(self.allocator, &self.options);
            self.allocator.free(self.table_name);
            self.protocol.deinit();
            self.* = undefined;
        }

        /// Returns a page borrowed from this pager, or `null` after the final
        /// continuation. Failed calls preserve both continuation values so a
        /// subsequent call can safely retry the same page.
        pub fn nextPage(self: *Self) !responses.TableResult(?*const Page) {
            if (self.done) return .{ .success = null };

            var query = self.options;
            query.next_partition_key = self.next_partition_key;
            query.next_row_key = self.next_row_key;
            const result = try self.protocol.queryEntitiesResult(
                self.allocator,
                self.table_name,
                query,
            );
            switch (result) {
                .failure => |failure| return .{ .failure = failure },
                .success => |fetched_page| {
                    var raw: ?responses.SdkResponse(protocol_client.QueryEntitiesResponse) = fetched_page;
                    errdefer if (raw) |*value| value.deinit();
                    var page = try decodeEntityPage(T, &raw.?);
                    raw = null;
                    errdefer page.deinit();

                    const continuation = try entityContinuation(
                        self.allocator,
                        &page.raw_headers,
                    );
                    errdefer continuation.deinit(self.allocator);

                    if (self.current) |*old_page| old_page.deinit();
                    self.current = page;
                    self.freeContinuation();
                    self.next_partition_key = continuation.partition;
                    self.next_row_key = continuation.row;
                    self.done = self.next_partition_key == null and self.next_row_key == null;
                    return .{ .success = &self.current.? };
                },
            }
        }

        pub fn next(self: *Self) !?*const Page {
            return responses.unwrapQueryEntities(
                ?*const Page,
                try self.nextPage(),
            );
        }

        fn freeContinuation(self: *Self) void {
            if (self.next_partition_key) |value| self.allocator.free(value);
            if (self.next_row_key) |value| self.allocator.free(value);
            self.next_partition_key = null;
            self.next_row_key = null;
        }
    };
}

const EntityContinuation = struct {
    partition: ?[]u8 = null,
    row: ?[]u8 = null,

    fn deinit(self: *const EntityContinuation, allocator: std.mem.Allocator) void {
        if (self.partition) |value| allocator.free(value);
        if (self.row) |value| allocator.free(value);
    }
};

fn entityContinuation(
    allocator: std.mem.Allocator,
    headers: *const responses.RawHeaders,
) !EntityContinuation {
    const partition = if (headers.getFirst("x-ms-continuation-NextPartitionKey")) |value|
        try allocator.dupe(u8, value)
    else
        null;
    errdefer if (partition) |value| allocator.free(value);
    const row = if (headers.getFirst("x-ms-continuation-NextRowKey")) |value|
        try allocator.dupe(u8, value)
    else
        null;
    return .{ .partition = partition, .row = row };
}

fn decodeEntityPage(
    comptime T: type,
    raw: *responses.SdkResponse(protocol_client.QueryEntitiesResponse),
) !EntityPage(T) {
    const page_allocator = raw.arena.allocator();
    const response = switch (raw.value) {
        .status_200 => |value| value,
    };
    const body = raw.body orelse return error.MissingRawResponseBody;
    var parsed = try std.json.parseFromSlice(std.json.Value, page_allocator, body, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();
    const object = switch (parsed.value) {
        .object => |value| value,
        else => return error.ExpectedObject,
    };
    const source_values: []const std.json.Value = if (object.get("value")) |value| switch (value) {
        .array => |items| items.items,
        else => return error.InvalidPropertyType,
    } else &.{};
    const values = try page_allocator.alloc(T, source_values.len);
    for (source_values, 0..) |source, index| {
        const json = try std.json.Stringify.valueAlloc(page_allocator, source, .{});
        values[index] = if (T == entity.DynamicEntity)
            try entity_codec.dynamicFromJson(page_allocator, json)
        else
            try entity_codec.EntityCodec(T).deserialize(page_allocator, json);
    }
    return .{
        .values = values,
        .status = raw.status,
        .headers = entityHeaders(&raw.headers),
        .metadata = response.body.odata_metadata,
        .raw_headers = raw.headers,
        .arena = raw.arena,
        .allocator = raw.allocator,
    };
}

fn entityHeaders(headers: *const responses.RawHeaders) responses.EntityHeaders {
    return .{
        .request_id = headers.getFirst("x-ms-request-id"),
        .client_request_id = headers.getFirst("x-ms-client-request-id"),
        .date = headers.getFirst("Date"),
        .api_version = headers.getFirst("x-ms-version"),
        .content_type = headers.getFirst("Content-Type"),
        .preference_applied = headers.getFirst("Preference-Applied"),
    };
}

fn copyQueryEntitiesOptions(
    allocator: std.mem.Allocator,
    source: options.QueryEntitiesOptions,
) !options.QueryEntitiesOptions {
    var result: options.QueryEntitiesOptions = .{
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
        .next_partition_key = null,
        .next_row_key = null,
    };
    errdefer deinitQueryEntitiesOptions(allocator, &result);

    if (source.select) |value| result.select = try allocator.dupe(u8, value);
    if (source.filter) |value| result.filter = try allocator.dupe(u8, value);
    if (source.protocol.client_request_id) |value|
        result.protocol.client_request_id = try allocator.dupe(u8, value);
    if (source.protocol.metadata) |metadata| switch (metadata) {
        .unrecognized => |value| {
            const owned_value = try allocator.dupe(u8, value);
            result.protocol.metadata = .{ .unrecognized = owned_value };
        },
        else => result.protocol.metadata = metadata,
    };
    if (source.protocol.policies.len > 0)
        result.protocol.policies = try allocator.dupe(
            *core.pipeline.HttpPolicy,
            source.protocol.policies,
        );
    return result;
}

fn deinitQueryEntitiesOptions(
    allocator: std.mem.Allocator,
    query_options: *options.QueryEntitiesOptions,
) void {
    if (query_options.select) |value| allocator.free(value);
    if (query_options.filter) |value| allocator.free(value);
    if (query_options.protocol.client_request_id) |value| allocator.free(value);
    if (query_options.protocol.metadata) |metadata| switch (metadata) {
        .unrecognized => |value| allocator.free(value),
        else => {},
    };
    if (query_options.protocol.policies.len > 0)
        allocator.free(query_options.protocol.policies);
    query_options.* = undefined;
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

test "entity pager preserves all continuation combinations and decodes typed pages" {
    const TypedEntity = struct {
        partition_key: []const u8,
        row_key: []const u8,
        name: []const u8,
    };
    const allocator = std.testing.allocator;
    const page_headers = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"odata.metadata\":\"first\",\"value\":[{\"PartitionKey\":\"p1\",\"RowKey\":\"1\",\"name\":\"first\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextPartitionKey", .value = "P /雪?&%" },
                .{ .name = "x-ms-continuation-NextRowKey", .value = "R /雪?&%" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p2\",\"RowKey\":\"2\",\"name\":\"second\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextPartitionKey", .value = "partition only" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p3\",\"RowKey\":\"3\",\"name\":\"third\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextRowKey", .value = "row only" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p4\",\"RowKey\":\"4\",\"name\":\"fourth\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
            },
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &page_headers);
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

    var entity_pager = try EntityPager(TypedEntity).init(allocator, &protocol, "Table123", .{
        .top = 1,
        .select = "PartitionKey,RowKey,name",
        .filter = "name ne 'skip'",
        .next_partition_key = "Initial P /雪?&%",
        .next_row_key = "Initial R /雪?&%",
        .protocol = .{
            .metadata = .full_metadata,
            .client_request_id = "entity-pager",
            .timeout = 30,
        },
    });
    defer entity_pager.deinit();

    const expected = [_][]const u8{ "first", "second", "third", "fourth" };
    for (expected) |name| {
        const page = (try entity_pager.next()).?;
        try std.testing.expectEqual(@as(usize, 1), page.values.len);
        try std.testing.expectEqualStrings(name, page.values[0].name);
    }
    try std.testing.expect((try entity_pager.next()) == null);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Table123()?$format=application%2Fjson%3Bodata%3Dfullmetadata&$top=1&$select=PartitionKey%2CRowKey%2Cname&$filter=name%20ne%20%27skip%27&timeout=30&NextPartitionKey=Initial%20P%20%2F%E9%9B%AA%3F%26%25&NextRowKey=Initial%20R%20%2F%E9%9B%AA%3F%26%25",
        transport.captured_urls[0][0..transport.captured_url_lengths[0]],
    );
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[1][0..transport.captured_url_lengths[1]],
        "NextPartitionKey=P%20%2F%E9%9B%AA%3F%26%25&NextRowKey=R%20%2F%E9%9B%AA%3F%26%25",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[2][0..transport.captured_url_lengths[2]],
        "NextPartitionKey=partition%20only",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[2][0..transport.captured_url_lengths[2]],
        "NextRowKey=",
    ) == null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[3][0..transport.captured_url_lengths[3]],
        "NextRowKey=row%20only",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[3][0..transport.captured_url_lengths[3]],
        "NextPartitionKey=",
    ) == null);
}

test "entity pager owns mutable options and decodes dynamic EDM values" {
    const allocator = std.testing.allocator;
    const pages = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body =
            \\{"value":[{"PartitionKey":"p","RowKey":"1","Count":"9223372036854775807","Count@odata.type":"Edm.Int64"}]}
            ,
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextPartitionKey", .value = "next /%?" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p\",\"RowKey\":\"2\",\"Name\":\"second\"}]}",
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

    var select = [_]u8{ 'P', 'a', 'r', 't', 'i', 't', 'i', 'o', 'n', 'K', 'e', 'y' };
    var filter = [_]u8{ 'N', 'a', 'm', 'e', ' ', 'e', 'q', ' ', '\'', 'o', 'r', 'i', 'g', '\'' };
    var request_id = [_]u8{ 'o', 'r', 'i', 'g', '-', 'i', 'd' };
    var metadata = [_]u8{ 'a', 'p', 'p', '/', 'j', 's', 'o', 'n' };
    var initial_partition = [_]u8{ 'i', 'n', 'i', 't', ' ', '/', '%', '?' };
    var applied = OptionPolicy{ .expected_request_id = "orig-id" };
    var replacement = OptionPolicy{ .expected_request_id = "orig-id" };
    var policy_ptrs = [_]*core.pipeline.HttpPolicy{&applied.policy};
    var entity_pager = try EntityPager(entity.DynamicEntity).init(allocator, &protocol, "Table123", .{
        .select = &select,
        .filter = &filter,
        .next_partition_key = &initial_partition,
        .protocol = .{
            .metadata = .{ .unrecognized = &metadata },
            .client_request_id = &request_id,
            .policies = &policy_ptrs,
        },
    });
    defer entity_pager.deinit();

    @memset(&select, 'x');
    @memset(&filter, 'x');
    @memset(&request_id, 'x');
    @memset(&metadata, 'x');
    @memset(&initial_partition, 'x');
    policy_ptrs[0] = &replacement.policy;

    const first = (try entity_pager.next()).?;
    try std.testing.expectEqual(@as(i64, 9_223_372_036_854_775_807), first.values[0].properties.get("Count").?.int64.value);
    const second = (try entity_pager.next()).?;
    try std.testing.expectEqualStrings("second", second.values[0].properties.get("Name").?.string);
    try std.testing.expectEqual(@as(usize, 2), applied.calls);
    try std.testing.expectEqual(@as(usize, 0), replacement.calls);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[0][0..transport.captured_url_lengths[0]],
        "$select=PartitionKey&$filter=Name%20eq%20%27orig%27&NextPartitionKey=init%20%2F%25%3F",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[1][0..transport.captured_url_lengths[1]],
        "NextPartitionKey=next%20%2F%25%3F",
    ) != null);
}

test "entity pager preserves continuation after a structured service failure" {
    const TypedEntity = struct {
        partition_key: []const u8,
        row_key: []const u8,
        name: []const u8,
    };
    const allocator = std.testing.allocator;
    const pages = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p\",\"RowKey\":\"1\",\"name\":\"first\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextPartitionKey", .value = "retry /%?" },
            },
        },
        .{
            .status = 500,
            .body = "{\"code\":\"InternalError\",\"message\":\"retry\"}",
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-request-id", .value = "failed-page" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"PartitionKey\":\"p\",\"RowKey\":\"2\",\"name\":\"second\"}]}",
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
    var entity_pager = try EntityPager(TypedEntity).init(
        allocator,
        &protocol,
        "Table123",
        .{},
    );
    defer entity_pager.deinit();

    const first = (try entity_pager.nextPage()).success.?;
    try std.testing.expectEqualStrings("first", first.values[0].name);
    var failure = try entity_pager.nextPage();
    defer failure.deinit(allocator);
    switch (failure) {
        .failure => |table_error| {
            try std.testing.expectEqual(@as(u16, 500), table_error.status);
            try std.testing.expectEqualStrings("InternalError", table_error.code);
        },
        .success => return error.TestExpectedStructuredFailure,
    }
    const retried = (try entity_pager.nextPage()).success.?;
    try std.testing.expectEqualStrings("second", retried.values[0].name);
    try std.testing.expectEqualStrings(
        transport.captured_urls[1][0..transport.captured_url_lengths[1]],
        transport.captured_urls[2][0..transport.captured_url_lengths[2]],
    );
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.captured_urls[2][0..transport.captured_url_lengths[2]],
        "NextPartitionKey=retry%20%2F%25%3F",
    ) != null);
}

fn testEntityPagerAllocationFailures(allocator: std.mem.Allocator) !void {
    const TypedEntity = struct {
        partition_key: []const u8,
        row_key: []const u8,
        name: []const u8,
    };
    var transport = core.http.MockTransport.init(allocator, 200,
        \\{"value":[{"PartitionKey":"p","RowKey":"r","name":"allocated"}]}
    );
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "x-ms-continuation-NextPartitionKey", .value = "next" },
        .{ .name = "x-ms-continuation-NextRowKey", .value = "row" },
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
    var entity_pager = try EntityPager(TypedEntity).init(
        allocator,
        &protocol,
        "Table123",
        .{
            .select = "PartitionKey,RowKey,name",
            .filter = "name ne 'bad'",
            .next_partition_key = "initial",
            .next_row_key = "row",
            .protocol = .{
                .metadata = .full_metadata,
                .client_request_id = "allocation-test",
            },
        },
    );
    defer entity_pager.deinit();
    try std.testing.expect((try entity_pager.next()) != null);
}

test "entity pager releases staged allocations" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testEntityPagerAllocationFailures,
        .{},
    );
}
