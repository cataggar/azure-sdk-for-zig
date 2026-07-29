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
/// Drop `link` from `list` and free it. A link that is not in the list was
/// already dropped, so freeing it here would be a double free.
fn removeLink(comptime T: type, list: *std.ArrayList(*T), link: *T) void {
    for (list.items, 0..) |item, i| {
        if (item != link) continue;
        _ = list.orderedRemove(i);
        link.deinit();
        return;
    }
}

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

    /// Detach one sender and drop it from the session.
    ///
    /// Detaching without dropping would leave the session pumping frames into
    /// a link nobody can reach, and `deinit` would free it a second time. The
    /// detach is best effort: a link being recovered has usually already been
    /// detached by the peer, and failing here would strand the link instead.
    pub fn closeSender(self: *Session, sender: *Sender, deadline_ms: i64) void {
        if (sender.attached) sender.detach(deadline_ms) catch {};
        removeLink(Sender, &self.senders, sender);
    }

    /// Detach one receiver and drop it from the session.
    pub fn closeReceiver(self: *Session, receiver: *Receiver, deadline_ms: i64) void {
        if (receiver.attached) receiver.detach(deadline_ms) catch {};
        removeLink(Receiver, &self.receivers, receiver);
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

    /// Scratch for one outgoing frame body, reused for every frame of every
    /// send. Sized to the peer's `max-frame-size`, which `chunkBudget` has
    /// already guaranteed is enough for a transfer performative plus its
    /// chunk. Growing this per frame meant a doubling series of reallocs and
    /// copies, up to the frame size, on every frame of every batch.
    frame_buf: []u8 = &.{},

    pub fn deinit(self: *Sender) void {
        self.allocator.free(self.name);
        if (self.frame_buf.len > 0) self.allocator.free(self.frame_buf);
        if (self.rejection) |r| r.deinit(self.allocator);
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Detach the link, waiting for the peer's detach.
    ///
    /// A peer that has already gone reads as closed rather than as a failure:
    /// the link is detached either way, and reporting an error would make a
    /// caller tearing down think it had to retry.
    pub fn detach(self: *Sender, deadline_ms: i64) LinkError!void {
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
        // At most two budgets exist for a delivery: the opening frame carries
        // the delivery id, tag and message format, and every continuation
        // carries none of them. Measuring per chunk re-encoded the same
        // performative once per frame to learn the same two numbers.
        const first_budget = try self.chunkBudget(delivery_id, &tag, true, options.message_format);
        const cont_budget: usize = if (payload.len > first_budget)
            try self.chunkBudget(delivery_id, &tag, false, options.message_format)
        else
            first_budget;

        while (first or offset < payload.len) {
            const budget = if (first) first_budget else cont_budget;
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
            // The frame is the performative plus the chunk, and `chunkBudget`
            // measured that performative as `maxOutgoingBody() - budget`.
            const frame_cap = self.session.driver.maxOutgoingBody() - budget + take;
            try self.sendTransfer(xfer, payload[offset..][0..take], frame_cap);

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

    fn sendTransfer(
        self: *Sender,
        xfer: perf.Transfer,
        chunk: []const u8,
        frame_cap: usize,
    ) LinkError!void {
        var buf = uamqp.encoder.Buffer.initFixed(try self.frameBuffer(frame_cap));
        try perf.encodeTransfer(self.allocator, xfer, &buf);
        // A fixed buffer never allocates, so the only way `writeAll` fails is
        // running out of room — which `chunkBudget` is supposed to have made
        // impossible. Report that as the frame problem it is rather than as a
        // memory problem it is not.
        buf.writeAll(chunk) catch return error.FrameTooLarge;
        try self.session.driver.sendFrame(.amqp, self.session.channel, buf.written());
    }

    /// The reusable frame scratch, grown to `need` if it is not already there.
    ///
    /// `need` is the size of the frame actually being written, not the peer's
    /// advertised `max-frame-size`. That value is unbounded on the wire — AMQP
    /// §2.7.1 makes an absent `max-frame-size` mean `2^32-1`, which this
    /// codec implements — so sizing to it would let a peer dictate a 4 GiB
    /// allocation for a five-byte message. Sizing to the frame instead means
    /// a sender holds only as much as its largest real frame, and every
    /// later frame of the same size reuses it.
    fn frameBuffer(self: *Sender, need: usize) LinkError![]u8 {
        if (self.frame_buf.len >= need) return self.frame_buf;
        self.frame_buf = if (self.frame_buf.len == 0)
            try self.allocator.alloc(u8, need)
        else
            try self.allocator.realloc(self.frame_buf, need);
        return self.frame_buf;
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
    ///
    /// Drained with a head cursor rather than by removing the front element:
    /// a prefetching receiver holds hundreds of deliveries, and shifting them
    /// all down on every `receive` makes draining the queue quadratic.
    ready: std.ArrayList(Delivery) = .empty,
    ready_head: usize = 0,
    /// The delivery most recently returned. Owned here, not copied: `receive`
    /// takes the buffers straight out of `ready` and frees them when the next
    /// `receive` ends their "valid until" window.
    current: ?[]const u8 = null,
    current_tag: ?[]const u8 = null,

    pub fn deinit(self: *Receiver) void {
        self.allocator.free(self.name);
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.partial.deinit(self.allocator);
        self.partial_tag.deinit(self.allocator);
        // Everything before `ready_head` was already handed out, so its
        // buffers belong to `current` and are freed by `releaseCurrent`.
        for (self.ready.items[self.ready_head..]) |d| {
            self.allocator.free(d.payload);
            self.allocator.free(d.tag);
        }
        self.ready.deinit(self.allocator);
        self.releaseCurrent();
        self.allocator.destroy(self);
    }

    fn recordDetach(self: *Receiver, err: ?perf.AmqpError) LinkError!void {
        if (self.detach_error) |e| e.deinit(self.allocator);
        self.detach_error = null;
        const e = err orelse return;
        self.detach_error = try connection.RemoteError.dupe(self.allocator, e);
    }

    /// Queue a completed delivery. The buffers stay the caller's until this
    /// succeeds, so a failed append does not free them twice.
    fn enqueue(self: *Receiver, id: u32, tag: []u8, payload: []u8, settled: bool) LinkError!void {
        try self.ready.append(self.allocator, .{
            .id = id,
            .tag = tag,
            .payload = payload,
            .settled = settled,
        });
        self.delivery_count +%= 1;
        self.credit -|= 1;
    }

    /// Drop the entries the cursor has already passed.
    ///
    /// The cursor alone would let `ready` grow without bound: it only shrinks
    /// when the caller happens to consume the exact last queued delivery, and
    /// a receiver that stays even one delivery behind — an app pumping the
    /// session itself, or two links on one session consumed in turn — never
    /// hits that. Compacting once the consumed run reaches half the array
    /// bounds it by the live backlog while still moving each entry at most
    /// once per two `receive` calls, so draining stays amortised O(1).
    fn compactReady(self: *Receiver) void {
        if (self.ready_head == self.ready.items.len) {
            self.ready.clearRetainingCapacity();
            self.ready_head = 0;
            return;
        }
        if (self.ready_head * 2 < self.ready.items.len) return;

        const live = self.ready.items.len - self.ready_head;
        std.mem.copyForwards(
            Delivery,
            self.ready.items[0..live],
            self.ready.items[self.ready_head..],
        );
        self.ready.shrinkRetainingCapacity(live);
        self.ready_head = 0;
    }

    /// Free the delivery handed out by the previous `receive`, whose "valid
    /// until the next `receive`" window has just closed.
    fn releaseCurrent(self: *Receiver) void {
        if (self.current) |payload| self.allocator.free(payload);
        if (self.current_tag) |tag| self.allocator.free(tag);
        self.current = null;
        self.current_tag = null;
    }

    fn acceptTransfer(self: *Receiver, t: perf.Transfer, chunk: []const u8) LinkError!void {
        // A delivery that arrives whole in a single transfer — which is every
        // delivery below the peer's frame size, so nearly all of them — does
        // not need the reassembly buffer. Staging it there copies the body in
        // and then copies it straight back out.
        if (t.delivery_id) |id| {
            if (!t.more and self.partial_id == null) {
                if (self.maxMessageSize()) |limit| {
                    if (chunk.len > limit) return error.MessageTooLarge;
                }
                const payload = try self.allocator.dupe(u8, chunk);
                errdefer self.allocator.free(payload);
                const tag = try self.allocator.dupe(u8, t.delivery_tag orelse "");
                errdefer self.allocator.free(tag);
                return self.enqueue(id, tag, payload, t.settled orelse false);
            }
        }

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

        const id = self.partial_id.?;
        const settled = self.partial_settled;
        self.partial.clearRetainingCapacity();
        self.partial_tag.clearRetainingCapacity();
        self.partial_id = null;

        try self.enqueue(id, tag, payload, settled);
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
        while (self.ready.items.len == self.ready_head) {
            if (!self.attached) return error.LinkDetached;
            try self.replenish();
            _ = try self.session.pump(deadline_ms);
        }

        const delivery = self.ready.items[self.ready_head];
        self.ready_head += 1;
        self.compactReady();

        // Only now that a replacement is in hand, so a `receive` that fails or
        // times out leaves the previously returned delivery readable, as it
        // was when this held a reused scratch buffer.
        self.releaseCurrent();

        // The delivery already owns correctly sized buffers, so hand those to
        // the caller instead of copying them into scratch storage.
        self.current = delivery.payload;
        self.current_tag = delivery.tag;

        try self.replenish();
        return delivery;
    }

    /// Settle a delivery with a terminal state.
    pub fn settle(
        self: *Receiver,
        delivery: Delivery,
        state: perf.DeliveryState,
    ) LinkError!void {
        return self.settleRange(delivery.id, delivery.id, state);
    }

    /// Settle a contiguous run of deliveries with one disposition.
    ///
    /// A disposition names a `first`..`last` range (Â§2.7.6), so a consumer
    /// working through a prefetch window does not need a frame per message.
    /// At the default 300-deep prefetch that is the difference between 300
    /// frames of bookkeeping and one.
    ///
    /// The range must be contiguous and must not span a delivery the caller
    /// does not mean to settle: `SettleBatch` builds runs safely from ids that
    /// may have gaps, which they do whenever another link on the same session
    /// took a delivery id in between.
    pub fn settleRange(
        self: *Receiver,
        first: u32,
        last: u32,
        state: perf.DeliveryState,
    ) LinkError!void {
        try self.session.driver.sendPerformative(.amqp, self.session.channel, .{
            .disposition = .{
                .role = .receiver,
                .first = first,
                .last = last,
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

/// Coalesces deliveries into as few dispositions as their ids allow.
///
/// Delivery ids are allocated by the session, not by the link, so a receiver
/// sharing a session with anything else — a CBS link, `$management`, a second
/// partition — sees gaps in the ids it is handed. Settling a range that spans
/// a gap would settle a delivery belonging to another link, so a run is
/// closed and emitted whenever the next id is not the one after it.
///
/// Nothing is on the wire until `flush`, so a caller that abandons a batch
/// must either flush it or accept that the deliveries stay unsettled — which
/// is the safe direction, since the peer redelivers them.
pub const SettleBatch = struct {
    receiver: *Receiver,
    state: perf.DeliveryState = .accepted,
    first: ?u32 = null,
    last: u32 = 0,

    pub fn init(receiver: *Receiver, state: perf.DeliveryState) SettleBatch {
        return .{ .receiver = receiver, .state = state };
    }

    /// Extend the open run, or close it and start a new one.
    pub fn add(self: *SettleBatch, delivery: Delivery) LinkError!void {
        return self.addId(delivery.id);
    }

    pub fn addId(self: *SettleBatch, id: u32) LinkError!void {
        if (self.first) |_| {
            // A delivery id is a serial number (Â§2.8.3), so 0 really does
            // follow 0xffffffff — but a range written that way reads as
            // `first > last` to anything comparing the two numerically, which
            // includes this library's own `Sender.applyDisposition`. Rather
            // than emit a form only a strict serial-number implementation can
            // read, close the run at the wrap and start a new one.
            if (self.last != std.math.maxInt(u32) and id == self.last + 1) {
                self.last = id;
                return;
            }
            try self.flush();
        }
        self.first = id;
        self.last = id;
    }

    /// Put the open run on the wire, if there is one.
    pub fn flush(self: *SettleBatch) LinkError!void {
        const first = self.first orelse return;
        self.first = null;
        try self.receiver.settleRange(first, self.last, self.state);
    }

    /// Whether anything is waiting to be settled.
    pub fn pending(self: SettleBatch) bool {
        return self.first != null;
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

test "a multi-frame send does not allocate per frame" {
    // The transport and the scripted peer stay on the plain test allocator so
    // that the count reflects the link layer only, not the growth of the
    // in-memory wire.
    var counting = CountingAllocator{ .child = testing.allocator };
    const allocator = counting.allocator();

    var mem = MemoryTransport.init(testing.allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = testing.allocator, .mem = &mem };

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
    var settled: u32 = 0;
    while (settled < 2) : (settled += 1) {
        try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = settled,
            .last = settled,
            .settled = true,
            .state = .accepted,
        } });
    }

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "producer",
        .target_address = "eh",
    }, 10_000);

    // Twenty-odd frames at the spec-minimum frame size, so a per-frame cost
    // is impossible to miss.
    const big = try testing.allocator.alloc(u8, 8000);
    defer testing.allocator.free(big);
    @memset(big, 'x');

    // The first send pays for the frame scratch once.
    try sender.sendBytes(big, 10_000);
    try testing.expect(sender.frame_buf.len > 0);

    const before = counting.allocs;
    try sender.sendBytes(big, 10_000);
    const spent = counting.allocs - before;

    var frames = try EmittedFrames.parse(testing.allocator, mem.written());
    defer frames.deinit();
    var transfers: usize = 0;
    for (frames.bodies.items) |body| {
        if (perf.peekDescriptor(body) == perf.descriptor.transfer) transfers += 1;
    }
    // Both sends, so the second one alone sent half of these.
    const per_send = transfers / 2;
    try testing.expect(per_send > 15);

    // One allocation per frame is left: the temporary `encodeDescribedList`
    // builds for the performative's list body. The constant covers the two
    // budget measurements and decoding the peer's disposition.
    //
    // Before the frame scratch and the hoisted budget this same send cost 88
    // allocations rather than 24 — and at the spec-minimum 512-byte frame the
    // old buffer only doubled three times. A real 64 KiB frame doubled ten.
    try testing.expect(spent <= per_send + 8);
}

test "the frame scratch is sized by the message, not by the peer's frame size" {
    var counting = CountingAllocator{ .child = testing.allocator };
    const allocator = counting.allocator();

    var mem = MemoryTransport.init(testing.allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = testing.allocator, .mem = &mem };

    // AMQP §2.7.1: an absent `max-frame-size` means 2^32-1, and this codec
    // decodes it that way. A peer is entitled to say so, and plenty do rather
    // than nominate a number.
    try scriptHandshake(peer, std.math.maxInt(u32));
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

    try testing.expectEqual(
        @as(usize, std.math.maxInt(u32) - frame.frame_header_size),
        driver.maxOutgoingBody(),
    );

    try sender.sendBytes("five!", 10_000);

    // Reserving what the peer advertised would have asked for four gibibytes
    // to put five bytes on the wire — either an outright `OutOfMemory` for a
    // well-formed small message, or four gibibytes of address space held for
    // the life of every link.
    try testing.expect(sender.frame_buf.len < 256);
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

/// Counts allocations so a test can assert that a code path performs none.
/// Deliberately local to the tests: `azure_sdk_amqp` depends on nothing but
/// `uamqp`, and a benchmark harness is not worth changing that.
const CountingAllocator = struct {
    child: Allocator,
    allocs: usize = 0,

    fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn alloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawAlloc(len, a, ra);
        if (result != null) self.allocs += 1;
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, a: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(buf, a, new_len, ra);
    }

    fn remap(ctx: *anyopaque, buf: []u8, a: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child.rawRemap(buf, a, new_len, ra);
        // Only a move is a new allocation; growing in place is not.
        if (result) |p| {
            if (p != buf.ptr) self.allocs += 1;
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, a: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, a, ra);
    }
};

test "a single-frame delivery bypasses the reassembly buffer" {
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
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
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
        .prefetch = 16,
    }, 10_000);

    i = 0;
    while (i < 5) : (i += 1) {
        const delivery = try receiver.receive(10_000);
        try testing.expectEqualStrings("event", delivery.payload);
    }

    // Staging a whole-in-one-frame delivery in `partial` would copy the body
    // in and straight back out. Never having allocated the buffer is the
    // observable proof that neither copy happened.
    try testing.expectEqual(@as(usize, 0), receiver.partial.capacity);
    try testing.expectEqual(@as(usize, 0), receiver.partial_tag.capacity);
}

test "receive hands out the queued buffer rather than copying it" {
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
    var i: u32 = 0;
    while (i < 3) : (i += 1) {
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
        .prefetch = 16,
    }, 10_000);

    // Queue every delivery before taking any, which is the state a
    // prefetching receiver is normally in.
    while (receiver.ready.items.len < 3) _ = try fixture.session.pump(10_000);

    const first = try receiver.receive(10_000);

    // Draining advances a cursor instead of shifting the queue down — which
    // is what made draining a 300-deep prefetch quadratic.
    try testing.expectEqual(@as(usize, 3), receiver.ready.items.len);
    try testing.expectEqual(@as(usize, 1), receiver.ready_head);

    // Same allocation, not a copy of it.
    try testing.expectEqual(receiver.ready.items[0].payload.ptr, first.payload.ptr);
    try testing.expectEqual(receiver.ready.items[0].tag.ptr, first.tag.ptr);

    // The second receive puts the consumed run at half the array, so the live
    // tail is shifted down and the cursor resets.
    _ = try receiver.receive(10_000);
    try testing.expectEqual(@as(usize, 0), receiver.ready_head);
    try testing.expectEqual(@as(usize, 1), receiver.ready.items.len);

    const last = try receiver.receive(10_000);
    try testing.expectEqual(@as(u32, 2), last.id);
    // Fully drained, so the queue resets rather than growing without bound.
    try testing.expectEqual(@as(usize, 0), receiver.ready.items.len);
    try testing.expectEqual(@as(usize, 0), receiver.ready_head);
}

test "a partially drained queue stays bounded by the backlog" {
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

    const count = 400;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
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
        .prefetch = 512,
    }, 10_000);

    while (receiver.ready.items.len < count) _ = try fixture.session.pump(10_000);

    // Consume all but one. A cursor that only reset on an exactly empty queue
    // would still be holding all 400 entries, 399 of them dead, and would go
    // on accruing them for the life of the link.
    i = 0;
    while (i < count - 1) : (i += 1) {
        const delivery = try receiver.receive(10_000);
        try testing.expectEqual(i, delivery.id);
    }

    const backlog = receiver.ready.items.len - receiver.ready_head;
    try testing.expectEqual(@as(usize, 1), backlog);
    try testing.expect(receiver.ready.items.len <= 2 * backlog);

    const last = try receiver.receive(10_000);
    try testing.expectEqual(@as(u32, count - 1), last.id);
}

test "draining an already queued backlog allocates nothing" {
    var counting = CountingAllocator{ .child = testing.allocator };
    const allocator = counting.allocator();

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

    // Bodies grow, so a receiver that copied each delivery into one reused
    // scratch buffer would have to keep reallocating it.
    const count = 64;
    var body: [8 + count * 4]u8 = undefined;
    @memset(&body, 'x');

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        try peer.pushTransfer(0, .{
            .handle = 0,
            .delivery_id = i,
            .delivery_tag = "t",
            .message_format = 0,
            .settled = true,
            .more = false,
        }, body[0 .. 8 + i * 4]);
    }

    var driver = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh/ConsumerGroups/$default/Partitions/0",
        .prefetch = 128,
    }, 10_000);

    // Queue the whole backlog first, so the receives below are pure drain.
    while (receiver.ready.items.len < count) _ = try fixture.session.pump(10_000);

    const first = try receiver.receive(10_000);
    try testing.expectEqual(@as(usize, 8), first.payload.len);

    counting.allocs = 0;
    i = 1;
    while (i < count) : (i += 1) {
        const delivery = try receiver.receive(10_000);
        try testing.expectEqual(i, delivery.id);
        try testing.expectEqual(@as(usize, 8 + i * 4), delivery.payload.len);
    }
    try testing.expectEqual(@as(usize, 0), counting.allocs);
}

