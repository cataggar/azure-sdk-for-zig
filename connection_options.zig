//! Connection-level client options, and the factory that honours them.
//!
//! Everything here is about *reaching* the namespace rather than talking to
//! it: which address is dialled, which identity the certificate must match,
//! what the service records about the caller, and how a caller behind a
//! firewall that blocks 5671 gets out at all.
//!
//! Go carries these on `ProducerClientOptions`/`ConsumerClientOptions`
//! (`producer_client.go`, `consumer_client.go`) and reaches the service over
//! WebSockets by handing the caller a `wss://…/$servicebus/websocket` URL and
//! using whatever connection comes back (`internal/namespace.go`). Rust has
//! `with_application_id`, `with_custom_endpoint`, and `with_retry_options`,
//! and routes the custom endpoint while keeping the original hostname for TLS
//! and authentication. This does both.

const std = @import("std");
const builtin = @import("builtin");
const amqp = @import("azure_sdk_amqp");
const errors = @import("errors.zig");
const recovery = @import("recovery.zig");

const Allocator = std.mem.Allocator;

/// Version reported to the service in the `open` properties.
pub const sdk_version = "0.1.0";

/// The product half of the user agent, matching the other SDKs' shape.
pub const user_agent_product = "azsdk-zig-eventhubs";

/// Path Event Hubs serves AMQP-over-WebSockets on.
pub const web_socket_path = "/$servicebus/websocket";

/// Somewhere other than the namespace to dial.
///
/// The namespace stays the TLS server name and the CBS audience: a proxy
/// fronting the service presents the *namespace's* certificate, and tokens are
/// issued for the namespace no matter which address carried the bytes.
pub const CustomEndpoint = struct {
    host: []const u8,
    port: u16 = amqp.tls_port,
};

/// TLS knobs.
pub const TlsSettings = struct {
    /// Certificate bundle to validate against. Null rescans the system trust
    /// store on every dial, which is slow enough that a long-lived client
    /// should hoist one out and share it. Supplying a bundle is also how the
    /// emulator's self-signed root gets trusted.
    bundle: ?*std.crypto.Certificate.Bundle = null,
};

/// A caller-supplied AMQP-over-WebSockets connection.
///
/// The SDK deliberately ships no WebSocket implementation: it would be a
/// second protocol stack and, in Zig, a dependency. Instead the caller is
/// handed the URL to connect to and returns a duplex stream, exactly as Go's
/// `NewWebSocketConn` does.
pub const WebSocketHook = struct {
    context: *anyopaque,
    /// `url` is valid only for the duration of the call.
    connectFn: *const fn (
        context: *anyopaque,
        allocator: Allocator,
        url: []const u8,
    ) anyerror!amqp.Transport,
    /// Release whatever `connectFn` returned. Null when the caller keeps
    /// ownership of the stream.
    closeFn: ?*const fn (context: *anyopaque, stream: amqp.Transport) void = null,

    pub fn connect(self: WebSocketHook, allocator: Allocator, url: []const u8) !amqp.Transport {
        return self.connectFn(self.context, allocator, url);
    }

    pub fn close(self: WebSocketHook, stream: amqp.Transport) void {
        if (self.closeFn) |f| f(self.context, stream);
    }
};

