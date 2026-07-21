const std = @import("std");
const core = @import("azure_core");
const blob_download = @import("blob_download.zig");
const digest_mod = @import("digest.zig");

const BlobDownloadClient = blob_download.BlobDownloadClient;
const isRetryableDownloadError = blob_download.isRetryableDownloadError;
const isRetryableStatus = blob_download.isRetryableStatus;
const copy_buffer_size: usize = 64 * 1024;

fn checkCancellation(cancellation: ?*const core.http.CancellationToken) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

fn testClient(
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
) !BlobDownloadClient {
    return BlobDownloadClient.init(
        allocator,
        "https://registry.example",
        "team/app",
        .{
            .transport = transport,
            .authentication = .anonymous,
        },
    );
}

fn capturedHeader(
    headers: *const std.StringHashMap([]const u8),
    name: []const u8,
) ?[]const u8 {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name))
            return entry.value_ptr.*;
    }
    return null;
}

fn expectRedirectedBlobDownload(
    allocator: std.mem.Allocator,
    body: []const u8,
    requested_digest: []const u8,
    service_digest: ?[]const u8,
    expected_error: ?anyerror,
) !void {
    const redirect_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Location", .value = "https://storage.example/blob" },
    };
    var content_length_buffer: [32]u8 = undefined;
    const content_length = try std.fmt.bufPrint(
        &content_length_buffer,
        "{d}",
        .{body.len},
    );
    var final_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = content_length },
        .{
            .name = "Docker-Content-Digest",
            .value = service_digest orelse "",
        },
    };
    const final_header_count: usize = if (service_digest == null) 1 else 2;
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 307, .body = "", .headers = &redirect_headers },
        .{
            .status = 200,
            .body = body,
            .headers = final_headers[0..final_header_count],
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    if (expected_error) |expected| {
        try std.testing.expectError(
            expected,
            client.downloadBlob(requested_digest, .{}),
        );
    } else {
        var result = try client.downloadBlob(requested_digest, .{});
        defer result.deinit();
        try std.testing.expectEqualStrings(body, result.bytes);
        try std.testing.expectEqualStrings(requested_digest, result.digest);
    }
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqualStrings(
        "https://storage.example/blob",
        transport.capturedUrl(1),
    );
}

const DownloadTestTransport = struct {
    const Header = core.http.MockTransport.HeaderPair;
    const ResponseSpec = struct {
        status: u16,
        body: []const u8 = "",
        headers: []const Header = &.{},
        fail_after: ?usize = null,
        body_error: ?anyerror = null,
        open_error: ?anyerror = null,
        read_size: usize = 2,
    };

    allocator: std.mem.Allocator,
    responses: []const ResponseSpec,
    transport: core.http.HttpTransport,
    call_count: usize = 0,
    ranges: [32][96]u8 = undefined,
    range_lengths: [32]usize = .{0} ** 32,
    urls: [32][512]u8 = undefined,
    url_lengths: [32]usize = .{0} ** 32,
    captured_authorization: [32]bool = .{false} ** 32,
    captured_cookie: [32]bool = .{false} ** 32,
    captured_proxy_authorization: [32]bool = .{false} ** 32,
    captured_host: [32]bool = .{false} ** 32,
    finish_count: usize = 0,
    abort_count: usize = 0,
    cancel_count: usize = 0,
    deinit_count: usize = 0,

    fn init(
        allocator: std.mem.Allocator,
        responses: []const ResponseSpec,
    ) DownloadTestTransport {
        return .{
            .allocator = allocator,
            .responses = responses,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
        };
    }

    fn asTransport(self: *DownloadTestTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn capturedRange(self: *const DownloadTestTransport, index: usize) []const u8 {
        return self.ranges[index][0..self.range_lengths[index]];
    }

    fn capturedUrl(self: *const DownloadTestTransport, index: usize) []const u8 {
        return self.urls[index][0..self.url_lengths[index]];
    }

    fn capture(
        self: *DownloadTestTransport,
        request: *const core.http.Request,
    ) !usize {
        if (self.responses.len == 0) return error.NoCannedResponses;
        if (self.call_count >= self.ranges.len) return error.TooManyMockRequests;
        const call = self.call_count;
        if (request.url.len > self.urls[call].len) return error.MockRequestUrlTooLong;
        @memcpy(self.urls[call][0..request.url.len], request.url);
        self.url_lengths[call] = request.url.len;
        if (request.getHeader("Range")) |range| {
            if (range.len > self.ranges[call].len) return error.MockRangeTooLong;
            @memcpy(self.ranges[call][0..range.len], range);
            self.range_lengths[call] = range.len;
        }
        self.captured_authorization[call] = request.getHeader("Authorization") != null;
        self.captured_cookie[call] = request.getHeader("Cookie") != null;
        self.captured_proxy_authorization[call] =
            request.getHeader("Proxy-Authorization") != null;
        self.captured_host[call] = request.getHeader("Host") != null;
        self.call_count += 1;
        return @min(call, self.responses.len - 1);
    }

    fn sendImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *DownloadTestTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        const index = try self.capture(request);
        const spec = self.responses[index];
        if (spec.open_error) |failure| return failure;
        const body = try self.allocator.dupe(u8, spec.body);
        errdefer self.allocator.free(body);
        var headers = try testHeaderSet(self.allocator, spec.headers);
        errdefer headers.deinit(self.allocator);
        return .{
            .status_code = spec.status,
            .headers = headers.map,
            .body = body,
            .allocator = self.allocator,
            .response_headers = headers.values,
        };
    }

    fn openImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *DownloadTestTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        try checkCancellation(options.cancellation);
        const index = try self.capture(request);
        const spec = self.responses[index];
        if (spec.open_error) |failure| return failure;
        return DownloadTestOperation.open(self, spec);
    }
};

