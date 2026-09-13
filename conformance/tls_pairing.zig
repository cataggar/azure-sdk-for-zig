//! Native counterpart of HTTPX ff720540's canonical public pairing fixture.
//! Uses one public HTTPX module; deterministic certificate fixtures import only std.
const std = @import("std");
const testing = std.testing;
const httpx = @import("httpx");
const native = @import("azure_sdk_core_symcrypt_tls");
const fixtures = @import("httpx_certificate_fixtures");
const Client = httpx.Client;
const types = httpx.types;
const net = httpx.socket;
const engine = httpx.tls;
const trust = engine.trust;
const crypto = httpx.crypto_provider;
const http = httpx.http;
const streams = httpx.stream;
const Version = std.crypto.tls.ProtocolVersion;
const Snapshot = @typeInfo(@FieldType(engine.TrustContext, "platform_snapshot")).optional.child;
const sdk_enabled = @import("paired_options").sdk_transport;
const sdk = if (sdk_enabled) @import("sdk_httpx") else void;

const Api = enum { connection, streaming_h1, streaming_h2, sdk_h1, sdk_h2 };

fn isSdk(api: Api) bool {
    return api == .sdk_h1 or api == .sdk_h2;
}

fn isH2(api: Api) bool {
    return api == .streaming_h2 or api == .sdk_h2;
}

const ClientOwner = union(enum) {
    direct: Client,
    adapter: if (sdk_enabled) sdk.HttpxTransport else void,

    fn init(api: Api, config: httpx.ClientConfig) !ClientOwner {
        if (isSdk(api)) {
            if (comptime sdk_enabled) return .{ .adapter = try sdk.HttpxTransport.init(testing.allocator, testing.io, .{
                .client = config,
                .operation = .{ .version = if (isH2(api)) .HTTP_2 else .HTTP_1_1 },
            }) };
            return error.SdkTransportUnavailable;
        }
        return .{ .direct = try Client.tryInitWithConfig(testing.allocator, config) };
    }

    fn client(self: *ClientOwner) *Client {
        return switch (self.*) {
            .direct => &self.direct,
            .adapter => if (comptime sdk_enabled) &self.adapter.client else unreachable,
        };
    }

    fn deinit(self: *ClientOwner) void {
        switch (self.*) {
            .direct => self.direct.deinit(),
            .adapter => if (comptime sdk_enabled) self.adapter.deinit() else unreachable,
        }
    }
};
const Case = enum {
    matching,
    provider_context,
    provider_vtable,
    provider_missing,
    adapter_missing,
    adapter_mismatch,
    policy_disabled,
    backend_disabled,
    hash_failed,
    snapshot_failed,
    metadata_oom,
    signature_failed,
    fingerprint_denied,
    path_depth,
};