/// Connection-level options shared by both clients.
pub const ConnectionOptions = struct {
    /// Prefixed to the user agent so the service can attribute traffic to the
    /// calling application. Borrowed; must outlive the client.
    application_id: ?[]const u8 = null,
    /// Dial here instead of the namespace.
    custom_endpoint: ?CustomEndpoint = null,
    /// Schedule used for every operation the client retries.
    retry_options: errors.RetryOptions = .{},
    tls: TlsSettings = .{},
    /// Set to go out over WebSockets, for firewalls that allow only 443.
    web_socket: ?WebSocketHook = null,
    /// Cleared for the emulator, which speaks plaintext AMQP.
    use_tls: bool = true,

    /// Where to dial and whose certificate to demand.
    ///
    /// A custom endpoint replaces the address only. `viaCustomEndpoint` keeps
    /// the namespace as the server name, so SNI and hostname verification are
    /// unaffected by the detour.
    pub fn endpointFor(self: ConnectionOptions, fully_qualified_namespace: []const u8) amqp.Endpoint {
        const direct: amqp.Endpoint = .{
            .host = fully_qualified_namespace,
            .port = if (self.use_tls) amqp.tls_port else amqp.tcp_port,
            .tls = self.use_tls,
        };
        const custom = self.custom_endpoint orelse return direct;
        return direct.viaCustomEndpoint(custom.host, custom.port);
    }

    /// The user agent sent in the `open` properties. Caller owns the result.
    ///
    /// `<application id> azsdk-zig-eventhubs/<version> (<platform>)`, the same
    /// ordering azcore uses: the application id first so it survives any
    /// truncation the service applies.
    pub fn userAgent(self: ConnectionOptions, allocator: Allocator) Allocator.Error![]u8 {
        const platform = @tagName(builtin.os.tag);
        if (self.application_id) |id| {
            return std.fmt.allocPrint(allocator, "{s} {s}/{s} ({s})", .{
                id,
                user_agent_product,
                sdk_version,
                platform,
            });
        }
        return std.fmt.allocPrint(allocator, "{s}/{s} ({s})", .{
            user_agent_product,
            sdk_version,
            platform,
        });
    }

    /// The retry schedule these options describe, ready for `runWithRecovery`.
    pub fn retryConfig(
        self: ConnectionOptions,
        sleeper: *errors.Sleeper,
        random: std.Random,
    ) errors.RetryConfig {
        return .{ .options = self.retry_options, .sleeper = sleeper, .random = random };
    }

    /// The WebSocket URL for `fully_qualified_namespace`. Caller owns it.
    pub fn webSocketUrl(
        self: ConnectionOptions,
        allocator: Allocator,
        fully_qualified_namespace: []const u8,
    ) Allocator.Error![]u8 {
        _ = self;
        return std.fmt.allocPrint(allocator, "wss://{s}{s}", .{
            fully_qualified_namespace,
            web_socket_path,
        });
    }
};

/// Capabilities every Event Hubs connection asks for.
///
/// Geo-replication changes how the service reports partition ownership, and
/// it is only reported to a connection that asked.
pub const desired_capabilities = [_][]const u8{amqp.georeplication_capability};

// ─────────────────── Connection factory ───────────────────

/// Everything one connection generation owns, so recovery can drop it whole.
const Generation = struct {
    allocator: Allocator,
    socket: ?amqp.Socket,
    web_socket: ?amqp.Transport,
    hook: ?WebSocketHook,
    clock: ?*amqp.IoClock,
    driver: *amqp.Driver,
    session: *amqp.Session,
    properties: []amqp.MapEntry,
    user_agent: []u8,

    fn deinit(self: *Generation) void {
        self.session.end(0) catch {};
        self.session.deinit();
        self.allocator.destroy(self.session);
        self.driver.close(null, 0) catch {};
        self.driver.deinit();
        self.allocator.destroy(self.driver);
        if (self.socket) |socket| socket.deinit();
        if (self.web_socket) |stream| {
            if (self.hook) |hook| hook.close(stream);
        }
        if (self.clock) |clock| self.allocator.destroy(clock);
        self.allocator.free(self.properties);
        self.allocator.free(self.user_agent);
        self.allocator.destroy(self);
    }
};

