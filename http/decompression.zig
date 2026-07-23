///! HTTP response decompression support.
///!
///! In Zig, `std.http.Client` handles response decompression natively
///! via `response.readerDecompressing()` which supports gzip, deflate, and
///! zstd using `std.compress.flate` and `std.compress.zstd` internally.
///!
///! This policy adds `Accept-Encoding` to requests so servers know they
///! may compress responses. The actual decompression is handled by the
///! `StdHttpTransport` (std.http.Client).
const std = @import("std");
const transport = @import("transport.zig");
const pipeline_mod = @import("pipeline.zig");

const Request = transport.Request;
const Response = transport.Response;
const HttpTransport = transport.HttpTransport;
const HttpPolicy = pipeline_mod.HttpPolicy;

/// Pipeline policy that requests compressed responses.
///
/// Adds `Accept-Encoding: gzip, deflate` to outgoing requests.
/// Decompression of the response body is handled transparently by
/// `std.http.Client` in the transport layer.
pub const DecompressionPolicy = struct {
    policy: HttpPolicy,

    pub fn init() DecompressionPolicy {
        return .{ .policy = .{ .processFn = &processImpl, .prepareFn = &prepareImpl } };
    }

    pub fn asPolicy(self: *DecompressionPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        try prepareImpl(policy, request);
        return callNext(request, next, final_transport);
    }

    fn prepareImpl(_: *HttpPolicy, request: *Request) !void {
        try request.setHeader("Accept-Encoding", "gzip, deflate");
    }
};

fn callNext(request: *Request, next: []*HttpPolicy, final_transport: *HttpTransport) !Response {
    if (next.len == 0) {
        return final_transport.send(request);
    }
    return next[0].process(request, next[1..], final_transport);
}

test "DecompressionPolicy sets Accept-Encoding" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "body");
    defer mock.deinit();
    var decomp = DecompressionPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{decomp.asPolicy()};
    var pip = pipeline_mod.HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqualStrings("gzip, deflate", req.headers.get("Accept-Encoding").?);
}

test "DecompressionPolicy prepares streaming request" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "body");
    defer mock.deinit();
    var decomp = DecompressionPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{decomp.asPolicy()};
    var pip = pipeline_mod.HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var operation = try pip.open(&req, .{});
    defer operation.deinit();
    try std.testing.expectEqualStrings(
        "gzip, deflate",
        mock.last_headers.get("Accept-Encoding").?,
    );
    try operation.finish();
}
