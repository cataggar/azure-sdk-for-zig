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
//! Not here yet: the management operations (`scheduleMessage`,
//! `cancelScheduled`). They report `error.NotImplemented` rather than
//! succeeding silently.

const std = @import("std");
const builtin = @import("builtin");
const core = @import("azure_sdk_core");
const messaging_common = @import("azure_sdk_messaging_common");
const amqp = @import("azure_sdk_amqp");
const sb = @import("root.zig");
const message_codec = @import("message.zig");
const management = @import("management.zig");

const Allocator = std.mem.Allocator;

var testing_crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);
var testing_http_context: u8 = 0;

const testing_http_vtable: core.http.HttpTransport.VTable = .{
    .send = struct {
        fn send(_: *anyopaque, _: *core.http.Request) !core.http.Response {
            return error.UnexpectedHttpRequest;
        }
    }.send,
};

fn testingRuntime() core.http.HttpRuntime {
    return .init(
        .{ .context = &testing_http_context, .vtable = &testing_http_vtable },
        testing_crypto_provider.asProvider(),
    );
}

/// Version reported to the service in the `open` properties.
pub const sdk_version = "0.2.0";

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

    pub fn getToken(
        self: *Credential,
        ctx: core.context.Context,
        runtime: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        return self.tokenCredential().getToken(
            .{ .scopes = &.{token_scope} },
            ctx,
            runtime,
        );
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
    runtime: core.http.HttpRuntime,
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
        var token = try self.credential.getToken(self.ctx, self.runtime);
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

const receiver_prefetch_limit: u32 = 8;
const receiver_max_message_size: u64 = 128 * 1024 * 1024;
const receiver_max_buffered_bytes: u64 = 1024 * 1024 * 1024;

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
    /// Credit granted to a receiver on attach and topped back up as
    /// deliveries arrive.
    ///
    /// A receiver holding credit lets the broker stream messages ahead of the
    /// call that asks for them, so a batch is one round trip rather than one
    /// per message. Service Bus caps this at eight deliveries to keep every
    /// grant within the receiver's one-GiB aggregate byte budget. Zero
    /// disables the window and makes each `receiveMessages` ask for exactly
    /// the count it was given, which is the right shape for a consumer that
    /// must not hold locks it is not about to work through.
    prefetch: u32 = receiver_prefetch_limit,
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

/// One entity's receiver link, with the audience its claim is put under and
/// the mode it was attached in.
///
/// The mode is part of the link, not of the call: a `receive_and_delete` link
/// settles on receipt and a `peek_lock` link does not, so a call asking for
/// the other mode needs a different link rather than different handling.
const EntityReceiver = struct {
    receiver: *amqp.Receiver,
    audience: []u8,
    mode: sb.ReceiveMode,
};

/// One entity's `$management` link pair, with the audience its claim is put
/// under.
const EntityManagement = struct {
    rpc: *amqp.RpcLink,
    audience: []u8,
};

/// The rejection condition Service Bus reads as "dead-letter this".
const dead_letter_condition = "com.microsoft:dead-letter";

/// The most messages one `receiveMessages` may ask for.
///
/// The same ceiling `azure_sdk_eventhubs` puts on a receive, and for the same
/// reason: the count becomes both a credit grant and a precise reservation, so
/// it has to be the caller's intent rather than whatever number arrived.
pub const max_receive_count: u32 = 5000;

/// How much of a management call's remaining deadline is kept back from the
/// broker, so that a broker that has run out of time still has the return leg
/// left to say so in.
const server_timeout_buffer_ms: i64 = 1000;

/// A real Service Bus AMQP transport.
///
/// Holds interior pointers — the vtable it hands out points back at itself —
/// so initialise it in place and never copy it afterwards.
pub const AmqpTransport = struct {
    allocator: Allocator,
    /// Copied by value. Its HTTP and crypto backend contexts are borrowed and
    /// must outlive this transport and every operation.
    runtime: core.http.HttpRuntime,
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
    /// Receiver links by entity. Keys and everything in the value are owned.
    receivers: std.StringHashMapUnmanaged(EntityReceiver) = .empty,
    /// `$management` link pairs by entity. Keys and everything in the value
    /// are owned.
    managers: std.StringHashMapUnmanaged(EntityManagement) = .empty,
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
        .settleMessagesFn = settleMessagesImpl,
        .scheduleMessagesFn = scheduleMessagesImpl,
        .cancelScheduledFn = cancelScheduledImpl,
        .renewMessageLockFn = renewMessageLockImpl,
        .peekMessagesFn = peekMessagesImpl,
        .closeFn = closeImpl,
    },

    pub const Options = struct {
        allocator: Allocator,
        runtime: core.http.HttpRuntime,
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
            .runtime = options.runtime,
            .io = options.io,
            .fully_qualified_namespace = options.fully_qualified_namespace,
            .credential = options.credential,
            .options = options.connection,
            .borrowed_session = options.session,
        };
        self.encode_buf = amqp.encoder.Buffer.initDynamic(options.allocator);
        self.scratch = .init(options.allocator);
        self.token_source = .{
            .credential = &self.credential,
            .runtime = options.runtime,
        };
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
        runtime: core.http.HttpRuntime,
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
            .runtime = runtime,
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
            var receiving = self.receivers.iterator();
            while (receiving.next()) |entry| {
                current.closeReceiver(entry.value_ptr.receiver, 0);
                self.allocator.free(entry.value_ptr.audience);
                self.allocator.free(entry.key_ptr.*);
            }
            var managing = self.managers.iterator();
            while (managing.next()) |entry| {
                closeRpc(current, entry.value_ptr.rpc);
                self.allocator.free(entry.value_ptr.audience);
                self.allocator.free(entry.key_ptr.*);
            }
        }
        self.senders.deinit(self.allocator);
        self.senders = .empty;
        self.receivers.deinit(self.allocator);
        self.receivers = .empty;
        self.managers.deinit(self.allocator);
        self.managers = .empty;

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

    /// The authorised receiver link for `entity`, attaching on first use.
    ///
    /// A cached link is re-attached when the broker has detached it, for the
    /// reason `senderFor` gives, and also when the caller asks for a
    /// different `ReceiveMode` than the link was attached in.
    fn receiverFor(
        self: *AmqpTransport,
        current: *amqp.Session,
        entity: []const u8,
        mode: sb.ReceiveMode,
        deadline_ms: i64,
    ) !*amqp.Receiver {
        if (self.receivers.getPtr(entity)) |existing| {
            if (existing.receiver.attached and existing.mode == mode) {
                try self.authorize(current, existing.audience, deadline_ms);
                return existing.receiver;
            }
            self.dropReceiver(current, entity);
        }

        const audience = try audienceFor(
            self.allocator,
            self.scheme,
            self.fully_qualified_namespace,
            entity,
        );
        errdefer self.allocator.free(audience);

        try self.authorize(current, audience, deadline_ms);

        const name = try std.fmt.allocPrint(
            self.allocator,
            "{s}-receiver-{s}",
            .{ self.options.link_id, entity },
        );
        defer self.allocator.free(name);

        const receiver = try amqp.openReceiver(current, .{
            .name = name,
            .source_address = entity,
            .prefetch = @min(self.options.prefetch, receiver_prefetch_limit),
            .max_message_size = receiver_max_message_size,
            .max_buffered_bytes = receiver_max_buffered_bytes,
        }, deadline_ms);
        errdefer current.closeReceiver(receiver, 0);

        const key = try self.allocator.dupe(u8, entity);
        errdefer self.allocator.free(key);
        try self.receivers.put(self.allocator, key, .{
            .receiver = receiver,
            .audience = audience,
            .mode = mode,
        });
        return receiver;
    }

    /// Forget `entity`'s receiver, releasing everything the entry owned.
    fn dropReceiver(self: *AmqpTransport, current: *amqp.Session, entity: []const u8) void {
        const removed = self.receivers.fetchRemove(entity) orelse return;
        current.closeReceiver(removed.value.receiver, 0);
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

    /// Receive up to `max_count` messages from `entity`.
    ///
    /// Returns with whatever arrived when the entity goes quiet rather than
    /// holding out for a full batch, and an empty batch when nothing arrived
    /// at all: an empty queue is the steady state of a Service Bus consumer,
    /// not a failure, and the driver's deadline expiring is the only signal
    /// there is that no message is coming. Every other error still surfaces —
    /// a detached link and a quiet queue are not the same thing.
    ///
    /// A failure part-way through keeps the messages already in hand, for the
    /// same reason: they arrived, and dropping them here would lose them. That
    /// holds for a failed decode as much as for a failed read — under
    /// `receive_and_delete` the earlier messages may already have been settled
    /// and deleted at the broker, so returning an error instead would destroy
    /// them. The one case with no good answer is a message that cannot be
    /// decoded at the head of the batch: it is returned as an error, and
    /// because the caller never gets a handle to it, it cannot be
    /// dead-lettered either. Under `peek_lock` that is a loop rather than a
    /// one-off — the delivery is consumed from the ready queue but left
    /// unsettled, so it returns when the lock lapses and stops the batch at
    /// the same place again. Breaking it needs the raw delivery, which this
    /// signature has nowhere to put.
    pub fn receiveMessages(
        self: *AmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        max_count: u32,
        mode: sb.ReceiveMode,
    ) !sb.ReceivedMessages {
        if (max_count == 0) return .{};
        // `max_count` sizes both a credit grant and a precise reservation, so
        // an unbounded one turns a caller's typo into an arbitrary allocation.
        if (max_count > max_receive_count) return error.InvalidCount;

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);
        const receiver = try self.receiverFor(current, entity, mode, deadline_ms);

        // Without a prefetch window the link holds no credit at all, so ask
        // for exactly what this call needs on top of anything outstanding.
        if (self.options.prefetch == 0 and receiver.credit < max_count) {
            try receiver.issueCredit(max_count - receiver.credit);
        }

        // Nothing is allocated until a message actually arrives. A consumer on
        // a quiet queue polls in a loop, and reserving room for a batch that
        // never comes would make the steady state the expensive case.
        var arena: ?*std.heap.ArenaAllocator = null;
        errdefer if (arena) |owned| {
            owned.deinit();
            allocator.destroy(owned);
        };
        var messages: std.ArrayList(sb.ServiceBusReceivedMessage) = .empty;
        var owned_entity: []const u8 = &.{};

        // `receive_and_delete` has no lock to hold, so the messages are
        // settled as they are read rather than left for the caller. The true
        // AMQP form of this is `snd-settle-mode: settled` on the attach,
        // which `azure_sdk_amqp` does not expose yet, so this is at-least-once
        // where the broker's own mode is at-most-once: a disposition lost in
        // flight means redelivery rather than a silently dropped message.
        var settling = amqp.SettleBatch.init(receiver, .accepted);

        while (messages.items.len < max_count) {
            const delivery = receiver.receive(deadline_ms) catch |err| {
                if (messages.items.len > 0) break;
                if (err == error.Timeout) break;
                return err;
            };

            // Decoding immediately is not an optimisation but the contract:
            // a `Delivery` is valid only until the next `receive`, which the
            // next turn of this loop performs. The decode borrows nothing
            // from the payload, so what lands in the arena outlives it.
            takeDelivery(
                allocator,
                &arena,
                &messages,
                &owned_entity,
                entity,
                max_count,
                delivery,
            ) catch |err| {
                if (messages.items.len > 0) break;
                return err;
            };

            if (mode == .receive_and_delete) {
                // Settling is advisory: a message that could not be settled
                // is redelivered, and failing here would throw away messages
                // the caller has already been given.
                settling.add(delivery) catch {};
            }
        }

        if (mode == .receive_and_delete) settling.flush() catch {};

        // Nothing arrived, so no arena was ever made and an empty poll costs
        // no page at all.
        const owned = arena orelse return .{};
        return .{ .messages = messages.items, .arena = owned };
    }

    /// Copy one delivery into the batch, creating the batch's arena if this is
    /// the first message to arrive.
    ///
    /// Split out so that every allocation a message needs sits behind a single
    /// `catch` in the loop above: a failure here must leave the messages
    /// already taken intact, which a bare `try` in the loop would not do.
    ///
    /// Free-standing rather than a method, so that the only entity slice in
    /// scope is the caller's. The `receivers` map key is the tempting thing to
    /// borrow and the wrong one — `dropReceiver` frees it at the next
    /// re-attach, while a batch taken before it may still be in the caller's
    /// hands.
    fn takeDelivery(
        allocator: Allocator,
        arena: *?*std.heap.ArenaAllocator,
        messages: *std.ArrayList(sb.ServiceBusReceivedMessage),
        owned_entity: *[]const u8,
        entity: []const u8,
        max_count: u32,
        delivery: amqp.Delivery,
    ) !void {
        if (arena.* == null) {
            const owned = try allocator.create(std.heap.ArenaAllocator);
            errdefer allocator.destroy(owned);
            owned.* = .init(allocator);
            errdefer owned.deinit();

            const a = owned.allocator();
            // Exactly how many can be appended, and the loop only runs while
            // short of it, so every append below is infallible.
            try messages.ensureTotalCapacityPrecise(a, max_count);
            // One copy for the whole batch. It cannot borrow the receivers
            // map's key: a re-attach frees that while a batch taken before it
            // may still be in the caller's hands.
            owned_entity.* = try a.dupe(u8, entity);
            arena.* = owned;
        }
        const a = arena.*.?.allocator();

        const decoded = try amqp.decodeMessageInto(a, delivery.payload);

        var received = message_codec.fromAmqpMessage(decoded);
        received.delivery_id = delivery.id;
        // The tag is Service Bus's lock token and lives in the delivery's own
        // buffer, so it has to be copied to outlive it.
        received.delivery_tag = try a.dupe(u8, delivery.tag);
        received.entity = owned_entity.*;
        messages.appendAssumeCapacity(received);
    }

    /// The AMQP outcome a Service Bus disposition maps to.
    ///
    /// `info` backs the dead-letter fields, which ride on the caller's stack
    /// because nothing here outlives the disposition frame.
    fn outcomeFor(
        action: sb.DispositionAction,
        dead_letter: sb.DeadLetterOptions,
        info: *[2]amqp.MapEntry,
    ) amqp.performative.DeliveryState {
        return switch (action) {
            .complete => .accepted,
            // Neither flag: the message failed at nothing and is still
            // deliverable here, it is simply being handed back.
            .abandon => .{ .modified = .{} },
            // The broker reads `undeliverable-here` as "park this under its
            // sequence number", which is what deferral is.
            .defer_msg => .{ .modified = .{ .undeliverable_here = true } },
            .dead_letter => blk: {
                var n: usize = 0;
                if (dead_letter.reason) |reason| {
                    info[n] = .{
                        .key = .{ .string = message_codec.application_property.dead_letter_reason },
                        .value = .{ .string = reason },
                    };
                    n += 1;
                }
                if (dead_letter.error_description) |description| {
                    info[n] = .{
                        .key = .{ .string = message_codec.application_property.dead_letter_description },
                        .value = .{ .string = description },
                    };
                    n += 1;
                }
                break :blk .{ .rejected = .{
                    .condition = dead_letter_condition,
                    .description = dead_letter.reason,
                    .info = if (n == 0) null else info[0..n],
                } };
            },
        };
    }

    /// Settle a run of received messages, coalescing them into as few
    /// dispositions as their delivery ids allow.
    ///
    /// Delivery ids are allocated by the *session*, not the link, and a
    /// `disposition` carries no handle (§2.7.6), so a range is not confined to
    /// one link. That cuts both ways here.
    ///
    /// The run is broken wherever the ids are not consecutive, because a gap
    /// means another link on the session — `$cbs`, `$management`, a second
    /// entity — took an id in between, and settling across the gap would
    /// decide that link's delivery too.
    ///
    /// It is broken wherever the entity changes for a different reason: not
    /// because the ids would be misread, but because whether they should be
    /// settled at all is a property of the *link*. A `receive_and_delete`
    /// entity's ids were settled as they were read; folding them into a
    /// neighbouring `peek_lock` entity's range would settle them twice.
    pub fn settleMessages(
        self: *AmqpTransport,
        allocator: Allocator,
        messages: []const sb.ServiceBusReceivedMessage,
        action: sb.DispositionAction,
        dead_letter: sb.DeadLetterOptions,
    ) !void {
        _ = allocator;
        if (messages.len == 0) return;

        var info: [2]amqp.MapEntry = undefined;
        const state = outcomeFor(action, dead_letter, &info);

        var i: usize = 0;
        while (i < messages.len) {
            const entity = messages[i].entity orelse return error.MissingEntity;
            const entry = self.receivers.getPtr(entity) orelse return error.NoSuchReceiver;
            if (!entry.receiver.attached) return error.LinkDetached;

            // A `receive_and_delete` message was settled as it was read, so
            // settling it again would decide a delivery id the broker has
            // already forgotten — and may since have reissued.
            const settle = entry.mode == .peek_lock;
            var batch = amqp.SettleBatch.init(entry.receiver, state);

            while (i < messages.len) : (i += 1) {
                const message = messages[i];
                const at = message.entity orelse return error.MissingEntity;
                if (!std.mem.eql(u8, at, entity)) break;
                const id = message.delivery_id orelse return error.MissingDeliveryId;
                if (settle) try batch.addId(id);
            }
            try batch.flush();
        }
    }

    // ─────────────────── Management operations ───────────────────

    /// The `$management` link pair for one entity.
    ///
    /// Opened lazily and cached like the sender and receiver links, since a
    /// client that renews a lock once will almost certainly renew another.
    fn managementFor(
        self: *AmqpTransport,
        current: *amqp.Session,
        entity: []const u8,
        deadline_ms: i64,
    ) !*amqp.RpcLink {
        if (self.managers.getPtr(entity)) |existing| {
            // Same reason the sender and receiver caches check: §2.6.1 unbinds
            // the handle at detach, and a transfer on an unbound handle ends
            // the session and takes every other link on it with it.
            if (existing.rpc.sender.attached and existing.rpc.receiver.attached) {
                try self.authorize(current, existing.audience, deadline_ms);
                return existing.rpc;
            }
            self.dropManagement(current, entity);
        }

        // The claim is on the entity, not on `<entity>/$management`: the
        // broker matches a token's resource against the link address by
        // prefix, so the entity's token covers the node beneath it. This is
        // what the Python client relies on, and it is why Go's second claim
        // for the management path and .NET's single claim *only* for the
        // management path both work — the three do not agree, so the token is
        // demonstrably accepted either way round.
        const audience = try audienceFor(
            self.allocator,
            self.scheme,
            self.fully_qualified_namespace,
            entity,
        );
        errdefer self.allocator.free(audience);

        try self.authorize(current, audience, deadline_ms);

        // Service Bus scopes management to the entity rather than to the
        // connection, so the address carries the entity path.
        const address = try std.fmt.allocPrint(self.allocator, "{s}/$management", .{entity});
        defer self.allocator.free(address);

        // The link id is the transport's, not one per entity. `RpcLink`
        // derives both link names and the private reply address from the
        // address, which already carries the entity, so every pair is
        // distinct without repeating it — and `RpcLink` formats each
        // correlation id as `{reply_to}:{n}` into a 64-byte buffer, falling
        // back to a bare `{n}` when that does not fit. Doubling the entity
        // into `reply_to` would spend that budget on nothing.
        const rpc = try amqp.RpcLink.open(current, .{
            .address = address,
            .link_id = self.options.link_id,
        }, deadline_ms);
        errdefer closeRpc(current, rpc);

        const key = try self.allocator.dupe(u8, entity);
        errdefer self.allocator.free(key);
        try self.managers.put(self.allocator, key, .{ .rpc = rpc, .audience = audience });
        return rpc;
    }

    fn dropManagement(self: *AmqpTransport, current: *amqp.Session, entity: []const u8) void {
        const removed = self.managers.fetchRemove(entity) orelse return;
        closeRpc(current, removed.value.rpc);
        self.allocator.free(removed.value.audience);
        self.allocator.free(removed.key);
    }

    /// Detach and destroy both halves of an RPC link.
    ///
    /// `RpcLink.deinit` frees only the link pair's own state; the two links
    /// belong to the session, so they have to be closed through it or they
    /// stay attached and allocated for the life of the connection.
    fn closeRpc(current: *amqp.Session, rpc: *amqp.RpcLink) void {
        current.closeReceiver(rpc.receiver, 0);
        current.closeSender(rpc.sender, 0);
        rpc.deinit();
    }

    /// The name of the link this operation acts on behalf of, if one is open.
    ///
    /// The broker uses `associated-link-name` to route the operation to the
    /// same partition and session as the link, so it must name the link that
    /// actually holds the message: the sender for scheduling, the receiver for
    /// locks and peeks. When no such link is open there is nothing to
    /// associate with and the property is omitted, as the Go client does.
    fn senderName(self: *AmqpTransport, entity: []const u8) ?[]const u8 {
        const cached = self.senders.get(entity) orelse return null;
        return cached.sender.name;
    }

    fn receiverName(self: *AmqpTransport, entity: []const u8) ?[]const u8 {
        const cached = self.receivers.get(entity) orelse return null;
        return cached.receiver.name;
    }

    /// The `com.microsoft:server-timeout` to send with a request whose own
    /// deadline is `deadline_ms`.
    ///
    /// What is left of the deadline, less a second, rather than the whole
    /// configured budget: the broker's timer starts when the request lands,
    /// which is after the dial, the claim and the attach this call may have
    /// had to do first. Sending the whole budget would have the broker give
    /// up strictly later than the caller, which is the case the property
    /// exists to avoid — the caller times out first and the broker is left
    /// working on an answer nobody is waiting for. The second is the same
    /// buffer Go's `serverTimeoutBuffer` takes off, and for the same reason:
    /// expiring together is not enough, because the reply still needs the
    /// return leg. Under a second left there is no room for the broker to
    /// answer first, so this clamps to zero and the buffer simply stops
    /// helping.
    fn serverTimeoutMs(current: *amqp.Session, deadline_ms: i64) u32 {
        const remaining = deadline_ms -| current.driver.clock.nowMillis();
        const budget = remaining -| server_timeout_buffer_ms;
        if (budget <= 0) return 0;
        return @intCast(@min(budget, std.math.maxInt(u32)));
    }

    /// Perform one management operation and return its reply.
    ///
    /// The caller owns the reply and must `deinit` it. Everything the reply's
    /// body points at lives inside it, so it has to outlive the reading.
    fn managementCall(
        self: *AmqpTransport,
        current: *amqp.Session,
        entity: []const u8,
        op: []const u8,
        associated_link: ?[]const u8,
        body: amqp.AmqpValue,
        deadline_ms: i64,
    ) !amqp.rpc.Response {
        const rpc = try self.managementFor(current, entity, deadline_ms);

        var props: [3]amqp.MapEntry = undefined;
        var n: usize = 0;
        props[n] = .{
            .key = .{ .string = management.property.operation },
            .value = .{ .string = op },
        };
        n += 1;
        props[n] = .{
            .key = .{ .string = management.property.server_timeout },
            .value = .{ .uint = serverTimeoutMs(current, deadline_ms) },
        };
        n += 1;
        if (associated_link) |name| {
            props[n] = .{
                .key = .{ .string = management.property.associated_link_name },
                .value = .{ .string = name },
            };
            n += 1;
        }

        var response = try rpc.call(.{
            .application_properties = props[0..n],
            .body = .{ .value = body },
        }, deadline_ms);
        errdefer response.deinit();

        // 410 is the broker saying the lock this operation named has already
        // lapsed. Distinguished from every other refusal because it is the one
        // a caller can act on: the message is back on the queue and will be
        // redelivered rather than needing a retry of this call.
        if (response.status_code == 410) return error.MessageLockLost;
        try amqp.rpc.checkStatus(response.status_code);
        return response;
    }

    /// Schedule a run of messages, writing one sequence number per message
    /// into `out` and returning how many were written.
    pub fn scheduleMessages(
        self: *AmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        messages: []const sb.ServiceBusMessage,
        enqueue_time: i64,
        out: []i64,
    ) !usize {
        if (messages.len == 0) return 0;
        if (messages.len > max_receive_count) return error.InvalidCount;

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);

        // One arena for the request: the body is a tree of maps and lists over
        // a copy of every encoded message, all of it dead the moment the
        // request is on the wire.
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const a = arena.allocator();

        const entries = try a.alloc(management.Scheduled, messages.len);
        for (messages, entries) |message, *slot| {
            // `enqueue_time` is the call's, so it wins over anything left on
            // the message: the caller named it here.
            var scheduled = message;
            scheduled.scheduled_enqueue_time = enqueue_time;

            // `Scratch` holds one live message at a time, so each is encoded
            // and copied out before the next overwrites it.
            self.encode_buf.reset();
            const amqp_message = try message_codec.toAmqpMessage(scheduled, &self.scratch);
            try amqp.message_codec.encode(allocator, amqp_message, &self.encode_buf);

            slot.* = .{
                .message_id = message.message_id,
                .encoded = try a.dupe(u8, self.encode_buf.written()),
                .partition_key = message.partition_key,
                .session_id = message.session_id,
            };
        }

        const body = try management.scheduleBody(a, entries);
        var response = try self.managementCall(
            current,
            entity,
            management.operation.schedule_message,
            self.senderName(entity),
            body,
            deadline_ms,
        );
        defer response.deinit();

        return management.readSequenceNumbers(response.msg().body, out);
    }

    /// Cancel a run of scheduled messages by sequence number.
    pub fn cancelScheduled(
        self: *AmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        sequence_numbers: []const i64,
    ) !void {
        if (sequence_numbers.len == 0) return;

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const body = try management.cancelBody(arena.allocator(), sequence_numbers);
        var response = try self.managementCall(
            current,
            entity,
            management.operation.cancel_scheduled_message,
            self.senderName(entity),
            body,
            deadline_ms,
        );
        // The reply carries a status and nothing else worth reading; a
        // non-2xx has already been turned into an error.
        response.deinit();
    }

    /// Extend the peek-lock on `message`, returning when the new lock expires
    /// in milliseconds since the epoch.
    pub fn renewMessageLock(
        self: *AmqpTransport,
        allocator: Allocator,
        message: sb.ServiceBusReceivedMessage,
    ) !i64 {
        const entity = message.entity orelse return error.MissingEntity;
        const tag = message.delivery_tag orelse return error.MissingLockToken;
        const token = try management.lockTokenFromDeliveryTag(tag);

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const body = try management.renewLockBody(arena.allocator(), &.{token});
        var response = try self.managementCall(
            current,
            entity,
            management.operation.renew_lock,
            self.receiverName(entity),
            body,
            deadline_ms,
        );
        defer response.deinit();

        var expirations: [1]i64 = undefined;
        const n = try management.readExpirations(response.msg().body, &expirations);
        if (n != 1) return error.MalformedReply;
        return expirations[0];
    }

    /// Read up to `max_count` messages from `from_sequence_number` onwards
    /// without locking or removing them.
    pub fn peekMessages(
        self: *AmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        from_sequence_number: i64,
        max_count: u32,
    ) !sb.ReceivedMessages {
        if (max_count == 0) return .{};
        // The same ceiling a receive has, and here it also keeps the count
        // inside the `int` the broker reads it as.
        if (max_count > max_receive_count) return error.InvalidCount;

        const current = try self.session();
        const deadline_ms = self.deadlineFrom(current);

        // The batch's arena is also what the request is built in, so the
        // request tree is dead weight in it until the batch is freed. That is
        // a few hundred bytes against saving a second arena per peek, and a
        // peek that returns nothing frees the whole thing immediately.
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = try management.peekBody(a, from_sequence_number, max_count);
        var response = try self.managementCall(
            current,
            entity,
            management.operation.peek_message,
            self.receiverName(entity),
            body,
            deadline_ms,
        );
        defer response.deinit();

        // An empty peek answers 204 with no body at all, which `readPeekedMessages`
        // reports as an empty slice rather than as malformed.
        const returned = try management.readPeekedMessages(a, response.msg().body);
        // `message-count` is a request, not a guarantee. The caller asked for
        // at most this many and sized whatever it does next accordingly, so a
        // broker that answers with more does not get to hand them on.
        const encoded = returned[0..@min(returned.len, max_count)];
        if (encoded.len == 0) {
            arena.deinit();
            allocator.destroy(arena);
            return .{};
        }

        const owned_entity = try a.dupe(u8, entity);
        var messages = try std.ArrayList(sb.ServiceBusReceivedMessage).initCapacity(a, encoded.len);
        for (encoded) |bytes| {
            // Decoded into the batch arena, so the messages outlive the reply
            // they were carried in.
            const decoded = try amqp.decodeMessageInto(a, bytes);
            var peeked = message_codec.fromAmqpMessage(decoded);

            // A peeked message is not a delivery: it holds no lock and has no
            // delivery id, so it cannot be settled. `fromAmqpMessage` adds one
            // to the header's `delivery-count` to give the count this delivery
            // would be, and there is no delivery here — the raw header value
            // is how many times it really has been delivered.
            peeked.delivery_count = decoded.header.delivery_count;
            peeked.entity = owned_entity;
            messages.appendAssumeCapacity(peeked);
        }

        return .{ .messages = messages.items, .arena = arena };
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
    ) anyerror!sb.ReceivedMessages {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.receiveMessages(allocator, entity, max_count, mode);
    }

    fn settleMessagesImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        messages: []const sb.ServiceBusReceivedMessage,
        action: sb.DispositionAction,
        dead_letter: sb.DeadLetterOptions,
    ) anyerror!void {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.settleMessages(allocator, messages, action, dead_letter);
    }

    fn scheduleMessagesImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        messages: []const sb.ServiceBusMessage,
        enqueue_time: i64,
        out: []i64,
    ) anyerror!usize {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.scheduleMessages(allocator, entity, messages, enqueue_time, out);
    }

    fn cancelScheduledImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        sequence_numbers: []const i64,
    ) anyerror!void {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.cancelScheduled(allocator, entity, sequence_numbers);
    }

    fn renewMessageLockImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        message: sb.ServiceBusReceivedMessage,
    ) anyerror!i64 {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.renewMessageLock(allocator, message);
    }

    fn peekMessagesImpl(
        t: *sb.ServiceBusAmqpTransport,
        allocator: Allocator,
        entity: []const u8,
        from_sequence_number: i64,
        max_count: u32,
    ) anyerror!sb.ReceivedMessages {
        const self: *AmqpTransport = @fieldParentPtr("transport", t);
        return self.peekMessages(allocator, entity, from_sequence_number, max_count);
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
        runtime: core.http.HttpRuntime,
    ) anyerror!core.credentials.AccessToken {
        _ = .{ request_context, ctx, runtime };
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
        runtime: core.http.HttpRuntime,
    ) anyerror!core.credentials.AccessToken {
        _ = .{ request_context, ctx, runtime };
        const self: *OwningStubCredential = @alignCast(@fieldParentPtr("credential", c));
        self.calls += 1;
        return .{
            .token = try self.allocator.dupe(u8, "minted-sas-signature"),
            .expires_on = stub_token_expires_on,
            .allocator = self.allocator,
        };
    }
};

