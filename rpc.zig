//! Request/response over a pair of AMQP links.
//!
//! Both CBS (`$cbs`) and the Event Hubs `$management` endpoint work the same
//! way: a sender writes a message to a well-known address, and a receiver
//! attached to a private reply address gets the answer back, correlated by
//! message id. Go shares one `rpcLink` between them for exactly this reason,
//! so the mechanism lives here rather than in either caller.
//!
//! The status of a reply is carried in application properties rather than in
//! the AMQP delivery outcome, so a rejected request still arrives as an
//! accepted transfer with a 4xx or 5xx `status-code`.

const std = @import("std");
const Allocator = std.mem.Allocator;

const link = @import("link.zig");
const message = @import("message.zig");
const perf = @import("performative.zig");
const uamqp = @import("uamqp");

const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;

pub const RpcError = link.LinkError || error{
    /// The reply carried no `status-code` property.
    MissingStatusCode,
    /// The reply's `status-code` was not an integer.
    InvalidStatusCode,
    /// The service rejected the request; see `Response.status_code`.
    RequestFailed,
    /// The service refused the credential (401).
    Unauthorized,
    /// Awaited a request id that was never begun, or was already awaited.
    UnknownRequest,
    /// The reply body could not be parsed as an AMQP message.
    MalformedReply,
};

/// The property names a reply's status arrives under. Go accepts both
/// spellings because the Event Hubs and Service Bus brokers disagree.
pub const status_code_key = "status-code";
pub const status_description_key = "status-description";
pub const alt_status_code_key = "statusCode";
pub const alt_status_description_key = "statusDescription";

/// A parsed reply. Owns its backing bytes; call `deinit`.
pub const Response = struct {
    allocator: Allocator,
    decoded: message.Decoded,
    payload: []const u8,
    status_code: i32,
    status_description: ?[]const u8,

    pub fn deinit(self: *Response) void {
        self.decoded.deinit();
        self.allocator.free(self.payload);
    }

    pub fn msg(self: Response) message.Message {
        return self.decoded.message;
    }

    /// The reply's application properties, or an empty slice.
    pub fn properties(self: Response) perf.Fields {
        return self.decoded.message.application_properties orelse &.{};
    }
};

pub const Options = struct {
    /// The well-known address to send to, such as `$cbs` or `$management`.
    address: []const u8,
    /// Distinguishes this link pair from others on the same connection.
    /// Callers that open more than one must vary it.
    link_id: []const u8,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?perf.Fields = null,
};

