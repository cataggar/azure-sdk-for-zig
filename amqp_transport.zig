//! The AMQP transport that actually moves Service Bus messages.
//!
//! Replaces a stub that built a connection and a session per call and then
//! returned without attaching a link, issuing credit, or transferring
//! anything. Everything below the message codec — dialling, the SASL and CBS
//! handshakes, link attachment, credit, and settlement — is
//! `azure_sdk_amqp`'s; this is the Service Bus-shaped wiring over it.
//!
//! What it holds across calls is the point of it. A connection, a session,
//! the `$cbs` link pair, one sender link per entity, and the encode buffer
//! are all built once and reused, so the steady-state cost of a send is a
//! transfer frame and nothing else. The stub's per-call connection was three
//! round trips of handshake before the first byte of payload.
//!
//! Not here yet: receive and settlement (`receiveMessages`, `settleMessage`)
//! and the management operations (`scheduleMessage`, `cancelScheduled`).
//! They report `error.NotImplemented` rather than succeeding silently.

const std = @import("std");
const builtin = @import("builtin");
const core = @import("azure_sdk_core");
const messaging_common = @import("azure_sdk_messaging_common");
const amqp = @import("azure_sdk_amqp");
const sb = @import("root.zig");
const message_codec = @import("message.zig");

const Allocator = std.mem.Allocator;

/// Version reported to the service in the `open` properties.
pub const sdk_version = "0.1.0";

/// The product half of the user agent, matching the other SDKs' shape.
pub const user_agent_product = "azsdk-zig-servicebus";

/// AAD scope for Service Bus data-plane access.
pub const token_scope = "https://servicebus.azure.net/.default";

/// Path Service Bus serves AMQP-over-WebSockets on. Present for the audience
/// and URL shapes; this package dials TCP or TLS directly.
pub const web_socket_path = "/$servicebus/websocket";

// ─────────────────────── Credentials ───────────────────────

/// How the client proves who it is.
pub const Credential = union(enum) {
    /// An AAD credential. The caller owns it and must outlive the client.
    token: *core.credentials.TokenCredential,
    /// Built from a connection string and owned by the transport.
    sas: messaging_common.SasCredential,

    /// Resolve to the abstract credential. Takes a pointer so the SAS case
    /// hands out an address that stays valid.
    pub fn tokenCredential(self: *Credential) *core.credentials.TokenCredential {
        return switch (self.*) {
            .token => |c| c,
            .sas => |*sas| sas.asCredential(),
        };
    }

    /// The CBS token type the broker expects for this credential.
    pub fn cbsTokenType(self: Credential) amqp.CbsTokenType {
        return switch (self) {
            .token => .jwt,
            .sas => .sas,
        };
    }

    /// Whether a new token can be minted once the current one expires. A
    /// pre-formed signature from a connection string cannot be re-signed.
    pub fn isRefreshable(self: Credential) bool {
        return switch (self) {
            .token => true,
            .sas => |sas| sas.isRefreshable(),
        };
    }

    pub fn getToken(self: *Credential, ctx: core.context.Context) !core.credentials.AccessToken {
        return self.tokenCredential().getToken(.{ .scopes = &.{token_scope} }, ctx);
    }
};

/// Bridges a Service Bus `Credential` to the AMQP layer's `TokenProvider`.
///
/// `TokenProvider.getToken` hands back a borrowed slice and gives the
/// provider nowhere to release what backed it, while `Cbs.authorize` dupes
/// whatever it decides to keep. So the last token minted is held here and
/// released on the next mint or at `deinit` — the shortest lifetime that
/// still outlives the borrow.
const TokenSource = struct {
    credential: *Credential,
    ctx: core.context.Context = .none,
    held: ?core.credentials.AccessToken = null,

    fn provider(self: *TokenSource) amqp.TokenProvider {
        return .{ .ctx = self, .getTokenFn = getToken };
    }

    fn getToken(ctx: *anyopaque, audience: []const u8) anyerror!amqp.AccessToken {
        const self: *TokenSource = @ptrCast(@alignCast(ctx));
        // The SAS case signs the audience it was constructed with and ignores
        // this one; the AAD case authorises the whole namespace by scope.
        _ = audience;

        self.release();
        var token = try self.credential.getToken(self.ctx);
        errdefer token.deinit();
        self.held = token;

        return .{
            .token = token.token,
            .expires_on_ms = token.expires_on * std.time.ms_per_s,
            .kind = self.credential.cbsTokenType(),
            .refreshable = self.credential.isRefreshable(),
        };
    }

    fn release(self: *TokenSource) void {
        if (self.held) |*token| token.deinit();
        self.held = null;
    }
};

// ─────────────────────── Options ───────────────────────

/// Somewhere other than the namespace to dial.
///
/// The namespace stays the TLS server name and the CBS audience: a proxy
/// fronting the service presents the *namespace's* certificate, and tokens
/// are issued for the namespace whichever address carried the bytes.
pub const CustomEndpoint = struct {
    host: []const u8,
    port: u16 = amqp.tls_port,
};

pub const TlsSettings = struct {
    /// Certificate bundle to validate against. Null rescans the system trust
    /// store on every dial, so a long-lived client should hoist one out.
    /// Supplying a bundle is also how a self-signed root gets trusted.
    bundle: ?*std.crypto.Certificate.Bundle = null,
};

pub const ConnectionOptions = struct {
    /// Prefixed to the user agent so the service can attribute traffic to the
    /// calling application. Borrowed; must outlive the transport.
    application_id: ?[]const u8 = null,
    /// Dial here instead of the namespace.
    custom_endpoint: ?CustomEndpoint = null,
    tls: TlsSettings = .{},
    /// Cleared for the emulator, which speaks plaintext AMQP.
    use_tls: bool = true,
    /// Identifies this connection to the service.
    container_id: []const u8 = "azure-sdk-for-zig",
    /// Distinguishes this client's links from any other on the connection.
    link_id: []const u8 = "servicebus",
    /// How many messages a sender may have on the wire unconfirmed.
    ///
    /// One means every send waits a full round trip before the next goes out,
    /// which caps a link at one message per round trip however small the
    /// messages are. This is what lets `sendMessages` overlap them.
    max_in_flight: u32 = 20,
    /// How long any one operation may take.
    deadline_ms: i64 = 60_000,
    session: amqp.SessionOptions = .{},
    /// Service Bus expects an anonymous SASL layer and then CBS. Cleared for
    /// a peer that negotiates no SASL layer at all.
    sasl: amqp.connection_driver.SaslMode = .anonymous,

    /// Where to dial and whose certificate to demand.
    ///
    /// A custom endpoint replaces the address only, so SNI and hostname
    /// verification still name the namespace.
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
    /// The application id leads so it survives any truncation the service
    /// applies, matching azcore's ordering.
    pub fn userAgent(self: ConnectionOptions, allocator: Allocator) Allocator.Error![]u8 {
        const platform = @tagName(builtin.os.tag);
        if (self.application_id) |id| {
            return std.fmt.allocPrint(allocator, "{s} {s}/{s} ({s})", .{
                id, user_agent_product, sdk_version, platform,
            });
        }
        return std.fmt.allocPrint(allocator, "{s}/{s} ({s})", .{
            user_agent_product, sdk_version, platform,
        });
    }
};