const CryptoSpy = struct {
    hmac_calls: usize = 0,
    fail_hmac: bool = false,

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    fn asProvider(self: *CryptoSpy) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn randomBytes(_: *anyopaque, _: []u8) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn md5(_: *anyopaque, _: []const u8, _: *core.crypto.Md5Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn sha256(_: *anyopaque, _: []const u8, _: *core.crypto.Sha256Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn hmacSha256(
        context: *anyopaque,
        _: []const u8,
        _: []const u8,
        out: *core.crypto.HmacSha256Digest,
    ) !void {
        const self: *CryptoSpy = @ptrCast(@alignCast(context));
        self.hmac_calls += 1;
        @memset(out, 0xa5);
        if (self.fail_hmac) return error.SelectedCryptoFailure;
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        return error.UnexpectedCryptoOperation;
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

    try scriptCbsReply(peer, allocator, 1);
}

/// Script the settle-and-reply half of the `n`th put-token round trip.
///
/// Each claim is one request and one reply, so the `n`th of each takes
/// delivery `n - 1` in its own direction. Split out of `scriptCbsExchange`
/// because a second audience needs another claim but not another handshake.
fn scriptCbsReply(peer: Peer, allocator: Allocator, n: u32) !void {
    return scriptCbsReplyAt(peer, allocator, n, n - 1, n - 1);
}

/// `scriptCbsReply` with the delivery ids spelled out.
///
/// Delivery ids belong to the session, not to the link, so once another link
/// has sent or received anything the `n`th claim is no longer the `n`th
/// delivery in either direction.
fn scriptCbsReplyAt(
    peer: Peer,
    allocator: Allocator,
    n: u32,
    request_id: u32,
    reply_id: u32,
) !void {
    // The broker settles the request before the reply lands on the receiver
    // link.
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = request_id,
        .last = request_id,
        .settled = true,
        .state = .accepted,
    } });
    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
        .{ .key = .{ .string = "statusDescription" }, .value = .{ .string = "Accepted" } },
    };
    var id_buf: [64]u8 = undefined;
    const correlation = try std.fmt.bufPrint(&id_buf, "cbs-reply-to-servicebus:{d}", .{n});
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = correlation } },
        .application_properties = &props,
    });
    defer allocator.free(reply);
    try peer.pushTransfer(0, .{
        .handle = 1,
        .delivery_id = reply_id,
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

fn emittedDetaches(allocator: Allocator, written: []const u8) ![]const []const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, written);
    defer frames.deinit();
    return frames.of(allocator, 0x16);
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
            .runtime = testingRuntime(),
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

    var claim = try amqp.decodeMessage(allocator, try harness.transferPayload(allocator, transfers[0]));
    defer claim.deinit();
    try testing.expectEqualStrings("put-token", propertyOf(claim.message, "operation").?.string);
    try testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/orders",
        propertyOf(claim.message, "name").?.string,
    );
    try testing.expectEqualStrings("stub-jwt", claim.message.body.value.string);

    var decoded = try amqp.decodeMessage(allocator, try harness.transferPayload(allocator, transfers[1]));
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
    const entity = try t.initFromConnectionString(
        allocator,
        null,
        cs,
        testingRuntime(),
        .{},
    );
    defer t.deinit();

    try testing.expectEqualStrings("orders", entity.?);
    try testing.expectEqualStrings("ns.servicebus.windows.net", t.fully_qualified_namespace);
    try testing.expect(t.credential == .sas);
    try testing.expect(t.options.use_tls);
}

