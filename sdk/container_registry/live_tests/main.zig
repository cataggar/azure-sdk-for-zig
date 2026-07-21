//! Destructive, explicit opt-in Azure Container Registry live coverage.
const std = @import("std");
const core = @import("azure_core");
const acr = @import("azure_sdk_container_registry");

const Config = struct {
    endpoint: []const u8,
    repository_prefix: []const u8,
    run_id: []const u8,

    fn fromEnvironment(env: *const std.process.Environ.Map) !?Config {
        const enabled = nonEmpty(env.get("AZURE_CONTAINER_REGISTRY_LIVE_TESTS")) orelse
            return null;
        if (!std.mem.eql(u8, enabled, "1"))
            return error.InvalidContainerRegistryLiveTestOptIn;
        const endpoint = nonEmpty(env.get("AZURE_CONTAINER_REGISTRY_ENDPOINT")) orelse
            return error.ContainerRegistryEndpointRequired;
        if (!std.mem.startsWith(u8, endpoint, "https://") or
            std.mem.endsWith(u8, endpoint, "/"))
        {
            return error.InvalidContainerRegistryEndpoint;
        }
        const run_id = nonEmpty(
            env.get("AZURE_CONTAINER_REGISTRY_LIVE_TEST_RUN_ID"),
        ) orelse return error.ContainerRegistryLiveTestRunIdRequired;
        try validateNameComponent(run_id);
        const prefix = nonEmpty(
            env.get("AZURE_CONTAINER_REGISTRY_LIVE_TEST_REPOSITORY_PREFIX"),
        ) orelse "azure-sdk-for-zig-live";
        try validateRepositoryPrefix(prefix);
        return .{
            .endpoint = endpoint,
            .repository_prefix = prefix,
            .run_id = run_id,
        };
    }
};

