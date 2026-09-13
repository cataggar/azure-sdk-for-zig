const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
pub const conformance = @import("azure_sdk_core_http_conformance");

pub fn factory() conformance.BackendFactory {
    return .{
        .name = "azure_sdk_core_httpx",
        .capabilities = .{
            .response_framing_validation = true,
            .response_body_limit = true,
            .decompression = true,
            .cancellation = .cooperative_upload,
            .automatic_request_headers = true,
            .bounded_memory_logical_large_upload = true,
            .bounded_memory_logical_large_download = true,
            .scripted_attempts = true,
            .allocation_failure_cleanup = true,
        },
        .createFn = create,
        .allocationFixtureFn = allocation,
    };
}

fn allocation(_: ?*anyopaque, allocator: std.mem.Allocator, fixture_allocator: std.mem.Allocator, io: std.Io, scenario: conformance.AllocationScenario) !void {
    try conformance.runBackendAllocationScenario(allocator, fixture_allocator, io, factory(), scenario);
}

pub const Backend = struct {
    allocator: std.mem.Allocator,
    server: conformance.scripted.ScriptedHttpServer,
    transport: adapter.HttpxTransport,
    url: []u8,
    expect_request: bool,

    fn finish(context: *anyopaque) !void {
        const self: *Backend = @ptrCast(@alignCast(context));
        if (!self.expect_request or self.server.responses.len > 0) {
            try self.server.stopAndJoin();
        } else {
            try self.server.join();
        }
    }

    fn quiescent(context: *anyopaque) !void {
        const self: *Backend = @ptrCast(@alignCast(context));
        try std.testing.expectEqual(@as(usize, 0), self.transport.live_operations);
        try std.testing.expectEqual(@as(usize, 0), self.transport.poolStats().active);
    }

    fn observe(context: *anyopaque) conformance.Observation {
        const self: *Backend = @ptrCast(@alignCast(context));
        const server = &self.server;
        return .{
            .request_count = if (server.responses.len > 0) server.requests.items.len else @intFromBool(server.request_line.len > 0),
            .body = server.body(),
            .body_length = server.body_length,
            .body_hash = server.body_hasher.final(),
            .request_line = server.request_line,
            .user_agent_count = server.headerCount("User-Agent"),
            .accept_encoding_count = server.headerCount("Accept-Encoding"),
            .host_count = server.headerCount("Host"),
            .connection_count = server.headerCount("Connection"),
            .accept_count = server.headerCount("Accept"),
            .content_length = server.headerValue("Content-Length"),
        };
    }

    fn attempt(context: *anyopaque, index: usize) ?conformance.Observation {
        const self: *Backend = @ptrCast(@alignCast(context));
        if (index >= self.server.requests.items.len) return null;
        const captured = &self.server.requests.items[index];
        return .{
            .request_count = 1,
            .body = captured.body_prefix[0..captured.body_prefix_len],
            .body_length = captured.body_length,
            .body_hash = captured.body_hash,
            .request_line = captured.request_line,
            .authorization = captured.headerValue("Authorization"),
            .cookie = captured.headerValue("Cookie"),
            .proxy_authorization = captured.headerValue("Proxy-Authorization"),
            .policy_marker = captured.headerValue("X-Conformance-Policy"),
            .content_length = captured.headerValue("Content-Length"),
            .host = captured.headerValue("Host"),
        };
    }

    fn destroy(context: *anyopaque) void {
        const self: *Backend = @ptrCast(@alignCast(context));
        self.server.deinit();
        self.transport.deinit();
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

fn create(_: ?*anyopaque, allocator: std.mem.Allocator, io: std.Io, options: conformance.BackendOptions) !conformance.BackendInstance {
    const state = try allocator.create(Backend);
    errdefer allocator.destroy(state);
    state.* = .{
        .allocator = allocator,
        .server = try conformance.scripted.ScriptedHttpServer.init(options.fixture_allocator orelse allocator, io, options.response),
        .transport = undefined,
        .url = undefined,
        .expect_request = options.expect_request,
    };
    errdefer state.server.deinit();
    state.server.allow_peer_failure = options.allow_peer_failure;
    state.server.responses = options.responses;
    state.url = try state.server.allocUrl(allocator, "/conformance");
    errdefer allocator.free(state.url);
    state.transport = try adapter.HttpxTransport.init(allocator, io, .{
        .max_buffered_response = if (options.max_response_body) |limit| .limited(limit) else .unlimited,
    });
    errdefer state.transport.deinit();
    try state.server.start();
    return .{
        .transport = state.transport.asTransport(),
        .url = state.url,
        .context = state,
        .finishFn = Backend.finish,
        .observeFn = Backend.observe,
        .deinitFn = Backend.destroy,
        .attemptFn = Backend.attempt,
        .assertQuiescentFn = Backend.quiescent,
    };
}
