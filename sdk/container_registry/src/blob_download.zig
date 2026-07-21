const std = @import("std");
const core = @import("azure_core");
const client_mod = @import("client.zig");
const digest_mod = @import("digest.zig");
const service_error = @import("service_error.zig");

pub const default_buffered_blob_limit: usize = 16 * 1024 * 1024;
pub const default_range_size: usize = 4 * 1024 * 1024;
const copy_buffer_size: usize = 64 * 1024;
const max_error_body_size: usize = 1024 * 1024;

pub const BlobDownloadClientOptions = client_mod.ContainerRegistryClientOptions;

pub const BufferedBlobDownloadOptions = struct {
    max_size: usize = default_buffered_blob_limit,
    cancellation: ?*const core.http.CancellationToken = null,
};

pub const StreamingBlobDownloadOptions = struct {
    cancellation: ?*const core.http.CancellationToken = null,
};

pub const DownloadBlobToWriterOptions = struct {
    range_size: usize = default_range_size,
    max_retries: u32 = 3,
    cancellation: ?*const core.http.CancellationToken = null,
};

pub const DownloadedBlob = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    digest: []u8,

    pub fn deinit(self: *DownloadedBlob) void {
        self.allocator.free(self.bytes);
        self.allocator.free(self.digest);
        self.* = undefined;
    }
};

pub const BlobDownloadDetails = struct {
    allocator: std.mem.Allocator,
    digest: []u8,
    size: u64,

    pub fn deinit(self: *BlobDownloadDetails) void {
        self.allocator.free(self.digest);
        self.* = undefined;
    }
};

pub const BufferedBlobDownloadResponse = BlobDownloadResponse(DownloadedBlob);
pub const StreamingBlobDownloadResponse = BlobDownloadResponse(BlobDownloadStream);
pub const DownloadBlobToWriterResponse = BlobDownloadResponse(BlobDownloadDetails);

pub fn BlobDownloadResponse(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: service_error.ServiceError,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            switch (self.*) {
                .ok => |*value| value.deinit(),
                .err => |*failure| failure.deinit(),
            }
            self.* = undefined;
        }

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn errorCode(self: Self) ?[]const u8 {
            return switch (self) {
                .ok => null,
                .err => |failure| failure.code,
            };
        }

        pub fn unwrap(self: *Self, failure_error: anyerror) anyerror!T {
            switch (self.*) {
                .ok => |value| {
                    self.* = undefined;
                    return value;
                },
                .err => |*failure| {
                    failure.deinit();
                    self.* = undefined;
                    return failure_error;
                },
            }
        }
    };
}

const DownloadState = enum {
    active,
    finished,
    aborted,
    cancelled,
};