const Observed = struct {
    implementation: native.Provider,
    version: Version,
    case: Case,
    bound_policy: trust.TrustProvider = undefined,
    in_policy: bool = false,
    policy_calls: usize = 0,
    verifier: ?trust.CertificateSignatureVerifier = null,
    request_time: i64 = 0,
    creates: usize = 0,
    updates: usize = 0,
    snapshots: usize = 0,
    destroys: usize = 0,
    signatures: usize = 0,
    seals: usize = 0,
    opens: usize = 0,
    traffic_updates: usize = 0,

    fn owner(context: *anyopaque) *@This() {
        const implementation: *native.Provider = @ptrCast(@alignCast(context));
        return @fieldParentPtr("implementation", implementation);
    }

    fn capabilities(context: *anyopaque) crypto.Capabilities {
        const self = owner(context);
        var result = self.implementation.provider().vtable.capabilities(context);
        if (self.version == .tls_1_2) result.hkdf_hashes = 0;
        result.aeads = 0;
        result.setAead(.aes_128_gcm, true);
        result.key_agreements = 0;
        result.setKeyAgreement(.secp256r1, true);
        return result;
    }

    fn verifyPeer(context: *anyopaque, request: trust.VerifyPeerRequest) trust.TrustError!void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.policy_calls += 1;
        self.verifier = request.signature_verifier;
        self.request_time = request.now_seconds;
        const now = std.Io.Timestamp.now(testing.io, .real).toSeconds();
        if (request.now_seconds < now - 5 or request.now_seconds > now + 5)
            return error.TlsInvalidTrustConfiguration;
        self.in_policy = true;
        defer self.in_policy = false;
        return self.bound_policy.verifyPeer(request);
    }

    fn hashCreate(context: *anyopaque, allocator: std.mem.Allocator, algorithm: crypto.HashAlgorithm, output: *?*anyopaque) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            self.creates += 1;
            if (algorithm != .sha1) return error.UnsupportedAlgorithm;
            if (self.case == .metadata_oom) {
                output.* = null;
                return error.OutOfMemory;
            }
        }
        return self.implementation.provider().vtable.hashCreate(context, allocator, algorithm, output);
    }

    fn hashUpdate(context: *anyopaque, handle: *anyopaque, bytes: []const u8) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            self.updates += 1;
            if (self.case == .hash_failed) return error.InternalError;
        }
        return self.implementation.provider().vtable.hashUpdate(context, handle, bytes);
    }

    fn hashSnapshot(context: *anyopaque, handle: *anyopaque, output: []u8) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            self.snapshots += 1;
            if (self.case == .snapshot_failed) {
                @memset(output, 0x55);
                return error.InternalError;
            }
        }
        return self.implementation.provider().vtable.hashSnapshot(context, handle, output);
    }

    fn hashDestroy(context: *anyopaque, allocator: std.mem.Allocator, handle: *anyopaque) void {
        const self = owner(context);
        if (self.in_policy) self.destroys += 1;
        self.implementation.provider().vtable.hashDestroy(context, allocator, handle);
    }

    fn verify(context: *anyopaque, scheme: crypto.SignatureScheme, key: crypto.PublicKey, parts: []const []const u8, signature: []const u8) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            self.signatures += 1;
            if (self.case == .signature_failed) return error.SignatureInvalid;
        }
        return self.implementation.provider().vtable.verify(context, scheme, key, parts, signature);
    }

    fn expand(context: *anyopaque, algorithm: crypto.HashAlgorithm, prk: []const u8, info: []const []const u8, output: []u8) crypto.ProviderError!void {
        const self = owner(context);
        for (info) |part| {
            if (std.mem.indexOf(u8, part, "tls13 traffic upd") != null) self.traffic_updates += 1;
        }
        return self.implementation.provider().vtable.hkdfExpand(context, algorithm, prk, info, output);
    }

    fn seal(context: *anyopaque, algorithm: crypto.AeadAlgorithm, key: []const u8, nonce: []const u8, aad: []const []const u8, plain: []const u8, encrypted: []u8, tag: []u8) crypto.ProviderError!void {
        const self = owner(context);
        if (algorithm != .aes_128_gcm) return error.UnsupportedAlgorithm;
        self.seals += 1;
        return self.implementation.provider().vtable.aeadSeal(context, algorithm, key, nonce, aad, plain, encrypted, tag);
    }

    fn open(context: *anyopaque, algorithm: crypto.AeadAlgorithm, key: []const u8, nonce: []const u8, aad: []const []const u8, encrypted: []const u8, tag: []const u8, plain: []u8) crypto.ProviderError!void {
        const self = owner(context);
        if (algorithm != .aes_128_gcm) return error.UnsupportedAlgorithm;
        self.opens += 1;
        return self.implementation.provider().vtable.aeadOpen(context, algorithm, key, nonce, aad, encrypted, tag, plain);
    }
};

fn readExact(connection: *engine.Connection, output: []u8) !void {
    var offset: usize = 0;
    while (offset < output.len) {
        const count = try connection.read(output[offset..]);
        if (count == 0) return error.UnexpectedEndOfStream;
        offset += count;
    }
}

