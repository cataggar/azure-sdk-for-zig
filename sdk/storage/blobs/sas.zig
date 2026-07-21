//! Complete-URL SAS Blob uploads without credentials or retry policies.
const std = @import("std");
const core = @import("azure_core");
const storage_common = @import("azure_storage_common");

const sas = storage_common.sas;

/// The default cutoff for one `Put Blob` request. Larger sources use ordered
/// `Put Block` requests followed by a `Put Block List` commit.
pub const default_single_upload_max_bytes: u64 = 256 * 1024 * 1024;
/// The largest single-request `Put Blob` upload this client permits.
pub const max_single_upload_bytes: u64 = 5_000 * 1024 * 1024;
/// The default bounded block size for uploads above the single-request limit.
pub const default_block_size: u64 = 4 * 1024 * 1024;
/// The largest block size accepted by this client.
pub const max_block_size: u64 = 100 * 1024 * 1024;
/// Azure Blob Storage permits at most this many uncommitted blocks per blob.
pub const max_block_count: u64 = 50_000;
pub const max_upload_bytes: u64 = max_block_size * max_block_count;
pub const storage_api_version = "2024-11-04";

/// A borrowed reader with an exact byte length. The reader is consumed once;
/// this client never retries or rewinds it.
pub const BorrowedReaderSource = struct {
    reader: *std.Io.Reader,
    size: u64,
};

/// An upload source. Byte slices and paths are borrowed for the duration of
/// `upload`; a file is opened once and streamed, never whole-buffered.
pub const BlobUploadSource = union(enum) {
    bytes: []const u8,
    file: []const u8,
    reader: BorrowedReaderSource,

    pub fn kind(self: BlobUploadSource) BlobUploadSourceKind {
        return switch (self) {
            .bytes => .bytes,
            .file => .file,
            .reader => .reader,
        };
    }
};

pub const BlobUploadSourceKind = enum {
    bytes,
    file,
    reader,
};

pub const BlobUploadOptions = struct {
    content_type: []const u8 = "application/octet-stream",
    /// Sources at or below this size use one streaming `Put Blob` request.
    /// Set to zero to always use blocks.
    single_upload_max_bytes: u64 = default_single_upload_max_bytes,
    /// Used only for block uploads. The client validates `1..max_block_size`
    /// and the resulting `max_block_count` before any transport operation.
    block_size: u64 = default_block_size,
};

pub const BlobUploadPhase = enum {
    put_blob,
    put_block,
    put_block_list,
};

/// A final Blob upload outcome. Received non-2xx responses are known not
/// accepted; errors after transport entry have unknown server-side outcome.
pub const BlobUploadOutcome = union(enum) {
    accepted: struct { status_code: u16 },
    rejected: struct {
        status_code: u16,
        phase: BlobUploadPhase,
    },
    unknown: struct {
        cause: anyerror,
        phase: BlobUploadPhase,
    },
    /// One or more blocks were accepted, but no block-list commit was sent.
    /// Retrying with the same deterministic block IDs is safe.
    incomplete: struct {
        cause: anyerror,
        phase: BlobUploadPhase,
        staged_blocks: u64,
    },

    pub fn isAccepted(self: BlobUploadOutcome) bool {
        return self == .accepted;
    }

    pub fn format(self: BlobUploadOutcome, writer: anytype) !void {
        switch (self) {
            .accepted => |value| try writer.print(
                "BlobUploadOutcome(accepted, status={d})",
                .{value.status_code},
            ),
            .rejected => |value| try writer.print(
                "BlobUploadOutcome(rejected, phase={s}, status={d})",
                .{ @tagName(value.phase), value.status_code },
            ),
            .unknown => |value| try writer.print(
                "BlobUploadOutcome(unknown, phase={s}, cause={s})",
                .{ @tagName(value.phase), @errorName(value.cause) },
            ),
            .incomplete => |value| try writer.print(
                "BlobUploadOutcome(incomplete, phase={s}, staged_blocks={d}, cause={s})",
                .{ @tagName(value.phase), value.staged_blocks, @errorName(value.cause) },
            ),
        }
    }
};