const TestHeaderSet = struct {
    map: std.StringHashMap([]const u8),
    values: core.http.ResponseHeaders,

    fn deinit(self: *TestHeaderSet, allocator: std.mem.Allocator) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
        self.values.deinit();
    }
};

fn testHeaderSet(
    allocator: std.mem.Allocator,
    headers: []const DownloadTestTransport.Header,
) !TestHeaderSet {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer {
        var iterator = map.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }
    var values = core.http.ResponseHeaders.init(allocator);
    errdefer values.deinit();
    for (headers) |header| {
        try values.append(header.name, header.value);
        const name = try allocator.dupe(u8, header.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, header.value);
        errdefer allocator.free(value);
        const entry = try map.getOrPut(name);
        if (entry.found_existing) {
            allocator.free(name);
            allocator.free(entry.value_ptr.*);
        } else {
            entry.key_ptr.* = name;
        }
        entry.value_ptr.* = value;
    }
    return .{ .map = map, .values = values };
}

const DownloadTestOperation = struct {
    operation: core.http.HttpOperation,
    allocator: std.mem.Allocator,
    owner: *DownloadTestTransport,
    body: []u8,
    reader_impl: DownloadTestReader,

    fn open(
        owner: *DownloadTestTransport,
        spec: DownloadTestTransport.ResponseSpec,
    ) !*core.http.HttpOperation {
        const self = try owner.allocator.create(DownloadTestOperation);
        errdefer owner.allocator.destroy(self);
        const body = try owner.allocator.dupe(u8, spec.body);
        errdefer owner.allocator.free(body);
        var headers = try testHeaderSet(owner.allocator, spec.headers);
        errdefer headers.deinit(owner.allocator);
        self.* = .{
            .operation = undefined,
            .allocator = owner.allocator,
            .owner = owner,
            .body = body,
            .reader_impl = DownloadTestReader.init(
                body,
                spec.read_size,
                spec.fail_after,
                spec.body_error,
            ),
        };
        self.operation = .{
            .status_code = spec.status,
            .headers = headers.map,
            .response_headers = headers.values,
            .body_reader = &self.reader_impl.interface,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &cancelImpl,
            .deinitFn = &deinitImpl,
            .bodyErrorFn = &bodyErrorImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *DownloadTestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.finish_count += 1;
        _ = try self.reader_impl.interface.discardRemaining();
    }

    fn abortImpl(operation: *core.http.HttpOperation) void {
        const self: *DownloadTestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.abort_count += 1;
    }

    fn cancelImpl(operation: *core.http.HttpOperation) void {
        const self: *DownloadTestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.cancel_count += 1;
    }

    fn bodyErrorImpl(operation: *const core.http.HttpOperation) ?anyerror {
        const self: *const DownloadTestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        return self.reader_impl.body_error;
    }

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *DownloadTestOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.deinit_count += 1;
        var headers = TestHeaderSet{
            .map = self.operation.headers,
            .values = self.operation.response_headers,
        };
        headers.deinit(self.allocator);
        self.allocator.free(self.body);
        self.allocator.destroy(self);
    }
};