/// Every disposition on the wire, as `first..last` pairs.
fn settledRanges(allocator: Allocator, written: []const u8) ![]const [2]u32 {
    var frames = try EmittedFrames.parse(allocator, written);
    defer frames.deinit();

    var ranges: std.ArrayList([2]u32) = .empty;
    errdefer ranges.deinit(allocator);
    for (frames.bodies.items) |body| {
        if (perf.peekDescriptor(body) != perf.descriptor.disposition) continue;
        var decoded = try perf.decode(allocator, body);
        defer decoded.deinit();
        const d = decoded.performative.disposition;
        try testing.expectEqual(perf.Role.receiver, d.role);
        try testing.expect(d.settled);
        try testing.expectEqual(perf.DeliveryState.accepted, d.state.?);
        try ranges.append(allocator, .{ d.first, d.last orelse d.first });
    }
    return ranges.toOwnedSlice(allocator);
}

/// Attach a receiver and feed it `ids` as settled single-frame deliveries.
fn scriptedReceiver(
    allocator: Allocator,
    mem: *MemoryTransport,
    clock: *connection.ManualClock,
    driver: *Driver,
    fixture: *Fixture,
    ids: []const u32,
) !*Receiver {
    const peer = Peer{ .allocator = allocator, .mem = mem };
    try scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "consumer",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    for (ids) |id| {
        try peer.pushTransfer(0, .{
            .handle = 0,
            .delivery_id = id,
            .delivery_tag = "t",
            .message_format = 0,
            .settled = false,
            .more = false,
        }, "event");
    }

    driver.* = try Driver.init(allocator, mem.transport(), clock.clock(), test_options);
    fixture.* = try Fixture.init(allocator, mem, clock, driver);
    return openReceiver(&fixture.session, .{
        .name = "consumer",
        .source_address = "eh/ConsumerGroups/$default/Partitions/0",
        .prefetch = 32,
    }, 10_000);
}