/// The audience a token is requested for, and the CBS name it is put under.
///
/// `messaging_common.audienceFor` always writes `amqps://`, but the emulator
/// serves plaintext AMQP, so the scheme is a parameter here — matching Event
/// Hubs, which carries the same helper for the same reason. Caller owns the
/// result.
fn audienceFor(
    allocator: Allocator,
    scheme: []const u8,
    fully_qualified_namespace: []const u8,
    entity: ?[]const u8,
) Allocator.Error![]u8 {
    if (entity) |path| {
        if (path.len > 0) {
            return std.fmt.allocPrint(allocator, "{s}://{s}/{s}", .{ scheme, fully_qualified_namespace, path });
        }
    }
    return std.fmt.allocPrint(allocator, "{s}://{s}/", .{ scheme, fully_qualified_namespace });
}

/// Wall-clock milliseconds since the Unix epoch.
fn wallClockMs() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const ts = std.Io.Timestamp.now(threaded.io(), .real);
    return @intCast(@divTrunc(ts.nanoseconds, std.time.ns_per_ms));
}

// ─────────────────────── The connection ───────────────────────

/// Everything one dialled connection owns, so it can be dropped whole.
const Generation = struct {
    allocator: Allocator,
    socket: ?amqp.Socket,
    clock: *amqp.IoClock,
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
        self.allocator.destroy(self.clock);
        self.allocator.free(self.properties);
        self.allocator.free(self.user_agent);
        self.allocator.destroy(self);
    }
};

/// One entity's sender link, with the audience its claim is put under.
///
/// The audience is derived from the entity and never changes, so it is built
/// once with the link rather than reformatted on every send.
const EntityLink = struct {
    sender: *amqp.Sender,
    audience: []u8,
};

