const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
const core = adapter.core;
const httpx = adapter.httpx;
const conformance = @import("azure_sdk_core_http_conformance");

const Phase = conformance.InterruptionPhase;
const Trigger = conformance.InterruptionTrigger;
const Evidence = conformance.InterruptionEvidence;
const request_budget_ms = 500;
const observation_budget_ms = 1000;
const ping_payload = "az-phase";

pub const phases = conformance.InterruptionPhases.initMany(&.{
    .connect,
    .upload_write,
    .response_headers,
    .response_body,
    .finish_drain,
});

pub const Sample = struct {
    phase: Phase,
    trigger: Trigger,
    evidence: Evidence,
    connect_requests: usize,
    ping_acks: usize,
    uploaded_bytes: usize,
    body_credit: usize,
};

pub const Report = struct {
    samples: [10]Sample = undefined,
    count: usize = 0,

    fn append(self: *Report, sample: Sample) !void {
        if (self.count == self.samples.len) return error.TooManyInterruptionSamples;
        self.samples[self.count] = sample;
        self.count += 1;
    }
};

pub fn run(
    context: ?*anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
    phase: Phase,
    trigger: Trigger,
) !Evidence {
    return runScenario(context, allocator, io, phase, trigger, false);
}

fn runScenario(
    context: ?*anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
    phase: Phase,
    trigger: Trigger,
    withhold_probe: bool,
) !Evidence {
    if (!phases.contains(phase)) return error.UnsupportedInterruptionPair;
    var address: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
    var fixture: Fixture = .{
        .io = io,
        .phase = phase,
        .trigger = trigger,
        .withhold_probe = withhold_probe,
        .listener = try address.listen(io, .{ .reuse_address = true }),
        .transport = undefined,
        .request = undefined,
    };
    defer fixture.listener.deinit(io);
    const port = fixture.listener.socket.address.getPort();
    const url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/interruption", .{port});
    defer allocator.free(url);
    fixture.request = core.http.Request.init(allocator, if (phase == .upload_write) .POST else .GET, url);
    defer fixture.request.deinit();
    fixture.transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{
            .max_request_size = 0,
            .max_response_size = 0,
            .http2_enabled = phase != .connect,
            .drain_timeout_ms = 0,
            .timeouts = .{
                .connect_ms = 0,
                .read_ms = 0,
                .write_ms = 0,
                .request_ms = if (trigger == .deadline) request_budget_ms else 0,
            },
            .proxy = if (phase == .connect) .{
                .kind = .socks5h,
                .host = "127.0.0.1",
                .port = port,
            } else null,
        },
    });
    defer fixture.transport.deinit();
    const evidence = try fixture.exercise();
    if (context) |value| {
        const report: *Report = @ptrCast(@alignCast(value));
        try report.append(.{
            .phase = phase,
            .trigger = trigger,
            .evidence = evidence,
            .connect_requests = fixture.connect_requests,
            .ping_acks = fixture.ping_acks,
            .uploaded_bytes = fixture.uploaded_bytes,
            .body_credit = fixture.body_credit,
        });
    }
    return evidence;
}