test "a batch settles a contiguous run in one disposition" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};

    const ids = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var driver: Driver = undefined;
    var fixture: Fixture = undefined;
    const receiver = try scriptedReceiver(allocator, &mem, &clock, &driver, &fixture, &ids);
    defer driver.deinit();
    defer fixture.deinit();

    mem.clearWritten();
    var batch = SettleBatch.init(receiver, .accepted);
    for (ids) |_| try batch.add(try receiver.receive(10_000));
    try testing.expect(batch.pending());
    try batch.flush();
    try testing.expect(!batch.pending());

    const ranges = try settledRanges(allocator, mem.written());
    defer allocator.free(ranges);

    // Settling one at a time put eight frames on the wire to say the same
    // thing. At the default 300-deep prefetch that is 300.
    try testing.expectEqual(@as(usize, 1), ranges.len);
    try testing.expectEqual([2]u32{ 0, 7 }, ranges[0]);
}

test "a batch does not settle across a gap in delivery ids" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};

    // Delivery ids are the session's, not the link's, so anything else on the
    // session — a CBS link, `$management`, another partition — takes ids out
    // of this receiver's run. Settling 3..9 as one range would settle two
    // deliveries this receiver was never handed.
    const ids = [_]u32{ 3, 4, 5, 8, 9, 11 };
    var driver: Driver = undefined;
    var fixture: Fixture = undefined;
    const receiver = try scriptedReceiver(allocator, &mem, &clock, &driver, &fixture, &ids);
    defer driver.deinit();
    defer fixture.deinit();

    mem.clearWritten();
    var batch = SettleBatch.init(receiver, .accepted);
    for (ids) |_| try batch.add(try receiver.receive(10_000));
    try batch.flush();

    const ranges = try settledRanges(allocator, mem.written());
    defer allocator.free(ranges);

    try testing.expectEqual(@as(usize, 3), ranges.len);
    try testing.expectEqual([2]u32{ 3, 5 }, ranges[0]);
    try testing.expectEqual([2]u32{ 8, 9 }, ranges[1]);
    try testing.expectEqual([2]u32{ 11, 11 }, ranges[2]);
}