fn writeFrame(connection: *engine.Connection, frame_type: http.HTTP2FrameType, flags: u8, stream_id: u31, payload: []const u8) !void {
    const header = (http.HTTP2FrameHeader{
        .length = @intCast(payload.len),
        .frame_type = frame_type,
        .flags = flags,
        .stream_id = stream_id,
    }).serialize();
    try connection.writeAll(&header);
    try connection.writeAll(payload);
}

fn requestKeyUpdate(connection: *engine.Connection) !void {
    // The peer uses HTTPX's existing provider-backed HKDF, not a test crypto implementation.
    try testing.expectEqual(std.crypto.tls.CipherSuite.AES_128_GCM_SHA256, connection.cipher_suite.?);
    const update = [_]u8{ @intFromEnum(std.crypto.tls.HandshakeType.key_update), 0, 0, 1, 1 };
    try connection.writeEncryptedRecord(&update, .handshake);
    const provider = connection.cryptoProvider();
    var secret = try engine.hkdfExpandLabel(provider, connection.app_write_secret.?[0..32], "traffic upd", "", 32);
    defer crypto.secureWipe(&secret);
    var key = try engine.hkdfExpandLabel(provider, &secret, "key", "", 16);
    defer crypto.secureWipe(&key);
    var iv = try engine.hkdfExpandLabel(provider, &secret, "iv", "", 12);
    defer crypto.secureWipe(&iv);
    crypto.secureWipe(&connection.app_write_secret.?);
    crypto.secureWipe(&connection.app_write_key.?);
    @memcpy(connection.app_write_secret.?[0..32], &secret);
    @memcpy(connection.app_write_key.?[0..16], &key);
    connection.app_write_iv.? = iv;
    connection.write_seq = 0;
}