pub const BlobDownloadStream = struct {
    allocator: std.mem.Allocator,
    operation: *core.http.HttpOperation,
    digest: []u8,
    content_length: u64,
    decoded_content_length: ?u64,
    reader_impl: ValidatingReader,
    state: DownloadState = .active,

    fn init(
        allocator: std.mem.Allocator,
        operation: *core.http.HttpOperation,
        requested_digest: []const u8,
        service_digest: ?[]const u8,
        content_length: u64,
        decoded_content_length: ?u64,
        cancellation: ?*const core.http.CancellationToken,
    ) !BlobDownloadStream {
        const owned_digest = try allocator.dupe(u8, requested_digest);
        errdefer allocator.free(owned_digest);
        const owned_service_digest = if (service_digest) |value|
            try allocator.dupe(u8, value)
        else
            null;
        errdefer if (owned_service_digest) |value| allocator.free(value);

        return .{
            .allocator = allocator,
            .operation = operation,
            .digest = owned_digest,
            .content_length = content_length,
            .decoded_content_length = decoded_content_length,
            .reader_impl = ValidatingReader.init(
                operation,
                owned_digest,
                owned_service_digest,
                decoded_content_length,
                cancellation,
            ),
        };
    }

    /// Returns a validating reader over the decoded response bytes.
    ///
    /// Read failures are reported as `error.ReadFailed`; call `lastError` for
    /// the specific transport, cancellation, length, or digest failure.
    pub fn reader(self: *BlobDownloadStream) !*std.Io.Reader {
        if (self.state != .active) return error.BlobDownloadNotActive;
        return &self.reader_impl.interface;
    }

    pub fn lastError(self: *const BlobDownloadStream) ?anyerror {
        return self.reader_impl.failure;
    }

    /// Drains and validates the response, then releases the HTTP connection.
    pub fn finish(self: *BlobDownloadStream) !void {
        if (self.state != .active) return error.BlobDownloadNotActive;
        var buffer: [copy_buffer_size]u8 = undefined;
        while (true) {
            const count = self.reader_impl.interface.readSliceShort(&buffer) catch {
                self.operation.abort();
                const failure = self.reader_impl.failure orelse error.ReadFailed;
                self.state = if (failure == error.OperationCancelled)
                    .cancelled
                else
                    .aborted;
                return failure;
            };
            if (count == 0) break;
        }
        if (self.reader_impl.failure) |failure| {
            self.operation.abort();
            self.state = if (failure == error.OperationCancelled)
                .cancelled
            else
                .aborted;
            return failure;
        }
        self.operation.finish() catch |err| {
            self.state = .aborted;
            return err;
        };
        self.state = .finished;
    }

    pub fn computedDigest(
        self: *const BlobDownloadStream,
    ) ![digest_mod.sha256_formatted_length]u8 {
        if (!self.reader_impl.complete) return error.BlobDownloadIncomplete;
        if (self.reader_impl.failure) |failure| return failure;
        return self.reader_impl.computed_digest;
    }

    pub fn decodedLength(self: *const BlobDownloadStream) u64 {
        return self.reader_impl.total;
    }

    pub fn abort(self: *BlobDownloadStream) void {
        if (self.state != .active) return;
        self.operation.abort();
        self.state = .aborted;
    }

    pub fn cancel(self: *BlobDownloadStream) void {
        if (self.state != .active) return;
        self.operation.cancel();
        self.reader_impl.failure = error.OperationCancelled;
        self.state = .cancelled;
    }

    pub fn deinit(self: *BlobDownloadStream) void {
        self.operation.deinit();
        if (self.reader_impl.service_digest) |value| self.allocator.free(value);
        self.allocator.free(self.digest);
        self.* = undefined;
    }
};

