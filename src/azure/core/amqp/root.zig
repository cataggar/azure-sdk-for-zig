///! Azure AMQP Core — wraps azure-uamqp-zig for AMQP 1.0 protocol support.
///!
///! Re-exports the uamqp library types and provides Azure-specific
///! convenience wrappers for Connection, Session, Link, and Message.

const std = @import("std");
pub const uamqp = @import("uamqp");

// Re-export core protocol types.
pub const Connection = uamqp.connection.Connection;
pub const Session = uamqp.session.Session;
pub const Link = uamqp.link.Link;
pub const Message = uamqp.message.Message;

// Re-export AMQP type system.
pub const AmqpValue = uamqp.AmqpValue;
pub const Described = uamqp.Described;
pub const MapEntry = uamqp.MapEntry;
pub const encoder = uamqp.encoder;
pub const decoder = uamqp.decoder;

// Re-export protocol definitions (performatives, states, enums).
pub const definitions = uamqp.definitions;

// Re-export SASL mechanisms.
pub const SaslPlain = uamqp.sasl.plain.Plain;
pub const SaslAnonymous = uamqp.sasl.anonymous.Anonymous;
pub const SaslMechanism = uamqp.sasl.mechanism.Mechanism;

// Re-export CBS (Claims-Based Security).
pub const Cbs = uamqp.cbs.Cbs;

// Re-export management operations.
pub const Management = uamqp.management.Management;

// Re-export messaging helpers.
pub const messaging = uamqp.messaging;

/// CBS token types used by Azure services.
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

test "Connection init and deinit" {
    const allocator = std.testing.allocator;
    var conn = Connection.init(allocator, "azure-sdk-zig", "mynamespace.servicebus.windows.net", .{});
    defer conn.deinit();
    try std.testing.expectEqualStrings("azure-sdk-zig", conn.container_id);
}

test "Session init" {
    const allocator = std.testing.allocator;
    var conn = Connection.init(allocator, "test", null, .{});
    defer conn.deinit();
    var session = Session.init(allocator, &conn, .{});
    defer session.deinit();
    try std.testing.expectEqual(@as(u32, 0), session.next_outgoing_id);
}

test "Message create and add body data" {
    const allocator = std.testing.allocator;
    var msg = Message.init(allocator);
    defer msg.deinit();
    try msg.addBodyData("hello, event hub!");
    try std.testing.expectEqual(@as(usize, 1), msg.bodyDataCount());
}

test "SASL Plain mechanism" {
    const allocator = std.testing.allocator;
    var plain = SaslPlain.init(allocator, "user", "pass", null);
    defer plain.deinit();
    const mech = plain.mechanism();
    try std.testing.expectEqualStrings("PLAIN", mech.getMechanismName());
    const init_bytes = mech.getInitBytes();
    try std.testing.expect(init_bytes != null);
}

test "AmqpValue string" {
    const v = AmqpValue{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", v.string);
}

test "CbsTokenType" {
    try std.testing.expectEqualStrings("servicebus.windows.net:sastoken", CbsTokenType.sas.toString());
    try std.testing.expectEqualStrings("jwt", CbsTokenType.jwt.toString());
}
