//! The `$management` request/response endpoint.
//!
//! Event Hubs exposes hub and partition metadata here, and Service Bus uses
//! the same endpoint for its own operations. The transport is the ordinary RPC
//! link pair; what is specific to management is the request shape — an
//! `operation`, an entity `type`, a `name`, and the caller's `security_token`
//! — and turning a non-2xx reply into an error that carries the broker's
//! description.
//!
//! The path has to be authorised over CBS before this link attaches.

const std = @import("std");
const Allocator = std.mem.Allocator;

const link = @import("link.zig");
const message = @import("message.zig");
const perf = @import("performative.zig");
const rpc = @import("rpc.zig");
const uamqp = @import("uamqp");

const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;

pub const address = "$management";

pub const operation_key = "operation";
pub const type_key = "type";
pub const name_key = "name";
pub const security_token_key = "security_token";

/// The operation every metadata read uses.
pub const read_operation = "READ";

pub const ManagementError = rpc.RpcError;

/// A non-2xx reply, copied so it outlives the response it came from.
pub const StatusError = struct {
    code: i32,
    description: ?[]const u8,

    pub fn deinit(self: StatusError, allocator: Allocator) void {
        if (self.description) |d| allocator.free(d);
    }
};

pub const Request = struct {
    /// Defaults to `READ`, which is what every metadata operation uses.
    operation: []const u8 = read_operation,
    /// The entity type, such as `com.microsoft:eventhub`.
    entity_type: []const u8,
    /// The entity the operation applies to.
    name: []const u8,
    /// The CBS token for the management path. Omitted when the broker does
    /// not require it on the message itself.
    security_token: ?[]const u8 = null,
    /// Merged after the standard four. A caller may override any of them by
    /// repeating the key, since the broker reads the last occurrence.
    properties: ?perf.Fields = null,
    body: message.Body = .empty,
};

pub const Options = struct {
    /// Distinguishes this link pair from any other on the connection.
    link_id: []const u8,
};