const ValidatingReader = struct {
    interface: std.Io.Reader,
    operation: *core.http.HttpOperation,
    source: *std.Io.Reader,
    requested_digest: []const u8,
    service_digest: ?[]u8,
    expected_length: ?u64,
    cancellation: ?*const core.http.CancellationToken,
    hasher: digest_mod.Sha256Digest = .{},
    computed_digest: [digest_mod.sha256_formatted_length]u8 = undefined,
    total: u64 = 0,
    complete: bool = false,
    failure: ?anyerror = null,

    fn init(
        operation: *core.http.HttpOperation,
        requested_digest: []const u8,
        service_digest: ?[]u8,
        expected_length: ?u64,
        cancellation: ?*const core.http.CancellationToken,
    ) ValidatingReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .operation = operation,
            .source = operation.body_reader,
            .requested_digest = requested_digest,
            .service_digest = service_digest,
            .expected_length = expected_length,
            .cancellation = cancellation,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *ValidatingReader = @alignCast(@fieldParentPtr("interface", interface));
        if (self.failure != null) return error.ReadFailed;
        if (self.complete) return error.EndOfStream;
        self.checkCancellation() catch return error.ReadFailed;

        var buffer: [copy_buffer_size]u8 = undefined;
        const read_limit = limit.minInt(buffer.len);
        if (read_limit == 0) return 0;
        const count = readSome(self.source, buffer[0..read_limit]) catch |err| {
            self.failure = switch (err) {
                error.ReadFailed => self.operation.bodyError() orelse error.ReadFailed,
            };
            return error.ReadFailed;
        };
        if (count == 0) {
            self.completeAndValidate() catch return error.ReadFailed;
            return error.EndOfStream;
        }
        if (self.expected_length) |expected| {
            if (self.total > expected or count > expected - self.total) {
                self.failure = error.ContentLengthMismatch;
                return error.ReadFailed;
            }
        }
        self.checkCancellation() catch return error.ReadFailed;
        try writer.writeAll(buffer[0..count]);
        self.hasher.update(buffer[0..count]);
        self.total += count;
        return count;
    }

    fn checkCancellation(self: *ValidatingReader) !void {
        if (self.cancellation) |token| {
            if (token.isCancelled()) {
                self.operation.cancel();
                self.failure = error.OperationCancelled;
                return error.OperationCancelled;
            }
        }
    }

    fn completeAndValidate(self: *ValidatingReader) !void {
        if (self.expected_length) |expected| {
            if (self.total != expected) {
                self.failure = error.ContentLengthMismatch;
                return error.ContentLengthMismatch;
            }
        }
        self.computed_digest = self.hasher.final();
        if (!std.ascii.eqlIgnoreCase(&self.computed_digest, self.requested_digest)) {
            self.failure = error.RequestedDigestMismatch;
            return error.RequestedDigestMismatch;
        }
        if (self.service_digest) |service_digest| {
            if (!std.ascii.eqlIgnoreCase(&self.computed_digest, service_digest)) {
                self.failure = error.DigestMismatch;
                return error.DigestMismatch;
            }
        }
        self.complete = true;
    }
};