const DownloadTestReader = struct {
    interface: std.Io.Reader,
    body: []const u8,
    offset: usize = 0,
    read_size: usize,
    fail_after: ?usize,
    body_error: ?anyerror,

    fn init(
        body: []const u8,
        read_size: usize,
        fail_after: ?usize,
        body_error: ?anyerror,
    ) DownloadTestReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .body = body,
            .read_size = @max(read_size, 1),
            .fail_after = fail_after,
            .body_error = body_error,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *DownloadTestReader =
            @alignCast(@fieldParentPtr("interface", interface));
        if (self.fail_after) |fail_after| {
            if (self.offset >= fail_after) return error.ReadFailed;
        }
        if (self.offset >= self.body.len) return error.EndOfStream;
        var count = @min(
            self.body.len - self.offset,
            limit.minInt(self.read_size),
        );
        if (self.fail_after) |fail_after| {
            count = @min(count, fail_after - self.offset);
        }
        if (count == 0) return 0;
        try writer.writeAll(self.body[self.offset .. self.offset + count]);
        self.offset += count;
        return count;
    }
};

test "buffered blob download validates exact identity bytes and bound" {
    const allocator = std.testing.allocator;
    const body = "small blob";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "10" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 200, body);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    transport.stream_response_chunk_size = 3;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.downloadBlob(&expected_digest, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings(body, result.bytes);
    try std.testing.expectEqualStrings(&expected_digest, result.digest);
    try std.testing.expectEqualStrings(
        "application/octet-stream",
        capturedHeader(&transport.last_headers, "Accept").?,
    );
    try std.testing.expectEqual(@as(usize, 1), transport.stream_finish_count);

    try std.testing.expectError(
        error.BlobTooLarge,
        client.downloadBlob(&expected_digest, .{ .max_size = body.len - 1 }),
    );
    try std.testing.expectEqual(@as(usize, 1), transport.stream_abort_count);
}

test "buffered and streaming downloads distinguish identity and compressed lengths" {
    const allocator = std.testing.allocator;
    const body = "decoded bytes";
    const expected_digest = digest_mod.computeSha256Digest(body);
    var headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "3" },
        .{ .name = "Content-Encoding", .value = "gzip" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 200, body);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var compressed = try client.downloadBlob(&expected_digest, .{});
    defer compressed.deinit();
    try std.testing.expectEqualStrings(body, compressed.bytes);

    headers[1].value = "identity";
    try std.testing.expectError(
        error.ContentLengthMismatch,
        client.downloadBlob(&expected_digest, .{}),
    );
}

test "streaming blob ownership supports finish abort cancellation and exact failures" {
    const allocator = std.testing.allocator;
    const body = "streamed";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "8" },
    };
    var transport = core.http.MockTransport.init(allocator, 200, body);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    transport.stream_response_chunk_size = 2;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    {
        var stream = try client.downloadBlobStreaming(&expected_digest, .{});
        defer stream.deinit();
        var first: [3]u8 = undefined;
        const count = try (try stream.reader()).readSliceShort(&first);
        try std.testing.expectEqualStrings("str", first[0..count]);
    }
    try std.testing.expectEqual(@as(usize, 1), transport.stream_abort_count);

    {
        var stream = try client.downloadBlobStreaming(&expected_digest, .{});
        defer stream.deinit();
        stream.abort();
    }
    try std.testing.expectEqual(@as(usize, 2), transport.stream_abort_count);

    {
        var stream = try client.downloadBlobStreaming(&expected_digest, .{});
        defer stream.deinit();
        try stream.finish();
        try std.testing.expectEqual(@as(u64, body.len), stream.decodedLength());
        try std.testing.expectEqualSlices(
            u8,
            &expected_digest,
            &(try stream.computedDigest()),
        );
    }
    try std.testing.expectEqual(@as(usize, 1), transport.stream_finish_count);

    var cancellation = core.http.CancellationToken{};
    {
        var stream = try client.downloadBlobStreaming(
            &expected_digest,
            .{ .cancellation = &cancellation },
        );
        defer stream.deinit();
        cancellation.cancel();
        var byte: [1]u8 = undefined;
        try std.testing.expectError(
            error.ReadFailed,
            (try stream.reader()).readSliceShort(&byte),
        );
        try std.testing.expectEqual(error.OperationCancelled, stream.lastError().?);
    }
    try std.testing.expectEqual(@as(usize, 1), transport.stream_cancel_count);
    try std.testing.expectEqual(@as(usize, 4), transport.stream_deinit_count);
}

test "blob response content length headers are required unique and numeric" {
    const allocator = std.testing.allocator;
    const body = "length";
    const digest = digest_mod.computeSha256Digest(body);
    var transport = core.http.MockTransport.init(allocator, 200, body);
    defer transport.deinit();
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    const missing = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    transport.response_headers_list = &missing;
    try std.testing.expectError(
        error.MissingContentLength,
        client.downloadBlob(&digest, .{}),
    );

    const invalid = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "-1" },
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    transport.response_headers_list = &invalid;
    try std.testing.expectError(
        error.InvalidContentLength,
        client.downloadBlob(&digest, .{}),
    );

    const duplicate = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "6" },
        .{ .name = "content-length", .value = "6" },
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    transport.response_headers_list = &duplicate;
    try std.testing.expectError(
        error.AmbiguousResponseHeader,
        client.downloadBlob(&digest, .{}),
    );
}

