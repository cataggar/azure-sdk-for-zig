const std = @import("std");
const core = @import("azure_sdk_core");
const digest_mod = @import("digest.zig");
const content_client = @import("content_client.zig");
const upload_mod = @import("blob_upload.zig");

const BlobUploadOptions = upload_mod.BlobUploadOptions;
const BlobUploadResponse = upload_mod.BlobUploadResponse;
const BlobUploadResult = upload_mod.BlobUploadResult;
const UploadContext = upload_mod.UploadContext;
const max_chunk_size = upload_mod.max_chunk_size;
const upload = upload_mod.upload;

const TestHeader = struct {
    name: []const u8,
    value: []const u8,
};

const TestAction = union(enum) {
    response: struct {
        status: u16,
        headers: []const TestHeader = &.{},
        body: []const u8 = "",
    },
    fail: struct {
        after_bytes: usize = 0,
        cause: anyerror = error.InjectedTransportFailure,
        cancel: bool = false,
    },
};

const TestCapture = struct {
    method: core.http.Method = .GET,
    url: [1024]u8 = undefined,
    url_len: usize = 0,
    body: [256]u8 = undefined,
    body_len: usize = 0,
    content_range: [64]u8 = undefined,
    content_range_len: usize = 0,
    content_length: [32]u8 = undefined,
    content_length_len: usize = 0,

    fn urlSlice(self: *const TestCapture) []const u8 {
        return self.url[0..self.url_len];
    }

    fn bodySlice(self: *const TestCapture) []const u8 {
        return self.body[0..@min(self.body_len, self.body.len)];
    }

    fn contentRange(self: *const TestCapture) ?[]const u8 {
        if (self.content_range_len == 0) return null;
        return self.content_range[0..self.content_range_len];
    }

    fn contentLength(self: *const TestCapture) ?[]const u8 {
        if (self.content_length_len == 0) return null;
        return self.content_length[0..self.content_length_len];
    }
};

const ScriptedTransport = struct {
    allocator: std.mem.Allocator,
    actions: []const TestAction,
    transport: core.http.HttpTransport,
    call_count: usize = 0,
    captures: [64]TestCapture = [_]TestCapture{.{}} ** 64,
    finish_count: usize = 0,
    abort_count: usize = 0,
    deinit_count: usize = 0,
    cancellation: ?*core.http.CancellationToken = null,

    fn init(
        allocator: std.mem.Allocator,
        actions: []const TestAction,
    ) ScriptedTransport {
        return .{
            .allocator = allocator,
            .actions = actions,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
        };
    }

    fn asTransport(self: *ScriptedTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(
        _: *core.http.HttpTransport,
        _: *core.http.Request,
    ) !core.http.Response {
        return error.UnexpectedBufferedSend;
    }

    fn openImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *ScriptedTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        if (self.call_count >= self.actions.len)
            return error.NoScriptedResponse;
        if (self.call_count >= self.captures.len)
            return error.TooManyTestRequests;
        const action = self.actions[self.call_count];
        const capture = &self.captures[self.call_count];
        self.call_count += 1;
        try captureRequest(capture, request);

        var body_length: usize = 0;
        if (options.body) |body| {
            var scratch: [13]u8 = undefined;
            while (true) {
                const count = try body.reader.readSliceShort(&scratch);
                if (count == 0) break;
                const copy_start = @min(body_length, capture.body.len);
                const copy_end = @min(body_length + count, capture.body.len);
                if (copy_end > copy_start) {
                    @memcpy(
                        capture.body[copy_start..copy_end],
                        scratch[0 .. copy_end - copy_start],
                    );
                }
                body_length += count;
                if (action == .fail and
                    body_length >= action.fail.after_bytes)
                {
                    capture.body_len = body_length;
                    if (action.fail.cancel) {
                        if (self.cancellation) |token| token.cancel();
                    }
                    return action.fail.cause;
                }
            }
        }
        capture.body_len = body_length;

        return switch (action) {
            .fail => |failure| blk: {
                if (failure.cancel) {
                    if (self.cancellation) |token| token.cancel();
                }
                break :blk failure.cause;
            },
            .response => |response| TestOperation.create(
                self,
                response.status,
                response.headers,
                response.body,
            ),
        };
    }

    fn captureRequest(
        capture: *TestCapture,
        request: *const core.http.Request,
    ) !void {
        if (request.url.len > capture.url.len) return error.TestUrlTooLong;
        capture.method = request.method;
        @memcpy(capture.url[0..request.url.len], request.url);
        capture.url_len = request.url.len;
        if (request.getHeader("Content-Range")) |value| {
            if (value.len > capture.content_range.len)
                return error.TestHeaderTooLong;
            @memcpy(capture.content_range[0..value.len], value);
            capture.content_range_len = value.len;
        }
        if (request.getHeader("Content-Length")) |value| {
            if (value.len > capture.content_length.len)
                return error.TestHeaderTooLong;
            @memcpy(capture.content_length[0..value.len], value);
            capture.content_length_len = value.len;
        }
    }
};