test "connection string SAS preserves the runtime and provider failures are atomic" {
    const allocator = testing.allocator;
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=root;" ++
        "SharedAccessKey=c2VjcmV0;EntityPath=orders";
    var crypto = CryptoSpy{};
    const runtime = core.http.HttpRuntime.init(
        .{ .context = &testing_http_context, .vtable = &testing_http_vtable },
        crypto.asProvider(),
    );

    var transport: AmqpTransport = undefined;
    _ = try transport.initFromConnectionString(
        allocator,
        null,
        cs,
        runtime,
        .{},
    );
    defer transport.deinit();

    try testing.expectEqual(runtime.transport.context, transport.runtime.transport.context);
    try testing.expectEqual(runtime.transport.vtable, transport.runtime.transport.vtable);
    try testing.expectEqual(runtime.crypto.context, transport.runtime.crypto.context);
    try testing.expectEqual(runtime.crypto.vtable, transport.runtime.crypto.vtable);

    const provider = transport.token_source.provider();
    _ = try provider.getToken(transport.owned_audience.?);
    try testing.expectEqual(@as(usize, 1), crypto.hmac_calls);
    try testing.expect(transport.token_source.held != null);

    crypto.fail_hmac = true;
    try testing.expectError(
        error.SelectedCryptoFailure,
        provider.getToken(transport.owned_audience.?),
    );
    try testing.expectEqual(@as(usize, 2), crypto.hmac_calls);
    try testing.expect(transport.token_source.held == null);
}

test "the emulator's connection string turns TLS off" {
    const allocator = testing.allocator;
    const cs = "Endpoint=sb://localhost;SharedAccessKeyName=root;" ++
        "SharedAccessKey=c2VjcmV0;UseDevelopmentEmulator=true";

    var t: AmqpTransport = undefined;
    _ = try t.initFromConnectionString(
        allocator,
        null,
        cs,
        testingRuntime(),
        .{},
    );
    defer t.deinit();

    try testing.expect(!t.options.use_tls);
}