/// A Blob client constructed only from an allocator, a complete SAS URL, and
/// a transport. It deliberately has no credential or caller-supplied
/// pipeline: every request uses an empty-policy, no-redirect pipeline.
pub const SasBlobClient = struct {
    allocator: std.mem.Allocator,
    uri: sas.CompleteSasUri,
    transport: *core.http.HttpTransport,

    pub fn init(
        allocator: std.mem.Allocator,
        complete_sas_uri: []const u8,
        transport: *core.http.HttpTransport,
    ) !SasBlobClient {
        var uri = try sas.CompleteSasUri.init(allocator, complete_sas_uri);
        errdefer uri.deinit();
        if (!uri.hasAzureStorageServiceHost("blob"))
            return error.UnexpectedBlobSasHost;
        return .{
            .allocator = allocator,
            .uri = uri,
            .transport = transport,
        };
    }

    pub fn deinit(self: *SasBlobClient) void {
        self.uri.deinit();
        self.* = undefined;
    }

    /// Renders a query-redacted SAS URL only.
    pub fn format(self: SasBlobClient, writer: anytype) !void {
        try writer.print("SasBlobClient({f})", .{self.uri});
    }

    /// Uploads a known-size source. The method does not retry: a borrowed
    /// reader is one-shot, and file/byte sources are not replayed implicitly.
    pub fn upload(
        self: *SasBlobClient,
        source: BlobUploadSource,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        const source_size = try sourceSize(source);
        try validateOptions(source_size, options);

        if (source_size <= options.single_upload_max_bytes) {
            if (source == .bytes)
                return self.putBlobBytes(source.bytes, options);
            var opened = try OpenedSource.init(self.allocator, source, source_size);
            defer opened.deinit();
            return self.putBlob(opened.reader(), source_size, options);
        }

        // Allocate the complete ordered commit body before staging any block.
        // This avoids a local allocation failure after successful block puts.
        const commit_body = try makeBlockList(self.allocator, source_size, options.block_size);
        defer self.allocator.free(commit_body);

        var opened = try OpenedSource.init(self.allocator, source, source_size);
        defer opened.deinit();
        var remaining = source_size;
        var block_index: u64 = 0;
        while (remaining != 0) : (block_index += 1) {
            const block_length = @min(remaining, options.block_size);
            var block_reader = LimitedReader.init(opened.reader(), block_length);
            const block_id = blockId(block_index);
            const block_url = self.uri.appendProtocolQuery(self.allocator, &.{
                .{ .name = "comp", .value = "block" },
                .{ .name = "blockid", .value = &block_id },
            }) catch |err| return localFailureAfterBlocks(err, .put_block, block_index);
            defer self.allocator.free(block_url);

            var request = core.http.Request.init(self.allocator, .PUT, block_url);
            defer request.deinit();
            request.setHeader("Content-Type", "application/octet-stream") catch |err|
                return localFailureAfterBlocks(err, .put_block, block_index);
            request.setHeader("x-ms-version", storage_api_version) catch |err|
                return localFailureAfterBlocks(err, .put_block, block_index);
            const streaming_body: ?core.http.StreamingRequestBody = switch (source) {
                .bytes => |bytes| blk: {
                    const start: usize = @intCast(source_size - remaining);
                    const length: usize = @intCast(block_length);
                    request.body = bytes[start .. start + length];
                    break :blk null;
                },
                .file, .reader => .{
                    .reader = &block_reader.interface,
                    .content_length = block_length,
                },
            };
            const outcome = sas.send(self.transport, &request, streaming_body) catch |err|
                return localFailureAfterBlocks(err, .put_block, block_index);
            switch (outcome) {
                .accepted => {},
                else => return mapOutcome(outcome, .put_block),
            }
            remaining -= block_length;
        }

        // Each limited block reader hides its following source bytes from the
        // transport's exact-length probe. Verify the source's advertised
        // length once all blocks have been consumed.
        if (source != .bytes) {
            ensureExhausted(opened.reader()) catch |err|
                return localFailureAfterBlocks(err, .put_block_list, block_index);
        }

        const commit_url = self.uri.appendProtocolQuery(self.allocator, &.{
            .{ .name = "comp", .value = "blocklist" },
        }) catch |err| return localFailureAfterBlocks(err, .put_block_list, block_index);
        defer self.allocator.free(commit_url);
        var request = core.http.Request.init(self.allocator, .PUT, commit_url);
        defer request.deinit();
        request.setHeader("Content-Type", "application/xml") catch |err|
            return localFailureAfterBlocks(err, .put_block_list, block_index);
        request.setHeader("x-ms-version", storage_api_version) catch |err|
            return localFailureAfterBlocks(err, .put_block_list, block_index);
        request.setHeader("x-ms-blob-content-type", options.content_type) catch |err|
            return localFailureAfterBlocks(err, .put_block_list, block_index);
        request.body = commit_body;
        const outcome = sas.send(self.transport, &request, null) catch |err|
            return localFailureAfterBlocks(err, .put_block_list, block_index);
        return mapOutcome(outcome, .put_block_list);
    }

    pub fn uploadBytes(
        self: *SasBlobClient,
        bytes: []const u8,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        return self.upload(.{ .bytes = bytes }, options);
    }

    pub fn uploadFile(
        self: *SasBlobClient,
        path: []const u8,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        return self.upload(.{ .file = path }, options);
    }

    pub fn uploadReader(
        self: *SasBlobClient,
        reader: *std.Io.Reader,
        size: u64,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        return self.upload(.{ .reader = .{ .reader = reader, .size = size } }, options);
    }

    fn putBlob(
        self: *SasBlobClient,
        reader: *std.Io.Reader,
        size: u64,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        var request = core.http.Request.init(self.allocator, .PUT, self.uri.bytes);
        defer request.deinit();
        try request.setHeader("Content-Type", options.content_type);
        try request.setHeader("x-ms-blob-type", "BlockBlob");
        try request.setHeader("x-ms-version", storage_api_version);
        return mapOutcome(
            try sas.send(
                self.transport,
                &request,
                .{ .reader = reader, .content_length = size },
            ),
            .put_blob,
        );
    }

    fn putBlobBytes(
        self: *SasBlobClient,
        bytes: []const u8,
        options: BlobUploadOptions,
    ) !BlobUploadOutcome {
        var request = core.http.Request.init(self.allocator, .PUT, self.uri.bytes);
        defer request.deinit();
        try request.setHeader("Content-Type", options.content_type);
        try request.setHeader("x-ms-blob-type", "BlockBlob");
        try request.setHeader("x-ms-version", storage_api_version);
        request.body = bytes;
        return mapOutcome(try sas.send(self.transport, &request, null), .put_blob);
    }
};

