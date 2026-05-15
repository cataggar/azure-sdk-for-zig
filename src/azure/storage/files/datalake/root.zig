const std = @import("std");
const core = @import("azure_core");

// ──────────────── DataLakeFileSystemClient ────────────────────

pub const DataLakeFileSystemClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

pub const DataLakeFileSystemClient = struct {
    endpoint: []const u8,
    filesystem_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        filesystem_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: DataLakeFileSystemClientOptions,
    ) DataLakeFileSystemClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .filesystem_name = filesystem_name,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// PUT /filesystem?resource=filesystem
    pub fn create(self: *DataLakeFileSystemClient, allocator: std.mem.Allocator) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?resource=filesystem",
            .{ self.endpoint, self.filesystem_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.CreateFileSystemFailed;
        }
    }

    /// DELETE /filesystem?resource=filesystem
    pub fn deleteFileSystem(self: *DataLakeFileSystemClient, allocator: std.mem.Allocator) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?resource=filesystem",
            .{ self.endpoint, self.filesystem_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.DeleteFileSystemFailed;
        }
    }

    pub fn getFileClient(self: *DataLakeFileSystemClient, file_path: []const u8) DataLakeFileClient {
        return .{
            .endpoint = self.endpoint,
            .filesystem_name = self.filesystem_name,
            .file_path = file_path,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ──────────────────── DataLakeFileClient ──────────────────────

pub const DataLakeFileClient = struct {
    endpoint: []const u8,
    filesystem_name: []const u8,
    file_path: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    /// PUT /filesystem/path?resource=file
    pub fn create(self: *DataLakeFileClient, allocator: std.mem.Allocator) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}?resource=file",
            .{ self.endpoint, self.filesystem_name, self.file_path },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.CreateFileFailed;
        }
    }

    /// PATCH /filesystem/path?action=append&position={pos}
    pub fn append(self: *DataLakeFileClient, allocator: std.mem.Allocator, data: []const u8, position: u64) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}?action=append&position={d}",
            .{ self.endpoint, self.filesystem_name, self.file_path, position },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/octet-stream");
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.AppendFailed;
        }
    }

    /// PATCH /filesystem/path?action=flush&position={pos}
    pub fn flush(self: *DataLakeFileClient, allocator: std.mem.Allocator, position: u64) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}?action=flush&position={d}",
            .{ self.endpoint, self.filesystem_name, self.file_path, position },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PATCH, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.FlushFailed;
        }
    }

    /// GET /filesystem/path
    pub fn read(self: *DataLakeFileClient, allocator: std.mem.Allocator) ![]const u8 {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}",
            .{ self.endpoint, self.filesystem_name, self.file_path },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.ReadFailed;
        }

        return allocator.dupe(u8, resp.body);
    }

    /// DELETE /filesystem/path
    pub fn deleteFile(self: *DataLakeFileClient, allocator: std.mem.Allocator) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}",
            .{ self.endpoint, self.filesystem_name, self.file_path },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.DeleteFileFailed;
        }
    }
};

// ─────────────────────────── Tests ────────────────────────────

test "DataLakeFileClient create append flush and read" {
    const allocator = std.testing.allocator;
    var mock_create = core.http.MockTransport.init(allocator, 201, "");
    defer mock_create.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var fs_client = DataLakeFileSystemClient.init(
        "https://myaccount.dfs.core.windows.net",
        "myfilesystem",
        cred.asCredential(),
        mock_create.asTransport(),
        .{},
    );

    try fs_client.create(allocator);
    try std.testing.expect(std.mem.find(u8, mock_create.last_url.?, "myfilesystem?resource=filesystem") != null);

    var file = fs_client.getFileClient("data/myfile.csv");

    // Create file
    var mock_file = core.http.MockTransport.init(allocator, 201, "");
    defer mock_file.deinit();
    file.pipeline = .{ .policies = &.{}, .transport_impl = mock_file.asTransport() };
    try file.create(allocator);
    try std.testing.expect(std.mem.find(u8, mock_file.last_url.?, "data/myfile.csv?resource=file") != null);

    // Append data
    var mock_append = core.http.MockTransport.init(allocator, 202, "");
    defer mock_append.deinit();
    file.pipeline = .{ .policies = &.{}, .transport_impl = mock_append.asTransport() };
    try file.append(allocator, "col1,col2\na,b\n", 0);
    try std.testing.expect(std.mem.find(u8, mock_append.last_url.?, "action=append&position=0") != null);

    // Read
    var mock_read = core.http.MockTransport.init(allocator, 200, "col1,col2\na,b\n");
    defer mock_read.deinit();
    file.pipeline = .{ .policies = &.{}, .transport_impl = mock_read.asTransport() };

    const content = try file.read(allocator);
    defer allocator.free(content);
    try std.testing.expectEqualStrings("col1,col2\na,b\n", content);
}