/// A sender/receiver pair implementing request/response against `address`.
pub const RpcLink = struct {
    allocator: Allocator,
    session: *link.Session,
    address: []const u8,
    /// The private address replies are routed back to.
    reply_to: []const u8,
    sender: *link.Sender,
    receiver: *link.Receiver,
    /// Serial number behind the correlation id.
    next_id: u64 = 1,
    /// Requests awaiting a reply, keyed by correlation id. A filled value is a
    /// reply that arrived before its caller asked for it.
    pending: std.StringHashMapUnmanaged(?Response) = .empty,

    pub fn open(
        session: *link.Session,
        options: Options,
        deadline_ms: i64,
    ) RpcError!*RpcLink {
        const allocator = session.allocator;
        const self = try allocator.create(RpcLink);
        errdefer allocator.destroy(self);

        const address = try allocator.dupe(u8, options.address);
        errdefer allocator.free(address);

        const reply_to = try replyAddress(allocator, options.address, options.link_id);
        errdefer allocator.free(reply_to);

        const sender_name = try std.fmt.allocPrint(
            allocator,
            "{s}-sender-{s}",
            .{ options.address, options.link_id },
        );
        defer allocator.free(sender_name);

        const receiver_name = try std.fmt.allocPrint(
            allocator,
            "{s}-receiver-{s}",
            .{ options.address, options.link_id },
        );
        defer allocator.free(receiver_name);

        const sender = try link.openSender(session, .{
            .name = sender_name,
            .target_address = options.address,
            .desired_capabilities = options.desired_capabilities,
            .properties = options.properties,
        }, deadline_ms);
        errdefer sender.deinit();

        // Replies arrive pre-settled: the reply carries its own status, so
        // there is nothing useful to signal back with a disposition.
        const receiver = try link.openReceiver(session, .{
            .name = receiver_name,
            .source_address = options.address,
            .target_address = reply_to,
            .rcv_settle_mode = .first,
            .desired_capabilities = options.desired_capabilities,
            .properties = options.properties,
        }, deadline_ms);
        errdefer receiver.deinit();

        self.* = .{
            .allocator = allocator,
            .session = session,
            .address = address,
            .reply_to = reply_to,
            .sender = sender,
            .receiver = receiver,
        };
        return self;
    }

    pub fn deinit(self: *RpcLink) void {
        self.failAll();
        self.pending.deinit(self.allocator);
        self.allocator.free(self.address);
        self.allocator.free(self.reply_to);
        self.allocator.destroy(self);
    }

    /// Detach both links.
    pub fn close(self: *RpcLink, deadline_ms: i64) RpcError!void {
        self.receiver.detach(deadline_ms) catch {};
        try self.sender.detach(deadline_ms);
    }

    /// Send `request` and return the id its reply will be correlated by.
    ///
    /// `request.properties.message_id` and `.reply_to` are filled in here and
    /// overwrite anything the caller set, since the correlation depends on
    /// them. The returned id is owned by the link and stays valid until the
    /// request is awaited or abandoned.
    pub fn begin(
        self: *RpcLink,
        request: message.Message,
        deadline_ms: i64,
    ) RpcError![]const u8 {
        var buf: [64]u8 = undefined;
        const id = try self.allocator.dupe(u8, self.nextMessageId(&buf));
        errdefer self.allocator.free(id);

        const entry = try self.pending.getOrPut(self.allocator, id);
        std.debug.assert(!entry.found_existing);
        entry.value_ptr.* = null;
        errdefer _ = self.pending.remove(id);

        var outgoing = request;
        outgoing.properties.message_id = .{ .string = id };
        outgoing.properties.reply_to = self.reply_to;

        try self.sender.send(outgoing, deadline_ms);
        return id;
    }

    /// Wait for the reply to `id`.
    ///
    /// Replies for other outstanding requests are held rather than discarded,
    /// so callers with several requests in flight each get their own answer
    /// however the broker orders them.
    pub fn awaitReply(
        self: *RpcLink,
        id: []const u8,
        deadline_ms: i64,
    ) RpcError!Response {
        defer self.release(id);
        while (true) {
            if (self.pending.getEntry(id)) |entry| {
                if (entry.value_ptr.*) |response| {
                    entry.value_ptr.* = null;
                    return response;
                }
            } else {
                return error.UnknownRequest;
            }

            // A detached link will never answer, so fail rather than block
            // until the deadline.
            if (!self.receiver.attached) return error.LinkDetached;

            const delivery = self.receiver.receive(deadline_ms) catch |e| {
                if (e == error.LinkDetached) self.failAll();
                return e;
            };
            self.deposit(delivery.payload) catch |e| switch (e) {
                // A reply we cannot parse belongs to nobody; keep reading
                // rather than failing a request that may still be answered.
                error.MalformedReply => {},
                else => return e,
            };
            self.receiver.accept(delivery) catch {};
        }
    }

    /// Give up on `id` without waiting for its reply.
    pub fn abandon(self: *RpcLink, id: []const u8) void {
        self.release(id);
    }

    /// Send `request` and wait for its reply.
    pub fn call(
        self: *RpcLink,
        request: message.Message,
        deadline_ms: i64,
    ) RpcError!Response {
        const id = try self.begin(request, deadline_ms);
        return self.awaitReply(id, deadline_ms);
    }

    /// Park a reply against the request it answers, dropping it if no request
    /// is waiting for it — a late answer to something already abandoned.
    fn deposit(self: *RpcLink, payload: []const u8) RpcError!void {
        var response = try self.parse(payload);
        errdefer response.deinit();

        const id = correlationOf(response.decoded.message) orelse {
            response.deinit();
            return;
        };
        const entry = self.pending.getEntry(id) orelse {
            response.deinit();
            return;
        };
        if (entry.value_ptr.*) |*existing| existing.deinit();
        entry.value_ptr.* = response;
    }

    fn release(self: *RpcLink, id: []const u8) void {
        if (self.pending.fetchRemove(id)) |removed| {
            if (removed.value) |value| {
                var response = value;
                response.deinit();
            }
            self.allocator.free(removed.key);
        }
    }

    /// Drop every outstanding request. Their callers get `error.LinkDetached`
    /// on the next await rather than blocking for a reply that cannot come.
    fn failAll(self: *RpcLink) void {
        var it = self.pending.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*) |*response| response.deinit();
            self.allocator.free(entry.key_ptr.*);
        }
        self.pending.clearRetainingCapacity();
    }

    fn nextMessageId(self: *RpcLink, buf: []u8) []const u8 {
        const n = self.next_id;
        self.next_id += 1;
        return std.fmt.bufPrint(buf, "{s}:{d}", .{ self.reply_to, n }) catch
            std.fmt.bufPrint(buf, "{d}", .{n}) catch unreachable;
    }

    fn parse(self: *RpcLink, payload: []const u8) RpcError!Response {
        const owned = try self.allocator.dupe(u8, payload);
        errdefer self.allocator.free(owned);

        var decoded = message.decode(self.allocator, owned) catch
            return error.MalformedReply;
        errdefer decoded.deinit();

        const props = decoded.message.application_properties orelse &.{};
        const code = try statusCode(props);
        return .{
            .allocator = self.allocator,
            .decoded = decoded,
            .payload = owned,
            .status_code = code,
            .status_description = statusDescription(props),
        };
    }
};

/// The private address replies come back on.
///
/// Go intends to strip the leading `$` from the endpoint address, but its
/// `strings.ReplaceAll("$", "", args.Address)` has the haystack and needle
/// swapped, so it actually produces `$cbs$$cbs-reply-to-<id>`. Any unique
/// address works, so this implements the intent rather than the accident.
fn replyAddress(allocator: Allocator, address: []const u8, link_id: []const u8) Allocator.Error![]u8 {
    const bare = std.mem.trimStart(u8, address, "$");
    return std.fmt.allocPrint(allocator, "{s}-reply-to-{s}", .{ bare, link_id });
}

