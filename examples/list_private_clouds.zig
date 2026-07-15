//! List Microsoft.AVS private clouds in a subscription.
//!
//! Mirrors the Rust SDK example
//! `sdk/avs/azure_resourcemanager_vmware/examples/list_private_clouds.rs`.
//!
//! Usage:
//!   az login
//!   AZURE_SUBSCRIPTION_ID=<sub-id> zig build list-private-clouds
//!   # or pass the subscription id as a positional argument:
//!   zig build list-private-clouds -- <sub-id>
//!   # or put `AZURE_SUBSCRIPTION_ID=<sub-id>` in a `.env` file in the cwd.

const std = @import("std");
const core = @import("azure_core");
const identity = @import("azure_core").identity;
const arm_avs = @import("arm_avs");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var dotenv = core.dotenv.loadFromFileOrEmpty(gpa, init.io, ".env");
    defer dotenv.deinit();

    const subscription_id = try resolveSubscriptionId(init, &dotenv);

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
    // each PrivateCloud's owned strings field-by-field.
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var private_clouds = client.privateClouds();
    var pager = try private_clouds.listInSubscription(arena.allocator());
    defer pager.deinit();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &stdout_buf);
    const w = &stdout.interface;
    defer w.flush() catch {};

    try w.print("{s:<40}  {s:<14}  {s:<18}\n", .{ "NAME", "LOCATION", "PROVISIONING_STATE" });
    try w.splatByteAll('-', 78);
    try w.writeByte('\n');

    var count: usize = 0;
    while (try pager.next()) |page| {
        for (page) |cloud| {
            const state: []const u8 = if (cloud.properties) |props|
                if (props.provisioning_state) |ps| switch (ps) {
                    .unrecognized => |s| s,
                    else => @tagName(ps),
                } else "-"
            else
                "-";
            try w.print("{s:<40}  {s:<14}  {s:<18}\n", .{ cloud.name, cloud.location, state });
            count += 1;
        }
    }
    try w.print("\n{d} private cloud(s).\n", .{count});
}

/// Look up subscription id from (in order): argv[1], $AZURE_SUBSCRIPTION_ID,
/// or AZURE_SUBSCRIPTION_ID in a `.env` file in the cwd.
fn resolveSubscriptionId(init: std.process.Init, dotenv: *const core.dotenv.DotEnv) ![]const u8 {
    var args = init.minimal.args.iterate();
    _ = args.next(); // argv[0]
    if (args.next()) |arg1| return arg1;
    if (init.environ_map.get("AZURE_SUBSCRIPTION_ID")) |v| return v;
    if (dotenv.get("AZURE_SUBSCRIPTION_ID")) |v| return v;
    return error.MissingAzureSubscriptionId;
}