/// High-level, digest-safe blob downloader for one ACR repository.
pub const BlobDownloadClient = struct {
    allocator: std.mem.Allocator,
    repository_name: []u8,
    registry_client: client_mod.ContainerRegistryClient,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        repository_name: []const u8,
        options: BlobDownloadClientOptions,
    ) !BlobDownloadClient {
        try validateRepositoryName(repository_name);
        const owned_repository = try allocator.dupe(u8, repository_name);
        errdefer allocator.free(owned_repository);
        const registry_client = try client_mod.ContainerRegistryClient.init(
            allocator,
            endpoint,
            options,
        );
        return .{
            .allocator = allocator,
            .repository_name = owned_repository,
            .registry_client = registry_client,
        };
    }

    pub fn deinit(self: *BlobDownloadClient) void {
        self.registry_client.deinit();
        self.allocator.free(self.repository_name);
        self.* = undefined;
    }

    pub fn downloadBlob(
        self: *BlobDownloadClient,
        digest: []const u8,
        options: BufferedBlobDownloadOptions,
    ) !DownloadedBlob {
        var result = try self.downloadBlobResult(digest, options);
        return result.unwrap(error.BlobDownloadFailed);
    }

    /// Buffers a blob only up to `options.max_size`.
    pub fn downloadBlobResult(
        self: *BlobDownloadClient,
        digest: []const u8,
        options: BufferedBlobDownloadOptions,
    ) !BufferedBlobDownloadResponse {
        const opened = try self.downloadBlobStreamingResult(digest, .{
            .cancellation = options.cancellation,
        });
        switch (opened) {
            .err => |failure| return .{ .err = failure },
            .ok => |stream_value| {
                var stream = stream_value;
                defer stream.deinit();

                if (stream.decoded_content_length) |length| {
                    if (length > options.max_size) return error.BlobTooLarge;
                }

                var body: std.ArrayList(u8) = .empty;
                defer body.deinit(self.allocator);
                if (stream.decoded_content_length) |length| {
                    const capacity: usize = @intCast(length);
                    if (capacity > 0) {
                        try body.ensureTotalCapacityPrecise(self.allocator, capacity);
                    }
                }

                const reader = try stream.reader();
                var buffer: [copy_buffer_size]u8 = undefined;
                while (true) {
                    const count = reader.readSliceShort(&buffer) catch
                        return stream.lastError() orelse error.ReadFailed;
                    if (count == 0) break;
                    if (count > options.max_size -| body.items.len)
                        return error.BlobTooLarge;
                    try body.appendSlice(self.allocator, buffer[0..count]);
                }
                try stream.finish();
                const computed = try stream.computedDigest();
                const owned_digest = try self.allocator.dupe(u8, &computed);
                errdefer self.allocator.free(owned_digest);
                return .{ .ok = .{
                    .allocator = self.allocator,
                    .bytes = try body.toOwnedSlice(self.allocator),
                    .digest = owned_digest,
                } };
            },
        }
    }

    pub fn downloadBlobStreaming(
        self: *BlobDownloadClient,
        digest: []const u8,
        options: StreamingBlobDownloadOptions,
    ) !BlobDownloadStream {
        var result = try self.downloadBlobStreamingResult(digest, options);
        return result.unwrap(error.BlobDownloadFailed);
    }

    /// Opens a single-owner validating stream. Call `finish`, `abort`, or
    /// `cancel`, then always call `deinit`.
    pub fn downloadBlobStreamingResult(
        self: *BlobDownloadClient,
        requested_digest: []const u8,
        options: StreamingBlobDownloadOptions,
    ) !StreamingBlobDownloadResponse {
        try digest_mod.validateSha256Digest(requested_digest);
        try checkCancellation(options.cancellation);

        const url = try self.buildBlobUrl(requested_digest);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("Accept", "application/octet-stream");

        const operation = try self.pipeline().open(
            &request,
            .{ .cancellation = options.cancellation },
        );
        var operation_owned = true;
        defer if (operation_owned) operation.deinit();
        if (operation.status_code != 200) {
            if (operation.isSuccess()) return error.UnexpectedResponseStatus;
            return .{ .err = try self.serviceErrorFromOperation(operation) };
        }

        const content_length = try requiredContentLength(self.allocator, operation);
        const encoding = try responseBodyEncoding(self.allocator, operation);
        const expected_decoded_length = switch (encoding) {
            .identity => content_length,
            .encoded => null,
        };
        const service_digest = try serviceDigest(
            self.allocator,
            operation,
            requested_digest,
        );

        const stream = try BlobDownloadStream.init(
            self.allocator,
            operation,
            requested_digest,
            service_digest,
            content_length,
            expected_decoded_length,
            options.cancellation,
        );
        operation_owned = false;
        return .{ .ok = stream };
    }

    pub fn downloadBlobToWriter(
        self: *BlobDownloadClient,
        digest: []const u8,
        writer: *std.Io.Writer,
        options: DownloadBlobToWriterOptions,
    ) !BlobDownloadDetails {
        var result = try self.downloadBlobToWriterResult(digest, writer, options);
        return result.unwrap(error.BlobDownloadFailed);
    }

    /// Downloads sequential ranges. Only bytes accepted by `writer.writeAll`
    /// advance the confirmed offset and digest, so read/transport retries
    /// resume without duplicating confirmed output.
    pub fn downloadBlobToWriterResult(
        self: *BlobDownloadClient,
        requested_digest: []const u8,
        writer: *std.Io.Writer,
        options: DownloadBlobToWriterOptions,
    ) !DownloadBlobToWriterResponse {
        try digest_mod.validateSha256Digest(requested_digest);
        if (options.range_size == 0) return error.InvalidRangeSize;
        try checkCancellation(options.cancellation);

        var hasher = digest_mod.Sha256Digest{};
        var confirmed: u64 = 0;
        var total_size: ?u64 = null;
        var retries: u32 = 0;

        while (total_size == null or confirmed < total_size.?) {
            try checkCancellation(options.cancellation);
            const request_end = rangeEnd(confirmed, options.range_size, total_size);
            var operation = self.openRange(
                requested_digest,
                confirmed,
                request_end,
                options.cancellation,
            ) catch |err| {
                if (isRetryableDownloadError(err) and retries < options.max_retries) {
                    retries += 1;
                    continue;
                }
                return err;
            };
            var operation_owned = true;
            defer if (operation_owned) operation.deinit();

            if (isRetryableStatus(operation.status_code) and
                retries < options.max_retries)
            {
                operation.abort();
                operation.deinit();
                operation_owned = false;
                retries += 1;
                continue;
            }

            switch (operation.status_code) {
                200 => {
                    if (confirmed != 0) return error.RangeNotHonored;
                    _ = try serviceDigest(
                        self.allocator,
                        operation,
                        requested_digest,
                    );
                    const content_length = try requiredContentLength(
                        self.allocator,
                        operation,
                    );
                    const encoding = try responseBodyEncoding(self.allocator, operation);
                    const expected_length: ?u64 = switch (encoding) {
                        .identity => content_length,
                        .encoded => null,
                    };
                    if (expected_length) |length| total_size = length;

                    copyOperationBody(
                        operation,
                        writer,
                        &hasher,
                        &confirmed,
                        expected_length,
                        options.cancellation,
                    ) catch |err| {
                        operation.abort();
                        operation.deinit();
                        operation_owned = false;
                        if (isRetryableDownloadError(err) and
                            retries < options.max_retries)
                        {
                            retries += 1;
                            continue;
                        }
                        return err;
                    };
                    operation.finish() catch |err| {
                        operation.deinit();
                        operation_owned = false;
                        if (isRetryableDownloadError(err) and
                            retries < options.max_retries)
                        {
                            retries += 1;
                            continue;
                        }
                        return err;
                    };
                    operation.deinit();
                    operation_owned = false;
                    total_size = confirmed;
                    break;
                },
                206 => {
                    if (try responseBodyEncoding(self.allocator, operation) != .identity)
                        return error.EncodedRangeResponse;
                    const content_range = try requiredContentRange(
                        self.allocator,
                        operation,
                    );
                    const parsed = try parseSatisfiedContentRange(content_range);
                    if (parsed.start != confirmed) return error.ContentRangeOffsetMismatch;
                    if (parsed.end > request_end) return error.ContentRangeOutsideRequest;
                    if (total_size) |known_total| {
                        if (parsed.total != known_total) return error.TotalSizeMismatch;
                    } else {
                        total_size = parsed.total;
                    }
                    const span = parsed.end - parsed.start + 1;
                    if (try requiredContentLength(self.allocator, operation) != span)
                        return error.ContentLengthMismatch;
                    _ = try serviceDigest(
                        self.allocator,
                        operation,
                        requested_digest,
                    );

                    copyOperationBody(
                        operation,
                        writer,
                        &hasher,
                        &confirmed,
                        span,
                        options.cancellation,
                    ) catch |err| {
                        operation.abort();
                        operation.deinit();
                        operation_owned = false;
                        if (isRetryableDownloadError(err) and
                            retries < options.max_retries)
                        {
                            retries += 1;
                            continue;
                        }
                        return err;
                    };
                    operation.finish() catch |err| {
                        operation.deinit();
                        operation_owned = false;
                        if (isRetryableDownloadError(err) and
                            retries < options.max_retries)
                        {
                            retries += 1;
                            continue;
                        }
                        return err;
                    };
                    operation.deinit();
                    operation_owned = false;
                    retries = 0;
                },
                416 => {
                    const content_range = try requiredContentRange(
                        self.allocator,
                        operation,
                    );
                    const parsed_total = try parseUnsatisfiedContentRange(content_range);
                    if (total_size) |known_total| {
                        if (parsed_total != known_total) return error.TotalSizeMismatch;
                    }
                    if (confirmed != parsed_total) return error.RangeNotSatisfiable;
                    if (try optionalContentLength(self.allocator, operation)) |length| {
                        if (length != 0) return error.ContentLengthMismatch;
                    }
                    _ = try serviceDigest(
                        self.allocator,
                        operation,
                        requested_digest,
                    );
                    try ensureEmptyBody(operation, options.cancellation);
                    try operation.finish();
                    operation.deinit();
                    operation_owned = false;
                    total_size = parsed_total;
                    break;
                },
                else => {
                    if (operation.isSuccess()) return error.UnexpectedResponseStatus;
                    const failure = try self.serviceErrorFromOperation(operation);
                    operation.deinit();
                    operation_owned = false;
                    return .{ .err = failure };
                },
            }
        }

        const computed = hasher.final();
        if (!std.ascii.eqlIgnoreCase(&computed, requested_digest))
            return error.RequestedDigestMismatch;
        const owned_digest = try self.allocator.dupe(u8, &computed);
        return .{ .ok = .{
            .allocator = self.allocator,
            .digest = owned_digest,
            .size = total_size orelse confirmed,
        } };
    }

    fn pipeline(self: *BlobDownloadClient) *core.pipeline.HttpPipeline {
        return &self.registry_client.protocolClient().pipeline;
    }

    fn buildBlobUrl(
        self: *BlobDownloadClient,
        digest: []const u8,
    ) ![]u8 {
        const protocol_client = self.registry_client.protocolClient();
        const repository = try core.url.encodeRepositoryName(
            self.allocator,
            self.repository_name,
        );
        defer self.allocator.free(repository);
        const encoded_digest = try core.url.encodePathSegment(
            self.allocator,
            digest,
        );
        defer self.allocator.free(encoded_digest);
        const api_version = try core.url.percentEncode(
            self.allocator,
            protocol_client.api_version,
        );
        defer self.allocator.free(api_version);
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/v2/{s}/blobs/{s}?api-version={s}",
            .{
                protocol_client.endpoint,
                repository,
                encoded_digest,
                api_version,
            },
        );
    }

    fn openRange(
        self: *BlobDownloadClient,
        digest: []const u8,
        start: u64,
        end: u64,
        cancellation: ?*const core.http.CancellationToken,
    ) !*core.http.HttpOperation {
        const url = try self.buildBlobUrl(digest);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("Accept", "application/octet-stream");
        try request.setHeader("Accept-Encoding", "identity");
        var range_buffer: [96]u8 = undefined;
        const range = try std.fmt.bufPrint(
            &range_buffer,
            "bytes={d}-{d}",
            .{ start, end },
        );
        try request.setHeader("Range", range);
        return self.pipeline().open(
            &request,
            .{ .cancellation = cancellation },
        );
    }

    fn serviceErrorFromOperation(
        self: *BlobDownloadClient,
        operation: *core.http.HttpOperation,
    ) !service_error.ServiceError {
        const reader = try operation.reader();
        const body = reader.allocRemaining(
            self.allocator,
            .limited(max_error_body_size),
        ) catch |err| switch (err) {
            error.ReadFailed => return operation.bodyError() orelse error.ReadFailed,
            error.StreamTooLong => return error.ErrorResponseTooLarge,
            else => |other| return other,
        };
        var response = core.http.Response{
            .status_code = operation.status_code,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = body,
            .allocator = self.allocator,
        };
        defer response.deinit();
        var failure = try service_error.ServiceError.fromResponse(
            self.allocator,
            &response,
        );
        errdefer failure.deinit();
        try operation.finish();
        return failure;
    }
};