const TestOperation = struct {
    operation: core.http.HttpOperation,
    owner: *ScriptedTransport,
    allocator: std.mem.Allocator,
    body: []u8,
    reader: std.Io.Reader,

    fn create(
        owner: *ScriptedTransport,
        status: u16,
        headers: []const TestHeader,
        body_value: []const u8,
    ) !*core.http.HttpOperation {
        const self = try owner.allocator.create(TestOperation);
        errdefer owner.allocator.destroy(self);
        const body = try owner.allocator.dupe(u8, body_value);
        errdefer owner.allocator.free(body);
        var header_map = std.StringHashMap([]const u8).init(owner.allocator);
        errdefer deinitTestHeaderMap(owner.allocator, &header_map);
        var response_headers = core.http.ResponseHeaders.init(owner.allocator);
        errdefer response_headers.deinit();
        for (headers) |header| {
            try response_headers.append(header.name, header.value);
            const name = try owner.allocator.dupe(u8, header.name);
            errdefer owner.allocator.free(name);
            const value = try owner.allocator.dupe(u8, header.value);
            errdefer owner.allocator.free(value);
            const entry = try header_map.getOrPut(name);
            if (entry.found_existing) {
                owner.allocator.free(name);
                owner.allocator.free(entry.value_ptr.*);
            } else {
                entry.key_ptr.* = name;
            }
            entry.value_ptr.* = value;
        }
        self.* = .{
            .operation = undefined,
            .owner = owner,
            .allocator = owner.allocator,
            .body = body,
            .reader = std.Io.Reader.fixed(body),
        };
        self.operation = .{
            .status_code = status,
            .headers = header_map,
            .response_headers = response_headers,
            .body_reader = &self.reader,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &abortImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *TestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.finish_count += 1;
        _ = try self.reader.discardRemaining();
    }

    fn abortImpl(operation: *core.http.HttpOperation) void {
        const self: *TestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.abort_count += 1;
    }

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *TestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.deinit_count += 1;
        self.operation.response_headers.deinit();
        deinitTestHeaderMap(self.allocator, &self.operation.headers);
        self.allocator.free(self.body);
        self.allocator.destroy(self);
    }
};

fn deinitTestHeaderMap(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
) void {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    headers.deinit();
}

fn testUpload(
    allocator: std.mem.Allocator,
    transport: *ScriptedTransport,
    reader: *std.Io.Reader,
    options: BlobUploadOptions,
) !BlobUploadResponse {
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    return upload(.{
        .allocator = allocator,
        .pipeline = &pipeline,
        .endpoint = "https://registry.example",
        .api_version = "2021-07-01",
        .repository_name = "team/app",
    }, reader, options);
}

fn expectUpload(
    allocator: std.mem.Allocator,
    transport: *ScriptedTransport,
    bytes: []const u8,
    options: BlobUploadOptions,
) !BlobUploadResult {
    var reader = std.Io.Reader.fixed(bytes);
    var response = try testUpload(allocator, transport, &reader, options);
    return switch (response) {
        .ok => |result| result,
        .err => |*failure| {
            defer failure.deinit();
            return error.UnexpectedServiceError;
        },
    };
}

fn successHeaders(
    comptime location: []const u8,
    comptime range: []const u8,
    comptime uuid: []const u8,
) []const TestHeader {
    return &.{
        .{ .name = "Location", .value = location },
        .{ .name = "Range", .value = range },
        .{ .name = "Docker-Upload-UUID", .value = uuid },
    };
}

fn completionHeaders(
    comptime location: []const u8,
    comptime range: []const u8,
    digest: []const u8,
) [3]TestHeader {
    return .{
        .{ .name = "Location", .value = location },
        .{ .name = "Range", .value = range },
        .{ .name = "Docker-Content-Digest", .value = digest },
    };
}

test "blob upload accepts empty content" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("");
    const complete_headers = completionHeaders(
        "/v2/team/app/blobs/empty",
        "0-0",
        &digest,
    );
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders(
                "/v2/team/app/blobs/uploads/id?_state=start",
                "bytes=0-0",
                "id",
            ),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, "", .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u64, 0), result.size);
    try std.testing.expectEqualStrings(&digest, result.digest);
    try std.testing.expectEqual(core.http.Method.PUT, transport.captures[1].method);
    try std.testing.expectEqualStrings("0", transport.captures[1].contentLength().?);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.captures[1].urlSlice(), "digest=sha256%3A") != null,
    );
    try std.testing.expectEqual(@as(usize, 2), transport.finish_count);
    try std.testing.expectEqual(transport.call_count, transport.deinit_count);
}

