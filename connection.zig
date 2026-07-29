//! AMQP 1.0 connection driver.
//!
//! Drives the protocol header exchange, SASL, and the connection- and
//! session-level performatives over a `Transport`. `azure-uamqp-zig` supplies
//! the frame header layout and type system; the state machine, negotiation,
//! and keep-alives live here.
//!
//! The driver is synchronous and single threaded. Every call that can wait
//! takes a deadline in milliseconds on the driver's clock, so a stalled peer
//! surfaces `error.Timeout` rather than hanging.

const std = @import("std");
const uamqp = @import("uamqp");
const transport_mod = @import("transport.zig");
const perf = @import("performative.zig");

const Allocator = std.mem.Allocator;
const frame = uamqp.frame;
const FrameHeader = uamqp.frame.FrameHeader;
const FrameType = uamqp.frame.FrameType;
const MapEntry = uamqp.MapEntry;

pub const Transport = transport_mod.Transport;

/// Capability advertised so the service enables geo-replication metadata.
///
/// Go spells this `com.microsoft:georeplication`
/// (`internal/constants.go:10`); the Rust client uses a dot instead of a
/// colon, which does not match the service's error conditions such as
/// `com.microsoft:georeplication:invalid-offset`. Go's spelling is used here.
pub const georeplication_capability = "com.microsoft:georeplication";

pub const sasl_anonymous = "ANONYMOUS";

/// Initial response Go sends for anonymous SASL (`sasl.go:75`).
pub const sasl_anonymous_response = "anonymous";

/// Includes the encoder's failure modes by union rather than by restating
/// them, so a value the encoder cannot represent surfaces as itself instead of
/// being flattened into a transport error.
pub const ConnectionError = perf.EncodeError || error{
    OutOfMemory,
    ConnectionFailed,
    ConnectionClosed,
    ReadFailed,
    WriteFailed,
    TlsFailed,
    /// The peer answered a protocol header with a different protocol or version.
    ProtocolMismatch,
    /// The peer rejected the SASL exchange.
    SaslFailed,
    /// The peer offered no mechanism the driver can use.
    SaslMechanismUnsupported,
    /// A frame arrived that the current state does not allow.
    UnexpectedPerformative,
    /// A frame exceeded the negotiated `max-frame-size`.
    FrameTooLarge,
    MalformedFrame,
    /// The peer closed the connection; inspect `remoteError`.
    RemoteClosed,
    /// The peer went silent past a deadline or past the advertised idle timeout.
    Timeout,
    InvalidState,
};

// ─────────────────────── Clock ───────────────────────

/// Millisecond clock seam so tests can drive idle-timeout behaviour without
/// sleeping.
pub const Clock = struct {
    ptr: *anyopaque,
    nowMillisFn: *const fn (ptr: *anyopaque) i64,

    pub fn nowMillis(self: Clock) i64 {
        return self.nowMillisFn(self.ptr);
    }
};

/// A clock backed by the monotonic clock of an `std.Io` implementation.
pub const IoClock = struct {
    io: std.Io,

    pub fn init(io: std.Io) IoClock {
        return .{ .io = io };
    }

    pub fn clock(self: *IoClock) Clock {
        return .{ .ptr = self, .nowMillisFn = nowMillis };
    }

    fn nowMillis(ptr: *anyopaque) i64 {
        const self: *IoClock = @ptrCast(@alignCast(ptr));
        const ts = std.Io.Timestamp.now(self.io, .awake);
        return @intCast(@divTrunc(ts.nanoseconds, std.time.ns_per_ms));
    }
};

/// A clock tests move by hand.
///
/// `auto_advance_ms` bumps the clock on every read, which lets a starved
/// transport reach a deadline instead of spinning forever.
pub const ManualClock = struct {
    millis: i64 = 0,
    auto_advance_ms: i64 = 0,

    pub fn clock(self: *ManualClock) Clock {
        return .{ .ptr = self, .nowMillisFn = nowMillis };
    }

    pub fn advance(self: *ManualClock, ms: i64) void {
        self.millis += ms;
    }

    fn nowMillis(ptr: *anyopaque) i64 {
        const self: *ManualClock = @ptrCast(@alignCast(ptr));
        const now = self.millis;
        self.millis += self.auto_advance_ms;
        return now;
    }
};

// ─────────────────────── Options ───────────────────────

pub const SaslMode = enum {
    /// Skip the SASL layer entirely.
    none,
    /// ANONYMOUS, which is what Event Hubs expects because CBS carries the
    /// real credential (`internal/namespace.go:177`).
    anonymous,
};

