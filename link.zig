//! AMQP 1.0 sessions and links.
//!
//! `uamqp.protocol.link` and `uamqp.protocol.session` are stubs that never
//! encode anything, so this module drives attach, credit, transfer, and
//! settlement over the connection `Driver`.
//!
//! Everything here is synchronous and deadline-driven, like the driver: a call
//! that can wait takes a deadline in milliseconds on the driver's clock.

const std = @import("std");
const uamqp = @import("uamqp");
const perf = @import("performative.zig");
const message = @import("message.zig");
const connection = @import("connection.zig");

const Allocator = std.mem.Allocator;
const Driver = connection.Driver;
const frame = uamqp.frame;
const FrameType = uamqp.frame.FrameType;

pub const LinkError = connection.ConnectionError || error{
    /// The peer detached the link; inspect `remoteError`.
    LinkDetached,
    /// The peer rejected the delivery; inspect `rejection`.
    SendRejected,
    /// The peer released or modified the delivery rather than accepting it.
    SendNotAccepted,
    /// A message exceeded the peer's advertised `max-message-size`.
    MessageTooLarge,
    /// A transfer arrived for a handle no link owns.
    UnknownHandle,
    /// The peer sent a transfer without the credit to do so.
    CreditExceeded,
};

/// Set on a receiver so Event Hubs can name the owner in its error text.
pub const receiver_name_property = "com.microsoft:receiver-name";

/// Set on a receiver to claim exclusive ownership of a partition.
pub const epoch_property = "com.microsoft:epoch";

/// What the peer said about a delivery it would not accept.
pub const Rejection = struct {
    condition: []const u8,
    description: ?[]const u8 = null,

    pub fn deinit(self: Rejection, allocator: Allocator) void {
        allocator.free(self.condition);
        if (self.description) |d| allocator.free(d);
    }
};

// ─────────────────────── Session ───────────────────────

pub const SessionOptions = struct {
    /// Window sizes. Rust opens sessions with very large windows so the
    /// service is never the one throttling.
    incoming_window: u32 = std.math.maxInt(u32),
    outgoing_window: u32 = std.math.maxInt(u32),
    handle_max: u32 = std.math.maxInt(u32),
};

