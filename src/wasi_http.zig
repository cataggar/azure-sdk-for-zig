//! An `azure_core` HTTP transport that performs outbound requests through
//! the WASI component-model `wasi:http/outgoing-handler@0.2.6` interface,
//! so the Azure SDK can run inside a WebAssembly component (wamr / wasmtime)
//! instead of `std.http.Client` (which has no wasm32-wasi socket backend).
//!
//! The host (wamr's wasi_cli_adapter / wasmtime's wasi-http) performs the
//! real HTTPS round-trip incl. TLS; this file is the guest-side glue that
//! drives the canonical-ABI imports by hand. Lowered signatures follow the
//! canonical ABI rules (MAX_FLAT_RESULTS = 1; any wider result is returned
//! through a guest ret-area pointer passed as the last argument).
//!
//! Scope: GET/HEAD/etc. without a request body — enough for ARM list
//! pagers. Sending a request body (outgoing-body/output-stream) is not
//! wired up and returns `error.RequestBodyUnsupported`.

const std = @import("std");
const core = @import("azure_core");

// ── Canonical-ABI lowered host imports ─────────────────────────────────

extern "wasi:http/types@0.2.6" fn @"[constructor]fields"() i32;
/// `fields.append(name: string, value: list<u8>) -> result<_, header-error>`.
/// Result flat = 2 → ret-area: [disc, _].
extern "wasi:http/types@0.2.6" fn @"[method]fields.append"(self: i32, name_ptr: i32, name_len: i32, val_ptr: i32, val_len: i32, ret: i32) void;

/// `[constructor]outgoing-request(headers: own<fields>) -> own<outgoing-request>`.
extern "wasi:http/types@0.2.6" fn @"[constructor]outgoing-request"(headers: i32) i32;
/// `set-method(method) -> result`. `method` flat = 3 (disc + other(string)).
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-method"(self: i32, d: i32, p0: i32, p1: i32) i32;
/// `set-scheme(option<scheme>) -> result`. option<scheme> flat = 4.
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-scheme"(self: i32, opt: i32, d: i32, p0: i32, p1: i32) i32;
/// `set-authority(option<string>) -> result`. option<string> flat = 3.
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-authority"(self: i32, opt: i32, ptr: i32, len: i32) i32;
/// `set-path-with-query(option<string>) -> result`.
extern "wasi:http/types@0.2.6" fn @"[method]outgoing-request.set-path-with-query"(self: i32, opt: i32, ptr: i32, len: i32) i32;

/// `outgoing-handler.handle(own<outgoing-request>, option<own<request-options>>)
///   -> result<own<future-incoming-response>, error-code>`.
/// error-code (canonical) has align 8, so memory layout is: disc @ byte 0,
/// ok payload (future handle) @ byte 8 → ret word[2].
extern "wasi:http/outgoing-handler@0.2.6" fn handle(request: i32, opt_disc: i32, opt_val: i32, ret: i32) void;

extern "wasi:http/types@0.2.6" fn @"[method]future-incoming-response.subscribe"(self: i32) i32;
/// `future.get() -> option<result<result<incoming-response, error-code>>>`.
/// Canonical memory layout (everything align 8): outer option disc @ 0
/// (word[0]); middle result disc @ 8 (word[2]); inner result disc @ 16
/// (word[4]); ok incoming-response handle @ 24 (word[6]).
extern "wasi:http/types@0.2.6" fn @"[method]future-incoming-response.get"(self: i32, ret: i32) void;
extern "wasi:io/poll@0.2.6" fn @"[method]pollable.block"(self: i32) void;

extern "wasi:http/types@0.2.6" fn @"[method]incoming-response.status"(self: i32) i32;
/// `consume() -> result<own<incoming-body>>` → ret-area: [disc, body].
extern "wasi:http/types@0.2.6" fn @"[method]incoming-response.consume"(self: i32, ret: i32) void;
/// `incoming-body.stream() -> result<own<input-stream>>` → ret-area: [disc, stream].
extern "wasi:http/types@0.2.6" fn @"[method]incoming-body.stream"(self: i32, ret: i32) void;
/// `input-stream.blocking-read(len: u64) -> result<list<u8>, stream-error>`.
/// Result flat = 3 → ret-area: [disc, ptr, len]; err (disc=1) ⇒ end-of-stream.
extern "wasi:io/streams@0.2.6" fn @"[method]input-stream.blocking-read"(self: i32, len: i64, ret: i32) void;

// ── cabi_realloc — canonical-ABI return-value materialization ──────────
//
// The host calls this to lift `list<u8>` returned by `blocking-read` into
// guest memory. A small bump arena suffices because each chunk is copied
// out immediately; `reallocReset()` is called right before every read.

var realloc_buf: [128 * 1024]u8 align(16) = undefined;
var realloc_top: usize = 0;

fn reallocReset() void {
    realloc_top = 0;
}