const Peer = struct {
    listener: *net.TcpListener,
    config: engine.ServerTLSConfig,
    api: Api,
    version: Version,
    handshakes: usize = 0,
    requests: usize = 0,
    failure: ?anyerror = null,
    client_done: std.atomic.Value(bool) = .init(false),

    fn run(self: *@This()) void {
        self.serve() catch |err| {
            self.failure = err;
        };
    }

    fn beforeResponse(self: *@This(), connection: *engine.Connection) !void {
        if (self.version == .tls_1_3 and self.requests == 0) try requestKeyUpdate(connection);
    }

    fn serve(self: *@This()) !void {
        if (!self.listener.socket.waitReadable(2_000)) return error.FixtureAcceptTimeout;
        var accepted = try self.listener.accept();
        defer accepted.socket.close();
        try accepted.socket.setRecvTimeout(2_000);
        try accepted.socket.setSendTimeout(2_000);
        const protocols: []const []const u8 = if (isH2(self.api)) &.{"h2"} else &.{"http/1.1"};
        var connection = try engine.acceptServer(testing.allocator, &accepted.socket, protocols, self.config);
        defer connection.deinit();
        self.handshakes += 1;
        try testing.expectEqual(self.version, connection.tlsVersion());
        try testing.expectEqualStrings(protocols[0], connection.negotiatedAlpn().?);
        if (isH2(self.api)) return self.serveH2(&connection);
        while (self.requests < 2) {
            if (self.api == .connection) {
                var request: [4]u8 = undefined;
                try readExact(&connection, &request);
                try testing.expectEqualStrings("ping", &request);
                try self.beforeResponse(&connection);
                try connection.writeAll("pong");
            } else {
                var request: [4096]u8 = undefined;
                var length: usize = 0;
                while (std.mem.indexOf(u8, request[0..length], "\r\n\r\n") == null) {
                    if (length == request.len) return error.FixtureRequestTooLarge;
                    const count = try connection.read(request[length..]);
                    if (count == 0) return error.UnexpectedEndOfStream;
                    length += count;
                }
                try self.beforeResponse(&connection);
                try connection.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nbound");
            }
            self.requests += 1;
        }
    }

    fn serveH2(self: *@This(), connection: *engine.Connection) !void {
        var preface: [http.HTTP2_PREFACE.len]u8 = undefined;
        try readExact(connection, &preface);
        try testing.expectEqualStrings(http.HTTP2_PREFACE, &preface);
        try writeFrame(connection, .settings, 0, 0, "");
        var manager = streams.StreamManager.init(testing.allocator, false);
        defer manager.deinit();
        var payload: [16_384]u8 = undefined;
        var last_stream: u31 = 0;
        var current_stream: u31 = 0;
        for (0..128) |_| {
            var bytes: [9]u8 = undefined;
            const count = connection.read(&bytes) catch |err| {
                if (err == error.TlsConnectionTruncated and self.requests == 2 and self.client_done.load(.acquire)) return;
                return err;
            };
            if (count == 0) {
                if (self.requests == 2 and self.client_done.load(.acquire)) return;
                return error.UnexpectedEndOfStream;
            }
            try readExact(connection, bytes[count..]);
            const header = http.HTTP2FrameHeader.parse(bytes);
            if (header.length > payload.len) return error.FixtureFrameTooLarge;
            try readExact(connection, payload[0..header.length]);
            switch (header.frame_type) {
                .settings => if (header.flags & 1 == 0) {
                    try writeFrame(connection, .settings, 1, 0, "");
                },
                .window_update => {},
                .headers => {
                    if (self.requests == 2) return error.FixtureUnexpectedFrame;
                    try testing.expect(header.stream_id > last_stream);
                    try testing.expect(header.flags & 4 != 0);
                    current_stream = header.stream_id;
                    if (header.flags & 1 == 0) continue;
                },
                .data => {
                    if (self.requests == 2) return error.FixtureUnexpectedFrame;
                    try testing.expectEqual(current_stream, header.stream_id);
                    if (header.flags & 1 == 0) continue;
                },
                else => return error.FixtureUnexpectedFrame,
            }
            if (header.frame_type != .headers and header.frame_type != .data) continue;
            try self.beforeResponse(connection);
            const headers = try streams.buildHeadersAndContinuations(&manager, current_stream, &.{
                .{ .name = ":status", .value = "200", .representation = .without_indexing },
                .{ .name = "content-length", .value = "5", .representation = .without_indexing },
            }, null, 16_384, false, testing.allocator);
            defer testing.allocator.free(headers);
            try connection.writeAll(headers);
            try writeFrame(connection, .data, 1, current_stream, "bound");
            last_stream = current_stream;
            self.requests += 1;
        }
        return error.FixtureFrameLimit;
    }
};