const LiveSession = struct {
    allocator: std.mem.Allocator,
    transport: ObservingTransport,
    credential: core.identity.DefaultAzureCredential,

    fn create(
        allocator: std.mem.Allocator,
        io: std.Io,
        env: *const std.process.Environ.Map,
        endpoint: []const u8,
    ) !*LiveSession {
        const self = try allocator.create(LiveSession);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.transport = try ObservingTransport.init(allocator, io, endpoint);
        errdefer self.transport.deinit();
        self.credential = try core.identity.DefaultAzureCredential.init(
            allocator,
            io,
            self.transport.asTransport(),
            env,
        );
        return self;
    }

    fn options(self: *LiveSession) acr.ContainerRegistryClientOptions {
        return .{
            .transport = self.transport.asTransport(),
            .authentication = .{ .credential = self.credential.asCredential() },
        };
    }

    fn deinit(self: *LiveSession) void {
        self.credential.deinit();
        self.transport.deinit();
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

test "live ACR metadata, transfers, non-seekable upload, range resume, redirects, and cleanup" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;
    const repository = try std.fmt.allocPrint(
        allocator,
        "{s}/azure-sdk-for-zig-live-issue-89-{s}",
        .{ config.repository_prefix, config.run_id },
    );
    defer allocator.free(repository);
    const tag = "live";

    const session = try LiveSession.create(
        allocator,
        std.testing.io,
        &env,
        config.endpoint,
    );
    defer session.deinit();
    var metadata = try acr.ContainerRegistryClient.init(
        allocator,
        config.endpoint,
        session.options(),
    );
    defer metadata.deinit();
    var cleanup_needed = true;
    defer if (cleanup_needed) cleanupRepository(&metadata, allocator, repository);

    var content = try acr.ContainerRegistryContentClient.init(
        allocator,
        config.endpoint,
        repository,
        session.options(),
    );
    defer content.deinit();
    var downloads = try acr.BlobDownloadClient.init(
        allocator,
        config.endpoint,
        repository,
        session.options(),
    );
    defer downloads.deinit();

    const config_bytes =
        \\{"architecture":"amd64","os":"linux","rootfs":{"type":"layers","diff_ids":[]},"config":{}}
    ;
    const layer_bytes = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(layer_bytes);
    for (layer_bytes, 0..) |*byte, index| byte.* = @truncate(index *% 31 +% 7);

    var config_blob = try content.uploadBlobBytes(config_bytes, .{
        .chunk_size = 8 * 1024,
    });
    defer config_blob.deinit();
    var non_seekable = NonSeekableReader.init(layer_bytes, 3 * 1024);
    var layer_blob = try content.uploadBlob(&non_seekable.interface, .{
        .chunk_size = 16 * 1024,
    });
    defer layer_blob.deinit();
    try std.testing.expectEqual(@as(u64, layer_bytes.len), layer_blob.size);

    const manifest_bytes = try std.fmt.allocPrint(
        allocator,
        "{{\"schemaVersion\":2,\"mediaType\":\"application/vnd.oci.image.manifest.v1+json\"," ++
            "\"config\":{{\"mediaType\":\"application/vnd.oci.image.config.v1+json\"," ++
            "\"digest\":\"{s}\",\"size\":{d}}},\"layers\":[{{\"mediaType\":" ++
            "\"application/vnd.oci.image.layer.v1.tar\",\"digest\":\"{s}\"," ++
            "\"size\":{d}}}]}}",
        .{
            config_blob.digest,
            config_blob.size,
            layer_blob.digest,
            layer_blob.size,
        },
    );
    defer allocator.free(manifest_bytes);
    var uploaded_manifest = try content.uploadManifest(manifest_bytes, .{
        .reference = tag,
    });
    defer uploaded_manifest.deinit(allocator);

    try expectRepositoryListed(&metadata, allocator, repository);
    try expectTagListed(&metadata, allocator, repository, tag);
    try expectMetadataProperties(
        &metadata,
        allocator,
        repository,
        tag,
        uploaded_manifest.digest,
    );

    var downloaded_manifest = try content.downloadManifest(
        uploaded_manifest.digest,
    );
    defer downloaded_manifest.deinit(allocator);
    try std.testing.expectEqualStrings(
        manifest_bytes,
        downloaded_manifest.bytes,
    );

    session.transport.redirect_count = 0;
    var downloaded_blob = try downloads.downloadBlob(layer_blob.digest, .{
        .max_size = layer_bytes.len,
    });
    defer downloaded_blob.deinit();
    try std.testing.expectEqualSlices(u8, layer_bytes, downloaded_blob.bytes);
    try std.testing.expect(session.transport.redirect_count > 0);

    session.transport.inject_range_failure = true;
    var ranged_output: std.Io.Writer.Allocating = .init(allocator);
    defer ranged_output.deinit();
    var ranged = try downloads.downloadBlobToWriter(
        layer_blob.digest,
        &ranged_output.writer,
        .{ .range_size = 32 * 1024, .max_retries = 3 },
    );
    defer ranged.deinit();
    try std.testing.expectEqualSlices(
        u8,
        layer_bytes,
        ranged_output.writer.buffered(),
    );
    try std.testing.expect(session.transport.range_request_count >= 2);
    try std.testing.expect(session.transport.sawResumedRange());

    var tag_delete = try metadata.deleteTag(allocator, repository, tag);
    defer tag_delete.deinit();
    try expectDeleteAccepted(&tag_delete);
    const manifest_delete = try content.deleteManifest(uploaded_manifest.digest);
    try std.testing.expect(
        manifest_delete == .accepted or manifest_delete == .not_found,
    );
    var repository_delete = try metadata.deleteRepository(allocator, repository);
    defer repository_delete.deinit();
    try expectDeleteAccepted(&repository_delete);
    cleanup_needed = false;
}

fn expectRepositoryListed(
    client: *acr.ContainerRegistryClient,
    allocator: std.mem.Allocator,
    repository: []const u8,
) !void {
    var pager = try client.listRepositories(allocator, .{ .max_results = 100 });
    defer pager.deinit();
    while (try pager.next()) |page_value| {
        var page = page_value;
        defer page.deinit();
        switch (page) {
            .ok => |value| for (value.names) |name| {
                if (std.mem.eql(u8, name, repository)) return;
            },
            .err => return error.ContainerRegistryLiveMetadataFailed,
        }
    }
    return error.ContainerRegistryLiveRepositoryNotListed;
}

fn expectTagListed(
    client: *acr.ContainerRegistryClient,
    allocator: std.mem.Allocator,
    repository: []const u8,
    tag: []const u8,
) !void {
    var pager = try client.listTagProperties(allocator, repository, .{});
    defer pager.deinit();
    while (try pager.next()) |page_value| {
        var page = page_value;
        defer page.deinit();
        switch (page) {
            .ok => |value| for (value.items) |item| {
                if (std.mem.eql(u8, item.name, tag)) return;
            },
            .err => return error.ContainerRegistryLiveMetadataFailed,
        }
    }
    return error.ContainerRegistryLiveTagNotListed;
}

fn expectMetadataProperties(
    client: *acr.ContainerRegistryClient,
    allocator: std.mem.Allocator,
    repository: []const u8,
    tag: []const u8,
    digest: []const u8,
) !void {
    var repository_result = try client.getRepositoryProperties(
        allocator,
        repository,
    );
    defer repository_result.deinit();
    switch (repository_result) {
        .ok => |value| try std.testing.expectEqualStrings(repository, value.name),
        .err => return error.ContainerRegistryLiveRepositoryPropertiesFailed,
    }
    var updated_repository = try client.updateRepositoryProperties(
        allocator,
        repository,
        .{
            .can_delete = true,
            .can_write = true,
            .can_list = true,
            .can_read = true,
        },
    );
    defer updated_repository.deinit();
    switch (updated_repository) {
        .ok => |value| try std.testing.expectEqual(true, value.can_read.?),
        .err => return error.ContainerRegistryLiveRepositoryUpdateFailed,
    }

    var tag_result = try client.getTagProperties(allocator, repository, tag);
    defer tag_result.deinit();
    switch (tag_result) {
        .ok => |value| try std.testing.expectEqualStrings(digest, value.digest),
        .err => return error.ContainerRegistryLiveTagPropertiesFailed,
    }
    var updated_tag = try client.updateTagProperties(
        allocator,
        repository,
        tag,
        .{
            .can_delete = true,
            .can_write = true,
            .can_list = true,
            .can_read = true,
        },
    );
    defer updated_tag.deinit();
    switch (updated_tag) {
        .ok => |value| try std.testing.expectEqual(true, value.can_read.?),
        .err => return error.ContainerRegistryLiveTagUpdateFailed,
    }

    var manifest_result = try client.getManifestProperties(
        allocator,
        repository,
        digest,
    );
    defer manifest_result.deinit();
    switch (manifest_result) {
        .ok => |value| try std.testing.expectEqualStrings(digest, value.digest),
        .err => return error.ContainerRegistryLiveManifestPropertiesFailed,
    }

    var updated = try client.updateManifestProperties(
        allocator,
        repository,
        digest,
        .{
            .can_delete = true,
            .can_write = true,
            .can_list = true,
            .can_read = true,
        },
    );
    defer updated.deinit();
    switch (updated) {
        .ok => |value| try std.testing.expectEqual(true, value.can_read.?),
        .err => return error.ContainerRegistryLiveManifestUpdateFailed,
    }
}

fn expectDeleteAccepted(result: *acr.DeleteResult) !void {
    switch (result.*) {
        .ok => |outcome| try std.testing.expect(
            outcome == .accepted or outcome == .not_found,
        ),
        .err => return error.ContainerRegistryLiveDeleteFailed,
    }
}

fn cleanupRepository(
    client: *acr.ContainerRegistryClient,
    allocator: std.mem.Allocator,
    repository: []const u8,
) void {
    var result = client.deleteRepository(allocator, repository) catch |err| {
        std.log.err("ACR live cleanup failed: {s}", .{@errorName(err)});
        return;
    };
    switch (result) {
        .ok => {},
        .err => |failure| std.log.err(
            "ACR live cleanup service failure: {f}",
            .{failure},
        ),
    }
    result.deinit();
}

const NonSeekableReader = struct {
    interface: std.Io.Reader,
    bytes: []const u8,
    offset: usize = 0,
    max_per_read: usize,

    fn init(bytes: []const u8, max_per_read: usize) NonSeekableReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .bytes = bytes,
            .max_per_read = max_per_read,
        };
    }

    fn stream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *NonSeekableReader =
            @alignCast(@fieldParentPtr("interface", reader));
        if (self.offset == self.bytes.len) return error.EndOfStream;
        const count = @min(
            self.bytes.len - self.offset,
            @min(self.max_per_read, limit.minInt(std.math.maxInt(usize))),
        );
        try writer.writeAll(self.bytes[self.offset .. self.offset + count]);
        self.offset += count;
        return count;
    }
};