test "content client exposes high-level blob upload" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("public");
    const complete_headers = completionHeaders("/blob/final", "0-5", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-5", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var client = try content_client.ContainerRegistryContentClient.init(
        allocator,
        "https://registry.example",
        "team/app",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();

    var result = try client.uploadBlobBytes("public", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings(&digest, result.digest);
    try std.testing.expectEqual(@as(u64, 6), result.size);
}

test "blob upload sends one exact ranged chunk" {
    const allocator = std.testing.allocator;
    const bytes = "hello";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders(
        "/v2/team/app/blobs/final",
        "0-4",
        &digest,
    );
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?_state=a", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?_state=b", "bytes=0-4", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, bytes, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("0-4", transport.captures[1].contentRange().?);
    try std.testing.expectEqualStrings("5", transport.captures[1].contentLength().?);
    try std.testing.expectEqualStrings(bytes, transport.captures[1].bodySlice());
    try std.testing.expect(
        std.mem.indexOf(u8, transport.captures[1].urlSlice(), "_state=a") != null,
    );
}

test "blob upload sends sequential multiple chunks" {
    const allocator = std.testing.allocator;
    const bytes = "abcdefghij";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-9", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?s=0", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?s=1", "0-3", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?s=2", "0-7", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?s=3", "0-9", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(
        allocator,
        &transport,
        bytes,
        .{ .chunk_size = 4 },
    );
    defer result.deinit();

    try std.testing.expectEqualStrings("0-3", transport.captures[1].contentRange().?);
    try std.testing.expectEqualStrings("4-7", transport.captures[2].contentRange().?);
    try std.testing.expectEqualStrings("8-9", transport.captures[3].contentRange().?);
    try std.testing.expectEqualStrings("abcd", transport.captures[1].bodySlice());
    try std.testing.expectEqualStrings("efgh", transport.captures[2].bodySlice());
    try std.testing.expectEqualStrings("ij", transport.captures[3].bodySlice());
}

test "blob upload exact chunk boundary does not send an empty patch" {
    const allocator = std.testing.allocator;
    const bytes = "abcdefgh";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-7", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-3", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-7", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(
        allocator,
        &transport,
        bytes,
        .{ .chunk_size = 4 },
    );
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqual(core.http.Method.PUT, transport.captures[3].method);
}

const PartialReader = struct {
    interface: std.Io.Reader,
    bytes: []const u8,
    offset: usize = 0,
    max_per_read: usize,
    max_requested: usize = 0,

    fn init(bytes: []const u8, max_per_read: usize) PartialReader {
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
        const self: *PartialReader =
            @alignCast(@fieldParentPtr("interface", reader));
        const requested = limit.minInt(std.math.maxInt(usize));
        self.max_requested = @max(self.max_requested, requested);
        if (self.offset == self.bytes.len) return error.EndOfStream;
        const count = @min(
            self.bytes.len - self.offset,
            @min(self.max_per_read, requested),
        );
        try writer.writeAll(self.bytes[self.offset .. self.offset + count]);
        self.offset += count;
        return count;
    }
};

test "blob upload supports non-seekable partial readers" {
    const allocator = std.testing.allocator;
    const bytes = "partial-reader";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-13", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-4", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-9", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-13", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var source = PartialReader.init(bytes, 2);
    var transport = ScriptedTransport.init(allocator, &actions);
    var response = try testUpload(
        allocator,
        &transport,
        &source.interface,
        .{ .chunk_size = 5 },
    );
    defer response.deinit();

    try std.testing.expect(response == .ok);
    try std.testing.expect(source.max_requested <= 5);
    try std.testing.expectEqual(bytes.len, source.offset);
}

const FailBeforeTransportPolicy = struct {
    policy: core.pipeline.HttpPolicy,
    remaining_failures: usize,
    failure_count: usize = 0,

    fn init(failures: usize) FailBeforeTransportPolicy {
        return .{
            .policy = .{
                .processFn = &processImpl,
                .prepareFn = &prepareImpl,
                .openFn = &openImpl,
            },
            .remaining_failures = failures,
        };
    }

    fn asPolicy(self: *FailBeforeTransportPolicy) *core.pipeline.HttpPolicy {
        return &self.policy;
    }

    fn prepareImpl(_: *core.pipeline.HttpPolicy, _: *core.http.Request) !void {}

    fn processImpl(
        _: *core.pipeline.HttpPolicy,
        request: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) !core.http.Response {
        if (next.len == 0) return transport.send(request);
        return next[0].process(request, next[1..], transport);
    }

    fn openImpl(
        policy: *core.pipeline.HttpPolicy,
        request: *core.http.Request,
        options: core.http.OpenOptions,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) !*core.http.HttpOperation {
        const self: *FailBeforeTransportPolicy =
            @alignCast(@fieldParentPtr("policy", policy));
        if (request.method == .PATCH and self.remaining_failures > 0) {
            self.remaining_failures -= 1;
            self.failure_count += 1;
            return error.InjectedPreTransportFailure;
        }
        if (next.len == 0) return transport.open(request, options);
        return next[0].open(request, options, next[1..], transport);
    }
};

