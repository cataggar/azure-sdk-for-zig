const std = @import("std");
const core = @import("azure_core");

// ─────────────────────────── Models ───────────────────────────

pub const BlobProperties = struct {
    content_type: ?[]const u8 = null,
    content_length: ?u64 = null,
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,
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

        if (!resp.isSuccess()) return error.CreateContainerFailed;
    }

    /// DELETE /container?restype=container
    pub fn deleteContainer(self: *BlobContainerClient, allocator: std.mem.Allocator) !void {
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

        if (!resp.isSuccess()) return error.DeleteContainerFailed;
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
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.ListBlobsFailed;

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
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.DownloadFailed;

        return allocator.dupe(u8, resp.body);
    }

    /// PUT /container/blob
    pub fn upload(self: *BlobClient, allocator: std.mem.Allocator, data: []const u8, content_type: []const u8) !void {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", content_type);
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.UploadFailed;
    }

    /// DELETE /container/blob
    pub fn deleteBlob(self: *BlobClient, allocator: std.mem.Allocator) !void {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.DeleteBlobFailed;
    }

    /// HEAD /container/blob
    pub fn getProperties(self: *BlobClient, allocator: std.mem.Allocator) !BlobProperties {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .HEAD, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.GetPropertiesFailed;

        return .{};
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
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return allocator.alloc(BlobItem, 0);
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else
        return allocator.alloc(BlobItem, 0);

    const blobs_arr = if (obj.get("blobs")) |v| (if (v == .array) v.array.items else null) else null;
    const items = blobs_arr orelse return allocator.alloc(BlobItem, 0);

    var result = try allocator.alloc(BlobItem, items.len);
    for (items, 0..) |item, i| {
        var blob_item = BlobItem{ .name = "" };
        if (item == .object) {
            if (item.object.get("name")) |n| {
                if (n == .string) blob_item.name = try allocator.dupe(u8, n.string);
            }
            if (item.object.get("properties")) |p| {
                if (p == .object) {
                    if (p.object.get("Content-Type")) |ct| {
                        if (ct == .string) blob_item.properties.content_type = try allocator.dupe(u8, ct.string);
                    }
                }
            }
        }
        result[i] = blob_item;
    }
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

test "BlobContainerClient create and listBlobs" {
    const allocator = std.testing.allocator;
    const list_body =
        \\{"blobs":[{"name":"file1.txt","properties":{"Content-Type":"text/plain"}},{"name":"file2.bin","properties":{"Content-Type":"application/octet-stream"}}]}
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
    try std.testing.expect(std.mem.indexOf(u8, mock_create.last_url.?, "mycontainer?restype=container") != null);

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
    try std.testing.expect(std.mem.indexOf(u8, mock_upload.last_url.?, "mycontainer/myblob.txt") != null);

    // Switch to download mock
    var mock_dl = core.http.MockTransport.init(allocator, 200, "hello world");
    defer mock_dl.deinit();
    client.pipeline = .{ .policies = &.{}, .transport_impl = mock_dl.asTransport() };

    const content = try client.download(allocator);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("hello world", content);
}