fn drive(owner: *ClientOwner, address: httpx.Address, api: Api) !void {
    const client = owner.client();
    if (api == .connection) {
        var socket = try net.Socket.create();
        defer socket.close();
        try socket.connectWithTimeout(address, 2_000);
        try socket.setRecvTimeout(2_000);
        try socket.setSendTimeout(2_000);
        const config = client.makeTlsConfig(true, &.{"http/1.1"});
        var connection = try engine.connectClient(testing.allocator, &socket, &config, "127.0.0.1");
        defer connection.deinit();
        try testing.expectEqual(config.crypto_provider.?.context, connection.crypto_provider.?.context);
        try testing.expectEqual(config.crypto_provider.?.vtable, connection.crypto_provider.?.vtable);
        for (0..2) |_| {
            try connection.writeAll("ping");
            var response: [4]u8 = undefined;
            try readExact(&connection, &response);
            try testing.expectEqualStrings("pong", &response);
        }
        return;
    }
    var url_buffer: [96]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://127.0.0.1:{d}/paired", .{address.getPort()});
    if (isSdk(api)) {
        if (comptime sdk_enabled) {
            try testing.expect(sdk.httpx.Client == httpx.Client);
            const transport = owner.adapter.asTransport();
            for (0..2) |_| {
                {
                    var request = sdk.core.http.Request.init(testing.allocator, .GET, url);
                    defer request.deinit();
                    const operation = try transport.open(&request, .{});
                    defer operation.deinit();
                    try testing.expectEqual(@as(u16, 200), operation.status_code);
                    const response = try operation.body_reader.allocRemaining(testing.allocator, .limited(1024));
                    defer testing.allocator.free(response);
                    try testing.expectEqualStrings("bound", response);
                    try operation.finish();
                }
                try testing.expectEqual(@as(usize, 0), owner.adapter.live_operations);
                try testing.expectEqual(@as(usize, 0), owner.adapter.poolStats().active);
                try testing.expectEqual(@as(usize, 1), owner.adapter.poolStats().idle);
            }
            return;
        }
        return error.SdkTransportUnavailable;
    }
    for (0..2) |_| {
        var operation = try client.open(.GET, url, .{
            .version = if (api == .streaming_h2) .HTTP_2 else .HTTP_1_1,
        });
        defer operation.deinit();
        const head = try operation.finishRequest(null);
        try testing.expectEqual(@as(u16, 200), head.status.code);
        try testing.expectEqual(if (api == .streaming_h2) types.Version.HTTP_2 else .HTTP_1_1, head.version);
        var response: [5]u8 = undefined;
        var offset: usize = 0;
        while (offset < response.len) {
            const count = try operation.read(response[offset..]);
            if (count == 0) return error.UnexpectedEndOfStream;
            offset += count;
        }
        try testing.expectEqualStrings("bound", &response);
        var extra: [1]u8 = undefined;
        try testing.expectEqual(@as(usize, 0), try operation.read(&extra));
        try operation.finish(.{});
        try testing.expectEqual(@as(usize, 0), client.poolStats().active);
        try testing.expectEqual(@as(usize, 1), client.poolStats().idle);
    }
}