test "blob upload retries failures before transport starts" {
    const allocator = std.testing.allocator;
    const bytes = "retry";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-4", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-4", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var failure_policy = FailBeforeTransportPolicy.init(1);
    var policies = [_]*core.pipeline.HttpPolicy{failure_policy.asPolicy()};
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &policies,
        .transport_impl = transport.asTransport(),
    };
    var reader = std.Io.Reader.fixed(bytes);
    var response = try upload(.{
        .allocator = allocator,
        .pipeline = &pipeline,
        .endpoint = "https://registry.example",
        .api_version = "2021-07-01",
        .repository_name = "team/app",
    }, &reader, .{});
    defer response.deinit();

    try std.testing.expect(response == .ok);
    try std.testing.expectEqual(@as(usize, 1), failure_policy.failure_count);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqual(core.http.Method.PATCH, transport.captures[1].method);
}

test "blob upload recovers a fully accepted uncertain chunk" {
    const allocator = std.testing.allocator;
    const bytes = "recover";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-6", &digest);
    const status_headers = [_]TestHeader{
        .{ .name = "Range", .value = "bytes=0-6" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
        .{ .name = "Location", .value = "/upload/id?_state=recovered" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?_state=start", "0-0", "id"),
        } },
        .{ .fail = .{ .after_bytes = bytes.len } },
        .{ .response = .{ .status = 204, .headers = &status_headers } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, bytes, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqual(core.http.Method.GET, transport.captures[2].method);
    try std.testing.expectEqual(core.http.Method.PUT, transport.captures[3].method);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.captures[3].urlSlice(), "_state=recovered") != null,
    );
}

test "blob upload resumes the confirmed suffix after uncertain transport" {
    const allocator = std.testing.allocator;
    const bytes = "abcdef";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-5", &digest);
    const status_headers = [_]TestHeader{
        .{ .name = "Range", .value = "0-1" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .fail = .{ .after_bytes = 2 } },
        .{ .response = .{ .status = 204, .headers = &status_headers } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-5", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(
        allocator,
        &transport,
        bytes,
        .{ .chunk_size = 6 },
    );
    defer result.deinit();

    try std.testing.expectEqualStrings("2-5", transport.captures[3].contentRange().?);
    try std.testing.expectEqualStrings("cdef", transport.captures[3].bodySlice());
    try std.testing.expectEqualStrings(&digest, result.digest);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.captures[4].urlSlice(), "digest=sha256%3A") != null,
    );
}

test "blob upload restores digest and chunk cursor before retry" {
    const allocator = std.testing.allocator;
    const bytes = "abcdefgh";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-7", &digest);
    const status_headers = [_]TestHeader{
        .{ .name = "Range", .value = "0-3" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-3", "id"),
        } },
        .{ .fail = .{ .after_bytes = 4 } },
        .{ .response = .{ .status = 204, .headers = &status_headers } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-7", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(
        allocator,
        &transport,
        bytes,
        .{ .chunk_size = 4 },
    );
    defer result.deinit();

    try std.testing.expectEqualStrings("4-7", transport.captures[2].contentRange().?);
    try std.testing.expectEqualStrings("4-7", transport.captures[4].contentRange().?);
    try std.testing.expectEqualStrings("efgh", transport.captures[4].bodySlice());
    try std.testing.expectEqualStrings(&digest, result.digest);
}

