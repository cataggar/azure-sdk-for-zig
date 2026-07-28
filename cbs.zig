//! Claims-Based Security: authorising a path over the `$cbs` endpoint.
//!
//! Event Hubs carries no credential in the AMQP SASL exchange — the driver
//! authenticates anonymously — so every entity has to be authorised separately
//! by putting a token to `$cbs` before any link on that path attaches. The
//! token is a SAS signature or an AAD JWT; acquiring it is the credential's
//! job, not this module's.

const std = @import("std");
const Allocator = std.mem.Allocator;

const link = @import("link.zig");
const message = @import("message.zig");
const perf = @import("performative.zig");
const rpc = @import("rpc.zig");
const uamqp = @import("uamqp");

const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;

pub const address = "$cbs";

pub const operation_key = "operation";
pub const put_token_operation = "put-token";
pub const token_type_key = "type";
pub const audience_key = "name";
pub const expiration_key = "expiration";

pub const CbsError = rpc.RpcError || error{
    /// No token has been cached for the requested audience.
    NotAuthorized,
};

/// The token kinds Azure accepts over CBS.
pub const TokenType = enum {
    sas,
    jwt,

    pub fn toString(self: TokenType) []const u8 {
        return switch (self) {
            .sas => "servicebus.windows.net:sastoken",
            .jwt => "jwt",
        };
    }
};

pub const AccessToken = struct {
    /// The signature or bearer token itself.
    token: []const u8,
    /// Expiry as milliseconds since the Unix epoch.
    expires_on_ms: i64,
    kind: TokenType,
    /// False for a pre-formed SAS supplied in a connection string. Refreshing
    /// one returns the same expiry it already had, so scheduling a refresh
    /// would spin without ever extending it. The broker still enforces the
    /// real expiry, and recovery re-authorises the path if a link drops.
    refreshable: bool = true,
};

/// Supplies tokens on demand. A function-pointer struct so a credential can
/// back it without this module depending on the credential type.
pub const TokenProvider = struct {
    ctx: *anyopaque,
    getTokenFn: *const fn (ctx: *anyopaque, audience: []const u8) anyerror!AccessToken,

    pub fn getToken(self: TokenProvider, audience: []const u8) anyerror!AccessToken {
        return self.getTokenFn(self.ctx, audience);
    }
};

/// When to refresh, relative to expiry. The defaults match the Rust client.
pub const RefreshPolicy = struct {
    /// Refresh this long before the token expires.
    bias_ms: i64 = 6 * std.time.ms_per_min,
    /// Jitter added to the bias, so a fleet of clients does not stampede.
    /// The minimum is negative, meaning it can push the refresh later.
    jitter_min_ms: i64 = -5 * std.time.ms_per_s,
    jitter_max_ms: i64 = 5 * std.time.ms_per_s,
    /// How long to wait before retrying a refresh that failed.
    failure_backoff_ms: i64 = 30 * std.time.ms_per_s,
};

/// The instant a token expiring at `expires_on_ms` should be refreshed.
pub fn refreshAtMs(policy: RefreshPolicy, expires_on_ms: i64, jitter_ms: i64) i64 {
    return expires_on_ms -| (policy.bias_ms +| jitter_ms);
}

const CachedToken = struct {
    token: []const u8,
    expires_on_ms: i64,
    kind: TokenType,
    refreshable: bool,
    /// When a refresh is next due, or null when the token cannot be renewed.
    refresh_at_ms: ?i64,

    fn deinit(self: CachedToken, allocator: Allocator) void {
        allocator.free(self.token);
    }
};

pub const Options = struct {
    /// Distinguishes this link pair from any other on the connection.
    link_id: []const u8,
    policy: RefreshPolicy = .{},
    /// Seed for the refresh jitter. Fixed in tests for determinism.
    jitter_seed: u64 = 0,
};

