//! Hand-written high-level convenience helpers layered on the generated Blob
//! Storage clients.
//!
//! These are kept out of `src/clients.zig` because that file is emitter-owned
//! and overwritten on regeneration (see the header in `src/clients_test.zig`).
//! This mirrors the `sas.zig` precedent for first-class hand-written features.
//!
//! Zig has no extension methods, so these are free functions that take a
//! pointer to the relevant generated sub-client (`Blob`, `Container`,
//! `BlockBlob`). Obtain those via `BlobClient.blob()`, `.container()`, and
//! `.blockBlob()`, having set the client endpoint to the target resource URL.

const std = @import("std");
const core = @import("azure_sdk_core");
const clients = @import("src/clients.zig");
const enums = @import("src/enums.zig");

pub const Blob = clients.Blob;
pub const Container = clients.Container;
pub const BlockBlob = clients.BlockBlob;

/// Default block size used by `uploadBlockBlob` when splitting large payloads
/// into staged blocks (4 MiB).
pub const default_block_size: u64 = 4 * 1024 * 1024;
/// Payloads at or below this size are uploaded with a single `Put Blob`
/// request; larger payloads are staged and committed as blocks (256 MiB).
pub const default_single_upload_max_bytes: u64 = 256 * 1024 * 1024;
/// Azure caps a block blob at 50,000 committed blocks.
pub const max_block_count: u64 = 50_000;

// ───────────────────────────── exists ─────────────────────────────

pub const ExistsOptions = struct {
    client_request_id: ?[]const u8 = null,
    lease_id: ?[]const u8 = null,
    snapshot: ?[]const u8 = null,
    version_id: ?[]const u8 = null,
    timeout: ?i32 = null,
};

/// Returns whether the blob exists.
///
/// Issues a `HEAD` (Get Blob Properties) and maps `200 => true`,
/// `404 => false`. Any other status is surfaced as `error.AzureRequestFailed`.
/// This is done with a direct request rather than the generated
/// `getProperties` because that helper collapses every non-200 status into a
/// single error, which cannot distinguish "not found" from a real failure.
pub fn blobExists(blob: *Blob, alloc: std.mem.Allocator, options: ExistsOptions) !bool {
    var url_buf: std.ArrayList(u8) = .empty;
    defer url_buf.deinit(alloc);
    try url_buf.appendSlice(alloc, blob.endpoint);
    var has_query = false;
    try appendQuery(alloc, &url_buf, &has_query, "snapshot", options.snapshot);
    try appendQuery(alloc, &url_buf, &has_query, "versionid", options.version_id);
    try appendQueryInt(alloc, &url_buf, &has_query, "timeout", options.timeout);
    const url = try url_buf.toOwnedSlice(alloc);
    defer alloc.free(url);

    return existsRequest(blob.pipeline, alloc, blob.api_version, url, options);
}

/// Returns whether the container exists. Issues a `HEAD` (Get Container
/// Properties) and maps `200 => true`, `404 => false`.
pub fn containerExists(container: *Container, alloc: std.mem.Allocator, options: ExistsOptions) !bool {
    var url_buf: std.ArrayList(u8) = .empty;
    defer url_buf.deinit(alloc);
    try url_buf.appendSlice(alloc, container.endpoint);
    try url_buf.appendSlice(alloc, "?restype=container");
    var has_query = true;
    try appendQueryInt(alloc, &url_buf, &has_query, "timeout", options.timeout);
    const url = try url_buf.toOwnedSlice(alloc);
    defer alloc.free(url);

    return existsRequest(container.pipeline, alloc, container.api_version, url, options);
}