test "blob upload rejects server offset divergence" {
    const allocator = std.testing.allocator;
    const bytes = "abcdefgh";
    const status_headers = [_]TestHeader{
        .{ .name = "Range", .value = "0-8" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-3", "id"),
        } },
        .{ .fail = .{ .after_bytes = 4 } },
        .{ .response = .{ .status = 204, .headers = &status_headers } },
        .{ .response = .{ .status = 204 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var reader = std.Io.Reader.fixed(bytes);
    try std.testing.expectError(
        error.ServerUploadOffsetDiverged,
        testUpload(
            allocator,
            &transport,
            &reader,
            .{ .chunk_size = 4 },
        ),
    );
    try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[4].method);
}

test "blob upload rejects malformed ranges and changed upload UUIDs" {
    const allocator = std.testing.allocator;
    const cases = [_]struct {
        range: []const u8,
        uuid: []const u8,
        expected: anyerror,
    }{
        .{ .range = "1-4", .uuid = "id", .expected = error.InvalidUploadRange },
        .{ .range = "0-four", .uuid = "id", .expected = error.InvalidUploadRange },
        .{ .range = "0-3", .uuid = "other", .expected = error.UploadUuidChanged },
    };
    for (cases) |case| {
        const response_headers = [_]TestHeader{
            .{ .name = "Location", .value = "/upload/id" },
            .{ .name = "Range", .value = case.range },
            .{ .name = "Docker-Upload-UUID", .value = case.uuid },
        };
        const actions = [_]TestAction{
            .{ .response = .{
                .status = 202,
                .headers = successHeaders("/upload/id", "0-0", "id"),
            } },
            .{ .response = .{ .status = 202, .headers = &response_headers } },
            .{ .response = .{ .status = 204 } },
        };
        var transport = ScriptedTransport.init(allocator, &actions);
        var reader = std.Io.Reader.fixed("data");
        try std.testing.expectError(
            case.expected,
            testUpload(allocator, &transport, &reader, .{}),
        );
        try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[2].method);
    }
}

test "blob upload validates every continuation Location origin" {
    const allocator = std.testing.allocator;
    const invalid_locations = [_]struct {
        value: []const u8,
        expected: anyerror,
    }{
        .{ .value = "http://registry.example/upload/id", .expected = error.HttpsRequired },
        .{ .value = "https://evil.example/upload/id", .expected = error.UntrustedUploadLocation },
        .{ .value = "https://registry.example:444/upload/id", .expected = error.UntrustedUploadLocation },
        .{ .value = "https://user@registry.example/upload/id", .expected = error.InvalidUrl },
        .{ .value = "https://registry.example/upload/id#fragment", .expected = error.InvalidUrl },
    };
    for (invalid_locations) |invalid| {
        const start_headers = [_]TestHeader{
            .{ .name = "Location", .value = invalid.value },
            .{ .name = "Range", .value = "0-0" },
            .{ .name = "Docker-Upload-UUID", .value = "id" },
        };
        const actions = [_]TestAction{
            .{ .response = .{ .status = 202, .headers = &start_headers } },
        };
        var transport = ScriptedTransport.init(allocator, &actions);
        var reader = std.Io.Reader.fixed("");
        try std.testing.expectError(
            invalid.expected,
            testUpload(allocator, &transport, &reader, .{}),
        );
    }
}

