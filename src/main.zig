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

extern "wasi:http/types@0.2.6" fn @"[constructor]fields"() i32;
extern "wasi:http/types@0.2.6" fn @"[method]fields.append"(self: i32, name_ptr: i32, name_len: i32, val_ptr: i32, val_len: i32, ret: i32) void;
extern "wasi:http/types@0.2.6" fn @"[constructor]outgoing-request"(headers: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-method"(self: i32, d: i32, p0: i32, p1: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-scheme"(self: i32, opt: i32, d: i32, p0: i32, p1: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-authority"(self: i32, opt: i32, ptr: i32, len: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-path-with-query"(self: i32, opt: i32, ptr: i32, len: i32) i32;
extern "wasi:http/outgoing-handler@0.2.6" fn handle(request: i32, opt_disc: i32, opt_val: i32, ret: i32) void;
extern "wasi:http/types@0.2.6" fn @"[method]future-incoming-response.subscribe"(self: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]future-incoming-response.get"(self: i32, ret: i32) void;
extern "wasi:io/poll@0.2.6" fn @"[method]pollable.block"(self: i32) void;
extern "wasi:http/types@0.2.6" fn @"[method]incoming-response.status"(self: i32) i32;
extern "wasi:http/types@0.2.6" fn @"[method]incoming-response.consume"(self: i32, ret: i32) void;
extern "wasi:http/types@0.2.6" fn @"[method]incoming-body.stream"(self: i32, ret: i32) void;
extern "wasi:io/streams@0.2.6" fn @"[method]input-stream.blocking-read"(self: i32, len: i64, ret: i32) void;

var realloc_buf: [128 * 1024]u8 align(16) = undefined;
var realloc_top: usize = 0;

export fn cabi_realloc(old_ptr: usize, old_size: usize, alignment: usize, new_size: usize) usize {
    _ = old_ptr;
    _ = old_size;
    if (new_size == 0) return 0;
    const a = if (alignment == 0) 1 else alignment;
    const start = (realloc_top + a - 1) & ~(a - 1);
    if (start + new_size > realloc_buf.len) return 0;
    realloc_top = start + new_size;
    return @intFromPtr(&realloc_buf[start]);
}

var ret_area: [64]u8 align(8) = undefined;

inline fn retPtr() i32 {
    return @intCast(@intFromPtr(&ret_area));
}
inline fn retWords() [*]u32 {
    return @ptrCast(@alignCast(&ret_area));
}
inline fn retClear() void {
    @memset(&ret_area, 0);
}

const WasiHttpTransport = struct {
    allocator: std.mem.Allocator,

    const vtable: core.http.HttpTransport.VTable = .{ .send = &sendImpl };

    pub fn init(allocator: std.mem.Allocator) WasiHttpTransport {
        return .{ .allocator = allocator };
    }

    pub fn asTransport(self: *WasiHttpTransport) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn methodDisc(m: core.http.Method) i32 {
        return switch (m) {
            .GET => 0,
            .HEAD => 1,
            .POST => 2,
            .PUT => 3,
            .DELETE => 4,
            .OPTIONS => 6,
            .PATCH => 8,
        };
    }

    fn sendImpl(context: *anyopaque, request: *core.http.Request) !core.http.Response {
        const self: *WasiHttpTransport = @ptrCast(@alignCast(context));
        if (request.body != null) return error.RequestBodyUnsupported;

        const uri = std.Uri.parse(request.url) catch return error.InvalidUrl;
        const scheme_disc: i32 = if (std.ascii.eqlIgnoreCase(uri.scheme, "http"))
            0
        else if (std.ascii.eqlIgnoreCase(uri.scheme, "https"))
            1
        else
            return error.InvalidUrl;
        if (uri.host == null or uri.user != null or uri.password != null)
            return error.InvalidUrl;

        const authority = try std.fmt.allocPrint(self.allocator, "{f}", .{
            std.Uri.fmt(&uri, .{ .authority = true, .port = true }),
        });
        defer self.allocator.free(authority);
        const path_with_query = try std.fmt.allocPrint(self.allocator, "{f}", .{
            std.Uri.fmt(&uri, .{ .path = true, .query = true, .fragment = false }),
        });
        defer self.allocator.free(path_with_query);

        const headers = @"[constructor]fields"();
        var it = request.headers.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            if (std.ascii.eqlIgnoreCase(name, "host")) continue;
            const value = entry.value_ptr.*;
            @"[method]fields.append"(
                headers,
                @intCast(@intFromPtr(name.ptr)),
                @intCast(name.len),
                @intCast(@intFromPtr(value.ptr)),
                @intCast(value.len),
                retPtr(),
            );
        }

        const req_handle = @"[constructor]outgoing-request"(headers);
        _ = @"[method]outgoing-request.set-method"(req_handle, methodDisc(request.method), 0, 0);
        _ = @"[method]outgoing-request.set-scheme"(req_handle, 1, scheme_disc, 0, 0);
        _ = @"[method]outgoing-request.set-authority"(
            req_handle,
            1,
            @intCast(@intFromPtr(authority.ptr)),
            @intCast(authority.len),
        );
        _ = @"[method]outgoing-request.set-path-with-query"(
            req_handle,
            1,
            @intCast(@intFromPtr(path_with_query.ptr)),
            @intCast(path_with_query.len),
        );

        retClear();
        handle(req_handle, 0, 0, retPtr());
        if (retWords()[0] != 0) return error.HttpRequestDenied;
        const compact = retWords()[1] != 0;
        const future: i32 = @bitCast(if (compact) retWords()[1] else retWords()[2]);
        if (future == 0) return error.HttpRequestDenied;

        const pollable = @"[method]future-incoming-response.subscribe"(future);
        var resp_handle: i32 = undefined;
        while (true) {
            @"[method]pollable.block"(pollable);
            retClear();
            @"[method]future-incoming-response.get"(future, retPtr());
            const w = retWords();
            if (w[0] != 1) continue;
            if (w[2] != 0) return error.FutureAlreadyConsumed;
            if (w[4] != 0) return error.HttpProtocolError;
            resp_handle = @bitCast(w[6]);
            break;
        }

        const status: u16 = @intCast(@as(u32, @intCast(@"[method]incoming-response.status"(resp_handle))) & 0xFFFF);

        retClear();
        @"[method]incoming-response.consume"(resp_handle, retPtr());
        if (retWords()[0] != 0) return error.ResponseBodyConsumeFailed;
        const body_handle: i32 = @bitCast(retWords()[1]);

        retClear();
        @"[method]incoming-body.stream"(body_handle, retPtr());
        if (retWords()[0] != 0) return error.ResponseBodyStreamFailed;
        const stream_handle: i32 = @bitCast(retWords()[1]);

        var body = std.ArrayList(u8).empty;
        errdefer body.deinit(self.allocator);
        while (true) {
            realloc_top = 0;
            retClear();
            @"[method]input-stream.blocking-read"(stream_handle, 64 * 1024, retPtr());
            const w = retWords();
            if (w[0] != 0) break;
            const ptr = w[1];
            const len = w[2];
            if (len == 0) continue;
            const chunk: [*]const u8 = @ptrFromInt(ptr);
            try body.appendSlice(self.allocator, chunk[0..len]);
        }

        return .{
            .status_code = status,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = try body.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
            .response_headers = core.http.ResponseHeaders.init(self.allocator),
        };
    }
};

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
    var crypto = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        http_transport.asTransport(),
        crypto.asProvider(),
    );
    var auth_policy = core.http.BearerTokenAuthPolicy.init(
        gpa,
        credential.asCredential(),
        &.{"https://management.azure.com/.default"},
    );
    defer auth_policy.deinit();
    var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
    const pipeline = core.http.HttpPipeline.init(runtime, &policies);

    var client = arm_avs.AVSClient.init(pipeline, .{
        .subscription_id = subscription_id,
    });

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