fn existsRequest(
    pipeline: core.pipeline.HttpPipeline,
    alloc: std.mem.Allocator,
    api_version: []const u8,
    url: []const u8,
    options: ExistsOptions,
) !bool {
    var pl = pipeline;
    var req = core.http.Request.init(alloc, .HEAD, url);
    defer req.deinit();
    try req.setHeader("x-ms-version", api_version);
    if (options.client_request_id) |v| try req.setHeader("x-ms-client-request-id", v);
    if (options.lease_id) |v| try req.setHeader("x-ms-lease-id", v);

    var resp = try pl.send(&req);
    defer resp.deinit();
    return switch (resp.status_code) {
        200 => true,
        404 => false,
        else => {
            core.pager.logHttpError("blobExists", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        },
    };
}

// ─────────────────────────── download ─────────────────────────────

pub const DownloadOptions = struct {
    client_request_id: ?[]const u8 = null,
    lease_id: ?[]const u8 = null,
    snapshot: ?[]const u8 = null,
    version_id: ?[]const u8 = null,
    timeout: ?i32 = null,
    /// HTTP `Range` header value, e.g. `"bytes=0-1023"`.
    range: ?[]const u8 = null,
    if_match: ?[]const u8 = null,
    if_none_match: ?[]const u8 = null,
};

/// Alias kept for callers that used the original `downloadInto` option name.
pub const DownloadIntoOptions = DownloadOptions;

/// Full blob contents returned by `download`, owned by the caller.
pub const DownloadResult = struct {
    /// The downloaded bytes. Free with `deinit` (or `alloc.free(data)`).
    data: []u8,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *DownloadResult) void {
        self.alloc.free(self.data);
        self.* = undefined;
    }
};