test "sequential ranged download validates 206 ranges and exact digest" {
    const allocator = std.testing.allocator;
    const body = "abcdefghij";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const headers_1 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "bytes 0-3/10" },
    };
    const headers_2 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "bytes 4-7/10" },
    };
    const headers_3 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "2" },
        .{ .name = "Content-Range", .value = "bytes 8-9/10" },
    };
    const responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = body[0..4], .headers = &headers_1 },
        .{ .status = 206, .body = body[4..8], .headers = &headers_2 },
        .{ .status = 206, .body = body[8..10], .headers = &headers_3 },
    };
    var transport = DownloadTestTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();

    var details = try client.downloadBlobToWriter(
        &expected_digest,
        &output.writer,
        .{ .range_size = 4 },
    );
    defer details.deinit();

    try std.testing.expectEqualStrings(body, output.writer.buffered());
    try std.testing.expectEqualStrings(&expected_digest, details.digest);
    try std.testing.expectEqual(@as(u64, body.len), details.size);
    try std.testing.expectEqualStrings("bytes=0-3", transport.capturedRange(0));
    try std.testing.expectEqualStrings("bytes=4-7", transport.capturedRange(1));
    try std.testing.expectEqualStrings("bytes=8-9", transport.capturedRange(2));
}

test "ranged download accepts full 200 and terminal 416" {
    const allocator = std.testing.allocator;
    const body = "full body";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const full_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "9" },
    };
    const full_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 200, .body = body, .headers = &full_headers },
    };
    var full_transport = DownloadTestTransport.init(allocator, &full_responses);
    var full_client = try testClient(allocator, full_transport.asTransport());
    defer full_client.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var details = try full_client.downloadBlobToWriter(
        &expected_digest,
        &output.writer,
        .{ .range_size = 4 },
    );
    defer details.deinit();
    try std.testing.expectEqualStrings(body, output.writer.buffered());
    try std.testing.expectEqualStrings("bytes=0-3", full_transport.capturedRange(0));

    const empty_digest = digest_mod.computeSha256Digest("");
    const empty_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "0" },
        .{ .name = "Content-Range", .value = "bytes */0" },
        .{ .name = "Docker-Content-Digest", .value = &empty_digest },
    };
    const empty_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 416, .headers = &empty_headers },
    };
    var empty_transport = DownloadTestTransport.init(allocator, &empty_responses);
    var empty_client = try testClient(allocator, empty_transport.asTransport());
    defer empty_client.deinit();
    var empty_output: std.Io.Writer.Allocating = .init(allocator);
    defer empty_output.deinit();
    var empty_details = try empty_client.downloadBlobToWriter(
        &empty_digest,
        &empty_output.writer,
        .{},
    );
    defer empty_details.deinit();
    try std.testing.expectEqual(@as(u64, 0), empty_details.size);

    const invalid_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Range", .value = "bytes */5" },
    };
    const invalid_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 416, .headers = &invalid_headers },
    };
    var invalid_transport = DownloadTestTransport.init(allocator, &invalid_responses);
    var invalid_client = try testClient(allocator, invalid_transport.asTransport());
    defer invalid_client.deinit();
    try std.testing.expectError(
        error.RangeNotSatisfiable,
        invalid_client.downloadBlobToWriter(
            &empty_digest,
            &empty_output.writer,
            .{},
        ),
    );
}