/// Compatibility spelling emphasizing that `init` accepts a complete SAS URL.
pub const CompleteSasBlobClient = SasBlobClient;

fn mapOutcome(outcome: sas.RequestOutcome, phase: BlobUploadPhase) BlobUploadOutcome {
    return switch (outcome) {
        .accepted => |value| .{ .accepted = .{
            .status_code = value.status_code,
        } },
        .rejected => |value| .{ .rejected = .{
            .status_code = value.status_code,
            .phase = phase,
        } },
        .unknown => |value| .{ .unknown = .{
            .cause = value.cause,
            .phase = phase,
        } },
    };
}

fn localFailureAfterBlocks(
    cause: anyerror,
    phase: BlobUploadPhase,
    staged_blocks: u64,
) anyerror!BlobUploadOutcome {
    if (staged_blocks == 0) return cause;
    return .{ .incomplete = .{
        .cause = cause,
        .phase = phase,
        .staged_blocks = staged_blocks,
    } };
}

fn validateOptions(size: u64, options: BlobUploadOptions) !void {
    if (options.block_size == 0 or options.block_size > max_block_size)
        return error.InvalidBlobBlockSize;
    if (options.single_upload_max_bytes > max_single_upload_bytes)
        return error.InvalidBlobSingleUploadLimit;
    if (size > max_upload_bytes)
        return error.BlobUploadTooLarge;
    if (size > options.single_upload_max_bytes) {
        const blocks = blockCount(size, options.block_size);
        if (blocks > max_block_count)
            return error.BlobUploadTooLarge;
    }
}

fn blockCount(size: u64, block_size: u64) u64 {
    return (size / block_size) + @intFromBool(size % block_size != 0);
}

fn blockId(index: u64) [12]u8 {
    var decimal: [8]u8 = undefined;
    _ = std.fmt.bufPrint(&decimal, "{d:0>8}", .{index}) catch unreachable;
    var encoded: [12]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&encoded, &decimal);
    return encoded;
}

fn makeBlockList(
    allocator: std.mem.Allocator,
    size: u64,
    block_size: u64,
) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "<BlockList>");
    const count = blockCount(size, block_size);
    var index: u64 = 0;
    while (index < count) : (index += 1) {
        const id = blockId(index);
        try output.appendSlice(allocator, "<Latest>");
        try output.appendSlice(allocator, &id);
        try output.appendSlice(allocator, "</Latest>");
    }
    try output.appendSlice(allocator, "</BlockList>");
    return output.toOwnedSlice(allocator);
}