pub const Options = struct {
    container_id: []const u8,
    /// Virtual host sent in `open`, normally the fully qualified namespace.
    hostname: ?[]const u8 = null,
    /// Largest frame the driver will accept from the peer.
    max_frame_size: u32 = 65536,
    /// Highest session channel the driver will accept. Go asks for 65535.
    channel_max: u16 = 65535,
    /// Idle timeout advertised to the peer, in milliseconds.
    idle_timeout_ms: ?u32 = 60_000,
    properties: ?perf.Fields = null,
    desired_capabilities: ?[]const []const u8 = null,
    sasl: SaslMode = .anonymous,
};

/// Identifying strings the service records for a connection.
pub const ClientInfo = struct {
    product: []const u8,
    version: []const u8,
    platform: []const u8,
    user_agent: []const u8,
};

/// Default client info for this SDK, matching the shape Go and Rust send.
pub fn defaultClientInfo(version: []const u8, user_agent: []const u8) ClientInfo {
    return .{
        .product = "azure-sdk-for-zig",
        .version = version,
        .platform = @tagName(@import("builtin").os.tag),
        .user_agent = user_agent,
    };
}

/// Build the `open` properties map Azure expects. Caller owns the result.
pub fn buildProperties(allocator: Allocator, info: ClientInfo) Allocator.Error![]MapEntry {
    const entries = try allocator.alloc(MapEntry, 4);
    entries[0] = .{ .key = .{ .symbol = "product" }, .value = .{ .string = info.product } };
    entries[1] = .{ .key = .{ .symbol = "version" }, .value = .{ .string = info.version } };
    entries[2] = .{ .key = .{ .symbol = "platform" }, .value = .{ .string = info.platform } };
    entries[3] = .{ .key = .{ .symbol = "user-agent" }, .value = .{ .string = info.user_agent } };
    return entries;
}

// ─────────────────────── Driver ───────────────────────

/// An error condition reported by the peer, owned by the driver.
pub const RemoteError = struct {
    condition: []const u8,
    description: ?[]const u8,

    /// Copy an inbound error so it outlives the frame it arrived in.
    pub fn dupe(allocator: Allocator, err: perf.AmqpError) Allocator.Error!RemoteError {
        const condition = try allocator.dupe(u8, err.condition);
        errdefer allocator.free(condition);
        return .{
            .condition = condition,
            .description = if (err.description) |d| try allocator.dupe(u8, d) else null,
        };
    }

    pub fn deinit(self: RemoteError, allocator: Allocator) void {
        allocator.free(self.condition);
        if (self.description) |d| allocator.free(d);
    }
};

/// A frame handed back by `receiveFrame`. The body is owned by the driver and
/// stays valid until the next receive.
pub const InboundFrame = struct {
    header: FrameHeader,
    body: []const u8,
};

/// A per-channel frame sink, used by sessions and links.
pub const FrameHandler = struct {
    ptr: *anyopaque,
    onFrameFn: *const fn (ptr: *anyopaque, header: FrameHeader, body: []const u8) void,

    pub fn onFrame(self: FrameHandler, header: FrameHeader, body: []const u8) void {
        self.onFrameFn(self.ptr, header, body);
    }
};

pub const State = enum {
    start,
    header_exchanged,
    open_sent,
    opened,
    close_sent,
    closed,
    err,
};