/// A real Service Bus AMQP transport.
///
/// Holds interior pointers — the vtable it hands out points back at itself —
/// so initialise it in place and never copy it afterwards.
pub const AmqpTransport = struct {
    allocator: Allocator,
    /// Required to dial. Unused when a session is supplied instead.
    io: ?std.Io = null,
    fully_qualified_namespace: []const u8,
    credential: Credential,
    options: ConnectionOptions = .{},
    /// The AMQP URI scheme audiences are written with. Plaintext only for the
    /// emulator, which has no TLS to name.
    scheme: []const u8 = "amqps",

    /// Set once dialled. Null until the first operation needs the wire.
    generation: ?*Generation = null,
    /// A session to use instead of dialling, for a caller driving a scripted
    /// peer. Borrowed, never closed here.
    borrowed_session: ?*amqp.Session = null,

    cbs: ?*amqp.Cbs = null,
    token_source: TokenSource = undefined,
    /// Sender links by entity. Keys and everything in the value are owned.
    senders: std.StringHashMapUnmanaged(EntityLink) = .empty,
    /// Reused across every send, so encoding amortises to no allocation.
    encode_buf: amqp.encoder.Buffer = undefined,
    scratch: message_codec.Scratch = undefined,
    /// Wall-clock milliseconds, for deciding whether a cached CBS token has
    /// gone stale. Separate from the driver's clock, which is monotonic and
    /// says nothing about a token's Unix expiry. Injected so a test can pin
    /// it.
    nowMsFn: *const fn () i64 = wallClockMs,
    /// The audience string `initFromConnectionString` allocated, if any.
    owned_audience: ?[]u8 = null,

    transport: sb.ServiceBusAmqpTransport = .{
        .sendMessagesFn = sendMessagesImpl,
        .receiveMessagesFn = receiveMessagesImpl,
        .settleMessageFn = settleMessageImpl,
        .scheduleMessageFn = scheduleMessageImpl,
        .cancelScheduledFn = cancelScheduledImpl,
        .closeFn = closeImpl,
    },

    pub const Options = struct {
        allocator: Allocator,
        io: ?std.Io = null,
        fully_qualified_namespace: []const u8,
        credential: Credential,
        connection: ConnectionOptions = .{},
        /// Use this session rather than dialling. The caller keeps it.
        session: ?*amqp.Session = null,
    };

    /// Initialise in place. Nothing dials until the first operation runs.
    pub fn init(self: *AmqpTransport, options: Options) void {
        self.* = .{
            .allocator = options.allocator,
            .io = options.io,
            .fully_qualified_namespace = options.fully_qualified_namespace,
            .credential = options.credential,
            .options = options.connection,
            .borrowed_session = options.session,
        };
        self.encode_buf = amqp.encoder.Buffer.initDynamic(options.allocator);
        self.scratch = .init(options.allocator);
        self.token_source = .{ .credential = &self.credential };
    }

    /// Initialise from a connection string, parsing it exactly once.
    ///
    /// The parsed properties borrow from `connection_string`, and the SAS
    /// credential built here borrows from those, so the string must outlive
    /// the transport. `audience` is owned by the transport.
    ///
    /// Returns the entity path the string named, if any, so a client can
    /// default to it without parsing the string a second time.
    pub fn initFromConnectionString(
        self: *AmqpTransport,
        allocator: Allocator,
        io: ?std.Io,
        connection_string: []const u8,
        options: ConnectionOptions,
    ) !?[]const u8 {
        const properties = try sb.ConnectionStringProperties.parse(connection_string);

        // A namespace-scoped signature authorises every entity beneath it,
        // because the broker prefix-matches the token's resource against the
        // audience a link asks for. So the signature is scoped to whatever
        // the connection string named and the per-entity audience is still
        // what goes to `$cbs`.
        const audience = try audienceFor(
            allocator,
            properties.scheme(),
            properties.fully_qualified_namespace,
            properties.entity_path,
        );
        errdefer allocator.free(audience);

        const sas = try messaging_common.SasCredential.initFromConnectionString(
            allocator,
            properties,
            audience,
        );

        var connection = options;
        // The emulator serves plaintext AMQP and has no certificate.
        if (properties.emulator) connection.use_tls = false;
        const scheme = properties.scheme();

        self.init(.{
            .allocator = allocator,
            .io = io,
            .fully_qualified_namespace = properties.fully_qualified_namespace,
            .credential = .{ .sas = sas },
            .connection = connection,
        });
        self.owned_audience = audience;
        self.scheme = scheme;
        return properties.entity_path;
    }

    pub fn asTransport(self: *AmqpTransport) *sb.ServiceBusAmqpTransport {
        return &self.transport;
    }

    pub fn deinit(self: *AmqpTransport) void {
        self.closeLinks();
        if (self.generation) |generation| generation.deinit();
        self.generation = null;
        self.token_source.release();
        self.encode_buf.deinit();
        self.scratch.deinit();
        if (self.owned_audience) |audience| self.allocator.free(audience);
        self.owned_audience = null;
    }

    /// When an operation started now must give up.
    ///
    /// Taken from the driver's clock rather than the wall clock: it is what
    /// the session and link code compare against, so any other source would
    /// produce a deadline that never arrives or has already passed.
    fn deadlineFrom(self: *AmqpTransport, current: *amqp.Session) i64 {
        return current.driver.clock.nowMillis() +| self.options.deadline_ms;
    }

    /// The session links are attached to, if one exists yet.
    fn currentSession(self: *AmqpTransport) ?*amqp.Session {
        if (self.borrowed_session) |s| return s;
        if (self.generation) |generation| return generation.session;
        return null;
    }

    /// Detach every link and drop the `$cbs` client, leaving the connection.
    ///
    /// Links go back through `Session.closeSender`, which detaches, drops the
    /// link from the session's list, *and* frees it. Detaching and freeing
    /// directly leaves the session still holding the pointer, and its own
    /// `deinit` then frees it a second time.
    fn closeLinks(self: *AmqpTransport) void {
        if (self.currentSession()) |current| {
            var it = self.senders.iterator();
            while (it.next()) |entry| {
                current.closeSender(entry.value_ptr.sender, 0);
                self.allocator.free(entry.value_ptr.audience);
                self.allocator.free(entry.key_ptr.*);
            }
        }
        self.senders.deinit(self.allocator);
        self.senders = .empty;

        if (self.cbs) |cbs| {
            cbs.close(0) catch {};
            cbs.deinit();
        }
        self.cbs = null;
    }

    /// The session to attach links to, dialling if this is the first use.
    fn session(self: *AmqpTransport) !*amqp.Session {
        if (self.borrowed_session) |s| return s;
        if (self.generation) |generation| return generation.session;

        const allocator = self.allocator;
        const io = self.io orelse return error.MissingIo;

        const generation = try allocator.create(Generation);
        errdefer allocator.destroy(generation);

        // The clock leads, because the deadline for the dial itself has to
        // be measured on the same clock the driver will later compare
        // against.
        const clock = try allocator.create(amqp.IoClock);
        errdefer allocator.destroy(clock);
        clock.* = .{ .io = io };
        const deadline_ms = clock.clock().nowMillis() +| self.options.deadline_ms;

        const user_agent = try self.options.userAgent(allocator);
        errdefer allocator.free(user_agent);

        const properties = try amqp.buildProperties(
            allocator,
            amqp.defaultClientInfo(sdk_version, user_agent),
        );
        errdefer allocator.free(properties);

        const socket = try amqp.connect(
            allocator,
            io,
            self.options.endpointFor(self.fully_qualified_namespace),
            .{ .bundle = self.options.tls.bundle },
        );
        errdefer socket.deinit();

        const driver = try allocator.create(amqp.Driver);
        errdefer allocator.destroy(driver);
        driver.* = try amqp.Driver.init(allocator, socket.transport(), clock.clock(), .{
            .container_id = self.options.container_id,
            // The virtual host is the namespace, never the custom endpoint:
            // it is what the service routes on.
            .hostname = self.fully_qualified_namespace,
            .properties = properties,
            .sasl = self.options.sasl,
        });
        errdefer driver.deinit();
        try driver.open(deadline_ms);

        const begun = try allocator.create(amqp.Session);
        errdefer allocator.destroy(begun);
        begun.* = try amqp.Session.begin(allocator, driver, 0, self.options.session, deadline_ms);
        errdefer begun.deinit();

        generation.* = .{
            .allocator = allocator,
            .socket = socket,
            .clock = clock,
            .driver = driver,
            .session = begun,
            .properties = properties,
            .user_agent = user_agent,
        };
        self.generation = generation;
        return begun;
    }

    /// Put a CBS token for `entity`'s audience, unless a live one is cached.
    ///
    /// Called before every operation, not only when a link is attached. A
    /// claim expires while its link stays attached — after which the broker
    /// detaches it — so binding renewal to attachment would authorise a
    /// long-lived sender exactly once and let it die an hour later.
    /// `Cbs.authorize` owns the caching, so the usual cost is a hash lookup
    /// rather than a round trip.
    fn authorize(
        self: *AmqpTransport,
        current: *amqp.Session,
        audience: []const u8,
        deadline_ms: i64,
    ) !void {
        const cbs = self.cbs orelse blk: {
            const opened = try amqp.Cbs.open(current, .{ .link_id = self.options.link_id }, deadline_ms);
            self.cbs = opened;
            break :blk opened;
        };

        try cbs.authorize(audience, self.token_source.provider(), self.nowMsFn(), deadline_ms);
    }

    /// The authorised sender link for `entity`, attaching on first use and
    /// re-attaching one the broker has detached.
    ///
    /// A cached link cannot be handed back unchecked. The broker detaches a
    /// sender for ordinary reasons — a claim that lapsed before its renewal
    /// landed, an entity disabled or moved — and §2.6.1 unbinds the handle
    /// when it does. Writing a transfer on an unbound handle is
    /// `amqp:session:unattached-handle`, which ends the *session* and so
    /// takes down every other entity's link with it.
    fn senderFor(
        self: *AmqpTransport,
        current: *amqp.Session,
        entity: []const u8,
        deadline_ms: i64,
    ) !*amqp.Sender {
        if (self.senders.getPtr(entity)) |existing| {
            if (existing.sender.attached) {
                try self.authorize(current, existing.audience, deadline_ms);
                return existing.sender;
            }
            self.dropSender(current, entity);
        }

        const audience = try audienceFor(
            self.allocator,
            self.scheme,
            self.fully_qualified_namespace,
            entity,
        );
        errdefer self.allocator.free(audience);

        // Before the attach, not after: the broker refuses to attach a link
        // whose audience has no live claim.
        try self.authorize(current, audience, deadline_ms);

        const name = try std.fmt.allocPrint(
            self.allocator,
            "{s}-sender-{s}",
            .{ self.options.link_id, entity },
        );
        defer self.allocator.free(name);

        const sender = try amqp.openSender(current, .{
            .name = name,
            .target_address = entity,
            .max_in_flight = self.options.max_in_flight,
        }, deadline_ms);
        errdefer current.closeSender(sender, 0);

        const key = try self.allocator.dupe(u8, entity);
        errdefer self.allocator.free(key);
        try self.senders.put(self.allocator, key, .{ .sender = sender, .audience = audience });
        return sender;
    }

    /// Forget `entity`'s link, releasing everything the entry owned.
    fn dropSender(self: *AmqpTransport, current: *amqp.Session, entity: []const u8) void {
        const removed = self.senders.fetchRemove(entity) orelse return;
        current.closeSender(removed.value.sender, 0);
        self.allocator.free(removed.value.audience);
        self.allocator.free(removed.key);
    }

    /// Wait for the oldest delivery and map its outcome the way a
    /// one-at-a-time `sendBytes` would.
    fn awaitOne(sender: *amqp.Sender, deadline_ms: i64) !void {
        const settlement = try sender.awaitSettlement(deadline_ms);
        switch (settlement.outcome) {
            .accepted => {},
            .rejected => return error.SendRejected,
            .released, .modified => return error.SendNotAccepted,
        }
    }

    /// Encode and send every message, keeping up to `max_in_flight` of them
    /// on the wire at once.
    pub fn sendMessages(
        self: *AmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        messages: []const sb.ServiceBusMessage,
    ) !void {
        if (messages.len == 0) return;

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);
        const sender = try self.senderFor(current, entity, deadline_ms);
        const window = @max(self.options.max_in_flight, 1);

        // A send that fails partway leaves deliveries written but unsettled.
        // Left in the ring they would wedge the link: the next send would
        // find the window full and wait for verdicts that never come.
        errdefer sender.abandonInFlight();

        var in_flight: u32 = 0;
        for (messages) |message| {
            if (in_flight == window) {
                try awaitOne(sender, deadline_ms);
                in_flight -= 1;
            }

            // One buffer for the whole loop. `sendBytesAsync` writes every
            // frame before it returns, so the bytes are on the wire and the
            // buffer is free to be overwritten by the next message.
            self.encode_buf.reset();
            const amqp_message = try message_codec.toAmqpMessage(message, &self.scratch);
            try amqp.message_codec.encode(allocator, amqp_message, &self.encode_buf);

            _ = try sender.sendBytesAsync(self.encode_buf.written(), .{}, deadline_ms);
            in_flight += 1;
        }

        while (in_flight > 0) : (in_flight -= 1) try awaitOne(sender, deadline_ms);
    }

    // ── vtable ──

    fn sendMessagesImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        messages: []const sb.ServiceBusMessage,
    ) anyerror!void {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.sendMessages(allocator, entity, messages);
    }

    fn receiveMessagesImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        max_count: u32,
        mode: sb.ReceiveMode,
    ) anyerror![]sb.ServiceBusReceivedMessage {
        _ = .{ t, allocator, entity, max_count, mode };
        return error.NotImplemented;
    }

    fn settleMessageImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        delivery_tag: []const u8,
        action: sb.DispositionAction,
        reason: ?[]const u8,
    ) anyerror!void {
        _ = .{ t, allocator, delivery_tag, action, reason };
        return error.NotImplemented;
    }

    fn scheduleMessageImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        message: sb.ServiceBusMessage,
        enqueue_time: i64,
    ) anyerror!i64 {
        _ = .{ t, allocator, entity, message, enqueue_time };
        return error.NotImplemented;
    }

    fn cancelScheduledImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        sequence_number: i64,
    ) anyerror!void {
        _ = .{ t, allocator, entity, sequence_number };
        return error.NotImplemented;
    }

    fn closeImpl(t: *sb.ServiceBusAmqpTransport) void {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        self.closeLinks();
        if (self.generation) |generation| generation.deinit();
        self.generation = null;
    }
};

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const MemoryTransport = amqp.MemoryTransport;
const Peer = harness.Peer;

