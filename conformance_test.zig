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
    observed_body: std.ArrayList(u8) = .empty,
    request_count: usize = 0,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &send,
        .open = &open,
    };

    fn finish(_: *anyopaque) !void {}

    fn observe(context: *anyopaque) conformance.Observation {
        const self: *State = @ptrCast(@alignCast(context));
        return .{
            .request_count = self.request_count,
            .body = self.observed_body.items,
            .body_length = self.observed_body.items.len,
            .finish_count = self.playback.finish_count,
            .abort_count = self.playback.abort_count,
            .cancel_count = self.playback.cancel_count,
            .deinit_count = self.playback.deinit_count,
        };
    }

    fn asTransport(self: *State) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn send(
        context: *anyopaque,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *State = @ptrCast(@alignCast(context));
        const transport = self.playback.asTransport();
        const response = try transport.vtable.send(
            transport.context,
            request,
        );
        self.request_count += 1;
        if (request.body) |body| {
            try self.observed_body.appendSlice(self.allocator, body);
        }
        return response;
    }

    fn open(
        context: *anyopaque,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *State = @ptrCast(@alignCast(context));
        const transport = self.playback.asTransport();
        const open_fn = transport.vtable.open.?;
        var wrapped_options = options;
        var observer: ObservingReader = undefined;
        if (options.body) |body| {
            observer.init(self, body.reader);
            wrapped_options.body.?.reader = &observer.interface;
        }
        const operation = try open_fn(
            transport.context,
            request,
            wrapped_options,
        );
        self.request_count += 1;
        return operation;
    }

    fn destroy(context: *anyopaque) void {
        const self: *State = @ptrCast(@alignCast(context));
        self.observed_body.deinit(self.allocator);
        self.allocator.free(self.response_headers);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

const ObservingReader = struct {
    interface: std.Io.Reader,
    source: *std.Io.Reader,
    state: *State,
    buffer: [64]u8 = undefined,
    scratch: [4096]u8 = undefined,

    fn init(
        self: *ObservingReader,
        state: *State,
        source: *std.Io.Reader,
    ) void {
        self.* = .{
            .interface = undefined,
            .source = source,
            .state = state,
        };
        self.interface = .{
            .vtable = &.{ .stream = &stream },
            .buffer = &self.buffer,
            .seek = 0,
            .end = 0,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *ObservingReader =
            @alignCast(@fieldParentPtr("interface", interface));
        const length = limit.minInt(self.scratch.len);
        if (length == 0) return 0;
        const count = self.source.readSliceShort(
            self.scratch[0..length],
        ) catch return error.ReadFailed;
        if (count == 0) return error.EndOfStream;
        self.state.observed_body.appendSlice(
            self.state.allocator,
            self.scratch[0..count],
        ) catch return error.ReadFailed;
        try writer.writeAll(self.scratch[0..count]);
        return count;
    }
};

fn createBackend(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    _: std.Io,
    options: conformance.BackendOptions,
) !conformance.BackendInstance {
    const streaming = std.mem.eql(
        u8,
        options.response.body,
        "stream-response",
    );
    const buffered = std.mem.eql(
        u8,
        options.response.body,
        "buffered-response",
    );
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
            .request_method = if (streaming) .POST else .GET,
            .request_url = url,
            .request_headers = if (buffered) &.{
                .{
                    .name = "User-Agent",
                    .value = "azsdk-zig-conformance/0.3.0",
                },
            } else &.{},
            .request_body = if (streaming) "stream-upload" else null,
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
        .transport = state.asTransport(),
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

test "playback satisfies Core raw transport conformance" {
    try conformance.runRawTransportContracts(
        std.testing.allocator,
        std.testing.io,
        playbackFactory(),
    );
}

test "Core exported allocation conformance remains leak-free" {
    try conformance.runAllocationFailureContracts();
}