pub const Driver = struct {
    allocator: Allocator,
    transport: Transport,
    clock: Clock,
    options: Options,
    state: State = .start,

    /// Negotiated from the peer's `open`.
    remote_max_frame_size: u32 = frame.min_max_frame_size,
    remote_channel_max: u16 = 0,
    remote_idle_timeout_ms: ?u32 = null,
    remote_container_id: ?[]u8 = null,
    remote_error: ?RemoteError = null,

    last_sent_ms: i64 = 0,
    /// Null until the first byte arrives, so an idle check cannot fire before
    /// the connection has seen any traffic.
    last_received_ms: ?i64 = null,

    handlers: std.AutoHashMapUnmanaged(u16, FrameHandler) = .empty,
    /// Streaming input buffer. Frame bodies are copied out of it, so it only
    /// has to be large enough to make reads efficient.
    in_buf: []u8,
    in_start: usize = 0,
    in_end: usize = 0,
    /// The body most recently returned by `receiveFrame`, owned by the driver.
    current_body: ?[]u8 = null,
    current_header: ?FrameHeader = null,

    const in_buf_len = 16 * 1024;

    pub fn init(
        allocator: Allocator,
        transport: Transport,
        clock: Clock,
        options: Options,
    ) Allocator.Error!Driver {
        return .{
            .allocator = allocator,
            .transport = transport,
            .clock = clock,
            .options = options,
            .in_buf = try allocator.alloc(u8, in_buf_len),
        };
    }

    pub fn deinit(self: *Driver) void {
        if (self.current_body) |b| self.allocator.free(b);
        self.handlers.deinit(self.allocator);
        self.allocator.free(self.in_buf);
        if (self.remote_container_id) |id| self.allocator.free(id);
        if (self.remote_error) |*e| e.deinit(self.allocator);
        self.* = undefined;
    }

    /// The condition the peer closed with, if any.
    pub fn remoteError(self: *const Driver) ?RemoteError {
        return self.remote_error;
    }

    /// Largest frame body the driver may send, honouring the peer's `open`.
    pub fn maxOutgoingBody(self: *const Driver) usize {
        return self.remote_max_frame_size - frame.frame_header_size;
    }

    /// Interval between keep-alives, half the peer's advertised idle timeout as
    /// both Go and the AMQP guidance recommend.
    pub fn keepaliveIntervalMs(self: *const Driver) ?i64 {
        const remote = self.remote_idle_timeout_ms orelse return null;
        if (remote == 0) return null;
        return @max(@as(i64, 1), @divTrunc(@as(i64, remote), 2));
    }

    // ── Handshake ──

    /// Run the full handshake: SASL if configured, then `open`.
    pub fn open(self: *Driver, deadline_ms: i64) ConnectionError!void {
        if (self.state != .start) return error.InvalidState;

        if (self.options.sasl != .none) try self.runSasl(deadline_ms);

        try self.exchangeHeader(&frame.amqp_header, deadline_ms);
        self.state = .header_exchanged;

        try self.sendOpen();
        self.state = .open_sent;

        const inbound = try self.receiveFrame(deadline_ms);
        var decoded = try self.decodeBody(inbound.body);
        defer decoded.deinit();

        switch (decoded.performative) {
            .open => |remote| try self.applyRemoteOpen(remote),
            .close => |c| {
                try self.recordRemoteError(c.err);
                self.state = .closed;
                return error.RemoteClosed;
            },
            else => {
                self.state = .err;
                return error.UnexpectedPerformative;
            },
        }
        self.state = .opened;
    }

    fn applyRemoteOpen(self: *Driver, remote: perf.Open) ConnectionError!void {
        self.remote_max_frame_size = @max(remote.max_frame_size, frame.min_max_frame_size);
        self.remote_channel_max = remote.channel_max;
        self.remote_idle_timeout_ms = remote.idle_time_out;
        if (remote.container_id.len != 0) {
            self.remote_container_id = try self.allocator.dupe(u8, remote.container_id);
        }
    }

    fn runSasl(self: *Driver, deadline_ms: i64) ConnectionError!void {
        try self.exchangeHeader(&frame.sasl_header, deadline_ms);

        {
            const inbound = try self.receiveFrame(deadline_ms);
            var decoded = try self.decodeBody(inbound.body);
            defer decoded.deinit();
            const mechanisms = switch (decoded.performative) {
                .sasl_mechanisms => |m| m,
                else => return error.UnexpectedPerformative,
            };
            var supported = false;
            for (mechanisms.sasl_server_mechanisms) |name| {
                if (std.mem.eql(u8, name, sasl_anonymous)) supported = true;
            }
            if (!supported) return error.SaslMechanismUnsupported;
        }

        try self.sendPerformative(.sasl, 0, .{ .sasl_init = .{
            .mechanism = sasl_anonymous,
            .initial_response = sasl_anonymous_response,
            .hostname = self.options.hostname,
        } });

        const inbound = try self.receiveFrame(deadline_ms);
        var decoded = try self.decodeBody(inbound.body);
        defer decoded.deinit();
        const outcome = switch (decoded.performative) {
            .sasl_outcome => |o| o,
            else => return error.UnexpectedPerformative,
        };
        if (outcome.code != .ok) return error.SaslFailed;
    }

    fn exchangeHeader(self: *Driver, header: *const [8]u8, deadline_ms: i64) ConnectionError!void {
        try self.writeBytes(header);
        self.transport.flush() catch |e| return mapTransportError(e);
        var received: [8]u8 = undefined;
        try self.readExact(&received, deadline_ms);
        if (!std.mem.eql(u8, &received, header)) return error.ProtocolMismatch;
    }

    fn sendOpen(self: *Driver) ConnectionError!void {
        try self.sendPerformative(.amqp, 0, .{ .open = .{
            .container_id = self.options.container_id,
            .hostname = self.options.hostname,
            .max_frame_size = self.options.max_frame_size,
            .channel_max = self.options.channel_max,
            .idle_time_out = self.options.idle_timeout_ms,
            .desired_capabilities = self.options.desired_capabilities,
            .properties = self.options.properties,
        } });
    }

    // ── Sessions ──

    pub const SessionOptions = struct {
        next_outgoing_id: u32 = 0,
        incoming_window: u32 = 5000,
        outgoing_window: u32 = 5000,
        handle_max: u32 = std.math.maxInt(u32),
    };

    /// Send `begin` on `channel` and wait for the peer's `begin`.
    /// Returns the channel the peer chose.
    pub fn beginSession(
        self: *Driver,
        channel: u16,
        options: SessionOptions,
        deadline_ms: i64,
    ) ConnectionError!u16 {
        if (self.state != .opened) return error.InvalidState;
        if (channel > self.remote_channel_max) return error.InvalidState;

        try self.sendPerformative(.amqp, channel, .{ .begin = .{
            .next_outgoing_id = options.next_outgoing_id,
            .incoming_window = options.incoming_window,
            .outgoing_window = options.outgoing_window,
            .handle_max = options.handle_max,
        } });

        const inbound = try self.receiveFrame(deadline_ms);
        var decoded = try self.decodeBody(inbound.body);
        defer decoded.deinit();
        switch (decoded.performative) {
            .begin => return inbound.header.channel,
            .close => |c| {
                try self.recordRemoteError(c.err);
                self.state = .closed;
                return error.RemoteClosed;
            },
            .end => |e| {
                try self.recordRemoteError(e.err);
                return error.RemoteClosed;
            },
            else => return error.UnexpectedPerformative,
        }
    }

    /// Send `end` on `channel` and wait for the peer's `end`.
    pub fn endSession(self: *Driver, channel: u16, deadline_ms: i64) ConnectionError!void {
        try self.sendPerformative(.amqp, channel, .{ .end = .{} });
        const inbound = try self.receiveFrame(deadline_ms);
        var decoded = try self.decodeBody(inbound.body);
        defer decoded.deinit();
        switch (decoded.performative) {
            .end => |e| try self.recordRemoteError(e.err),
            .close => |c| {
                try self.recordRemoteError(c.err);
                self.state = .closed;
                return error.RemoteClosed;
            },
            else => return error.UnexpectedPerformative,
        }
    }

    // ── Close ──

    /// Send `close` and wait for the peer's `close`.
    pub fn close(self: *Driver, err: ?perf.AmqpError, deadline_ms: i64) ConnectionError!void {
        if (self.state == .closed) return;
        try self.sendPerformative(.amqp, 0, .{ .close = .{ .err = err } });
        self.state = .close_sent;

        const inbound = self.receiveFrame(deadline_ms) catch |e| switch (e) {
            error.ConnectionClosed => {
                self.state = .closed;
                return;
            },
            else => return e,
        };
        var decoded = try self.decodeBody(inbound.body);
        defer decoded.deinit();
        switch (decoded.performative) {
            .close => |c| try self.recordRemoteError(c.err),
            else => return error.UnexpectedPerformative,
        }
        self.state = .closed;
    }

    pub fn recordRemoteError(self: *Driver, err: ?perf.AmqpError) ConnectionError!void {
        const e = err orelse return;
        const copy = try RemoteError.dupe(self.allocator, e);
        if (self.remote_error) |old| old.deinit(self.allocator);
        self.remote_error = copy;
    }

    // ── Channel routing ──

    pub fn registerChannel(
        self: *Driver,
        channel: u16,
        handler: FrameHandler,
    ) Allocator.Error!void {
        try self.handlers.put(self.allocator, channel, handler);
    }

    pub fn unregisterChannel(self: *Driver, channel: u16) void {
        _ = self.handlers.remove(channel);
    }

    /// Read one frame, routing it to a registered channel when there is one.
    ///
    /// Returns the frame when no handler claimed it, so a caller can inspect
    /// performatives the driver does not model. Returns `error.RemoteClosed`
    /// when the peer closes; the condition is on `remoteError`.
    pub fn pump(self: *Driver, deadline_ms: i64) ConnectionError!?InboundFrame {
        try self.doWork();
        const inbound = try self.receiveFrame(deadline_ms);
        if (self.handlers.get(inbound.header.channel)) |handler| {
            handler.onFrame(inbound.header, inbound.body);
            return null;
        }
        if (inbound.header.channel == 0 and isClose(inbound.body)) {
            var decoded = try self.decodeBody(inbound.body);
            defer decoded.deinit();
            try self.recordRemoteError(decoded.performative.close.err);
            self.state = .closed;
            return error.RemoteClosed;
        }
        return inbound;
    }

    /// Emit a keep-alive if the peer's idle timeout is close, and fail if the
    /// peer itself has gone quiet for longer than the driver advertised.
    pub fn doWork(self: *Driver) ConnectionError!void {
        const now = self.clock.nowMillis();

        if (self.options.idle_timeout_ms) |local| {
            if (local != 0) {
                if (self.last_received_ms) |last| {
                    if (now - last > @as(i64, local) * 2) return error.Timeout;
                }
            }
        }

        const interval = self.keepaliveIntervalMs() orelse return;
        if (now - self.last_sent_ms < interval) return;
        try self.sendEmptyFrame();
    }

    /// Write an empty frame, the AMQP heartbeat.
    pub fn sendEmptyFrame(self: *Driver) ConnectionError!void {
        const header = FrameHeader{
            .size = @intCast(frame.frame_header_size),
            .doff = 2,
            .frame_type = .amqp,
            .channel = 0,
        };
        const bytes = header.serialize();
        try self.writeBytes(&bytes);
        self.transport.flush() catch |e| return mapTransportError(e);
        self.last_sent_ms = self.clock.nowMillis();
    }

    // ── Frame IO ──

    /// Encode and send a performative.
    pub fn sendPerformative(
        self: *Driver,
        frame_type: FrameType,
        channel: u16,
        performative: perf.Performative,
    ) ConnectionError!void {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        try perf.encode(self.allocator, performative, &buf);
        try self.sendFrame(frame_type, channel, buf.written());
    }

    /// Send a frame, rejecting bodies past the peer's `max-frame-size`.
    pub fn sendFrame(
        self: *Driver,
        frame_type: FrameType,
        channel: u16,
        body: []const u8,
    ) ConnectionError!void {
        const total = frame.frame_header_size + body.len;
        // Before `open` the peer has only guaranteed the spec minimum.
        const limit: usize = if (self.state == .opened or self.state == .close_sent)
            self.remote_max_frame_size
        else
            @max(self.remote_max_frame_size, frame.min_max_frame_size);
        if (total > limit) return error.FrameTooLarge;

        const header = FrameHeader{
            .size = @intCast(total),
            .doff = 2,
            .frame_type = frame_type,
            .channel = channel,
        };
        const header_bytes = header.serialize();
        try self.writeBytes(&header_bytes);
        try self.writeBytes(body);
        self.transport.flush() catch |e| return mapTransportError(e);
        self.last_sent_ms = self.clock.nowMillis();
    }

    /// Read the next non-empty frame.
    ///
    /// The returned body is owned by the driver and stays valid until the next
    /// receive. Empty frames (heartbeats) are consumed silently.
    ///
    /// Frames are read one at a time rather than through
    /// `uamqp.frame_codec.FrameCodec`: that codec streams whatever it is
    /// handed, which cannot work across the protocol-header exchange that
    /// separates the SASL layer from the AMQP layer.
    pub fn receiveFrame(self: *Driver, deadline_ms: i64) ConnectionError!InboundFrame {
        if (self.current_body) |b| {
            self.allocator.free(b);
            self.current_body = null;
            self.current_header = null;
        }
        while (true) {
            var header_bytes: [frame.frame_header_size]u8 = undefined;
            try self.readExact(&header_bytes, deadline_ms);
            const header = FrameHeader.parse(&header_bytes) catch return error.MalformedFrame;
            if (header.size > self.acceptMaxFrameSize()) return error.FrameTooLarge;

            const prefix: u32 = @as(u32, header.doff) * 4;
            if (prefix > header.size) return error.MalformedFrame;
            var skip = prefix - frame.frame_header_size;
            while (skip > 0) {
                var scratch: [64]u8 = undefined;
                const n = @min(skip, scratch.len);
                try self.readExact(scratch[0..n], deadline_ms);
                skip -= @intCast(n);
            }

            const body_size = header.size - prefix;
            if (body_size == 0) continue; // heartbeat

            const body = try self.allocator.alloc(u8, body_size);
            errdefer self.allocator.free(body);
            try self.readExact(body, deadline_ms);
            self.current_body = body;
            self.current_header = header;
            return .{ .header = header, .body = body };
        }
    }

    /// Largest frame the driver will accept, which is what it advertised in
    /// `open` but never below the spec minimum.
    pub fn acceptMaxFrameSize(self: *const Driver) u32 {
        return @max(self.options.max_frame_size, frame.min_max_frame_size);
    }

    /// Decode a frame body into a performative.
    pub fn decodeBody(self: *Driver, body: []const u8) ConnectionError!perf.Decoded {
        return perf.decode(self.allocator, body) catch |e| switch (e) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.MalformedFrame,
        };
    }

    fn buffered(self: *const Driver) []const u8 {
        return self.in_buf[self.in_start..self.in_end];
    }

    /// Pull one transport read into the input buffer, compacting first when
    /// the tail is full.
    fn fillMore(self: *Driver, deadline_ms: i64) ConnectionError!void {
        if (self.in_start == self.in_end) {
            self.in_start = 0;
            self.in_end = 0;
        } else if (self.in_end == self.in_buf.len) {
            std.mem.copyForwards(u8, self.in_buf, self.in_buf[self.in_start..self.in_end]);
            self.in_end -= self.in_start;
            self.in_start = 0;
        }
        if (self.clock.nowMillis() >= deadline_ms) return error.Timeout;
        const n = self.transport.read(self.in_buf[self.in_end..]) catch |e|
            return mapTransportError(e);
        if (n == 0) return; // starved; the caller loops until the deadline
        self.in_end += n;
        self.last_received_ms = self.clock.nowMillis();
    }

    fn readExact(self: *Driver, dst: []u8, deadline_ms: i64) ConnectionError!void {
        var filled: usize = 0;
        while (filled < dst.len) {
            const available = self.buffered();
            if (available.len != 0) {
                const n = @min(available.len, dst.len - filled);
                @memcpy(dst[filled..][0..n], available[0..n]);
                self.in_start += n;
                filled += n;
                continue;
            }
            try self.fillMore(deadline_ms);
        }
    }

    fn writeBytes(self: *Driver, bytes: []const u8) ConnectionError!void {
        self.transport.write(bytes) catch |e| return mapTransportError(e);
    }
};