test "blob upload origin comparison includes effective HTTPS port" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("");
    const complete_headers = completionHeaders(
        "https://REGISTRY.example:8443/blob/final",
        "0-0",
        &digest,
    );
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders(
                "https://registry.example:8443/upload/id",
                "0-0",
                "id",
            ),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var reader = std.Io.Reader.fixed("");
    var response = try upload(.{
        .allocator = allocator,
        .pipeline = &pipeline,
        .endpoint = "https://registry.example:8443",
        .api_version = "2021-07-01",
        .repository_name = "team/app",
    }, &reader, .{});
    defer response.deinit();
    try std.testing.expect(response == .ok);

    const wrong_port_headers = [_]TestHeader{
        .{ .name = "Location", .value = "https://registry.example/upload/id" },
        .{ .name = "Range", .value = "0-0" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const wrong_actions = [_]TestAction{
        .{ .response = .{ .status = 202, .headers = &wrong_port_headers } },
    };
    var wrong_transport = ScriptedTransport.init(allocator, &wrong_actions);
    var wrong_pipeline = core.pipeline.HttpPipeline{
        .policies = &.{},
        .transport_impl = wrong_transport.asTransport(),
    };
    var wrong_reader = std.Io.Reader.fixed("");
    try std.testing.expectError(
        error.UntrustedUploadLocation,
        upload(.{
            .allocator = allocator,
            .pipeline = &wrong_pipeline,
            .endpoint = "https://registry.example:8443",
            .api_version = "2021-07-01",
            .repository_name = "team/app",
        }, &wrong_reader, .{}),
    );
}

test "blob upload recovers uncertain completion through upload status" {
    const allocator = std.testing.allocator;
    const bytes = "done";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-3", &digest);
    const status_headers = [_]TestHeader{
        .{ .name = "Range", .value = "0-3" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-3", "id"),
        } },
        .{ .fail = .{} },
        .{ .response = .{ .status = 204, .headers = &status_headers } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, bytes, .{});
    defer result.deinit();

    try std.testing.expectEqual(core.http.Method.PUT, transport.captures[2].method);
    try std.testing.expectEqual(core.http.Method.GET, transport.captures[3].method);
    try std.testing.expectEqual(core.http.Method.PUT, transport.captures[4].method);
}

test "blob upload verifies the final blob when completion closed the session" {
    const allocator = std.testing.allocator;
    const bytes = "done";
    const digest = digest_mod.computeSha256Digest(bytes);
    const head_headers = [_]TestHeader{
        .{ .name = "Docker-Content-Digest", .value = &digest },
        .{ .name = "Content-Length", .value = "4" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-3", "id"),
        } },
        .{ .fail = .{} },
        .{ .response = .{ .status = 404 } },
        .{ .response = .{ .status = 200, .headers = &head_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, bytes, .{});
    defer result.deinit();

    try std.testing.expectEqual(core.http.Method.HEAD, transport.captures[4].method);
    try std.testing.expectEqualStrings(&digest, result.digest);
    try std.testing.expect(
        std.mem.indexOf(u8, result.location, "/blobs/sha256%3A") != null,
    );
}

test "blob upload rejects a mismatched final service digest" {
    const allocator = std.testing.allocator;
    const bytes = "expected";
    const wrong_digest = digest_mod.computeSha256Digest("different");
    const complete_headers = completionHeaders(
        "/blob/final",
        "0-7",
        &wrong_digest,
    );
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-7", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
        .{ .response = .{ .status = 404 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var reader = std.Io.Reader.fixed(bytes);
    try std.testing.expectError(
        error.DigestMismatch,
        testUpload(allocator, &transport, &reader, .{}),
    );
    try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[3].method);
}

test "blob upload preserves cancellation and cancels the session" {
    const allocator = std.testing.allocator;
    var cancellation = core.http.CancellationToken{};
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .fail = .{
            .after_bytes = 2,
            .cause = error.OperationCancelled,
            .cancel = true,
        } },
        .{ .response = .{ .status = 204 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    transport.cancellation = &cancellation;
    var reader = std.Io.Reader.fixed("cancel");
    try std.testing.expectError(
        error.OperationCancelled,
        testUpload(
            allocator,
            &transport,
            &reader,
            .{ .cancellation = &cancellation },
        ),
    );
    try std.testing.expect(cancellation.isCancelled());
    try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[2].method);
}

test "blob upload preserves cancellation when cleanup fails" {
    const allocator = std.testing.allocator;
    var cancellation = core.http.CancellationToken{};
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .fail = .{
            .after_bytes = 2,
            .cause = error.OperationCancelled,
            .cancel = true,
        } },
        .{ .response = .{ .status = 500 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    transport.cancellation = &cancellation;
    var reader = std.Io.Reader.fixed("cancel");
    try std.testing.expectError(
        error.OperationCancelled,
        testUpload(
            allocator,
            &transport,
            &reader,
            .{ .cancellation = &cancellation },
        ),
    );
    try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[2].method);
}

test "blob upload returns structured service errors after cleanup" {
    const allocator = std.testing.allocator;
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 400,
            .body = "{\"errors\":[{\"code\":\"BLOB_UPLOAD_INVALID\",\"message\":\"bad range\"}]}",
        } },
        .{ .response = .{ .status = 204 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var reader = std.Io.Reader.fixed("bad");
    var response = try testUpload(allocator, &transport, &reader, .{});
    defer response.deinit();
    switch (response) {
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 400), failure.status_code);
            try std.testing.expectEqualStrings("BLOB_UPLOAD_INVALID", failure.code.?);
        },
        .ok => return error.ExpectedServiceError,
    }
    try std.testing.expectEqual(core.http.Method.DELETE, transport.captures[2].method);
}

test "blob upload preserves structured service errors when cleanup fails" {
    const allocator = std.testing.allocator;
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 400,
            .body = "{\"errors\":[{\"code\":\"BLOB_UPLOAD_INVALID\"}]}",
        } },
        .{ .response = .{ .status = 500 } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var reader = std.Io.Reader.fixed("bad");
    var response = try testUpload(allocator, &transport, &reader, .{});
    defer response.deinit();
    switch (response) {
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 400), failure.status_code);
            try std.testing.expectEqualStrings("BLOB_UPLOAD_INVALID", failure.code.?);
        },
        .ok => return error.ExpectedServiceError,
    }
    try std.testing.expectEqual(@as(usize, 3), transport.deinit_count);
}