/// Downloads the blob and returns its full contents in a newly allocated,
/// caller-owned buffer. Mirrors Rust `BlobClient::download`.
///
/// The caller owns the returned `DownloadResult` and must call `deinit` on it
/// (or free `result.data`). To stream into a caller-provided sink without an
/// intermediate owned copy, use `downloadInto` instead.
pub fn download(
    blob: *Blob,
    alloc: std.mem.Allocator,
    options: DownloadOptions,
) !DownloadResult {
    const url = try downloadUrl(alloc, blob, options);
    defer alloc.free(url);

    var pl = blob.pipeline;
    var req = core.http.Request.init(alloc, .GET, url);
    defer req.deinit();
    try setDownloadHeaders(&req, blob, options);

    var resp = try pl.send(&req);
    defer resp.deinit();
    switch (resp.status_code) {
        200, 206 => return .{ .data = try alloc.dupe(u8, resp.body), .alloc = alloc },
        else => {
            core.pager.logHttpError("download", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        },
    }
}

/// Downloads the blob and writes its bytes to `writer`, returning the number
/// of bytes written.
///
/// NOTE: this currently buffers the full response body in memory before
/// writing it out, because the core HTTP transport buffers response bodies
/// (`transport.Response.body` is a `[]const u8`) and does not yet expose a
/// streaming reader. The signature is intentionally stable: once core gains a
/// streaming response API, this can stream to `writer` without changing its
/// public shape (see the note in `src/clients.zig` about adopting the core
/// streaming response API).
pub fn downloadInto(
    blob: *Blob,
    alloc: std.mem.Allocator,
    writer: *std.Io.Writer,
    options: DownloadOptions,
) !u64 {
    const url = try downloadUrl(alloc, blob, options);
    defer alloc.free(url);

    var pl = blob.pipeline;
    var req = core.http.Request.init(alloc, .GET, url);
    defer req.deinit();
    try setDownloadHeaders(&req, blob, options);

    var resp = try pl.send(&req);
    defer resp.deinit();
    switch (resp.status_code) {
        200, 206 => {
            try writer.writeAll(resp.body);
            return resp.body.len;
        },
        else => {
            core.pager.logHttpError("downloadInto", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        },
    }
}

/// Builds the blob GET URL with the shared download query parameters. Caller
/// owns the returned slice.
fn downloadUrl(alloc: std.mem.Allocator, blob: *Blob, options: DownloadOptions) ![]u8 {
    var url_buf: std.ArrayList(u8) = .empty;
    errdefer url_buf.deinit(alloc);
    try url_buf.appendSlice(alloc, blob.endpoint);
    var has_query = false;
    try appendQuery(alloc, &url_buf, &has_query, "snapshot", options.snapshot);
    try appendQuery(alloc, &url_buf, &has_query, "versionid", options.version_id);
    try appendQueryInt(alloc, &url_buf, &has_query, "timeout", options.timeout);
    return url_buf.toOwnedSlice(alloc);
}

/// Applies the shared download request headers.
fn setDownloadHeaders(req: *core.http.Request, blob: *Blob, options: DownloadOptions) !void {
    try req.setHeader("x-ms-version", blob.api_version);
    if (options.client_request_id) |v| try req.setHeader("x-ms-client-request-id", v);
    if (options.range) |v| try req.setHeader("Range", v);
    if (options.lease_id) |v| try req.setHeader("x-ms-lease-id", v);
    if (options.if_match) |v| try req.setHeader("If-Match", v);
    if (options.if_none_match) |v| try req.setHeader("If-None-Match", v);
}

// ────────────────────────── uploadBlockBlob ───────────────────────

pub const BlockUploadOptions = struct {
    client_request_id: ?[]const u8 = null,
    /// Value for the committed blob's `Content-Type`. Defaults to
    /// `application/octet-stream`.
    content_type: ?[]const u8 = null,
    tier: ?enums.AccessTier = null,
    lease_id: ?[]const u8 = null,
    /// Block size for the staged-block path. Ignored when the payload fits in
    /// a single `Put Blob`.
    block_size: u64 = default_block_size,
    /// Payloads at or below this size use a single `Put Blob` request.
    single_upload_max_bytes: u64 = default_single_upload_max_bytes,
};

/// Uploads `data` to a block blob, automatically choosing between a single
/// `Put Blob` request (small payloads) and a staged `Put Block` +
/// `Put Block List` sequence (large payloads).
///
/// The requests are issued directly against the credentialed pipeline (rather
/// than the generated `BlockBlob` operations) so that only the HTTP status is
/// inspected. This mirrors the `sas.zig` upload helper and avoids the
/// generated result parsers, which require response headers that Azure omits
/// for many accounts (for example `x-ms-version-id` when blob versioning is
/// disabled, or `Content-MD5` on `Put Block`).
pub fn uploadBlockBlob(
    client: *BlockBlob,
    alloc: std.mem.Allocator,
    data: []const u8,
    options: BlockUploadOptions,
) !void {
    if (options.block_size == 0) return error.InvalidBlockSize;

    // All throwaway allocations (URLs, block ids, and the commit body) live in
    // one arena so nothing leaks regardless of which path or error occurs.
    var arena_state = std.heap.ArenaAllocator.init(alloc);
    defer arena_state.deinit();
    const a = arena_state.allocator();

    const content_type = options.content_type orelse "application/octet-stream";

    if (data.len <= options.single_upload_max_bytes) {
        var req = core.http.Request.init(a, .PUT, client.endpoint);
        defer req.deinit();
        try req.setHeader("x-ms-version", client.api_version);
        try req.setHeader("x-ms-blob-type", "BlockBlob");
        try req.setHeader("Content-Type", content_type);
        if (options.client_request_id) |v| try req.setHeader("x-ms-client-request-id", v);
        if (options.lease_id) |v| try req.setHeader("x-ms-lease-id", v);
        if (options.tier) |v| try req.setHeader("x-ms-access-tier", v.toWire());
        req.body = data;
        try sendExpect(client.pipeline, &req, 201, "uploadBlockBlob:putBlob");
        return;
    }

    const block_size: usize = @intCast(options.block_size);
    const block_count = (data.len + block_size - 1) / block_size;
    if (block_count > max_block_count) return error.BlobUploadTooLarge;

    // Build the ordered commit body as blocks are staged. Each block id is a
    // fixed-width base64 string so the committed order is well defined.
    var block_list: std.ArrayList(u8) = .empty;
    try block_list.appendSlice(a, "<BlockList>");

    var index: u64 = 0;
    var offset: usize = 0;
    while (offset < data.len) : (index += 1) {
        const end = @min(offset + block_size, data.len);
        const chunk = data[offset..end];
        const id = blockId(index);

        var url_buf: std.ArrayList(u8) = .empty;
        try url_buf.appendSlice(a, client.endpoint);
        var has_query = false;
        try appendQuery(a, &url_buf, &has_query, "comp", "block");
        try appendQuery(a, &url_buf, &has_query, "blockid", &id);
        const url = try url_buf.toOwnedSlice(a);

        var req = core.http.Request.init(a, .PUT, url);
        defer req.deinit();
        try req.setHeader("x-ms-version", client.api_version);
        try req.setHeader("Content-Type", "application/octet-stream");
        if (options.client_request_id) |v| try req.setHeader("x-ms-client-request-id", v);
        if (options.lease_id) |v| try req.setHeader("x-ms-lease-id", v);
        req.body = chunk;
        try sendExpect(client.pipeline, &req, 201, "uploadBlockBlob:stageBlock");

        try block_list.appendSlice(a, "<Latest>");
        try block_list.appendSlice(a, &id);
        try block_list.appendSlice(a, "</Latest>");
        offset = end;
    }
    try block_list.appendSlice(a, "</BlockList>");

    const commit_url = try std.fmt.allocPrint(a, "{s}?comp=blocklist", .{client.endpoint});
    var req = core.http.Request.init(a, .PUT, commit_url);
    defer req.deinit();
    try req.setHeader("x-ms-version", client.api_version);
    try req.setHeader("Content-Type", "application/xml");
    try req.setHeader("x-ms-blob-content-type", content_type);
    if (options.client_request_id) |v| try req.setHeader("x-ms-client-request-id", v);
    if (options.lease_id) |v| try req.setHeader("x-ms-lease-id", v);
    if (options.tier) |v| try req.setHeader("x-ms-access-tier", v.toWire());
    req.body = block_list.items;
    try sendExpect(client.pipeline, &req, 201, "uploadBlockBlob:commitBlockList");
}

/// Sends `req` and returns `error.AzureRequestFailed` unless the response
/// status equals `expected`. Only the status line is inspected, so callers are
/// insulated from optional/omitted Azure response headers.
fn sendExpect(
    pipeline: core.pipeline.HttpPipeline,
    req: *core.http.Request,
    expected: u16,
    ctx: []const u8,
) !void {
    var pl = pipeline;
    var resp = try pl.send(req);
    defer resp.deinit();
    if (resp.status_code != expected) {
        core.pager.logHttpError(ctx, resp.status_code, resp.body);
        return error.AzureRequestFailed;
    }
}

/// Base64 block id derived from an 8-digit, zero-padded index. Every id has
/// the same length, as required for `Put Block List` ordering.
fn blockId(index: u64) [12]u8 {
    var decimal: [8]u8 = undefined;
    _ = std.fmt.bufPrint(&decimal, "{d:0>8}", .{index}) catch unreachable;
    var encoded: [12]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&encoded, &decimal);
    return encoded;
}

fn appendQuery(
    alloc: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    has_query: *bool,
    name: []const u8,
    value: ?[]const u8,
) !void {
    const v = value orelse return;
    const sep: []const u8 = if (has_query.*) "&" else "?";
    const enc = try core.url.percentEncode(alloc, v);
    defer alloc.free(enc);
    try buf.print(alloc, "{s}{s}={s}", .{ sep, name, enc });
    has_query.* = true;
}

fn appendQueryInt(
    alloc: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    has_query: *bool,
    name: []const u8,
    value: ?i32,
) !void {
    const v = value orelse return;
    const sep: []const u8 = if (has_query.*) "&" else "?";
    try buf.print(alloc, "{s}{s}={d}", .{ sep, name, v });
    has_query.* = true;
}

test {
    // Force analysis (and thus execution) of the inline tests below.
    std.testing.refAllDecls(@This());
}

// ─────────────────────────────── tests ────────────────────────────
//
// In-process mock `HttpTransport` that records every request and returns a
// canned response carrying the superset of success headers the generated
// `stageBlock` / `commitBlockList` / `upload` parsers require.

const testing = std.testing;
const test_api_version = "2024-11-04";
const test_blob_endpoint = "https://acct.blob.core.windows.net/cont/blob";
const test_container_endpoint = "https://acct.blob.core.windows.net/cont";

const RecordedCall = struct {
    method: core.http.Method,
    url: []const u8,
    body: ?[]const u8,
};

const MockTransport = struct {
    transport: core.http.HttpTransport,
    alloc: std.mem.Allocator,
    status: u16,
    body: []const u8,
    calls: std.ArrayList(RecordedCall),

    fn init(alloc: std.mem.Allocator, status: u16, body: []const u8) MockTransport {
        return .{
            .transport = .{ .sendFn = &sendImpl, .openFn = null },
            .alloc = alloc,
            .status = status,
            .body = body,
            .calls = .empty,
        };
    }

    fn deinit(self: *MockTransport) void {
        for (self.calls.items) |c| {
            self.alloc.free(c.url);
            if (c.body) |b| self.alloc.free(b);
        }
        self.calls.deinit(self.alloc);
    }

    fn pipeline(self: *MockTransport) core.pipeline.HttpPipeline {
        return .{ .policies = &.{}, .transport_impl = &self.transport };
    }

    fn blobClient(self: *MockTransport) Blob {
        return .{ .endpoint = test_blob_endpoint, .api_version = test_api_version, .pipeline = self.pipeline() };
    }

    fn containerClient(self: *MockTransport) Container {
        return .{ .endpoint = test_container_endpoint, .api_version = test_api_version, .pipeline = self.pipeline() };
    }

    fn blockBlobClient(self: *MockTransport) BlockBlob {
        return .{ .endpoint = test_blob_endpoint, .api_version = test_api_version, .pipeline = self.pipeline() };
    }

    fn sendImpl(transport: *core.http.HttpTransport, request: *core.http.Request) !core.http.Response {
        const self: *MockTransport = @alignCast(@fieldParentPtr("transport", transport));
        try self.calls.append(self.alloc, .{
            .method = request.method,
            .url = try self.alloc.dupe(u8, request.url),
            .body = if (request.body) |b| try self.alloc.dupe(u8, b) else null,
        });
        var headers = std.StringHashMap([]const u8).init(self.alloc);
        try putTestHeader(&headers, self.alloc, "Content-MD5", "1B2M2Y8AsgTpgAmY7PhCfg==");
        try putTestHeader(&headers, self.alloc, "Date", "Fri, 25 Jul 2026 00:00:00 GMT");
        try putTestHeader(&headers, self.alloc, "x-ms-version", test_api_version);
        try putTestHeader(&headers, self.alloc, "ETag", "\"0x8D\"");
        try putTestHeader(&headers, self.alloc, "Last-Modified", "Fri, 25 Jul 2026 00:00:00 GMT");
        try putTestHeader(&headers, self.alloc, "x-ms-version-id", "2026-07-25T00:00:00.0000000Z");
        return .{
            .status_code = self.status,
            .headers = headers,
            .body = try self.alloc.dupe(u8, self.body),
            .allocator = self.alloc,
        };
    }
};

fn putTestHeader(map: *std.StringHashMap([]const u8), alloc: std.mem.Allocator, k: []const u8, v: []const u8) !void {
    try map.put(try alloc.dupe(u8, k), try alloc.dupe(u8, v));
}

test "blobExists: 200 -> true, HEAD to blob url" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 200, "");
    defer mock.deinit();
    var blob = mock.blobClient();
    try testing.expect(try blobExists(&blob, alloc, .{}));
    try testing.expectEqual(@as(usize, 1), mock.calls.items.len);
    try testing.expectEqual(core.http.Method.HEAD, mock.calls.items[0].method);
    try testing.expect(std.mem.startsWith(u8, mock.calls.items[0].url, test_blob_endpoint));
}