/// The request id a reply answers.
fn correlationOf(msg: message.Message) ?[]const u8 {
    const value = msg.properties.correlation_id orelse
        // Some brokers echo the id in message-id instead.
        msg.properties.message_id orelse return null;
    return switch (value) {
        .string, .binary, .symbol => |s| s,
        else => null,
    };
}

fn lookup(props: perf.Fields, key: []const u8) ?AmqpValue {
    for (props) |entry| {
        const name = switch (entry.key) {
            .string, .symbol => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, name, key)) return entry.value;
    }
    return null;
}

/// Read the reply's status code, accepting either spelling and any integral
/// encoding the broker chose.
pub fn statusCode(props: perf.Fields) RpcError!i32 {
    const value = lookup(props, status_code_key) orelse
        lookup(props, alt_status_code_key) orelse
        return error.MissingStatusCode;
    return switch (value) {
        .byte => |v| v,
        .short => |v| v,
        .int => |v| v,
        .long => |v| std.math.cast(i32, v) orelse error.InvalidStatusCode,
        .ubyte => |v| v,
        .ushort => |v| v,
        .uint => |v| std.math.cast(i32, v) orelse error.InvalidStatusCode,
        .ulong => |v| std.math.cast(i32, v) orelse error.InvalidStatusCode,
        else => error.InvalidStatusCode,
    };
}

/// Read the reply's status description, accepting either spelling.
pub fn statusDescription(props: perf.Fields) ?[]const u8 {
    const value = lookup(props, status_description_key) orelse
        lookup(props, alt_status_description_key) orelse
        return null;
    return switch (value) {
        .string, .symbol => |s| s,
        else => null,
    };
}

/// Map a reply status onto an error. 2xx succeeds; a 401 is reported
/// distinctly because callers must not retry it.
pub fn checkStatus(code: i32) RpcError!void {
    if (code >= 200 and code < 300) return;
    if (code == 401) return error.Unauthorized;
    return error.RequestFailed;
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test "the reply address strips the endpoint's leading sigil" {
    const allocator = testing.allocator;
    const addr = try replyAddress(allocator, "$cbs", "abc");
    defer allocator.free(addr);
    try testing.expectEqualStrings("cbs-reply-to-abc", addr);

    const mgmt = try replyAddress(allocator, "$management", "xyz");
    defer allocator.free(mgmt);
    try testing.expectEqualStrings("management-reply-to-xyz", mgmt);
}

test "a status code is read under either spelling and any integral encoding" {
    try testing.expectEqual(@as(i32, 202), try statusCode(&.{
        .{ .key = .{ .string = status_code_key }, .value = .{ .int = 202 } },
    }));
    try testing.expectEqual(@as(i32, 202), try statusCode(&.{
        .{ .key = .{ .symbol = alt_status_code_key }, .value = .{ .ushort = 202 } },
    }));
    try testing.expectEqual(@as(i32, 401), try statusCode(&.{
        .{ .key = .{ .string = status_code_key }, .value = .{ .long = 401 } },
    }));
    try testing.expectError(error.MissingStatusCode, statusCode(&.{
        .{ .key = .{ .string = "other" }, .value = .{ .int = 200 } },
    }));
    try testing.expectError(error.InvalidStatusCode, statusCode(&.{
        .{ .key = .{ .string = status_code_key }, .value = .{ .string = "200" } },
    }));
}

test "a status description is read under either spelling" {
    try testing.expectEqualStrings("ok", statusDescription(&.{
        .{ .key = .{ .string = status_description_key }, .value = .{ .string = "ok" } },
    }).?);
    try testing.expectEqualStrings("bad", statusDescription(&.{
        .{ .key = .{ .string = alt_status_description_key }, .value = .{ .string = "bad" } },
    }).?);
    try testing.expect(statusDescription(&.{}) == null);
}

test "a 401 is distinguished from other failures so it is not retried" {
    try checkStatus(200);
    try checkStatus(202);
    try testing.expectError(error.Unauthorized, checkStatus(401));
    try testing.expectError(error.RequestFailed, checkStatus(404));
    try testing.expectError(error.RequestFailed, checkStatus(500));
}

test "a reply correlates on correlation-id, falling back to message-id" {
    try testing.expectEqualStrings("id-1", correlationOf(.{
        .properties = .{ .correlation_id = .{ .string = "id-1" } },
    }).?);
    // Some brokers echo the request id in message-id instead.
    try testing.expectEqualStrings("id-1", correlationOf(.{
        .properties = .{ .message_id = .{ .string = "id-1" } },
    }).?);
    // correlation-id wins when both are present.
    try testing.expectEqualStrings("id-1", correlationOf(.{
        .properties = .{
            .correlation_id = .{ .string = "id-1" },
            .message_id = .{ .string = "id-2" },
        },
    }).?);
    try testing.expect(correlationOf(.{}) == null);
}