export fn cabi_realloc(old_ptr: usize, old_size: usize, alignment: usize, new_size: usize) usize {
    _ = old_ptr;
    _ = old_size;
    if (new_size == 0) return 0;
    const a = if (alignment == 0) 1 else alignment;
    const start = (realloc_top + a - 1) & ~(a - 1);
    if (start + new_size > realloc_buf.len) return 0; // OOM → host sees null
    realloc_top = start + new_size;
    return @intFromPtr(&realloc_buf[start]);
}

// ── Shared ret-area for spilled canonical-ABI results ──────────────────

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

// ── Transport ──────────────────────────────────────────────────────────

pub const WasiHttpTransport = struct {
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,

    pub fn init(allocator: std.mem.Allocator) WasiHttpTransport {
        return .{ .allocator = allocator, .transport = .{ .sendFn = &sendImpl } };
    }

    pub fn asTransport(self: *WasiHttpTransport) *core.http.HttpTransport {
        return &self.transport;
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

    fn sendImpl(t: *core.http.HttpTransport, request: *core.http.Request) anyerror!core.http.Response {
        const self: *WasiHttpTransport = @fieldParentPtr("transport", t);
        const allocator = self.allocator;

        if (request.body != null) return error.RequestBodyUnsupported;

        // Split "scheme://authority/path?query".
        const url = request.url;
        const sep = std.mem.indexOf(u8, url, "://") orelse return error.InvalidUrl;
        const scheme = url[0..sep];
        const after = url[sep + 3 ..];
        const slash = std.mem.indexOfScalar(u8, after, '/') orelse after.len;
        const authority = after[0..slash];
        const path_query: []const u8 = if (slash < after.len) after[slash..] else "/";

        const scheme_disc: i32 = if (std.ascii.eqlIgnoreCase(scheme, "http")) 0 else 1; // default HTTPS

        // Build headers (skip Host — wasi:http derives it from authority).
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

        // Build + configure the outgoing request.
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
            @intCast(@intFromPtr(path_query.ptr)),
            @intCast(path_query.len),
        );

        // Fire the request: handle(request, none) -> result<own<future>, error-code>.
        retClear();
        handle(req_handle, 0, 0, retPtr());
        if (retWords()[0] != 0) return error.HttpRequestDenied; // ok disc == 0
        const compact = retWords()[1] != 0; // true ⇒ wamr (align-4) layout
        const future: i32 = @bitCast(if (compact) retWords()[1] else retWords()[2]);
        if (future == 0) return error.HttpRequestDenied;

        // Wait for the response, then take it.
        // get() -> option<result<result<incoming-response, error-code>>>.
        // Both runtimes lay this out align-8: option@w0, middle@w2, inner@w4,
        // response@w6. (Unlike `handle`, whose ok payload position differs.)
        const pollable = @"[method]future-incoming-response.subscribe"(future);
        var resp_handle: i32 = undefined;
        while (true) {
            @"[method]pollable.block"(pollable);
            retClear();
            @"[method]future-incoming-response.get"(future, retPtr());
            const w = retWords();
            if (w[0] != 1) continue; // outer option: not ready yet
            if (w[2] != 0) return error.FutureAlreadyConsumed; // middle result err
            if (w[4] != 0) return error.HttpProtocolError; // inner result err (error-code)
            resp_handle = @bitCast(w[6]);
            break;
        }

        const status: u16 = @intCast(@as(u32, @intCast(@"[method]incoming-response.status"(resp_handle))) & 0xFFFF);

        // incoming-response.consume → incoming-body → input-stream.
        // result<own<T>> (err = unit, no error-code) is align-4 on both
        // runtimes, so the ok handle is at word[1].
        retClear();
        @"[method]incoming-response.consume"(resp_handle, retPtr());
        if (retWords()[0] != 0) return error.ResponseBodyConsumeFailed;
        const body_handle: i32 = @bitCast(retWords()[1]);

        retClear();
        @"[method]incoming-body.stream"(body_handle, retPtr());
        if (retWords()[0] != 0) return error.ResponseBodyStreamFailed;
        const stream_handle: i32 = @bitCast(retWords()[1]);

        // Drain the body. Each chunk lands in the realloc arena (reset per
        // read) and is copied into the caller-allocator-owned accumulator.
        // result<list<u8>, stream-error> is align-4: [disc, ptr, len].
        var body = std.ArrayList(u8).empty;
        errdefer body.deinit(allocator);
        while (true) {
            reallocReset();
            retClear();
            @"[method]input-stream.blocking-read"(stream_handle, 64 * 1024, retPtr());
            const w = retWords();
            if (w[0] != 0) break; // err arm ⇒ stream closed (end of body)
            const ptr = w[1];
            const len = w[2];
            if (len == 0) continue;
            const chunk: [*]const u8 = @ptrFromInt(ptr);
            try body.appendSlice(allocator, chunk[0..len]);
        }

        return .{
            .status_code = status,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = try body.toOwnedSlice(allocator),
            .allocator = allocator,
        };
    }
};
