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
const default_api_version = "2026-06-06";
pub const BlobClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const InitOptions = struct {
        endpoint: []const u8,
        api_version: []const u8 = default_api_version,
    };

    /// The pipeline and its runtime descriptors are copied by value. Their
    /// borrowed transport, crypto, policy, and credential contexts must
    /// outlive this client and every client derived from it.
    pub fn init(
        pipeline: core.http.HttpPipeline,
        options: InitOptions,
    ) BlobClient {
        return .{
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    pub fn service(self: *@This()) Service {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn container(self: *@This()) Container {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn blob(self: *@This()) Blob {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn appendBlob(self: *@This()) AppendBlob {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn blockBlob(self: *@This()) BlockBlob {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }

    pub fn pageBlob(self: *@This()) PageBlob {
        return .{
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
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
                date: []const u8,
                version: []const u8,
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
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.BlobServiceProperties,
        },
    };

    pub const GetStatisticsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.StorageServiceStats,
        },
    };

    pub const ListContainersResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.ListContainersResponse,
        },
    };

    pub const GetUserDelegationKeyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.UserDelegationKey,
        },
    };

    pub const GetAccountInfoResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                sku_name: ?enums.SkuName = null,
                account_kind: ?enums.AccountKind = null,
                is_hierarchical_namespace_enabled: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SubmitBatchResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const FindBlobsByTagsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.FilteredBlobResponse,
        },
    };
    /// Sets properties for a storage account's Blob service endpoint, including properties for Storage Analytics and CORS (Cross-Origin Resource Sharing) rules.
    pub fn setProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, storage_service_properties: models.BlobServiceProperties) !SetPropertiesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/xml");
        const body_xml = try serde.xml.toSlice(alloc, storage_service_properties);
        defer alloc.free(body_xml);
        req.body = body_xml;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
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
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
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
    /// Retrieves properties of a storage account's Blob service, including properties for Storage Analytics and CORS (Cross-Origin Resource Sharing) rules.
    pub fn getProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetPropertiesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
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
                const response_body = try serde.xml.fromSlice(models.BlobServiceProperties, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .content_type = response_header_4,
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
    /// Retrieves statistics related to replication for the Blob service. It is only available on the secondary location endpoint when read-access geo-redundant replication is enabled for the storage account.
    pub fn getStatistics(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetStatisticsResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=stats", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
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
                const response_body = try serde.xml.fromSlice(models.StorageServiceStats, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
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
    /// Returns a list of the containers in the specified account.
    pub fn listContainers(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, prefix: ?[]const u8, marker: ?[]const u8, maxresults: ?i32, timeout: ?i32, include: ?[]const enums.ListContainersIncludeType) !core.pager.XmlPager(models.ListContainersResponse) {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=list", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (prefix) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}prefix={s}", .{ sep, enc });
            has_query = true;
        }
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (include) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item.toWire());
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}include={s}", .{ sep, enc });
                has_query = true;
            }
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.XmlPager(models.ListContainersResponse).init(
            self.pipeline,
            url,
            self.api_version,
            marker,
            client_request_id,
            alloc,
        );
    }
    /// Retrieves a user delegation key for the Blob service. This is only a valid operation when using bearer token authentication.
    pub fn getUserDelegationKey(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, key_info: models.KeyInfo, timeout: ?i32) !GetUserDelegationKeyResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=service&comp=userdelegationkey", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/xml");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Accept", "application/xml");
        const body_xml = try serde.xml.toSlice(alloc, key_info);
        defer alloc.free(body_xml);
        req.body = body_xml;

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
                const response_body = try serde.xml.fromSlice(models.UserDelegationKey, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .content_type = response_header_4,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Service.getUserDelegationKey", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns information about the storage account.
    pub fn getAccountInfo(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetAccountInfoResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=account&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0: ?enums.SkuName = if (resp.getHeader("x-ms-sku-name")) |value|
                    enums.SkuName.fromWire(value)
                else
                    null;
                const response_header_1: ?enums.AccountKind = if (resp.getHeader("x-ms-account-kind")) |value|
                    enums.AccountKind.fromWire(value)
                else
                    null;
                const response_header_2: ?bool = if (resp.getHeader("x-ms-is-hns-enabled")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .sku_name = response_header_0,
                        .account_kind = response_header_1,
                        .is_hierarchical_namespace_enabled = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Service.getAccountInfo", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Allows multiple API calls to be embedded into a single HTTP request.
    pub fn submitBatch(self: *@This(), alloc: std.mem.Allocator, timeout: ?i32, client_request_id: ?[]const u8, content_length: i64, body: models.SubmitBatchRequest) !SubmitBatchResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=batch", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        try req.setHeader("Accept", "multipart/mixed");
        const multipart_boundary = "azure-sdk-for-zig-acr-boundary";
        var multipart_body: std.ArrayList(u8) = .empty;
        defer multipart_body.deinit(alloc);
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"body\"\r\nContent-Type: application/octet-stream\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.body },
        );
        try multipart_body.print(alloc, "--{s}--\r\n", .{multipart_boundary});
        const multipart_bytes = try multipart_body.toOwnedSlice(alloc);
        defer alloc.free(multipart_bytes);
        req.body = multipart_bytes;
        try req.setHeader("Content-Type", "multipart/form-data; boundary=azure-sdk-for-zig-acr-boundary");

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
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .version = response_header_0,
                        .request_id = response_header_1,
                        .client_request_id = response_header_2,
                        .content_type = response_header_3,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Service.submitBatch", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Lists blobs across all containers whose tags match a given search expression.
    pub fn findBlobsByTags(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, filter_expression: []const u8, marker: ?[]const u8, maxresults: ?i32, include: ?[]const enums.FilterBlobsIncludeItem) !core.pager.XmlPager(models.FilteredBlobResponse) {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=blobs", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, filter_expression);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}where={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        if (include) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item.toWire());
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}include={s}", .{ sep, enc });
                has_query = true;
            }
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.XmlPager(models.FilteredBlobResponse).init(
            self.pipeline,
            url,
            self.api_version,
            marker,
            client_request_id,
            alloc,
        );
    }
};

