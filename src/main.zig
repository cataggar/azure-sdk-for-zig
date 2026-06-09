//! List Microsoft.AVS private clouds in a subscription — WASI component edition.
//!
//! A WebAssembly port of `/work/avs-smoke` (`list_private_clouds`). Instead of
//! `std.http.Client` + `az`, it uses:
//!   * `WasiHttpTransport`   — outbound HTTP via wasi:http/outgoing-handler
//!   * `EnvTokenCredential`  — bearer token from the `AZURE_TOKEN` env var
//!
//! Usage (token from `az account get-access-token`):
//!   TOK=$(az account get-access-token --resource https://management.azure.com \
//!         --query accessToken -o tsv)
//!   SUB=$(az account show --query id -o tsv)
//!
//!   # wamr (AOT-compile once, then run; flags MUST precede the module):
//!   wamrc run avs-wasi.component.wasm        # produces the .cwasm.json
//!   wamr  run --allow-net 0.0.0.0/0 \
//!         --env AZURE_SUBSCRIPTION_ID=$SUB --env AZURE_TOKEN=$TOK \
//!         avs-wasi.component.wasm
//!
//!   # wasmtime:
//!   wasmtime run -S http -S cli-exit-with-code \
//!         --env AZURE_SUBSCRIPTION_ID=$SUB --env AZURE_TOKEN=$TOK \
//!         avs-wasi.component.wasm

const std = @import("std");
const core = @import("azure_sdk_core");
const arm_avs = @import("azure_rest_arm_avs");
const EnvTokenCredential = core.env_token.EnvTokenCredential;
const WasiHttpTransport = core.wasi_http.WasiHttpTransport;

fn writeAll(bytes: []const u8) void {
    var off: usize = 0;
    while (off < bytes.len) {
        var nwritten: usize = 0;
        const rc = std.os.wasi.fd_write(1, &.{.{ .base = bytes.ptr + off, .len = bytes.len - off }}, 1, &nwritten);
        if (rc != .SUCCESS or nwritten == 0) return;
        off += nwritten;
    }
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [512]u8 = undefined;
    const out = std.fmt.bufPrint(&buf, fmt, args) catch return;
    writeAll(out);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const subscription_id = init.environ_map.get("AZURE_SUBSCRIPTION_ID") orelse {
        writeAll("error: missing AZURE_SUBSCRIPTION_ID env var\n");
        return error.MissingAzureSubscriptionId;
    };
    const token = init.environ_map.get("AZURE_TOKEN") orelse {
        writeAll("error: missing AZURE_TOKEN env var\n");
        return error.MissingAzureToken;
    };

    var credential = EnvTokenCredential.init(gpa, token);
    var http_transport = WasiHttpTransport.init(gpa);

    var client = try arm_avs.AVSClient.init(gpa, .{
        .subscription_id = subscription_id,
        .credential = credential.asCredential(),
        .transport = http_transport.asTransport(),
    });
    defer client.deinit();

    // Pager + per-page items use an arena so we don't deep-free each
    // PrivateCloud's owned strings field-by-field.
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var private_clouds = client.privateClouds();
    var pager = try private_clouds.listInSubscription(arena.allocator());
    defer pager.deinit();

    print("{s:<40}  {s:<14}  {s:<18}\n", .{ "NAME", "LOCATION", "PROVISIONING_STATE" });
    var dashes: [78]u8 = undefined;
    @memset(&dashes, '-');
    writeAll(&dashes);
    writeAll("\n");

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
            print("{s:<40}  {s:<14}  {s:<18}\n", .{ cloud.name, cloud.location, state });
            count += 1;
        }
    }
    print("\n{d} private cloud(s).\n", .{count});
}