test "dialling without an io implementation is refused, not crashed" {
    const allocator = testing.allocator;
    var credential: StubCredential = .{};

    var t: AmqpTransport = undefined;
    t.init(.{
        .allocator = allocator,
        .runtime = testingRuntime(),
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
    // The peer's handle for the replacement link. A handle is scoped to
    // whoever sent the frame (§2.6.2) and `applyAttach` matches on the link
    // *name*, so this number is the peer's choice and says nothing about the
    // client's — which the assertion below covers instead.
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
    const replacement = decoded.performative.attach;
    try testing.expectEqualStrings("orders", replacement.target.?.address.?);
    // A fresh handle, not the unbound one. `$cbs` took 0 and 1 and the dead
    // link took 2; reusing 2 while the peer still considers it detached is
    // the collision the eviction exists to avoid.
    try testing.expectEqual(@as(u32, 3), replacement.handle);

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
        testingRuntime(),
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

test "a claim that cannot be put leaves nothing behind" {
    // The audience is allocated before `$cbs` is asked and only becomes the
    // link entry's property once the attach has succeeded. Everything between
    // those two points is a path that has to release it: for a new entity
    // `authorize` is a real round trip, so a write failure or a deadline
    // there returns while the audience is still loose.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try warmUp(&h, allocator, "orders");

    // A second entity needs its own claim, and the put cannot be written.
    h.mem.fail_write = true;
    try testing.expectError(
        error.WriteFailed,
        h.transport.sendMessages(allocator, "invoices", &.{msg}),
    );

    // No half-built entry: the failed entity is not in the map, and the one
    // that was already there is untouched.
    try testing.expectEqual(@as(usize, 1), h.transport.senders.count());
    try testing.expect(h.transport.senders.get("invoices") == null);
}

// ─────────────────────── Receive tests ───────────────────────

/// Script the peer's half of a receiver attach on `handle`.
fn scriptReceiverAttach(peer: Peer, handle: u32, name: []const u8) !void {
    try peer.push(0, .{ .attach = .{
        .name = name,
        .handle = handle,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
}

/// Push one Service Bus message as a single-frame delivery.
fn pushMessage(
    peer: Peer,
    allocator: Allocator,
    handle: u32,
    delivery_id: u32,
    tag: []const u8,
    body: []const u8,
    sequence_number: i64,
) !void {
    const annotations = [_]amqp.MapEntry{.{
        .key = .{ .symbol = message_codec.annotation.sequence_number },
        .value = .{ .long = sequence_number },
    }};
    const sections = [_][]const u8{body};
    const payload = try amqp.encodeMessageAlloc(allocator, .{
        .message_annotations = &annotations,
        .body = .{ .data = &sections },
    });
    defer allocator.free(payload);
    try peer.pushTransfer(0, .{
        .handle = handle,
        .delivery_id = delivery_id,
        .delivery_tag = tag,
        .message_format = 0,
        .settled = false,
        .more = false,
    }, payload);
}

/// Every disposition body the client emitted.
fn emittedDispositions(allocator: Allocator, written: []const u8) ![]const []const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, written);
    defer frames.deinit();
    return frames.of(allocator, 0x15);
}

/// Every flow body the client emitted.
fn emittedFlows(allocator: Allocator, written: []const u8) ![]const []const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, written);
    defer frames.deinit();
    return frames.of(allocator, 0x13);
}

/// The most recent credit the client granted on `handle`.
///
/// Picked out by handle rather than by position: `$cbs` opens a receiver of
/// its own and grants it credit, so the first flow on the connection is never
/// the entity's.
fn creditFor(allocator: Allocator, written: []const u8, handle: u32) !?u32 {
    const flows = try emittedFlows(allocator, written);
    defer allocator.free(flows);
    var credit: ?u32 = null;
    for (flows) |body| {
        var decoded = try amqp.performative.decode(allocator, body);
        defer decoded.deinit();
        const flow = decoded.performative.flow;
        if (flow.handle) |on| {
            if (on == handle) credit = flow.link_credit;
        }
    }
    return credit;
}

/// The delivery id of the first entity message. Delivery ids are scoped to
/// the session, and the `$cbs` reply already took 0.
const first_incoming_id = 1;

/// Bring a receiver up and drain `count` messages the peer has pushed.
fn scriptEntityReceiver(h: *Harness, allocator: Allocator, entity: []const u8) !void {
    const name = try std.fmt.allocPrint(allocator, "servicebus-receiver-{s}", .{entity});
    defer allocator.free(name);
    try scriptCbsExchange(h.peer(), allocator);
    try scriptReceiverAttach(h.peer(), 2, name);
}

test "a receive attaches a receiver, decodes what arrives, and names the entity" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "tag-0", "order-1", 101);

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer batch.deinit();

    try testing.expectEqual(@as(usize, 1), batch.count());
    const got = batch.messages[0];
    try testing.expectEqualStrings("order-1", got.body);
    try testing.expectEqual(@as(i64, 101), got.sequence_number.?);
    try testing.expectEqual(@as(u32, first_incoming_id), got.delivery_id.?);
    try testing.expectEqualStrings("tag-0", got.delivery_tag.?);
    // Settlement needs to know which link a delivery id belongs to, so the
    // message has to carry its entity, not just its id.
    try testing.expectEqualStrings("orders", got.entity.?);
}

test "a received message outlives the delivery it was decoded from" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    // The second delivery is much larger than the first, so a borrowed slice
    // would be overwritten rather than left readable by luck.
    try pushMessage(h.peer(), allocator, 2, 1, "tag-a", "first", 1);
    try pushMessage(h.peer(), allocator, 2, 2, "tag-bbbbbbbbbbbbbbbb", "second" ** 40, 2);

    try h.start(.{});

    // `Delivery` is valid only until the next `receive`, which the second
    // turn of the receive loop performs — so this asserts the batch copies
    // rather than borrows.
    var batch = try h.transport.receiveMessages(allocator, "orders", 2, .peek_lock);
    defer batch.deinit();

    try testing.expectEqual(@as(usize, 2), batch.count());
    try testing.expectEqualStrings("first", batch.messages[0].body);
    try testing.expectEqualStrings("tag-a", batch.messages[0].delivery_tag.?);
    try testing.expectEqualStrings("second" ** 40, batch.messages[1].body);
}

test "settling a batch costs one disposition, not one per message" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    for (0..3) |i| {
        try pushMessage(h.peer(), allocator, 2, @intCast(first_incoming_id + i), "t", "m", @intCast(i));
    }

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 3, .peek_lock);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 3), batch.count());

    h.mem.clearWritten();
    try h.transport.settleMessages(allocator, batch.messages, .complete, .{});

    const dispositions = try emittedDispositions(allocator, h.mem.written());
    defer allocator.free(dispositions);
    try testing.expectEqual(@as(usize, 1), dispositions.len);

    var decoded = try amqp.performative.decode(allocator, dispositions[0]);
    defer decoded.deinit();
    const d = decoded.performative.disposition;
    try testing.expectEqual(@as(u32, 1), d.first);
    try testing.expectEqual(@as(u32, 3), d.last.?);
    try testing.expect(d.state.? == .accepted);
}

test "a gap in the delivery ids breaks the run rather than settling across it" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    // Id 3 went to another link on this session, so settling 1..4 would
    // decide a delivery this caller never saw.
    try pushMessage(h.peer(), allocator, 2, 1, "t", "a", 1);
    try pushMessage(h.peer(), allocator, 2, 2, "t", "b", 2);
    try pushMessage(h.peer(), allocator, 2, 4, "t", "c", 3);

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 3, .peek_lock);
    defer batch.deinit();

    h.mem.clearWritten();
    try h.transport.settleMessages(allocator, batch.messages, .complete, .{});

    const dispositions = try emittedDispositions(allocator, h.mem.written());
    defer allocator.free(dispositions);
    try testing.expectEqual(@as(usize, 2), dispositions.len);

    var run = try amqp.performative.decode(allocator, dispositions[0]);
    defer run.deinit();
    try testing.expectEqual(@as(u32, 1), run.performative.disposition.first);
    try testing.expectEqual(@as(u32, 2), run.performative.disposition.last.?);

    var lone = try amqp.performative.decode(allocator, dispositions[1]);
    defer lone.deinit();
    try testing.expectEqual(@as(u32, 4), lone.performative.disposition.first);
    try testing.expectEqual(@as(u32, 4), lone.performative.disposition.last.?);
}

test "every settlement action maps to the outcome Service Bus reads" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    for (0..4) |i| {
        try pushMessage(h.peer(), allocator, 2, @intCast(first_incoming_id + i), "t", "m", @intCast(i));
    }

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 4, .peek_lock);
    defer batch.deinit();

    h.mem.clearWritten();
    try h.transport.settleMessages(allocator, batch.messages[0..1], .complete, .{});
    try h.transport.settleMessages(allocator, batch.messages[1..2], .abandon, .{});
    try h.transport.settleMessages(allocator, batch.messages[2..3], .defer_msg, .{});
    try h.transport.settleMessages(allocator, batch.messages[3..4], .dead_letter, .{});

    const dispositions = try emittedDispositions(allocator, h.mem.written());
    defer allocator.free(dispositions);
    try testing.expectEqual(@as(usize, 4), dispositions.len);

    var complete = try amqp.performative.decode(allocator, dispositions[0]);
    defer complete.deinit();
    try testing.expect(complete.performative.disposition.state.? == .accepted);

    // Abandon is a plain hand-back: the message failed at nothing, and it is
    // still deliverable to this consumer.
    var abandon = try amqp.performative.decode(allocator, dispositions[1]);
    defer abandon.deinit();
    const modified = abandon.performative.disposition.state.?.modified;
    try testing.expect(!modified.delivery_failed);
    try testing.expect(!modified.undeliverable_here);

    // Deferral is the same outcome with `undeliverable-here`, which is what
    // parks the message under its sequence number.
    var deferred = try amqp.performative.decode(allocator, dispositions[2]);
    defer deferred.deinit();
    try testing.expect(deferred.performative.disposition.state.?.modified.undeliverable_here);

    // Spelled out rather than compared against `dead_letter_condition`:
    // asserting a constant against itself cannot fail, and this string is a
    // wire contract with the broker, not an internal name. Any other
    // condition is read as an ordinary rejection and the message is lost.
    var dead = try amqp.performative.decode(allocator, dispositions[3]);
    defer dead.deinit();
    try testing.expectEqualStrings(
        "com.microsoft:dead-letter",
        dead.performative.disposition.state.?.rejected.?.condition,
    );
}

test "dead-lettering carries the reason and the description the broker copies" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "bad", 1);

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer batch.deinit();

    h.mem.clearWritten();
    try h.transport.settleMessages(allocator, batch.messages, .dead_letter, .{
        .reason = "ProcessingError",
        .error_description = "body was not JSON",
    });

    const dispositions = try emittedDispositions(allocator, h.mem.written());
    defer allocator.free(dispositions);
    try testing.expectEqual(@as(usize, 1), dispositions.len);

    var decoded = try amqp.performative.decode(allocator, dispositions[0]);
    defer decoded.deinit();
    const rejection = decoded.performative.disposition.state.?.rejected.?;
    try testing.expectEqualStrings("com.microsoft:dead-letter", rejection.condition);
    // The reason rides in the error's description as well as in the info map;
    // that is the field the broker surfaces on the dead-letter queue.
    try testing.expectEqualStrings("ProcessingError", rejection.description.?);
    const info = rejection.info.?;
    try testing.expectEqual(@as(usize, 2), info.len);
    try testing.expectEqualStrings(
        message_codec.application_property.dead_letter_reason,
        info[0].key.string,
    );
    try testing.expectEqualStrings("ProcessingError", info[0].value.string);
    try testing.expectEqualStrings(
        message_codec.application_property.dead_letter_description,
        info[1].key.string,
    );
    try testing.expectEqualStrings("body was not JSON", info[1].value.string);
}

test "receive_and_delete settles as it reads and does not settle twice" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    for (0..4) |i| {
        try pushMessage(h.peer(), allocator, 2, @intCast(first_incoming_id + i), "t", "m", @intCast(i));
    }

    try h.start(.{});

    // One message first, so the `$cbs` exchange and its own disposition are
    // behind us and what is counted below is only this batch's.
    var warm = try h.transport.receiveMessages(allocator, "orders", 1, .receive_and_delete);
    warm.deinit();

    h.mem.clearWritten();
    var batch = try h.transport.receiveMessages(allocator, "orders", 3, .receive_and_delete);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 3), batch.count());

    {
        const dispositions = try emittedDispositions(allocator, h.mem.written());
        defer allocator.free(dispositions);
        try testing.expectEqual(@as(usize, 1), dispositions.len);
        var decoded = try amqp.performative.decode(allocator, dispositions[0]);
        defer decoded.deinit();
        try testing.expectEqual(@as(u32, 2), decoded.performative.disposition.first);
        try testing.expectEqual(@as(u32, 4), decoded.performative.disposition.last.?);
    }

    // Settling again would decide delivery ids the broker has already
    // forgotten, and may since have reissued.
    h.mem.clearWritten();
    try h.transport.settleMessages(allocator, batch.messages, .complete, .{});
    const after = try emittedDispositions(allocator, h.mem.written());
    defer allocator.free(after);
    try testing.expectEqual(@as(usize, 0), after.len);
}