test "ranged and fallback downloads validate optional service digest and full bytes" {
    const allocator = std.testing.allocator;
    const requested_digest = digest_mod.computeSha256Digest("range");
    const other_digest = digest_mod.computeSha256Digest("other");
    const range_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "5" },
        .{ .name = "Content-Range", .value = "bytes 0-4/5" },
    };
    const range_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "wrong", .headers = &range_headers },
    };
    var range_transport = DownloadTestTransport.init(allocator, &range_responses);
    var range_client = try testClient(allocator, range_transport.asTransport());
    defer range_client.deinit();
    var range_output: std.Io.Writer.Allocating = .init(allocator);
    defer range_output.deinit();
    try std.testing.expectError(
        error.RequestedDigestMismatch,
        range_client.downloadBlobToWriter(
            &requested_digest,
            &range_output.writer,
            .{ .range_size = 5 },
        ),
    );

    const mismatched_range_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "5" },
        .{ .name = "Content-Range", .value = "bytes 0-4/5" },
        .{ .name = "Docker-Content-Digest", .value = &other_digest },
    };
    const mismatched_range_responses = [_]DownloadTestTransport.ResponseSpec{
        .{
            .status = 206,
            .body = "range",
            .headers = &mismatched_range_headers,
        },
    };
    var mismatched_range_transport = DownloadTestTransport.init(
        allocator,
        &mismatched_range_responses,
    );
    var mismatched_range_client = try testClient(
        allocator,
        mismatched_range_transport.asTransport(),
    );
    defer mismatched_range_client.deinit();
    var mismatched_range_output: std.Io.Writer.Allocating = .init(allocator);
    defer mismatched_range_output.deinit();
    try std.testing.expectError(
        error.ServiceDigestMismatch,
        mismatched_range_client.downloadBlobToWriter(
            &requested_digest,
            &mismatched_range_output.writer,
            .{ .range_size = 5 },
        ),
    );

    const fallback_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "5" },
    };
    const fallback_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 200, .body = "wrong", .headers = &fallback_headers },
    };
    var fallback_transport = DownloadTestTransport.init(allocator, &fallback_responses);
    var fallback_client = try testClient(allocator, fallback_transport.asTransport());
    defer fallback_client.deinit();
    var fallback_output: std.Io.Writer.Allocating = .init(allocator);
    defer fallback_output.deinit();
    try std.testing.expectError(
        error.RequestedDigestMismatch,
        fallback_client.downloadBlobToWriter(
            &requested_digest,
            &fallback_output.writer,
            .{ .range_size = 5 },
        ),
    );

    const mismatched_fallback_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "5" },
        .{ .name = "Docker-Content-Digest", .value = &other_digest },
    };
    const mismatched_fallback_responses = [_]DownloadTestTransport.ResponseSpec{
        .{
            .status = 200,
            .body = "range",
            .headers = &mismatched_fallback_headers,
        },
    };
    var mismatched_fallback_transport = DownloadTestTransport.init(
        allocator,
        &mismatched_fallback_responses,
    );
    var mismatched_fallback_client = try testClient(
        allocator,
        mismatched_fallback_transport.asTransport(),
    );
    defer mismatched_fallback_client.deinit();
    var mismatched_fallback_output: std.Io.Writer.Allocating = .init(allocator);
    defer mismatched_fallback_output.deinit();
    try std.testing.expectError(
        error.ServiceDigestMismatch,
        mismatched_fallback_client.downloadBlobToWriter(
            &requested_digest,
            &mismatched_fallback_output.writer,
            .{ .range_size = 5 },
        ),
    );
}

test "partial ranged reads resume at confirmed writer offset without duplication" {
    const allocator = std.testing.allocator;
    const body = "abcdefghij";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const first_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "6" },
        .{ .name = "Content-Range", .value = "bytes 0-5/10" },
    };
    const resumed_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "6" },
        .{ .name = "Content-Range", .value = "bytes 3-8/10" },
    };
    const final_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "1" },
        .{ .name = "Content-Range", .value = "bytes 9-9/10" },
    };
    const responses = [_]DownloadTestTransport.ResponseSpec{
        .{
            .status = 206,
            .body = body[0..6],
            .headers = &first_headers,
            .fail_after = 3,
            .body_error = error.ConnectionResetByPeer,
        },
        .{ .status = 206, .body = body[3..9], .headers = &resumed_headers },
        .{ .status = 206, .body = body[9..10], .headers = &final_headers },
    };
    var transport = DownloadTestTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();

    var details = try client.downloadBlobToWriter(
        &expected_digest,
        &output.writer,
        .{ .range_size = 6 },
    );
    defer details.deinit();
    try std.testing.expectEqualStrings(body, output.writer.buffered());
    try std.testing.expectEqualStrings("bytes=0-5", transport.capturedRange(0));
    try std.testing.expectEqualStrings("bytes=3-8", transport.capturedRange(1));
    try std.testing.expectEqualStrings("bytes=9-9", transport.capturedRange(2));
    try std.testing.expectEqual(@as(usize, 1), transport.abort_count);
}