fn isClose(body: []const u8) bool {
    const code = perf.peekDescriptor(body) orelse return false;
    return code == perf.descriptor.close;
}

fn mapTransportError(e: transport_mod.TransportError) ConnectionError {
    return switch (e) {
        error.ConnectionFailed => error.ConnectionFailed,
        error.ConnectionClosed => error.ConnectionClosed,
        error.ReadFailed => error.ReadFailed,
        error.WriteFailed => error.WriteFailed,
        error.TlsFailed => error.TlsFailed,
        error.OutOfMemory => error.OutOfMemory,
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const MemoryTransport = transport_mod.MemoryTransport;

/// A scripted peer: queues frames the driver will read.
const Peer = struct {
    allocator: Allocator,
    mem: *MemoryTransport,

    fn pushHeader(self: Peer, header: *const [8]u8) !void {
        try self.mem.pushPeerBytes(header);
    }

    fn push(self: Peer, frame_type: FrameType, channel: u16, p: perf.Performative) !void {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        try perf.encode(self.allocator, p, &buf);
        try self.pushRaw(frame_type, channel, buf.written());
    }

    fn pushRaw(self: Peer, frame_type: FrameType, channel: u16, body: []const u8) !void {
        const header = FrameHeader{
            .size = @intCast(frame.frame_header_size + body.len),
            .doff = 2,
            .frame_type = frame_type,
            .channel = channel,
        };
        const bytes = header.serialize();
        try self.mem.pushPeerBytes(&bytes);
        try self.mem.pushPeerBytes(body);
    }

    /// Fails if the driver ever blocked on a read while output was still
    /// buffered, which deadlocks against a real socket.
    fn expectNoUnflushedReads(self: Peer) !void {
        try std.testing.expectEqual(@as(usize, 0), self.mem.reads_with_pending_writes);
    }
};

const test_options = Options{
    .container_id = "zig",
    .hostname = "ns.servicebus.windows.net",
    .max_frame_size = 65536,
    .channel_max = 65535,
    .idle_timeout_ms = 60000,
    .desired_capabilities = &.{georeplication_capability},
    .sasl = .none,
};

/// The exact `open` performative `test_options` must produce.
fn expectedOpenBody(allocator: Allocator) ![]u8 {
    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(allocator);
    try body.appendSlice(allocator, &.{ 0xa1, 0x03 });
    try body.appendSlice(allocator, "zig");
    try body.appendSlice(allocator, &.{ 0xa1, 25 });
    try body.appendSlice(allocator, "ns.servicebus.windows.net");
    try body.appendSlice(allocator, &.{ 0x70, 0x00, 0x01, 0x00, 0x00 }); // max-frame-size
    try body.appendSlice(allocator, &.{ 0x60, 0xff, 0xff }); // channel-max
    try body.appendSlice(allocator, &.{ 0x70, 0x00, 0x00, 0xea, 0x60 }); // idle-time-out
    try body.appendSlice(allocator, &.{ 0x40, 0x40, 0x40 }); // locales, offered
    try body.appendSlice(allocator, &.{ 0xa3, 28 });
    try body.appendSlice(allocator, georeplication_capability);

    const list_len = body.items.len;
    try body.insertSlice(allocator, 0, &.{ 0x00, 0x53, 0x10, 0xc0, @intCast(list_len + 1), 9 });
    return body.toOwnedSlice(allocator);
}

test "open, begin, and close against a scripted peer" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{
        .container_id = "service-bus",
        .max_frame_size = 65536,
        .channel_max = 255,
        .idle_time_out = 240000,
    } });
    try peer.push(.amqp, 7, .{ .begin = .{
        .remote_channel = 0,
        .next_outgoing_id = 1,
        .incoming_window = 5000,
        .outgoing_window = 5000,
    } });
    try peer.push(.amqp, 0, .{ .close = .{} });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();

    try driver.open(10_000);
    try testing.expectEqual(State.opened, driver.state);
    try testing.expectEqualStrings("service-bus", driver.remote_container_id.?);
    try testing.expectEqual(@as(u32, 65536), driver.remote_max_frame_size);
    try testing.expectEqual(@as(u16, 255), driver.remote_channel_max);
    try testing.expectEqual(@as(i64, 120_000), driver.keepaliveIntervalMs().?);

    // The protocol header, then the open frame, byte for byte.
    const expected_body = try expectedOpenBody(allocator);
    defer allocator.free(expected_body);

    const written = mem.written();
    try testing.expectEqualSlices(u8, &frame.amqp_header, written[0..8]);

    const open_frame = written[8..][0 .. 8 + expected_body.len];
    const open_header = try FrameHeader.parse(open_frame[0..8]);
    try testing.expectEqual(@as(u32, @intCast(8 + expected_body.len)), open_header.size);
    try testing.expectEqual(@as(u8, 2), open_header.doff);
    try testing.expectEqual(FrameType.amqp, open_header.frame_type);
    try testing.expectEqual(@as(u16, 0), open_header.channel);
    try testing.expectEqualSlices(u8, expected_body, open_frame[8..]);

    const remote_channel = try driver.beginSession(0, .{}, 10_000);
    try testing.expectEqual(@as(u16, 7), remote_channel);

    try driver.close(null, 10_000);
    try testing.expectEqual(State.closed, driver.state);
    try peer.expectNoUnflushedReads();
}