const ObservingTransport = struct {
    allocator: std.mem.Allocator,
    endpoint: []u8,
    standard: core.http.StdHttpTransport,
    transport: core.http.HttpTransport,
    redirect_count: usize = 0,
    inject_range_failure: bool = false,
    range_failure_injected: bool = false,
    range_starts: [16]u64 = undefined,
    range_request_count: usize = 0,

    fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        endpoint: []const u8,
    ) !ObservingTransport {
        return .{
            .allocator = allocator,
            .endpoint = try allocator.dupe(u8, endpoint),
            .standard = core.http.StdHttpTransport.init(allocator, io),
            .transport = .{ .sendFn = &send, .openFn = &open },
        };
    }

    fn asTransport(self: *ObservingTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn deinit(self: *ObservingTransport) void {
        self.standard.deinit();
        self.allocator.free(self.endpoint);
        self.* = undefined;
    }

    fn sawResumedRange(self: *const ObservingTransport) bool {
        for (self.range_starts[0..self.range_request_count]) |start| {
            if (start > 0) return true;
        }
        return false;
    }

    fn send(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *ObservingTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        const base = self.standard.asTransport();
        return base.sendFn(base, request);
    }

    fn open(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *ObservingTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        const range = request.getHeader("Range");
        if (range != null and self.isRegistryUrl(request.url) and
            self.range_request_count < self.range_starts.len)
        {
            self.range_starts[self.range_request_count] = try rangeStart(range.?);
            self.range_request_count += 1;
        }
        const base = self.standard.asTransport();
        const operation = try base.openFn.?(base, request, options);
        if (operation.status_code == 307 and self.isRegistryUrl(request.url))
            self.redirect_count += 1;
        if (self.inject_range_failure and !self.range_failure_injected and
            range != null and operation.status_code == 206)
        {
            self.range_failure_injected = true;
            return FaultOperation.create(self.allocator, operation, 8 * 1024);
        }
        return operation;
    }

    fn isRegistryUrl(self: *const ObservingTransport, url: []const u8) bool {
        return std.mem.startsWith(u8, url, self.endpoint) and
            (url.len == self.endpoint.len or url[self.endpoint.len] == '/');
    }
};