/// A `$cbs` client: the RPC link pair plus a per-audience token cache.
pub const Cbs = struct {
    allocator: Allocator,
    rpc_link: *rpc.RpcLink,
    policy: RefreshPolicy,
    prng: std.Random.DefaultPrng,
    /// Cached tokens keyed by audience. Both keys and values are owned.
    tokens: std.StringHashMapUnmanaged(CachedToken) = .empty,

    pub fn open(
        session: *link.Session,
        options: Options,
        deadline_ms: i64,
    ) CbsError!*Cbs {
        const allocator = session.allocator;
        const self = try allocator.create(Cbs);
        errdefer allocator.destroy(self);

        const rpc_link = try rpc.RpcLink.open(session, .{
            .address = address,
            .link_id = options.link_id,
        }, deadline_ms);
        errdefer rpc_link.deinit();

        self.* = .{
            .allocator = allocator,
            .rpc_link = rpc_link,
            .policy = options.policy,
            .prng = std.Random.DefaultPrng.init(options.jitter_seed),
        };
        return self;
    }

    pub fn deinit(self: *Cbs) void {
        var it = self.tokens.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.tokens.deinit(self.allocator);
        self.rpc_link.deinit();
        self.allocator.destroy(self);
    }

    pub fn close(self: *Cbs, deadline_ms: i64) CbsError!void {
        try self.rpc_link.close(deadline_ms);
    }

    /// Put a token to `$cbs` for `audience`, unconditionally.
    ///
    /// The application-property map matches Go's exactly: `operation`,
    /// `type`, `name`, and `expiration`, with the token as the message value.
    pub fn putToken(
        self: *Cbs,
        audience: []const u8,
        token: AccessToken,
        deadline_ms: i64,
    ) CbsError!void {
        const props = [_]MapEntry{
            .{
                .key = .{ .string = operation_key },
                .value = .{ .string = put_token_operation },
            },
            .{
                .key = .{ .string = token_type_key },
                .value = .{ .string = token.kind.toString() },
            },
            .{
                .key = .{ .string = audience_key },
                .value = .{ .string = audience },
            },
            .{
                .key = .{ .string = expiration_key },
                .value = .{ .timestamp = token.expires_on_ms },
            },
        };

        var response = try self.rpc_link.call(.{
            .application_properties = &props,
            .body = .{ .value = .{ .string = token.token } },
        }, deadline_ms);
        defer response.deinit();

        try rpc.checkStatus(response.status_code);
    }

    /// Authorise `audience`, reusing the cached token when it is still good.
    ///
    /// The provider is only consulted when a round-trip is actually needed, so
    /// a cache hit costs nothing.
    pub fn authorize(
        self: *Cbs,
        audience: []const u8,
        provider: TokenProvider,
        now_ms: i64,
        deadline_ms: i64,
    ) !void {
        if (self.tokens.get(audience)) |cached| {
            if (!isStale(cached, now_ms)) return;
        }
        const token = try provider.getToken(audience);
        try self.putToken(audience, token, deadline_ms);
        try self.store(audience, token);
    }

    /// Re-put every cached token that has come due, and report when the next
    /// refresh is owed so a caller can decide how long to wait.
    ///
    /// A failure backs the audience off rather than propagating, because one
    /// unreachable audience must not stop the others from being renewed.
    pub fn refreshDue(
        self: *Cbs,
        provider: TokenProvider,
        now_ms: i64,
        deadline_ms: i64,
    ) !void {
        var it = self.tokens.iterator();
        while (it.next()) |entry| {
            const refresh_at = entry.value_ptr.refresh_at_ms orelse continue;
            if (now_ms < refresh_at) continue;

            const audience = entry.key_ptr.*;
            const token = provider.getToken(audience) catch {
                entry.value_ptr.refresh_at_ms = now_ms +| self.policy.failure_backoff_ms;
                continue;
            };
            self.putToken(audience, token, deadline_ms) catch |e| switch (e) {
                // A refused credential will not start working on a retry.
                error.Unauthorized => return e,
                else => {
                    entry.value_ptr.refresh_at_ms = now_ms +| self.policy.failure_backoff_ms;
                    continue;
                },
            };
            try self.store(audience, token);
            // `store` replaces the entry in place, so the iterator stays valid.
            it = self.tokens.iterator();
        }
    }

    /// The earliest instant at which any cached token needs refreshing, or
    /// null when nothing is refreshable.
    pub fn nextRefreshAtMs(self: *Cbs) ?i64 {
        var earliest: ?i64 = null;
        var it = self.tokens.valueIterator();
        while (it.next()) |value| {
            const at = value.refresh_at_ms orelse continue;
            if (earliest == null or at < earliest.?) earliest = at;
        }
        return earliest;
    }

    /// The cached token for `audience`, if any.
    pub fn cachedToken(self: *Cbs, audience: []const u8) ?AccessToken {
        const cached = self.tokens.get(audience) orelse return null;
        return .{
            .token = cached.token,
            .expires_on_ms = cached.expires_on_ms,
            .kind = cached.kind,
            .refreshable = cached.refreshable,
        };
    }

    /// Drop every cached token, forcing re-authorisation. Used after a
    /// connection is recovered, since the new connection carries no claims.
    pub fn invalidateAll(self: *Cbs) void {
        var it = self.tokens.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.tokens.clearRetainingCapacity();
    }

    fn store(self: *Cbs, audience: []const u8, token: AccessToken) Allocator.Error!void {
        const owned_token = try self.allocator.dupe(u8, token.token);
        errdefer self.allocator.free(owned_token);

        const refresh_at: ?i64 = if (token.refreshable)
            refreshAtMs(self.policy, token.expires_on_ms, self.jitter())
        else
            null;

        const entry = try self.tokens.getOrPut(self.allocator, audience);
        if (entry.found_existing) {
            entry.value_ptr.deinit(self.allocator);
        } else {
            entry.key_ptr.* = self.allocator.dupe(u8, audience) catch |e| {
                _ = self.tokens.remove(audience);
                return e;
            };
        }
        entry.value_ptr.* = .{
            .token = owned_token,
            .expires_on_ms = token.expires_on_ms,
            .kind = token.kind,
            .refreshable = token.refreshable,
            .refresh_at_ms = refresh_at,
        };
    }

    fn jitter(self: *Cbs) i64 {
        const min = self.policy.jitter_min_ms;
        const max = self.policy.jitter_max_ms;
        if (max <= min) return 0;
        return self.prng.random().intRangeLessThan(i64, min, max);
    }
};