/// The stock fixture pins `max_frame_size` to 512, which makes any message
/// over a few hundred bytes multi-frame and is not what a broker offers.
const peer_options = amqp.DriverOptions{
    .container_id = "test-container",
    .hostname = "ns.servicebus.windows.net",
    .sasl = .none,
    .max_frame_size = 65536,
    .idle_timeout_ms = 0,
};

const max_frame_size = 65536;

/// The wall clock every test runs on, so a cached token's staleness is decided
/// by the test rather than by today's date. Well before `StubCredential`'s
/// expiry, so a token starts out live.
var test_now_ms: i64 = stub_token_expires_on * std.time.ms_per_s - 3_600_000;

fn testNowMs() i64 {
    return test_now_ms;
}

const stub_token_expires_on: i64 = 1_700_000_000;

/// A credential handing out a fixed token, counting how often it was asked.
const StubCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = get },
    calls: usize = 0,

    fn get(
        c: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        ctx: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        _ = .{ request_context, ctx };
        const self: *StubCredential = @alignCast(@fieldParentPtr("credential", c));
        self.calls += 1;
        // Borrowed, so `deinit` frees nothing — the transport must not assume
        // otherwise.
        return .{ .token = "stub-jwt", .expires_on = stub_token_expires_on };
    }
};