/// A session, owning the links attached to one channel.
pub const Session = struct {
    allocator: Allocator,
    driver: *Driver,
    channel: u16,
    remote_channel: u16,

    next_outgoing_id: u32 = 0,
    next_incoming_id: u32 = 0,
    incoming_window: u32,
    outgoing_window: u32,
    /// The peer's remaining capacity to receive transfers.
    remote_incoming_window: u32 = 0,

    next_handle: u32 = 0,
    senders: std.ArrayList(*Sender) = .empty,
    receivers: std.ArrayList(*Receiver) = .empty,

    /// Begin a session on `channel`.
    pub fn begin(
        allocator: Allocator,
        driver: *Driver,
        channel: u16,
        options: SessionOptions,
        deadline_ms: i64,
    ) LinkError!Session {
        const remote = try driver.beginSession(channel, .{
            .next_outgoing_id = 0,
            .incoming_window = options.incoming_window,
            .outgoing_window = options.outgoing_window,
            .handle_max = options.handle_max,
        }, deadline_ms);

        return .{
            .allocator = allocator,
            .driver = driver,
            .channel = channel,
            .remote_channel = remote,
            .incoming_window = options.incoming_window,
            .outgoing_window = options.outgoing_window,
        };
    }

    pub fn deinit(self: *Session) void {
        for (self.senders.items) |s| s.deinit();
        for (self.receivers.items) |r| r.deinit();
        self.senders.deinit(self.allocator);
        self.receivers.deinit(self.allocator);
        self.* = undefined;
    }

    /// End the session on the wire.
    pub fn end(self: *Session, deadline_ms: i64) LinkError!void {
        try self.driver.endSession(self.channel, deadline_ms);
    }

    fn allocateHandle(self: *Session) u32 {
        const handle = self.next_handle;
        self.next_handle += 1;
        return handle;
    }

    /// Read one frame and apply it to the session and its links.
    ///
    /// Returns true when the frame was consumed. A frame for another channel
    /// is ignored, which keeps a single-session connection simple.
    pub fn pump(self: *Session, deadline_ms: i64) LinkError!bool {
        const inbound = try self.driver.receiveFrame(deadline_ms);
        if (inbound.header.channel != self.remote_channel) return false;

        var decoded = try self.driver.decodeBody(inbound.body);
        defer decoded.deinit();

        const body = inbound.body;
        switch (decoded.performative) {
            .flow => |f| try self.applyFlow(f),
            .disposition => |d| try self.applyDisposition(d),
            .transfer => |t| try self.applyTransfer(t, body),
            .attach => |a| try self.applyAttach(a),
            .detach => |d| try self.applyDetach(d),
            .end => |e| {
                try self.driver.recordRemoteError(e.err);
                return error.RemoteClosed;
            },
            .close => |c| {
                try self.driver.recordRemoteError(c.err);
                return error.RemoteClosed;
            },
            else => return false,
        }
        return true;
    }

    // A handle in an inbound frame is scoped to the peer that sent it
    // (§2.6.2), so it is matched against `remote_handle` only. Matching our
    // own handle too would collide whenever a session holds both a sender and
    // a receiver, which is the shape CBS and $management use.
    fn senderFor(self: *Session, handle: u32) ?*Sender {
        for (self.senders.items) |s| {
            if (s.attached and s.remote_handle == handle) return s;
        }
        return null;
    }

    fn receiverFor(self: *Session, handle: u32) ?*Receiver {
        for (self.receivers.items) |r| {
            if (r.attached and r.remote_handle == handle) return r;
        }
        return null;
    }

    fn applyFlow(self: *Session, f: perf.Flow) LinkError!void {
        self.next_incoming_id = f.next_outgoing_id;
        self.remote_incoming_window = f.incoming_window;

        const handle = f.handle orelse return;
        if (self.senderFor(handle)) |s| {
            if (f.link_credit) |credit| {
                // The peer states credit relative to its view of our delivery
                // count, so rebase onto ours (§2.6.7).
                const their_count = f.delivery_count orelse s.delivery_count;
                const consumed = s.delivery_count -% their_count;
                s.credit = credit -| consumed;
            }
            s.drain = f.drain;
        }
        if (self.receiverFor(handle)) |r| {
            // For a receiving link the peer is the sender, so its flow reports
            // where its delivery count has reached. Rebase the credit we still
            // hold onto our own count; a drain response advances the count to
            // consume the remainder, leaving us at zero.
            const credit = f.link_credit orelse r.credit;
            if (f.drain) {
                // A drain response advances the sender's count over whatever
                // credit went unused, so its count is authoritative.
                if (f.delivery_count) |their_count| r.delivery_count = their_count;
                r.credit = credit;
            } else if (f.delivery_count) |their_count| {
                const limit = their_count +% credit;
                r.credit = limit -% r.delivery_count;
            } else {
                r.credit = credit;
            }
        }
        if (f.echo) try self.sendFlow(null);
    }

    fn applyDisposition(self: *Session, d: perf.Disposition) LinkError!void {
        // A disposition from the receiving side settles what we sent.
        if (d.role != .receiver) return;
        const last = d.last orelse d.first;
        for (self.senders.items) |s| {
            try s.applyDisposition(d.first, last, d.state);
        }
    }

    fn applyAttach(self: *Session, a: perf.Attach) LinkError!void {
        // Match by link name: the peer echoes it and picks its own handle.
        for (self.senders.items) |s| {
            if (std.mem.eql(u8, s.name, a.name)) {
                s.remote_handle = a.handle;
                s.max_message_size = a.max_message_size;
                if (a.initial_delivery_count) |c| s.delivery_count = c;
                s.attached = true;
                return;
            }
        }
        for (self.receivers.items) |r| {
            if (std.mem.eql(u8, r.name, a.name)) {
                r.remote_handle = a.handle;
                r.max_message_size = a.max_message_size;
                r.attached = true;
                return;
            }
        }
    }

    fn applyDetach(self: *Session, d: perf.Detach) LinkError!void {
        if (self.senderFor(d.handle)) |s| {
            s.attached = false;
            try s.recordDetach(d.err);
            return;
        }
        if (self.receiverFor(d.handle)) |r| {
            r.attached = false;
            try r.recordDetach(d.err);
        }
    }

    fn applyTransfer(self: *Session, t: perf.Transfer, body: []const u8) LinkError!void {
        self.next_incoming_id +%= 1;
        if (self.incoming_window > 0) self.incoming_window -= 1;

        const receiver = self.receiverFor(t.handle) orelse return error.UnknownHandle;
        // The payload is whatever follows the performative in the frame.
        const consumed = performativeLength(self.allocator, body) orelse return error.MalformedFrame;
        try receiver.acceptTransfer(t, body[consumed..]);
    }

    /// Emit a session `flow`, optionally carrying link credit.
    fn sendFlow(self: *Session, link: ?*Receiver) LinkError!void {
        var f = perf.Flow{
            .next_incoming_id = self.next_incoming_id,
            .incoming_window = self.incoming_window,
            .next_outgoing_id = self.next_outgoing_id,
            .outgoing_window = self.outgoing_window,
        };
        if (link) |r| {
            f.handle = r.handle;
            f.link_credit = r.credit;
            f.delivery_count = r.delivery_count;
            f.drain = r.drain;
        }
        try self.driver.sendPerformative(.amqp, self.channel, .{ .flow = f });
    }
};

/// Byte length of the described performative at the head of a frame body.
///
/// A transfer frame carries the message payload immediately after the
/// performative, so the split has to be found by measuring the performative.
/// Byte length of the performative at the head of `body`; the rest is payload.
pub fn performativeLength(allocator: Allocator, body: []const u8) ?usize {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const result = uamqp.decoder.decode(arena.allocator(), body) catch return null;
    return result.bytes_consumed;
}

// ─────────────────────── Sender ───────────────────────

pub const SenderOptions = struct {
    name: []const u8,
    /// The entity the messages go to, such as `eh` or `eh/Partitions/3`.
    target_address: []const u8,
    source_address: ?[]const u8 = null,
    /// Go asks for mixed settlement with receiver-settle-mode first.
    snd_settle_mode: perf.SenderSettleMode = .mixed,
    rcv_settle_mode: perf.ReceiverSettleMode = .first,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?perf.Fields = null,
};

/// Per-delivery options.
pub const SendOptions = struct {
    /// The `message-format` field of the transfer (§2.7.5). Zero is a plain
    /// AMQP message; Event Hubs identifies a batch with `0x80013700`, whose
    /// body is one data section per contained message.
    message_format: u32 = 0,
};

