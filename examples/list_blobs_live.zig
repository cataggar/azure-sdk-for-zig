//! Live smoke test for the generated Blob service client against a real
//! Azure Storage account, using AAD bearer-token auth.
//!
//! Exercises the "slice 1" surface that mirrors azure-sdk-for-rust's
//! `azure_storage_blob`: `Service.listContainers` and `Container.listBlobs`,
//! both driven by the generated `XmlPager` (NextMarker continuation).
//!
//! Usage:
//!   AZURE_TOKEN=$(az account get-access-token \
//!       --resource https://storage.azure.com --query accessToken -o tsv) \
//!   zig build list-live -- <account-endpoint> <container>
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

    // Strip any trailing slash so container endpoints concatenate cleanly.
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

    // ── Service.listContainers ────────────────────────────────────────
    var service_client = blobs.BlobClient.init(pipeline, .{
        .endpoint = endpoint,
    });

    try out.print("listContainers @ {s}\n", .{endpoint});
    var svc = service_client.service();
    var container_pager = try svc.listContainers(allocator, null, null, null, null, null, null);
    defer container_pager.deinit();

    var total_containers: usize = 0;
    while (try container_pager.next()) |page| {
        for (page.container_items.items) |c| {
            total_containers += 1;
            try out.print("  container: {s}\n", .{c.name orelse "<null>"});
        }
    }
    try out.print("  → {d} container(s)\n\n", .{total_containers});

    // ── Container.listBlobs ───────────────────────────────────────────
    const container_endpoint = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ endpoint, container_name },
    );
    defer allocator.free(container_endpoint);

    var container_client = blobs.BlobClient.init(pipeline, .{
        .endpoint = container_endpoint,
    });

    try out.print("listBlobs @ {s}\n", .{container_endpoint});
    var cnt = container_client.container();
    var blob_pager = try cnt.listBlobs(allocator, null, null, null, null, null, null, null);
    defer blob_pager.deinit();

    var total_blobs: usize = 0;
    while (try blob_pager.next()) |page| {
        for (page.blob_items.items) |b| {
            total_blobs += 1;
            const blob_name = if (b.name) |n| n.content orelse "<null>" else "<null>";
            try out.print("  blob: {s}\n", .{blob_name});
        }
    }
    try out.print("  → {d} blob(s)\n", .{total_blobs});
}
