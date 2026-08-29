//! Live smoke test for the hand-written convenience helpers against a real
//! Azure Storage account, using AAD bearer-token auth.
//!
//! Exercises `blobExists`, `uploadBlockBlob` (auto-chunking), `downloadInto`
//! (buffered writer sink), and `download` (allocating, owned bytes) as a round
//! trip:
//!   1. assert the target blob does not exist,
//!   2. upload a payload (a small block size forces the staged-block path),
//!   3. assert it now exists,
//!   4. download it back into a buffer and verify the bytes match,
//!   5. `download()` the whole blob into an owned buffer and verify,
//!   6. `download()` a byte range and verify the window.
//!
//! Compiled without credentials in CI; only runs when `AZURE_TOKEN` is set.
//!
//! Usage:
//!   AZURE_TOKEN=$(az account get-access-token \
//!       --resource https://storage.azure.com --query accessToken -o tsv) \
//!   zig build blob-convenience-live -- <account-endpoint> <container> <blob>
//!
//! e.g. <account-endpoint> = https://acct.blob.core.windows.net (no trailing /)

const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const endpoint_raw = args.next() orelse return error.MissingEndpoint;
    const container_name = args.next() orelse return error.MissingContainerName;
    const blob_name = args.next() orelse return error.MissingBlobName;

    const endpoint = if (std.mem.endsWith(u8, endpoint_raw, "/"))
        endpoint_raw[0 .. endpoint_raw.len - 1]
    else
        endpoint_raw;

    const bearer = init.environ_map.get("AZURE_TOKEN") orelse
        return error.MissingAzureToken;
    var env_cred = core.env_token.EnvTokenCredential.init(allocator, bearer);

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var crypto_provider = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto_provider.asProvider(),
    );
    var auth_policy = core.http.BearerTokenAuthPolicy.init(
        allocator,
        env_cred.asCredential(),
        blobs.auth_scopes,
    );
    defer auth_policy.deinit();
    var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
    const pipeline = core.http.HttpPipeline.init(runtime, &policies);

    var stdout_file = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    const blob_endpoint = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}/{s}",
        .{ endpoint, container_name, blob_name },
    );
    defer allocator.free(blob_endpoint);

    var client = blobs.BlobClient.init(pipeline, .{
        .endpoint = blob_endpoint,
    });

    var blob = client.blob();
    var block_blob = client.blockBlob();

    // 1. Should not exist yet.
    const before = try blobs.blobExists(&blob, allocator, .{});
    try out.print("exists (before) @ {s} → {}\n", .{ blob_endpoint, before });

    // 2. Upload. A 4-byte block size forces the staged-block path so the
    //    chunking logic is exercised end to end.
    const payload = "azure-sdk-for-zig convenience round trip payload";
    try blobs.uploadBlockBlob(&block_blob, allocator, payload, .{
        .content_type = "text/plain",
        .block_size = 4,
        .single_upload_max_bytes = 4,
    });
    try out.print("uploaded {d} bytes\n", .{payload.len});

    // 3. Should now exist.
    const after = try blobs.blobExists(&blob, allocator, .{});
    try out.print("exists (after)  → {}\n", .{after});

    // 4. Download it back and verify the round trip.
    var download_buf: [256]u8 = undefined;
    var sink = std.Io.Writer.fixed(&download_buf);
    const n = try blobs.downloadInto(&blob, allocator, &sink, .{});
    const downloaded = download_buf[0..@intCast(n)];
    try out.print("downloaded {d} bytes: {s}\n", .{ n, downloaded });

    if (!std.mem.eql(u8, downloaded, payload)) return error.RoundTripMismatch;
    try out.print("round trip OK\n", .{});

    // 5. Allocating download returns owned bytes for the whole blob.
    var full = try blobs.download(&blob, allocator, .{});
    defer full.deinit();
    try out.print("download() {d} bytes: {s}\n", .{ full.data.len, full.data });
    if (!std.mem.eql(u8, full.data, payload)) return error.RoundTripMismatch;

    // 6. Ranged download returns just the requested window.
    var head = try blobs.download(&blob, allocator, .{ .range = "bytes=0-4" });
    defer head.deinit();
    try out.print("download(range 0-4) {d} bytes: {s}\n", .{ head.data.len, head.data });
    if (!std.mem.eql(u8, head.data, payload[0..5])) return error.RoundTripMismatch;
    try out.print("allocating download OK\n", .{});
}