/// A credential whose token owns its bytes, as the shared-key signer's does.
///
/// `StubCredential` hands back a literal, so `AccessToken.deinit` is a no-op
/// against it and the release path in `TokenSource` goes unexercised. A real
/// SAS credential mints a fresh signature on every call, and failing to
/// release it would leak one per claim renewal — forever, on a long-lived
/// client.
const OwningStubCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = get },
    allocator: Allocator,
    calls: usize = 0,

    fn get(
        c: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        ctx: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        _ = .{ request_context, ctx };
        const self: *OwningStubCredential = @alignCast(@fieldParentPtr("credential", c));
        self.calls += 1;
        return .{
            .token = try self.allocator.dupe(u8, "minted-sas-signature"),
            .expires_on = stub_token_expires_on,
            .allocator = self.allocator,
        };
    }
};

/// Script the peer's side of the CBS link pair and its put-token reply.
///
/// `Cbs.open` takes handles 0 and 1, so the first entity link is handle 2.
fn scriptCbsExchange(peer: Peer, allocator: Allocator) !void {
    try harness.scriptHandshake(peer, max_frame_size);
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-sender-servicebus",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-receiver-servicebus",
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
        .link_credit = 10,
    } });

    // The put-token request is delivery 0, and the broker settles it before
    // the reply lands on the receiver link.
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });
    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
        .{ .key = .{ .string = "statusDescription" }, .value = .{ .string = "Accepted" } },
    };
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = "cbs-reply-to-servicebus:1" } },
        .application_properties = &props,
    });
    defer allocator.free(reply);
    try peer.pushTransfer(0, .{
        .handle = 1,
        .delivery_id = 0,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
}

/// Script the attach and credit for an entity sender on `handle`.
fn scriptSenderAttach(peer: Peer, handle: u32, name: []const u8, credit: u32) !void {
    try peer.push(0, .{ .attach = .{
        .name = name,
        .handle = handle,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = handle,
        .delivery_count = 0,
        .link_credit = credit,
    } });
}

/// Accept delivery ids `first`..`last` inclusive.
fn scriptAccept(peer: Peer, first: u32, last: u32) !void {
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = first,
        .last = last,
        .settled = true,
        .state = .accepted,
    } });
}

/// Reject delivery ids `first`..`last` inclusive.
fn scriptReject(peer: Peer, first: u32, last: u32) !void {
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = first,
        .last = last,
        .settled = true,
        .state = .{ .rejected = null },
    } });
}

/// Every transfer body the client emitted.
fn emittedTransfers(allocator: Allocator, written: []const u8) ![]const []const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, written);
    defer frames.deinit();
    return frames.of(allocator, 0x14);
}

/// Every attach body the client emitted.
fn emittedAttaches(allocator: Allocator, written: []const u8) ![]const []const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, written);
    defer frames.deinit();
    return frames.of(allocator, 0x12);
}

/// A transport wired to a scripted peer, with everything it borrows.
const Harness = struct {
    allocator: Allocator,
    io_allocator: Allocator,
    mem: *MemoryTransport,
    clock: *amqp.ManualClock,
    driver: *amqp.Driver,
    session: *amqp.Session,
    credential: *StubCredential,
    transport: *AmqpTransport,

    fn init(allocator: Allocator) !Harness {
        return initSplit(allocator, allocator);
    }

    /// `io_allocator` backs the in-memory socket's own buffers, which grow
    /// with the number of bytes the peer exchanges rather than with anything
    /// the client decides. A measurement passes an uncounted allocator here,
    /// so the harness's bookkeeping stays out of the client's cost.
    fn initSplit(allocator: Allocator, io_allocator: Allocator) !Harness {
        test_now_ms = stub_token_expires_on * std.time.ms_per_s - 3_600_000;
        const mem = try io_allocator.create(MemoryTransport);
        mem.* = MemoryTransport.init(io_allocator);
        const clock = try allocator.create(amqp.ManualClock);
        clock.* = .{};
        const driver = try allocator.create(amqp.Driver);
        const session = try allocator.create(amqp.Session);
        const credential = try allocator.create(StubCredential);
        credential.* = .{};
        const transport = try allocator.create(AmqpTransport);
        return .{
            .allocator = allocator,
            .io_allocator = io_allocator,
            .mem = mem,
            .clock = clock,
            .driver = driver,
            .session = session,
            .credential = credential,
            .transport = transport,
        };
    }

    fn peer(self: Harness) Peer {
        return .{ .allocator = self.allocator, .mem = self.mem };
    }

    /// Open the driver and session against the already-scripted peer, then
    /// point a transport at that session.
    fn start(self: *Harness, options: ConnectionOptions) !void {
        self.driver.* = try amqp.Driver.init(
            self.allocator,
            self.mem.transport(),
            self.clock.clock(),
            peer_options,
        );
        try self.driver.open(10_000);
        self.session.* = try amqp.Session.begin(self.allocator, self.driver, 0, .{
            .incoming_window = 1000,
            .outgoing_window = 1000,
        }, 10_000);
        self.transport.init(.{
            .allocator = self.allocator,
            .fully_qualified_namespace = "ns.servicebus.windows.net",
            .credential = .{ .token = &self.credential.credential },
            .connection = options,
            .session = self.session,
        });
        self.transport.nowMsFn = testNowMs;
    }

    fn deinit(self: *Harness) void {
        self.transport.deinit();
        self.session.deinit();
        self.driver.deinit();
        self.mem.deinit();
        self.allocator.destroy(self.transport);
        self.allocator.destroy(self.credential);
        self.allocator.destroy(self.session);
        self.allocator.destroy(self.driver);
        self.allocator.destroy(self.clock);
        self.io_allocator.destroy(self.mem);
    }
};

/// Perform the first send, so the CBS exchange and the entity attach are
/// behind us and a later assertion sees only the traffic it is about.
fn warmUp(h: *Harness, allocator: Allocator, entity: []const u8) !void {
    var msg = sb.ServiceBusMessage.init(allocator, "warm");
    defer msg.deinit();
    try h.transport.sendMessages(allocator, entity, &.{msg});
    h.mem.clearWritten();
}

/// The value of application property `key` on a decoded message.
fn propertyOf(msg: amqp.Message, key: []const u8) ?amqp.AmqpValue {
    return message_codec.applicationPropertyOf(msg.application_properties, key);
}