test "SASL anonymous handshake precedes the open" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.sasl_header);
    try peer.push(.sasl, 0, .{ .sasl_mechanisms = .{
        .sasl_server_mechanisms = &.{ "MSSBCBS", "ANONYMOUS", "EXTERNAL" },
    } });
    try peer.push(.sasl, 0, .{ .sasl_outcome = .{ .code = .ok } });
    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{ .container_id = "service-bus" } });

    var options = test_options;
    options.sasl = .anonymous;
    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), options);
    defer driver.deinit();
    try driver.open(10_000);

    const written = mem.written();
    try testing.expectEqualSlices(u8, &frame.sasl_header, written[0..8]);

    // sasl-init on a SASL frame, then the plain AMQP header.
    const init_header = try FrameHeader.parse(written[8..16]);
    try testing.expectEqual(FrameType.sasl, init_header.frame_type);
    const init_body = written[16..][0 .. init_header.size - 8];
    var decoded = try perf.decode(allocator, init_body);
    defer decoded.deinit();
    try testing.expectEqualStrings("ANONYMOUS", decoded.performative.sasl_init.mechanism);
    try testing.expectEqualStrings("anonymous", decoded.performative.sasl_init.initial_response.?);
    try testing.expectEqualStrings("ns.servicebus.windows.net", decoded.performative.sasl_init.hostname.?);

    const after_init = 16 + init_header.size - 8;
    try testing.expectEqualSlices(u8, &frame.amqp_header, written[after_init..][0..8]);
    try peer.expectNoUnflushedReads();
}