pub const Sender = struct {
    allocator: Allocator,
    session: *Session,
    name: []const u8,
    handle: u32,
    remote_handle: u32 = std.math.maxInt(u32),
    attached: bool = false,

    credit: u32 = 0,
    drain: bool = false,
    delivery_count: u32 = 0,
    /// Peer's `max-message-size`; null or 0 means unlimited.
    max_message_size: ?u64 = null,

    /// Outcome of the delivery currently awaiting settlement.
    pending_id: ?u32 = null,
    outcome: ?perf.DeliveryState = null,
    rejection: ?Rejection = null,
    detach_error: ?connection.RemoteError = null,

    pub fn deinit(self: *Sender) void {
        self.allocator.free(self.name);
        if (self.rejection) |r| r.deinit(self.allocator);
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// The largest message the peer will take, or null when unlimited.
    pub fn maxMessageSize(self: *const Sender) ?u64 {
        const size = self.max_message_size orelse return null;
        return if (size == 0) null else size;
    }

    fn recordDetach(self: *Sender, err: ?perf.AmqpError) LinkError!void {
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.detach_error = null;
        const e = err orelse return;
        self.detach_error = try connection.RemoteError.dupe(self.allocator, e);
    }

    fn applyDisposition(
        self: *Sender,
        first: u32,
        last: u32,
        state: ?perf.DeliveryState,
    ) LinkError!void {
        const id = self.pending_id orelse return;
        if (id < first or id > last) return;
        self.outcome = state orelse .accepted;
        if (state) |s| switch (s) {
            .rejected => |maybe_err| {
                if (self.rejection) |r| r.deinit(self.allocator);
                self.rejection = null;
                if (maybe_err) |e| self.rejection = .{
                    .condition = try self.allocator.dupe(u8, e.condition),
                    .description = if (e.description) |d|
                        try self.allocator.dupe(u8, d)
                    else
                        null,
                };
            },
            else => {},
        };
    }

    /// Send a message and wait for the peer to settle it.
    pub fn send(self: *Sender, msg: message.Message, deadline_ms: i64) LinkError!void {
        return self.sendWithOptions(msg, .{}, deadline_ms);
    }

    /// Send a message under explicit delivery options.
    pub fn sendWithOptions(
        self: *Sender,
        msg: message.Message,
        options: SendOptions,
        deadline_ms: i64,
    ) LinkError!void {
        const payload = try message.encodeAlloc(self.allocator, msg);
        defer self.allocator.free(payload);
        try self.sendBytesWithOptions(payload, options, deadline_ms);
    }

    /// Send an already encoded message payload.
    pub fn sendBytes(self: *Sender, payload: []const u8, deadline_ms: i64) LinkError!void {
        return self.sendBytesWithOptions(payload, .{}, deadline_ms);
    }

    /// Send an already encoded message payload under explicit delivery
    /// options.
    pub fn sendBytesWithOptions(
        self: *Sender,
        payload: []const u8,
        options: SendOptions,
        deadline_ms: i64,
    ) LinkError!void {
        if (self.maxMessageSize()) |limit| {
            if (payload.len > limit) return error.MessageTooLarge;
        }
        try self.awaitCredit(deadline_ms);

        const delivery_id = self.session.next_outgoing_id;
        var tag: [4]u8 = undefined;
        std.mem.writeInt(u32, &tag, delivery_id, .big);

        var offset: usize = 0;
        var first = true;
        while (first or offset < payload.len) {
            const budget = try self.chunkBudget(delivery_id, &tag, first, options.message_format);
            const take = @min(budget, payload.len - offset);
            const more = offset + take < payload.len;

            const xfer = perf.Transfer{
                .handle = self.handle,
                .delivery_id = if (first) delivery_id else null,
                .delivery_tag = if (first) &tag else null,
                .message_format = if (first) options.message_format else null,
                .settled = false,
                .more = more,
            };
            try self.sendTransfer(xfer, payload[offset..][0..take]);

            offset += take;
            first = false;
        }

        self.session.next_outgoing_id +%= 1;
        self.delivery_count +%= 1;
        self.credit -|= 1;
        if (self.session.remote_incoming_window > 0) self.session.remote_incoming_window -= 1;

        self.pending_id = delivery_id;
        self.outcome = null;
        defer self.pending_id = null;

        while (self.outcome == null) {
            if (!self.attached) return error.LinkDetached;
            _ = try self.session.pump(deadline_ms);
        }

        switch (self.outcome.?) {
            .accepted => {},
            .rejected => return error.SendRejected,
            .released, .modified => return error.SendNotAccepted,
        }
    }

    /// How many payload bytes fit alongside the transfer performative.
    fn chunkBudget(
        self: *Sender,
        delivery_id: u32,
        tag: *const [4]u8,
        first: bool,
        message_format: u32,
    ) LinkError!usize {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        // Encode with `more` set so the measurement is never an underestimate:
        // a true boolean is written where a defaulted false would be elided.
        // The real message format has to be measured too, since a zero uint
        // encodes as one byte and a batch format as five.
        try perf.encodeTransfer(self.allocator, .{
            .handle = self.handle,
            .delivery_id = if (first) delivery_id else null,
            .delivery_tag = if (first) tag else null,
            .message_format = if (first) message_format else null,
            .settled = false,
            .more = true,
        }, &buf);

        const available = self.session.driver.maxOutgoingBody();
        if (available <= buf.written().len) return error.FrameTooLarge;
        return available - buf.written().len;
    }

    fn sendTransfer(self: *Sender, xfer: perf.Transfer, chunk: []const u8) LinkError!void {
        var buf = uamqp.encoder.Buffer.initDynamic(self.allocator);
        defer buf.deinit();
        try perf.encodeTransfer(self.allocator, xfer, &buf);
        try buf.writeAll(chunk);
        try self.session.driver.sendFrame(.amqp, self.session.channel, buf.written());
    }

    fn awaitCredit(self: *Sender, deadline_ms: i64) LinkError!void {
        while (self.credit == 0) {
            if (!self.attached) return error.LinkDetached;
            _ = try self.session.pump(deadline_ms);
        }
    }
};

/// Attach a sender and wait for the peer's attach.
pub fn openSender(
    session: *Session,
    options: SenderOptions,
    deadline_ms: i64,
) LinkError!*Sender {
    const sender = try session.allocator.create(Sender);
    errdefer session.allocator.destroy(sender);

    const name = try session.allocator.dupe(u8, options.name);
    errdefer session.allocator.free(name);

    sender.* = .{
        .allocator = session.allocator,
        .session = session,
        .name = name,
        .handle = session.allocateHandle(),
    };

    try session.senders.append(session.allocator, sender);
    errdefer _ = session.senders.pop();

    try session.driver.sendPerformative(.amqp, session.channel, .{ .attach = .{
        .name = name,
        .handle = sender.handle,
        .role = .sender,
        .snd_settle_mode = options.snd_settle_mode,
        .rcv_settle_mode = options.rcv_settle_mode,
        .source = .{ .address = options.source_address },
        .target = .{ .address = options.target_address },
        .initial_delivery_count = 0,
        .desired_capabilities = options.desired_capabilities,
        .properties = options.properties,
    } });

    while (!sender.attached) {
        if (sender.detach_error != null) return error.LinkDetached;
        _ = try session.pump(deadline_ms);
    }
    return sender;
}

// ─────────────────────── Receiver ───────────────────────

pub const ReceiverOptions = struct {
    name: []const u8,
    /// The entity to read from, such as
    /// `eh/ConsumerGroups/$default/Partitions/0`.
    source_address: []const u8,
    target_address: ?[]const u8 = null,
    rcv_settle_mode: perf.ReceiverSettleMode = .first,
    /// Source filters; Event Hubs carries the starting position in a selector.
    filters: ?[]const perf.Filter = null,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?perf.Fields = null,
    /// Credit issued on attach and topped back up as deliveries arrive. Zero
    /// disables prefetch, leaving credit to `issueCredit`.
    prefetch: u32 = 300,
};

/// One received message, valid until the next `receive`.
pub const Delivery = struct {
    id: u32,
    tag: []const u8,
    payload: []const u8,
    settled: bool,
};

pub const Receiver = struct {
    allocator: Allocator,
    session: *Session,
    name: []const u8,
    handle: u32,
    remote_handle: u32 = std.math.maxInt(u32),
    attached: bool = false,

    credit: u32 = 0,
    prefetch: u32 = 0,
    drain: bool = false,
    delivery_count: u32 = 0,
    max_message_size: ?u64 = null,
    detach_error: ?connection.RemoteError = null,

    /// Bytes of the delivery currently being assembled.
    partial: std.ArrayList(u8) = .empty,
    partial_id: ?u32 = null,
    partial_tag: std.ArrayList(u8) = .empty,
    partial_settled: bool = false,
    /// Completed deliveries not yet handed to the caller.
    ready: std.ArrayList(Delivery) = .empty,
    /// Backing storage for the delivery most recently returned.
    current: std.ArrayList(u8) = .empty,
    current_tag: std.ArrayList(u8) = .empty,

    pub fn deinit(self: *Receiver) void {
        self.allocator.free(self.name);
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.partial.deinit(self.allocator);
        self.partial_tag.deinit(self.allocator);
        for (self.ready.items) |d| {
            self.allocator.free(d.payload);
            self.allocator.free(d.tag);
        }
        self.ready.deinit(self.allocator);
        self.current.deinit(self.allocator);
        self.current_tag.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn recordDetach(self: *Receiver, err: ?perf.AmqpError) LinkError!void {
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.detach_error = null;
        const e = err orelse return;
        self.detach_error = try connection.RemoteError.dupe(self.allocator, e);
    }

    fn acceptTransfer(self: *Receiver, t: perf.Transfer, chunk: []const u8) LinkError!void {
        if (t.delivery_id) |id| {
            // A new delivery starts here.
            self.partial.clearRetainingCapacity();
            self.partial_tag.clearRetainingCapacity();
            self.partial_id = id;
            self.partial_settled = t.settled orelse false;
            if (t.delivery_tag) |tag| try self.partial_tag.appendSlice(self.allocator, tag);
        }
        if (self.partial_id == null) return error.MalformedFrame;

        if (self.maxMessageSize()) |limit| {
            if (self.partial.items.len + chunk.len > limit) return error.MessageTooLarge;
        }
        try self.partial.appendSlice(self.allocator, chunk);

        if (t.more) return;

        // The delivery is complete.
        const payload = try self.allocator.dupe(u8, self.partial.items);
        errdefer self.allocator.free(payload);
        const tag = try self.allocator.dupe(u8, self.partial_tag.items);
        errdefer self.allocator.free(tag);

        try self.ready.append(self.allocator, .{
            .id = self.partial_id.?,
            .tag = tag,
            .payload = payload,
            .settled = self.partial_settled,
        });
        self.partial.clearRetainingCapacity();
        self.partial_tag.clearRetainingCapacity();
        self.partial_id = null;

        self.delivery_count +%= 1;
        self.credit -|= 1;
    }

    /// The largest message the peer will send, or null when unlimited.
    pub fn maxMessageSize(self: *const Receiver) ?u64 {
        const size = self.max_message_size orelse return null;
        return if (size == 0) null else size;
    }

    /// Grant `count` more credit to the peer.
    pub fn issueCredit(self: *Receiver, count: u32) LinkError!void {
        self.credit += count;
        try self.session.sendFlow(self);
    }

    /// Top prefetch credit back up once half of it has been consumed, so a
    /// prefetching receiver never stalls waiting for the caller.
    fn replenish(self: *Receiver) LinkError!void {
        if (self.prefetch == 0) return;
        if (self.credit > self.prefetch / 2) return;
        self.credit = self.prefetch;
        try self.session.sendFlow(self);
    }

    /// Wait for the next complete delivery.
    ///
    /// The returned slices stay valid until the next `receive`.
    pub fn receive(self: *Receiver, deadline_ms: i64) LinkError!Delivery {
        while (self.ready.items.len == 0) {
            if (!self.attached) return error.LinkDetached;
            try self.replenish();
            _ = try self.session.pump(deadline_ms);
        }

        const delivery = self.ready.orderedRemove(0);
        defer {
            self.allocator.free(delivery.payload);
            self.allocator.free(delivery.tag);
        }

        self.current.clearRetainingCapacity();
        try self.current.appendSlice(self.allocator, delivery.payload);
        self.current_tag.clearRetainingCapacity();
        try self.current_tag.appendSlice(self.allocator, delivery.tag);

        try self.replenish();
        return .{
            .id = delivery.id,
            .tag = self.current_tag.items,
            .payload = self.current.items,
            .settled = delivery.settled,
        };
    }

    /// Settle a delivery with a terminal state.
    pub fn settle(
        self: *Receiver,
        delivery: Delivery,
        state: perf.DeliveryState,
    ) LinkError!void {
        try self.session.driver.sendPerformative(.amqp, self.session.channel, .{
            .disposition = .{
                .role = .receiver,
                .first = delivery.id,
                .last = delivery.id,
                .settled = true,
                .state = state,
            },
        });
    }

    pub fn accept(self: *Receiver, delivery: Delivery) LinkError!void {
        try self.settle(delivery, .accepted);
    }

    pub fn release(self: *Receiver, delivery: Delivery) LinkError!void {
        try self.settle(delivery, .released);
    }

    /// Drain outstanding credit so the peer reports what it has left.
    pub fn drainCredit(self: *Receiver, deadline_ms: i64) LinkError!void {
        self.drain = true;
        try self.session.sendFlow(self);
        // The sender answers a drain by advancing its delivery count over the
        // outstanding credit (§2.6.7), so wait until that lands rather than
        // leaving the link in a half-drained state.
        while (self.credit > 0 and self.attached) {
            _ = self.session.pump(deadline_ms) catch |e| switch (e) {
                error.RemoteClosed, error.ConnectionClosed => break,
                else => return e,
            };
        }
        self.drain = false;
    }

    /// Detach the link, waiting for the peer's detach.
    pub fn detach(self: *Receiver, deadline_ms: i64) LinkError!void {
        try self.session.driver.sendPerformative(.amqp, self.session.channel, .{
            .detach = .{ .handle = self.handle, .closed = true },
        });
        while (self.attached) {
            _ = self.session.pump(deadline_ms) catch |e| switch (e) {
                error.RemoteClosed, error.ConnectionClosed => return,
                else => return e,
            };
        }
    }
};

/// Attach a receiver and wait for the peer's attach.
pub fn openReceiver(
    session: *Session,
    options: ReceiverOptions,
    deadline_ms: i64,
) LinkError!*Receiver {
    const receiver = try session.allocator.create(Receiver);
    errdefer session.allocator.destroy(receiver);

    const name = try session.allocator.dupe(u8, options.name);
    errdefer session.allocator.free(name);

    receiver.* = .{
        .allocator = session.allocator,
        .session = session,
        .name = name,
        .handle = session.allocateHandle(),
        .prefetch = options.prefetch,
    };

    try session.receivers.append(session.allocator, receiver);
    errdefer _ = session.receivers.pop();

    try session.driver.sendPerformative(.amqp, session.channel, .{ .attach = .{
        .name = name,
        .handle = receiver.handle,
        .role = .receiver,
        .rcv_settle_mode = options.rcv_settle_mode,
        .source = .{
            .address = options.source_address,
            .filters = options.filters,
        },
        .target = .{ .address = options.target_address },
        .initial_delivery_count = 0,
        .desired_capabilities = options.desired_capabilities,
        .properties = options.properties,
    } });

    while (!receiver.attached) {
        if (receiver.detach_error != null) return error.LinkDetached;
        _ = try session.pump(deadline_ms);
    }

    if (options.prefetch > 0) try receiver.issueCredit(options.prefetch);
    return receiver;
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const MemoryTransport = @import("transport.zig").MemoryTransport;
const harness = @import("test_peer.zig");
const Peer = harness.Peer;
const EmittedFrames = harness.EmittedFrames;
const test_options = harness.driver_options;
const Fixture = harness.Fixture;
const scriptHandshake = harness.scriptHandshake;

test "a sender attaches and reports the peer's max-message-size" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .max_message_size = 1048576,
        .initial_delivery_count = 0,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
        .desired_capabilities = &.{connection.georeplication_capability},
    }, 10_000);

    try testing.expect(sender.attached);
    try testing.expectEqual(@as(u64, 1048576), sender.maxMessageSize().?);

    // The attach carried the target address and the geo-replication capability.
    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const attaches = try frames.of(allocator, perf.descriptor.attach);
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);

    var decoded = try perf.decode(allocator, attaches[0]);
    defer decoded.deinit();
    const a = decoded.performative.attach;
    try testing.expectEqualStrings("producer", a.name);
    try testing.expectEqual(perf.Role.sender, a.role);
    try testing.expectEqualStrings("eh", a.target.?.address.?);
    try testing.expectEqual(perf.SenderSettleMode.mixed, a.snd_settle_mode);
    try testing.expectEqual(perf.ReceiverSettleMode.first, a.rcv_settle_mode);
    try testing.expectEqualStrings(
        connection.georeplication_capability,
        a.desired_capabilities.?[0],
    );
}