test "a send authorises the entity before it puts the message on the wire" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    // The entity message is delivery 1: the put-token took delivery 0.
    try scriptAccept(h.peer(), 1, 1);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "order-42");
    defer msg.deinit();
    msg.message_id = "m-42";
    msg.session_id = "s-1";

    h.mem.clearWritten();
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    // Two, in this order: the broker rejects a link attached without a claim,
    // so the CBS put-token has to precede the message.
    try testing.expectEqual(@as(usize, 2), transfers.len);

    var claim = try amqp.decodeMessage(allocator, harness.transferPayload(allocator, transfers[0]).?);
    defer claim.deinit();
    try testing.expectEqualStrings("put-token", propertyOf(claim.message, "operation").?.string);
    try testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/orders",
        propertyOf(claim.message, "name").?.string,
    );
    try testing.expectEqualStrings("stub-jwt", claim.message.body.value.string);

    var decoded = try amqp.decodeMessage(allocator, harness.transferPayload(allocator, transfers[1]).?);
    defer decoded.deinit();

    const got = message_codec.fromAmqpMessage(decoded.message);
    try testing.expectEqualStrings("order-42", got.body);
    try testing.expectEqualStrings("m-42", got.message_id.?);
    try testing.expectEqualStrings("s-1", got.session_id.?);
}

test "the sender link is attached once and reused across sends" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);
    try scriptAccept(h.peer(), 2, 2);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();

    try h.transport.sendMessages(allocator, "orders", &.{msg});
    h.mem.clearWritten();
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    // The second send reuses the cached link, so it re-attaches nothing and
    // re-authorises nothing: one transfer and no attach.
    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);

    // And the credential was consulted once, not once per send: `Cbs`
    // caches the claim for the audience.
    try testing.expectEqual(@as(usize, 1), h.credential.calls);
}

test "a batch is pipelined rather than sent one round trip at a time" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 20);
    try scriptAccept(h.peer(), 1, 1);
    // One disposition covering all four, which a broker can only send if all
    // four transfers reached it before any outcome came back.
    try scriptAccept(h.peer(), 2, 5);

    try h.start(.{ .max_in_flight = 4 });
    try warmUp(&h, allocator, "orders");

    var msg = sb.ServiceBusMessage.init(allocator, "batched");
    defer msg.deinit();
    const batch = [_]sb.ServiceBusMessage{ msg, msg, msg, msg };

    try h.transport.sendMessages(allocator, "orders", &batch);

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 4), transfers.len);
}

test "a window of one still sends every message, one round trip each" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 20);
    try scriptAccept(h.peer(), 1, 1);
    try scriptAccept(h.peer(), 2, 2);
    try scriptAccept(h.peer(), 3, 3);
    try scriptAccept(h.peer(), 4, 4);

    try h.start(.{ .max_in_flight = 1 });
    try warmUp(&h, allocator, "orders");

    var msg = sb.ServiceBusMessage.init(allocator, "serial");
    defer msg.deinit();
    const batch = [_]sb.ServiceBusMessage{ msg, msg, msg };

    try h.transport.sendMessages(allocator, "orders", &batch);

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 3), transfers.len);
}

test "a rejected delivery is an error and leaves the link usable" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try h.peer().push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 1,
        .last = 1,
        .settled = true,
        .state = .{ .rejected = null },
    } });
    try scriptAccept(h.peer(), 2, 2);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "refused");
    defer msg.deinit();

    try testing.expectError(
        error.SendRejected,
        h.transport.sendMessages(allocator, "orders", &.{msg}),
    );

    // `awaitSettlement` retires the only entry before it reports the refusal,
    // so this holds however the transport behaves — it records the state, it
    // does not test it. The abandon path is tested where a *batch* fails
    // partway and entries really are left behind.
    try testing.expectEqual(@as(usize, 0), h.transport.senders.get("orders").?.sender.inFlight());

    // What this does test: a refusal is the message's verdict, not the link's,
    // so the next send goes out on the same link.
    try h.transport.sendMessages(allocator, "orders", &.{msg});
}

test "each entity gets its own link and its own claim" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);
    // The second entity authorises first — delivery 2 is its put-token — and
    // then attaches on handle 3.
    try h.peer().push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 2,
        .last = 2,
        .settled = true,
        .state = .accepted,
    } });
    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
    };
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = "cbs-reply-to-servicebus:2" } },
        .application_properties = &props,
    });
    defer allocator.free(reply);
    try h.peer().pushTransfer(0, .{
        .handle = 1,
        .delivery_id = 1,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
    try scriptSenderAttach(h.peer(), 3, "servicebus-sender-invoices", 10);
    try scriptAccept(h.peer(), 3, 3);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();

    try h.transport.sendMessages(allocator, "orders", &.{msg});
    try h.transport.sendMessages(allocator, "invoices", &.{msg});

    try testing.expectEqual(@as(usize, 2), h.transport.senders.count());
    // A distinct audience is a distinct claim, so the credential is asked
    // again rather than the first entity's token being reused.
    try testing.expectEqual(@as(usize, 2), h.credential.calls);
}

test "an empty send does not attach a link" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try harness.scriptHandshake(h.peer(), max_frame_size);
    try h.start(.{});

    h.mem.clearWritten();
    try h.transport.sendMessages(allocator, "orders", &.{});

    try testing.expectEqual(@as(usize, 0), h.transport.senders.count());
    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);
}

test "a custom endpoint moves the address but not the identity" {
    const fqdn = "ns.servicebus.windows.net";
    const options = ConnectionOptions{
        .custom_endpoint = .{ .host = "proxy.contoso.com", .port = 8443 },
    };

    const endpoint = options.endpointFor(fqdn);
    try testing.expectEqualStrings("proxy.contoso.com", endpoint.host);
    try testing.expectEqual(@as(u16, 8443), endpoint.port);
    // The proxy presents the namespace's certificate and tokens are issued
    // for the namespace, so validating against the proxy's own name would
    // both fail and accept a certificate for the wrong service.
    try testing.expectEqualStrings(fqdn, endpoint.serverName());
}

test "clearing TLS dials the plaintext port, for the emulator" {
    const options = ConnectionOptions{ .use_tls = false };
    const endpoint = options.endpointFor("localhost");
    try testing.expect(!endpoint.tls);
    try testing.expectEqual(amqp.tcp_port, endpoint.port);
}

