//! List Microsoft.AVS clusters within a private cloud.
//!
//! Demonstrates a sub-client (`Clusters`) reached through the root
//! client (`AVSClient`).
//!
//! Usage:
//!   az login
//!   zig build list-clusters -- <sub-id> <resource-group> <private-cloud>
//!   # or set AZURE_SUBSCRIPTION_ID / AZURE_RESOURCE_GROUP / AZURE_PRIVATE_CLOUD
//!   # via env or `.env`.

const std = @import("std");
const core = @import("azure_core");
const identity = @import("azure_core").identity;
const arm_avs = @import("arm_avs");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var dotenv = core.dotenv.loadFromFileOrEmpty(gpa, init.io, ".env");
    defer dotenv.deinit();

    const subscription_id, const resource_group, const private_cloud_name =
        try resolveArgs(init, &dotenv);

    var cli_cred = identity.AzureCliCredential.init(gpa, init.io);

    var http_transport = core.http.StdHttpTransport.init(gpa, init.io);
    defer http_transport.deinit();

    var client = try arm_avs.AVSClient.init(gpa, .{
        .subscription_id = subscription_id,
        .credential = cli_cred.asCredential(),
        .transport = http_transport.asTransport(),
    });
    defer client.deinit();

    // Pager + per-page items use an arena so we don't have to deep-free
    // each Cluster's owned strings field-by-field.
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var clusters = client.clusters();
    var pager = try clusters.list(arena.allocator(), resource_group, private_cloud_name);
    defer pager.deinit();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &stdout_buf);
    const w = &stdout.interface;
    defer w.flush() catch {};

    try w.print("{s:<32}  {s:<10}  {s:<18}\n", .{ "NAME", "SKU", "PROVISIONING_STATE" });
    try w.splatByteAll('-', 64);
    try w.writeByte('\n');

    var count: usize = 0;
    while (try pager.next()) |page| {
        for (page) |cluster| {
            const state: []const u8 = if (cluster.properties) |props|
                if (props.provisioning_state) |ps| switch (ps) {
                    .unrecognized => |s| s,
                    else => @tagName(ps),
                } else "-"
            else
                "-";
            try w.print("{s:<32}  {s:<10}  {s:<18}\n", .{ cluster.name, cluster.sku.name, state });
            count += 1;
        }
    }
    try w.print("\n{d} cluster(s).\n", .{count});
}

const Args = struct { []const u8, []const u8, []const u8 };

/// Look up subscription id, resource group, and private cloud name from
/// (in order): argv, env vars, then `.env` in the cwd.
fn resolveArgs(init: std.process.Init, dotenv: *const core.dotenv.DotEnv) !Args {
    var args = init.minimal.args.iterate();
    _ = args.next(); // argv[0]
    const arg1 = args.next();
    const arg2 = args.next();
    const arg3 = args.next();

    const sub = arg1 orelse
        init.environ_map.get("AZURE_SUBSCRIPTION_ID") orelse
        dotenv.get("AZURE_SUBSCRIPTION_ID") orelse
        return error.MissingAzureSubscriptionId;
    const rg = arg2 orelse
        init.environ_map.get("AZURE_RESOURCE_GROUP") orelse
        dotenv.get("AZURE_RESOURCE_GROUP") orelse
        return error.MissingAzureResourceGroup;
    const pc = arg3 orelse
        init.environ_map.get("AZURE_PRIVATE_CLOUD") orelse
        dotenv.get("AZURE_PRIVATE_CLOUD") orelse
        return error.MissingAzurePrivateCloud;

    return .{ sub, rg, pc };
}