test "a quiet entity gives back an empty batch rather than an error" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    // Nothing to read once the attach is done, and the socket stays open —
    // which is exactly an empty queue.
    h.mem.starve = true;

    try h.start(.{ .deadline_ms = 1_000 });
    h.clock.auto_advance_ms = 5;

    var batch = try h.transport.receiveMessages(allocator, "orders", 10, .peek_lock);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 0), batch.count());
    // An empty batch allocated nothing, so there is nothing for `deinit` to
    // give back. This says only that nothing was *retained*; that nothing was
    // allocated and freed either is the test below.
    try testing.expect(batch.arena == null);
}

test "an empty poll allocates nothing at all, not even to throw it away" {
    // A consumer on a quiet queue polls in a loop, so the empty case is the
    // steady state rather than the exception. Reserving room for a batch
    // before knowing one is coming would charge the whole `max_count` — an
    // arena page and a precise reservation — to every one of those polls.
    // `batch.arena == null` cannot see that, because the arena would be gone
    // by the time the caller looks.
    const perf = @import("azure_sdk_core").perf;

    var counting = perf.CountingAllocator.init(testing.allocator);
    const allocator = counting.allocator();

    var h = try Harness.initSplit(allocator, testing.allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), testing.allocator);
    try scriptReceiverAttach(h.peer(), 2, "servicebus-receiver-orders");
    h.mem.starve = true;

    try h.start(.{ .deadline_ms = 1_000 });
    h.clock.auto_advance_ms = 5;

    // Warm up so the attach is not charged to the measured poll.
    var warm = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    warm.deinit();

    counting.reset();
    var batch = try h.transport.receiveMessages(allocator, "orders", max_receive_count, .peek_lock);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 0), batch.count());
    // Asked for the largest batch the transport allows, so a reservation made
    // ahead of the first message would be impossible to miss.
    try testing.expectEqual(@as(u64, 0), counting.count);
}

test "a receive larger than the transport allows is refused rather than reserved for" {
    // `max_count` sizes a credit grant and a precise reservation, so an
    // unbounded one turns a caller's typo into an arbitrary allocation and an
    // arbitrary credit grant. Event Hubs puts the same ceiling on a receive.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    h.mem.starve = true;

    try h.start(.{ .deadline_ms = 1_000 });
    h.clock.auto_advance_ms = 5;

    try testing.expectError(
        error.InvalidCount,
        h.transport.receiveMessages(allocator, "orders", max_receive_count + 1, .peek_lock),
    );
}

test "a failure part-way through keeps the messages already in hand" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, 1, "t", "a", 1);
    try pushMessage(h.peer(), allocator, 2, 2, "t", "b", 2);
    // The script ends without `starve`, so the third read is end of stream —
    // a dead connection rather than a quiet queue.

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 5, .peek_lock);
    defer batch.deinit();

    // Both arrived. Dropping them because the fifth never came would lose
    // messages the broker has already handed over.
    try testing.expectEqual(@as(usize, 2), batch.count());
    try testing.expectEqualStrings("a", batch.messages[0].body);
    try testing.expectEqualStrings("b", batch.messages[1].body);
}

test "a message that will not decode keeps the ones already taken" {
    // Not the same as a read failing. Under `receive_and_delete` the earlier
    // deliveries have already been settled `accepted` — the broker has
    // deleted them — so returning an error here would destroy messages that
    // no longer exist anywhere else. Under `peek_lock` it would wedge the
    // entity: every later receive fails at the same position once the locks
    // lapse, and the caller can never see the poison message to dead-letter
    // it because it never gets that far.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "good", 1);
    // A described type the message decoder does not model, in place of a body.
    try h.peer().pushTransfer(0, .{
        .handle = 2,
        .delivery_id = first_incoming_id + 1,
        .delivery_tag = "t",
        .message_format = 0,
        .settled = false,
        .more = false,
    }, &[_]u8{ 0x00, 0x53, 0x7e, 0x40 });

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 2, .peek_lock);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 1), batch.count());
    try testing.expectEqualStrings("good", batch.messages[0].body);

    // And the one that did arrive is still settleable.
    try h.transport.settleMessages(allocator, batch.messages, .complete, .{});
}

test "a batch that fails on its very first message frees the arena it had started" {
    // The head-of-batch case the doc comment calls out. It is the only path
    // that creates the arena and then returns an error, so it is the only
    // thing keeping `receiveMessages`' `errdefer` honest — the test above
    // always has a message in hand and so always takes the `break` arm.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try h.peer().pushTransfer(0, .{
        .handle = 2,
        .delivery_id = first_incoming_id,
        .delivery_tag = "t",
        .message_format = 0,
        .settled = false,
        .more = false,
    }, &[_]u8{ 0x00, 0x53, 0x7e, 0x40 });

    try h.start(.{});

    // The arena and its first page are already allocated by the time the
    // decode fails, so without the `errdefer` this leaks and the testing
    // allocator fails the test rather than the assertion doing it.
    try testing.expectError(
        error.UnexpectedSection,
        h.transport.receiveMessages(allocator, "orders", 2, .peek_lock),
    );
}

test "a broken connection with nothing in hand is an error, not an empty batch" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try h.start(.{});

    // A closed socket and an empty queue must not read the same to a caller.
    try testing.expectError(
        error.ConnectionClosed,
        h.transport.receiveMessages(allocator, "orders", 1, .peek_lock),
    );
}

test "the receiver link is attached once and reused across receives" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, 1, "t", "a", 1);
    try pushMessage(h.peer(), allocator, 2, 2, "t", "b", 2);

    try h.start(.{});

    var first = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer first.deinit();
    h.mem.clearWritten();

    var second = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer second.deinit();
    try testing.expectEqualStrings("b", second.messages[0].body);

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);
}

test "asking for a different receive mode re-attaches rather than reusing the link" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, 1, "t", "a", 1);
    // Dropping the old link waits for the peer's detach, so it has to come
    // before the replacement's attach or the detach would swallow it.
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    // The replacement link takes the next handle.
    try scriptReceiverAttach(h.peer(), 3, "servicebus-receiver-orders");
    try pushMessage(h.peer(), allocator, 3, 2, "t", "b", 2);

    try h.start(.{});

    var locked = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer locked.deinit();
    h.mem.clearWritten();

    // A link that settles on receipt and one that does not are different
    // links, not the same link used differently.
    var deleted = try h.transport.receiveMessages(allocator, "orders", 1, .receive_and_delete);
    defer deleted.deinit();
    try testing.expectEqualStrings("b", deleted.messages[0].body);

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);

    var decoded = try amqp.performative.decode(allocator, attaches[0]);
    defer decoded.deinit();
    try testing.expectEqual(@as(u32, 3), decoded.performative.attach.handle);
}

test "max_count is honoured and leaves the rest for the next call" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    for (0..3) |i| {
        try pushMessage(h.peer(), allocator, 2, @intCast(first_incoming_id + i), "t", "m", @intCast(i));
    }

    try h.start(.{});

    var first = try h.transport.receiveMessages(allocator, "orders", 2, .peek_lock);
    defer first.deinit();
    try testing.expectEqual(@as(usize, 2), first.count());
    try testing.expectEqual(@as(i64, 0), first.messages[0].sequence_number.?);
    try testing.expectEqual(@as(i64, 1), first.messages[1].sequence_number.?);

    var rest = try h.transport.receiveMessages(allocator, "orders", 2, .peek_lock);
    defer rest.deinit();
    try testing.expectEqual(@as(usize, 1), rest.count());
    try testing.expectEqual(@as(i64, 2), rest.messages[0].sequence_number.?);
}

test "a prefetch window grants credit up front, and no window grants exactly what is asked" {
    const allocator = testing.allocator;

    {
        var h = try Harness.init(allocator);
        defer h.deinit();
        try scriptEntityReceiver(&h, allocator, "orders");
        try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "m", 1);
        try h.start(.{});

        h.mem.clearWritten();
        var batch = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
        defer batch.deinit();

        // The bounded default window is granted on attach, so the broker may
        // stream ahead of the call that asks for the messages.
        try testing.expectEqual(receiver_prefetch_limit, (try creditFor(allocator, h.mem.written(), 2)).?);
        const receiver = h.transport.receivers.get("orders").?.receiver;
        try testing.expectEqual(@as(?u64, receiver_max_message_size), receiver.max_message_size);
        try testing.expectEqual(@as(?u64, receiver_max_buffered_bytes), receiver.max_buffered_bytes);
    }

    {
        var h = try Harness.init(allocator);
        defer h.deinit();
        try scriptEntityReceiver(&h, allocator, "orders");
        try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "m", 1);
        try h.start(.{ .prefetch = 0 });

        h.mem.clearWritten();
        var batch = try h.transport.receiveMessages(allocator, "orders", 7, .peek_lock);
        defer batch.deinit();

        // Without a window nothing else issues credit, so a receive that did
        // not ask for its own would wait out the deadline for a message the
        // broker was never allowed to send.
        try testing.expectEqual(@as(u32, 7), (try creditFor(allocator, h.mem.written(), 2)).?);
    }
}

test "settling a message with no entity is refused rather than guessed at" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "m", 1);
    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer batch.deinit();

    const orphan = sb.ServiceBusReceivedMessage{ .body = "x", .delivery_id = 9 };
    try testing.expectError(
        error.MissingEntity,
        h.transport.settleMessages(allocator, &.{orphan}, .complete, .{}),
    );

    const unknown = sb.ServiceBusReceivedMessage{ .body = "x", .delivery_id = 9, .entity = "elsewhere" };
    try testing.expectError(
        error.NoSuchReceiver,
        h.transport.settleMessages(allocator, &.{unknown}, .complete, .{}),
    );
}

/// What `azure_sdk_amqp` allocates per delivery on the receive path: the
/// payload copy and the delivery-tag copy, both of which end up in something
/// this package hands to the caller.
const amqp_receive_allocs_per_delivery = 2;

/// Encoding a replenishment Flow currently needs two temporary allocations.
const amqp_allocs_per_refill = 2;

/// What a batch costs beyond those per-delivery copies: the arena struct, its
/// first page, and the one copy of the entity name every message shares. The
/// message list and the delivery tags come out of the arena page.
const max_receive_fixed_allocs = 3;

test "a received message costs a bounded number of allocations, whatever the batch" {
    // What is counted is traffic to the *backing* allocator, so copies made
    // inside the batch's arena are deliberately invisible here — being cheap
    // is what the arena is for. The claim under test is the one that reaches
    // the allocator: a message costs the dependency's two copies and nothing
    // else that scales, so no second arena, no allocation outside it, and no
    // growth that is not amortised. Measured marginally, so every fixed
    // per-call cost cancels without needing to know what any of them are.
    const perf = @import("azure_sdk_core").perf;

    const small = 4;
    const large = 36;

    var counting = perf.CountingAllocator.init(testing.allocator);
    const allocator = counting.allocator();

    var h = try Harness.initSplit(allocator, testing.allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), testing.allocator);
    try scriptReceiverAttach(h.peer(), 2, "servicebus-receiver-orders");
    for (0..1 + small + large) |i| {
        try pushMessage(
            h.peer(),
            testing.allocator,
            2,
            @intCast(first_incoming_id + i),
            "lock-token-0123",
            "0123456789abcdef0123456789abcdef",
            @intCast(i),
        );
    }

    try h.start(.{});

    // Warm up, so the CBS exchange and the link attach are behind both
    // measured batches rather than charged to the first.
    var warm = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    warm.deinit();

    // AMQP 0.5 tracks unsettled ids both on the receiver and session-wide.
    // Reserve those dependency-owned tables up front so allocator-specific
    // growth policy is not mistaken for Service Bus's per-message cost.
    const tracked: usize = 1 + small + large;
    const receiver = h.transport.receivers.get("orders").?.receiver;
    try receiver.unsettled_ids.ensureTotalCapacityPrecise(allocator, tracked);
    try h.session.incoming_deliveries.ensureUnusedCapacity(
        allocator,
        @intCast(tracked - h.session.incoming_deliveries.count()),
    );

    h.mem.clearWritten();
    counting.reset();
    var first = try h.transport.receiveMessages(allocator, "orders", small, .peek_lock);
    const cost_small = counting.count;
    const small_refills = blk: {
        const flows = try emittedFlows(testing.allocator, h.mem.written());
        defer testing.allocator.free(flows);
        break :blk flows.len;
    };
    try testing.expectEqual(@as(usize, small), first.count());
    first.deinit();

    h.mem.clearWritten();
    counting.reset();
    var rest = try h.transport.receiveMessages(allocator, "orders", large, .peek_lock);
    const cost_large = counting.count;
    const large_refills = blk: {
        const flows = try emittedFlows(testing.allocator, h.mem.written());
        defer testing.allocator.free(flows);
        break :blk flows.len;
    };
    try testing.expectEqual(@as(usize, large), rest.count());
    rest.deinit();

    // AMQP 0.5's bounded eight-delivery window is replenished as it drains.
    // Account for those emitted Flows explicitly rather than weakening the
    // per-delivery bound: this package still adds no backing allocation that
    // scales with the batch.
    const marginal = cost_large - cost_small;
    const refill_growth =
        (large_refills - small_refills) * amqp_allocs_per_refill;
    try testing.expect(marginal <=
        (large - small) * amqp_receive_allocs_per_delivery +
            refill_growth);

    // The other half of the claim, and the discriminating half: what is left
    // once the dependency's per-delivery copies and replenishment Flows are
    // taken out is the batch's own overhead, paid once rather than per
    // message. A second arena, reservation, or per-message entity copy lands
    // here.
    //
    // No matching lower bound on `marginal`: `azure_sdk_amqp` dupes the
    // payload and the tag itself, so a lower bound of one per message would
    // be satisfied by the dependency alone whatever this code did. That the
    // messages really are copied is the lifetime test's job, not this one's.
    const fixed = cost_small -
        small * amqp_receive_allocs_per_delivery -
        small_refills * amqp_allocs_per_refill;
    try testing.expect(fixed <= max_receive_fixed_allocs);
}