fn sourceSize(source: BlobUploadSource) !u64 {
    return switch (source) {
        .bytes => |bytes| @intCast(bytes.len),
        .file => |path| fileSize(path),
        .reader => |reader| reader.size,
    };
}

fn fileSize(path: []const u8) !u64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file) return error.BlobUploadSourceNotFile;
    return stat.size;
}

const FileSourceHandle = struct {
    allocator: std.mem.Allocator,
    threaded: std.Io.Threaded,
    file: std.Io.File,
    reader_impl: std.Io.File.Reader,
    buffer: [16 * 1024]u8 = undefined,

    fn deinit(self: *FileSourceHandle) void {
        self.file.close(self.threaded.io());
        self.allocator.destroy(self);
    }
};

const OpenedSource = union(enum) {
    bytes: struct { reader_impl: std.Io.Reader },
    file: *FileSourceHandle,
    borrowed: *std.Io.Reader,

    fn init(
        allocator: std.mem.Allocator,
        source: BlobUploadSource,
        expected_size: u64,
    ) !OpenedSource {
        return switch (source) {
            .bytes => |bytes| .{ .bytes = .{
                .reader_impl = std.Io.Reader.fixed(bytes),
            } },
            .reader => |source_reader| .{ .borrowed = source_reader.reader },
            .file => |path| blk: {
                const handle = try allocator.create(FileSourceHandle);
                errdefer allocator.destroy(handle);
                handle.* = .{
                    .allocator = allocator,
                    .threaded = .init_single_threaded,
                    .file = undefined,
                    .reader_impl = undefined,
                };
                const io = handle.threaded.io();
                handle.file = try std.Io.Dir.cwd().openFile(io, path, .{});
                errdefer handle.file.close(io);
                const stat = try handle.file.stat(io);
                if (stat.kind != .file) return error.BlobUploadSourceNotFile;
                if (stat.size != expected_size) return error.BlobUploadSourceChanged;
                handle.reader_impl = handle.file.readerStreaming(io, &handle.buffer);
                break :blk .{ .file = handle };
            },
        };
    }

    fn reader(self: *OpenedSource) *std.Io.Reader {
        return switch (self.*) {
            .bytes => |*bytes| &bytes.reader_impl,
            .file => |file| &file.reader_impl.interface,
            .borrowed => |source_reader| source_reader,
        };
    }

    fn deinit(self: *OpenedSource) void {
        switch (self.*) {
            .file => |file| file.deinit(),
            .bytes, .borrowed => {},
        }
    }
};

/// Restricts one `Put Block` request to its assigned bytes without consuming
/// the first byte of the next block during the transport's length check.
const LimitedReader = struct {
    interface: std.Io.Reader,
    source: *std.Io.Reader,
    remaining: u64,
    buffer: [16 * 1024]u8 = undefined,
    buffered_start: usize = 0,
    buffered_end: usize = 0,

    fn init(source: *std.Io.Reader, remaining: u64) LimitedReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .source = source,
            .remaining = remaining,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *LimitedReader = @alignCast(@fieldParentPtr("interface", interface));
        if (self.buffered_start == self.buffered_end) {
            if (self.remaining == 0) return error.EndOfStream;
            const wanted: usize = @intCast(@min(self.remaining, self.buffer.len));
            const count = self.source.readSliceShort(self.buffer[0..wanted]) catch
                return error.ReadFailed;
            if (count == 0) return error.EndOfStream;
            self.remaining -= count;
            self.buffered_start = 0;
            self.buffered_end = count;
        }
        const written = writer.write(
            limit.slice(self.buffer[self.buffered_start..self.buffered_end]),
        ) catch return error.WriteFailed;
        self.buffered_start += written;
        return written;
    }
};

fn ensureExhausted(reader: *std.Io.Reader) !void {
    var extra: [1]u8 = undefined;
    if (try reader.readSliceShort(&extra) != 0)
        return error.RequestBodyTooLong;
}