const ResponseBodyEncoding = enum {
    identity,
    encoded,
};

fn responseBodyEncoding(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !ResponseBodyEncoding {
    const values = try operation.getHeaderValues(allocator, "Content-Encoding");
    defer allocator.free(values);
    if (values.len == 0) return .identity;

    var saw_encoding = false;
    var encoded = false;
    for (values) |value| {
        var encodings = std.mem.splitScalar(u8, value, ',');
        while (encodings.next()) |raw_encoding| {
            const encoding = std.mem.trim(u8, raw_encoding, " \t");
            if (encoding.len == 0) return error.InvalidContentEncoding;
            saw_encoding = true;
            if (!std.ascii.eqlIgnoreCase(encoding, "identity")) encoded = true;
        }
    }
    if (!saw_encoding) return error.InvalidContentEncoding;
    return if (encoded) .encoded else .identity;
}

fn requiredContentLength(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !u64 {
    return (try optionalContentLength(allocator, operation)) orelse
        error.MissingContentLength;
}

fn optionalContentLength(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !?u64 {
    const values = try operation.getHeaderValues(allocator, "Content-Length");
    defer allocator.free(values);
    if (values.len == 0) return null;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) return error.InvalidContentLength;
    return std.fmt.parseInt(u64, values[0], 10) catch
        return error.InvalidContentLength;
}

fn requiredContentRange(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) ![]const u8 {
    const values = try operation.getHeaderValues(allocator, "Content-Range");
    defer allocator.free(values);
    if (values.len == 0) return error.MissingContentRange;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) return error.InvalidContentRange;
    return values[0];
}

fn serviceDigest(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    requested_digest: []const u8,
) !?[]const u8 {
    const values = try operation.getHeaderValues(
        allocator,
        "Docker-Content-Digest",
    );
    defer allocator.free(values);
    if (values.len == 0) return null;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    try digest_mod.validateSha256Digest(values[0]);
    if (!(try digest_mod.sha256DigestsEqual(values[0], requested_digest)))
        return error.ServiceDigestMismatch;
    return values[0];
}

const SatisfiedContentRange = struct {
    start: u64,
    end: u64,
    total: u64,
};

fn parseSatisfiedContentRange(value: []const u8) !SatisfiedContentRange {
    if (value.len < "bytes 0-0/1".len or
        !std.ascii.eqlIgnoreCase(value[0.."bytes ".len], "bytes "))
    {
        return error.InvalidContentRange;
    }
    const range_and_total = value["bytes ".len..];
    const slash = std.mem.indexOfScalar(u8, range_and_total, '/') orelse
        return error.InvalidContentRange;
    if (slash == 0 or slash + 1 == range_and_total.len)
        return error.InvalidContentRange;
    const range = range_and_total[0..slash];
    const total_text = range_and_total[slash + 1 ..];
    if (std.mem.indexOfScalar(u8, total_text, '*') != null)
        return error.InvalidContentRange;
    const dash = std.mem.indexOfScalar(u8, range, '-') orelse
        return error.InvalidContentRange;
    if (dash == 0 or dash + 1 == range.len) return error.InvalidContentRange;
    const start = std.fmt.parseInt(u64, range[0..dash], 10) catch
        return error.InvalidContentRange;
    const end = std.fmt.parseInt(u64, range[dash + 1 ..], 10) catch
        return error.InvalidContentRange;
    const total = std.fmt.parseInt(u64, total_text, 10) catch
        return error.InvalidContentRange;
    if (start > end or total == 0 or end >= total)
        return error.InvalidContentRange;
    return .{ .start = start, .end = end, .total = total };
}

fn parseUnsatisfiedContentRange(value: []const u8) !u64 {
    if (value.len <= "bytes */".len or
        !std.ascii.eqlIgnoreCase(value[0.."bytes */".len], "bytes */"))
    {
        return error.InvalidContentRange;
    }
    return std.fmt.parseInt(u64, value["bytes */".len..], 10) catch
        return error.InvalidContentRange;
}

fn rangeEnd(start: u64, range_size: usize, total_size: ?u64) u64 {
    const size_minus_one: u64 = @intCast(range_size - 1);
    const uncapped = std.math.add(u64, start, size_minus_one) catch
        std.math.maxInt(u64);
    if (total_size) |total| {
        if (total == 0) return 0;
        return @min(uncapped, total - 1);
    }
    return uncapped;
}

fn copyOperationBody(
    operation: *core.http.HttpOperation,
    writer: *std.Io.Writer,
    hasher: *digest_mod.Sha256Digest,
    confirmed: *u64,
    expected_length: ?u64,
    cancellation: ?*const core.http.CancellationToken,
) !void {
    const reader = try operation.reader();
    var copied: u64 = 0;
    var buffer: [copy_buffer_size]u8 = undefined;
    while (expected_length == null or copied < expected_length.?) {
        try checkCancellationAndCancel(cancellation, operation);
        const limit = if (expected_length) |expected|
            @min(buffer.len, @as(usize, @intCast(expected - copied)))
        else
            buffer.len;
        const count = readSome(reader, buffer[0..limit]) catch
            return operation.bodyError() orelse error.ReadFailed;
        if (count == 0) {
            if (expected_length != null) return error.UnexpectedEndOfStream;
            return;
        }
        try checkCancellationAndCancel(cancellation, operation);
        try writer.writeAll(buffer[0..count]);
        hasher.update(buffer[0..count]);
        confirmed.* += count;
        copied += count;
    }

    var extra: [1]u8 = undefined;
    const extra_count = readSome(reader, &extra) catch
        return operation.bodyError() orelse error.ReadFailed;
    if (extra_count != 0) return error.ContentLengthMismatch;
}

fn ensureEmptyBody(
    operation: *core.http.HttpOperation,
    cancellation: ?*const core.http.CancellationToken,
) !void {
    try checkCancellationAndCancel(cancellation, operation);
    const reader = try operation.reader();
    var extra: [1]u8 = undefined;
    const count = readSome(reader, &extra) catch
        return operation.bodyError() orelse error.ReadFailed;
    if (count != 0) return error.ContentLengthMismatch;
}

fn readSome(reader: *std.Io.Reader, buffer: []u8) error{ReadFailed}!usize {
    if (buffer.len == 0) return 0;
    var writer = std.Io.Writer.fixed(buffer);
    return reader.stream(&writer, .limited(buffer.len)) catch |err| switch (err) {
        error.EndOfStream => 0,
        error.ReadFailed => error.ReadFailed,
        error.WriteFailed => error.ReadFailed,
    };
}

fn checkCancellation(
    cancellation: ?*const core.http.CancellationToken,
) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

fn checkCancellationAndCancel(
    cancellation: ?*const core.http.CancellationToken,
    operation: *core.http.HttpOperation,
) !void {
    checkCancellation(cancellation) catch |err| {
        operation.cancel();
        return err;
    };
}

pub fn isRetryableDownloadError(err: anyerror) bool {
    return switch (err) {
        error.ReadFailed,
        error.UnexpectedEndOfStream,
        error.ConnectionResetByPeer,
        error.ConnectionTimedOut,
        error.ConnectionRefused,
        error.NetworkUnreachable,
        error.HostUnreachable,
        error.TemporaryNameServerFailure,
        error.NameServerFailure,
        error.BrokenPipe,
        error.SocketNotConnected,
        error.WouldBlock,
        => true,
        else => false,
    };
}

pub fn isRetryableStatus(status_code: u16) bool {
    return status_code == 408 or status_code == 429 or
        status_code == 500 or status_code == 502 or
        status_code == 503 or status_code == 504;
}

fn validateRepositoryName(repository_name: []const u8) !void {
    if (repository_name.len == 0) return error.RepositoryNameRequired;
    if (repository_name.len > 255) return error.RepositoryNameTooLong;
    if (repository_name[0] == '/' or repository_name[repository_name.len - 1] == '/')
        return error.InvalidRepositoryName;

    var previous_slash = false;
    for (repository_name) |byte| {
        if (byte == '/') {
            if (previous_slash) return error.InvalidRepositoryName;
            previous_slash = true;
            continue;
        }
        previous_slash = false;
        if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and
            byte != '.' and byte != '_' and byte != '-')
        {
            return error.InvalidRepositoryName;
        }
    }
}