test "a SASL failure surfaces as SaslFailed" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.sasl_header);
    try peer.push(.sasl, 0, .{ .sasl_mechanisms = .{ .sasl_server_mechanisms = &.{"ANONYMOUS"} } });
    try peer.push(.sasl, 0, .{ .sasl_outcome = .{ .code = .auth } });

    var options = test_options;
    options.sasl = .anonymous;
    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), options);
    defer driver.deinit();
    try testing.expectError(error.SaslFailed, driver.open(10_000));
}

test "a peer offering no usable mechanism is rejected" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.sasl_header);
    try peer.push(.sasl, 0, .{ .sasl_mechanisms = .{ .sasl_server_mechanisms = &.{"MSSBCBS"} } });

    var options = test_options;
    options.sasl = .anonymous;
    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), options);
    defer driver.deinit();
    try testing.expectError(error.SaslMechanismUnsupported, driver.open(10_000));
}

test "a mismatched protocol header is rejected" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    // The peer answers with the SASL header when plain AMQP was offered.
    try mem.pushPeerBytes(&frame.sasl_header);

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try testing.expectError(error.ProtocolMismatch, driver.open(10_000));
}

test "a peer that closes with a condition surfaces it" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .close = .{ .err = .{
        .condition = "amqp:unauthorized-access",
        .description = "Unauthorized access. 'Send' claim(s) are required.",
    } } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();

    try testing.expectError(error.RemoteClosed, driver.open(10_000));
    const err = driver.remoteError().?;
    try testing.expectEqualStrings("amqp:unauthorized-access", err.condition);
    try testing.expectEqualStrings(
        "Unauthorized access. 'Send' claim(s) are required.",
        err.description.?,
    );
}