/// Dials a real namespace, honouring `ConnectionOptions`.
///
/// One of these backs a `RecoverableConnection`, so a rebuild re-reads the
/// options and re-dials from scratch — including re-invoking the WebSocket
/// hook, since the caller's stream died with the connection.
pub const AmqpConnectionFactory = struct {
    allocator: Allocator,
    /// Required to dial. A caller supplying a WebSocket hook brings its own
    /// connected stream, so it may leave this null.
    io: ?std.Io = null,
    /// Source of the deadlines the driver enforces. Defaults to an `IoClock`
    /// over `io`.
    clock: ?amqp.Clock = null,
    /// The namespace. Stays the TLS identity and the CBS audience even when a
    /// custom endpoint moves the address.
    fully_qualified_namespace: []const u8,
    /// Identifies this connection to the service.
    container_id: []const u8,
    options: ConnectionOptions = .{},
    session_options: amqp.SessionOptions = .{},
    /// Event Hubs expects an anonymous SASL layer and then CBS. Cleared for a
    /// peer that negotiates no SASL layer at all.
    sasl: amqp.connection_driver.SaslMode = .anonymous,
    factory: recovery.ConnectionFactory = .{ .openFn = open, .closeFn = close },

    fn open(f: *recovery.ConnectionFactory, deadline_ms: i64) anyerror!recovery.Plumbing {
        const self: *AmqpConnectionFactory = @fieldParentPtr("factory", f);
        const allocator = self.allocator;

        const generation = try allocator.create(Generation);
        errdefer allocator.destroy(generation);

        const user_agent = try self.options.userAgent(allocator);
        errdefer allocator.free(user_agent);

        const properties = try amqp.buildProperties(
            allocator,
            amqp.defaultClientInfo(sdk_version, user_agent),
        );
        errdefer allocator.free(properties);

        var socket: ?amqp.Socket = null;
        var web_socket: ?amqp.Transport = null;
        errdefer {
            if (socket) |s| s.deinit();
            if (web_socket) |s| {
                if (self.options.web_socket) |hook| hook.close(s);
            }
        }

        const stream = if (self.options.web_socket) |hook| blk: {
            const url = try self.options.webSocketUrl(allocator, self.fully_qualified_namespace);
            defer allocator.free(url);
            web_socket = try hook.connect(allocator, url);
            break :blk web_socket.?;
        } else blk: {
            socket = try amqp.connect(
                allocator,
                self.io orelse return error.MissingIo,
                self.options.endpointFor(self.fully_qualified_namespace),
                .{ .bundle = self.options.tls.bundle },
            );
            break :blk socket.?.transport();
        };

        var owned_clock: ?*amqp.IoClock = null;
        errdefer if (owned_clock) |c| allocator.destroy(c);
        const clock = self.clock orelse blk: {
            const io_clock = try allocator.create(amqp.IoClock);
            io_clock.* = .{ .io = self.io orelse return error.MissingIo };
            owned_clock = io_clock;
            break :blk io_clock.clock();
        };

        const driver = try allocator.create(amqp.Driver);
        errdefer allocator.destroy(driver);
        driver.* = try amqp.Driver.init(allocator, stream, clock, .{
            .container_id = self.container_id,
            // The virtual host is the namespace, never the custom endpoint:
            // it is what the service routes on.
            .hostname = self.fully_qualified_namespace,
            .properties = properties,
            .desired_capabilities = &desired_capabilities,
            .sasl = self.sasl,
        });
        errdefer driver.deinit();
        try driver.open(deadline_ms);

        const session = try allocator.create(amqp.Session);
        errdefer allocator.destroy(session);
        session.* = try amqp.Session.begin(allocator, driver, 0, self.session_options, deadline_ms);
        errdefer session.deinit();

        generation.* = .{
            .allocator = allocator,
            .socket = socket,
            .web_socket = web_socket,
            .hook = self.options.web_socket,
            .clock = owned_clock,
            .driver = driver,
            .session = session,
            .properties = properties,
            .user_agent = user_agent,
        };
        return .{ .context = generation, .session = session };
    }

    fn close(f: *recovery.ConnectionFactory, plumbing: recovery.Plumbing) void {
        _ = f;
        const generation: *Generation = @ptrCast(@alignCast(plumbing.context));
        generation.deinit();
    }
};

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const MemoryTransport = amqp.MemoryTransport;
const Peer = harness.Peer;

test "a custom endpoint moves the address but not the identity" {
    const fqdn = "ns.servicebus.windows.net";
    const options = ConnectionOptions{
        .custom_endpoint = .{ .host = "proxy.contoso.com", .port = 8443 },
    };

    const endpoint = options.endpointFor(fqdn);
    try testing.expectEqualStrings("proxy.contoso.com", endpoint.host);
    try testing.expectEqual(@as(u16, 8443), endpoint.port);
    try testing.expect(endpoint.tls);
    // The proxy presents the namespace's certificate, and tokens are issued
    // for the namespace. Validating against the proxy's own name would fail,
    // and would also accept a certificate for the wrong service.
    try testing.expectEqualStrings(fqdn, endpoint.serverName());
}

test "without a custom endpoint the namespace is dialled directly" {
    const fqdn = "ns.servicebus.windows.net";
    const endpoint = (ConnectionOptions{}).endpointFor(fqdn);
    try testing.expectEqualStrings(fqdn, endpoint.host);
    try testing.expectEqual(amqp.tls_port, endpoint.port);
    try testing.expect(endpoint.tls);
    try testing.expectEqualStrings(fqdn, endpoint.serverName());
}

test "the emulator is reached over plaintext on the AMQP port" {
    const endpoint = (ConnectionOptions{ .use_tls = false }).endpointFor("localhost");
    try testing.expect(!endpoint.tls);
    try testing.expectEqual(amqp.tcp_port, endpoint.port);
}