test "a batch does not settle across the delivery id wrap" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};

    const max = std.math.maxInt(u32);
    const ids = [_]u32{ max - 2, max - 1, max, 0, 1 };
    var driver: Driver = undefined;
    var fixture: Fixture = undefined;
    const receiver = try scriptedReceiver(allocator, &mem, &clock, &driver, &fixture, &ids);
    defer driver.deinit();
    defer fixture.deinit();

    mem.clearWritten();
    var batch = SettleBatch.init(receiver, .accepted);
    for (ids) |_| try batch.add(try receiver.receive(10_000));
    try batch.flush();

    const ranges = try settledRanges(allocator, mem.written());
    defer allocator.free(ranges);

    // Treating these five as one run would put `first = 0xfffffffd,
    // last = 1` on the wire: legal under serial-number arithmetic, and
    // unreadable to every peer that just compares the two.
    try testing.expectEqual(@as(usize, 2), ranges.len);
    try testing.expectEqual([2]u32{ max - 2, max }, ranges[0]);
    try testing.expectEqual([2]u32{ 0, 1 }, ranges[1]);
    for (ranges) |r| try testing.expect(r[0] <= r[1]);
}

test "flushing an empty batch says nothing" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};

    var driver: Driver = undefined;
    var fixture: Fixture = undefined;
    const receiver = try scriptedReceiver(allocator, &mem, &clock, &driver, &fixture, &.{});
    defer driver.deinit();
    defer fixture.deinit();

    mem.clearWritten();
    var batch = SettleBatch.init(receiver, .accepted);
    try testing.expect(!batch.pending());
    try batch.flush();
    try batch.flush();

    const ranges = try settledRanges(allocator, mem.written());
    defer allocator.free(ranges);
    try testing.expectEqual(@as(usize, 0), ranges.len);
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