const CommitFailureTransport = struct {
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,
    fail_on_call: usize,
    call_count: usize = 0,
    operation: core.http.HttpOperation = undefined,
    response_reader: std.Io.Reader = undefined,

    fn init(allocator: std.mem.Allocator, fail_on_call: usize) CommitFailureTransport {
        return .{
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
            .fail_on_call = fail_on_call,
        };
    }

    fn asTransport(self: *CommitFailureTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(
        _: *core.http.HttpTransport,
        _: *core.http.Request,
    ) !core.http.Response {
        return error.TestUnexpectedSend;
    }

    fn openImpl(
        transport: *core.http.HttpTransport,
        _: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *CommitFailureTransport = @alignCast(@fieldParentPtr("transport", transport));
        self.call_count += 1;
        if (self.call_count == self.fail_on_call)
            return error.InjectedCommitFailure;

        if (options.body) |body| {
            var buffer: [4 * 1024]u8 = undefined;
            while (try body.reader.readSliceShort(&buffer) != 0) {}
        }
        self.response_reader = std.Io.Reader.fixed("");
        self.operation = .{
            .status_code = 201,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body_reader = &self.response_reader,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &abortImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(_: *core.http.HttpOperation) !void {}

    fn abortImpl(_: *core.http.HttpOperation) void {}

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *CommitFailureTransport = @alignCast(@fieldParentPtr("operation", operation));
        self.operation.headers.deinit();
    }
};

const BoundedReadSource = struct {
    reader: std.Io.Reader,
    bytes: []const u8,
    offset: usize = 0,
    max_read_request: usize = 0,

    fn init(bytes: []const u8) BoundedReadSource {
        return .{
            .reader = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .bytes = bytes,
        };
    }

    fn stream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *BoundedReadSource = @alignCast(@fieldParentPtr("reader", reader));
        const requested = limit.minInt(std.math.maxInt(usize));
        self.max_read_request = @max(self.max_read_request, requested);
        if (self.offset == self.bytes.len) return error.EndOfStream;
        const count = @min(self.bytes.len - self.offset, requested);
        const written = writer.write(
            self.bytes[self.offset..][0..count],
        ) catch return error.WriteFailed;
        self.offset += written;
        return written;
    }
};

test "SAS blob upload preserves query, isolates credentials, and drains response" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "done");
    defer transport.deinit();
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=a%2Bb%3D&sp=rw",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.uploadBytes("payload", .{ .content_type = "text/plain" });
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqualStrings(
        "https://account.blob.core.windows.net/container/blob?sig=a%2Bb%3D&sp=rw",
        transport.last_url.?,
    );
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.last_redirect_policy.?);
    try std.testing.expectEqual(@as(usize, 1), transport.stream_finish_count);
    try std.testing.expectEqualStrings("payload", transport.last_body.?);
}

test "SAS blob byte uploads support buffered-only transports" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.transport.openFn = null;
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const single = try client.uploadBytes("payload", .{});
    try std.testing.expect(single.isAccepted());
    try std.testing.expectEqualStrings("payload", transport.last_body.?);

    const blocked = try client.uploadBytes("abcdefgh", .{
        .single_upload_max_bytes = 3,
        .block_size = 3,
    });
    try std.testing.expect(blocked.isAccepted());
    try std.testing.expectEqual(@as(usize, 5), transport.call_count);
    try std.testing.expectEqualStrings(
        "<BlockList><Latest>MDAwMDAwMDA=</Latest><Latest>MDAwMDAwMDE=</Latest><Latest>MDAwMDAwMDI=</Latest></BlockList>",
        transport.last_body.?,
    );
}

test "SAS blob block upload orders deterministic IDs and bounds reads" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.stream_upload_chunk_size = 2;
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sp=w&sig=opaque%2Bvalue",
        transport.asTransport(),
    );
    defer client.deinit();

    var reader = std.Io.Reader.fixed("abcdefgh");
    const outcome = try client.uploadReader(&reader, 8, .{
        .single_upload_max_bytes = 3,
        .block_size = 3,
    });
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqualStrings(
        "https://account.blob.core.windows.net/container/blob?sp=w&sig=opaque%2Bvalue&comp=blocklist",
        transport.last_url.?,
    );
    try std.testing.expectEqualStrings(
        "<BlockList><Latest>MDAwMDAwMDA=</Latest><Latest>MDAwMDAwMDE=</Latest><Latest>MDAwMDAwMDI=</Latest></BlockList>",
        transport.last_body.?,
    );
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
}