test "the application id leads the user agent" {
    const allocator = testing.allocator;

    const with_id = try (ConnectionOptions{ .application_id = "my-app/2.1" }).userAgent(allocator);
    defer allocator.free(with_id);
    try testing.expect(std.mem.startsWith(u8, with_id, "my-app/2.1 azsdk-zig-eventhubs/"));

    const without = try (ConnectionOptions{}).userAgent(allocator);
    defer allocator.free(without);
    try testing.expect(std.mem.startsWith(u8, without, "azsdk-zig-eventhubs/"));
}

test "the WebSocket URL names the namespace and the service bus path" {
    const allocator = testing.allocator;
    const url = try (ConnectionOptions{}).webSocketUrl(allocator, "ns.servicebus.windows.net");
    defer allocator.free(url);
    try testing.expectEqualStrings(
        "wss://ns.servicebus.windows.net/$servicebus/websocket",
        url,
    );
}

/// A hook that records its URL and hands back a scripted in-memory stream.
const FakeWebSocket = struct {
    mem: *MemoryTransport,
    url: ?[]u8 = null,
    allocator: Allocator,
    calls: usize = 0,

    fn deinit(self: *FakeWebSocket) void {
        if (self.url) |url| self.allocator.free(url);
    }

    fn hook(self: *FakeWebSocket) WebSocketHook {
        return .{ .context = self, .connectFn = connect };
    }

    fn connect(context: *anyopaque, allocator: Allocator, url: []const u8) anyerror!amqp.Transport {
        const self: *FakeWebSocket = @ptrCast(@alignCast(context));
        if (self.url) |old| self.allocator.free(old);
        self.url = try allocator.dupe(u8, url);
        self.calls += 1;
        return self.mem.transport();
    }
};

/// The `open` performative the client emitted, still borrowed from `mem`.
fn sentOpen(allocator: Allocator, mem: *MemoryTransport) !?[]const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) == amqp.performative.descriptor.open) return body;
    }
    return null;
}

fn propertyValue(properties: []const amqp.MapEntry, name: []const u8) ?[]const u8 {
    for (properties) |entry| {
        const key = switch (entry.key) {
            .symbol, .string => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, key, name)) return entry.value.string;
    }
    return null;
}

test "a WebSocket hook is given the namespace URL and its stream opens the connection" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    try harness.scriptHandshake(.{ .allocator = allocator, .mem = &mem }, 512);

    var socket = FakeWebSocket{ .mem = &mem, .allocator = allocator };
    defer socket.deinit();

    var clock: amqp.ManualClock = .{};
    var factory = AmqpConnectionFactory{
        .allocator = allocator,
        .clock = clock.clock(),
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .container_id = "container-1",
        .sasl = .none,
        .options = .{
            .application_id = "my-app",
            .web_socket = socket.hook(),
            // A custom endpoint must not reach the hook: the URL is derived
            // from the namespace, and the proxying is the caller's business.
            .custom_endpoint = .{ .host = "proxy.contoso.com", .port = 443 },
        },
    };

    const plumbing = try factory.factory.open(10_000);
    defer factory.factory.close(plumbing);

    try testing.expectEqual(@as(usize, 1), socket.calls);
    try testing.expectEqualStrings(
        "wss://ns.servicebus.windows.net/$servicebus/websocket",
        socket.url.?,
    );

    const body = (try sentOpen(allocator, &mem)).?;
    var decoded = try amqp.performative.decode(allocator, body);
    defer decoded.deinit();
    const open = decoded.performative.open;

    // The virtual host is what the service routes on, so it names the
    // namespace no matter which address carried the bytes.
    try testing.expectEqualStrings("ns.servicebus.windows.net", open.hostname.?);
    try testing.expectEqualStrings("container-1", open.container_id);

    const user_agent = propertyValue(open.properties.?, "user-agent").?;
    try testing.expect(std.mem.startsWith(u8, user_agent, "my-app azsdk-zig-eventhubs/"));
    try testing.expectEqualStrings("azure-sdk-for-zig", propertyValue(open.properties.?, "product").?);

    // Geo-replication is only reported to a connection that asked for it.
    const capabilities = open.desired_capabilities.?;
    try testing.expectEqual(@as(usize, 1), capabilities.len);
    try testing.expectEqualStrings(amqp.georeplication_capability, capabilities[0]);
}

test "the retry schedule comes from the client options" {
    var sleeper = errors.Sleeper{ .sleepFn = struct {
        fn noSleep(_: *errors.Sleeper, _: u64) error{Canceled}!void {}
    }.noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    const options = ConnectionOptions{ .retry_options = .{ .max_retries = 7 } };
    const config = options.retryConfig(&sleeper, prng.random());
    try testing.expectEqual(@as(u32, 7), config.options.max_retries);
}