test "a message past max-frame-size is split and reassembles to the original" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    // 512 is the spec minimum, so the payload must span several frames.
    try scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 10,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    const big = try allocator.alloc(u8, 1500);
    defer allocator.free(big);
    for (big, 0..) |*b, i| b.* = @intCast(i % 251);

    mem.clearWritten();
    try sender.sendBytes(big, 10_000);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    // Reassemble exactly as a peer would: concatenate the payload that follows
    // each transfer performative, stopping at the frame without `more`.
    var reassembled: std.ArrayList(u8) = .empty;
    defer reassembled.deinit(allocator);

    var count: usize = 0;
    var saw_final = false;
    var first_delivery_id: ?u32 = null;
    var first_tag: ?[]const u8 = null;

    for (frames.bodies.items) |body| {
        if (perf.peekDescriptor(body) != perf.descriptor.transfer) continue;
        count += 1;
        var decoded = try perf.decode(allocator, body);
        defer decoded.deinit();
        const t = decoded.performative.transfer;

        if (count == 1) {
            first_delivery_id = t.delivery_id;
            first_tag = t.delivery_tag;
            try testing.expectEqual(@as(u32, 0), t.message_format.?);
        } else {
            // Continuation frames must not repeat the delivery id or tag.
            try testing.expectEqual(@as(?u32, null), t.delivery_id);
            try testing.expectEqual(@as(?[]const u8, null), t.delivery_tag);
        }

        const consumed = performativeLength(allocator, body).?;
        try reassembled.appendSlice(allocator, body[consumed..]);
        if (!t.more) saw_final = true;
    }

    try testing.expect(count > 1);
    try testing.expect(saw_final);
    try testing.expectEqualSlices(u8, big, reassembled.items);
    try testing.expectEqual(@as(u32, 0), first_delivery_id.?);
    // The tag is the delivery id in network order.
    try testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, first_tag.?);

    // Every frame stayed inside the peer's advertised limit.
    for (frames.bodies.items) |body| {
        try testing.expect(body.len + frame.frame_header_size <= 512);
    }
}