test "SAS blob returns known rejections and unknown transport outcomes" {
    const allocator = std.testing.allocator;
    var rejected_transport = core.http.MockTransport.init(allocator, 403, "denied");
    defer rejected_transport.deinit();
    var rejected_client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        rejected_transport.asTransport(),
    );
    defer rejected_client.deinit();
    const rejected = try rejected_client.uploadBytes("x", .{});
    switch (rejected) {
        .rejected => |value| {
            try std.testing.expectEqual(@as(u16, 403), value.status_code);
            try std.testing.expectEqual(BlobUploadPhase.put_blob, value.phase);
        },
        else => return error.TestUnexpectedResult,
    }

    var unknown_transport = core.http.MockTransport.init(allocator, 201, "");
    defer unknown_transport.deinit();
    unknown_transport.stream_fail_upload_after = 0;
    var unknown_client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        unknown_transport.asTransport(),
    );
    defer unknown_client.deinit();
    var unknown_reader = std.Io.Reader.fixed("x");
    const unknown = try unknown_client.uploadReader(&unknown_reader, 1, .{});
    switch (unknown) {
        .unknown => |value| try std.testing.expectEqual(BlobUploadPhase.put_blob, value.phase),
        else => return error.TestUnexpectedResult,
    }
}

test "SAS blob rejects a host-changing redirect without another request" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 302, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "Location", .value = "https://attacker.example/collect-sas" },
    };
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.uploadBytes("x", .{});
    switch (outcome) {
        .rejected => |value| try std.testing.expectEqual(@as(u16, 302), value.status_code),
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.last_redirect_policy.?);
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
}

test "SAS blob does not commit after an unknown commit transport failure" {
    const allocator = std.testing.allocator;
    var transport = CommitFailureTransport.init(allocator, 4);
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.uploadBytes("abcdefgh", .{
        .single_upload_max_bytes = 3,
        .block_size = 3,
    });
    switch (outcome) {
        .unknown => |value| {
            try std.testing.expectEqual(BlobUploadPhase.put_block_list, value.phase);
            try std.testing.expectEqual(error.InjectedCommitFailure, value.cause);
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
}

test "SAS blob block reader stays bounded and short sources are unknown" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{'x'} ** (64 * 1024 + 1);
    var source = BoundedReadSource.init(&bytes);
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.uploadReader(&source.reader, bytes.len, .{
        .single_upload_max_bytes = 0,
        .block_size = 32 * 1024,
    });
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expect(source.max_read_request <= 16 * 1024);
    try std.testing.expectEqual(bytes.len, source.offset);

    var short_reader = std.Io.Reader.fixed("short");
    const short = try client.uploadReader(&short_reader, 6, .{});
    switch (short) {
        .unknown => |value| try std.testing.expectEqual(BlobUploadPhase.put_blob, value.phase),
        else => return error.TestUnexpectedResult,
    }
}

test "SAS blob reports extra source data after staging as incomplete" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    var reader = std.Io.Reader.fixed("1234567");
    const outcome = try client.uploadReader(&reader, 6, .{
        .single_upload_max_bytes = 0,
        .block_size = 3,
    });
    switch (outcome) {
        .incomplete => |value| {
            try std.testing.expectEqual(@as(u64, 2), value.staged_blocks);
            try std.testing.expectEqual(error.RequestBodyTooLong, value.cause);
            try std.testing.expectEqual(BlobUploadPhase.put_block_list, value.phase);
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}

test "SAS blob validates limits and redacts diagnostics" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = try SasBlobClient.init(
        allocator,
        "https://account.blob.core.windows.net/container/blob?sig=secret",
        transport.asTransport(),
    );
    defer client.deinit();

    try std.testing.expectError(
        error.InvalidBlobBlockSize,
        client.uploadBytes("x", .{ .block_size = 0 }),
    );
    try std.testing.expectError(
        error.InvalidBlobSingleUploadLimit,
        client.uploadBytes("x", .{
            .single_upload_max_bytes = max_single_upload_bytes + 1,
        }),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);

    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.print("{f}", .{client});
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "?***") != null);
    try std.testing.expectError(
        error.UnexpectedBlobSasHost,
        SasBlobClient.init(
            allocator,
            "https://account.queue.core.windows.net/queue?sig=opaque",
            transport.asTransport(),
        ),
    );
}

fn blockListAllocationTest(allocator: std.mem.Allocator) !void {
    const body = try makeBlockList(allocator, 16 * 1024, 4 * 1024);
    defer allocator.free(body);
}

test "SAS blob block-list allocation failures clean up" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        blockListAllocationTest,
        .{},
    );
}