test "a receiver the broker detached is re-attached rather than read from again" {
    // The sender path has the same test. The receiver path is if anything
    // worse: with no prefetch window the first thing `receiveMessages` does
    // on a cached link is `issueCredit`, so a flow naming an unbound handle
    // (§2.6.1) goes out before anything has had a chance to notice, and the
    // peer must end the whole session in reply — taking every other entity's
    // link with it.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "a", 1);
    // Behind the first message, so the receive that reads it is the one that
    // discovers the link is gone.
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    try scriptReceiverAttach(h.peer(), 3, "servicebus-receiver-orders");
    try pushMessage(h.peer(), allocator, 3, first_incoming_id + 1, "t", "b", 2);

    try h.start(.{ .prefetch = 0 });

    var first = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer first.deinit();
    try testing.expectEqualStrings("a", first.messages[0].body);

    try testing.expectError(
        error.LinkDetached,
        h.transport.receiveMessages(allocator, "orders", 1, .peek_lock),
    );
    try testing.expect(!h.transport.receivers.get("orders").?.receiver.attached);

    h.mem.clearWritten();
    var second = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer second.deinit();
    try testing.expectEqualStrings("b", second.messages[0].body);

    // The replacement was attached, and no credit was granted on the handle
    // the peer has already unbound.
    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);
    try testing.expectEqual(@as(?u32, null), try creditFor(allocator, h.mem.written(), 2));
    try testing.expectEqual(@as(?u32, 1), try creditFor(allocator, h.mem.written(), 3));

    // One entity, one link: the replacement took the old one's place rather
    // than accumulating beside it.
    try testing.expectEqual(@as(usize, 1), h.transport.receivers.count());
}

test "a settle run stops at the entity boundary, whichever entity comes first" {
    // Delivery ids come from the session and a `disposition` carries no
    // handle, so nothing about the ids themselves would stop a range from
    // spanning two entities. What must stop it is the *mode*, which belongs
    // to the link: `audit` is settled as it is read, so folding its ids in
    // with `orders`'s would settle them a second time against ids the broker
    // has already forgotten and may since have reissued.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptReceiverAttach(h.peer(), 2, "servicebus-receiver-orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "o", 1);
    // A second audience means a second claim, but the connection and the
    // `$cbs` link pair are already up.
    try scriptCbsReplyAt(h.peer(), allocator, 2, 1, 2);
    try scriptReceiverAttach(h.peer(), 3, "servicebus-receiver-audit");
    try pushMessage(h.peer(), allocator, 3, first_incoming_id + 2, "t", "a", 2);

    try h.start(.{});

    var locked = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer locked.deinit();
    var deleted = try h.transport.receiveMessages(allocator, "audit", 1, .receive_and_delete);
    defer deleted.deinit();

    const locked_id = locked.messages[0].delivery_id.?;

    // Locked entity first.
    h.mem.clearWritten();
    const locked_first = [_]sb.ServiceBusReceivedMessage{ locked.messages[0], deleted.messages[0] };
    try h.transport.settleMessages(allocator, &locked_first, .complete, .{});
    try expectOnlyDisposition(allocator, h.mem.written(), locked_id);

    // And deleted entity first, which under a single run would take its mode
    // from `audit` and settle nothing at all — the locks would simply lapse.
    h.mem.clearWritten();
    const deleted_first = [_]sb.ServiceBusReceivedMessage{ deleted.messages[0], locked.messages[0] };
    try h.transport.settleMessages(allocator, &deleted_first, .complete, .{});
    try expectOnlyDisposition(allocator, h.mem.written(), locked_id);
}

/// Assert exactly one disposition went out, covering exactly `id`.
fn expectOnlyDisposition(allocator: Allocator, written: []const u8, id: u32) !void {
    const dispositions = try emittedDispositions(allocator, written);
    defer allocator.free(dispositions);
    try testing.expectEqual(@as(usize, 1), dispositions.len);

    var decoded = try amqp.performative.decode(allocator, dispositions[0]);
    defer decoded.deinit();
    try testing.expectEqual(id, decoded.performative.disposition.first);
    try testing.expectEqual(id, decoded.performative.disposition.last.?);
}

test "a batch does not borrow the entity name it was asked for" {
    // The entity travels on every message in the batch and is what settlement
    // looks the link up by. Borrowing the caller's slice makes the batch
    // outlive its own name the moment the caller reuses that buffer, and the
    // settle that follows either misses the map or hits the wrong entry.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "m", 1);

    try h.start(.{});

    var name: [6]u8 = "orders".*;
    var batch = try h.transport.receiveMessages(allocator, &name, 1, .peek_lock);
    defer batch.deinit();

    @memset(&name, 'z');
    try testing.expectEqualStrings("orders", batch.messages[0].entity.?);

    // And it still routes: a borrowed name would look up "zzzzzz".
    try h.transport.settleMessages(allocator, batch.messages, .complete, .{});
}

test "a batch's entity survives the link it was received on being replaced" {
    // `dropReceiver` frees the `receivers` map key. A batch that borrowed it
    // rather than copying would have every message's `entity` dangling from
    // the next re-attach onwards, and `settleMessages` hashes that slice to
    // find the link — so the failure would be a lookup against freed memory,
    // not a crash.
    //
    // The replacement key is the same six bytes as the one just freed, so on
    // an ordinary allocator a dangling pointer would very likely still read
    // "orders" and the test would pass for the wrong reason. An allocator
    // that never hands freed memory back is what makes this decide anything.
    var debug: std.heap.DebugAllocator(.{
        .never_unmap = true,
        .retain_metadata = true,
    }) = .init;
    // Checked rather than discarded: this is the only test that re-attaches
    // while a batch from the old link is still held, so it is the one place a
    // leak on that path would show.
    defer testing.expect(debug.deinit() == .ok) catch @panic("leak");
    const allocator = debug.allocator();

    var h = try Harness.initSplit(allocator, testing.allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "t", "a", 1);
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    try scriptReceiverAttach(h.peer(), 3, "servicebus-receiver-orders");
    try pushMessage(h.peer(), allocator, 3, first_incoming_id + 1, "t", "b", 2);

    try h.start(.{});

    var held = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer held.deinit();

    // A mode change drops the old link, and with it the key the map was
    // holding for "orders".
    var replaced = try h.transport.receiveMessages(allocator, "orders", 1, .receive_and_delete);
    defer replaced.deinit();

    try testing.expectEqualStrings("orders", held.messages[0].entity.?);
}

// ─────────────────── Management tests ───────────────────

/// The address a `$management` link pair for `entity` is opened at.
fn managementAddress(allocator: Allocator, entity: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/$management", .{entity});
}

/// The correlation id the `n`th request on `entity`'s management link carries.
///
/// `RpcLink` derives it from the private reply address, which in turn is
/// derived from the link address and the link id, so a reply that does not
/// echo exactly this is never handed to the caller.
fn managementCorrelation(allocator: Allocator, entity: []const u8, n: u32) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/$management-reply-to-servicebus:{d}",
        .{ entity, n },
    );
}

/// Script the peer half of a `$management` link pair for `entity`.
///
/// `handle` is the sender's; the receiver takes the next one, since that is
/// the order `RpcLink.open` attaches them in.
fn scriptManagementAttach(peer: Peer, allocator: Allocator, entity: []const u8, handle: u32) !void {
    const address = try managementAddress(allocator, entity);
    defer allocator.free(address);
    const sender_name = try std.fmt.allocPrint(
        allocator,
        "{s}-sender-servicebus",
        .{address},
    );
    defer allocator.free(sender_name);
    const receiver_name = try std.fmt.allocPrint(
        allocator,
        "{s}-receiver-servicebus",
        .{address},
    );
    defer allocator.free(receiver_name);

    try scriptSenderAttach(peer, handle, sender_name, 10);
    try scriptReceiverAttach(peer, handle + 1, receiver_name);
}

/// Push the reply to the `n`th management request on `entity`.
///
/// `handle` is the client's management *receiver* handle. `request_id` and
/// `reply_id` are the outgoing and incoming delivery ids, which are allocated
/// by the session rather than the link and so have to be counted across every
/// link on it.
fn pushManagementReply(
    peer: Peer,
    allocator: Allocator,
    entity: []const u8,
    handle: u32,
    n: u32,
    request_id: u32,
    reply_id: u32,
    status: i32,
    body: ?amqp.AmqpValue,
) !void {
    try scriptAccept(peer, request_id, request_id);

    const props = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = status } },
    };
    const correlation = try managementCorrelation(allocator, entity, n);
    defer allocator.free(correlation);

    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = correlation } },
        .application_properties = &props,
        .body = if (body) |value| .{ .value = value } else .empty,
    });
    defer allocator.free(reply);

    try peer.pushTransfer(0, .{
        .handle = handle,
        .delivery_id = reply_id,
        .delivery_tag = "m",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
}

/// The request message the client sent as the `index`th transfer.
fn requestAt(allocator: Allocator, written: []const u8, index: usize) !amqp.message_codec.Decoded {
    const transfers = try emittedTransfers(allocator, written);
    defer allocator.free(transfers);
    return amqp.decodeMessage(allocator, try harness.transferPayload(allocator, transfers[index]));
}

test "scheduling sends the whole encoded message and reads back its sequence number" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    var numbers = [_]amqp.AmqpValue{.{ .long = 77 }};
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = management.body_key.sequence_numbers },
        .value = .{ .array = numbers[0..] },
    }};
    // Deliveries 1 and 1: the CBS put-token and its reply took 0 in each
    // direction, and the ids are the session's rather than the link's.
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, .{ .map = reply_body[0..] });

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "order-42");
    defer msg.deinit();
    msg.message_id = "m-42";
    msg.session_id = "s-1";

    h.mem.clearWritten();
    var out: [1]i64 = undefined;
    const n = try h.transport.scheduleMessages(allocator, "orders", &.{msg}, 1_700_000_000_000, &out);
    try testing.expectEqual(@as(usize, 1), n);
    try testing.expectEqual(@as(i64, 77), out[0]);

    // Transfer 0 is the CBS put-token: the broker refuses a management link
    // attached without a claim, so the token has to precede the request.
    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();

    try testing.expectEqualStrings(
        "com.microsoft:schedule-message",
        propertyOf(request.message, "operation").?.string,
    );
    // A uint of milliseconds, which is the shape .NET puts and the broker
    // reads. A long here is silently ignored. The value is the deadline less
    // the buffer kept back for the return leg, not the whole 60s budget.
    try testing.expectEqual(
        @as(u32, 59_000),
        propertyOf(request.message, "com.microsoft:server-timeout").?.uint,
    );

    const entries = management.bodyField(request.message.body, management.body_key.messages).?.list;
    try testing.expectEqual(@as(usize, 1), entries.len);

    var encoded: ?[]const u8 = null;
    var id: ?[]const u8 = null;
    var session_id: ?[]const u8 = null;
    for (entries[0].map) |entry| {
        if (std.mem.eql(u8, entry.key.string, "message")) encoded = entry.value.binary;
        if (std.mem.eql(u8, entry.key.string, "message-id")) id = entry.value.string;
        if (std.mem.eql(u8, entry.key.string, "session-id")) session_id = entry.value.string;
    }
    try testing.expectEqualStrings("m-42", id.?);
    try testing.expectEqualStrings("s-1", session_id.?);

    // The broker stores what it is given verbatim and delivers it later, so
    // the binary has to be the complete message — every section — rather than
    // just the body.
    var scheduled = try amqp.decodeMessage(allocator, encoded.?);
    defer scheduled.deinit();
    const got = message_codec.fromAmqpMessage(scheduled.message);
    try testing.expectEqualStrings("order-42", got.body);
    try testing.expectEqualStrings("m-42", got.message_id.?);

    // The enqueue time the call named, not whatever was left on the message.
    const when = message_codec.annotationOf(
        scheduled.message.message_annotations,
        message_codec.annotation.scheduled_enqueue_time,
    );
    try testing.expectEqual(@as(i64, 1_700_000_000_000), when.?.timestamp);
}