test "a delivery carries the requested message format" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 5,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    mem.clearWritten();
    // The Event Hubs batch format, which is what motivates the option.
    try sender.sendBytesWithOptions("payload", .{ .message_format = 0x80013700 }, 10_000);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const transfers = try frames.of(allocator, perf.descriptor.transfer);
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);

    var decoded = try perf.decode(allocator, transfers[0]);
    defer decoded.deinit();
    try testing.expectEqual(@as(u32, 0x80013700), decoded.performative.transfer.message_format.?);

    const consumed = performativeLength(allocator, transfers[0]).?;
    try testing.expectEqualStrings("payload", transfers[0][consumed..]);
}

test "a formatted delivery split across frames keeps every frame within the limit" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    // 512 is the spec minimum, so a five-byte format field is a meaningful
    // share of the budget and an unmeasured one would overflow the frame.
    try scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 10,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    const big = try allocator.alloc(u8, 1500);
    defer allocator.free(big);
    for (big, 0..) |*b, i| b.* = @intCast(i % 251);

    mem.clearWritten();
    try sender.sendBytesWithOptions(big, .{ .message_format = 0x80013700 }, 10_000);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    var reassembled: std.ArrayList(u8) = .empty;
    defer reassembled.deinit(allocator);

    var count: usize = 0;
    for (frames.bodies.items) |body| {
        if (perf.peekDescriptor(body) != perf.descriptor.transfer) continue;
        count += 1;
        var decoded = try perf.decode(allocator, body);
        defer decoded.deinit();

        // Only the first frame names the format; the rest continue it.
        if (count == 1) {
            try testing.expectEqual(@as(u32, 0x80013700), decoded.performative.transfer.message_format.?);
        } else {
            try testing.expectEqual(@as(?u32, null), decoded.performative.transfer.message_format);
        }

        const consumed = performativeLength(allocator, body).?;
        try reassembled.appendSlice(allocator, body[consumed..]);
        try testing.expect(body.len + frame.frame_header_size <= 512);
    }

    try testing.expect(count > 1);
    try testing.expectEqualSlices(u8, big, reassembled.items);
}