const FaultOperation = struct {
    allocator: std.mem.Allocator,
    operation: core.http.HttpOperation,
    inner: *core.http.HttpOperation,
    reader: FaultReader,

    fn create(
        allocator: std.mem.Allocator,
        inner: *core.http.HttpOperation,
        fail_after: usize,
    ) !*core.http.HttpOperation {
        const self = try allocator.create(FaultOperation);
        self.* = .{
            .allocator = allocator,
            .operation = undefined,
            .inner = inner,
            .reader = FaultReader.init(inner.body_reader, fail_after),
        };
        self.operation = .{
            .status_code = inner.status_code,
            .headers = inner.headers,
            .response_headers = inner.response_headers,
            .body_reader = &self.reader.interface,
            .finishFn = &finish,
            .abortFn = &abort,
            .cancelFn = &cancel,
            .deinitFn = &deinit,
            .bodyErrorFn = &bodyError,
        };
        inner.headers = std.StringHashMap([]const u8).init(allocator);
        inner.response_headers = .{};
        return &self.operation;
    }

    fn finish(operation: *core.http.HttpOperation) !void {
        const self: *FaultOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        try self.inner.finish();
    }

    fn abort(operation: *core.http.HttpOperation) void {
        const self: *FaultOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.inner.abort();
    }

    fn cancel(operation: *core.http.HttpOperation) void {
        const self: *FaultOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.inner.cancel();
    }

    fn bodyError(operation: *const core.http.HttpOperation) ?anyerror {
        const self: *const FaultOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        if (self.reader.failed) return error.ConnectionResetByPeer;
        return self.inner.bodyError();
    }

    fn deinit(operation: *core.http.HttpOperation) void {
        const self: *FaultOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.operation.response_headers.deinit();
        var iterator = self.operation.headers.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.operation.headers.deinit();
        self.inner.deinit();
        self.allocator.destroy(self);
    }
};

const FaultReader = struct {
    interface: std.Io.Reader,
    source: *std.Io.Reader,
    remaining: usize,
    failed: bool = false,

    fn init(source: *std.Io.Reader, fail_after: usize) FaultReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .source = source,
            .remaining = fail_after,
        };
    }

    fn stream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *FaultReader =
            @alignCast(@fieldParentPtr("interface", reader));
        if (self.remaining == 0) {
            self.failed = true;
            return error.ReadFailed;
        }
        var buffer: [16 * 1024]u8 = undefined;
        const count = self.source.readSliceShort(buffer[0..@min(
            self.remaining,
            limit.minInt(buffer.len),
        )]) catch {
            self.failed = true;
            return error.ReadFailed;
        };
        if (count == 0) return error.EndOfStream;
        try writer.writeAll(buffer[0..count]);
        self.remaining -= count;
        return count;
    }
};

fn rangeStart(value: []const u8) !u64 {
    if (!std.mem.startsWith(u8, value, "bytes="))
        return error.InvalidLiveTestRange;
    const dash = std.mem.indexOfScalar(u8, value, '-') orelse
        return error.InvalidLiveTestRange;
    return std.fmt.parseInt(u64, value["bytes=".len..dash], 10);
}

fn validateNameComponent(value: []const u8) !void {
    if (value.len == 0 or value.len > 40) return error.InvalidLiveTestRunId;
    for (value) |byte| {
        if (!(std.ascii.isLower(byte) or std.ascii.isDigit(byte) or byte == '-'))
            return error.InvalidLiveTestRunId;
    }
}

fn validateRepositoryPrefix(value: []const u8) !void {
    if (value.len == 0 or value.len > 120)
        return error.InvalidLiveTestRepositoryPrefix;
    for (value) |byte| {
        if (!(std.ascii.isLower(byte) or std.ascii.isDigit(byte) or
            byte == '-' or byte == '_' or byte == '.' or byte == '/'))
        {
            return error.InvalidLiveTestRepositoryPrefix;
        }
    }
}

fn nonEmpty(value: ?[]const u8) ?[]const u8 {
    const present = value orelse return null;
    return if (present.len == 0) null else present;
}