/// A cached token is stale once its refresh time has passed, or once it has
/// actually expired. A non-refreshable token is only stale when expired.
fn isStale(cached: CachedToken, now_ms: i64) bool {
    if (now_ms >= cached.expires_on_ms) return true;
    const refresh_at = cached.refresh_at_ms orelse return false;
    return now_ms >= refresh_at;
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const connection = @import("connection.zig");
const harness = @import("test_peer.zig");
const MemoryTransport = @import("transport.zig").MemoryTransport;
const Peer = harness.Peer;
const Fixture = harness.Fixture;
const EmittedFrames = harness.EmittedFrames;

/// A provider handing out a fixed token, counting how often it was asked.
const StubProvider = struct {
    token: AccessToken,
    calls: usize = 0,

    fn get(ctx: *anyopaque, audience: []const u8) anyerror!AccessToken {
        _ = audience;
        const self: *StubProvider = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        return self.token;
    }

    fn provider(self: *StubProvider) TokenProvider {
        return .{ .ctx = self, .getTokenFn = get };
    }
};

/// Script the peer's side of opening a `$cbs` link pair: an attach for each
/// link, then credit for the sender.
fn scriptCbsAttach(peer: Peer) !void {
    try harness.scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-sender-test",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-receiver-test",
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
}

/// Push the peer's answer to request `n`: a disposition settling the request,
/// then the reply carrying `status`, correlated back to it.
///
/// The disposition is what a real broker sends — the sender leaves the
/// transfer unsettled and blocks on the outcome, as Go's RPC link does.
fn scriptCbsReply(peer: Peer, allocator: Allocator, n: u64, status: i32) !void {
    const delivery_id: u32 = @intCast(n - 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = delivery_id,
        .last = delivery_id,
        .settled = true,
        .state = .accepted,
    } });

    var id_buf: [64]u8 = undefined;
    const correlation = try std.fmt.bufPrint(&id_buf, "cbs-reply-to-test:{d}", .{n});
    const props = [_]MapEntry{
        .{ .key = .{ .string = rpc.status_code_key }, .value = .{ .int = status } },
        .{
            .key = .{ .string = rpc.status_description_key },
            .value = .{ .string = if (status == 202) "Accepted" else "Unauthorized" },
        },
    };
    const payload = try message.encodeAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = correlation } },
        .application_properties = &props,
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

/// The application properties of the single put-token request the driver sent.
fn sentPutTokenProperties(allocator: Allocator, written: []const u8) !message.Decoded {
    var frames = try EmittedFrames.parse(allocator, written);
    defer frames.deinit();

    const transfers = try frames.of(allocator, 0x14);
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);

    const payload = harness.transferPayload(allocator, transfers[0]).?;
    return message.decode(allocator, payload);
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

