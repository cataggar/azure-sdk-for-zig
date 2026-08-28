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
fn encodeODataStringLiteral(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var escaped: std.ArrayList(u8) = .empty;
    defer escaped.deinit(allocator);
    for (value) |byte| {
        try escaped.append(allocator, byte);
        if (byte == '\'') try escaped.append(allocator, '\'');
    }
    return core.url.encodePathSegment(allocator, escaped.items);
}
const default_api_version = "2019-02-02";

pub const TablesClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const InitOptions = struct {
        endpoint: []const u8,
        api_version: []const u8 = default_api_version,
    };

    pub fn init(
        pipeline: core.http.HttpPipeline,
        options: InitOptions,
    ) TablesClient {
        return .{
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    pub fn table(self: *@This()) Table {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn service(self: *@This()) Service {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

pub const Table = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const QueryResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                next_table_name: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                content_type: []const u8,
            },
            body: models.TableQueryResponse,
        },
    };

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                preference_applied: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                content_type: []const u8,
            },
            body: models.TableResponse,
        },
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                preference_applied: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
            },
            body: void,
        },
    };

    pub const DeleteResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
            },
            body: void,
        },
    };

    pub const QueryEntitiesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                next_partition_key: ?[]const u8 = null,
                next_row_key: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                content_type: []const u8,
            },
            body: models.TableEntityQueryResponse,
        },
    };

    pub const QueryEntityWithPartitionAndRowKeyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                next_partition_key: ?[]const u8 = null,
                next_row_key: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                content_type: []const u8,
            },
            body: std.json.ArrayHashMap(models.JsonValue),
        },
    };

    pub const UpdateEntityResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                e_tag: []const u8,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
            },
            body: void,
        },
    };

    pub const MergeEntityResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                e_tag: []const u8,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
            },
            body: void,
        },
    };

    pub const DeleteEntityResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
            },
            body: void,
        },
    };

    pub const InsertEntityResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                preference_applied: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                e_tag: []const u8,
                content_type: []const u8,
            },
            body: std.json.ArrayHashMap(models.JsonValue),
        },
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                preference_applied: ?[]const u8 = null,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                date: []const u8,
                e_tag: []const u8,
            },
            body: void,
        },
    };

    pub const GetAccessPolicyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.SignedIdentifiers,
        },
    };

    pub const SetAccessPolicyResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                date: []const u8,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };
    /// Queries tables under the given account.
    pub fn query(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, @"$format": ?enums.OdataMetadataFormat, @"$top": ?i32, @"$select": ?[]const u8, @"$filter": ?[]const u8, next_table_name: ?[]const u8) !QueryResult {
        @setEvalBranchQuota(100_000);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/Tables", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$select") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$select={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$filter") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$filter={s}", .{ sep, enc });
            has_query = true;
        }
        if (next_table_name) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}NextTableName={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/json;odata=minimalmetadata");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-continuation-NextTableName")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_body = try serde.json.fromSlice(models.TableQueryResponse, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .next_table_name = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                        .content_type = response_header_5,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Table.query", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Creates a new table under the given account.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, @"$format": ?enums.OdataMetadataFormat, table_properties: models.TableProperties, prefer: ?enums.ResponseFormat) !CreateResult {
        @setEvalBranchQuota(100_000);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/Tables", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (prefer) |value| try req.setHeader("Prefer", value.toWire());
        try req.setHeader("Accept", "application/json;odata=minimalmetadata");
        const body_json = try serde.json.toSlice(alloc, table_properties);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("Preference-Applied")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_body = try serde.json.fromSlice(models.TableResponse, alloc, resp.body);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .preference_applied = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                        .content_type = response_header_5,
                    },
                    .body = response_body,
                } };
            },
            204 => {
                const response_header_0 = if (resp.getHeader("Preference-Applied")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .preference_applied = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes an existing table.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8) !DeleteResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try encodeODataStringLiteral(alloc, table);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/Tables('{s}')", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        const url = base_url;
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .api_version = response_header_0,
                        .request_id = response_header_1,
                        .client_request_id = response_header_2,
                        .date = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.delete", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Queries entities under the given table.
    pub fn queryEntities(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, @"$format": ?enums.OdataMetadataFormat, @"$top": ?i32, @"$select": ?[]const u8, @"$filter": ?[]const u8, timeout: ?i32, next_partition_key: ?[]const u8, next_row_key: ?[]const u8) !QueryEntitiesResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}()", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$top") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}$top={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$select") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$select={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$filter") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$filter={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        if (next_partition_key) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}NextPartitionKey={s}", .{ sep, enc });
            has_query = true;
        }
        if (next_row_key) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}NextRowKey={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/json;odata=minimalmetadata");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-continuation-NextPartitionKey")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = if (resp.getHeader("x-ms-continuation-NextRowKey")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_body = try serde.json.fromSlice(models.TableEntityQueryResponse, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .next_partition_key = response_header_0,
                        .next_row_key = response_header_1,
                        .api_version = response_header_2,
                        .request_id = response_header_3,
                        .client_request_id = response_header_4,
                        .date = response_header_5,
                        .content_type = response_header_6,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Table.queryEntities", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieve a single entity.
    pub fn queryEntityWithPartitionAndRowKey(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, timeout: ?i32, @"$format": ?enums.OdataMetadataFormat, @"$select": ?[]const u8, @"$filter": ?[]const u8, partition_key: []const u8, row_key: []const u8) !QueryEntityWithPartitionAndRowKeyResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try encodeODataStringLiteral(alloc, partition_key);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try encodeODataStringLiteral(alloc, row_key);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}(PartitionKey='{s}',RowKey='{s}')", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$select") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$select={s}", .{ sep, enc });
            has_query = true;
        }
        if (@"$filter") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$filter={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/json;odata=minimalmetadata");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-continuation-NextPartitionKey")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-continuation-NextRowKey")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_body = try serde.json.fromSlice(std.json.ArrayHashMap(models.JsonValue), alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .next_partition_key = response_header_1,
                        .next_row_key = response_header_2,
                        .api_version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                        .date = response_header_6,
                        .content_type = response_header_7,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Table.queryEntityWithPartitionAndRowKey", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Update entity in a table.
    pub fn updateEntity(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, timeout: ?i32, if_match: ?[]const u8, partition_key: []const u8, row_key: []const u8, table_entity_properties: ?std.json.ArrayHashMap(models.JsonValue)) !UpdateEntityResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try encodeODataStringLiteral(alloc, partition_key);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try encodeODataStringLiteral(alloc, row_key);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}(PartitionKey='{s}',RowKey='{s}')", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        if (if_match) |value| try req.setHeader("If-Match", value);
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (table_entity_properties) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.updateEntity", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Merge entity in a table.
    pub fn mergeEntity(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, timeout: ?i32, if_match: ?[]const u8, partition_key: []const u8, row_key: []const u8, table_entity_properties: ?std.json.ArrayHashMap(models.JsonValue)) !MergeEntityResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try encodeODataStringLiteral(alloc, partition_key);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try encodeODataStringLiteral(alloc, row_key);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}(PartitionKey='{s}',RowKey='{s}')", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        if (if_match) |value| try req.setHeader("If-Match", value);
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (table_entity_properties) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.mergeEntity", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes the specified entity in a table.
    pub fn deleteEntity(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, timeout: ?i32, if_match: []const u8, partition_key: []const u8, row_key: []const u8) !DeleteEntityResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const encoded_path_1 = try encodeODataStringLiteral(alloc, partition_key);
        defer alloc.free(encoded_path_1);
        const encoded_path_2 = try encodeODataStringLiteral(alloc, row_key);
        defer alloc.free(encoded_path_2);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}(PartitionKey='{s}',RowKey='{s}')", .{ self.endpoint, encoded_path_0, encoded_path_1, encoded_path_2 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("If-Match", if_match);
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .api_version = response_header_0,
                        .request_id = response_header_1,
                        .client_request_id = response_header_2,
                        .date = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.deleteEntity", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Insert entity in a table.
    pub fn insertEntity(self: *@This(), alloc: std.mem.Allocator, table: []const u8, timeout: ?i32, @"$format": ?enums.OdataMetadataFormat, client_request_id: ?[]const u8, prefer: ?enums.ResponseFormat, table_entity_properties: ?std.json.ArrayHashMap(models.JsonValue)) !InsertEntityResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        if (@"$format") |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, query_value.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}$format={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("DataServiceVersion", "3.0");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (prefer) |value| try req.setHeader("Prefer", value.toWire());
        try req.setHeader("Accept", "application/json;odata=minimalmetadata");
        var body_json: ?[]u8 = null;
        defer if (body_json) |bytes| alloc.free(bytes);
        if (table_entity_properties) |body| {
            const bytes = try serde.json.toSlice(alloc, body);
            body_json = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("Preference-Applied")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_body = try serde.json.fromSlice(std.json.ArrayHashMap(models.JsonValue), alloc, resp.body);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .preference_applied = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                        .e_tag = response_header_5,
                        .content_type = response_header_6,
                    },
                    .body = response_body,
                } };
            },
            204 => {
                const response_header_0 = if (resp.getHeader("Preference-Applied")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .preference_applied = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .date = response_header_4,
                        .e_tag = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.insertEntity", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieves details about any stored access policies specified on the table that
    /// may be used with Shared Access Signatures.
    pub fn getAccessPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, timeout: ?i32) !GetAccessPolicyResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}?comp=acl", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_body = try serde.xml.fromSlice(models.SignedIdentifiers, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .content_type = response_header_4,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Table.getAccessPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets stored access policies for the table that may be used with Shared Access
    /// Signatures.
    pub fn setAccessPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, table: []const u8, table_acl: models.SignedIdentifiers, timeout: ?i32) !SetAccessPolicyResult {
        @setEvalBranchQuota(100_000);
        const encoded_path_0 = try core.url.encodePathSegment(alloc, table);
        defer alloc.free(encoded_path_0);
        const base_url = try std.fmt.allocPrint(alloc, "{s}/{s}?comp=acl", .{ self.endpoint, encoded_path_0 });
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/xml");
        try req.setHeader("Accept", "application/xml");
        const body_xml = try serde.xml.toSlice(alloc, table_acl);
        defer alloc.free(body_xml);
        req.body = body_xml;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            204 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                return .{ .status_204 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Table.setAccessPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Service = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const SetPropertiesResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetPropertiesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.TableServiceProperties,
        },
    };

    pub const GetStatisticsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                api_version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.TableServiceStats,
        },
    };
    /// Sets properties for an account's Table service endpoint, including properties
    /// for Analytics and CORS (Cross-Origin Resource Sharing) rules.
    pub fn setProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, table_service_properties: models.TableServiceProperties) !SetPropertiesResult {
        @setEvalBranchQuota(100_000);
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/xml");
        try req.setHeader("Accept", "application/xml");
        const body_xml = try serde.xml.toSlice(alloc, table_service_properties);
        defer alloc.free(body_xml);
        req.body = body_xml;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .api_version = response_header_0,
                        .request_id = response_header_1,
                        .client_request_id = response_header_2,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Service.setProperties", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Gets the properties of an account's Table service, including properties for
    /// Analytics and CORS (Cross-Origin Resource Sharing) rules.
    pub fn getProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetPropertiesResult {
        @setEvalBranchQuota(100_000);
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_body = try serde.xml.fromSlice(models.TableServiceProperties, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .api_version = response_header_0,
                        .request_id = response_header_1,
                        .client_request_id = response_header_2,
                        .content_type = response_header_3,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Service.getProperties", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieves statistics related to replication for the Table service. It is only
    /// available on the secondary location endpoint when read-access geo-redundant
    /// replication is enabled for the account.
    pub fn getStatistics(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetStatisticsResult {
        @setEvalBranchQuota(100_000);
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=stats", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |query_value| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, query_value });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_body = try serde.xml.fromSlice(models.TableServiceStats, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .api_version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .content_type = response_header_4,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Service.getStatistics", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};