pub const Container = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
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
                metadata: ?[]const u8 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                access: ?enums.PublicAccessType = null,
                has_immutability_policy: ?bool = null,
                has_legal_hold: ?bool = null,
                default_encryption_scope: ?[]const u8 = null,
                prevent_encryption_scope_override: ?bool = null,
                is_immutable_storage_with_versioning_enabled: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const DeleteResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetMetadataResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetAccessPolicyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                access: ?enums.PublicAccessType = null,
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.SignedIdentifiers,
        },
    };

    pub const SetAccessPolicyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const RestoreResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const RenameResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SubmitBatchResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                request_id: ?[]const u8 = null,
                version: []const u8,
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const FindBlobsByTagsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.FilteredBlobResponse,
        },
    };

    pub const AcquireLeaseResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                lease_id: ?[]const u8 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ReleaseLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const RenewLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                lease_id: ?[]const u8 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const BreakLeaseResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                lease_time: ?i32 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ChangeLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                lease_id: ?[]const u8 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ListBlobsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.ListBlobsResponse,
        },
    };

    pub const ListBlobHierarchySegmentResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.ListBlobsHierarchicalResponse,
        },
    };

    pub const GetAccountInfoResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                sku_name: ?enums.SkuName = null,
                account_kind: ?enums.AccountKind = null,
                is_hierarchical_namespace_enabled: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };
    /// Creates a new container in the specified account. If the container with the same name already exists, the operation fails.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, metadata: ?[]const u8, access: ?enums.PublicAccessType, default_encryption_scope: ?[]const u8, prevent_encryption_scope_override: ?bool) !CreateResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (access) |value| try req.setHeader("x-ms-blob-public-access", value.toWire());
        if (default_encryption_scope) |value| try req.setHeader("x-ms-default-encryption-scope", value);
        if (prevent_encryption_scope_override) |value| try req.setHeader("x-ms-deny-encryption-scope-override", if (value) "true" else "false");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns all user-defined metadata and system properties for the specified container. The data returned does not include the container's list of blobs.
    pub fn getProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8) !GetPropertiesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_4: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_5: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_6: ?enums.PublicAccessType = if (resp.getHeader("x-ms-blob-public-access")) |value|
                    try enums.PublicAccessType.fromWire(alloc, value)
                else
                    null;
                const response_header_7: ?bool = if (resp.getHeader("x-ms-has-immutability-policy")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_8: ?bool = if (resp.getHeader("x-ms-has-legal-hold")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_9 = if (resp.getHeader("x-ms-default-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10: ?bool = if (resp.getHeader("x-ms-deny-encryption-scope-override")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_11: ?bool = if (resp.getHeader("x-ms-immutable-storage-with-versioning-enabled")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_12 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_12);
                const response_header_13 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_13);
                const response_header_14 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_14) |value| alloc.free(value);
                const response_header_15 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_15) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .metadata = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .duration = response_header_3,
                        .lease_state = response_header_4,
                        .lease_status = response_header_5,
                        .access = response_header_6,
                        .has_immutability_policy = response_header_7,
                        .has_legal_hold = response_header_8,
                        .default_encryption_scope = response_header_9,
                        .prevent_encryption_scope_override = response_header_10,
                        .is_immutable_storage_with_versioning_enabled = response_header_11,
                        .date = response_header_12,
                        .version = response_header_13,
                        .request_id = response_header_14,
                        .client_request_id = response_header_15,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.getProperties", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes the specified container.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !DeleteResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
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
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.delete", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets user-defined metadata for the specified container.
    pub fn setMetadata(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, metadata: ?[]const u8, if_modified_since: ?[]const u8) !SetMetadataResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=metadata", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.setMetadata", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Gets the permissions for the specified container.
    pub fn getAccessPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8) !GetAccessPolicyResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=acl", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0: ?enums.PublicAccessType = if (resp.getHeader("x-ms-blob-public-access")) |value|
                    try enums.PublicAccessType.fromWire(alloc, value)
                else
                    null;
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_body = try serde.xml.fromSlice(models.SignedIdentifiers, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .access = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                        .content_type = response_header_7,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Container.getAccessPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets the permissions for the specified container.
    pub fn setAccessPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, container_acl: ?models.SignedIdentifiers, timeout: ?i32, lease_id: ?[]const u8, access: ?enums.PublicAccessType, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !SetAccessPolicyResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=acl", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (container_acl != null) try req.setHeader("Content-Type", "application/xml");
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (access) |value| try req.setHeader("x-ms-blob-public-access", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        var body_xml: ?[]u8 = null;
        defer if (body_xml) |bytes| alloc.free(bytes);
        if (container_acl) |body| {
            const bytes = try serde.xml.toSlice(alloc, body);
            body_xml = bytes;
            req.body = bytes;
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.setAccessPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Restores the specified previously-deleted container.
    pub fn restore(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, deleted_container_name: ?[]const u8, deleted_container_version: ?[]const u8, timeout: ?i32) !RestoreResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=undelete", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (deleted_container_name) |value| try req.setHeader("x-ms-deleted-container-name", value);
        if (deleted_container_version) |value| try req.setHeader("x-ms-deleted-container-version", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
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
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.restore", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Renames the specified existing container.
    pub fn rename(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, source_container_name: []const u8, source_lease_id: ?[]const u8, timeout: ?i32) !RenameResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=rename", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-source-container-name", source_container_name);
        if (source_lease_id) |value| try req.setHeader("x-ms-source-lease-id", value);

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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.rename", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Allows multiple API calls to be embedded into a single HTTP request.
    pub fn submitBatch(self: *@This(), alloc: std.mem.Allocator, timeout: ?i32, client_request_id: ?[]const u8, content_length: i64, body: models.SubmitBatchRequest) !SubmitBatchResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=batch", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        try req.setHeader("Accept", "multipart/mixed");
        const multipart_boundary = "azure-sdk-for-zig-acr-boundary";
        var multipart_body: std.ArrayList(u8) = .empty;
        defer multipart_body.deinit(alloc);
        try multipart_body.print(
            alloc,
            "--{s}\r\nContent-Disposition: form-data; name=\"body\"\r\nContent-Type: application/octet-stream\r\n\r\n{s}\r\n",
            .{ multipart_boundary, body.body },
        );
        try multipart_body.print(alloc, "--{s}--\r\n", .{multipart_boundary});
        const multipart_bytes = try multipart_body.toOwnedSlice(alloc);
        defer alloc.free(multipart_bytes);
        req.body = multipart_bytes;
        try req.setHeader("Content-Type", "multipart/form-data; boundary=azure-sdk-for-zig-acr-boundary");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .request_id = response_header_0,
                        .version = response_header_1,
                        .content_type = response_header_2,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Container.submitBatch", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Lists blobs in the specified container whose tags match a given search expression.
    pub fn findBlobsByTags(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, filter_expression: []const u8, marker: ?[]const u8, maxresults: ?i32, include: ?[]const enums.FilterBlobsIncludeItem) !core.pager.XmlPager(models.FilteredBlobResponse) {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=blobs", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, filter_expression);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}where={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        if (include) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item.toWire());
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}include={s}", .{ sep, enc });
                has_query = true;
            }
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.XmlPager(models.FilteredBlobResponse).init(
            self.pipeline,
            url,
            self.api_version,
            marker,
            client_request_id,
            alloc,
        );
    }
    /// Requests a new lease on the specified container.
    pub fn acquireLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, duration: i32, timeout: ?i32, proposed_lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !AcquireLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease&restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{duration});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-lease-duration", header_val);
        }
        if (proposed_lease_id) |value| try req.setHeader("x-ms-proposed-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        try req.setHeader("x-ms-lease-action", "acquire");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .lease_id = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.acquireLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Frees the lease if it's no longer needed, so that another client can immediately acquire a lease against the container.
    pub fn releaseLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, lease_id: []const u8, timeout: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !ReleaseLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease&restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        try req.setHeader("x-ms-lease-action", "release");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.releaseLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Renews an existing lease.
    pub fn renewLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, lease_id: []const u8, timeout: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !RenewLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease&restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        try req.setHeader("x-ms-lease-action", "renew");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .lease_id = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.renewLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Ends a lease and ensures that another client can't acquire a new lease until the current lease period has expired.
    pub fn breakLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, break_period: ?i32) !BreakLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease&restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (break_period) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-lease-break-period", header_val);
        }
        try req.setHeader("x-ms-lease-action", "break");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0: ?i32 = if (resp.getHeader("x-ms-lease-time")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .lease_time = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.breakLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Change the ID of an existing lease.
    pub fn changeLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, lease_id: []const u8, proposed_lease_id: []const u8, timeout: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8) !ChangeLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease&restype=container", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        try req.setHeader("x-ms-proposed-lease-id", proposed_lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        try req.setHeader("x-ms-lease-action", "change");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .lease_id = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.changeLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns a list of the blobs in the specified container.
    pub fn listBlobs(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, prefix: ?[]const u8, marker: ?[]const u8, maxresults: ?i32, include: ?[]const enums.ListBlobsIncludeItem, timeout: ?i32, start_from: ?[]const u8) !core.pager.XmlPager(models.ListBlobsResponse) {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=list", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (prefix) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}prefix={s}", .{ sep, enc });
            has_query = true;
        }
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        if (include) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item.toWire());
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}include={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (start_from) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}startFrom={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.XmlPager(models.ListBlobsResponse).init(
            self.pipeline,
            url,
            self.api_version,
            marker,
            client_request_id,
            alloc,
        );
    }
    /// Returns a list of the blobs in the specified container. A delimiter can be used to traverse a virtual hierarchy of blobs as though it were a file system.
    pub fn listBlobHierarchySegment(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, delimiter: []const u8, prefix: ?[]const u8, marker: ?[]const u8, maxresults: ?i32, include: ?[]const enums.ListBlobsIncludeItem, timeout: ?i32, start_from: ?[]const u8) !core.pager.XmlPager(models.ListBlobsHierarchicalResponse) {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=container&comp=list", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, delimiter);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}delimiter={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (prefix) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}prefix={s}", .{ sep, enc });
            has_query = true;
        }
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        if (include) |items| {
            var list_buf: std.ArrayList(u8) = .empty;
            defer list_buf.deinit(alloc);
            for (items, 0..) |item, i| {
                if (i != 0) try list_buf.append(alloc, ',');
                try list_buf.appendSlice(alloc, item.toWire());
            }
            if (items.len != 0) {
                const sep: []const u8 = if (has_query) "&" else "?";
                const enc = try core.url.percentEncode(alloc, list_buf.items);
                defer alloc.free(enc);
                try url_buf.print(alloc, "{s}include={s}", .{ sep, enc });
                has_query = true;
            }
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (start_from) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}startFrom={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.XmlPager(models.ListBlobsHierarchicalResponse).init(
            self.pipeline,
            url,
            self.api_version,
            marker,
            client_request_id,
            alloc,
        );
    }
    /// Returns information about the storage account.
    pub fn getAccountInfo(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetAccountInfoResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=account&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0: ?enums.SkuName = if (resp.getHeader("x-ms-sku-name")) |value|
                    enums.SkuName.fromWire(value)
                else
                    null;
                const response_header_1: ?enums.AccountKind = if (resp.getHeader("x-ms-account-kind")) |value|
                    enums.AccountKind.fromWire(value)
                else
                    null;
                const response_header_2: ?bool = if (resp.getHeader("x-ms-is-hns-enabled")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .sku_name = response_header_0,
                        .account_kind = response_header_1,
                        .is_hierarchical_namespace_enabled = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Container.getAccountInfo", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const Blob = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const DownloadResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                metadata: ?[]const u8 = null,
                object_replication_rules: ?[]const u8 = null,
                last_modified: []const u8,
                creation_time: []const u8,
                object_replication_policy_id: ?[]const u8 = null,
                content_length: i64,
                content_range: []const u8,
                e_tag: []const u8,
                content_md5: []const u8,
                content_encoding: []const u8,
                cache_control: []const u8,
                content_disposition: []const u8,
                content_language: []const u8,
                blob_sequence_number: i64,
                blob_type: ?enums.BlobType = null,
                copy_completion_time: ?[]const u8 = null,
                copy_status_description: ?[]const u8 = null,
                copy_id: ?[]const u8 = null,
                copy_progress: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                copy_source: ?[]const u8 = null,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                version_id: []const u8,
                is_current_version: ?bool = null,
                accept_ranges: ?[]const u8 = null,
                date: []const u8,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                blob_content_md5: ?[]const u8 = null,
                tag_count: ?i64 = null,
                is_sealed: ?bool = null,
                last_accessed: ?[]const u8 = null,
                immutability_policy_expires_on: ?[]const u8 = null,
                immutability_policy_mode: enums.ImmutabilityPolicyMode,
                legal_hold: ?bool = null,
                structured_body_type: ?[]const u8 = null,
                structured_content_length: ?i64 = null,
                version: []const u8,
                content_type: []const u8,
            },
            body: []const u8,
        },
        status_206: struct {
            status: u16 = 206,
            headers: struct {
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                metadata: ?[]const u8 = null,
                object_replication_rules: ?[]const u8 = null,
                last_modified: []const u8,
                creation_time: []const u8,
                object_replication_policy_id: ?[]const u8 = null,
                content_length: i64,
                content_range: []const u8,
                e_tag: []const u8,
                content_md5: []const u8,
                content_encoding: []const u8,
                cache_control: []const u8,
                content_disposition: []const u8,
                content_language: []const u8,
                blob_sequence_number: i64,
                blob_type: ?enums.BlobType = null,
                content_crc64: ?[]const u8 = null,
                copy_completion_time: ?[]const u8 = null,
                copy_status_description: ?[]const u8 = null,
                copy_id: ?[]const u8 = null,
                copy_progress: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                copy_source: ?[]const u8 = null,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                version_id: []const u8,
                is_current_version: ?bool = null,
                accept_ranges: ?[]const u8 = null,
                date: []const u8,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                blob_content_md5: ?[]const u8 = null,
                tag_count: ?i64 = null,
                is_sealed: ?bool = null,
                last_accessed: ?[]const u8 = null,
                immutability_policy_expires_on: ?[]const u8 = null,
                immutability_policy_mode: enums.ImmutabilityPolicyMode,
                legal_hold: ?bool = null,
                structured_body_type: ?[]const u8 = null,
                structured_content_length: ?i64 = null,
                version: []const u8,
                content_type: []const u8,
            },
            body: []const u8,
        },
    };

    pub const GetPropertiesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                content_type: ?[]const u8 = null,
                metadata: ?[]const u8 = null,
                object_replication_rules: ?[]const u8 = null,
                last_modified: []const u8,
                creation_time: []const u8,
                object_replication_policy_id: ?[]const u8 = null,
                blob_type: ?enums.BlobType = null,
                copy_completion_time: ?[]const u8 = null,
                copy_status_description: ?[]const u8 = null,
                copy_id: ?[]const u8 = null,
                copy_progress: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                copy_source: ?[]const u8 = null,
                is_incremental_copy: ?bool = null,
                destination_snapshot: ?[]const u8 = null,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                content_length: i64,
                e_tag: []const u8,
                content_md5: []const u8,
                content_encoding: []const u8,
                content_disposition: []const u8,
                content_language: []const u8,
                cache_control: []const u8,
                blob_sequence_number: i64,
                accept_ranges: ?[]const u8 = null,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                access_tier: ?[]const u8 = null,
                access_tier_inferred: ?bool = null,
                archive_status: ?enums.ArchiveStatus = null,
                access_tier_change_time: ?[]const u8 = null,
                smart_access_tier: ?[]const u8 = null,
                version_id: []const u8,
                is_current_version: ?bool = null,
                tag_count: ?i64 = null,
                expires_on: ?[]const u8 = null,
                is_sealed: ?bool = null,
                rehydrate_priority: ?enums.RehydratePriority = null,
                last_accessed: ?[]const u8 = null,
                immutability_policy_expires_on: ?[]const u8 = null,
                immutability_policy_mode: enums.ImmutabilityPolicyMode,
                legal_hold: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const DeleteResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const UndeleteResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetExpiryResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetPropertiesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                blob_sequence_number: i64,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetImmutabilityPolicyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                immutability_policy_expires_on: ?[]const u8 = null,
                immutability_policy_mode: enums.ImmutabilityPolicyMode,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const DeleteImmutabilityPolicyResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetLegalHoldResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                legal_hold: bool,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetMetadataResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const AcquireLeaseResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                lease_id: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ReleaseLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const RenewLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                lease_id: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ChangeLeaseResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                lease_id: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const BreakLeaseResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                lease_time: ?i32 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const CreateSnapshotResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                snapshot: ?[]const u8 = null,
                e_tag: []const u8,
                last_modified: []const u8,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const StartCopyFromUrlResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                version_id: []const u8,
                copy_id: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const CopyFromUrlResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                version_id: []const u8,
                copy_id: ?[]const u8 = null,
                copy_status: ?[]const u8 = null,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const AbortCopyFromUrlResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetTierResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetAccountInfoResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                account_kind: ?enums.AccountKind = null,
                sku_name: ?enums.SkuName = null,
                is_hierarchical_namespace_enabled: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetTagsResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.BlobTags,
        },
    };

    pub const SetTagsResult = union(enum) {
        status_204: struct {
            status: u16 = 204,
            headers: struct {
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };
    /// Downloads the specified blob.
    pub fn download(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, version_id: ?[]const u8, timeout: ?i32, range: ?[]const u8, lease_id: ?[]const u8, range_get_content_md5: ?bool, range_get_content_crc64: ?bool, structured_body_type: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, if_tags: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8) !DownloadResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (range) |value| try req.setHeader("Range", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (range_get_content_md5) |value| try req.setHeader("x-ms-range-get-content-md5", if (value) "true" else "false");
        if (range_get_content_crc64) |value| try req.setHeader("x-ms-range-get-content-crc64", if (value) "true" else "false");
        if (structured_body_type) |value| try req.setHeader("x-ms-structured-body", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        try req.setHeader("Accept", "application/octet-stream");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-or")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-creation-time") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = if (resp.getHeader("x-ms-or-policy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Encoding") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_11);
                const response_header_12 = try alloc.dupe(
                    u8,
                    resp.getHeader("Cache-Control") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_12);
                const response_header_13 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Disposition") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_13);
                const response_header_14 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Language") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_14);
                const response_header_15 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_16: ?enums.BlobType = if (resp.getHeader("x-ms-blob-type")) |value|
                    enums.BlobType.fromWire(value)
                else
                    null;
                const response_header_17 = if (resp.getHeader("x-ms-copy-completion-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_17) |value| alloc.free(value);
                const response_header_18 = if (resp.getHeader("x-ms-copy-status-description")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_18) |value| alloc.free(value);
                const response_header_19 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_19) |value| alloc.free(value);
                const response_header_20 = if (resp.getHeader("x-ms-copy-progress")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_20) |value| alloc.free(value);
                const response_header_21: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_22 = if (resp.getHeader("x-ms-copy-source")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_22) |value| alloc.free(value);
                const response_header_23: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_24: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_25: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_26 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_26);
                const response_header_27: ?bool = if (resp.getHeader("x-ms-is-current-version")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_28 = if (resp.getHeader("Accept-Ranges")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_28) |value| alloc.free(value);
                const response_header_29 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_29);
                const response_header_30: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_31: ?bool = if (resp.getHeader("x-ms-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_32 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_32) |value| alloc.free(value);
                const response_header_33 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_33) |value| alloc.free(value);
                const response_header_34 = if (resp.getHeader("x-ms-blob-content-md5")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_34) |value| alloc.free(value);
                const response_header_35: ?i64 = if (resp.getHeader("x-ms-tag-count")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_36: ?bool = if (resp.getHeader("x-ms-blob-sealed")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_37 = if (resp.getHeader("x-ms-last-access-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_37) |value| alloc.free(value);
                const response_header_38 = if (resp.getHeader("x-ms-immutability-policy-until-date")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_38) |value| alloc.free(value);
                const response_header_39 = enums.ImmutabilityPolicyMode.fromWire(
                    resp.getHeader("x-ms-immutability-policy-mode") orelse return error.MissingResponseHeader,
                ) orelse return error.UnexpectedResponseHeaderValue;
                const response_header_40: ?bool = if (resp.getHeader("x-ms-legal-hold")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_41 = if (resp.getHeader("x-ms-structured-body")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_41) |value| alloc.free(value);
                const response_header_42: ?i64 = if (resp.getHeader("x-ms-structured-content-length")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_43 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_43);
                const response_header_44 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_44);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .request_id = response_header_0,
                        .client_request_id = response_header_1,
                        .metadata = response_header_2,
                        .object_replication_rules = response_header_3,
                        .last_modified = response_header_4,
                        .creation_time = response_header_5,
                        .object_replication_policy_id = response_header_6,
                        .content_length = response_header_7,
                        .content_range = response_header_8,
                        .e_tag = response_header_9,
                        .content_md5 = response_header_10,
                        .content_encoding = response_header_11,
                        .cache_control = response_header_12,
                        .content_disposition = response_header_13,
                        .content_language = response_header_14,
                        .blob_sequence_number = response_header_15,
                        .blob_type = response_header_16,
                        .copy_completion_time = response_header_17,
                        .copy_status_description = response_header_18,
                        .copy_id = response_header_19,
                        .copy_progress = response_header_20,
                        .copy_status = response_header_21,
                        .copy_source = response_header_22,
                        .duration = response_header_23,
                        .lease_state = response_header_24,
                        .lease_status = response_header_25,
                        .version_id = response_header_26,
                        .is_current_version = response_header_27,
                        .accept_ranges = response_header_28,
                        .date = response_header_29,
                        .blob_committed_block_count = response_header_30,
                        .is_server_encrypted = response_header_31,
                        .encryption_key_sha256 = response_header_32,
                        .encryption_scope = response_header_33,
                        .blob_content_md5 = response_header_34,
                        .tag_count = response_header_35,
                        .is_sealed = response_header_36,
                        .last_accessed = response_header_37,
                        .immutability_policy_expires_on = response_header_38,
                        .immutability_policy_mode = response_header_39,
                        .legal_hold = response_header_40,
                        .structured_body_type = response_header_41,
                        .structured_content_length = response_header_42,
                        .version = response_header_43,
                        .content_type = response_header_44,
                    },
                    .body = response_body,
                } };
            },
            206 => {
                const response_header_0 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = if (resp.getHeader("x-ms-or")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-creation-time") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = if (resp.getHeader("x-ms-or-policy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Encoding") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_11);
                const response_header_12 = try alloc.dupe(
                    u8,
                    resp.getHeader("Cache-Control") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_12);
                const response_header_13 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Disposition") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_13);
                const response_header_14 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Language") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_14);
                const response_header_15 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_16: ?enums.BlobType = if (resp.getHeader("x-ms-blob-type")) |value|
                    enums.BlobType.fromWire(value)
                else
                    null;
                const response_header_17 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_17) |value| alloc.free(value);
                const response_header_18 = if (resp.getHeader("x-ms-copy-completion-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_18) |value| alloc.free(value);
                const response_header_19 = if (resp.getHeader("x-ms-copy-status-description")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_19) |value| alloc.free(value);
                const response_header_20 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_20) |value| alloc.free(value);
                const response_header_21 = if (resp.getHeader("x-ms-copy-progress")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_21) |value| alloc.free(value);
                const response_header_22: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_23 = if (resp.getHeader("x-ms-copy-source")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_23) |value| alloc.free(value);
                const response_header_24: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_25: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_26: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_27 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_27);
                const response_header_28: ?bool = if (resp.getHeader("x-ms-is-current-version")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_29 = if (resp.getHeader("Accept-Ranges")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_29) |value| alloc.free(value);
                const response_header_30 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_30);
                const response_header_31: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_32: ?bool = if (resp.getHeader("x-ms-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_33 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_33) |value| alloc.free(value);
                const response_header_34 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_34) |value| alloc.free(value);
                const response_header_35 = if (resp.getHeader("x-ms-blob-content-md5")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_35) |value| alloc.free(value);
                const response_header_36: ?i64 = if (resp.getHeader("x-ms-tag-count")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_37: ?bool = if (resp.getHeader("x-ms-blob-sealed")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_38 = if (resp.getHeader("x-ms-last-access-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_38) |value| alloc.free(value);
                const response_header_39 = if (resp.getHeader("x-ms-immutability-policy-until-date")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_39) |value| alloc.free(value);
                const response_header_40 = enums.ImmutabilityPolicyMode.fromWire(
                    resp.getHeader("x-ms-immutability-policy-mode") orelse return error.MissingResponseHeader,
                ) orelse return error.UnexpectedResponseHeaderValue;
                const response_header_41: ?bool = if (resp.getHeader("x-ms-legal-hold")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_42 = if (resp.getHeader("x-ms-structured-body")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_42) |value| alloc.free(value);
                const response_header_43: ?i64 = if (resp.getHeader("x-ms-structured-content-length")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_44 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_44);
                const response_header_45 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_45);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_206 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .request_id = response_header_0,
                        .client_request_id = response_header_1,
                        .metadata = response_header_2,
                        .object_replication_rules = response_header_3,
                        .last_modified = response_header_4,
                        .creation_time = response_header_5,
                        .object_replication_policy_id = response_header_6,
                        .content_length = response_header_7,
                        .content_range = response_header_8,
                        .e_tag = response_header_9,
                        .content_md5 = response_header_10,
                        .content_encoding = response_header_11,
                        .cache_control = response_header_12,
                        .content_disposition = response_header_13,
                        .content_language = response_header_14,
                        .blob_sequence_number = response_header_15,
                        .blob_type = response_header_16,
                        .content_crc64 = response_header_17,
                        .copy_completion_time = response_header_18,
                        .copy_status_description = response_header_19,
                        .copy_id = response_header_20,
                        .copy_progress = response_header_21,
                        .copy_status = response_header_22,
                        .copy_source = response_header_23,
                        .duration = response_header_24,
                        .lease_state = response_header_25,
                        .lease_status = response_header_26,
                        .version_id = response_header_27,
                        .is_current_version = response_header_28,
                        .accept_ranges = response_header_29,
                        .date = response_header_30,
                        .blob_committed_block_count = response_header_31,
                        .is_server_encrypted = response_header_32,
                        .encryption_key_sha256 = response_header_33,
                        .encryption_scope = response_header_34,
                        .blob_content_md5 = response_header_35,
                        .tag_count = response_header_36,
                        .is_sealed = response_header_37,
                        .last_accessed = response_header_38,
                        .immutability_policy_expires_on = response_header_39,
                        .immutability_policy_mode = response_header_40,
                        .legal_hold = response_header_41,
                        .structured_body_type = response_header_42,
                        .structured_content_length = response_header_43,
                        .version = response_header_44,
                        .content_type = response_header_45,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Blob.download", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns all user-defined metadata, standard HTTP properties, and system properties for the specified blob. It does not return the content of the blob.
    pub fn getProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, version_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !GetPropertiesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .HEAD, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("Content-Type")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2 = if (resp.getHeader("x-ms-or")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-creation-time") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-or-policy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6: ?enums.BlobType = if (resp.getHeader("x-ms-blob-type")) |value|
                    enums.BlobType.fromWire(value)
                else
                    null;
                const response_header_7 = if (resp.getHeader("x-ms-copy-completion-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-copy-status-description")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10 = if (resp.getHeader("x-ms-copy-progress")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                const response_header_11: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_12 = if (resp.getHeader("x-ms-copy-source")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                const response_header_13: ?bool = if (resp.getHeader("x-ms-incremental-copy")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_14 = if (resp.getHeader("x-ms-copy-destination-snapshot")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_14) |value| alloc.free(value);
                const response_header_15: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_16: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_17: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_18 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_19 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_19);
                const response_header_20 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_20);
                const response_header_21 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Encoding") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_21);
                const response_header_22 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Disposition") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_22);
                const response_header_23 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Language") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_23);
                const response_header_24 = try alloc.dupe(
                    u8,
                    resp.getHeader("Cache-Control") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_24);
                const response_header_25 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_26 = if (resp.getHeader("Accept-Ranges")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_26) |value| alloc.free(value);
                const response_header_27: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_28: ?bool = if (resp.getHeader("x-ms-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_29 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_29) |value| alloc.free(value);
                const response_header_30 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_30) |value| alloc.free(value);
                const response_header_31 = if (resp.getHeader("x-ms-access-tier")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_31) |value| alloc.free(value);
                const response_header_32: ?bool = if (resp.getHeader("x-ms-access-tier-inferred")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_33: ?enums.ArchiveStatus = if (resp.getHeader("x-ms-archive-status")) |value|
                    try enums.ArchiveStatus.fromWire(alloc, value)
                else
                    null;
                const response_header_34 = if (resp.getHeader("x-ms-access-tier-change-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_34) |value| alloc.free(value);
                const response_header_35 = if (resp.getHeader("x-ms-smart-access-tier")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_35) |value| alloc.free(value);
                const response_header_36 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_36);
                const response_header_37: ?bool = if (resp.getHeader("x-ms-is-current-version")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_38: ?i64 = if (resp.getHeader("x-ms-tag-count")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_39 = if (resp.getHeader("x-ms-expiry-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_39) |value| alloc.free(value);
                const response_header_40: ?bool = if (resp.getHeader("x-ms-blob-sealed")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_41: ?enums.RehydratePriority = if (resp.getHeader("x-ms-rehydrate-priority")) |value|
                    try enums.RehydratePriority.fromWire(alloc, value)
                else
                    null;
                const response_header_42 = if (resp.getHeader("x-ms-last-access-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_42) |value| alloc.free(value);
                const response_header_43 = if (resp.getHeader("x-ms-immutability-policy-until-date")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_43) |value| alloc.free(value);
                const response_header_44 = enums.ImmutabilityPolicyMode.fromWire(
                    resp.getHeader("x-ms-immutability-policy-mode") orelse return error.MissingResponseHeader,
                ) orelse return error.UnexpectedResponseHeaderValue;
                const response_header_45: ?bool = if (resp.getHeader("x-ms-legal-hold")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_46 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_46);
                const response_header_47 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_47);
                const response_header_48 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_48) |value| alloc.free(value);
                const response_header_49 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_49) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_type = response_header_0,
                        .metadata = response_header_1,
                        .object_replication_rules = response_header_2,
                        .last_modified = response_header_3,
                        .creation_time = response_header_4,
                        .object_replication_policy_id = response_header_5,
                        .blob_type = response_header_6,
                        .copy_completion_time = response_header_7,
                        .copy_status_description = response_header_8,
                        .copy_id = response_header_9,
                        .copy_progress = response_header_10,
                        .copy_status = response_header_11,
                        .copy_source = response_header_12,
                        .is_incremental_copy = response_header_13,
                        .destination_snapshot = response_header_14,
                        .duration = response_header_15,
                        .lease_state = response_header_16,
                        .lease_status = response_header_17,
                        .content_length = response_header_18,
                        .e_tag = response_header_19,
                        .content_md5 = response_header_20,
                        .content_encoding = response_header_21,
                        .content_disposition = response_header_22,
                        .content_language = response_header_23,
                        .cache_control = response_header_24,
                        .blob_sequence_number = response_header_25,
                        .accept_ranges = response_header_26,
                        .blob_committed_block_count = response_header_27,
                        .is_server_encrypted = response_header_28,
                        .encryption_key_sha256 = response_header_29,
                        .encryption_scope = response_header_30,
                        .access_tier = response_header_31,
                        .access_tier_inferred = response_header_32,
                        .archive_status = response_header_33,
                        .access_tier_change_time = response_header_34,
                        .smart_access_tier = response_header_35,
                        .version_id = response_header_36,
                        .is_current_version = response_header_37,
                        .tag_count = response_header_38,
                        .expires_on = response_header_39,
                        .is_sealed = response_header_40,
                        .rehydrate_priority = response_header_41,
                        .last_accessed = response_header_42,
                        .immutability_policy_expires_on = response_header_43,
                        .immutability_policy_mode = response_header_44,
                        .legal_hold = response_header_45,
                        .date = response_header_46,
                        .version = response_header_47,
                        .request_id = response_header_48,
                        .client_request_id = response_header_49,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.getProperties", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes the specified blob. If blob soft delete is enabled, the blob is marked for deletion and can be recovered until the retention period expires.
    pub fn delete(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, version_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, delete_snapshots: ?enums.DeleteSnapshotsOptionType, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, blob_delete_type: ?enums.BlobDeleteType, access_tier_if_modified_since: ?[]const u8, access_tier_if_unmodified_since: ?[]const u8) !DeleteResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (blob_delete_type) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}deletetype={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (delete_snapshots) |value| try req.setHeader("x-ms-delete-snapshots", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (access_tier_if_modified_since) |value| try req.setHeader("x-ms-access-tier-if-modified-since", value);
        if (access_tier_if_unmodified_since) |value| try req.setHeader("x-ms-access-tier-if-unmodified-since", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
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
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.delete", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Undelete the specified previously soft deleted blob.
    pub fn undelete(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !UndeleteResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=undelete", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);

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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.undelete", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Set the expiration time of the specified blob.
    pub fn setExpiry(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, expiry_options: enums.BlobExpiryOptions, expires_on: ?[]const u8) !SetExpiryResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=expiry", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-expiry-option", expiry_options.toWire());
        if (expires_on) |value| try req.setHeader("x-ms-expiry-time", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setExpiry", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets system properties on the specified blob.
    pub fn setProperties(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, blob_cache_control: ?[]const u8, blob_content_type: ?[]const u8, blob_content_md5: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !SetPropertiesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .blob_sequence_number = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setProperties", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Set the immutability policy on the specified blob.
    pub fn setImmutabilityPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, if_unmodified_since: ?[]const u8, expiry: []const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, snapshot: ?[]const u8, version_id: ?[]const u8) !SetImmutabilityPolicyResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=immutabilityPolicies", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        try req.setHeader("x-ms-immutability-policy-until-date", expiry);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-immutability-policy-until-date")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = enums.ImmutabilityPolicyMode.fromWire(
                    resp.getHeader("x-ms-immutability-policy-mode") orelse return error.MissingResponseHeader,
                ) orelse return error.UnexpectedResponseHeaderValue;
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .immutability_policy_expires_on = response_header_0,
                        .immutability_policy_mode = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setImmutabilityPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Deletes the immutability policy on the specified blob.
    pub fn deleteImmutabilityPolicy(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, snapshot: ?[]const u8, version_id: ?[]const u8) !DeleteImmutabilityPolicyResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=immutabilityPolicies", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);

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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.deleteImmutabilityPolicy", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets a legal hold on the specified blob.
    pub fn setLegalHold(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, legal_hold: bool, snapshot: ?[]const u8, version_id: ?[]const u8) !SetLegalHoldResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=legalhold", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-legal-hold", if (legal_hold) "true" else "false");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = std.mem.eql(u8, resp.getHeader("x-ms-legal-hold") orelse return error.MissingResponseHeader, "true");
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .legal_hold = response_header_0,
                        .date = response_header_1,
                        .version = response_header_2,
                        .request_id = response_header_3,
                        .client_request_id = response_header_4,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setLegalHold", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets user-defined metadata for the specified blob.
    pub fn setMetadata(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, metadata: ?[]const u8, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !SetMetadataResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=metadata", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_4 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5 = if (resp.getHeader("x-ms-encryption-scope")) |value|
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
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .version_id = response_header_2,
                        .is_server_encrypted = response_header_3,
                        .encryption_key_sha256 = response_header_4,
                        .encryption_scope = response_header_5,
                        .date = response_header_6,
                        .version = response_header_7,
                        .request_id = response_header_8,
                        .client_request_id = response_header_9,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setMetadata", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Requests a new lease on the specified blob.
    pub fn acquireLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, duration: i32, proposed_lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !AcquireLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{duration});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-lease-duration", header_val);
        }
        if (proposed_lease_id) |value| try req.setHeader("x-ms-proposed-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-lease-action", "acquire");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .lease_id = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.acquireLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Frees the lease if it's no longer needed, so that another client can immediately acquire a lease against the blob.
    pub fn releaseLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: []const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !ReleaseLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-lease-action", "release");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .date = response_header_2,
                        .version = response_header_3,
                        .request_id = response_header_4,
                        .client_request_id = response_header_5,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.releaseLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Renews an existing lease.
    pub fn renewLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: []const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !RenewLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-lease-action", "renew");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .lease_id = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.renewLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Change the ID of an existing lease.
    pub fn changeLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: []const u8, proposed_lease_id: []const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !ChangeLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-lease-id", lease_id);
        try req.setHeader("x-ms-proposed-lease-id", proposed_lease_id);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-lease-action", "change");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-lease-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .lease_id = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.changeLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Ends a lease and ensures that another client can't acquire a new lease until the current lease period has expired.
    pub fn breakLease(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, break_period: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !BreakLeaseResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=lease", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (break_period) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-lease-break-period", header_val);
        }
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-lease-action", "break");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2: ?i32 = if (resp.getHeader("x-ms-lease-time")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .lease_time = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.breakLease", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Creates a read-only snapshot of the specified blob.
    pub fn createSnapshot(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, metadata: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, lease_id: ?[]const u8) !CreateSnapshotResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=snapshot", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = if (resp.getHeader("x-ms-snapshot")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .snapshot = response_header_0,
                        .e_tag = response_header_1,
                        .last_modified = response_header_2,
                        .version_id = response_header_3,
                        .is_server_encrypted = response_header_4,
                        .date = response_header_5,
                        .version = response_header_6,
                        .request_id = response_header_7,
                        .client_request_id = response_header_8,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.createSnapshot", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Starts an asynchronous copy from a source URL to a destination blob.
    pub fn startCopyFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, metadata: ?[]const u8, tier: ?enums.AccessTier, rehydrate_priority: ?enums.RehydratePriority, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, source_if_tags: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, copy_source: []const u8, lease_id: ?[]const u8, blob_tags_string: ?[]const u8, seal_blob: ?bool, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool) !StartCopyFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (rehydrate_priority) |value| try req.setHeader("x-ms-rehydrate-priority", value.toWire());
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (source_if_tags) |value| try req.setHeader("x-ms-source-if-tags", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-copy-source", copy_source);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (seal_blob) |value| try req.setHeader("x-ms-seal-blob", if (value) "true" else "false");
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .version_id = response_header_2,
                        .copy_id = response_header_3,
                        .copy_status = response_header_4,
                        .date = response_header_5,
                        .version = response_header_6,
                        .request_id = response_header_7,
                        .client_request_id = response_header_8,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.startCopyFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Synchronously copies a blob from a source URL to the destination blob.
    pub fn copyFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, metadata: ?[]const u8, tier: ?enums.AccessTier, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, copy_source: []const u8, lease_id: ?[]const u8, source_content_md5: ?[]const u8, blob_tags_string: ?[]const u8, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool, copy_source_authorization: ?[]const u8, encryption_scope: ?[]const u8, copy_source_tags: ?enums.BlobCopySourceTags, file_request_intent: ?enums.FileShareTokenIntent) !CopyFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-copy-source", copy_source);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (source_content_md5) |value| try req.setHeader("x-ms-source-content-md5", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");
        if (copy_source_authorization) |value| try req.setHeader("x-ms-copy-source-authorization", value);
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (copy_source_tags) |value| try req.setHeader("x-ms-copy-source-tag-option", value.toWire());
        if (file_request_intent) |value| try req.setHeader("x-ms-file-request-intent", value.toWire());
        try req.setHeader("x-ms-requires-sync", "true");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-copy-status")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                const response_header_11 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .version_id = response_header_2,
                        .copy_id = response_header_3,
                        .copy_status = response_header_4,
                        .content_md5 = response_header_5,
                        .content_crc64 = response_header_6,
                        .encryption_scope = response_header_7,
                        .date = response_header_8,
                        .version = response_header_9,
                        .request_id = response_header_10,
                        .client_request_id = response_header_11,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.copyFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Aborts a pending asynchronous copy operation and leaves a destination blob with zero length and full metadata.
    pub fn abortCopyFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, copy_id: []const u8, lease_id: ?[]const u8) !AbortCopyFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=copy", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, copy_id);
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}copyid={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        try req.setHeader("x-ms-copy-action", "abort");

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
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.abortCopyFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets the tier of the specified blob.
    pub fn setTier(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, version_id: ?[]const u8, timeout: ?i32, tier: enums.AccessTier, rehydrate_priority: ?enums.RehydratePriority, lease_id: ?[]const u8, if_tags: ?[]const u8) !SetTierResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=tier", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-access-tier", tier.toWire());
        if (rehydrate_priority) |value| try req.setHeader("x-ms-rehydrate-priority", value.toWire());
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);

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
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            202 => {
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
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setTier", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns information about the storage account.
    pub fn getAccountInfo(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32) !GetAccountInfoResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?restype=account&comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0: ?enums.AccountKind = if (resp.getHeader("x-ms-account-kind")) |value|
                    enums.AccountKind.fromWire(value)
                else
                    null;
                const response_header_1: ?enums.SkuName = if (resp.getHeader("x-ms-sku-name")) |value|
                    enums.SkuName.fromWire(value)
                else
                    null;
                const response_header_2: ?bool = if (resp.getHeader("x-ms-is-hns-enabled")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .account_kind = response_header_0,
                        .sku_name = response_header_1,
                        .is_hierarchical_namespace_enabled = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.getAccountInfo", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Gets the tags of the specified blob.
    pub fn getTags(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, snapshot: ?[]const u8, version_id: ?[]const u8, lease_id: ?[]const u8, if_tags: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_match: ?[]const u8, if_none_match: ?[]const u8) !GetTagsResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=tags", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (if_modified_since) |value| try req.setHeader("x-ms-blob-if-modified-since", value);
        if (if_unmodified_since) |value| try req.setHeader("x-ms-blob-if-unmodified-since", value);
        if (if_match) |value| try req.setHeader("x-ms-blob-if-match", value);
        if (if_none_match) |value| try req.setHeader("x-ms-blob-if-none-match", value);
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
                const response_body = try serde.xml.fromSlice(models.BlobTags, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .date = response_header_0,
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                        .content_type = response_header_4,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("Blob.getTags", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Sets the tags of the specified blob.
    pub fn setTags(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, version_id: ?[]const u8, transactional_content_md5: ?[]const u8, transactional_content_crc64: ?[]const u8, if_tags: ?[]const u8, lease_id: ?[]const u8, tags: models.BlobTags, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_match: ?[]const u8, if_none_match: ?[]const u8) !SetTagsResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=tags", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (version_id) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}versionid={s}", .{ sep, enc });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/xml");
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("x-ms-blob-if-modified-since", value);
        if (if_unmodified_since) |value| try req.setHeader("x-ms-blob-if-unmodified-since", value);
        if (if_match) |value| try req.setHeader("x-ms-blob-if-match", value);
        if (if_none_match) |value| try req.setHeader("x-ms-blob-if-none-match", value);
        const body_xml = try serde.xml.toSlice(alloc, tags);
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
                        .version = response_header_1,
                        .request_id = response_header_2,
                        .client_request_id = response_header_3,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("Blob.setTags", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const AppendBlob = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const AppendBlockResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                blob_append_offset: ?[]const u8 = null,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                structured_body_type: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const AppendBlockFromUrlResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                blob_append_offset: ?[]const u8 = null,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SealResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                is_sealed: ?bool = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };
    /// Creates a new append blob.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, metadata: ?[]const u8, timeout: ?i32, blob_content_type: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, blob_content_md5: ?[]const u8, blob_cache_control: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, blob_tags_string: ?[]const u8, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool) !CreateResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");
        try req.setHeader("Content-Length", "0");
        try req.setHeader("x-ms-blob-type", "AppendBlob");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_5 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .version_id = response_header_3,
                        .is_server_encrypted = response_header_4,
                        .encryption_key_sha256 = response_header_5,
                        .encryption_scope = response_header_6,
                        .date = response_header_7,
                        .version = response_header_8,
                        .request_id = response_header_9,
                        .client_request_id = response_header_10,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("AppendBlob.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Uploads a new block of data to the end of an append blob.
    pub fn appendBlock(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, body: []const u8, timeout: ?i32, content_length: i64, transactional_content_md5: ?[]const u8, transactional_content_crc64: ?[]const u8, lease_id: ?[]const u8, max_size: ?i64, append_position: ?i64, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, structured_body_type: ?[]const u8, structured_content_length: ?i64) !AppendBlockResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=appendblock", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/octet-stream");
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (max_size) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-condition-maxsize", header_val);
        }
        if (append_position) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-condition-appendpos", header_val);
        }
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (structured_body_type) |value| try req.setHeader("x-ms-structured-body", value);
        if (structured_content_length) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-structured-content-length", header_val);
        }
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-blob-append-offset")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_6: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_7 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = if (resp.getHeader("x-ms-structured-body")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_11);
                const response_header_12 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                const response_header_13 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_13) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .blob_append_offset = response_header_4,
                        .blob_committed_block_count = response_header_5,
                        .is_server_encrypted = response_header_6,
                        .encryption_key_sha256 = response_header_7,
                        .encryption_scope = response_header_8,
                        .structured_body_type = response_header_9,
                        .date = response_header_10,
                        .version = response_header_11,
                        .request_id = response_header_12,
                        .client_request_id = response_header_13,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("AppendBlob.appendBlock", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Uploads a new block of data from the specified URL to the end of an append blob.
    pub fn appendBlockFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, source_url: []const u8, source_range: ?[]const u8, source_content_md5: ?[]const u8, source_content_crc64: ?[]const u8, timeout: ?i32, content_length: i64, transactional_content_md5: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, lease_id: ?[]const u8, max_size: ?i64, append_position: ?i64, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, copy_source_authorization: ?[]const u8, file_request_intent: ?enums.FileShareTokenIntent, source_encryption_key: ?[]const u8, source_encryption_key_sha256: ?[]const u8, source_encryption_algorithm: ?enums.EncryptionAlgorithmType) !AppendBlockFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=appendblock", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-copy-source", source_url);
        if (source_range) |value| try req.setHeader("x-ms-source-range", value);
        if (source_content_md5) |value| try req.setHeader("x-ms-source-content-md5", value);
        if (source_content_crc64) |value| try req.setHeader("x-ms-source-content-crc64", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (max_size) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-condition-maxsize", header_val);
        }
        if (append_position) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-condition-appendpos", header_val);
        }
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (copy_source_authorization) |value| try req.setHeader("x-ms-copy-source-authorization", value);
        if (file_request_intent) |value| try req.setHeader("x-ms-file-request-intent", value.toWire());
        if (source_encryption_key) |value| try req.setHeader("x-ms-source-encryption-key", value);
        if (source_encryption_key_sha256) |value| try req.setHeader("x-ms-source-encryption-key-sha256", value);
        if (source_encryption_algorithm) |value| try req.setHeader("x-ms-source-encryption-algorithm", value.toWire());

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-blob-append-offset")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_6: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_7 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                const response_header_12 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .blob_append_offset = response_header_4,
                        .blob_committed_block_count = response_header_5,
                        .is_server_encrypted = response_header_6,
                        .encryption_key_sha256 = response_header_7,
                        .encryption_scope = response_header_8,
                        .date = response_header_9,
                        .version = response_header_10,
                        .request_id = response_header_11,
                        .client_request_id = response_header_12,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("AppendBlob.appendBlockFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Seals the append blob to make it read-only.
    pub fn seal(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, append_position: ?i64) !SealResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=seal", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (append_position) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-condition-appendpos", header_val);
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2: ?bool = if (resp.getHeader("x-ms-blob-sealed")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .is_sealed = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("AppendBlob.seal", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const BlockBlob = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const UploadResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                structured_body_type: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const UploadBlobFromUrlResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const StageBlockResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                structured_body_type: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const StageBlockFromUrlResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const CommitBlockListResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetBlockListResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                last_modified: []const u8,
                e_tag: []const u8,
                blob_content_length: ?i64 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.BlockList,
        },
    };

    pub const QueryResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                metadata: ?[]const u8 = null,
                last_modified: []const u8,
                content_length: i64,
                content_range: []const u8,
                e_tag: []const u8,
                content_md5: []const u8,
                content_encoding: []const u8,
                cache_control: []const u8,
                content_disposition: []const u8,
                content_language: []const u8,
                blob_sequence_number: i64,
                blob_type: ?enums.BlobType = null,
                content_crc64: ?[]const u8 = null,
                copy_completion_time: ?[]const u8 = null,
                copy_status_description: ?[]const u8 = null,
                copy_id: ?[]const u8 = null,
                copy_progress: ?[]const u8 = null,
                copy_source: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                accept_ranges: ?[]const u8 = null,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                blob_content_md5: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: []const u8,
        },
        status_206: struct {
            status: u16 = 206,
            headers: struct {
                metadata: ?[]const u8 = null,
                last_modified: []const u8,
                content_length: i64,
                content_range: []const u8,
                e_tag: []const u8,
                content_md5: []const u8,
                content_encoding: []const u8,
                cache_control: []const u8,
                content_disposition: []const u8,
                content_language: []const u8,
                blob_sequence_number: i64,
                blob_type: ?enums.BlobType = null,
                content_crc64: ?[]const u8 = null,
                copy_completion_time: ?[]const u8 = null,
                copy_status_description: ?[]const u8 = null,
                copy_id: ?[]const u8 = null,
                copy_progress: ?[]const u8 = null,
                copy_source: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                duration: ?enums.LeaseDuration = null,
                lease_state: ?enums.LeaseState = null,
                lease_status: ?enums.LeaseStatus = null,
                accept_ranges: ?[]const u8 = null,
                blob_committed_block_count: ?i32 = null,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                blob_content_md5: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: []const u8,
        },
    };
    /// Uploads the content to the specified block blob. If the blob already exists, the data and any existing metadata will be overwritten.
    pub fn upload(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, metadata: ?[]const u8, body: []const u8, timeout: ?i32, transactional_content_md5: ?[]const u8, content_length: i64, blob_content_type: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, blob_content_md5: ?[]const u8, blob_cache_control: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, tier: ?enums.AccessTier, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, blob_tags_string: ?[]const u8, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool, transactional_content_crc64: ?[]const u8, structured_body_type: ?[]const u8, structured_content_length: ?i64) !UploadResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/octet-stream");
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        if (structured_body_type) |value| try req.setHeader("x-ms-structured-body", value);
        if (structured_content_length) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-structured-content-length", header_val);
        }
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_6 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-structured-body")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                const response_header_12 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .version_id = response_header_4,
                        .is_server_encrypted = response_header_5,
                        .encryption_key_sha256 = response_header_6,
                        .encryption_scope = response_header_7,
                        .structured_body_type = response_header_8,
                        .date = response_header_9,
                        .version = response_header_10,
                        .request_id = response_header_11,
                        .client_request_id = response_header_12,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.upload", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Uploads the content from the specified URL to the block blob. If the blob already exists, the data and any existing metadata will be overwritten.
    pub fn uploadBlobFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, metadata: ?[]const u8, timeout: ?i32, transactional_content_md5: ?[]const u8, blob_content_type: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, blob_content_md5: ?[]const u8, blob_cache_control: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, tier: ?enums.AccessTier, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, source_if_tags: ?[]const u8, source_content_md5: ?[]const u8, blob_tags_string: ?[]const u8, copy_source: []const u8, copy_source_blob_properties: ?bool, copy_source_authorization: ?[]const u8, copy_source_tags: ?enums.BlobCopySourceTags, file_request_intent: ?enums.FileShareTokenIntent, source_encryption_key: ?[]const u8, source_encryption_key_sha256: ?[]const u8, source_encryption_algorithm: ?enums.EncryptionAlgorithmType) !UploadBlobFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (source_if_tags) |value| try req.setHeader("x-ms-source-if-tags", value);
        if (source_content_md5) |value| try req.setHeader("x-ms-source-content-md5", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        try req.setHeader("x-ms-copy-source", copy_source);
        try req.setHeader("Content-Length", "0");
        if (copy_source_blob_properties) |value| try req.setHeader("x-ms-copy-source-blob-properties", if (value) "true" else "false");
        if (copy_source_authorization) |value| try req.setHeader("x-ms-copy-source-authorization", value);
        if (copy_source_tags) |value| try req.setHeader("x-ms-copy-source-tag-option", value.toWire());
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        if (file_request_intent) |value| try req.setHeader("x-ms-file-request-intent", value.toWire());
        if (source_encryption_key) |value| try req.setHeader("x-ms-source-encryption-key", value);
        if (source_encryption_key_sha256) |value| try req.setHeader("x-ms-source-encryption-key-sha256", value);
        if (source_encryption_algorithm) |value| try req.setHeader("x-ms-source-encryption-algorithm", value.toWire());

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_5 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .version_id = response_header_3,
                        .is_server_encrypted = response_header_4,
                        .encryption_key_sha256 = response_header_5,
                        .encryption_scope = response_header_6,
                        .date = response_header_7,
                        .version = response_header_8,
                        .request_id = response_header_9,
                        .client_request_id = response_header_10,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.uploadBlobFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Creates a new block of data to be committed as part of a blob.
    pub fn stageBlock(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, block_id: []const u8, content_length: i64, transactional_content_md5: ?[]const u8, transactional_content_crc64: ?[]const u8, body: []const u8, timeout: ?i32, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, structured_body_type: ?[]const u8, structured_content_length: ?i64) !StageBlockResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=block", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, block_id);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}blockid={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/octet-stream");
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (structured_body_type) |value| try req.setHeader("x-ms-structured-body", value);
        if (structured_content_length) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-structured-content-length", header_val);
        }
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_4) |value| alloc.free(value);
                const response_header_5 = if (resp.getHeader("x-ms-structured-body")) |value|
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
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_md5 = response_header_0,
                        .content_crc64 = response_header_1,
                        .is_server_encrypted = response_header_2,
                        .encryption_key_sha256 = response_header_3,
                        .encryption_scope = response_header_4,
                        .structured_body_type = response_header_5,
                        .date = response_header_6,
                        .version = response_header_7,
                        .request_id = response_header_8,
                        .client_request_id = response_header_9,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.stageBlock", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Creates a new block of data from the specified URL to be committed as part of a blob.
    pub fn stageBlockFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, block_id: []const u8, content_length: i64, source_url: []const u8, source_range: ?[]const u8, source_content_md5: ?[]const u8, source_content_crc64: ?[]const u8, timeout: ?i32, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, lease_id: ?[]const u8, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, copy_source_authorization: ?[]const u8, file_request_intent: ?enums.FileShareTokenIntent, source_encryption_key: ?[]const u8, source_encryption_key_sha256: ?[]const u8, source_encryption_algorithm: ?enums.EncryptionAlgorithmType) !StageBlockFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=block", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        const encoded_query_0 = try core.url.percentEncode(alloc, block_id);
        defer alloc.free(encoded_query_0);
        try url_buf.print(alloc, "{s}blockid={s}", .{ if (has_query) "&" else "?", encoded_query_0 });
        has_query = true;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        try req.setHeader("x-ms-copy-source", source_url);
        if (source_range) |value| try req.setHeader("x-ms-source-range", value);
        if (source_content_md5) |value| try req.setHeader("x-ms-source-content-md5", value);
        if (source_content_crc64) |value| try req.setHeader("x-ms-source-content-crc64", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (copy_source_authorization) |value| try req.setHeader("x-ms-copy-source-authorization", value);
        if (file_request_intent) |value| try req.setHeader("x-ms-file-request-intent", value.toWire());
        if (source_encryption_key) |value| try req.setHeader("x-ms-source-encryption-key", value);
        if (source_encryption_key_sha256) |value| try req.setHeader("x-ms-source-encryption-key-sha256", value);
        if (source_encryption_algorithm) |value| try req.setHeader("x-ms-source-encryption-algorithm", value.toWire());

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_1) |value| alloc.free(value);
                const response_header_2: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_3 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = if (resp.getHeader("x-ms-encryption-scope")) |value|
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
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .content_md5 = response_header_0,
                        .content_crc64 = response_header_1,
                        .is_server_encrypted = response_header_2,
                        .encryption_key_sha256 = response_header_3,
                        .encryption_scope = response_header_4,
                        .date = response_header_5,
                        .version = response_header_6,
                        .request_id = response_header_7,
                        .client_request_id = response_header_8,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.stageBlockFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Writes to the block blob by specifying the list of block IDs that make up the blob.
    pub fn commitBlockList(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, blob_cache_control: ?[]const u8, blob_content_type: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, blob_content_md5: ?[]const u8, transactional_content_md5: ?[]const u8, transactional_content_crc64: ?[]const u8, metadata: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, tier: ?enums.AccessTier, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, blocks: models.BlockLookupList, blob_tags_string: ?[]const u8, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool) !CommitBlockListResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=blocklist", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/xml");
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");
        const body_xml = try serde.xml.toSlice(alloc, blocks);
        defer alloc.free(body_xml);
        req.body = body_xml;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_6 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                const response_header_11 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .version_id = response_header_4,
                        .is_server_encrypted = response_header_5,
                        .encryption_key_sha256 = response_header_6,
                        .encryption_scope = response_header_7,
                        .date = response_header_8,
                        .version = response_header_9,
                        .request_id = response_header_10,
                        .client_request_id = response_header_11,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.commitBlockList", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Retrieves the list of blocks that have been uploaded as part of the block blob.
    pub fn getBlockList(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, list_type: enums.BlockListType, timeout: ?i32, lease_id: ?[]const u8, if_tags: ?[]const u8) !GetBlockListResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=blocklist", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        const encoded_query_1 = try core.url.percentEncode(alloc, list_type.toWire());
        defer alloc.free(encoded_query_1);
        try url_buf.print(alloc, "{s}blocklisttype={s}", .{ if (has_query) "&" else "?", encoded_query_1 });
        has_query = true;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2: ?i64 = if (resp.getHeader("x-ms-blob-content-length")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_body = try serde.xml.fromSlice(models.BlockList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .last_modified = response_header_0,
                        .e_tag = response_header_1,
                        .blob_content_length = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                        .content_type = response_header_7,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.getBlockList", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Queries the data of the specified blob with the provided query expressions.
    pub fn query(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, query_request: models.QueryRequest, snapshot: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !QueryResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=query", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/xml");
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("Accept", "application/octet-stream");
        const body_xml = try serde.xml.toSlice(alloc, query_request);
        defer alloc.free(body_xml);
        req.body = body_xml;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Encoding") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Cache-Control") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Disposition") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Language") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_11: ?enums.BlobType = if (resp.getHeader("x-ms-blob-type")) |value|
                    enums.BlobType.fromWire(value)
                else
                    null;
                const response_header_12 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                const response_header_13 = if (resp.getHeader("x-ms-copy-completion-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_13) |value| alloc.free(value);
                const response_header_14 = if (resp.getHeader("x-ms-copy-status-description")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_14) |value| alloc.free(value);
                const response_header_15 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_15) |value| alloc.free(value);
                const response_header_16 = if (resp.getHeader("x-ms-copy-progress")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_16) |value| alloc.free(value);
                const response_header_17 = if (resp.getHeader("x-ms-copy-source")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_17) |value| alloc.free(value);
                const response_header_18: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_19: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_20: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_21: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_22 = if (resp.getHeader("Accept-Ranges")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_22) |value| alloc.free(value);
                const response_header_23: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_24: ?bool = if (resp.getHeader("x-ms-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_25 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_25) |value| alloc.free(value);
                const response_header_26 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_26) |value| alloc.free(value);
                const response_header_27 = if (resp.getHeader("x-ms-blob-content-md5")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_27) |value| alloc.free(value);
                const response_header_28 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_28);
                const response_header_29 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_29);
                const response_header_30 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_30) |value| alloc.free(value);
                const response_header_31 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_31) |value| alloc.free(value);
                const response_header_32 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_32);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .metadata = response_header_0,
                        .last_modified = response_header_1,
                        .content_length = response_header_2,
                        .content_range = response_header_3,
                        .e_tag = response_header_4,
                        .content_md5 = response_header_5,
                        .content_encoding = response_header_6,
                        .cache_control = response_header_7,
                        .content_disposition = response_header_8,
                        .content_language = response_header_9,
                        .blob_sequence_number = response_header_10,
                        .blob_type = response_header_11,
                        .content_crc64 = response_header_12,
                        .copy_completion_time = response_header_13,
                        .copy_status_description = response_header_14,
                        .copy_id = response_header_15,
                        .copy_progress = response_header_16,
                        .copy_source = response_header_17,
                        .copy_status = response_header_18,
                        .duration = response_header_19,
                        .lease_state = response_header_20,
                        .lease_status = response_header_21,
                        .accept_ranges = response_header_22,
                        .blob_committed_block_count = response_header_23,
                        .is_server_encrypted = response_header_24,
                        .encryption_key_sha256 = response_header_25,
                        .encryption_scope = response_header_26,
                        .blob_content_md5 = response_header_27,
                        .date = response_header_28,
                        .version = response_header_29,
                        .request_id = response_header_30,
                        .client_request_id = response_header_31,
                        .content_type = response_header_32,
                    },
                    .body = response_body,
                } };
            },
            206 => {
                const response_header_0 = if (resp.getHeader("x-ms-meta")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_0) |value| alloc.free(value);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("Content-Length") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Range") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Encoding") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Cache-Control") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Disposition") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Language") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_11: ?enums.BlobType = if (resp.getHeader("x-ms-blob-type")) |value|
                    enums.BlobType.fromWire(value)
                else
                    null;
                const response_header_12 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                const response_header_13 = if (resp.getHeader("x-ms-copy-completion-time")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_13) |value| alloc.free(value);
                const response_header_14 = if (resp.getHeader("x-ms-copy-status-description")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_14) |value| alloc.free(value);
                const response_header_15 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_15) |value| alloc.free(value);
                const response_header_16 = if (resp.getHeader("x-ms-copy-progress")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_16) |value| alloc.free(value);
                const response_header_17 = if (resp.getHeader("x-ms-copy-source")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_17) |value| alloc.free(value);
                const response_header_18: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_19: ?enums.LeaseDuration = if (resp.getHeader("x-ms-lease-duration")) |value|
                    enums.LeaseDuration.fromWire(value)
                else
                    null;
                const response_header_20: ?enums.LeaseState = if (resp.getHeader("x-ms-lease-state")) |value|
                    enums.LeaseState.fromWire(value)
                else
                    null;
                const response_header_21: ?enums.LeaseStatus = if (resp.getHeader("x-ms-lease-status")) |value|
                    enums.LeaseStatus.fromWire(value)
                else
                    null;
                const response_header_22 = if (resp.getHeader("Accept-Ranges")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_22) |value| alloc.free(value);
                const response_header_23: ?i32 = if (resp.getHeader("x-ms-blob-committed-block-count")) |value|
                    try std.fmt.parseInt(i32, value, 10)
                else
                    null;
                const response_header_24: ?bool = if (resp.getHeader("x-ms-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_25 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_25) |value| alloc.free(value);
                const response_header_26 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_26) |value| alloc.free(value);
                const response_header_27 = if (resp.getHeader("x-ms-blob-content-md5")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_27) |value| alloc.free(value);
                const response_header_28 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_28);
                const response_header_29 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_29);
                const response_header_30 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_30) |value| alloc.free(value);
                const response_header_31 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_31) |value| alloc.free(value);
                const response_header_32 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_32);
                const response_body = try bufferRawResponseBody(alloc, resp.body);
                errdefer alloc.free(response_body);
                return .{ .status_206 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .metadata = response_header_0,
                        .last_modified = response_header_1,
                        .content_length = response_header_2,
                        .content_range = response_header_3,
                        .e_tag = response_header_4,
                        .content_md5 = response_header_5,
                        .content_encoding = response_header_6,
                        .cache_control = response_header_7,
                        .content_disposition = response_header_8,
                        .content_language = response_header_9,
                        .blob_sequence_number = response_header_10,
                        .blob_type = response_header_11,
                        .content_crc64 = response_header_12,
                        .copy_completion_time = response_header_13,
                        .copy_status_description = response_header_14,
                        .copy_id = response_header_15,
                        .copy_progress = response_header_16,
                        .copy_source = response_header_17,
                        .copy_status = response_header_18,
                        .duration = response_header_19,
                        .lease_state = response_header_20,
                        .lease_status = response_header_21,
                        .accept_ranges = response_header_22,
                        .blob_committed_block_count = response_header_23,
                        .is_server_encrypted = response_header_24,
                        .encryption_key_sha256 = response_header_25,
                        .encryption_scope = response_header_26,
                        .blob_content_md5 = response_header_27,
                        .date = response_header_28,
                        .version = response_header_29,
                        .request_id = response_header_30,
                        .client_request_id = response_header_31,
                        .content_type = response_header_32,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("BlockBlob.query", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};

pub const PageBlob = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const CreateResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                version_id: []const u8,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const UploadPagesResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                blob_sequence_number: i64,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                structured_body_type: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const ClearPagesResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                blob_sequence_number: i64,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const UploadPagesFromUrlResult = union(enum) {
        status_201: struct {
            status: u16 = 201,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                content_md5: []const u8,
                content_crc64: ?[]const u8 = null,
                blob_sequence_number: i64,
                is_server_encrypted: ?bool = null,
                encryption_key_sha256: ?[]const u8 = null,
                encryption_scope: ?[]const u8 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const GetPageRangesResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                last_modified: []const u8,
                e_tag: []const u8,
                blob_content_length: ?i64 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.PageList,
        },
    };

    pub const GetPageRangesDiffResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                last_modified: []const u8,
                e_tag: []const u8,
                blob_content_length: ?i64 = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
                content_type: []const u8,
            },
            body: models.PageList,
        },
    };

    pub const ResizeResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                blob_sequence_number: i64,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const SetSequenceNumberResult = union(enum) {
        status_200: struct {
            status: u16 = 200,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                blob_sequence_number: i64,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };

    pub const CopyIncrementalResult = union(enum) {
        status_202: struct {
            status: u16 = 202,
            headers: struct {
                e_tag: []const u8,
                last_modified: []const u8,
                copy_id: ?[]const u8 = null,
                copy_status: ?enums.CopyStatus = null,
                date: []const u8,
                version: []const u8,
                request_id: ?[]const u8 = null,
                client_request_id: ?[]const u8 = null,
            },
            body: void,
        },
    };
    /// Creates a new page blob.
    pub fn create(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, metadata: ?[]const u8, timeout: ?i32, tier: ?enums.PremiumPageBlobAccessTier, blob_content_type: ?[]const u8, blob_content_encoding: ?[]const u8, blob_content_language: ?[]const u8, blob_content_md5: ?[]const u8, blob_cache_control: ?[]const u8, lease_id: ?[]const u8, blob_content_disposition: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, size: i64, blob_sequence_number: ?i64, blob_tags_string: ?[]const u8, immutability_policy_expiry: ?[]const u8, immutability_policy_mode: ?enums.ImmutabilityPolicyMode, legal_hold: ?bool) !CreateResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}/", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (metadata) |value| try req.setHeader("x-ms-meta", value);
        if (tier) |value| try req.setHeader("x-ms-access-tier", value.toWire());
        if (blob_content_type) |value| try req.setHeader("x-ms-blob-content-type", value);
        if (blob_content_encoding) |value| try req.setHeader("x-ms-blob-content-encoding", value);
        if (blob_content_language) |value| try req.setHeader("x-ms-blob-content-language", value);
        if (blob_content_md5) |value| try req.setHeader("x-ms-blob-content-md5", value);
        if (blob_cache_control) |value| try req.setHeader("x-ms-blob-cache-control", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (blob_content_disposition) |value| try req.setHeader("x-ms-blob-content-disposition", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{size});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-content-length", header_val);
        }
        if (blob_sequence_number) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-sequence-number", header_val);
        }
        if (blob_tags_string) |value| try req.setHeader("x-ms-tags", value);
        if (immutability_policy_expiry) |value| try req.setHeader("x-ms-immutability-policy-until-date", value);
        if (immutability_policy_mode) |value| try req.setHeader("x-ms-immutability-policy-mode", value.toWire());
        if (legal_hold) |value| try req.setHeader("x-ms-legal-hold", if (value) "true" else "false");
        try req.setHeader("Content-Length", "0");
        try req.setHeader("x-ms-blob-type", "PageBlob");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version-id") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_5 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_9) |value| alloc.free(value);
                const response_header_10 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .version_id = response_header_3,
                        .is_server_encrypted = response_header_4,
                        .encryption_key_sha256 = response_header_5,
                        .encryption_scope = response_header_6,
                        .date = response_header_7,
                        .version = response_header_8,
                        .request_id = response_header_9,
                        .client_request_id = response_header_10,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.create", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Writes a range of pages to the specified page blob.
    pub fn uploadPages(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, body: []const u8, content_length: i64, transactional_content_md5: ?[]const u8, transactional_content_crc64: ?[]const u8, timeout: ?i32, range: []const u8, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_sequence_number_less_than_or_equal_to: ?i64, if_sequence_number_less_than: ?i64, if_sequence_number_equal_to: ?i64, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, structured_body_type: ?[]const u8, structured_content_length: ?i64) !UploadPagesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=page", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Type", "application/octet-stream");
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        if (transactional_content_md5) |value| try req.setHeader("Content-MD5", value);
        if (transactional_content_crc64) |value| try req.setHeader("x-ms-content-crc64", value);
        try req.setHeader("Range", range);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_sequence_number_less_than_or_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-le", header_val);
        }
        if (if_sequence_number_less_than) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-lt", header_val);
        }
        if (if_sequence_number_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-eq", header_val);
        }
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (structured_body_type) |value| try req.setHeader("x-ms-structured-body", value);
        if (structured_content_length) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-structured-content-length", header_val);
        }
        try req.setHeader("x-ms-page-write", "update");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_5: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_6 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-structured-body")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_10);
                const response_header_11 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                const response_header_12 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_12) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .blob_sequence_number = response_header_4,
                        .is_server_encrypted = response_header_5,
                        .encryption_key_sha256 = response_header_6,
                        .encryption_scope = response_header_7,
                        .structured_body_type = response_header_8,
                        .date = response_header_9,
                        .version = response_header_10,
                        .request_id = response_header_11,
                        .client_request_id = response_header_12,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.uploadPages", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Clears a range of pages from the specified page blob.
    pub fn clearPages(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, range: []const u8, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_sequence_number_less_than_or_equal_to: ?i64, if_sequence_number_less_than: ?i64, if_sequence_number_equal_to: ?i64, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8) !ClearPagesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=page", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("Content-Length", "0");
        try req.setHeader("Range", range);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_sequence_number_less_than_or_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-le", header_val);
        }
        if (if_sequence_number_less_than) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-lt", header_val);
        }
        if (if_sequence_number_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-eq", header_val);
        }
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-page-write", "clear");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_6);
                const response_header_7 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_8) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .blob_sequence_number = response_header_4,
                        .date = response_header_5,
                        .version = response_header_6,
                        .request_id = response_header_7,
                        .client_request_id = response_header_8,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.clearPages", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Writes a range of pages to the specified page blob where the contents are read from a URL.
    pub fn uploadPagesFromUrl(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, source_url: []const u8, source_range: []const u8, source_content_md5: ?[]const u8, source_content_crc64: ?[]const u8, content_length: i64, timeout: ?i32, range: []const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, lease_id: ?[]const u8, if_sequence_number_less_than_or_equal_to: ?i64, if_sequence_number_less_than: ?i64, if_sequence_number_equal_to: ?i64, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, source_if_modified_since: ?[]const u8, source_if_unmodified_since: ?[]const u8, source_if_match: ?[]const u8, source_if_none_match: ?[]const u8, copy_source_authorization: ?[]const u8, file_request_intent: ?enums.FileShareTokenIntent, source_encryption_key: ?[]const u8, source_encryption_key_sha256: ?[]const u8, source_encryption_algorithm: ?enums.EncryptionAlgorithmType) !UploadPagesFromUrlResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=page", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        try req.setHeader("x-ms-copy-source", source_url);
        try req.setHeader("x-ms-source-range", source_range);
        if (source_content_md5) |value| try req.setHeader("x-ms-source-content-md5", value);
        if (source_content_crc64) |value| try req.setHeader("x-ms-source-content-crc64", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{content_length});
            defer alloc.free(header_val);
            try req.setHeader("Content-Length", header_val);
        }
        try req.setHeader("Range", range);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_sequence_number_less_than_or_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-le", header_val);
        }
        if (if_sequence_number_less_than) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-lt", header_val);
        }
        if (if_sequence_number_equal_to) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-if-sequence-number-eq", header_val);
        }
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        if (source_if_modified_since) |value| try req.setHeader("x-ms-source-if-modified-since", value);
        if (source_if_unmodified_since) |value| try req.setHeader("x-ms-source-if-unmodified-since", value);
        if (source_if_match) |value| try req.setHeader("x-ms-source-if-match", value);
        if (source_if_none_match) |value| try req.setHeader("x-ms-source-if-none-match", value);
        if (copy_source_authorization) |value| try req.setHeader("x-ms-copy-source-authorization", value);
        if (file_request_intent) |value| try req.setHeader("x-ms-file-request-intent", value.toWire());
        try req.setHeader("x-ms-page-write", "update");
        if (source_encryption_key) |value| try req.setHeader("x-ms-source-encryption-key", value);
        if (source_encryption_key_sha256) |value| try req.setHeader("x-ms-source-encryption-key-sha256", value);
        if (source_encryption_algorithm) |value| try req.setHeader("x-ms-source-encryption-algorithm", value.toWire());

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            201 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-MD5") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_2);
                const response_header_3 = if (resp.getHeader("x-ms-content-crc64")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_3) |value| alloc.free(value);
                const response_header_4 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_5: ?bool = if (resp.getHeader("x-ms-request-server-encrypted")) |value|
                    std.mem.eql(u8, value, "true")
                else
                    null;
                const response_header_6 = if (resp.getHeader("x-ms-encryption-key-sha256")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-encryption-scope")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                const response_header_8 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_8);
                const response_header_9 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_9);
                const response_header_10 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_10) |value| alloc.free(value);
                const response_header_11 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_11) |value| alloc.free(value);
                return .{ .status_201 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .content_md5 = response_header_2,
                        .content_crc64 = response_header_3,
                        .blob_sequence_number = response_header_4,
                        .is_server_encrypted = response_header_5,
                        .encryption_key_sha256 = response_header_6,
                        .encryption_scope = response_header_7,
                        .date = response_header_8,
                        .version = response_header_9,
                        .request_id = response_header_10,
                        .client_request_id = response_header_11,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.uploadPagesFromUrl", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns the list of valid page ranges for the specified page blob.
    pub fn getPageRanges(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, timeout: ?i32, range: ?[]const u8, lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, marker: ?[]const u8, maxresults: ?i32) !GetPageRangesResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=pagelist", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (marker) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}marker={s}", .{ sep, enc });
            has_query = true;
        }
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (range) |value| try req.setHeader("Range", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2: ?i64 = if (resp.getHeader("x-ms-blob-content-length")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_body = try serde.xml.fromSlice(models.PageList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .last_modified = response_header_0,
                        .e_tag = response_header_1,
                        .blob_content_length = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                        .content_type = response_header_7,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.getPageRanges", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Returns the list of page ranges in the diff between the specified page blob and the specified previous snapshot.
    pub fn getPageRangesDiff(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, snapshot: ?[]const u8, timeout: ?i32, prevsnapshot: ?[]const u8, prev_snapshot_url: ?[]const u8, range: ?[]const u8, lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, marker: ?[]const u8, maxresults: ?i32) !GetPageRangesDiffResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=pagelist", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (snapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}snapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        if (prevsnapshot) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}prevsnapshot={s}", .{ sep, enc });
            has_query = true;
        }
        if (marker) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            const enc = try core.url.percentEncode(alloc, v);
            defer alloc.free(enc);
            try url_buf.print(alloc, "{s}marker={s}", .{ sep, enc });
            has_query = true;
        }
        if (maxresults) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}maxresults={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (prev_snapshot_url) |value| try req.setHeader("x-ms-previous-snapshot-url", value);
        if (range) |value| try req.setHeader("Range", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("Accept", "application/xml");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2: ?i64 = if (resp.getHeader("x-ms-blob-content-length")) |value|
                    try std.fmt.parseInt(i64, value, 10)
                else
                    null;
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = try alloc.dupe(
                    u8,
                    resp.getHeader("Content-Type") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_7);
                const response_body = try serde.xml.fromSlice(models.PageList, alloc, resp.body);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .last_modified = response_header_0,
                        .e_tag = response_header_1,
                        .blob_content_length = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                        .content_type = response_header_7,
                    },
                    .body = response_body,
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.getPageRangesDiff", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Changes the size of the specified page blob.
    pub fn resize(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, encryption_key: ?[]const u8, encryption_key_sha256: ?[]const u8, encryption_algorithm: ?enums.EncryptionAlgorithmType, encryption_scope: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, size: i64) !ResizeResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (encryption_key) |value| try req.setHeader("x-ms-encryption-key", value);
        if (encryption_key_sha256) |value| try req.setHeader("x-ms-encryption-key-sha256", value);
        if (encryption_algorithm) |value| try req.setHeader("x-ms-encryption-algorithm", value.toWire());
        if (encryption_scope) |value| try req.setHeader("x-ms-encryption-scope", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{size});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-content-length", header_val);
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .blob_sequence_number = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.resize", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Updates the sequence number of the specified page blob. The operation will fail if the specified sequence number is less than the current sequence number of the blob.
    pub fn setSequenceNumber(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, lease_id: ?[]const u8, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, sequence_number_action: enums.SequenceNumberActionType, blob_sequence_number: ?i64) !SetSequenceNumberResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=properties", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (lease_id) |value| try req.setHeader("x-ms-lease-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-sequence-number-action", sequence_number_action.toWire());
        if (blob_sequence_number) |value| {
            const header_val = try std.fmt.allocPrint(alloc, "{d}", .{value});
            defer alloc.free(header_val);
            try req.setHeader("x-ms-blob-sequence-number", header_val);
        }

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            200 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = try std.fmt.parseInt(
                    i64,
                    resp.getHeader("x-ms-blob-sequence-number") orelse return error.MissingResponseHeader,
                    10,
                );
                const response_header_3 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_3);
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_5) |value| alloc.free(value);
                const response_header_6 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                return .{ .status_200 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .blob_sequence_number = response_header_2,
                        .date = response_header_3,
                        .version = response_header_4,
                        .request_id = response_header_5,
                        .client_request_id = response_header_6,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.setSequenceNumber", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
    /// Copies a snapshot of the source page blob to a destination page blob. The snapshot is copied such that only the differential changes between the previously copied snapshot are transferred to the destination.
    pub fn copyIncremental(self: *@This(), alloc: std.mem.Allocator, client_request_id: ?[]const u8, timeout: ?i32, if_modified_since: ?[]const u8, if_unmodified_since: ?[]const u8, if_none_match: ?[]const u8, if_match: ?[]const u8, if_tags: ?[]const u8, copy_source: []const u8) !CopyIncrementalResult {
        const base_url = try std.fmt.allocPrint(alloc, "{s}?comp=incrementalcopy", .{self.endpoint});
        defer alloc.free(base_url);
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.appendSlice(alloc, base_url);
        var has_query = std.mem.indexOfScalar(u8, base_url, '?') != null;
        if (timeout) |v| {
            const sep: []const u8 = if (has_query) "&" else "?";
            try url_buf.print(alloc, "{s}timeout={d}", .{ sep, v });
            has_query = true;
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", self.api_version);
        if (client_request_id) |value| try req.setHeader("x-ms-client-request-id", value);
        if (if_modified_since) |value| try req.setHeader("If-Modified-Since", value);
        if (if_unmodified_since) |value| try req.setHeader("If-Unmodified-Since", value);
        if (if_none_match) |value| try req.setHeader("If-None-Match", value);
        if (if_match) |value| try req.setHeader("If-Match", value);
        if (if_tags) |value| try req.setHeader("x-ms-if-tags", value);
        try req.setHeader("x-ms-copy-source", copy_source);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        switch (resp.status_code) {
            202 => {
                const response_header_0 = try alloc.dupe(
                    u8,
                    resp.getHeader("ETag") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_0);
                const response_header_1 = try alloc.dupe(
                    u8,
                    resp.getHeader("Last-Modified") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_1);
                const response_header_2 = if (resp.getHeader("x-ms-copy-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_2) |value| alloc.free(value);
                const response_header_3: ?enums.CopyStatus = if (resp.getHeader("x-ms-copy-status")) |value|
                    enums.CopyStatus.fromWire(value)
                else
                    null;
                const response_header_4 = try alloc.dupe(
                    u8,
                    resp.getHeader("Date") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_4);
                const response_header_5 = try alloc.dupe(
                    u8,
                    resp.getHeader("x-ms-version") orelse return error.MissingResponseHeader,
                );
                errdefer alloc.free(response_header_5);
                const response_header_6 = if (resp.getHeader("x-ms-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_6) |value| alloc.free(value);
                const response_header_7 = if (resp.getHeader("x-ms-client-request-id")) |value|
                    try alloc.dupe(u8, value)
                else
                    null;
                errdefer if (response_header_7) |value| alloc.free(value);
                return .{ .status_202 = .{
                    .status = resp.status_code,
                    .headers = .{
                        .e_tag = response_header_0,
                        .last_modified = response_header_1,
                        .copy_id = response_header_2,
                        .copy_status = response_header_3,
                        .date = response_header_4,
                        .version = response_header_5,
                        .request_id = response_header_6,
                        .client_request_id = response_header_7,
                    },
                    .body = {},
                } };
            },
            else => {
                core.pager.logHttpError("PageBlob.copyIncremental", resp.status_code, resp.body);
                return error.AzureRequestFailed;
            },
        }
    }
};