/// A `$management` client.
pub const Management = struct {
    allocator: Allocator,
    rpc_link: *rpc.RpcLink,
    /// The most recent non-2xx reply. Errors cannot carry a payload, so the
    /// broker's status and description are recorded here, as the connection
    /// driver does for remote errors.
    last_error: ?StatusError = null,

    pub fn open(
        session: *link.Session,
        options: Options,
        deadline_ms: i64,
    ) ManagementError!*Management {
        const allocator = session.allocator;
        const self = try allocator.create(Management);
        errdefer allocator.destroy(self);

        const rpc_link = try rpc.RpcLink.open(session, .{
            .address = address,
            .link_id = options.link_id,
        }, deadline_ms);
        errdefer rpc_link.deinit();

        self.* = .{ .allocator = allocator, .rpc_link = rpc_link };
        return self;
    }

    pub fn deinit(self: *Management) void {
        self.clearError();
        self.rpc_link.deinit();
        self.allocator.destroy(self);
    }

    pub fn close(self: *Management, deadline_ms: i64) ManagementError!void {
        try self.rpc_link.close(deadline_ms);
    }

    /// Send `request` and return the id its reply will be correlated by.
    ///
    /// Splitting the send from the wait lets a caller keep several requests in
    /// flight; each is matched to its own reply however the broker orders
    /// them.
    pub fn begin(
        self: *Management,
        request: Request,
        deadline_ms: i64,
    ) ManagementError![]const u8 {
        var props: std.ArrayList(MapEntry) = .empty;
        defer props.deinit(self.allocator);

        try props.append(self.allocator, .{
            .key = .{ .string = operation_key },
            .value = .{ .string = request.operation },
        });
        try props.append(self.allocator, .{
            .key = .{ .string = type_key },
            .value = .{ .string = request.entity_type },
        });
        try props.append(self.allocator, .{
            .key = .{ .string = name_key },
            .value = .{ .string = request.name },
        });
        if (request.security_token) |token| {
            try props.append(self.allocator, .{
                .key = .{ .string = security_token_key },
                .value = .{ .string = token },
            });
        }
        if (request.properties) |extra| {
            try props.appendSlice(self.allocator, extra);
        }

        return self.rpc_link.begin(.{
            .application_properties = props.items,
            .body = request.body,
        }, deadline_ms);
    }

    /// Wait for the reply to `id`, failing on a non-2xx status.
    pub fn awaitReply(
        self: *Management,
        id: []const u8,
        deadline_ms: i64,
    ) ManagementError!rpc.Response {
        var response = try self.rpc_link.awaitReply(id, deadline_ms);
        errdefer response.deinit();
        try self.check(response);
        return response;
    }

    /// Give up on `id` without waiting for its reply.
    pub fn abandon(self: *Management, id: []const u8) void {
        self.rpc_link.abandon(id);
    }

    /// Send `request` and wait for its reply, failing on a non-2xx status.
    ///
    /// On failure `last_error` carries the broker's status and description.
    pub fn call(
        self: *Management,
        request: Request,
        deadline_ms: i64,
    ) ManagementError!rpc.Response {
        const id = try self.begin(request, deadline_ms);
        return self.awaitReply(id, deadline_ms);
    }

    /// Send `request` and return the reply whatever its status, for callers
    /// that treat some non-2xx codes as expected.
    pub fn callRaw(
        self: *Management,
        request: Request,
        deadline_ms: i64,
    ) ManagementError!rpc.Response {
        const id = try self.begin(request, deadline_ms);
        return self.rpc_link.awaitReply(id, deadline_ms);
    }

    fn check(self: *Management, response: rpc.Response) ManagementError!void {
        rpc.checkStatus(response.status_code) catch |e| {
            self.recordError(response);
            return e;
        };
        self.clearError();
    }

    fn recordError(self: *Management, response: rpc.Response) void {
        self.clearError();
        // A failure to copy the description must not mask the status itself.
        const description = if (response.status_description) |d|
            self.allocator.dupe(u8, d) catch null
        else
            null;
        self.last_error = .{
            .code = response.status_code,
            .description = description,
        };
    }

    fn clearError(self: *Management) void {
        if (self.last_error) |e| e.deinit(self.allocator);
        self.last_error = null;
    }
};

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const connection = @import("connection.zig");
const harness = @import("test_peer.zig");
const MemoryTransport = @import("transport.zig").MemoryTransport;
const Peer = harness.Peer;
const Fixture = harness.Fixture;
const EmittedFrames = harness.EmittedFrames;

/// Script the peer's side of attaching a `$management` link pair.
fn scriptAttach(peer: Peer, credit: u32) !void {
    try harness.scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "$management-sender-test",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "$management-receiver-test",
        .handle = 1,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = credit,
    } });
}

/// Settle the request the client sent as delivery `n - 1`.
fn scriptSettle(peer: Peer, n: u64) !void {
    const delivery_id: u32 = @intCast(n - 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = delivery_id,
        .last = delivery_id,
        .settled = true,
        .state = .accepted,
    } });
}

/// Push a reply correlated to request `n`.
fn scriptReply(
    peer: Peer,
    allocator: Allocator,
    n: u64,
    status: i32,
    description: []const u8,
    delivery_id: u32,
) !void {
    var id_buf: [64]u8 = undefined;
    const correlation = try std.fmt.bufPrint(&id_buf, "management-reply-to-test:{d}", .{n});
    const props = [_]MapEntry{
        .{ .key = .{ .string = rpc.status_code_key }, .value = .{ .int = status } },
        .{
            .key = .{ .string = rpc.status_description_key },
            .value = .{ .string = description },
        },
    };
    const payload = try message.encodeAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = correlation } },
        .application_properties = &props,
        .body = .{ .value = .{ .string = description } },
    });
    defer allocator.free(payload);

    try peer.pushTransfer(0, .{
        .handle = 1,
        .delivery_id = delivery_id,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, payload);
}

