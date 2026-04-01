///! AMQP 1.0 core — connection, session, link, and message primitives.
///!
///! Built over `std.net.Stream` + TLS. Provides the framing layer that
///! Event Hubs and Service Bus use for messaging.

const std = @import("std");

// ─────────────────────── AMQP Type System ───────────────────────

/// AMQP 1.0 primitive value (subset).
pub const Value = union(enum) {
    null_val: void,
    boolean: bool,
    ubyte: u8,
    uint: u32,
    ulong: u64,
    int: i32,
    long: i64,
    string: []const u8,
    binary: []const u8,
    list: []Value,
    map: []MapEntry,

    pub const MapEntry = struct { key: Value, value: Value };
};

// ─────────────────────── Message Model ───────────────────────

pub const MessageProperties = struct {
    message_id: ?[]const u8 = null,
    correlation_id: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    subject: ?[]const u8 = null,
    reply_to: ?[]const u8 = null,
    to: ?[]const u8 = null,
};

pub const MessageHeader = struct {
    durable: bool = false,
    priority: u8 = 4,
    ttl: ?u32 = null,
    first_acquirer: bool = false,
    delivery_count: u32 = 0,
};

pub const AmqpMessage = struct {
    header: MessageHeader = .{},
    properties: MessageProperties = .{},
    application_properties: std.StringHashMap([]const u8),
    body: []const u8 = "",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AmqpMessage {
        return .{
            .application_properties = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AmqpMessage) void {
        self.application_properties.deinit();
    }
};

// ─────────────────────── Connection / Session / Link ───────────────────────

pub const SaslMechanism = enum { plain, anonymous, external };

pub const ConnectionOptions = struct {
    host: []const u8,
    port: u16 = 5671,
    use_tls: bool = true,
    sasl: SaslMechanism = .plain,
    container_id: []const u8 = "azure-sdk-zig",
    max_frame_size: u32 = 65536,
    idle_timeout_ms: u32 = 120_000,
};

/// Represents an AMQP 1.0 connection (stub — actual TCP/TLS in future).
pub const Connection = struct {
    options: ConnectionOptions,
    state: State = .start,

    pub const State = enum { start, opened, close_sent, closed };

    pub fn init(options: ConnectionOptions) Connection {
        return .{ .options = options };
    }

    pub fn open(self: *Connection) !void {
        // In production: TCP connect → TLS handshake → SASL → AMQP Open frame.
        self.state = .opened;
    }

    pub fn close(self: *Connection) void {
        self.state = .closed;
    }
};

/// An AMQP session multiplexed over a connection.
pub const Session = struct {
    connection: *Connection,
    channel: u16 = 0,

    pub fn init(connection: *Connection) Session {
        return .{ .connection = connection };
    }
};

/// A unidirectional link (sender or receiver) on a session.
pub const Link = struct {
    session: *Session,
    name: []const u8,
    role: Role,
    target: []const u8,

    pub const Role = enum { sender, receiver };

    pub fn init(session: *Session, name: []const u8, role: Role, target: []const u8) Link {
        return .{ .session = session, .name = name, .role = role, .target = target };
    }
};

/// Send messages over a link.
pub const MessageSender = struct {
    link: Link,

    pub fn init(session: *Session, target: []const u8) MessageSender {
        return .{ .link = Link.init(session, "sender", .sender, target) };
    }

    pub fn send(self: *MessageSender, message: AmqpMessage) !void {
        _ = self;
        _ = message;
        // Stub: encode AMQP transfer frame + message payload.
    }
};

/// Receive messages from a link.
pub const MessageReceiver = struct {
    link: Link,

    pub fn init(session: *Session, source: []const u8) MessageReceiver {
        return .{ .link = Link.init(session, "receiver", .receiver, source) };
    }
};

// ─────────────────────── CBS (Claims-Based Security) ───────────────────────

/// Token types for CBS authentication.
pub const CbsTokenType = enum {
    sas,
    jwt,

    pub fn toString(self: CbsTokenType) []const u8 {
        return switch (self) {
            .sas => "servicebus.windows.net:sastoken",
            .jwt => "jwt",
        };
    }
};

// ─────────────────────── Tests ───────────────────────

test "AmqpMessage init and deinit" {
    const allocator = std.testing.allocator;
    var msg = AmqpMessage.init(allocator);
    defer msg.deinit();
    msg.body = "hello";
    try msg.application_properties.put("key", "val");
    try std.testing.expectEqualStrings("hello", msg.body);
    try std.testing.expectEqualStrings("val", msg.application_properties.get("key").?);
}

test "Connection lifecycle" {
    var conn = Connection.init(.{ .host = "mynamespace.servicebus.windows.net" });
    try std.testing.expectEqual(Connection.State.start, conn.state);
    try conn.open();
    try std.testing.expectEqual(Connection.State.opened, conn.state);
    conn.close();
    try std.testing.expectEqual(Connection.State.closed, conn.state);
}

test "Session and Link" {
    var conn = Connection.init(.{ .host = "localhost" });
    try conn.open();
    var session = Session.init(&conn);
    const link = Link.init(&session, "my-link", .sender, "my-queue");
    try std.testing.expectEqualStrings("my-link", link.name);
    try std.testing.expectEqual(Link.Role.sender, link.role);
}

test "Value union" {
    const v = Value{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", v.string);
    const b = Value{ .boolean = true };
    try std.testing.expect(b.boolean);
}
