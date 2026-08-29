const std = @import("std");
const core = @import("azure_sdk_core");
const testing = @import("azure_sdk_testing");
const conformance = @import("azure_sdk_core_http_conformance");

const State = struct {
    allocator: std.mem.Allocator,
    url: []u8,
    response_headers: []testing.HeaderPair,
    recordings: [1]testing.RecordedExchange,
    playback: testing.PlaybackTransport,

    fn finish(_: *anyopaque) !void {}

    fn observe(context: *anyopaque) conformance.Observation {
        const self: *State = @ptrCast(@alignCast(context));
        return .{ .request_count = self.playback.index };
    }

    fn destroy(context: *anyopaque) void {
        const self: *State = @ptrCast(@alignCast(context));
        self.allocator.free(self.response_headers);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

fn createBackend(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    _: std.Io,
    options: conformance.BackendOptions,
) !conformance.BackendInstance {
    const state = try allocator.create(State);
    errdefer allocator.destroy(state);
    const url = try allocator.dupe(u8, "https://example.com/conformance");
    errdefer allocator.free(url);
    const response_headers = try allocator.alloc(
        testing.HeaderPair,
        options.response.headers.len,
    );
    errdefer allocator.free(response_headers);
    for (options.response.headers, response_headers) |header, *pair| {
        pair.* = .{ .name = header.name, .value = header.value };
    }
    state.* = .{
        .allocator = allocator,
        .url = url,
        .response_headers = response_headers,
        .recordings = .{.{
            .request_method = .GET,
            .request_url = url,
            .request_headers = &.{
                .{
                    .name = "User-Agent",
                    .value = "azsdk-zig-conformance/0.3.0",
                },
            },
            .response_status = options.response.status_code,
            .response_body = options.response.body,
            .response_headers = response_headers,
        }},
        .playback = undefined,
    };
    state.playback = testing.PlaybackTransport.init(
        allocator,
        &state.recordings,
    );
    return .{
        .transport = state.playback.asTransport(),
        .url = state.url,
        .context = state,
        .finishFn = &State.finish,
        .observeFn = &State.observe,
        .deinitFn = &State.destroy,
    };
}

fn playbackFactory() conformance.BackendFactory {
    return .{
        .name = "azure_sdk_testing.PlaybackTransport",
        .capabilities = .{
            .streaming = true,
            .ordered_duplicate_response_headers = true,
            .request_framing_validation = true,
            .cancellation = .cooperative_upload,
            .lifecycle_observable = true,
        },
        .createFn = &createBackend,
    };
}

test "playback participates in compatible Core pipeline conformance" {
    try conformance.runPipelineContracts(
        std.testing.allocator,
        std.testing.io,
        playbackFactory(),
    );
}

test "Core exported allocation conformance remains leak-free" {
    try conformance.runAllocationFailureContracts();
}