test "a mid-session close is surfaced by pump" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{ .container_id = "service-bus" } });
    try peer.push(.amqp, 0, .{ .close = .{ .err = .{ .condition = "amqp:connection:forced" } } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);

    try testing.expectError(error.RemoteClosed, driver.pump(10_000));
    try testing.expectEqualStrings("amqp:connection:forced", driver.remoteError().?.condition);
    try testing.expectEqual(State.closed, driver.state);
}

test "an inbound frame past max-frame-size is rejected" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    // A header claiming more bytes than the driver advertised in `open`.
    const oversized = FrameHeader{
        .size = 4096,
        .doff = 2,
        .frame_type = .amqp,
        .channel = 0,
    };
    const bytes = oversized.serialize();
    try mem.pushPeerBytes(&bytes);

    var options = test_options;
    options.max_frame_size = 1024;
    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), options);
    defer driver.deinit();
    try testing.expectError(error.FrameTooLarge, driver.open(10_000));
}

test "an outbound frame past the peer's max-frame-size is rejected" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{
        .container_id = "service-bus",
        .max_frame_size = 512,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);
    try testing.expectEqual(@as(usize, 504), driver.maxOutgoingBody());

    const body = try allocator.alloc(u8, 600);
    defer allocator.free(body);
    @memset(body, 0);
    try testing.expectError(error.FrameTooLarge, driver.sendFrame(.amqp, 0, body));
}