test "a rejected disposition surfaces the AMQP condition" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 5,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .{ .rejected = .{
            .condition = "amqp:link:message-size-exceeded",
            .description = "The received message is larger than the maximum allowed size.",
        } },
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    try testing.expectError(error.SendRejected, sender.sendBytes("payload", 10_000));
    try testing.expectEqualStrings(
        "amqp:link:message-size-exceeded",
        sender.rejection.?.condition,
    );
    try testing.expectEqualStrings(
        "The received message is larger than the maximum allowed size.",
        sender.rejection.?.description.?,
    );
}

test "a message past the peer's max-message-size is refused before sending" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .max_message_size = 16,
        .initial_delivery_count = 0,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    mem.clearWritten();
    try testing.expectError(
        error.MessageTooLarge,
        sender.sendBytes("this payload is well past sixteen bytes", 10_000),
    );
    // Nothing went on the wire.
    try testing.expectEqual(@as(usize, 0), mem.written().len);
}

test "a receiver applies the epoch and receiver-name link properties" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const props = [_]uamqp.MapEntry{
        .{ .key = .{ .symbol = receiver_name_property }, .value = .{ .string = "instance-7" } },
        .{ .key = .{ .symbol = epoch_property }, .value = .{ .long = 5 } },
    };
    const filters = [_]perf.Filter{
        perf.Filter.selector("amqp.annotation.x-opt-offset > '100'"),
    };

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh/ConsumerGroups/$default/Partitions/0",
        .target_address = "instance-7",
        .filters = &filters,
        .properties = &props,
        .desired_capabilities = &.{connection.georeplication_capability},
        .prefetch = 0,
    }, 10_000);
    try testing.expect(receiver.attached);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const attaches = try frames.of(allocator, perf.descriptor.attach);
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);

    var decoded = try perf.decode(allocator, attaches[0]);
    defer decoded.deinit();
    const a = decoded.performative.attach;
    try testing.expectEqual(perf.Role.receiver, a.role);
    try testing.expectEqualStrings(
        "eh/ConsumerGroups/$default/Partitions/0",
        a.source.?.address.?,
    );
    try testing.expectEqualStrings("instance-7", a.target.?.address.?);

    try testing.expectEqualStrings(receiver_name_property, a.properties.?[0].key.symbol);
    try testing.expectEqualStrings("instance-7", a.properties.?[0].value.string);
    try testing.expectEqualStrings(epoch_property, a.properties.?[1].key.symbol);
    try testing.expectEqual(@as(i64, 5), a.properties.?[1].value.long);

    const f = a.source.?.filters.?[0];
    try testing.expectEqualStrings(perf.selector_filter_name, f.name);
    try testing.expectEqual(perf.selector_filter_code, f.code.?);
    try testing.expectEqualStrings("amqp.annotation.x-opt-offset > '100'", f.value.string);
}