test "blob upload validates configured chunk size before transport" {
    const allocator = std.testing.allocator;
    var transport = ScriptedTransport.init(allocator, &.{});
    var reader = std.Io.Reader.fixed("");
    try std.testing.expectError(
        error.InvalidBlobUploadChunkSize,
        testUpload(
            allocator,
            &transport,
            &reader,
            .{ .chunk_size = 0 },
        ),
    );
    try std.testing.expectError(
        error.InvalidBlobUploadChunkSize,
        testUpload(
            allocator,
            &transport,
            &reader,
            .{ .chunk_size = max_chunk_size + 1 },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

const SeekableTestReader = struct {
    interface: std.Io.Reader,
    bytes: []const u8,
    offset: usize = 0,

    fn init(bytes: []const u8) SeekableTestReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .bytes = bytes,
        };
    }

    fn seekTo(self: *SeekableTestReader, offset: u64) !void {
        if (offset > self.bytes.len) return error.InvalidSeek;
        self.offset = @intCast(offset);
    }

    fn stream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *SeekableTestReader =
            @alignCast(@fieldParentPtr("interface", reader));
        if (self.offset == self.bytes.len) return error.EndOfStream;
        const count = @min(
            self.bytes.len - self.offset,
            limit.minInt(std.math.maxInt(usize)),
        );
        try writer.writeAll(self.bytes[self.offset .. self.offset + count]);
        self.offset += count;
        return count;
    }
};

test "blob upload accepts a seekable reader at its current position" {
    const allocator = std.testing.allocator;
    const bytes = "prefix-content";
    const uploaded = "content";
    const digest = digest_mod.computeSha256Digest(uploaded);
    const complete_headers = completionHeaders("/blob/final", "0-6", &digest);
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-6", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var source = SeekableTestReader.init(bytes);
    try source.seekTo("prefix-".len);
    var transport = ScriptedTransport.init(allocator, &actions);
    var response = try testUpload(
        allocator,
        &transport,
        &source.interface,
        .{},
    );
    defer response.deinit();

    try std.testing.expect(response == .ok);
    try std.testing.expectEqual(bytes.len, source.offset);
    try std.testing.expectEqualStrings(uploaded, transport.captures[1].bodySlice());
}

test "blob upload resumes from a 416 confirmed range" {
    const allocator = std.testing.allocator;
    const bytes = "abcdef";
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders("/blob/final", "0-5", &digest);
    const range_headers = [_]TestHeader{
        .{ .name = "Location", .value = "/upload/id?_state=range" },
        .{ .name = "Range", .value = "0-1" },
        .{ .name = "Docker-Upload-UUID", .value = "id" },
    };
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{ .status = 416, .headers = &range_headers } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id?_state=next", "0-5", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var transport = ScriptedTransport.init(allocator, &actions);
    var result = try expectUpload(allocator, &transport, bytes, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("2-5", transport.captures[2].contentRange().?);
    try std.testing.expectEqualStrings("cdef", transport.captures[2].bodySlice());
    try std.testing.expect(
        std.mem.indexOf(u8, transport.captures[2].urlSlice(), "_state=range") != null,
    );
}

const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    current_bytes: usize = 0,
    max_bytes: usize = 0,
    max_allocation: usize = 0,

    fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = &alloc,
                .resize = &resize,
                .remap = &remap,
                .free = &free,
            },
        };
    }

    fn recordGrowth(self: *TrackingAllocator, amount: usize) void {
        self.current_bytes += amount;
        self.max_bytes = @max(self.max_bytes, self.current_bytes);
    }

    fn alloc(
        context: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(context));
        const pointer = self.backing.rawAlloc(
            len,
            alignment,
            return_address,
        ) orelse return null;
        self.recordGrowth(len);
        self.max_allocation = @max(self.max_allocation, len);
        return pointer;
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(context));
        if (!self.backing.rawResize(
            memory,
            alignment,
            new_len,
            return_address,
        )) return false;
        if (new_len > memory.len) {
            self.recordGrowth(new_len - memory.len);
        } else {
            self.current_bytes -= memory.len - new_len;
        }
        self.max_allocation = @max(self.max_allocation, new_len);
        return true;
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(context));
        const pointer = self.backing.rawRemap(
            memory,
            alignment,
            new_len,
            return_address,
        ) orelse return null;
        if (new_len > memory.len) {
            self.recordGrowth(new_len - memory.len);
        } else {
            self.current_bytes -= memory.len - new_len;
        }
        self.max_allocation = @max(self.max_allocation, new_len);
        return pointer;
    }

    fn free(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(context));
        self.current_bytes -= memory.len;
        self.backing.rawFree(memory, alignment, return_address);
    }
};