fn propertyValue(props: perf.Fields, key: []const u8) ?AmqpValue {
    for (props) |entry| {
        const name = switch (entry.key) {
            .string, .symbol => |str| str,
            else => continue,
        };
        if (std.mem.eql(u8, name, key)) return entry.value;
    }
    return null;
}

test "a request carries the operation, type, name, and security token" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 200, "OK", 0);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    mem.clearWritten();
    const extra = [_]MapEntry{
        .{ .key = .{ .string = "com.microsoft:partition" }, .value = .{ .string = "3" } },
    };
    var response = try client.call(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "my-hub",
        .security_token = "SharedAccessSignature sr=x&sig=y",
        .properties = &extra,
    }, 10_000);
    defer response.deinit();

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const transfers = try frames.of(allocator, 0x14);
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);

    var decoded = try message.decode(allocator, try harness.transferPayload(allocator, transfers[0]));
    defer decoded.deinit();
    const props = decoded.message.application_properties.?;

    try testing.expectEqualStrings("READ", propertyValue(props, operation_key).?.string);
    try testing.expectEqualStrings("com.microsoft:eventhub", propertyValue(props, type_key).?.string);
    try testing.expectEqualStrings("my-hub", propertyValue(props, name_key).?.string);
    try testing.expectEqualStrings(
        "SharedAccessSignature sr=x&sig=y",
        propertyValue(props, security_token_key).?.string,
    );
    // Caller properties are merged alongside the standard four.
    try testing.expectEqualStrings("3", propertyValue(props, "com.microsoft:partition").?.string);
    try testing.expectEqualStrings("management-reply-to-test", decoded.message.properties.reply_to.?);

    try testing.expectEqual(@as(i32, 200), response.status_code);
}

test "two requests answered out of order each reach the right caller" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptSettle(peer, 2);
    // The broker answers the second request first.
    try scriptReply(peer, allocator, 2, 200, "second", 0);
    try scriptReply(peer, allocator, 1, 200, "first", 1);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    const first = try client.begin(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "hub-one",
    }, 10_000);
    const second = try client.begin(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "hub-two",
    }, 10_000);

    // Awaiting the first has to hold the second's reply rather than discard
    // it, since it arrives first.
    var first_response = try client.awaitReply(first, 10_000);
    defer first_response.deinit();
    try testing.expectEqualStrings("first", first_response.status_description.?);

    var second_response = try client.awaitReply(second, 10_000);
    defer second_response.deinit();
    try testing.expectEqualStrings("second", second_response.status_description.?);
}

test "a 404 reply fails the call and records the broker's description" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 404, "The messaging entity 'missing' could not be found.", 0);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    try testing.expectError(error.RequestFailed, client.call(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "missing",
    }, 10_000));

    try testing.expectEqual(@as(i32, 404), client.last_error.?.code);
    try testing.expectEqualStrings(
        "The messaging entity 'missing' could not be found.",
        client.last_error.?.description.?,
    );
}

test "a detach fails an in-flight request instead of hanging" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    // The broker tears the reply link down without answering.
    try peer.push(0, .{ .detach = .{
        .handle = 1,
        .closed = true,
        .err = .{
            .condition = "amqp:link:detach-forced",
            .description = "The link was closed by the service.",
        },
    } });

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    const id = try client.begin(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "my-hub",
    }, 10_000);

    try testing.expectError(error.LinkDetached, client.awaitReply(id, 10_000));
}

test "a request with no reply times out rather than blocking forever" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    const id = try client.begin(.{
        .entity_type = "com.microsoft:eventhub",
        .name = "my-hub",
    }, 10_000);

    // The peer has nothing more to say, so the read starves and the deadline
    // decides the outcome.
    mem.starve = true;
    try testing.expectError(error.Timeout, client.awaitReply(id, clock.millis));
}

test "awaiting an unknown request id is an error, not a hang" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Management.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    try testing.expectError(error.UnknownRequest, client.awaitReply("never-sent", 10_000));
}