fn exercise(api: Api, version: Version, case: Case) !void {
    errdefer std.debug.print("native TLS pairing: api={s} version={s} case={s}\n", .{ @tagName(api), @tagName(version), @tagName(case) });
    var chain = try fixtures.Chain.init(testing.allocator, .ecdsa_p256);
    defer chain.deinit();
    var roots = try engine.TrustContext.init(testing.allocator, testing.io, .{
        .source = .{ .custom_only = .{ .der_certificates = &.{chain.root} } },
        .load_time_seconds = 1_700_000_000,
    });
    defer roots.deinit();
    roots.platform_snapshot = Snapshot.init(testing.allocator, .{});
    var identifier: [64]u8 = @splat(0);
    std.crypto.hash.Sha1.hash(chain.leaf, identifier[0..20], .{});
    try roots.platform_snapshot.?.addFingerprintList(.{
        .algorithm = .sha1,
        .this_update = 1_700_000_000,
        .next_update = 2_524_608_000,
        .entries = &.{.{ .identifier = identifier, .policy = .{
            .roles = if (case == .fingerprint_denied) 0 else 3,
        } }},
    });
    var observed: Observed = .{
        .implementation = try native.Provider.init(testing.allocator, .{
            .allow_sha1_identifier_hash = case != .backend_disabled,
        }),
        .version = version,
        .case = case,
    };
    var selected = observed.implementation.provider();
    var vtable = selected.vtable.*;
    vtable.capabilities = Observed.capabilities;
    vtable.hashCreate = Observed.hashCreate;
    vtable.hashUpdate = Observed.hashUpdate;
    vtable.hashSnapshot = Observed.hashSnapshot;
    vtable.hashDestroy = Observed.hashDestroy;
    vtable.verify = Observed.verify;
    vtable.hkdfExpand = Observed.expand;
    vtable.aeadSeal = Observed.seal;
    vtable.aeadOpen = Observed.open;
    selected.vtable = &vtable;
    var adapter = engine.CryptoCertificateVerifier.init(selected);
    var other_adapter = engine.CryptoCertificateVerifier.init(selected);
    var binding = try roots.bind(&adapter, .{ .allow_sha1_identifiers = case != .policy_disabled });
    observed.bound_policy = binding.provider();
    var alternate: Observed = .{
        .implementation = try native.Provider.init(testing.allocator, .{ .allow_sha1_identifier_hash = true }),
        .version = version,
        .case = case,
    };
    var copied_vtable = vtable;
    var configured = selected;
    if (case == .provider_context) configured.context = alternate.implementation.provider().context;
    if (case == .provider_vtable) configured.vtable = &copied_vtable;
    if (case == .provider_context or case == .provider_vtable) {
        try testing.expectEqualDeep(selected.vtable.capabilities(selected.context), configured.vtable.capabilities(configured.context));
        try testing.expectEqual(selected.abi_version, configured.abi_version);
        try testing.expectEqual(case == .provider_vtable, selected.context == configured.context);
        try testing.expectEqual(case == .provider_context, selected.vtable == configured.vtable);
    }
    var server_provider = try native.Provider.init(testing.allocator, .{});
    var server_config = try engine.ServerTLSConfig.init(testing.allocator, testing.io, &.{ chain.leaf, chain.intermediate }, .{
        .algorithm = .ecdsa_p256,
        .encoding = .raw_secret,
        .bytes = &chain.leaf_key.ecdsa_p256.secret_key.toBytes(),
    }, server_provider.provider());
    defer server_config.deinit();
    var listener = try net.TcpListener.init(try httpx.Address.parseIp("127.0.0.1", 0));
    defer listener.deinit();
    const address = try listener.getLocalAddress();
    var client_owner = try ClientOwner.init(api, .{
        .tls_crypto_provider = if (case == .provider_missing) null else configured,
        .tls_certificate_crypto = if (case == .adapter_missing) null else if (case == .adapter_mismatch) &other_adapter else &adapter,
        .server_authentication = .{ .verify = .{ .provider = .{
            .context = &observed,
            .vtable = &.{ .verify_peer = Observed.verifyPeer },
        } } },
        .tls_trust_limits = if (case == .path_depth) .{ .max_path_depth = 2 } else .{},
        .http2_enabled = isH2(api),
        .policy = types.ClientPolicy.embeddingOwned(),
        .timeouts = types.Timeouts.uniform(2_000),
    });
    const client = client_owner.client();
    var client_alive = true;
    defer if (client_alive) client_owner.deinit();
    if (case != .adapter_missing and case != .adapter_mismatch) {
        const verifier = client.configuration().tls_certificate_crypto.?.verifier();
        try testing.expectEqual(binding.signatureVerifier().context, verifier.context);
        try testing.expectEqual(binding.signatureVerifier().vtable, verifier.vtable);
    }
    var peer: Peer = .{ .listener = &listener, .config = server_config, .api = api, .version = version };
    const thread = try std.Thread.spawn(.{}, Peer.run, .{&peer});
    var joined = false;
    errdefer std.debug.print("native peer: handshakes={d} requests={d} failure={s}\n", .{
        peer.handshakes, peer.requests, if (peer.failure) |err| @errorName(err) else "none",
    });
    defer if (!joined) {
        peer.client_done.store(true, .release);
        client_owner.deinit();
        client_alive = false;
        thread.join();
    };
    const result = drive(&client_owner, address, api);
    if (case == .matching) {
        try result;
    } else {
        const expected = switch (case) {
            .matching => unreachable,
            .provider_context, .provider_vtable, .provider_missing, .adapter_missing, .adapter_mismatch => error.TlsInvalidTrustConfiguration,
            .policy_disabled, .backend_disabled, .hash_failed, .snapshot_failed => error.TlsTrustStoreLoadFailed,
            .metadata_oom => error.OutOfMemory,
            .signature_failed => error.TlsCertificateSignatureInvalid,
            .fingerprint_denied => error.TlsCertificateConstraintViolation,
            .path_depth => error.TlsCertificatePathTooDeep,
        };
        try testing.expectError(expected, result);
    }
    try testing.expectEqual(@as(usize, 0), client.poolStats().active);
    try testing.expectEqual(@as(usize, 0), client.shared.in_flight.load(.acquire));
    if (comptime sdk_enabled) {
        if (isSdk(api)) try testing.expectEqual(@as(usize, 0), client_owner.adapter.live_operations);
    }
    if (case != .matching) try testing.expectEqual(@as(usize, 0), client.poolStats().idle);
    peer.client_done.store(true, .release);
    client_owner.deinit();
    client_alive = false;
    thread.join();
    joined = true;
    if (case == .metadata_oom) {
        try testing.expectEqual(@as(usize, 1), observed.creates);
        try testing.expectEqual(@as(usize, 0), observed.destroys);
    } else {
        try testing.expectEqual(observed.creates, observed.destroys);
    }
    if (case == .matching) {
        if (peer.failure) |err| return err;
        try testing.expectEqual(@as(usize, 1), peer.handshakes);
        try testing.expectEqual(@as(usize, 2), peer.requests);
        try testing.expectEqual(@as(usize, 1), observed.policy_calls);
        try testing.expectEqual(binding.signatureVerifier().context, observed.verifier.?.context);
        try testing.expectEqual(binding.signatureVerifier().vtable, observed.verifier.?.vtable);
        try testing.expect(observed.request_time > 1_700_000_000);
        try testing.expect(observed.creates >= 3);
        try testing.expectEqual(observed.creates, observed.updates);
        try testing.expectEqual(observed.creates, observed.snapshots);
        try testing.expect(observed.signatures >= 2);
        try testing.expect(observed.seals > 0 and observed.opens > 0);
        if (version == .tls_1_3) try testing.expect(observed.traffic_updates > 0);
    } else {
        try testing.expect(peer.failure != null);
        try testing.expectEqual(@as(usize, 0), peer.handshakes);
        try testing.expectEqual(@as(usize, 0), peer.requests);
        switch (case) {
            .provider_context, .provider_vtable, .provider_missing => {
                try testing.expectEqual(@as(usize, 0), observed.policy_calls);
                try testing.expectEqual(@as(usize, 0), observed.creates);
                try testing.expectEqual(@as(usize, 0), observed.signatures);
            },
            .adapter_missing, .adapter_mismatch, .policy_disabled, .backend_disabled => {
                try testing.expectEqual(@as(usize, 0), observed.creates);
                try testing.expectEqual(@as(usize, 0), observed.signatures);
            },
            .hash_failed, .snapshot_failed, .metadata_oom, .fingerprint_denied, .path_depth => {
                try testing.expectEqual(@as(usize, 1), observed.creates);
                try testing.expectEqual(@as(usize, 0), observed.signatures);
            },
            .signature_failed => try testing.expect(observed.signatures > 0),
            .matching => unreachable,
        }
    }
}