test "blob upload allocations stay bounded by one configured chunk" {
    const backing = std.testing.allocator;
    const chunk_size = 64 * 1024;
    const bytes = try backing.alloc(u8, chunk_size * 3 + 17);
    defer backing.free(bytes);
    @memset(bytes, 'x');
    const digest = digest_mod.computeSha256Digest(bytes);
    const complete_headers = completionHeaders(
        "/blob/final",
        "0-196624",
        &digest,
    );
    const actions = [_]TestAction{
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-0", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-65535", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-131071", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-196607", "id"),
        } },
        .{ .response = .{
            .status = 202,
            .headers = successHeaders("/upload/id", "0-196624", "id"),
        } },
        .{ .response = .{ .status = 201, .headers = &complete_headers } },
    };
    var tracking = TrackingAllocator{ .backing = backing };
    const allocator = tracking.allocator();
    var transport = ScriptedTransport.init(backing, &actions);
    var reader = std.Io.Reader.fixed(bytes);
    var response = try testUpload(
        allocator,
        &transport,
        &reader,
        .{ .chunk_size = chunk_size },
    );

    try std.testing.expect(response == .ok);
    try std.testing.expect(tracking.max_allocation <= chunk_size);
    try std.testing.expect(tracking.max_bytes <= chunk_size + 16 * 1024);
    response.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracking.current_bytes);
}

const AllocationTransport = struct {
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,
    finish_count: usize = 0,
    abort_count: usize = 0,
    deinit_count: usize = 0,

    fn init(allocator: std.mem.Allocator) AllocationTransport {
        return .{
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
        };
    }

    fn asTransport(self: *AllocationTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(
        _: *core.http.HttpTransport,
        _: *core.http.Request,
    ) !core.http.Response {
        return error.UnexpectedBufferedSend;
    }

    fn openImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
        _: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *AllocationTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        const empty_digest = digest_mod.computeSha256Digest("");
        return switch (request.method) {
            .POST => AllocationOperation.create(self, 202, &.{
                .{ .name = "Location", .value = "/upload/id" },
                .{ .name = "Range", .value = "0-0" },
                .{ .name = "Docker-Upload-UUID", .value = "id" },
            }),
            .PUT => AllocationOperation.create(self, 201, &.{
                .{ .name = "Location", .value = "/blob/final" },
                .{ .name = "Range", .value = "0-0" },
                .{ .name = "Docker-Content-Digest", .value = &empty_digest },
            }),
            .DELETE => AllocationOperation.create(self, 204, &.{}),
            else => error.UnexpectedTestMethod,
        };
    }
};

const AllocationOperation = struct {
    operation: core.http.HttpOperation,
    owner: *AllocationTransport,
    allocator: std.mem.Allocator,
    reader: std.Io.Reader,

    fn create(
        owner: *AllocationTransport,
        status: u16,
        headers: []const TestHeader,
    ) !*core.http.HttpOperation {
        const self = try owner.allocator.create(AllocationOperation);
        errdefer owner.allocator.destroy(self);
        var header_map = std.StringHashMap([]const u8).init(owner.allocator);
        errdefer deinitTestHeaderMap(owner.allocator, &header_map);
        var response_headers = core.http.ResponseHeaders.init(owner.allocator);
        errdefer response_headers.deinit();
        for (headers) |header| {
            try response_headers.append(header.name, header.value);
            const name = try owner.allocator.dupe(u8, header.name);
            errdefer owner.allocator.free(name);
            const value = try owner.allocator.dupe(u8, header.value);
            errdefer owner.allocator.free(value);
            try header_map.put(name, value);
        }
        self.* = .{
            .operation = undefined,
            .owner = owner,
            .allocator = owner.allocator,
            .reader = std.Io.Reader.fixed(""),
        };
        self.operation = .{
            .status_code = status,
            .headers = header_map,
            .response_headers = response_headers,
            .body_reader = &self.reader,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &abortImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *AllocationOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.finish_count += 1;
    }

    fn abortImpl(operation: *core.http.HttpOperation) void {
        const self: *AllocationOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.abort_count += 1;
    }

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *AllocationOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.deinit_count += 1;
        self.operation.response_headers.deinit();
        deinitTestHeaderMap(self.allocator, &self.operation.headers);
        self.allocator.destroy(self);
    }
};

fn uploadAllocationFixture(allocator: std.mem.Allocator) !void {
    var transport = AllocationTransport.init(std.testing.allocator);
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var reader = std.Io.Reader.fixed("");
    var response = upload(.{
        .allocator = allocator,
        .pipeline = &pipeline,
        .endpoint = "https://registry.example",
        .api_version = "2021-07-01",
        .repository_name = "team/app",
    }, &reader, .{ .chunk_size = 16 }) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |other| return other,
    };
    response.deinit();
}

test "blob upload is leak free across allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        uploadAllocationFixture,
        .{},
    );
}