test "token types use the strings Azure expects" {
    try testing.expectEqualStrings("servicebus.windows.net:sastoken", TokenType.sas.toString());
    try testing.expectEqualStrings("jwt", TokenType.jwt.toString());
}

test "the refresh instant sits a biased interval ahead of expiry" {
    const policy = RefreshPolicy{};
    const expiry: i64 = 3_600_000;
    // Six minutes ahead of expiry, with no jitter.
    try testing.expectEqual(@as(i64, 3_600_000 - 360_000), refreshAtMs(policy, expiry, 0));
    // Jitter is added to the bias, so a positive value refreshes earlier and a
    // negative one later, spreading a fleet's renewals either side of the bias.
    try testing.expectEqual(@as(i64, 3_600_000 - 365_000), refreshAtMs(policy, expiry, 5_000));
    try testing.expectEqual(@as(i64, 3_600_000 - 355_000), refreshAtMs(policy, expiry, -5_000));
}

test "a token is stale once its refresh time passes but a fixed one only at expiry" {
    const refreshable = CachedToken{
        .token = "t",
        .expires_on_ms = 1_000_000,
        .kind = .jwt,
        .refreshable = true,
        .refresh_at_ms = 640_000,
    };
    try testing.expect(!isStale(refreshable, 639_999));
    try testing.expect(isStale(refreshable, 640_000));

    const fixed = CachedToken{
        .token = "t",
        .expires_on_ms = 1_000_000,
        .kind = .sas,
        .refreshable = false,
        .refresh_at_ms = null,
    };
    try testing.expect(!isStale(fixed, 999_999));
    try testing.expect(isStale(fixed, 1_000_000));
}

test "put-token sends the exact application-property map for a JWT" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    mem.clearWritten();
    try client.putToken("amqps://ns.servicebus.windows.net/eh", .{
        .token = "aad-jwt",
        .expires_on_ms = 1_700_000_000_000,
        .kind = .jwt,
    }, 10_000);

    var decoded = try sentPutTokenProperties(allocator, mem.written());
    defer decoded.deinit();
    const props = decoded.message.application_properties.?;

    try testing.expectEqual(@as(usize, 4), props.len);
    try testing.expectEqualStrings("put-token", propertyValue(props, operation_key).?.string);
    try testing.expectEqualStrings("jwt", propertyValue(props, token_type_key).?.string);
    try testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/eh",
        propertyValue(props, audience_key).?.string,
    );
    try testing.expectEqual(
        @as(i64, 1_700_000_000_000),
        propertyValue(props, expiration_key).?.timestamp,
    );

    // The token itself rides in the body as an AMQP value section.
    try testing.expectEqualStrings("aad-jwt", decoded.message.body.value.string);
    // The reply has to be routable back to us.
    try testing.expectEqualStrings("cbs-reply-to-test", decoded.message.properties.reply_to.?);
    try testing.expectEqualStrings("cbs-reply-to-test:1", decoded.message.properties.message_id.?.string);
}

test "put-token sends the SAS token type for a shared access signature" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    mem.clearWritten();
    try client.putToken("amqps://ns.servicebus.windows.net/eh", .{
        .token = "SharedAccessSignature sr=%2Feh&sig=abc&se=1700000000&skn=key",
        .expires_on_ms = 1_700_000_000_000,
        .kind = .sas,
        .refreshable = false,
    }, 10_000);

    var decoded = try sentPutTokenProperties(allocator, mem.written());
    defer decoded.deinit();
    const props = decoded.message.application_properties.?;

    try testing.expectEqualStrings(
        "servicebus.windows.net:sastoken",
        propertyValue(props, token_type_key).?.string,
    );
    try testing.expectEqualStrings(
        "SharedAccessSignature sr=%2Feh&sig=abc&se=1700000000&skn=key",
        decoded.message.body.value.string,
    );
}

test "a 401 reply surfaces as unauthorized and is not retried" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 401);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    mem.clearWritten();
    var stub = StubProvider{ .token = .{
        .token = "expired",
        .expires_on_ms = 1_700_000_000_000,
        .kind = .jwt,
    } };
    try testing.expectError(
        error.Unauthorized,
        client.authorize("eh", stub.provider(), 0, 10_000),
    );

    // Exactly one request went out: a refused credential is not retried, and
    // nothing was cached for the audience.
    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const transfers = try frames.of(allocator, 0x14);
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);
    try testing.expectEqual(@as(usize, 1), stub.calls);
    try testing.expect(client.cachedToken("eh") == null);
}