test "the user agent leads with the application id when there is one" {
    const allocator = testing.allocator;

    const plain = try (ConnectionOptions{}).userAgent(allocator);
    defer allocator.free(plain);
    try testing.expect(std.mem.startsWith(u8, plain, "azsdk-zig-servicebus/"));

    const tagged = try (ConnectionOptions{ .application_id = "contoso-app" }).userAgent(allocator);
    defer allocator.free(tagged);
    try testing.expect(std.mem.startsWith(u8, tagged, "contoso-app azsdk-zig-servicebus/"));
}

test "a connection string is parsed once and yields its entity path" {
    const allocator = testing.allocator;
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=root;" ++
        "SharedAccessKey=c2VjcmV0;EntityPath=orders";

    var t: AmqpTransport = undefined;
    const entity = try t.initFromConnectionString(allocator, null, cs, .{});
    defer t.deinit();

    try testing.expectEqualStrings("orders", entity.?);
    try testing.expectEqualStrings("ns.servicebus.windows.net", t.fully_qualified_namespace);
    try testing.expect(t.credential == .sas);
    try testing.expect(t.options.use_tls);
}

test "the emulator's connection string turns TLS off" {
    const allocator = testing.allocator;
    const cs = "Endpoint=sb://localhost;SharedAccessKeyName=root;" ++
        "SharedAccessKey=c2VjcmV0;UseDevelopmentEmulator=true";

    var t: AmqpTransport = undefined;
    _ = try t.initFromConnectionString(allocator, null, cs, .{});
    defer t.deinit();

    try testing.expect(!t.options.use_tls);
}

test "dialling without an io implementation is refused, not crashed" {
    const allocator = testing.allocator;
    var credential: StubCredential = .{};

    var t: AmqpTransport = undefined;
    t.init(.{
        .allocator = allocator,
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .credential = .{ .token = &credential.credential },
    });
    defer t.deinit();

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try testing.expectError(
        error.MissingIo,
        t.sendMessages(allocator, "orders", &.{msg}),
    );
}

/// What one delivery costs inside `azure_sdk_amqp`'s sender: the transfer
/// performative is encoded once to measure the chunk budget and once to write
/// it, plus the frame itself. None of the three belong to this package — they
/// are the residual `azure_sdk_amqp` was left with when it stopped re-encoding
/// the performative per frame. Named so that a change to this number reads as
/// a dependency regression rather than a Service Bus one.
const amqp_sender_allocs_per_delivery = 3;

test "a send costs the same per message however many are sent" {
    // The performance claim of this transport is that the session, the sender
    // link, the CBS token, the message scratch and the encode buffer are all
    // paid for once and then reused, so a message costs nothing to *encode*.
    // Assert the *marginal* cost of a message rather than the cost of a call,
    // so every fixed per-call cost cancels without needing to know what any of
    // them are.
    const perf = @import("azure_sdk_core").perf;

    const small = 4;
    const large = 36;
    const body = "0123456789abcdef0123456789abcdef";

    var counting = perf.CountingAllocator.init(testing.allocator);
    const allocator = counting.allocator();

    var h = try Harness.initSplit(allocator, testing.allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), testing.allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 200);
    // One range per `sendMessages` call: the put-token took delivery 0, so the
    // warm-up is delivery 1 and each batch follows on. A range decides every
    // entry it covers at once, so only the first await of a call reads a frame.
    try scriptAccept(h.peer(), 1, 1);
    try scriptAccept(h.peer(), 2, 1 + small);
    try scriptAccept(h.peer(), 2 + small, 1 + small + large);

    // A window wider than either batch, so no send waits mid-loop and the
    // difference between the two batches is encode-and-write only.
    try h.start(.{ .max_in_flight = 64 });

    var msg = sb.ServiceBusMessage.init(allocator, body);
    defer msg.deinit();
    // With application properties, which is how Service Bus messages usually
    // travel and the only branch of `toAmqpMessage` that reaches the heap. A
    // fixture without them would leave that branch untaken and the claim
    // below unmeasured.
    try msg.application_properties.put("tenant", "contoso");
    try msg.application_properties.put("region", "westus");

    // Warm up with a message of the shape that follows, so the encode buffer
    // and the property array have both reached their high-water mark before
    // either measured batch.
    // Growing it inside the small batch would be a one-off charged to the
    // subtrahend, which would understate the marginal cost.
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    var batch: [large]sb.ServiceBusMessage = undefined;
    for (&batch) |*slot| slot.* = msg;

    counting.reset();
    try h.transport.sendMessages(allocator, "orders", batch[0..small]);
    const cost_small = counting.count;

    counting.reset();
    try h.transport.sendMessages(allocator, "orders", batch[0..large]);
    const cost_large = counting.count;

    // Every marginal allocation is the dependency's. Building the message and
    // encoding it add none: `Scratch` overwrites its annotations and body in
    // place, keeps the property array it already grew, and `encode_buf.reset()`
    // only rewinds a cursor.
    const per_message = (cost_large - cost_small) / (large - small);
    try testing.expectEqual(@as(u64, amqp_sender_allocs_per_delivery), per_message);

    // The division above would hide a remainder, so pin the whole difference.
    try testing.expectEqual(
        @as(u64, (large - small) * amqp_sender_allocs_per_delivery),
        cost_large - cost_small,
    );
}

test "a send that fails partway leaves no delivery stuck on the link" {
    // Deliveries written but never settled are the failure mode that wedges a
    // link: the next send finds the window full, or drains a stale entry and
    // waits out its deadline on a verdict that can no longer arrive. Whatever
    // the caller does about the error, the link has to be usable afterwards.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 50);
    try scriptAccept(h.peer(), 1, 1);
    // The broker refuses the first of the three, and says nothing about the
    // two already on the wire behind it.
    try scriptReject(h.peer(), 2, 2);
    try scriptAccept(h.peer(), 5, 5);

    // Wide enough that all three are written before the first verdict is read.
    try h.start(.{ .max_in_flight = 8 });

    var msg = sb.ServiceBusMessage.init(allocator, "order-42");
    defer msg.deinit();
    try warmUp(&h, allocator, "orders");

    const batch = [_]sb.ServiceBusMessage{ msg, msg, msg };
    try testing.expectError(
        error.SendRejected,
        h.transport.sendMessages(allocator, "orders", &batch),
    );

    const sender = h.transport.senders.get("orders").?.sender;
    try testing.expectEqual(@as(usize, 0), sender.inFlight());

    // And the link still works: delivery 5 is the next id after the three
    // that were written, so a peer accepting it is answering this send.
    try h.transport.sendMessages(allocator, "orders", &.{msg});
}

