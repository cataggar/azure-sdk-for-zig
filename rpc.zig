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
        self.allocator.free(self.address);
        self.allocator.free(self.reply_to);
        self.allocator.destroy(self);
    }

    /// Detach both links.
    pub fn close(self: *RpcLink, deadline_ms: i64) RpcError!void {
        self.receiver.detach(deadline_ms) catch {};
        try self.sender.detach(deadline_ms);
    }

    /// Send `request` and wait for the reply correlated to it.
    ///
    /// `request.properties.message_id` and `.reply_to` are filled in here and
    /// overwrite anything the caller set, since the correlation depends on
    /// them.
    pub fn call(
        self: *RpcLink,
        request: message.Message,
        deadline_ms: i64,
    ) RpcError!Response {
        var buf: [48]u8 = undefined;
        const id = self.nextMessageId(&buf);

        var outgoing = request;
        outgoing.properties.message_id = .{ .string = id };
        outgoing.properties.reply_to = self.reply_to;

        try self.sender.send(outgoing, deadline_ms);

        // Replies for other requests can be in flight after a timeout, so keep
        // reading until the correlation id matches rather than trusting order.
        while (true) {
            const delivery = try self.receiver.receive(deadline_ms);
            var response = self.parse(delivery.payload) catch |e| switch (e) {
                error.MalformedReply => {
                    self.receiver.accept(delivery) catch {};
                    continue;
                },
                else => return e,
            };
            errdefer response.deinit();
            self.receiver.accept(delivery) catch {};

            if (!correlates(response.decoded.message, id)) {
                response.deinit();
                continue;
            }
            return response;
        }
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

fn correlates(msg: message.Message, id: []const u8) bool {
    const value = msg.properties.correlation_id orelse
        // Some brokers echo the id in message-id instead.
        msg.properties.message_id orelse return false;
    return switch (value) {
        .string, .binary, .symbol => |s| std.mem.eql(u8, s, id),
        else => false,
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
    try testing.expect(correlates(.{
        .properties = .{ .correlation_id = .{ .string = "id-1" } },
    }, "id-1"));
    try testing.expect(!correlates(.{
        .properties = .{ .correlation_id = .{ .string = "id-2" } },
    }, "id-1"));
    try testing.expect(correlates(.{
        .properties = .{ .message_id = .{ .string = "id-1" } },
    }, "id-1"));
    try testing.expect(!correlates(.{}, "id-1"));
}