test "blobExists: 404 -> false" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 404, "");
    defer mock.deinit();
    var blob = mock.blobClient();
    try testing.expect(!try blobExists(&blob, alloc, .{}));
}

test "blobExists: 403 -> error" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 403, "");
    defer mock.deinit();
    var blob = mock.blobClient();
    try testing.expectError(error.AzureRequestFailed, blobExists(&blob, alloc, .{}));
}

test "containerExists: 200 -> true, restype=container" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 200, "");
    defer mock.deinit();
    var container = mock.containerClient();
    try testing.expect(try containerExists(&container, alloc, .{}));
    try testing.expect(std.mem.indexOf(u8, mock.calls.items[0].url, "restype=container") != null);
}

test "downloadInto: writes buffered body and returns length" {
    const alloc = testing.allocator;
    const payload = "hello world";
    var mock = MockTransport.init(alloc, 200, payload);
    defer mock.deinit();
    var blob = mock.blobClient();

    var buf: [64]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    const n = try downloadInto(&blob, alloc, &w, .{});

    try testing.expectEqual(@as(u64, payload.len), n);
    try testing.expectEqualStrings(payload, buf[0..@intCast(n)]);
    try testing.expectEqual(core.http.Method.GET, mock.calls.items[0].method);
}

test "download: returns owned body bytes" {
    const alloc = testing.allocator;
    const payload = "hello world";
    var mock = MockTransport.init(alloc, 200, payload);
    defer mock.deinit();
    var blob = mock.blobClient();

    var result = try download(&blob, alloc, .{});
    defer result.deinit();

    try testing.expectEqualStrings(payload, result.data);
    try testing.expectEqual(core.http.Method.GET, mock.calls.items[0].method);
}