test "closing a sender detaches it and drops it from the session" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = connection.ManualClock{};
    var conn = try Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = harness.Peer{ .allocator = allocator, .mem = &mem };
    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "s",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .detach = .{ .handle = 0, .closed = true } });

    var fixture = try harness.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    const sender = try openSender(&fixture.session, .{
        .name = "s",
        .target_address = "hub",
    }, 10_000);
    try testing.expectEqual(@as(usize, 1), fixture.session.senders.items.len);

    mem.clearWritten();
    fixture.session.closeSender(sender, 10_000);

    // Left in the list, the session would keep pumping frames at a link
    // nobody can reach and `deinit` would free it a second time.
    try testing.expectEqual(@as(usize, 0), fixture.session.senders.items.len);

    var frames = try harness.EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    var detaches: usize = 0;
    for (frames.bodies.items) |body| {
        if (perf.peekDescriptor(body) == perf.descriptor.detach) detaches += 1;
    }
    try testing.expectEqual(@as(usize, 1), detaches);
}

test "closing a receiver the peer already detached sends no detach" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = connection.ManualClock{};
    var conn = try Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = harness.Peer{ .allocator = allocator, .mem = &mem };
    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "r",
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{ .condition = "amqp:link:stolen", .description = "taken" },
    } });

    var fixture = try harness.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    const receiver = try openReceiver(&fixture.session, .{
        .name = "r",
        .source_address = "hub/ConsumerGroups/$default/Partitions/0",
    }, 10_000);

    // Drain the peer's detach so the link knows it is gone.
    try testing.expectError(error.LinkDetached, receiver.receive(10_000));
    try testing.expectEqualStrings("amqp:link:stolen", receiver.detach_error.?.condition);

    mem.clearWritten();
    fixture.session.closeReceiver(receiver, 10_000);
    try testing.expectEqual(@as(usize, 0), fixture.session.receivers.items.len);

    var frames = try harness.EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    for (frames.bodies.items) |body| {
        try testing.expect(perf.peekDescriptor(body) != perf.descriptor.detach);
    }
}
