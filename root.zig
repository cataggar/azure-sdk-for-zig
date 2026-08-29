const std = @import("std");
const core = @import("azure_sdk_core");

// ─────────────────────── ShareServiceClient ──────────────────

pub const ShareServiceClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

/// Account-scoped Azure Files client.
///
/// The endpoint, option strings, pipeline policy storage, and the backend
/// contexts borrowed by `pipeline.runtime` must outlive this client and every
/// client derived from it.
pub const ShareServiceClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub fn init(
        pipeline: core.http.HttpPipeline,
        endpoint: []const u8,
        options: ShareServiceClientOptions,
    ) ShareServiceClient {
        return .{
            .endpoint = endpoint,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    pub fn getShareClient(self: *const ShareServiceClient, share_name: []const u8) ShareClient {
        return .{
            .endpoint = self.endpoint,
            .share_name = share_name,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ─────────────────────────── ShareClient ──────────────────────

pub const ShareClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

/// Share-scoped Azure Files client.
///
/// The endpoint, share name, option strings, pipeline policy storage, and the
/// backend contexts borrowed by `pipeline.runtime` must outlive this client
/// and every client derived from it.
pub const ShareClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub fn init(
        pipeline: core.http.HttpPipeline,
        endpoint: []const u8,
        share_name: []const u8,
        options: ShareClientOptions,
    ) ShareClient {
        return .{
            .endpoint = endpoint,
            .share_name = share_name,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    /// PUT /share?restype=share
    pub fn create(self: *ShareClient, allocator: std.mem.Allocator) !void {
        var r = try self.createResult(allocator);
        try r.unwrap(error.CreateShareFailed);
    }

    /// Same as `create` but returns `Result(void)`.
    pub fn createResult(self: *ShareClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=share",
            .{ self.endpoint, self.share_name },
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

    /// DELETE /share?restype=share
    pub fn deleteShare(self: *ShareClient, allocator: std.mem.Allocator) !void {
        var r = try self.deleteShareResult(allocator);
        try r.unwrap(error.DeleteShareFailed);
    }

    /// Same as `deleteShare` but returns `Result(void)`.
    pub fn deleteShareResult(self: *ShareClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=share",
            .{ self.endpoint, self.share_name },
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

    pub fn getDirectoryClient(self: *const ShareClient, directory_name: []const u8) ShareDirectoryClient {
        return .{
            .endpoint = self.endpoint,
            .share_name = self.share_name,
            .directory_name = directory_name,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ────────────────────── ShareDirectoryClient ──────────────────

pub const ShareDirectoryClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

/// Directory-scoped Azure Files client.
///
/// The endpoint, names, option strings, pipeline policy storage, and the
/// backend contexts borrowed by `pipeline.runtime` must outlive this client
/// and every client derived from it.
pub const ShareDirectoryClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    directory_name: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub fn init(
        pipeline: core.http.HttpPipeline,
        endpoint: []const u8,
        share_name: []const u8,
        directory_name: []const u8,
        options: ShareDirectoryClientOptions,
    ) ShareDirectoryClient {
        return .{
            .endpoint = endpoint,
            .share_name = share_name,
            .directory_name = directory_name,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    /// PUT /share/directory?restype=directory
    pub fn create(self: *ShareDirectoryClient, allocator: std.mem.Allocator) !void {
        var r = try self.createResult(allocator);
        try r.unwrap(error.CreateDirectoryFailed);
    }

    /// Same as `create` but returns `Result(void)`.
    pub fn createResult(self: *ShareDirectoryClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}?restype=directory",
            .{ self.endpoint, self.share_name, self.directory_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-type", "directory");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// DELETE /share/directory?restype=directory
    pub fn deleteDirectory(self: *ShareDirectoryClient, allocator: std.mem.Allocator) !void {
        var r = try self.deleteDirectoryResult(allocator);
        try r.unwrap(error.DeleteDirectoryFailed);
    }

    /// Same as `deleteDirectory` but returns `Result(void)`.
    pub fn deleteDirectoryResult(self: *ShareDirectoryClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}?restype=directory",
            .{ self.endpoint, self.share_name, self.directory_name },
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

    pub fn getFileClient(self: *const ShareDirectoryClient, file_name: []const u8) ShareFileClient {
        return .{
            .endpoint = self.endpoint,
            .share_name = self.share_name,
            .directory_name = self.directory_name,
            .file_name = file_name,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ──────────────────────── ShareFileClient ─────────────────────

pub const ShareFileClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

/// File-scoped Azure Files client.
///
/// The endpoint, names, option strings, pipeline policy storage, and the
/// transport and crypto backend contexts borrowed by `pipeline.runtime` must
/// outlive this client.
pub const ShareFileClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    directory_name: []const u8,
    file_name: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub fn init(
        pipeline: core.http.HttpPipeline,
        endpoint: []const u8,
        share_name: []const u8,
        directory_name: []const u8,
        file_name: []const u8,
        options: ShareFileClientOptions,
    ) ShareFileClient {
        return .{
            .endpoint = endpoint,
            .share_name = share_name,
            .directory_name = directory_name,
            .file_name = file_name,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    /// PUT /share/dir/file (create with x-ms-type: file and x-ms-content-length)
    pub fn create(self: *ShareFileClient, allocator: std.mem.Allocator, content_length: u64) !void {
        var r = try self.createResult(allocator, content_length);
        try r.unwrap(error.CreateFileFailed);
    }

    /// Same as `create` but returns `Result(void)`.
    pub fn createResult(self: *ShareFileClient, allocator: std.mem.Allocator, content_length: u64) !core.errors.Result(void) {
        const url = try self.buildFileUrl(allocator);
        defer allocator.free(url);

        const len_str = try std.fmt.allocPrint(allocator, "{d}", .{content_length});
        defer allocator.free(len_str);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-type", "file");
        try req.setHeader("x-ms-content-length", len_str);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// PUT /share/dir/file?comp=range
    pub fn upload(self: *ShareFileClient, allocator: std.mem.Allocator, data: []const u8) !void {
        var r = try self.uploadResult(allocator, data);
        try r.unwrap(error.UploadFailed);
    }

    /// Same as `upload` but returns `Result(void)`.
    pub fn uploadResult(self: *ShareFileClient, allocator: std.mem.Allocator, data: []const u8) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}/{s}?comp=range",
            .{ self.endpoint, self.share_name, self.directory_name, self.file_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-write", "update");
        try req.setHeader("x-ms-type", "file");
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /share/dir/file
    pub fn download(self: *ShareFileClient, allocator: std.mem.Allocator) ![]const u8 {
        var r = try self.downloadResult(allocator);
        return r.unwrap(error.DownloadFailed);
    }

    /// Same as `download` but returns `Result([]const u8)`.
    pub fn downloadResult(self: *ShareFileClient, allocator: std.mem.Allocator) !core.errors.Result([]const u8) {
        const url = try self.buildFileUrl(allocator);
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

    /// DELETE /share/dir/file
    pub fn deleteFile(self: *ShareFileClient, allocator: std.mem.Allocator) !void {
        var r = try self.deleteFileResult(allocator);
        try r.unwrap(error.DeleteFileFailed);
    }

    /// Same as `deleteFile` but returns `Result(void)`.
    pub fn deleteFileResult(self: *ShareFileClient, allocator: std.mem.Allocator) !core.errors.Result(void) {
        const url = try self.buildFileUrl(allocator);
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

    fn buildFileUrl(self: *ShareFileClient, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}/{s}",
            .{ self.endpoint, self.share_name, self.directory_name, self.file_name },
        );
    }
};

// ─────────────────────────── Tests ────────────────────────────

test "ShareFileClient create and download" {
    const allocator = std.testing.allocator;
    var mock_create = core.http.MockTransport.init(allocator, 201, "");
    defer mock_create.deinit();

    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        mock_create.asTransport(),
        crypto.asProvider(),
    );
    const pipeline = core.http.HttpPipeline.init(runtime, &.{});
    var service = ShareServiceClient.init(
        pipeline,
        "https://myaccount.file.core.windows.net",
        .{},
    );
    var share = service.getShareClient("myshare");

    try share.create(allocator);
    try std.testing.expect(std.mem.find(u8, mock_create.last_url.?, "myshare?restype=share") != null);

    // Create directory and file
    var dir = share.getDirectoryClient("mydir");
    try dir.create(allocator);

    var file = dir.getFileClient("readme.txt");
    mock_create.response_status = 200;
    mock_create.response_body = "file content here";

    const content = try file.download(allocator);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("file content here", content);
}

test "constructors and derived clients preserve the selected runtime providers" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(transport.asTransport(), crypto.asProvider());
    const pipeline = core.http.HttpPipeline.init(runtime, &.{});

    var service = ShareServiceClient.init(pipeline, "https://example.file.core.windows.net", .{});
    var share = service.getShareClient("share");
    var directory = share.getDirectoryClient("directory");
    const file = directory.getFileClient("file");

    inline for (.{ service.pipeline, share.pipeline, directory.pipeline, file.pipeline }) |client_pipeline| {
        try std.testing.expectEqual(runtime.transport.context, client_pipeline.runtime.transport.context);
        try std.testing.expectEqual(runtime.transport.vtable, client_pipeline.runtime.transport.vtable);
        try std.testing.expectEqual(runtime.crypto.context, client_pipeline.runtime.crypto.context);
        try std.testing.expectEqual(runtime.crypto.vtable, client_pipeline.runtime.crypto.vtable);
    }

    const direct_share = ShareClient.init(pipeline, service.endpoint, "share", .{});
    const direct_directory = ShareDirectoryClient.init(
        pipeline,
        service.endpoint,
        "share",
        "directory",
        .{},
    );
    const direct_file = ShareFileClient.init(
        pipeline,
        service.endpoint,
        "share",
        "directory",
        "file",
        .{},
    );
    inline for (.{ direct_share.pipeline, direct_directory.pipeline, direct_file.pipeline }) |client_pipeline| {
        try std.testing.expectEqual(runtime.transport.context, client_pipeline.runtime.transport.context);
        try std.testing.expectEqual(runtime.crypto.context, client_pipeline.runtime.crypto.context);
    }
}