test "range retries classify open status and read failures without broad fallback" {
    const allocator = std.testing.allocator;
    const body = "retry";
    const expected_digest = digest_mod.computeSha256Digest(body);
    const headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "5" },
        .{ .name = "Content-Range", .value = "bytes 0-4/5" },
    };
    const responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 0, .open_error = error.ConnectionTimedOut },
        .{ .status = 503, .body = "{\"errors\":[]}" },
        .{ .status = 206, .body = body, .headers = &headers },
    };
    var transport = DownloadTestTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var details = try client.downloadBlobToWriter(
        &expected_digest,
        &output.writer,
        .{ .range_size = 5, .max_retries = 2 },
    );
    defer details.deinit();
    try std.testing.expectEqualStrings(body, output.writer.buffered());
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);

    try std.testing.expect(isRetryableDownloadError(error.ReadFailed));
    try std.testing.expect(isRetryableDownloadError(error.UnexpectedEndOfStream));
    try std.testing.expect(isRetryableDownloadError(error.ConnectionResetByPeer));
    try std.testing.expect(!isRetryableDownloadError(error.OperationCancelled));
    try std.testing.expect(!isRetryableDownloadError(error.InvalidContentRange));
    try std.testing.expect(!isRetryableDownloadError(error.RequestedDigestMismatch));
    try std.testing.expect(isRetryableStatus(408));
    try std.testing.expect(isRetryableStatus(429));
    try std.testing.expect(isRetryableStatus(503));
    try std.testing.expect(!isRetryableStatus(416));
}

test "range validation rejects malformed offsets spans lengths encodings and totals" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("abcd");
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();

    const malformed_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "items 0-3/4" },
    };
    const malformed_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "abcd", .headers = &malformed_headers },
    };
    var malformed_transport = DownloadTestTransport.init(allocator, &malformed_responses);
    var malformed_client = try testClient(allocator, malformed_transport.asTransport());
    defer malformed_client.deinit();
    try std.testing.expectError(
        error.InvalidContentRange,
        malformed_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 4 }),
    );

    const offset_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "3" },
        .{ .name = "Content-Range", .value = "bytes 1-3/4" },
    };
    const offset_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "bcd", .headers = &offset_headers },
    };
    var offset_transport = DownloadTestTransport.init(allocator, &offset_responses);
    var offset_client = try testClient(allocator, offset_transport.asTransport());
    defer offset_client.deinit();
    try std.testing.expectError(
        error.ContentRangeOffsetMismatch,
        offset_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 4 }),
    );

    const span_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "bytes 0-3/4" },
    };
    const span_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "abcd", .headers = &span_headers },
    };
    var span_transport = DownloadTestTransport.init(allocator, &span_responses);
    var span_client = try testClient(allocator, span_transport.asTransport());
    defer span_client.deinit();
    try std.testing.expectError(
        error.ContentRangeOutsideRequest,
        span_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 3 }),
    );

    const length_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "3" },
        .{ .name = "Content-Range", .value = "bytes 0-3/4" },
    };
    const length_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "abcd", .headers = &length_headers },
    };
    var length_transport = DownloadTestTransport.init(allocator, &length_responses);
    var length_client = try testClient(allocator, length_transport.asTransport());
    defer length_client.deinit();
    try std.testing.expectError(
        error.ContentLengthMismatch,
        length_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 4 }),
    );

    const encoded_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Encoding", .value = "gzip" },
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "bytes 0-3/4" },
    };
    const encoded_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "abcd", .headers = &encoded_headers },
    };
    var encoded_transport = DownloadTestTransport.init(allocator, &encoded_responses);
    var encoded_client = try testClient(allocator, encoded_transport.asTransport());
    defer encoded_client.deinit();
    try std.testing.expectError(
        error.EncodedRangeResponse,
        encoded_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 4 }),
    );

    const total_headers_1 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "2" },
        .{ .name = "Content-Range", .value = "bytes 0-1/4" },
    };
    const total_headers_2 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "2" },
        .{ .name = "Content-Range", .value = "bytes 2-3/5" },
    };
    const total_responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 206, .body = "ab", .headers = &total_headers_1 },
        .{ .status = 206, .body = "cd", .headers = &total_headers_2 },
    };
    var total_transport = DownloadTestTransport.init(allocator, &total_responses);
    var total_client = try testClient(allocator, total_transport.asTransport());
    defer total_client.deinit();
    try std.testing.expectError(
        error.TotalSizeMismatch,
        total_client.downloadBlobToWriter(&digest, &output.writer, .{ .range_size = 2 }),
    );
}