test "a keepalive is emitted before the negotiated idle deadline" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{
        .container_id = "service-bus",
        .idle_time_out = 30_000,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);
    try testing.expectEqual(@as(i64, 15_000), driver.keepaliveIntervalMs().?);

    mem.clearWritten();
    clock.advance(14_999);
    try driver.doWork();
    try testing.expectEqual(@as(usize, 0), mem.written().len);

    clock.advance(1);
    try driver.doWork();
    // An empty frame is a bare 8-byte header, well before the 30s deadline.
    try testing.expectEqualSlices(
        u8,
        &.{ 0x00, 0x00, 0x00, 0x08, 0x02, 0x00, 0x00, 0x00 },
        mem.written(),
    );
}

test "a peer that goes quiet past the advertised idle timeout fails" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{ .container_id = "service-bus" } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);

    clock.advance(120_001);
    try testing.expectError(error.Timeout, driver.doWork());
}

test "a stalled peer surfaces a timeout instead of hanging" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    mem.starve = true;
    var clock: ManualClock = .{ .auto_advance_ms = 100 };

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try testing.expectError(error.Timeout, driver.open(5_000));
}

test "partial reads reassemble frames" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    mem.chunk = 1; // one byte per read
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{
        .container_id = "service-bus",
        .idle_time_out = 30_000,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);
    try testing.expectEqualStrings("service-bus", driver.remote_container_id.?);
}

test "pump routes frames to a registered channel" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try peer.pushHeader(&frame.amqp_header);
    try peer.push(.amqp, 0, .{ .open = .{ .container_id = "service-bus" } });
    try peer.push(.amqp, 4, .{ .end = .{} });

    const Sink = struct {
        count: usize = 0,
        last_channel: u16 = 0,

        fn handler(self: *@This()) FrameHandler {
            return .{ .ptr = self, .onFrameFn = onFrame };
        }

        fn onFrame(ptr: *anyopaque, header: FrameHeader, body: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            _ = body;
            self.count += 1;
            self.last_channel = header.channel;
        }
    };

    var sink: Sink = .{};
    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try driver.open(10_000);
    try driver.registerChannel(4, sink.handler());

    try testing.expect((try driver.pump(10_000)) == null);
    try testing.expectEqual(@as(usize, 1), sink.count);
    try testing.expectEqual(@as(u16, 4), sink.last_channel);

    driver.unregisterChannel(4);
    try testing.expect(!driver.handlers.contains(4));
}

test "an unopened driver refuses to begin a session" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: ManualClock = .{};

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    try testing.expectError(error.InvalidState, driver.beginSession(0, .{}, 10_000));
}

test "buildProperties carries the identity Azure records" {
    const allocator = testing.allocator;
    const info = defaultClientInfo("0.1.0", "azsdk-zig-eventhubs/0.1.0");
    const props = try buildProperties(allocator, info);
    defer allocator.free(props);

    try testing.expectEqual(@as(usize, 4), props.len);
    try testing.expectEqualStrings("product", props[0].key.symbol);
    try testing.expectEqualStrings("azure-sdk-for-zig", props[0].value.string);
    try testing.expectEqualStrings("version", props[1].key.symbol);
    try testing.expectEqualStrings("0.1.0", props[1].value.string);
    try testing.expectEqualStrings("platform", props[2].key.symbol);
    try testing.expectEqualStrings("user-agent", props[3].key.symbol);
    try testing.expectEqualStrings("azsdk-zig-eventhubs/0.1.0", props[3].value.string);
}

test "the handshake survives allocation failure" {
    const Case = struct {
        fn run(allocator: Allocator) !void {
            var mem = MemoryTransport.init(allocator);
            defer mem.deinit();
            var clock: ManualClock = .{};
            const peer = Peer{ .allocator = allocator, .mem = &mem };

            try peer.pushHeader(&frame.amqp_header);
            try peer.push(.amqp, 0, .{ .open = .{
                .container_id = "service-bus",
                .idle_time_out = 30_000,
            } });
            try peer.push(.amqp, 0, .{ .close = .{} });

            var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
            defer driver.deinit();
            try driver.open(10_000);
            try driver.close(null, 10_000);
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Case.run, .{});
}

test "type check the Io-backed clock" {
    std.testing.refAllDecls(IoClock);
}