test "a receiver reassembles a multi-frame delivery" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.pushTransfer(0, .{
        .handle = 0,
        .delivery_id = 4,
        .delivery_tag = "\x00\x00\x00\x04",
        .message_format = 0,
        .settled = false,
        .more = true,
    }, "part-one|");
    try peer.pushTransfer(0, .{ .handle = 0, .more = true }, "part-two|");
    try peer.pushTransfer(0, .{ .handle = 0, .more = false }, "part-three");

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh/ConsumerGroups/$default/Partitions/0",
        .prefetch = 0,
    }, 10_000);

    const delivery = try receiver.receive(10_000);
    try testing.expectEqual(@as(u32, 4), delivery.id);
    try testing.expectEqualSlices(u8, "\x00\x00\x00\x04", delivery.tag);
    try testing.expectEqualStrings("part-one|part-two|part-three", delivery.payload);

    mem.clearWritten();
    try receiver.accept(delivery);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    try testing.expectEqual(@as(usize, 1), frames.bodies.items.len);
    var decoded = try perf.decode(allocator, frames.bodies.items[0]);
    defer decoded.deinit();
    const d = decoded.performative.disposition;
    try testing.expectEqual(perf.Role.receiver, d.role);
    try testing.expectEqual(@as(u32, 4), d.first);
    try testing.expect(d.settled);
    try testing.expectEqual(perf.DeliveryState.accepted, d.state.?);
}

test "a prefetching receiver replenishes credit rather than stalling" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    const prefetch: u32 = 4;
    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    // More deliveries than the prefetch window, so credit must be topped up.
    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        try peer.pushTransfer(0, .{
            .handle = 0,
            .delivery_id = i,
            .delivery_tag = "t",
            .message_format = 0,
            .settled = true,
            .more = false,
        }, "event");
    }

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh/ConsumerGroups/$default/Partitions/0",
        .prefetch = prefetch,
    }, 10_000);

    mem.clearWritten();
    i = 0;
    while (i < 12) : (i += 1) {
        const delivery = try receiver.receive(10_000);
        try testing.expectEqualStrings("event", delivery.payload);
        try testing.expectEqual(i, delivery.id);
    }

    // Credit was re-issued as flows; without them the peer would have stalled.
    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const flows = try frames.of(allocator, perf.descriptor.flow);
    defer allocator.free(flows);
    try testing.expect(flows.len > 1);

    for (flows) |body| {
        var decoded = try perf.decode(allocator, body);
        defer decoded.deinit();
        const f = decoded.performative.flow;
        try testing.expectEqual(receiver.handle, f.handle.?);
        try testing.expectEqual(prefetch, f.link_credit.?);
    }
    try testing.expect(receiver.credit > 0);
}

