//! A scripted AMQP peer for tests.
//!
//! `MemoryTransport` gives a duplex byte pipe; this drives the far end of it,
//! writing frames a real broker would send and parsing back what the driver
//! emitted. Shared by the link, RPC, and CBS tests, which all need the same
//! open/begin/attach preamble before the behaviour under test starts.

const std = @import("std");
const Allocator = std.mem.Allocator;

const connection = @import("connection.zig");
const frame = uamqp.frame;
const link = @import("link.zig");
const perf = @import("performative.zig");
const uamqp = @import("uamqp");

const Driver = connection.Driver;
const Session = link.Session;
const MemoryTransport = @import("transport.zig").MemoryTransport;
const FrameHeader = uamqp.frame.FrameHeader;

/// Scripts peer bytes and reads back what the driver emitted.
pub const Peer = struct {
    allocator: Allocator,
    mem: *MemoryTransport,

    pub fn pushHeader(self: Peer, header: *const [8]u8) !void {
        try self.mem.pushPeerBytes(header);
    }

    pub fn push(self: Peer, channel: u16, p: perf.Performative) !void {
        var normalized = p;
        switch (normalized) {
            .attach => |*attach| switch (attach.role) {
                // An accepted sender Attach has a source, and an accepted
                // receiver Attach has a target. Most tests only care about
                // another field, so fill the mandatory terminus shorthand.
                .sender => if (attach.source == null) {
                    attach.source = .{};
                },
                .receiver => if (attach.target == null) {
                    attach.target = .{};
                },
            },
            else => {},
        }
        try self.pushExact(channel, normalized);
    }

    /// Push exactly the supplied performative without accepted-Attach
    /// normalization. Used for protocol refusal and malformed-state tests.
    pub fn pushExact(self: Peer, channel: u16, p: perf.Performative) !void {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        try perf.encode(self.allocator, p, &buf);
        try self.pushRaw(channel, buf.written());
    }

    /// Push a transfer performative followed by a payload chunk.
    pub fn pushTransfer(self: Peer, channel: u16, t: perf.Transfer, chunk: []const u8) !void {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        try perf.encodeTransfer(self.allocator, t, &buf);
        try buf.writeAll(chunk);
        try self.pushRaw(channel, buf.written());
    }

    pub fn pushRaw(self: Peer, channel: u16, body: []const u8) !void {
        const header = FrameHeader{
            .size = @intCast(frame.frame_header_size + body.len),
            .doff = 2,
            .frame_type = .amqp,
            .channel = channel,
        };
        const bytes = header.serialize();
        try self.mem.pushPeerBytes(&bytes);
        try self.mem.pushPeerBytes(body);
    }
};

/// Every frame body the driver wrote, in order.
pub const EmittedFrames = struct {
    bodies: std.ArrayList([]const u8),
    allocator: Allocator,

    pub fn parse(allocator: Allocator, written: []const u8) !EmittedFrames {
        var bodies: std.ArrayList([]const u8) = .empty;
        errdefer bodies.deinit(allocator);
        // A protocol header only leads the buffer before it is cleared.
        var offset: usize = if (std.mem.startsWith(u8, written, "AMQP")) 8 else 0;
        while (offset + frame.frame_header_size <= written.len) {
            const header = try FrameHeader.parse(written[offset..][0..8]);
            const body_len = header.size - @as(u32, header.doff) * 4;
            const start = offset + @as(usize, header.doff) * 4;
            try bodies.append(allocator, written[start..][0..body_len]);
            offset += header.size;
        }
        return .{ .bodies = bodies, .allocator = allocator };
    }

    pub fn deinit(self: *EmittedFrames) void {
        self.bodies.deinit(self.allocator);
    }

    /// Bodies whose descriptor matches `code`.
    pub fn of(self: EmittedFrames, allocator: Allocator, code: u64) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        // `parse` above guards its list the same way. Without this, a failing
        // `append` or `toOwnedSlice` strands the buffer. The error itself was
        // always reported faithfully, which is why this stayed invisible until
        // a test ran under `checkAllAllocationFailures`.
        errdefer out.deinit(allocator);
        for (self.bodies.items) |b| {
            if (perf.peekDescriptor(b) == code) try out.append(allocator, b);
        }
        return out.toOwnedSlice(allocator);
    }
};

pub const driver_options = connection.Options{
    .container_id = "test-container",
    .hostname = "ns.servicebus.windows.net",
    .sasl = .none,
    .max_frame_size = 512,
    .idle_timeout_ms = 0,
};

/// A driver opened against a scripted peer, plus a begun session.
pub const Fixture = struct {
    allocator: Allocator,
    mem: *MemoryTransport,
    clock: *connection.ManualClock,
    driver: *Driver,
    session: Session,

    pub fn init(allocator: Allocator, mem: *MemoryTransport, clock: *connection.ManualClock, driver: *Driver) !Fixture {
        try driver.open(10_000);
        const session = try Session.begin(allocator, driver, 0, .{
            .incoming_window = 100,
            .outgoing_window = 100,
        }, 10_000);
        return .{
            .allocator = allocator,
            .mem = mem,
            .clock = clock,
            .driver = driver,
            .session = session,
        };
    }

    pub fn deinit(self: *Fixture) void {
        self.session.deinit();
    }
};

/// Script the peer's side of open + begin.
pub fn scriptHandshake(peer: Peer, max_frame_size: u32) !void {
    try peer.pushHeader(&frame.amqp_header);
    try peer.push(0, .{ .open = .{
        .container_id = "service-bus",
        .max_frame_size = max_frame_size,
        .channel_max = 255,
    } });
    try peer.push(0, .{ .begin = .{
        .remote_channel = 0,
        .next_outgoing_id = 1,
        .incoming_window = 1000,
        .outgoing_window = 1000,
    } });
}

/// The message payload carried after a transfer performative in `body`.
///
/// Returns an error rather than null so that a test running under
/// `checkAllAllocationFailures` can tell an injected `error.OutOfMemory` from
/// a frame that really is malformed.
pub fn transferPayload(allocator: Allocator, body: []const u8) ![]const u8 {
    const consumed = try link.performativeLength(allocator, body);
    return body[consumed..];
}