test "an expired claim is renewed on a link that is already attached" {
    // A CBS claim expires while its link stays attached, and the broker
    // detaches the link when it does. Authorising only at attach time would
    // therefore work perfectly in every test that runs inside one token
    // lifetime and strand a real client an hour in.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);

    // The renewal: put-token is delivery 2, and its reply is the second
    // request on the CBS receiver link.
    try scriptAccept(h.peer(), 2, 2);
    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
        .{ .key = .{ .string = "statusDescription" }, .value = .{ .string = "Accepted" } },
    };
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = "cbs-reply-to-servicebus:2" } },
        .application_properties = &props,
    });
    defer allocator.free(reply);
    try h.peer().pushTransfer(0, .{
        .handle = 1,
        .delivery_id = 1,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
    try scriptAccept(h.peer(), 3, 3);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try h.transport.sendMessages(allocator, "orders", &.{msg});
    try testing.expectEqual(@as(usize, 1), h.credential.calls);

    h.mem.clearWritten();
    test_now_ms = stub_token_expires_on * std.time.ms_per_s + 1;
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    // A fresh token was minted and put, and the link was not re-attached to
    // get it: two transfers, the put-token and the message, and no attach.
    try testing.expectEqual(@as(usize, 2), h.credential.calls);

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 2), transfers.len);
}

test "a sender attaches to the entity, not to its own link name" {
    // The target address is what routes a message to a queue. The scripted
    // peer accepts any attach it is given, so nothing else here would notice
    // a link that named the wrong destination — and a real broker would
    // deliver the messages somewhere else, or refuse the attach.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);

    // The CBS pair attaches first; the entity sender is the third and last.
    try testing.expectEqual(@as(usize, 3), attaches.len);
    var decoded = try amqp.performative.decode(allocator, attaches[2]);
    defer decoded.deinit();

    const attach = decoded.performative.attach;
    try testing.expectEqualStrings("servicebus-sender-orders", attach.name);
    try testing.expectEqual(amqp.performative.Role.sender, attach.role);
    try testing.expectEqualStrings("orders", attach.target.?.address.?);
}

test "a link the broker detached is re-attached rather than written to again" {
    // §2.6.1 unbinds the handle at detach, so a transfer sent on it is
    // `amqp:session:unattached-handle` and the peer must end the *session* —
    // taking every other entity's link down with it. A cached sender handed
    // back unchecked does exactly that, and does it forever, since nothing
    // else ever removes the entry.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    // The detach lands before the outcome, so the send that is waiting for
    // that outcome is the one that reads it.
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    try scriptAccept(h.peer(), 1, 1);
    // The replacement link. `Session` allocates handles in order and the
    // detached one is not reused, so this is handle 3.
    try scriptSenderAttach(h.peer(), 3, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 2, 2);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();

    try testing.expectError(
        error.LinkDetached,
        h.transport.sendMessages(allocator, "orders", &.{msg}),
    );
    try testing.expect(!h.transport.senders.get("orders").?.sender.attached);

    // The next send replaces the link instead of writing on the dead handle,
    // and the claim is still cached so no second round trip to `$cbs`.
    h.mem.clearWritten();
    try h.transport.sendMessages(allocator, "orders", &.{msg});
    try testing.expect(h.transport.senders.get("orders").?.sender.attached);
    try testing.expectEqual(@as(usize, 1), h.credential.calls);

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);

    var decoded = try amqp.performative.decode(allocator, attaches[0]);
    defer decoded.deinit();
    try testing.expectEqualStrings("orders", decoded.performative.attach.target.?.address.?);

    // One entity, one link: the replacement took the old one's place rather
    // than accumulating beside it.
    try testing.expectEqual(@as(usize, 1), h.transport.senders.count());
}

test "an owned token is released when the next one is minted" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var owning = OwningStubCredential{ .allocator = allocator };

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);
    try scriptAccept(h.peer(), 2, 2);
    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
        .{ .key = .{ .string = "statusDescription" }, .value = .{ .string = "Accepted" } },
    };
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = "cbs-reply-to-servicebus:2" } },
        .application_properties = &props,
    });
    defer allocator.free(reply);
    try h.peer().pushTransfer(0, .{
        .handle = 1,
        .delivery_id = 1,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
    try scriptAccept(h.peer(), 3, 3);

    try h.start(.{});
    // Swap in the owning credential before anything mints a token.
    h.transport.credential = .{ .token = &owning.credential };

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    // Expire the claim so the second send mints a second token. The first
    // must have been released by then; `testing.allocator` fails the test if
    // it was not, which is the whole point of this fixture.
    test_now_ms = stub_token_expires_on * std.time.ms_per_s + 1;
    try h.transport.sendMessages(allocator, "orders", &.{msg});
    try testing.expectEqual(@as(usize, 2), owning.calls);
}

test "the emulator's audience names plaintext AMQP" {
    // The emulator serves plaintext AMQP and the signature is computed over
    // the audience, so writing `amqps://` here would sign and present a
    // resource the broker never serves. Event Hubs carries the same helper
    // for the same reason.
    const allocator = testing.allocator;

    var transport: AmqpTransport = undefined;
    const entity = try transport.initFromConnectionString(
        allocator,
        null,
        "Endpoint=sb://localhost;SharedAccessKeyName=root;SharedAccessKey=c2VjcmV0;UseDevelopmentEmulator=true;EntityPath=orders",
        .{},
    );
    defer transport.deinit();

    try testing.expectEqualStrings("orders", entity.?);
    try testing.expectEqualStrings("amqp", transport.scheme);
    try testing.expectEqualStrings("amqp://localhost/orders", transport.owned_audience.?);
    try testing.expect(!transport.options.use_tls);

    // And the audience a link asks `$cbs` for uses the same scheme, or the
    // broker would not match it against what was signed.
    const per_entity = try audienceFor(allocator, transport.scheme, transport.fully_qualified_namespace, "invoices");
    defer allocator.free(per_entity);
    try testing.expectEqualStrings("amqp://localhost/invoices", per_entity);
}