test "the attach flow issues the requested prefetch credit" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh",
        .prefetch = 250,
    }, 10_000);
    try testing.expectEqual(@as(u32, 250), receiver.credit);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const flows = try frames.of(allocator, perf.descriptor.flow);
    defer allocator.free(flows);
    try testing.expectEqual(@as(usize, 1), flows.len);

    var decoded = try perf.decode(allocator, flows[0]);
    defer decoded.deinit();
    try testing.expectEqual(@as(u32, 250), decoded.performative.flow.link_credit.?);
}

test "a detach surfaces the condition that stole the link" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{
            .condition = "amqp:link:stolen",
            .description = "New receiver with higher epoch of '1' is created.",
        },
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh",
        .prefetch = 0,
    }, 10_000);

    try testing.expectError(error.LinkDetached, receiver.receive(10_000));
    try testing.expect(!receiver.attached);
    try testing.expectEqualStrings("amqp:link:stolen", receiver.detach_error.?.condition);
}

test "credit from the peer is rebased onto our delivery count" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "producer",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    // The peer grants 10 from a delivery count of 0. By the time we apply it we
    // have already sent 3, so only 7 remain usable.
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 10,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    sender.delivery_count = 3;
    _ = try fixture.session.pump(10_000);
    try testing.expectEqual(@as(u32, 7), sender.credit);
}

test "a message round-trips from the sender's encoding to the receiver's payload" {
    const allocator = testing.allocator;
    const app_props = [_]uamqp.MapEntry{
        .{ .key = .{ .string = "operation" }, .value = .{ .string = "put-token" } },
    };
    const msg = message.Message{
        .properties = .{ .to = "$cbs", .message_id = .{ .string = "req-1" } },
        .application_properties = &app_props,
        .body = .{ .value = .{ .string = "token" } },
    };

    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "cbs-sender",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 1,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "cbs-sender",
        .target_address = "$cbs",
    }, 10_000);

    mem.clearWritten();
    try sender.send(msg, 10_000);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    try testing.expectEqual(@as(usize, 1), frames.bodies.items.len);

    const body = frames.bodies.items[0];
    const consumed = performativeLength(allocator, body).?;
    var decoded = try message.decode(allocator, body[consumed..]);
    defer decoded.deinit();

    try testing.expectEqualStrings("$cbs", decoded.message.properties.to.?);
    try testing.expectEqualStrings("req-1", decoded.message.properties.message_id.?.string);
    try testing.expectEqualStrings("put-token", decoded.message.application_properties.?[0].value.string);
    try testing.expectEqualStrings("token", decoded.message.body.value.string);
}

test "a session routes transfers by the peer's handle, not our own" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    // Two receivers on one session, as a client holding both a CBS link and an
    // events link has. The peer numbers its handles independently of ours, so
    // here they cross over: our handle 0 is the peer's 7, and our 1 is its 0.
    try peer.push(0, .{ .attach = .{
        .name = "cbs-receiver",
        .handle = 7,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "events-receiver",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    // Addressed to the peer's handle 0, which is the events link. A lookup that
    // also matched our own handles would hand this to the CBS receiver, whose
    // local handle happens to be 0.
    try peer.pushTransfer(0, .{
        .handle = 0,
        .delivery_id = 0,
        .delivery_tag = "e",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, "event-body");

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const cbs = try openReceiver(&fixture.session, .{
        .name = "cbs-receiver",
        .source_address = "$cbs",
        .prefetch = 0,
    }, 10_000);
    const events = try openReceiver(&fixture.session, .{
        .name = "events-receiver",
        .source_address = "partition/0",
        .prefetch = 0,
    }, 10_000);

    try testing.expectEqual(@as(u32, 0), cbs.handle);
    try testing.expectEqual(@as(u32, 7), cbs.remote_handle);
    try testing.expectEqual(@as(u32, 1), events.handle);
    try testing.expectEqual(@as(u32, 0), events.remote_handle);

    const delivery = try events.receive(10_000);
    try testing.expectEqualStrings("event-body", delivery.payload);
    try testing.expectEqual(@as(usize, 0), cbs.ready.items.len);
    try testing.expectEqual(@as(usize, 0), cbs.partial.items.len);
}

test "draining a receiver waits for the sender to consume the outstanding credit" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "drainable",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    // One message, then a drain response advancing the delivery count over the
    // four credits left unused.
    try peer.pushTransfer(0, .{
        .handle = 0,
        .delivery_id = 0,
        .delivery_tag = "d",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, "last");
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 5,
        .link_credit = 0,
        .drain = true,
    } });

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "drainable",
        .source_address = "partition/0",
        .prefetch = 5,
    }, 10_000);
    try testing.expectEqual(@as(u32, 5), receiver.credit);

    const delivery = try receiver.receive(10_000);
    try testing.expectEqualStrings("last", delivery.payload);

    try receiver.drainCredit(10_000);
    try testing.expectEqual(@as(u32, 0), receiver.credit);
    try testing.expect(!receiver.drain);
}
