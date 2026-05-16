const std = @import("std");
const core = @import("azure_core");

// ─────────────────────────── Models ───────────────────────────

pub const BlobProperties = struct {
    content_type: ?[]const u8 = null,
    content_length: ?u64 = null,
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,

    pub fn deinit(self: BlobProperties, allocator: std.mem.Allocator) void {
        if (self.content_type) |c| allocator.free(c);
        if (self.etag) |e| allocator.free(e);
        if (self.last_modified) |lm| allocator.free(lm);
    }
};

pub const BlobItem = struct {
    name: []const u8,
    properties: BlobProperties = .{},
};

// ─────────────────────── BlobContainerClient ──────────────────

pub const BlobContainerClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

pub const BlobContainerClient = struct {
    endpoint: []const u8,
    container_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        container_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: BlobContainerClientOptions,
    ) BlobContainerClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .container_name = container_name,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// PUT /container?restype=container
    pub fn create(self: *BlobContainerClient, allocator: std.mem.Allocator) !void {
        var r = try self.createResult(allocator);
        try r.unwrap(error.CreateContainerFailed);
    }

    /// Same as `create` but returns `Result(void)`.
    pub fn createResult(self: *BlobContainerClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=container",
            .{ self.endpoint, self.container_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// DELETE /container?restype=container
    pub fn deleteContainer(self: *BlobContainerClient, allocator: std.mem.Allocator) !void {
        var r = try self.deleteContainerResult(allocator);
        try r.unwrap(error.DeleteContainerFailed);
    }

    /// Same as `deleteContainer` but returns `Result(void)`.
    pub fn deleteContainerResult(self: *BlobContainerClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=container",
            .{ self.endpoint, self.container_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /container?restype=container&comp=list
    pub fn listBlobs(self: *BlobContainerClient, allocator: std.mem.Allocator) ![]BlobItem {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=container&comp=list",
            .{ self.endpoint, self.container_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListBlobsFailed;
        }

        return parseBlobList(allocator, resp.body);
    }

    pub fn getBlobClient(self: *BlobContainerClient, blob_name: []const u8) BlobClient {
        return .{
            .endpoint = self.endpoint,
            .container_name = self.container_name,
            .blob_name = blob_name,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ─────────────────────────── BlobClient ───────────────────────

pub const BlobClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

pub const UploadBlobOptions = struct {
    content_type: []const u8 = "application/octet-stream",
    if_match: ?[]const u8 = null,
    if_none_match: ?[]const u8 = null,
};

pub const UploadBlobResult = struct {
    etag: ?[]const u8 = null,
};

pub const BlobClient = struct {
    endpoint: []const u8,
    container_name: []const u8,
    blob_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        container_name: []const u8,
        blob_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: BlobClientOptions,
    ) BlobClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .container_name = container_name,
            .blob_name = blob_name,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET /container/blob
    pub fn download(self: *BlobClient, allocator: std.mem.Allocator) ![]const u8 {
        var r = try self.downloadResult(allocator);
        return r.unwrap(error.DownloadFailed);
    }

    /// Same as `download` but returns `Result([]const u8)`.
    pub fn downloadResult(self: *BlobClient, allocator: std.mem.Allocator) !core.errors.Result([]const u8) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try allocator.dupe(u8, resp.body) };
    }

    /// PUT /container/blob
    pub fn upload(self: *BlobClient, allocator: std.mem.Allocator, data: []const u8, content_type: []const u8) !void {
        var r = try self.uploadResult(allocator, data, content_type);
        try r.unwrap(error.UploadFailed);
    }

    /// Same as `upload` but returns `Result(void)`.
    pub fn uploadResult(self: *BlobClient, allocator: std.mem.Allocator, data: []const u8, content_type: []const u8) !core.errors.Result(void) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", content_type);
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// PUT /container/blob with conditional headers and ETag response.
    pub fn uploadConditional(self: *BlobClient, allocator: std.mem.Allocator, data: []const u8, options: UploadBlobOptions) !UploadBlobResult {
        var r = try self.uploadConditionalResult(allocator, data, options);
        return r.unwrap(error.UploadFailed);
    }

    /// Same as `uploadConditional` but returns `Result(UploadBlobResult)`.
    pub fn uploadConditionalResult(self: *BlobClient, allocator: std.mem.Allocator, data: []const u8, options: UploadBlobOptions) !core.errors.Result(UploadBlobResult) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", options.content_type);
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        if (options.if_match) |etag| try req.setHeader("If-Match", etag);
        if (options.if_none_match) |etag| try req.setHeader("If-None-Match", etag);
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        const etag = if (resp.headers.get("ETag")) |e| try allocator.dupe(u8, e) else null;
        return .{ .ok = .{ .etag = etag } };
    }

    /// DELETE /container/blob
    pub fn deleteBlob(self: *BlobClient, allocator: std.mem.Allocator) !void {
        var r = try self.deleteBlobResult(allocator);
        try r.unwrap(error.DeleteBlobFailed);
    }

    /// Same as `deleteBlob` but returns `Result(void)`.
    pub fn deleteBlobResult(self: *BlobClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// HEAD /container/blob
    pub fn getProperties(self: *BlobClient, allocator: std.mem.Allocator) !BlobProperties {
        var r = try self.getPropertiesResult(allocator);
        return r.unwrap(error.GetPropertiesFailed);
    }

    /// Same as `getProperties` but returns `Result(BlobProperties)`.
    pub fn getPropertiesResult(self: *BlobClient, allocator: std.mem.Allocator) !core.errors.Result(BlobProperties) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .HEAD, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = .{
            .etag = if (resp.headers.get("ETag")) |e| try allocator.dupe(u8, e) else null,
            .last_modified = if (resp.headers.get("Last-Modified")) |lm| try allocator.dupe(u8, lm) else null,
        } };
    }

    fn buildBlobUrl(self: *BlobClient, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}",
            .{ self.endpoint, self.container_name, self.blob_name },
        );
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseBlobList(allocator: std.mem.Allocator, body: []const u8) ![]BlobItem {
    // Azure Blob Storage returns XML:
    // <EnumerationResults>
    //   <Blobs>
    //     <Blob><Name>file1.txt</Name><Properties><Content-Type>text/plain</Content-Type></Properties></Blob>
    //   </Blobs>
    // </EnumerationResults>
    const serde = @import("serde");

    const BlobPropertiesSchema = struct {
        @"Content-Type": ?[]const u8 = null,
    };
    const BlobSchema = struct {
        Name: []const u8,
        Properties: ?BlobPropertiesSchema = null,
    };
    const BlobsSchema = struct {
        Blob: ?[]const BlobSchema = null,
    };
    const EnumerationResultsSchema = struct {
        Blobs: ?BlobsSchema = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(EnumerationResultsSchema, arena.allocator(), body) catch
        return allocator.alloc(BlobItem, 0);

    const blobs_envelope = parsed.Blobs orelse return allocator.alloc(BlobItem, 0);
    const blob_list = blobs_envelope.Blob orelse return allocator.alloc(BlobItem, 0);

    var result = try allocator.alloc(BlobItem, blob_list.len);
    for (blob_list, 0..) |blob, i| {
        result[i] = .{
            .name = try allocator.dupe(u8, blob.Name),
            .properties = .{
                .content_type = if (blob.Properties) |p|
                    (if (p.@"Content-Type") |ct| try allocator.dupe(u8, ct) else null)
                else
                    null,
            },
        };
    }
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

test "BlobContainerClient create and listBlobs" {
    const allocator = std.testing.allocator;
    const list_body =
        \\<EnumerationResults><Blobs><Blob><Name>file1.txt</Name><Properties><Content-Type>text/plain</Content-Type></Properties></Blob><Blob><Name>file2.bin</Name><Properties><Content-Type>application/octet-stream</Content-Type></Properties></Blob></Blobs></EnumerationResults>
    ;
    var mock_create = core.http.MockTransport.init(allocator, 201, "");
    defer mock_create.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var container = BlobContainerClient.init(
        "https://myaccount.blob.core.windows.net",
        "mycontainer",
        cred.asCredential(),
        mock_create.asTransport(),
        .{},
    );

    try container.create(allocator);
    try std.testing.expect(std.mem.find(u8, mock_create.last_url.?, "mycontainer?restype=container") != null);

    // Switch to list mock
    var mock_list = core.http.MockTransport.init(allocator, 200, list_body);
    defer mock_list.deinit();
    container.pipeline = .{ .policies = &.{}, .transport_impl = mock_list.asTransport() };

    const blobs = try container.listBlobs(allocator);
    defer {
        for (blobs) |b| {
            if (b.name.len > 0) allocator.free(b.name);
            if (b.properties.content_type) |ct| allocator.free(ct);
        }
        allocator.free(blobs);
    }

    try std.testing.expectEqual(@as(usize, 2), blobs.len);
    try std.testing.expectEqualStrings("file1.txt", blobs[0].name);
    try std.testing.expectEqualStrings("text/plain", blobs[0].properties.content_type.?);
}

test "BlobClient download and upload" {
    const allocator = std.testing.allocator;
    var mock_upload = core.http.MockTransport.init(allocator, 201, "");
    defer mock_upload.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = BlobClient.init(
        "https://myaccount.blob.core.windows.net",
        "mycontainer",
        "myblob.txt",
        cred.asCredential(),
        mock_upload.asTransport(),
        .{},
    );

    try client.upload(allocator, "hello world", "text/plain");
    try std.testing.expectEqual(core.http.Method.PUT, mock_upload.last_method.?);
    try std.testing.expect(std.mem.find(u8, mock_upload.last_url.?, "mycontainer/myblob.txt") != null);

    // Switch to download mock
    var mock_dl = core.http.MockTransport.init(allocator, 200, "hello world");
    defer mock_dl.deinit();
    client.pipeline = .{ .policies = &.{}, .transport_impl = mock_dl.asTransport() };

    const content = try client.download(allocator);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("hello world", content);
}

test "BlobClient uploadConditional with etag" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    mock.response_headers_list = &[_]core.http.MockTransport.HeaderPair{
        .{ .name = "ETag", .value = "\"0x8D12345\"" },
    };
    defer mock.deinit();

    const identity_uc = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity_uc.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = BlobClient.init(
        "https://myaccount.blob.core.windows.net",
        "mycontainer",
        "myblob.txt",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const result = try client.uploadConditional(allocator, "data", .{
        .content_type = "application/json",
        .if_none_match = "*",
    });
    defer if (result.etag) |e| allocator.free(e);
    try std.testing.expectEqualStrings("\"0x8D12345\"", result.etag.?);
}

test "BlobClient getProperties with etag" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    mock.response_headers_list = &[_]core.http.MockTransport.HeaderPair{
        .{ .name = "ETag", .value = "\"0xABC\"" },
        .{ .name = "Last-Modified", .value = "Mon, 12 Apr 2026 08:00:00 GMT" },
    };
    defer mock.deinit();

    const identity_gp = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity_gp.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = BlobClient.init(
        "https://myaccount.blob.core.windows.net",
        "mycontainer",
        "myblob.txt",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const props = try client.getProperties(allocator);
    defer {
        if (props.etag) |e| allocator.free(e);
        if (props.last_modified) |lm| allocator.free(lm);
    }
    try std.testing.expectEqualStrings("\"0xABC\"", props.etag.?);
    try std.testing.expectEqualStrings("Mon, 12 Apr 2026 08:00:00 GMT", props.last_modified.?);
}

test "BlobClient download 404" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 404,
        \\{"error":{"code":"BlobNotFound","message":"The specified blob does not exist."}}
    );
    defer mock.deinit();

    const identity3 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity3.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = BlobClient.init(
        "https://myaccount.blob.core.windows.net",
        "mycontainer",
        "missing.txt",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const result = client.download(allocator);
    try std.testing.expectError(error.DownloadFailed, result);
}