test "direct blob downloads allow absent service digest and validate present digests" {
    const allocator = std.testing.allocator;
    const body = "digest bytes";
    const requested_digest = digest_mod.computeSha256Digest(body);
    const other_digest = digest_mod.computeSha256Digest("other");
    const missing_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "12" },
    };
    var missing_transport = core.http.MockTransport.init(allocator, 200, body);
    defer missing_transport.deinit();
    missing_transport.response_headers_list = &missing_headers;
    var missing_client = try testClient(allocator, missing_transport.asTransport());
    defer missing_client.deinit();
    var missing_result = try missing_client.downloadBlob(&requested_digest, .{});
    missing_result.deinit();

    var missing_content_transport = core.http.MockTransport.init(
        allocator,
        200,
        "wrong bytes!",
    );
    defer missing_content_transport.deinit();
    missing_content_transport.response_headers_list = &missing_headers;
    var missing_content_client = try testClient(
        allocator,
        missing_content_transport.asTransport(),
    );
    defer missing_content_client.deinit();
    try std.testing.expectError(
        error.RequestedDigestMismatch,
        missing_content_client.downloadBlob(&requested_digest, .{}),
    );

    const service_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "12" },
        .{ .name = "Docker-Content-Digest", .value = &other_digest },
    };
    var service_transport = core.http.MockTransport.init(allocator, 200, body);
    defer service_transport.deinit();
    service_transport.response_headers_list = &service_headers;
    var service_client = try testClient(allocator, service_transport.asTransport());
    defer service_client.deinit();
    try std.testing.expectError(
        error.ServiceDigestMismatch,
        service_client.downloadBlob(&requested_digest, .{}),
    );

    const content_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "12" },
        .{ .name = "Docker-Content-Digest", .value = &requested_digest },
    };
    var content_transport = core.http.MockTransport.init(allocator, 200, "wrong bytes!");
    defer content_transport.deinit();
    content_transport.response_headers_list = &content_headers;
    var content_client = try testClient(allocator, content_transport.asTransport());
    defer content_client.deinit();
    try std.testing.expectError(
        error.RequestedDigestMismatch,
        content_client.downloadBlob(&requested_digest, .{}),
    );
}

test "blob download preserves structured ACR service errors" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("missing");
    const body =
        "{\"errors\":[{\"code\":\"BLOB_UNKNOWN\",\"message\":\"missing blob\"}]}";
    var transport = core.http.MockTransport.init(allocator, 404, body);
    defer transport.deinit();
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var response = try client.downloadBlobResult(&digest, .{});
    defer response.deinit();
    switch (response) {
        .ok => return error.ExpectedServiceError,
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 404), failure.status_code);
            try std.testing.expectEqualStrings("BLOB_UNKNOWN", failure.code.?);
            try std.testing.expectEqualStrings("missing blob", failure.message.?);
        },
    }
}

test "cross-origin blob redirects strip credentials and insecure redirects fail" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("redirected");
    const redirect_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Location", .value = "https://storage.example/blob#fragment" },
    };
    const success_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "10" },
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    var sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 307, .body = "", .headers = &redirect_headers },
        .{ .status = 200, .body = "redirected", .headers = &success_headers },
    });
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://registry.example/v2/team/app/blobs/test",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "******");
    try request.setHeader("Cookie", "session=test");
    try request.setHeader("Proxy-Authorization", "Basic test");
    try request.setHeader("Host", "registry.example");
    var operation = try sequence.asTransport().open(&request, .{});
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 200), operation.status_code);
    try std.testing.expect(sequence.captured_authorization[0]);
    try std.testing.expect(!sequence.captured_authorization[1]);
    try std.testing.expect(sequence.captured_cookie[0]);
    try std.testing.expect(!sequence.captured_cookie[1]);
    try std.testing.expect(sequence.captured_proxy_authorization[0]);
    try std.testing.expect(!sequence.captured_proxy_authorization[1]);
    try std.testing.expect(sequence.captured_host[0]);
    try std.testing.expect(!sequence.captured_host[1]);
    try std.testing.expectEqualStrings(
        "https://storage.example/blob",
        sequence.capturedUrl(1),
    );
    try operation.finish();

    const insecure_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Location", .value = "http://storage.example/blob" },
    };
    var insecure = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 307, .body = "", .headers = &insecure_headers },
    });
    var client = try testClient(allocator, insecure.asTransport());
    defer client.deinit();
    try std.testing.expectError(
        error.HttpsRequired,
        client.downloadBlob(&digest, .{}),
    );
}

test "redirected blob downloads allow absent service digest and validate present digests" {
    const allocator = std.testing.allocator;
    const body = "redirected";
    const requested_digest = digest_mod.computeSha256Digest(body);
    const other_digest = digest_mod.computeSha256Digest("other");

    try expectRedirectedBlobDownload(
        allocator,
        body,
        &requested_digest,
        null,
        null,
    );
    try expectRedirectedBlobDownload(
        allocator,
        body,
        &requested_digest,
        &requested_digest,
        null,
    );
    try expectRedirectedBlobDownload(
        allocator,
        body,
        &requested_digest,
        &other_digest,
        error.ServiceDigestMismatch,
    );
    try expectRedirectedBlobDownload(
        allocator,
        "wrong body",
        &requested_digest,
        null,
        error.RequestedDigestMismatch,
    );
}