test "cancelling sends the sequence numbers as a typed array" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    // 200 with nothing in it: the reply to a cancel carries a status and no
    // body, and none of the other SDKs read one.
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);

    try h.start(.{});
    h.mem.clearWritten();
    try h.transport.cancelScheduled(allocator, "orders", &.{ 77, 78 });

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    try testing.expectEqualStrings(
        "com.microsoft:cancel-scheduled-message",
        propertyOf(request.message, "operation").?.string,
    );

    // An array rather than a list: every element is a long, so the broker
    // reads one constructor and then the values.
    const field = management.bodyField(request.message.body, "sequence-numbers").?;
    try testing.expectEqual(@as(usize, 2), field.array.len);
    try testing.expectEqual(@as(i64, 77), field.array[0].long);
    try testing.expectEqual(@as(i64, 78), field.array[1].long);
}

test "renewing a lock puts the delivery tag in the byte order the broker reads" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    var expirations = [_]amqp.AmqpValue{.{ .timestamp = 1_700_000_060_000 }};
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = "expirations" },
        .value = .{ .array = expirations[0..] },
    }};
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, .{ .map = reply_body[0..] });

    try h.start(.{});
    h.mem.clearWritten();

    const tag = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    const until = try h.transport.renewMessageLock(allocator, .{
        .body = "x",
        .entity = "orders",
        .delivery_tag = &tag,
    });
    try testing.expectEqual(@as(i64, 1_700_000_060_000), until);

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    try testing.expectEqualStrings(
        "com.microsoft:renew-lock",
        propertyOf(request.message, "operation").?.string,
    );

    // The tag arrives as a .NET `Guid`, whose first three fields are
    // little-endian; an AMQP uuid is RFC 4122, so those three are reversed on
    // the way out and the last eight bytes pass through. Getting this wrong is
    // silent — the broker simply does not know the token.
    const tokens = management.bodyField(request.message.body, "lock-tokens").?.array;
    try testing.expectEqual(@as(usize, 1), tokens.len);
    try testing.expectEqualSlices(
        u8,
        &.{ 3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15 },
        &tokens[0].uuid,
    );
}

test "a lock the broker has already released is reported as lost, not as a failure" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    // 410 Gone is the broker saying the lock lapsed. It is the one refusal a
    // caller can act on — the message is back on the queue and will be
    // redelivered — so it must not be flattened into a generic failure.
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 410, null);

    try h.start(.{});

    const tag = [_]u8{0} ** 16;
    try testing.expectError(error.MessageLockLost, h.transport.renewMessageLock(allocator, .{
        .body = "x",
        .entity = "orders",
        .delivery_tag = &tag,
    }));
}

test "a delivery tag that is not a lock token is refused before anything is sent" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try harness.scriptHandshake(h.peer(), max_frame_size);
    try h.start(.{});
    h.mem.clearWritten();

    const short = [_]u8{ 1, 2, 3 };
    try testing.expectError(error.InvalidLockToken, h.transport.renewMessageLock(allocator, .{
        .body = "x",
        .entity = "orders",
        .delivery_tag = &short,
    }));
    // Nothing went out: not the claim, not the attach, not the request.
    try testing.expectEqual(@as(usize, 0), h.mem.written().len);

    try testing.expectError(error.MissingLockToken, h.transport.renewMessageLock(allocator, .{
        .body = "x",
        .entity = "orders",
    }));
    try testing.expectError(error.MissingEntity, h.transport.renewMessageLock(allocator, .{
        .body = "x",
        .delivery_tag = &[_]u8{0} ** 16,
    }));
}

/// A `peek-message` reply body carrying `count` messages, each numbered from
/// `first_sequence`.
///
/// The arena owns the encodings and the tree over them, so the caller frees
/// one thing rather than walking it.
fn peekReplyBody(
    arena: Allocator,
    first_sequence: i64,
    delivery_count: u32,
    count: usize,
) !amqp.AmqpValue {
    const items = try arena.alloc(amqp.AmqpValue, count);
    for (items, 0..) |*slot, i| {
        const annotations = try arena.alloc(amqp.MapEntry, 1);
        annotations[0] = .{
            .key = .{ .symbol = message_codec.annotation.sequence_number },
            .value = .{ .long = first_sequence + @as(i64, @intCast(i)) },
        };
        const sections = try arena.alloc([]const u8, 1);
        sections[0] = try std.fmt.allocPrint(arena, "peeked-{d}", .{i});
        const encoded = try amqp.encodeMessageAlloc(arena, .{
            .header = .{ .delivery_count = delivery_count },
            .message_annotations = annotations,
            .body = .{ .data = sections },
        });

        const fields = try arena.alloc(amqp.MapEntry, 1);
        fields[0] = .{
            .key = .{ .string = management.body_key.message },
            .value = .{ .binary = encoded },
        };
        slot.* = .{ .map = fields };
    }

    const outer = try arena.alloc(amqp.MapEntry, 1);
    outer[0] = .{
        .key = .{ .string = management.body_key.messages },
        .value = .{ .list = items },
    };
    return .{ .map = outer };
}

test "peeking decodes what came back and reports the delivery count unchanged" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    const body = try peekReplyBody(scratch.allocator(), 500, 3, 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, body);

    try h.start(.{});
    h.mem.clearWritten();

    var batch = try h.transport.peekMessages(allocator, "orders", 500, 10);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 2), batch.count());

    try testing.expectEqualStrings("peeked-0", batch.messages[0].body);
    try testing.expectEqualStrings("peeked-1", batch.messages[1].body);
    try testing.expectEqual(@as(?i64, 500), batch.messages[0].sequence_number);
    try testing.expectEqual(@as(?i64, 501), batch.messages[1].sequence_number);
    try testing.expectEqualStrings("orders", batch.messages[0].entity.?);

    // A peek is not a delivery, so there is no lock to settle and no id to
    // settle it by. Handing one back would let a caller build a disposition
    // naming a delivery that never happened.
    try testing.expectEqual(@as(?u32, null), batch.messages[0].delivery_id);
    try testing.expectEqual(@as(?[]const u8, null), batch.messages[0].delivery_tag);

    // The raw header value, not the received path's `+ 1`. That increment
    // exists because a delivery in hand is one the header has not counted yet;
    // a peek has no delivery, so the header is already the whole truth.
    try testing.expectEqual(@as(?u32, 3), batch.messages[0].delivery_count);

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    try testing.expectEqualStrings(
        "com.microsoft:peek-message",
        propertyOf(request.message, "operation").?.string,
    );
    try testing.expectEqual(
        @as(i64, 500),
        management.bodyField(request.message.body, "from-sequence-number").?.long,
    );
    // An int, not a long: the broker reads a 32-bit count here.
    try testing.expectEqual(
        @as(i32, 10),
        management.bodyField(request.message.body, "message-count").?.int,
    );
}

test "an empty peek is an empty batch, and keeps no arena for it" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    // 204 with no body at all is how the broker answers a peek past the end
    // of the queue. `rpc.checkStatus` takes any 2xx, so the only thing to
    // handle is the missing body.
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 204, null);

    try h.start(.{});

    var batch = try h.transport.peekMessages(allocator, "orders", 9_999, 10);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 0), batch.count());
    try testing.expect(batch.arena == null);
}

test "a peek larger than the broker's count field allows is refused rather than truncated" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    // Only the handshake: neither call below should reach the point of
    // authorising an entity or attaching a link.
    try harness.scriptHandshake(h.peer(), max_frame_size);
    try h.start(.{});
    h.mem.clearWritten();

    try testing.expectError(
        error.InvalidCount,
        h.transport.peekMessages(allocator, "orders", 0, max_receive_count + 1),
    );

    // Zero is not an error, just nothing to do, and it must not reach the wire.
    var none = try h.transport.peekMessages(allocator, "orders", 0, 0);
    defer none.deinit();
    try testing.expectEqual(@as(usize, 0), none.count());
    try testing.expectEqual(@as(usize, 0), h.mem.written().len);
}

test "the management link is attached once and reused across operations" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 2, 2, 2, 200, null);

    try h.start(.{});

    try h.transport.cancelScheduled(allocator, "orders", &.{77});
    h.mem.clearWritten();
    try h.transport.cancelScheduled(allocator, "orders", &.{78});

    // Nothing re-attached, and no second claim was put: the cached pair was
    // already authorised and still bound.
    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);
    try testing.expectEqual(@as(usize, 1), h.transport.managers.count());

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);
}

test "a management link the broker detached is re-attached rather than written to again" {
    // §2.6.1 unbinds the handle at detach, so a request written to it is a
    // transfer on an unbound handle — which ends the whole session and takes
    // every other entity's link with it.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);
    // Behind the first reply, so the call that reads it succeeds and the next
    // one is what discovers the pair is gone. Both halves: a broker ending a
    // management link ends both, and `Receiver.detach` pumps until the peer's
    // own detach arrives, so a receiver still believed attached would eat the
    // replacement's frames looking for one.
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    try h.peer().push(0, .{ .detach = .{ .handle = 3, .closed = true } });
    try scriptManagementAttach(h.peer(), allocator, "orders", 4);
    // The replacement is a new link pair, so its request ids restart at 1
    // even though the session's delivery ids carry on.
    try pushManagementReply(h.peer(), allocator, "orders", 5, 1, 2, 2, 200, null);

    try h.start(.{});

    try h.transport.cancelScheduled(allocator, "orders", &.{77});
    // Reading the detaches is what marks the links, so drive them through
    // before the next call looks at the cache.
    _ = h.session.pump(10_000) catch {};
    _ = h.session.pump(10_000) catch {};
    try testing.expect(!h.transport.managers.get("orders").?.rpc.sender.attached);
    try testing.expect(!h.transport.managers.get("orders").?.rpc.receiver.attached);

    h.mem.clearWritten();
    try h.transport.cancelScheduled(allocator, "orders", &.{78});

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 2), attaches.len);

    // One entity, one pair: the replacement took the old one's place rather
    // than accumulating beside it.
    try testing.expectEqual(@as(usize, 1), h.transport.managers.count());
}

test "scheduling names the sender link it acts for when one is open" {
    // The broker uses `associated-link-name` to tie the operation to the link
    // whose session and partition it concerns, so scheduling must name the
    // sender and not, say, a receiver on the same entity.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptSenderAttach(h.peer(), 2, "servicebus-sender-orders", 10);
    try scriptAccept(h.peer(), 1, 1);
    try scriptManagementAttach(h.peer(), allocator, "orders", 3);
    var numbers = [_]amqp.AmqpValue{.{ .long = 5 }};
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = "sequence-numbers" },
        .value = .{ .array = numbers[0..] },
    }};
    try pushManagementReply(h.peer(), allocator, "orders", 4, 1, 2, 1, 200, .{ .map = reply_body[0..] });

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    try h.transport.sendMessages(allocator, "orders", &.{msg});

    h.mem.clearWritten();
    var out: [1]i64 = undefined;
    _ = try h.transport.scheduleMessages(allocator, "orders", &.{msg}, 1_700_000_000_000, &out);

    var request = try requestAt(allocator, h.mem.written(), 0);
    defer request.deinit();
    try testing.expectEqualStrings(
        "servicebus-sender-orders",
        propertyOf(request.message, "associated-link-name").?.string,
    );
}

test "renewing a lock names the receiver link the message came in on" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptEntityReceiver(&h, allocator, "orders");
    try pushMessage(h.peer(), allocator, 2, first_incoming_id, "0123456789abcdef", "a", 1);
    try scriptManagementAttach(h.peer(), allocator, "orders", 3);
    var expirations = [_]amqp.AmqpValue{.{ .timestamp = 42 }};
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = "expirations" },
        .value = .{ .array = expirations[0..] },
    }};
    // The message took incoming delivery 1, so the reply takes 2.
    try pushManagementReply(h.peer(), allocator, "orders", 4, 1, 1, 2, 200, .{ .map = reply_body[0..] });

    try h.start(.{});

    var batch = try h.transport.receiveMessages(allocator, "orders", 1, .peek_lock);
    defer batch.deinit();

    h.mem.clearWritten();
    _ = try h.transport.renewMessageLock(allocator, batch.messages[0]);

    var request = try requestAt(allocator, h.mem.written(), 0);
    defer request.deinit();
    try testing.expectEqualStrings(
        "servicebus-receiver-orders",
        propertyOf(request.message, "associated-link-name").?.string,
    );
}