test "native paired canonical client-server and optional SDK transport matrix" {
    var count: usize = 0;
    for ([_]Version{ .tls_1_2, .tls_1_3 }) |version| {
        for (std.enums.values(Api)) |api| {
            if (isSdk(api) and !sdk_enabled) continue;
            for (std.enums.values(Case)) |case| {
                try exercise(api, version, case);
                count += 1;
            }
        }
    }
    try testing.expectEqual(@as(usize, if (sdk_enabled) 140 else 84), count);
}

fn metadataAllocation(allocator: std.mem.Allocator) !void {
    var implementation = try native.Provider.init(allocator, .{ .allow_sha1_identifier_hash = true });
    var adapter = engine.CryptoCertificateVerifier.init(implementation.provider());
    const digest = adapter.metadataHasher(.{ .allow_sha1_identifiers = true });
    var output: [20]u8 = @splat(0xa5);
    digest.hash(allocator, .sha1, "metadata", &output) catch |err| {
        try testing.expect(std.mem.allEqual(u8, &output, 0));
        return err;
    };
}

test "native paired metadata gates exact buffers every failure and allocation cleanup" {
    for ([_]bool{ false, true }) |backend_enabled| {
        for ([_]bool{ false, true }) |policy_enabled| {
            var implementation = try native.Provider.init(testing.allocator, .{
                .allow_sha1_identifier_hash = backend_enabled,
            });
            const selected = implementation.provider();
            var adapter = engine.CryptoCertificateVerifier.init(selected);
            const digest = adapter.metadataHasher(.{ .allow_sha1_identifiers = policy_enabled });
            try testing.expectEqual(adapter.verifier().context, digest.context);
            var output: [20]u8 = @splat(0xa5);
            if (backend_enabled and policy_enabled) {
                try digest.hash(testing.allocator, .sha1, "metadata", &output);
                var expected: [20]u8 = undefined;
                std.crypto.hash.Sha1.hash("metadata", &expected, .{});
                try testing.expectEqualSlices(u8, &expected, &output);
            } else {
                try testing.expectError(error.UnsupportedAlgorithm, digest.hash(testing.allocator, .sha1, "metadata", &output));
                try testing.expect(std.mem.allEqual(u8, &output, 0));
            }
            const capabilities = try selected.capabilities();
            try testing.expect(!capabilities.supportsSign(.rsa_pkcs1_sha1));
            try testing.expect(!capabilities.supportsVerify(.rsa_pkcs1_sha1));
            try testing.expect(!capabilities.supportsHmac(.sha1));
            try testing.expect(!capabilities.supportsHkdf(.sha1));
            try testing.expect(!capabilities.supportsTls12Prf(.sha1));
            var short: [19]u8 = @splat(0xa5);
            var long: [21]u8 = @splat(0xa5);
            try testing.expectError(error.InvalidDigestLength, digest.hash(testing.allocator, .sha1, "metadata", &short));
            try testing.expectError(error.InvalidDigestLength, digest.hash(testing.allocator, .sha1, "metadata", &long));
            try testing.expect(std.mem.allEqual(u8, &short, 0));
            try testing.expect(std.mem.allEqual(u8, &long, 0));
        }
    }
    for ([_]Case{ .metadata_oom, .hash_failed, .snapshot_failed }) |case| {
        var observed: Observed = .{
            .implementation = try native.Provider.init(testing.allocator, .{ .allow_sha1_identifier_hash = true }),
            .version = .tls_1_3,
            .case = case,
            .in_policy = true,
        };
        var selected = observed.implementation.provider();
        var vtable = selected.vtable.*;
        vtable.hashCreate = Observed.hashCreate;
        vtable.hashUpdate = Observed.hashUpdate;
        vtable.hashSnapshot = Observed.hashSnapshot;
        vtable.hashDestroy = Observed.hashDestroy;
        selected.vtable = &vtable;
        var adapter = engine.CryptoCertificateVerifier.init(selected);
        const digest = adapter.metadataHasher(.{ .allow_sha1_identifiers = true });
        var output: [20]u8 = @splat(0xa5);
        try testing.expectError(if (case == .metadata_oom) error.OutOfMemory else error.InternalError, digest.hash(testing.allocator, .sha1, "metadata", &output));
        try testing.expect(std.mem.allEqual(u8, &output, 0));
        try testing.expectEqual(@as(usize, 1), observed.creates);
        try testing.expectEqual(@as(usize, if (case == .metadata_oom) 0 else 1), observed.destroys);
    }
    try testing.checkAllAllocationFailures(testing.allocator, metadataAllocation, .{});
}