test "download: 206 partial content with range header" {
    const alloc = testing.allocator;
    const payload = "llo";
    var mock = MockTransport.init(alloc, 206, payload);
    defer mock.deinit();
    var blob = mock.blobClient();

    var result = try download(&blob, alloc, .{ .range = "bytes=2-4" });
    defer result.deinit();

    try testing.expectEqualStrings(payload, result.data);
}

test "download: 404 -> error" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 404, "");
    defer mock.deinit();
    var blob = mock.blobClient();
    try testing.expectError(error.AzureRequestFailed, download(&blob, alloc, .{}));
}

test "uploadBlockBlob: small payload -> single Put Blob" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 201, "");
    defer mock.deinit();
    var client = mock.blockBlobClient();
    const data = "small payload";
    try uploadBlockBlob(&client, alloc, data, .{});

    try testing.expectEqual(@as(usize, 1), mock.calls.items.len);
    const call = mock.calls.items[0];
    try testing.expectEqual(core.http.Method.PUT, call.method);
    try testing.expectEqualStrings(data, call.body.?);
    try testing.expect(std.mem.indexOf(u8, call.url, "comp=block") == null);
}

test "uploadBlockBlob: large payload -> staged blocks + commit" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 201, "");
    defer mock.deinit();
    var client = mock.blockBlobClient();

    // 10 bytes with a 4-byte block size forces 3 blocks (4 + 4 + 2).
    const data = "0123456789";
    try uploadBlockBlob(&client, alloc, data, .{ .block_size = 4, .single_upload_max_bytes = 4 });

    try testing.expectEqual(@as(usize, 4), mock.calls.items.len);
    var staged: usize = 0;
    var committed: usize = 0;
    for (mock.calls.items) |c| {
        try testing.expectEqual(core.http.Method.PUT, c.method);
        if (std.mem.indexOf(u8, c.url, "comp=block&") != null or std.mem.endsWith(u8, c.url, "comp=block")) {
            staged += 1;
        } else if (std.mem.indexOf(u8, c.url, "comp=blocklist") != null) {
            committed += 1;
            try testing.expect(std.mem.indexOf(u8, c.body.?, "<Latest>") != null);
        }
    }
    try testing.expectEqual(@as(usize, 3), staged);
    try testing.expectEqual(@as(usize, 1), committed);
}

test "uploadBlockBlob: zero block size rejected" {
    const alloc = testing.allocator;
    var mock = MockTransport.init(alloc, 201, "");
    defer mock.deinit();
    var client = mock.blockBlobClient();
    try testing.expectError(
        error.InvalidBlockSize,
        uploadBlockBlob(&client, alloc, "abcdef", .{ .block_size = 0, .single_upload_max_bytes = 1 }),
    );
}
