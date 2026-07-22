const std = @import("std");
const core = @import("azure_sdk_core");

// ─────────────────────────── ShareClient ──────────────────────

pub const ShareClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

pub const ShareClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        share_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: ShareClientOptions,
    ) ShareClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .share_name = share_name,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
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

    pub fn getDirectoryClient(self: *ShareClient, directory_name: []const u8) ShareDirectoryClient {
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

pub const ShareDirectoryClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    directory_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

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

    pub fn getFileClient(self: *ShareDirectoryClient, file_name: []const u8) ShareFileClient {
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

pub const ShareFileClient = struct {
    endpoint: []const u8,
    share_name: []const u8,
    directory_name: []const u8,
    file_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

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

    const identity = @import("azure_sdk_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var share = ShareClient.init(
        "https://myaccount.file.core.windows.net",
        "myshare",
        cred.asCredential(),
        mock_create.asTransport(),
        .{},
    );

    try share.create(allocator);
    try std.testing.expect(std.mem.find(u8, mock_create.last_url.?, "myshare?restype=share") != null);

    // Create directory and file
    var dir = share.getDirectoryClient("mydir");

    var mock_dir = core.http.MockTransport.init(allocator, 201, "");
    defer mock_dir.deinit();
    dir.pipeline = .{ .policies = &.{}, .transport_impl = mock_dir.asTransport() };
    try dir.create(allocator);

    var file = dir.getFileClient("readme.txt");

    var mock_dl = core.http.MockTransport.init(allocator, 200, "file content here");
    defer mock_dl.deinit();
    file.pipeline = .{ .policies = &.{}, .transport_impl = mock_dl.asTransport() };

    const content = try file.download(allocator);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("file content here", content);
}