const Fixture = struct {
    io: std.Io,
    phase: Phase,
    trigger: Trigger,
    withhold_probe: bool,
    listener: std.Io.net.Server,
    transport: adapter.HttpxTransport,
    request: core.http.Request,
    token: core.http.CancellationToken = .{},
    peer_thread: ?std.Thread = null,
    worker_thread: ?std.Thread = null,
    mutex: std.Io.Mutex = .init,
    stopping: bool = false,
    active_stream: ?std.Io.net.Stream = null,
    started: std.Io.Event = .unset,
    phase_entered: std.Io.Event = .unset,
    worker_done: std.Io.Event = .unset,
    peer_done: std.Io.Event = .unset,
    started_ns: i96 = 0,
    phase_ns: i96 = 0,
    finished_ns: i96 = 0,
    peer_finished_ns: i96 = 0,
    outcome: anyerror = error.WorkerDidNotRun,
    peer_failure: ?anyerror = null,
    transport_started: bool = false,
    live_operations: usize = 0,
    leased_connections: usize = 0,
    total_connections: usize = 0,
    peer_close_count: usize = 0,
    connect_requests: usize = 0,
    ping_acks: usize = 0,
    uploaded_bytes: usize = 0,
    body_credit: usize = 0,

    fn now(self: *const Fixture) i96 {
        return std.Io.Timestamp.now(self.io, .awake).toNanoseconds();
    }

    fn waitUntil(self: *Fixture, event: *std.Io.Event, deadline_ns: i96) !void {
        try event.waitTimeout(self.io, .{ .duration = .{
            .raw = .fromNanoseconds(@max(0, deadline_ns - self.now())),
            .clock = .awake,
        } });
    }

    fn exercise(self: *Fixture) !Evidence {
        // This controller is the scoped watchdog. Every failure, including
        // thread-spawn failure, shuts down the peer and joins both workers.
        defer self.stopAndJoin();
        self.peer_thread = try std.Thread.spawn(.{}, peerMain, .{self});
        self.worker_thread = try std.Thread.spawn(.{}, workerMain, .{self});
        try self.waitUntil(&self.started, self.now() + observation_budget_ms * std.time.ns_per_ms);
        const earliest_expiry = self.started_ns + request_budget_ms * std.time.ns_per_ms;
        try self.waitUntil(&self.phase_entered, if (self.trigger == .deadline)
            earliest_expiry
        else
            self.started_ns + observation_budget_ms * std.time.ns_per_ms);
        // An acknowledged control frame must not be followed by premature
        // success/failure before the intended interruption.
        if (self.worker_done.waitTimeout(self.io, .{ .duration = .{ .raw = .zero, .clock = .awake } })) |_| {
            return error.PhaseCompletedBeforeInterruption;
        } else |err| switch (err) {
            error.Timeout => {},
            else => return err,
        }
        const signal_ns = if (self.trigger == .token) self.now() else earliest_expiry;
        if (self.phase_ns >= signal_ns) return error.PhaseNotEnteredBeforeInterruption;
        if (self.trigger == .token) self.token.cancel();
        const completion_deadline = signal_ns + observation_budget_ms * std.time.ns_per_ms;
        try self.waitUntil(&self.worker_done, completion_deadline);
        self.worker_thread.?.join();
        self.worker_thread = null;
        // Never release the withheld protocol bytes to make an abort pass.
        // The peer must instead observe the client's own EOF/reset.
        try self.waitUntil(&self.peer_done, completion_deadline);
        self.peer_thread.?.join();
        self.peer_thread = null;
        if (self.peer_failure) |err| return err;
        if (self.finished_ns < signal_ns) return error.InterruptionCompletedBeforeTrigger;
        if (self.total_connections != 0) return error.InterruptedConnectionWasReused;
        return .{
            .phase_entered = self.phase_ns > self.started_ns and self.phase_ns < signal_ns and
                (if (self.phase == .connect) self.connect_requests == 1 else self.ping_acks == 1),
            .transport_started = self.transport_started,
            .outcome = self.outcome,
            // For deadlines, the timestamp immediately before Core dispatch
            // plus request_ms is an EARLIER bound on HTTPX's actual expiry.
            // This conservatively overestimates, never understates latency.
            .elapsed_ms = @intCast(@divTrunc(
                @max(self.finished_ns, self.peer_finished_ns) - signal_ns + std.time.ns_per_ms - 1,
                std.time.ns_per_ms,
            )),
            .cleanup_count = self.peer_close_count,
            .live_operations = self.live_operations,
            .leased_connections = self.leased_connections,
        };
    }

    fn workerMain(self: *Fixture) void {
        self.started_ns = self.now();
        self.started.set(self.io);
        self.performOperation() catch |err| {
            self.outcome = err;
        };
        self.transport_started = self.request.transport_started;
        self.live_operations = self.transport.live_operations;
        const stats = self.transport.poolStats();
        self.leased_connections = stats.active;
        self.total_connections = stats.total;
        self.finished_ns = self.now();
        self.worker_done.set(self.io);
    }

    fn performOperation(self: *Fixture) !void {
        var upload = conformance.fakes.RepeatingReader.init('u', 128 * 1024);
        const operation = try self.transport.asTransport().open(&self.request, .{
            .cancellation = &self.token,
            .body = if (self.phase == .upload_write)
                core.http.StreamingRequestBody.knownLength(&upload.interface, 128 * 1024)
            else
                null,
        });
        defer operation.deinit();
        switch (self.phase) {
            .response_body => {
                var bytes: [2]u8 = undefined;
                (try operation.reader()).readSliceAll(&bytes) catch |err|
                    return operation.bodyError() orelse err;
            },
            .finish_drain => try operation.finish(),
            else => return error.OperationUnexpectedlyOpened,
        }
        return error.OperationUnexpectedlyCompleted;
    }

    fn markPhase(self: *Fixture) void {
        self.phase_ns = self.now();
        self.phase_entered.set(self.io);
    }

    fn peerMain(self: *Fixture) void {
        defer {
            self.peer_finished_ns = self.now();
            self.peer_done.set(self.io);
        }
        self.serve() catch |err| {
            self.peer_failure = err;
        };
    }

    fn serve(self: *Fixture) !void {
        const stream = try self.listener.accept(self.io);
        self.mutex.lockUncancelable(self.io);
        if (self.stopping) {
            stream.close(self.io);
            self.mutex.unlock(self.io);
            return;
        }
        self.active_stream = stream;
        self.mutex.unlock(self.io);
        defer {
            self.mutex.lockUncancelable(self.io);
            self.active_stream = null;
            stream.close(self.io);
            self.mutex.unlock(self.io);
        }
        var input_buffer: [1024]u8 = undefined;
        var output_buffer: [1024]u8 = undefined;
        var input = stream.reader(self.io, &input_buffer);
        var output = stream.writer(self.io, &output_buffer);
        if (self.phase == .connect) {
            try self.negotiateProxy(&input.interface, &output.interface);
        } else {
            try self.negotiateHttp2(&input.interface, &output.interface);
        }
        // Count an observed owner close, not the fixture's own deferred close.
        // There is exactly one accepted connection and no peer release signal.
        var remaining: [1024]u8 = undefined;
        while (true) {
            const count = input.interface.readSliceShort(&remaining) catch |err| {
                if (err == error.ReadFailed) {
                    if (input.err) |read_error| {
                        if (read_error == error.ConnectionResetByPeer) {
                            self.peer_close_count += 1;
                            return;
                        }
                    }
                }
                return err;
            };
            if (count == 0) {
                self.peer_close_count += 1;
                return;
            }
        }
    }

    fn negotiateProxy(self: *Fixture, reader: *std.Io.Reader, writer: *std.Io.Writer) !void {
        var greeting: [3]u8 = undefined;
        try reader.readSliceAll(&greeting);
        try std.testing.expectEqualSlices(u8, &.{ 5, 1, 0 }, &greeting);
        try writer.writeAll(&.{ 5, 0 });
        try writer.flush();
        var connect: [10]u8 = undefined;
        try reader.readSliceAll(&connect);
        try std.testing.expectEqualSlices(u8, &.{ 5, 1, 0, 1, 127, 0, 0, 1 }, connect[0..8]);
        self.connect_requests += 1;
        // The native connect phase has consumed our method selection and sent
        // CONNECT. No SOCKS success reply is sent, so it cannot leave this phase.
        self.markPhase();
    }

    fn negotiateHttp2(self: *Fixture, reader: *std.Io.Reader, writer: *std.Io.Writer) !void {
        var preface: [httpx.http.HTTP2_PREFACE.len]u8 = undefined;
        try reader.readSliceAll(&preface);
        try std.testing.expectEqualStrings(httpx.http.HTTP2_PREFACE, &preface);
        var payload: [64 * 1024]u8 = undefined;
        const settings = try readFrame(reader, &payload);
        if (settings.frame_type != .settings or settings.flags != 0) return error.MissingClientSettings;
        const zero_window = [_]u8{ 0, 4, 0, 0, 0, 0 };
        try writeFrame(writer, .settings, 0, 0, if (self.phase == .upload_write) &zero_window else &.{});
        try writeFrame(writer, .settings, 1, 0, &.{});
        var stream_id: u31 = 0;
        var request_finished = false;
        while (stream_id == 0 or (self.phase != .upload_write and !request_finished)) {
            const frame = try readFrame(reader, &payload);
            if (frame.frame_type == .headers) {
                stream_id = frame.stream_id;
                if (stream_id == 0 or frame.flags & 4 == 0) return error.InvalidFixtureRequestHeaders;
            }
            if (frame.frame_type == .headers or frame.frame_type == .data) {
                if (frame.flags & 1 != 0) request_finished = true;
            }
        }
        if (self.phase == .response_body or self.phase == .finish_drain) {
            // Indexed HPACK :status 200, followed by one byte without END_STREAM.
            try writeFrame(writer, .headers, 4, stream_id, &.{0x88});
            try writeFrame(writer, .data, 0, stream_id, "x");
        }
        if (self.withhold_probe) return;
        try writeFrame(writer, .ping, 0, 0, ping_payload);
        while (self.ping_acks == 0) {
            const frame = try readFrame(reader, &payload);
            const bytes = payload[0..frame.length];
            switch (frame.frame_type) {
                .ping => {
                    if (frame.flags != 1 or frame.stream_id != 0 or
                        !std.mem.eql(u8, ping_payload, bytes)) return error.InvalidFixturePingAck;
                    self.ping_acks += 1;
                },
                .data => {
                    if (self.phase != .upload_write or frame.flags & 1 != 0)
                        return error.UnexpectedFixtureUpload;
                    self.uploaded_bytes += frame.length;
                },
                .window_update => {
                    if (frame.stream_id == stream_id) {
                        if (bytes.len != 4) return error.InvalidFixtureWindowUpdate;
                        self.body_credit += std.mem.readInt(u32, bytes[0..4], .big);
                    }
                },
                .settings => {},
                else => return error.UnexpectedFixtureFrame,
            }
        }
        switch (self.phase) {
            .upload_write => if (self.uploaded_bytes == 0 or self.uploaded_bytes >= 128 * 1024)
                return error.UploadWasNotFlowControlBlocked,
            .response_body, .finish_drain => if (self.body_credit != 1)
                return error.ResponseBodyWasNotConsumed,
            .response_headers => {},
            else => unreachable,
        }
        // Only the active native read/pump can ACK this PING. No response head,
        // END_STREAM or WINDOW_UPDATE is provided to complete the target phase.
        self.markPhase();
    }

    fn stopAndJoin(self: *Fixture) void {
        if (self.worker_thread != null or self.peer_thread != null) {
            self.token.cancel();
            self.mutex.lockUncancelable(self.io);
            self.stopping = true;
            const accepting = self.active_stream == null;
            if (self.active_stream) |stream| stream.shutdown(self.io, .both) catch {};
            self.mutex.unlock(self.io);
            if (accepting and self.peer_thread != null) {
                if (self.listener.socket.address.connect(self.io, .{ .mode = .stream })) |wake| {
                    wake.close(self.io);
                } else |_| {}
            }
        }
        if (self.worker_thread) |thread| {
            thread.join();
            self.worker_thread = null;
        }
        if (self.peer_thread) |thread| {
            thread.join();
            self.peer_thread = null;
        }
    }
};

fn readFrame(reader: *std.Io.Reader, payload: []u8) !httpx.HTTP2FrameHeader {
    var raw: [9]u8 = undefined;
    try reader.readSliceAll(&raw);
    const frame = httpx.HTTP2FrameHeader.parse(raw);
    if (frame.length > payload.len) return error.FixtureFrameTooLarge;
    try reader.readSliceAll(payload[0..frame.length]);
    return frame;
}

fn writeFrame(writer: *std.Io.Writer, kind: httpx.HTTP2FrameType, flags: u8, stream_id: u31, payload: []const u8) !void {
    const frame: httpx.HTTP2FrameHeader = .{
        .length = @intCast(payload.len),
        .frame_type = kind,
        .flags = flags,
        .stream_id = stream_id,
    };
    try writer.writeAll(&frame.serialize());
    try writer.writeAll(payload);
    try writer.flush();
}

test "interruption watchdog stops and joins without producing evidence" {
    var report: Report = .{};
    try std.testing.expectError(error.Timeout, runScenario(
        &report,
        std.testing.allocator,
        std.testing.io,
        .response_headers,
        .token,
        true,
    ));
    try std.testing.expectEqual(@as(usize, 0), report.count);
}