test "an operation with no entity link open omits the association rather than inventing one" {
    // Go omits the property when there is no link to name. Sending an empty
    // string or the management link's own name would both be claims about a
    // link that is not carrying the message.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);

    try h.start(.{});
    h.mem.clearWritten();
    try h.transport.cancelScheduled(allocator, "orders", &.{77});

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    try testing.expectEqual(
        @as(?amqp.AmqpValue, null),
        propertyOf(request.message, "associated-link-name"),
    );
}

test "scheduling a run costs one round trip and answers one number per message" {
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    var numbers = [_]amqp.AmqpValue{
        .{ .long = 10 },
        .{ .long = 11 },
        .{ .long = 12 },
    };
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = "sequence-numbers" },
        .value = .{ .array = numbers[0..] },
    }};
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, .{ .map = reply_body[0..] });

    try h.start(.{});

    var a = sb.ServiceBusMessage.init(allocator, "a");
    defer a.deinit();
    var b = sb.ServiceBusMessage.init(allocator, "b");
    defer b.deinit();
    var c = sb.ServiceBusMessage.init(allocator, "c");
    defer c.deinit();

    h.mem.clearWritten();
    var out: [3]i64 = undefined;
    const n = try h.transport.scheduleMessages(allocator, "orders", &.{ a, b, c }, 1, &out);
    try testing.expectEqual(@as(usize, 3), n);
    try testing.expectEqualSlices(i64, &.{ 10, 11, 12 }, &out);

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    const entries = management.bodyField(request.message.body, "messages").?.list;
    try testing.expectEqual(@as(usize, 3), entries.len);

    // `Scratch` holds one live message at a time, so each is encoded and
    // copied out before the next overwrites it. If it were not, every entry
    // would carry the last message's bytes.
    const bodies = [_][]const u8{ "a", "b", "c" };
    for (entries, bodies) |entry, expected| {
        var encoded: ?[]const u8 = null;
        for (entry.map) |field| {
            if (std.mem.eql(u8, field.key.string, "message")) encoded = field.value.binary;
        }
        var decoded = try amqp.decodeMessage(allocator, encoded.?);
        defer decoded.deinit();
        try testing.expectEqualStrings(expected, message_codec.fromAmqpMessage(decoded.message).body);
    }

    // Two transfers only: the claim and the one request.
    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 2), transfers.len);
}

test "a schedule reply with no number for a message is a malformed reply, not a zero" {
    // The sequence number is what a caller cancels by, so inventing one — or
    // handing back a default — would leave them holding an id the broker
    // never issued.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    var empty = [_]amqp.AmqpValue{};
    var reply_body = [_]amqp.MapEntry{.{
        .key = .{ .string = "sequence-numbers" },
        .value = .{ .array = empty[0..] },
    }};
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, .{ .map = reply_body[0..] });

    try h.start(.{});

    var msg = sb.ServiceBusMessage.init(allocator, "x");
    defer msg.deinit();
    var client = sb.ServiceBusSenderClient.init(
        "ns.servicebus.windows.net",
        "orders",
        &h.transport.transport,
    );
    try testing.expectError(
        error.MalformedReply,
        client.scheduleMessage(allocator, msg, 1_700_000_000_000),
    );
}

test "an expired claim is renewed on a management link that is already attached" {
    // The same hazard as on a sender: a claim expires while the pair stays
    // attached, and the broker detaches it when it does. Authorising only at
    // attach time works in every test that runs inside one token lifetime and
    // strands a real client an hour in.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);

    // The renewal: put-token is outgoing delivery 2 and its reply is the
    // second request on the CBS link, taking incoming delivery 2.
    try scriptAccept(h.peer(), 2, 2);
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
        .delivery_id = 2,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 2, 3, 3, 200, null);

    try h.start(.{});

    try h.transport.cancelScheduled(allocator, "orders", &.{77});
    try testing.expectEqual(@as(usize, 1), h.credential.calls);

    h.mem.clearWritten();
    test_now_ms = stub_token_expires_on * std.time.ms_per_s + 1;
    try h.transport.cancelScheduled(allocator, "orders", &.{78});

    // A fresh token was minted and put, and the pair was not re-attached to
    // get it: two transfers, the put-token and the request, and no attach.
    try testing.expectEqual(@as(usize, 2), h.credential.calls);

    const attaches = try emittedAttaches(allocator, h.mem.written());
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 0), attaches.len);

    const transfers = try emittedTransfers(allocator, h.mem.written());
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 2), transfers.len);
}

test "a peeked batch does not borrow the entity name it was asked for" {
    // `ServiceBusReceiverClient.peekMessages` formats the address, passes it
    // in, and frees it on return. A batch that kept that slice would hand
    // back messages whose `entity` dangles the moment the call returns —
    // and the caller is invited to read it, since it is how a received
    // message names where it came from.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    const body = try peekReplyBody(scratch.allocator(), 500, 3, 1);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, body);

    try h.start(.{});

    var name: [6]u8 = "orders".*;
    var batch = try h.transport.peekMessages(allocator, &name, 500, 10);
    defer batch.deinit();
    try testing.expectEqual(@as(usize, 1), batch.count());

    @memset(&name, 'z');
    try testing.expectEqualStrings("orders", batch.messages[0].entity.?);
}

test "closing detaches the management links and drops them from the session" {
    // `RpcLink.deinit` frees only the pair's own bookkeeping; the two links
    // belong to the session. Freeing the pair without closing its links
    // leaves them attached at the broker and still registered here, so the
    // session goes on pumping frames into a link whose owner is gone.
    // `Cbs` gets away with a bare `deinit` only because it is never reopened;
    // a management pair is reopened on the next operation.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);
    // The peer's own detaches, so `detach` does not wait out its deadline.
    try h.peer().push(0, .{ .detach = .{ .handle = 3, .closed = true } });
    try h.peer().push(0, .{ .detach = .{ .handle = 2, .closed = true } });
    try h.peer().push(0, .{ .detach = .{ .handle = 1, .closed = true } });
    try h.peer().push(0, .{ .detach = .{ .handle = 0, .closed = true } });

    try h.start(.{});
    try h.transport.cancelScheduled(allocator, "orders", &.{77});

    // Two links in the session for CBS and two for management.
    try testing.expectEqual(@as(usize, 2), h.session.senders.items.len);
    try testing.expectEqual(@as(usize, 2), h.session.receivers.items.len);

    h.mem.clearWritten();
    h.transport.transport.close();

    // `Cbs.close` detaches its pair but leaves it registered, so what the
    // session is left holding is exactly the CBS pair.
    try testing.expectEqual(@as(usize, 1), h.session.senders.items.len);
    try testing.expectEqual(@as(usize, 1), h.session.receivers.items.len);

    const detaches = try emittedDetaches(allocator, h.mem.written());
    defer allocator.free(detaches);
    try testing.expectEqual(@as(usize, 4), detaches.len);
}

test "a broker that returns more than was peeked for does not get to hand them on" {
    // `message-count` is what the request asks for, not a promise about the
    // reply. A caller that asked for two sized whatever it does next for two,
    // so a longer reply is cut back rather than passed through.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    const body = try peekReplyBody(scratch.allocator(), 500, 0, 5);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, body);

    try h.start(.{});

    var batch = try h.transport.peekMessages(allocator, "orders", 500, 2);
    defer batch.deinit();

    try testing.expectEqual(@as(usize, 2), batch.count());
    try testing.expectEqualStrings("peeked-0", batch.messages[0].body);
    try testing.expectEqualStrings("peeked-1", batch.messages[1].body);
}

test "two entities' management pairs are told apart by address, not by link id" {
    // Every management pair is opened with the transport's one link id, so
    // what keeps two entities' replies apart is the address: `RpcLink` derives
    // the link names and the private reply address from it, and the address
    // carries the entity. If that were not enough, each pair would be handed
    // the other's replies — so this scripts both and checks each answer
    // reaches the call that asked for it.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    const orders_body = try peekReplyBody(scratch.allocator(), 500, 0, 1);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, orders_body);

    try scriptCbsReplyAt(h.peer(), allocator, 2, 2, 2);
    try scriptManagementAttach(h.peer(), allocator, "billing", 4);
    const billing_body = try peekReplyBody(scratch.allocator(), 900, 0, 1);
    try pushManagementReply(h.peer(), allocator, "billing", 5, 1, 3, 3, 200, billing_body);

    try h.start(.{});

    var first = try h.transport.peekMessages(allocator, "orders", 500, 5);
    defer first.deinit();
    var second = try h.transport.peekMessages(allocator, "billing", 900, 5);
    defer second.deinit();

    // The sequence numbers are what say which entity answered: each reply
    // reached the pair that asked for it rather than the other one.
    try testing.expectEqual(@as(?i64, 500), first.messages[0].sequence_number);
    try testing.expectEqual(@as(?i64, 900), second.messages[0].sequence_number);
    try testing.expectEqual(@as(usize, 2), h.transport.managers.count());
}

test "the server timeout is what is left of the deadline, less the return leg" {
    // The broker's timer starts when the request lands, which is after the
    // dial, the claim and the attach the call may have had to do first.
    // Sending the whole configured budget would have the broker give up
    // strictly later than the caller — the case the property exists to
    // prevent — so what goes out is measured against the clock at the moment
    // the request is built, not at the moment the deadline was taken.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try harness.scriptHandshake(h.peer(), max_frame_size);
    try h.start(.{});

    const deadline = h.transport.deadlineFrom(h.session);

    // Nothing has been spent yet: the whole budget less the return leg.
    try testing.expectEqual(
        @as(u32, 60_000 - 1_000),
        AmqpTransport.serverTimeoutMs(h.session, deadline),
    );

    // Setup spent four seconds, and the broker only gets what is left.
    h.clock.advance(4_000);
    try testing.expectEqual(
        @as(u32, 60_000 - 4_000 - 1_000),
        AmqpTransport.serverTimeoutMs(h.session, deadline),
    );

    // Under a second left there is no room for the broker to answer first, so
    // the buffer stops helping rather than underflowing into a huge unsigned
    // timeout — which is how a broker would read a negative value.
    h.clock.advance(55_500);
    try testing.expectEqual(
        @as(u32, 0),
        AmqpTransport.serverTimeoutMs(h.session, deadline),
    );

    // And past the deadline entirely, still zero rather than wrapping.
    h.clock.advance(10_000);
    try testing.expectEqual(
        @as(u32, 0),
        AmqpTransport.serverTimeoutMs(h.session, deadline),
    );
}

test "what reaches the wire comes from the clock, not from the configured budget" {
    // The unit test above pins the arithmetic; this one pins that the wire
    // sees the result of it. A timeout computed from `deadline_ms` alone
    // would be the same number on every call however long the claim and the
    // attach took, and a clock that ticks on every read is what tells the two
    // apart: the value that goes out has to be strictly under the budget less
    // the buffer, because setup has already read the clock several times by
    // the point the request is built.
    //
    // How far under is not asserted. That depends on how many times the dial,
    // claim and attach path happens to read the clock, which belongs to
    // `azure_sdk_amqp` and would make this test fail on a change with nothing
    // to do with it. So what is checked is the side of the boundary: time was
    // spent, and there is still something left to give the broker.
    const allocator = testing.allocator;
    var h = try Harness.init(allocator);
    defer h.deinit();

    try scriptCbsExchange(h.peer(), allocator);
    try scriptManagementAttach(h.peer(), allocator, "orders", 2);
    try pushManagementReply(h.peer(), allocator, "orders", 3, 1, 1, 1, 200, null);

    try h.start(.{});
    h.clock.auto_advance_ms = 100;

    try h.transport.cancelScheduled(allocator, "orders", &.{77});

    var request = try requestAt(allocator, h.mem.written(), 1);
    defer request.deinit();
    const sent = propertyOf(request.message, "com.microsoft:server-timeout").?.uint;

    // Off the clock at build time this is strictly under; off the configured
    // budget it would be exactly the boundary.
    try testing.expect(sent < 60_000 - server_timeout_buffer_ms);
    try testing.expect(sent > 0);
}