test "authorising the same audience twice reuses the cached token" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    mem.clearWritten();
    var stub = StubProvider{ .token = .{
        .token = "aad-jwt",
        .expires_on_ms = 3_600_000,
        .kind = .jwt,
    } };

    try client.authorize("eh", stub.provider(), 0, 10_000);
    // Well inside the refresh window, so this must not go to the wire. Only
    // one reply was scripted, so a second round-trip would block and fail.
    try client.authorize("eh", stub.provider(), 1_000, 10_000);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const transfers = try frames.of(allocator, 0x14);
    defer allocator.free(transfers);
    try testing.expectEqual(@as(usize, 1), transfers.len);
    try testing.expectEqual(@as(usize, 1), stub.calls);
    try testing.expectEqualStrings("aad-jwt", client.cachedToken("eh").?.token);
}

test "a refreshable token schedules a refresh but a fixed SAS does not" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);
    try scriptCbsReply(peer, allocator, 2, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{
        .link_id = "test",
        .jitter_seed = 7,
    }, 10_000);
    defer client.deinit();

    var refreshable = StubProvider{ .token = .{
        .token = "aad-jwt",
        .expires_on_ms = 3_600_000,
        .kind = .jwt,
    } };
    try client.authorize("eh-aad", refreshable.provider(), 0, 10_000);

    var fixed = StubProvider{ .token = .{
        .token = "sas",
        .expires_on_ms = 3_600_000,
        .kind = .sas,
        .refreshable = false,
    } };
    try client.authorize("eh-sas", fixed.provider(), 0, 10_000);

    // The refresh is due roughly six minutes before expiry, jittered by at
    // most five seconds either side.
    const next = client.nextRefreshAtMs().?;
    try testing.expect(next >= 3_600_000 - 365_000);
    try testing.expect(next <= 3_600_000 - 355_000);

    // Only the renewable token is scheduled; the fixed SAS would return the
    // same expiry forever, so refreshing it would spin.
    try testing.expect(client.tokens.get("eh-sas").?.refresh_at_ms == null);
    try testing.expectEqual(next, client.tokens.get("eh-aad").?.refresh_at_ms.?);
}

test "a refresh that comes due re-puts the token" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);
    try scriptCbsReply(peer, allocator, 2, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    var stub = StubProvider{ .token = .{
        .token = "aad-jwt",
        .expires_on_ms = 3_600_000,
        .kind = .jwt,
    } };
    try client.authorize("eh", stub.provider(), 0, 10_000);
    const first_due = client.nextRefreshAtMs().?;

    // Nothing is owed before the refresh instant.
    try client.refreshDue(stub.provider(), first_due - 1, 10_000);
    try testing.expectEqual(@as(usize, 1), stub.calls);

    // Once it comes due the token goes back to the wire and is rescheduled
    // against the new expiry.
    stub.token.expires_on_ms = 7_200_000;
    try client.refreshDue(stub.provider(), first_due, 10_000);
    try testing.expectEqual(@as(usize, 2), stub.calls);
    try testing.expect(client.nextRefreshAtMs().? > first_due);
    try testing.expectEqual(@as(i64, 7_200_000), client.cachedToken("eh").?.expires_on_ms);
}

test "recovering a connection invalidates every cached claim" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: connection.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptCbsAttach(peer);
    try scriptCbsReply(peer, allocator, 1, 202);

    var driver = try connection.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer driver.deinit();
    var fixture = try Fixture.init(allocator, &mem, &clock, &driver);
    defer fixture.deinit();

    const client = try Cbs.open(&fixture.session, .{ .link_id = "test" }, 10_000);
    defer client.deinit();

    var stub = StubProvider{ .token = .{
        .token = "aad-jwt",
        .expires_on_ms = 3_600_000,
        .kind = .jwt,
    } };
    try client.authorize("eh", stub.provider(), 0, 10_000);
    try testing.expect(client.cachedToken("eh") != null);

    // A new connection carries none of the old connection's claims.
    client.invalidateAll();
    try testing.expect(client.cachedToken("eh") == null);
    try testing.expect(client.nextRefreshAtMs() == null);
}
