///! Azure AMQP Core — wraps azure-uamqp-zig for AMQP 1.0 protocol support.
///!
///! Re-exports the uamqp library types and adds what uamqp does not provide:
///! byte transports (TLS, plaintext TCP, and an in-memory duplex), a
///! performative codec, and a connection driver that runs the real handshake.
const std = @import("std");
pub const uamqp = @import("uamqp");

pub const transport = @import("transport.zig");
pub const performative = @import("performative.zig");
pub const connection_driver = @import("connection.zig");
pub const message_codec = @import("message.zig");
pub const link = @import("link.zig");
pub const rpc = @import("rpc.zig");
pub const cbs = @import("cbs.zig");
pub const management = @import("management.zig");
/// Scripted-peer helpers. Exported so packages built on this one can drive a
/// client against a canned peer without re-implementing the handshake.
pub const test_peer = @import("test_peer.zig");

// Transports.
pub const Transport = transport.Transport;
pub const TransportError = transport.TransportError;
pub const TlsTransport = transport.TlsTransport;
pub const TcpTransport = transport.TcpTransport;
pub const MemoryTransport = transport.MemoryTransport;
pub const Endpoint = transport.Endpoint;
pub const Socket = transport.Socket;
pub const connect = transport.connect;
pub const tls_port = transport.tls_port;
pub const tcp_port = transport.tcp_port;

// Connection driver.
pub const Driver = connection_driver.Driver;
pub const DriverOptions = connection_driver.Options;
pub const ConnectionError = connection_driver.ConnectionError;
pub const Clock = connection_driver.Clock;
pub const IoClock = connection_driver.IoClock;
pub const ManualClock = connection_driver.ManualClock;
pub const ClientInfo = connection_driver.ClientInfo;
pub const buildProperties = connection_driver.buildProperties;
pub const defaultClientInfo = connection_driver.defaultClientInfo;
pub const georeplication_capability = connection_driver.georeplication_capability;

// Sessions and links.
pub const Session = link.Session;
pub const SessionOptions = link.SessionOptions;
pub const Sender = link.Sender;
pub const SenderOptions = link.SenderOptions;
pub const SendOptions = link.SendOptions;
pub const DeliveryToken = link.DeliveryToken;
pub const Settlement = link.Settlement;
pub const Outcome = link.Outcome;
pub const Receiver = link.Receiver;
pub const ReceiverOptions = link.ReceiverOptions;
pub const Delivery = link.Delivery;
pub const Rejection = link.Rejection;
pub const SettleBatch = link.SettleBatch;
pub const LinkError = link.LinkError;
pub const openSender = link.openSender;
pub const openReceiver = link.openReceiver;
pub const receiver_name_property = link.receiver_name_property;
pub const epoch_property = link.epoch_property;

// Request/response and CBS.
pub const RpcLink = rpc.RpcLink;
pub const RpcOptions = rpc.Options;
pub const RpcError = rpc.RpcError;
pub const RpcResponse = rpc.Response;
pub const Cbs = cbs.Cbs;
pub const CbsOptions = cbs.Options;
pub const CbsError = cbs.CbsError;
pub const AccessToken = cbs.AccessToken;
pub const TokenProvider = cbs.TokenProvider;
pub const RefreshPolicy = cbs.RefreshPolicy;
pub const cbs_address = cbs.address;
pub const Management = management.Management;
pub const ManagementOptions = management.Options;
pub const ManagementRequest = management.Request;
pub const ManagementError = management.ManagementError;
pub const ManagementStatusError = management.StatusError;
pub const management_address = management.address;

// Message codec.
pub const Message = message_codec.Message;
pub const MessageBody = message_codec.Body;
pub const MessageHeader = message_codec.Header;
pub const MessageProperties = message_codec.Properties;
pub const encodeMessage = message_codec.encode;
pub const encodeMessageAlloc = message_codec.encodeAlloc;
pub const decodeMessage = message_codec.decode;

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

// Re-export messaging helpers.
pub const messaging = uamqp.messaging;

/// CBS token types used by Azure services.
pub const CbsTokenType = cbs.TokenType;

// Zig only analyzes a file that something actually references, so the
// re-exports above are not enough to make these files' tests run.
test {
    _ = transport;
    _ = performative;
    _ = connection_driver;
    _ = message_codec;
    _ = link;
    _ = rpc;
    _ = cbs;
    _ = management;
    _ = test_peer;
}

// ─────────────────────── Tests ───────────────────────

test "the re-exported message codec round-trips a body" {
    const allocator = std.testing.allocator;
    const bytes = try encodeMessageAlloc(allocator, .{
        .body = .{ .data = &.{"hello, event hub!"} },
    });
    defer allocator.free(bytes);

    var decoded = try decodeMessage(allocator, bytes);
    defer decoded.deinit();
    try std.testing.expectEqualStrings("hello, event hub!", decoded.message.body.data[0]);
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