test "ranged resume restarts from registry instead of retaining redirect continuation" {
    const allocator = std.testing.allocator;
    const body = "abcd";
    const digest = digest_mod.computeSha256Digest(body);
    const redirect_1 = [_]DownloadTestTransport.Header{
        .{ .name = "Location", .value = "https://storage-one.example/blob" },
    };
    const partial_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "4" },
        .{ .name = "Content-Range", .value = "bytes 0-3/4" },
    };
    const redirect_2 = [_]DownloadTestTransport.Header{
        .{ .name = "Location", .value = "https://storage-two.example/blob" },
    };
    const resume_headers = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "2" },
        .{ .name = "Content-Range", .value = "bytes 2-3/4" },
    };
    const responses = [_]DownloadTestTransport.ResponseSpec{
        .{ .status = 307, .headers = &redirect_1 },
        .{
            .status = 206,
            .body = body,
            .headers = &partial_headers,
            .fail_after = 2,
            .body_error = error.ConnectionResetByPeer,
        },
        .{ .status = 307, .headers = &redirect_2 },
        .{ .status = 206, .body = body[2..4], .headers = &resume_headers },
    };
    var transport = DownloadTestTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var details = try client.downloadBlobToWriter(
        &digest,
        &output.writer,
        .{ .range_size = 4 },
    );
    defer details.deinit();

    try std.testing.expectEqualStrings(body, output.writer.buffered());
    try std.testing.expect(std.mem.startsWith(
        u8,
        transport.capturedUrl(0),
        "https://registry.example/",
    ));
    try std.testing.expectEqualStrings(
        "https://storage-one.example/blob",
        transport.capturedUrl(1),
    );
    try std.testing.expect(std.mem.startsWith(
        u8,
        transport.capturedUrl(2),
        "https://registry.example/",
    ));
    try std.testing.expectEqualStrings(
        "https://storage-two.example/blob",
        transport.capturedUrl(3),
    );
    try std.testing.expectEqualStrings("bytes=2-3", transport.capturedRange(2));
}

test "large ranged writer path keeps SDK copy and request sizes bounded" {
    const allocator = std.testing.allocator;
    const body = try allocator.alloc(u8, 140 * 1024);
    defer allocator.free(body);
    for (body, 0..) |*byte, index| byte.* = @truncate(index);
    const digest = digest_mod.computeSha256Digest(body);
    var range_1_buffer: [64]u8 = undefined;
    const range_1 = try std.fmt.bufPrint(
        &range_1_buffer,
        "bytes 0-{d}/{d}",
        .{ (70 * 1024) - 1, body.len },
    );
    var range_2_buffer: [64]u8 = undefined;
    const range_2 = try std.fmt.bufPrint(
        &range_2_buffer,
        "bytes {d}-{d}/{d}",
        .{ 70 * 1024, body.len - 1, body.len },
    );
    const headers_1 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "71680" },
        .{ .name = "Content-Range", .value = range_1 },
    };
    const headers_2 = [_]DownloadTestTransport.Header{
        .{ .name = "Content-Length", .value = "71680" },
        .{ .name = "Content-Range", .value = range_2 },
    };
    const responses = [_]DownloadTestTransport.ResponseSpec{
        .{
            .status = 206,
            .body = body[0 .. 70 * 1024],
            .headers = &headers_1,
            .read_size = copy_buffer_size,
        },
        .{
            .status = 206,
            .body = body[70 * 1024 ..],
            .headers = &headers_2,
            .read_size = copy_buffer_size,
        },
    };
    var transport = DownloadTestTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var discard_buffer: [256]u8 = undefined;
    var discard: std.Io.Writer.Discarding = .init(&discard_buffer);

    var details = try client.downloadBlobToWriter(
        &digest,
        &discard.writer,
        .{ .range_size = 70 * 1024 },
    );
    defer details.deinit();
    try std.testing.expectEqual(@as(u64, body.len), discard.fullCount());
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqualStrings(
        "bytes=0-71679",
        transport.capturedRange(0),
    );
    try std.testing.expectEqualStrings(
        "bytes=71680-143359",
        transport.capturedRange(1),
    );
}

fn bufferedAllocationFixture(allocator: std.mem.Allocator) !void {
    const body = "allocation";
    const digest = digest_mod.computeSha256Digest(body);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "10" },
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    var transport = core.http.MockTransport.init(allocator, 200, body);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var result = try client.downloadBlob(&digest, .{});
    result.deinit();
}

test "blob download allocation failures release all ownership" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        bufferedAllocationFixture,
        .{},
    );
}
