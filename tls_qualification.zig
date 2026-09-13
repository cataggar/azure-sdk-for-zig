//! Opt-in paired-API qualification. The dependency's certificate generator
//! imports only std; every TLS/provider/trust descriptor uses the one HTTPX module.
const std = @import("std");
const testing = std.testing;
const adapter = @import("azure_sdk_core_httpx");
const httpx = @import("httpx");
const fixtures = @import("tls_fixture_data");
const tls = httpx.tls;
const crypto = httpx.crypto_provider;
const Version = std.crypto.tls.ProtocolVersion;
const https_fixture = @import("https_fixture.zig");

const Case = enum {
    matching,
    provider_abi,
    provider_context,
    provider_vtable,
    provider_missing,
    adapter_missing,
    adapter_mismatch,
    policy_disabled,
    backend_disabled,
    metadata_oom,
    signature_failed,
    path_depth,
};
const Action = enum { reuse, abort, cancel, token };

const Observed = struct {
    standard: httpx.StandardCryptoProvider,
    version: Version,
    case: Case,
    bound: httpx.TrustProvider = undefined,
    in_policy: bool = false,
    policy_calls: usize = 0,
    creates: usize = 0,
    destroys: usize = 0,
    signatures: usize = 0,
    verifier: ?httpx.CertificateSignatureVerifier = null,
    limits: httpx.TrustLimits = .{},

    fn owner(context: *anyopaque) *@This() {
        const standard: *httpx.StandardCryptoProvider = @ptrCast(@alignCast(context));
        return @fieldParentPtr("standard", standard);
    }

    fn capabilities(context: *anyopaque) crypto.Capabilities {
        const self = owner(context);
        var result = self.standard.provider().vtable.capabilities(context);
        if (self.version == .tls_1_2) result.hkdf_hashes = 0;
        if (self.case == .backend_disabled) result.setHash(.sha1, false);
        return result;
    }

    fn verifyPeer(context: *anyopaque, request: httpx.VerifyPeerRequest) httpx.TrustError!void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.policy_calls += 1;
        self.verifier = request.signature_verifier;
        self.limits = request.limits;
        self.in_policy = true;
        defer self.in_policy = false;
        return self.bound.verifyPeer(request);
    }

    fn hashCreate(context: *anyopaque, allocator: std.mem.Allocator, algorithm: crypto.HashAlgorithm, output: *?*anyopaque) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            if (self.case == .metadata_oom) {
                output.* = null;
                return error.OutOfMemory;
            }
            self.creates += 1;
        }
        return self.standard.provider().vtable.hashCreate(context, allocator, algorithm, output);
    }

    fn hashDestroy(context: *anyopaque, allocator: std.mem.Allocator, handle: *anyopaque) void {
        const self = owner(context);
        if (self.in_policy) self.destroys += 1;
        self.standard.provider().vtable.hashDestroy(context, allocator, handle);
    }

    fn verify(context: *anyopaque, scheme: crypto.SignatureScheme, key: crypto.PublicKey, parts: []const []const u8, signature: []const u8) crypto.ProviderError!void {
        const self = owner(context);
        if (self.in_policy) {
            self.signatures += 1;
            if (self.case == .signature_failed) return error.SignatureInvalid;
        }
        return self.standard.provider().vtable.verify(context, scheme, key, parts, signature);
    }
};

fn readExact(connection: *tls.Connection, output: []u8) !void {
    var offset: usize = 0;
    while (offset < output.len) {
        const count = try connection.read(output[offset..]);
        if (count == 0) return error.UnexpectedEndOfStream;
        offset += count;
    }
}

fn frame(connection: *tls.Connection, kind: httpx.HTTP2FrameType, flags: u8, stream: u31, payload: []const u8) !void {
    const header = (httpx.HTTP2FrameHeader{
        .length = @intCast(payload.len),
        .frame_type = kind,
        .flags = flags,
        .stream_id = stream,
    }).serialize();
    try connection.writeAll(&header);
    try connection.writeAll(payload);
}

const Peer = struct {
    listener: *httpx.TcpListener,
    config: tls.ServerTLSConfig,
    version: Version,
    h2: bool,
    expected_requests: usize,
    handshakes: usize = 0,
    requests: usize = 0,
    failure: ?anyerror = null,
    client_done: std.atomic.Value(bool) = .init(false),

    fn run(self: *@This()) void {
        self.serve() catch |err| {
            self.failure = err;
        };
    }

    fn serve(self: *@This()) !void {
        if (!self.listener.socket.waitReadable(2000)) return error.FixtureAcceptTimeout;
        var accepted = try self.listener.accept();
        defer accepted.socket.close();
        try accepted.socket.setRecvTimeout(2000);
        try accepted.socket.setSendTimeout(2000);
        const protocols: []const []const u8 = if (self.h2) &.{"h2"} else &.{"http/1.1"};
        var connection = try tls.acceptServer(testing.allocator, &accepted.socket, protocols, self.config);
        defer connection.deinit();
        self.handshakes += 1;
        try testing.expectEqual(self.version, connection.tlsVersion());
        try testing.expectEqualStrings(protocols[0], connection.negotiatedAlpn().?);
        if (self.h2) return self.serveH2(&connection);

        while (self.requests < self.expected_requests) {
            var request: [4096]u8 = undefined;
            var length: usize = 0;
            while (std.mem.indexOf(u8, request[0..length], "\r\n\r\n") == null) {
                if (length == request.len) return error.FixtureRequestTooLarge;
                const count = try connection.read(request[length..]);
                if (count == 0) return error.UnexpectedEndOfStream;
                length += count;
            }
            try testing.expect(std.mem.startsWith(u8, request[0..length], "GET /paired HTTP/1.1\r\n"));
            try connection.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nbound");
            self.requests += 1;
        }
        var byte: [1]u8 = undefined;
        const count = connection.read(&byte) catch |err| {
            if (self.client_done.load(.acquire) and err == error.TlsConnectionTruncated) return;
            return err;
        };
        if (count != 0 or !self.client_done.load(.acquire)) return error.FixtureUnexpectedData;
    }

    fn serveH2(self: *@This(), connection: *tls.Connection) !void {
        var preface: [httpx.http.HTTP2_PREFACE.len]u8 = undefined;
        try readExact(connection, &preface);
        try testing.expectEqualStrings(httpx.http.HTTP2_PREFACE, &preface);
        try frame(connection, .settings, 0, 0, "");
        var payload: [16384]u8 = undefined;
        var last_stream: u31 = 0;
        var current_stream: u31 = 0;
        for (0..128) |_| {
            var bytes: [9]u8 = undefined;
            const count = connection.read(&bytes) catch |err| {
                if (self.client_done.load(.acquire) and self.requests == self.expected_requests and
                    err == error.TlsConnectionTruncated) return;
                return err;
            };
            if (count == 0) {
                if (self.client_done.load(.acquire) and self.requests == self.expected_requests) return;
                return error.UnexpectedEndOfStream;
            }
            try readExact(connection, bytes[count..]);
            const header = httpx.HTTP2FrameHeader.parse(bytes);
            if (header.length > payload.len) return error.FixtureFrameTooLarge;
            try readExact(connection, payload[0..header.length]);
            switch (header.frame_type) {
                .settings => {
                    if (header.flags & 1 == 0) try frame(connection, .settings, 1, 0, "");
                    continue;
                },
                .window_update => continue,
                .headers => {
                    if (self.requests == self.expected_requests) return error.FixtureUnexpectedRequest;
                    try testing.expect(header.stream_id > last_stream);
                    try testing.expect(header.flags & 4 != 0);
                    current_stream = header.stream_id;
                    if (header.flags & 1 == 0) continue;
                },
                .data => {
                    try testing.expectEqual(current_stream, header.stream_id);
                    try testing.expectEqual(@as(u24, 0), header.length);
                    if (header.flags & 1 == 0) continue;
                },
                .rst_stream => {
                    try testing.expect(self.client_done.load(.acquire));
                    try testing.expectEqual(self.expected_requests, self.requests);
                    try testing.expectEqual(last_stream, header.stream_id);
                    try testing.expectEqual(@as(u24, 4), header.length);
                    try testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, payload[0..4], .big));
                    continue;
                },
                else => return error.FixtureUnexpectedFrame,
            }
            try frame(connection, .headers, 4, current_stream, "\x88");
            try frame(connection, .data, 1, current_stream, "bound");
            last_stream = current_stream;
            self.requests += 1;
        }
        return error.FixtureFrameLimit;
    }
};

fn drive(transport: *adapter.HttpxTransport, url: []const u8, action: Action, peer: *Peer) !void {
    var request = adapter.core.http.Request.init(testing.allocator, .GET, url);
    defer request.deinit();
    defer testing.expect(request.transport_started) catch @panic("missing transport_started");
    if (action == .reuse) {
        var response = try transport.asTransport().send(&request);
        defer response.deinit();
        try testing.expectEqual(@as(u16, 200), response.status_code);
        try testing.expectEqualStrings("bound", response.body);
        try testing.expectEqual(@as(usize, 0), transport.live_operations);
        try testing.expectEqual(@as(usize, 1), transport.poolStats().idle);
    }
    var token: adapter.core.http.CancellationToken = .{};
    const operation = try transport.asTransport().open(&request, .{ .cancellation = &token });
    defer operation.deinit();
    try testing.expectEqual(@as(u16, 200), operation.status_code);
    var prefix: [2]u8 = undefined;
    try (try operation.reader()).readSliceAll(&prefix);
    try testing.expectEqualStrings("bo", &prefix);
    // Terminal operations may close before control returns to this thread.
    if (action != .reuse) peer.client_done.store(true, .release);
    switch (action) {
        .reuse => try operation.finish(),
        .abort => operation.abort(),
        .cancel => operation.cancel(),
        .token => {
            token.cancel();
            try testing.expectError(error.OperationCancelled, operation.finish());
        },
    }
    try testing.expectEqual(@as(usize, 0), transport.poolStats().active);
    try testing.expectEqual(@as(usize, if (action == .reuse) 1 else 0), transport.poolStats().total);
}

fn exercise(version: Version, h2: bool, case: Case, action: Action) !void {
    errdefer std.debug.print("SDK paired TLS failed: version={s} h2={} case={s} action={s}\n", .{
        @tagName(version), h2, @tagName(case), @tagName(action),
    });
    try testing.expect(httpx.CryptoProvider == adapter.httpx.CryptoProvider);
    try testing.expect(httpx.CryptoCertificateVerifier == adapter.httpx.CryptoCertificateVerifier);
    const chain = fixtures;
    var roots = try tls.TrustContext.init(testing.allocator, testing.io, .{
        .source = .{ .custom_only = .{ .der_certificates = &.{chain.root} } },
    });
    defer roots.deinit();
    const Snapshot = @typeInfo(@TypeOf(roots.platform_snapshot)).optional.child;
    roots.platform_snapshot = Snapshot.init(testing.allocator, .{});
    var identifier: [64]u8 = @splat(0);
    std.crypto.hash.Sha1.hash(chain.leaf, identifier[0..20], .{});
    try roots.platform_snapshot.?.addFingerprintList(.{
        .algorithm = .sha1,
        .this_update = 1_700_000_000,
        .next_update = 2_524_608_000,
        .entries = &.{.{ .identifier = identifier, .policy = .{ .roles = 3 } }},
    });
    var observed: Observed = .{
        .standard = .init(testing.io, testing.allocator),
        .version = version,
        .case = case,
    };
    var selected = observed.standard.provider();
    var table = selected.vtable.*;
    table.capabilities = Observed.capabilities;
    table.hashCreate = Observed.hashCreate;
    table.hashDestroy = Observed.hashDestroy;
    table.verify = Observed.verify;
    selected.vtable = &table;
    var certificate_crypto = httpx.CryptoCertificateVerifier.init(selected);
    var other_certificate_crypto = httpx.CryptoCertificateVerifier.init(selected);
    var binding = try roots.bind(&certificate_crypto, .{ .allow_sha1_identifiers = case != .policy_disabled });
    observed.bound = binding.provider();
    var other: Observed = .{
        .standard = .init(testing.io, testing.allocator),
        .version = version,
        .case = case,
    };
    var other_table = table;
    var configured = selected;
    switch (case) {
        .provider_abi => configured.abi_version += 1,
        .provider_context => configured.context = other.standard.provider().context,
        .provider_vtable => configured.vtable = &other_table,
        else => {},
    }
    var server_config = try tls.ServerTLSConfig.init(testing.allocator, testing.io, &.{ chain.leaf, chain.intermediate }, .{
        .algorithm = .ecdsa_p256,
        .encoding = .raw_secret,
        .bytes = chain.leaf_key,
    }, null);
    defer server_config.deinit();
    var listener = try httpx.TcpListener.init(try httpx.Address.parseIp("127.0.0.1", 0));
    defer listener.deinit();
    var transport = try adapter.HttpxTransport.init(testing.allocator, testing.io, .{
        .client = .{
            .tls_crypto_provider = if (case == .provider_missing) null else configured,
            .tls_certificate_crypto = if (case == .adapter_missing) null else if (case == .adapter_mismatch) &other_certificate_crypto else &certificate_crypto,
            .server_authentication = .{ .verify = .{ .provider = .{
                .context = &observed,
                .vtable = &.{ .verify_peer = Observed.verifyPeer },
            } } },
            .tls_trust_limits = .{ .max_path_depth = if (case == .path_depth) 2 else 7 },
            .http2_enabled = h2,
            .pool_max_connections = 1,
            .pool_max_per_host = 1,
            .timeouts = httpx.Timeouts.uniform(2000),
        },
        .operation = .{
            .version = if (h2) .HTTP_2 else .HTTP_1_1,
            .require_interruptible_dns = true,
            .response_limit = .{ .bytes = 5 },
        },
    });
    var transport_alive = true;
    defer if (transport_alive) transport.deinit();
    var peer: Peer = .{
        .listener = &listener,
        .config = server_config,
        .version = version,
        .h2 = h2,
        .expected_requests = if (action == .reuse) 2 else 1,
    };
    const thread = try std.Thread.spawn(.{}, Peer.run, .{&peer});
    var joined = false;
    defer if (!joined) {
        peer.client_done.store(true, .release);
        transport.deinit();
        transport_alive = false;
        thread.join();
    };
    var url_buffer: [96]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "https://127.0.0.1:{d}/paired", .{(try listener.getLocalAddress()).getPort()});
    const result = drive(&transport, url, action, &peer);
    if (case == .matching) {
        try result;
    } else {
        try testing.expectError(switch (case) {
            .matching => unreachable,
            .provider_abi, .provider_context, .provider_vtable, .provider_missing, .adapter_missing, .adapter_mismatch => error.TlsInvalidTrustConfiguration,
            .policy_disabled, .backend_disabled => error.TlsTrustStoreLoadFailed,
            .metadata_oom => error.OutOfMemory,
            .signature_failed => error.TlsCertificateSignatureInvalid,
            .path_depth => error.TlsCertificatePathTooDeep,
        }, result);
        try testing.expectEqual(@as(usize, 0), transport.poolStats().total);
    }
    try testing.expectEqual(@as(usize, 0), transport.live_operations);
    try testing.expectEqual(@as(usize, 0), transport.poolStats().active);
    try testing.expectEqual(@as(usize, 0), transport.client.shared.in_flight.load(.acquire));
    peer.client_done.store(true, .release);
    transport.deinit();
    transport_alive = false;
    thread.join();
    joined = true;
    try testing.expectEqual(observed.creates, observed.destroys);
    if (case == .matching) {
        if (peer.failure) |err| {
            std.debug.print("SDK paired peer error={s} handshakes={d} requests={d}\n", .{
                @errorName(err), peer.handshakes, peer.requests,
            });
            return err;
        }
        try testing.expectEqual(@as(usize, 1), peer.handshakes);
        try testing.expectEqual(peer.expected_requests, peer.requests);
        try testing.expectEqual(@as(usize, 1), observed.policy_calls);
        try testing.expectEqual(binding.signatureVerifier().context, observed.verifier.?.context);
        try testing.expectEqual(binding.signatureVerifier().vtable, observed.verifier.?.vtable);
        try testing.expectEqual(@as(usize, 7), observed.limits.max_path_depth);
        try testing.expect(observed.creates >= 3);
        try testing.expect(observed.signatures >= 2);
    } else {
        try testing.expect(peer.failure != null);
        try testing.expectEqual(@as(usize, 0), peer.handshakes);
        try testing.expectEqual(@as(usize, 0), peer.requests);
        switch (case) {
            .provider_abi, .provider_context, .provider_vtable, .provider_missing => {
                try testing.expectEqual(@as(usize, 0), observed.policy_calls);
                try testing.expectEqual(@as(usize, 0), observed.creates);
                try testing.expectEqual(@as(usize, 0), observed.signatures);
            },
            else => {
                try testing.expectEqual(@as(usize, 1), observed.policy_calls);
                if (case == .path_depth) try testing.expectEqual(@as(usize, 2), observed.limits.max_path_depth);
                if (case == .signature_failed) try testing.expect(observed.signatures > 0);
            },
        }
    }
}

test "paired standard TLS forwards canonical identity policy errors and pooled owners" {
    for ([_]Version{ .tls_1_2, .tls_1_3 }) |version| {
        for ([_]bool{ false, true }) |h2| {
            for (std.enums.values(Case)) |case| try exercise(version, h2, case, .reuse);
        }
    }
    std.debug.print("SDK paired TLS: 48 cases (TLS1.2/TLS1.3 x H1/H2 x 12 trust/provider cases), buffered+streaming reuse verified\n", .{});
}

test "paired standard TLS drains aborts and cancels Core operations without leaked leases" {
    for ([_]Version{ .tls_1_2, .tls_1_3 }) |version| {
        for ([_]bool{ false, true }) |h2| {
            for ([_]Action{ .abort, .cancel, .token }) |action| try exercise(version, h2, .matching, action);
        }
    }
    std.debug.print("SDK paired TLS: 12 post-open abort/cancel/token cleanup cases; not new blocked-phase interruption evidence\n", .{});
}

fn sharedHttpsPipeline(version: Version) !void {
    const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{ .version = version });
    defer owner.deinit();
    errdefer std.debug.print("blocked shared HTTPS pipeline {s}: requests={d}, handshakes={d}, verified={d}, live_backends={d}\n", .{
        @tagName(version), owner.requests, owner.handshakes, owner.verified.load(.acquire), owner.live_backends,
    });
    try https_fixture.conformance.runPipelineContracts(testing.allocator, testing.io, owner.factory());
    try testing.expectEqual(@as(usize, 0), owner.live_backends);
    try testing.expectEqual(@as(usize, 22), owner.requests);
    try testing.expectEqual(owner.requests, owner.handshakes);
    try testing.expectEqual(owner.requests, owner.verified.load(.acquire));
    try testing.expectEqual(@as(usize, 0), owner.rejected.load(.acquire));
    try testing.expectEqual(@as(usize, 1), owner.roots.anchorCount());
}

test "trusted HTTPS shared pipeline TLS1.2" {
    try sharedHttpsPipeline(.tls_1_2);
}

test "trusted HTTPS shared pipeline TLS1.3" {
    try sharedHttpsPipeline(.tls_1_3);
}

fn sharedHttpsRaw(version: Version) !void {
    const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{ .version = version });
    defer owner.deinit();
    errdefer std.debug.print("blocked shared HTTPS raw {s}: live_backends={d}, verified={d}\n", .{
        @tagName(version), owner.live_backends, owner.verified.load(.acquire),
    });
    try https_fixture.conformance.runRawTransportContracts(testing.allocator, testing.io, owner.factory());
    try testing.expectEqual(@as(usize, 0), owner.live_backends);
}

test "trusted HTTPS shared raw TLS1.2" {
    try sharedHttpsRaw(.tls_1_2);
}

test "trusted HTTPS shared raw TLS1.3" {
    try sharedHttpsRaw(.tls_1_3);
}

test "trusted HTTPS shared allocation failure contracts retain concrete errors and cleanup" {
    const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{});
    defer owner.deinit();
    try https_fixture.conformance.runBackendAllocationFailureContracts(testing.allocator, testing.io, owner.factory());
    try testing.expectEqual(@as(usize, 0), owner.live_backends);
}

test "trusted HTTPS factory enforces hostname roots and actual path limits" {
    const cases = [_]struct { options: https_fixture.Options, expected: anyerror }{
        .{ .options = .{ .wrong_hostname = true }, .expected = error.TlsHostnameMismatch },
        .{ .options = .{ .untrusted_root = true }, .expected = error.TlsUnknownCa },
        .{ .options = .{ .path_depth = 2 }, .expected = error.TlsCertificatePathTooDeep },
    };
    for (cases) |case| {
        const owner = try https_fixture.Owner.create(testing.allocator, testing.io, case.options);
        defer owner.deinit();
        var backend = try owner.factory().create(testing.allocator, testing.io, .{ .allow_peer_failure = true });
        defer backend.deinit();
        var request = adapter.core.http.Request.init(testing.allocator, .GET, backend.url);
        defer request.deinit();
        try testing.expectError(case.expected, backend.transport.send(&request));
        try backend.finish();
        try backend.assertQuiescent();
        try testing.expect(request.transport_started);
        try testing.expectEqual(@as(usize, 0), backend.observe().request_count);
        try testing.expectEqual(@as(usize, 0), owner.verified.load(.acquire));
        try testing.expectEqual(@as(usize, 1), owner.rejected.load(.acquire));
    }
}

test "trusted HTTPS redirect rejects an unauthenticated destination without sending its request" {
    const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{});
    defer owner.deinit();
    const destination_owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{ .wrong_hostname = true });
    defer destination_owner.deinit();
    var destination = try destination_owner.factory().create(testing.allocator, testing.io, .{ .allow_peer_failure = true });
    defer destination.deinit();
    const headers = [_]https_fixture.conformance.scripted.Header{.{ .name = "Location", .value = destination.url }};
    var source = try owner.factory().create(testing.allocator, testing.io, .{
        .response = .{ .status_code = 307, .headers = &headers },
    });
    defer source.deinit();
    var crypto_provider = adapter.core.crypto.StdCryptoProvider.init(testing.io);
    var pipeline = adapter.core.http.HttpPipeline.init(
        adapter.core.http.HttpRuntime.init(source.transport, crypto_provider.asProvider()),
        &.{},
    );
    var request = adapter.core.http.Request.init(testing.allocator, .POST, source.url);
    defer request.deinit();
    try request.setHeader("Authorization", "fixture-token");
    var bytes = adapter.core.http.ReplayableBytes.init("fixture-body");
    try testing.expectError(error.TlsHostnameMismatch, pipeline.open(&request, .{ .body = bytes.body() }));
    try source.finish();
    try destination.finish();
    try source.assertQuiescent();
    try destination.assertQuiescent();
    try testing.expect(request.transport_started);
    try testing.expectEqual(@as(usize, 1), source.observe().request_count);
    try testing.expectEqual(@as(usize, 0), destination.observe().request_count);
    try testing.expectEqualStrings("fixture-token", (try source.attempt(0)).authorization.?);
    try testing.expectEqualStrings("fixture-token", request.getHeader("Authorization").?);
    try testing.expectEqual(@as(usize, 1), owner.verified.load(.acquire));
    try testing.expectEqual(@as(usize, 1), owner.rejected.load(.acquire));
}

const RedirectPolicyProbe = struct {
    calls: usize = 0,
    policy: adapter.core.http.HttpPolicy = .{ .processFn = process, .prepareFn = prepare },

    fn prepare(policy: *adapter.core.http.HttpPolicy, _: *adapter.core.http.Request, _: adapter.core.http.HttpRuntime) !void {
        const self: *@This() = @fieldParentPtr("policy", policy);
        self.calls += 1;
    }

    fn process(policy: *adapter.core.http.HttpPolicy, request: *adapter.core.http.Request, next: []*adapter.core.http.HttpPolicy, runtime: adapter.core.http.HttpRuntime) !adapter.core.http.Response {
        try prepare(policy, request, runtime);
        return if (next.len == 0) runtime.transport.send(request) else next[0].process(request, next[1..], runtime);
    }
};

test "trusted HTTPS independent redirects verify actual credentials without hiding the shared Host blocker" {
    for ([_]Version{ .tls_1_2, .tls_1_3 }) |version| {
        for ([_]enum { same_origin, cross_origin, see_other }{ .same_origin, .cross_origin, .see_other }) |case| {
            const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{ .version = version });
            defer owner.deinit();
            var destination = try owner.factory().create(testing.allocator, testing.io, .{ .response = .{ .body = "destination" } });
            defer destination.deinit();
            const same_origin = case == .same_origin;
            const headers = [_]https_fixture.conformance.scripted.Header{
                .{ .name = "Location", .value = if (same_origin) "/continued#fragment" else destination.url },
                .{ .name = "Set-Cookie", .value = "ambient=must-not-be-replayed" },
            };
            const responses = [_]https_fixture.conformance.scripted.Response{
                .{ .status_code = if (case == .see_other) 303 else 307, .headers = &headers },
                .{ .body = "same-origin" },
            };
            var source = try owner.factory().create(testing.allocator, testing.io, .{ .responses = &responses });
            defer source.deinit();
            var probe: RedirectPolicyProbe = .{};
            var policies = [_]*adapter.core.http.HttpPolicy{&probe.policy};
            var crypto_provider = adapter.core.crypto.StdCryptoProvider.init(testing.io);
            var pipeline = adapter.core.http.HttpPipeline.init(
                adapter.core.http.HttpRuntime.init(source.transport, crypto_provider.asProvider()),
                &policies,
            );
            var request = adapter.core.http.Request.init(testing.allocator, .POST, source.url);
            defer request.deinit();
            inline for (.{ "Authorization", "Cookie", "Cookie2", "Proxy-Authorization", "Host" }) |name|
                try request.setHeader(name, "fixture-value");
            var bytes = adapter.core.http.ReplayableBytes.init("redirect-upload");
            {
                const operation = try pipeline.open(&request, .{ .body = bytes.body() });
                defer operation.deinit();
                try testing.expectEqual(@as(u16, 200), operation.status_code);
                try operation.finish();
            }
            try source.finish();
            try destination.finish();
            try source.assertQuiescent();
            try destination.assertQuiescent();
            try testing.expect(request.transport_started);
            try testing.expectEqual(@as(usize, 1), probe.calls);
            try testing.expectEqual(@as(usize, if (same_origin) 2 else 1), source.observe().request_count);
            try testing.expectEqual(@as(usize, if (same_origin) 0 else 1), destination.observe().request_count);
            const first = try source.attempt(0);
            try testing.expectEqualStrings("fixture-value", first.authorization.?);
            try testing.expectEqualStrings("fixture-value", first.cookie.?);
            try testing.expectEqualStrings("fixture-value", first.proxy_authorization.?);
            try testing.expectEqualStrings("fixture-value", first.host.?);
            const last = if (same_origin) try source.attempt(1) else try destination.attempt(0);
            const captured_backend: *https_fixture.Backend = @ptrCast(@alignCast(if (same_origin) source.context else destination.context));
            const cookie2 = captured_backend.requests.items[if (same_origin) 1 else 0].headerValue("Cookie2");
            if (same_origin) {
                try testing.expectEqualStrings("fixture-value", last.authorization.?);
                try testing.expectEqualStrings("fixture-value", last.cookie.?);
                try testing.expectEqualStrings("fixture-value", last.proxy_authorization.?);
                try testing.expectEqualStrings("fixture-value", cookie2.?);
            } else {
                try testing.expect(last.authorization == null and last.cookie == null and last.proxy_authorization == null);
                try testing.expect(cookie2 == null);
            }
            // This matches released Core behavior, not its contradictory shared
            // assertion. The shared runner above remains an unmodified failing gate.
            const target = if (same_origin) source.url else destination.url;
            try testing.expectEqualStrings(std.mem.sliceTo(target["https://".len..], '/'), last.host.?);
            try testing.expectEqualStrings(if (case == .see_other) "" else "redirect-upload", last.body);
            try testing.expect(std.mem.startsWith(u8, last.request_line, if (case == .see_other) "GET " else "POST "));
            if (same_origin) try testing.expectEqualStrings("POST /continued HTTP/1.1", last.request_line);
            try testing.expectEqualStrings("fixture-value", request.getHeader("Authorization").?);
            try testing.expectEqual(@as(usize, 2), owner.verified.load(.acquire));
            try testing.expectEqual(@as(usize, 0), owner.rejected.load(.acquire));
        }
    }
}

test "trusted HTTPS independent logical streaming keeps the shared allocation budget" {
    const conformance = https_fixture.conformance;
    for ([_]Version{ .tls_1_2, .tls_1_3 }) |version| {
        const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{ .version = version });
        defer owner.deinit();
        const storage = try testing.allocator.alloc(u8, conformance.streaming_allocation_budget);
        defer testing.allocator.free(storage);
        var budget = std.heap.FixedBufferAllocator.init(storage);
        var backend = try owner.factory().create(budget.allocator(), testing.io, .{
            .fixture_allocator = testing.allocator,
            .max_response_body = 1024,
            .response = .{
                .chunked = true,
                .generated_body = .{ .byte = 'd', .length = conformance.logical_stream_length },
            },
        });
        defer backend.deinit();
        var request = adapter.core.http.Request.init(budget.allocator(), .POST, backend.url);
        defer request.deinit();
        var upload = conformance.fakes.RepeatingReader.init('u', conformance.logical_stream_length);
        {
            const operation = try backend.transport.open(&request, .{
                .body = adapter.core.http.StreamingRequestBody.chunked(&upload.interface),
            });
            defer operation.deinit();
            const reader = try operation.reader();
            var bytes: [8191]u8 = undefined;
            var received: usize = 0;
            while (true) {
                const count = try reader.readSliceShort(&bytes);
                if (count == 0) break;
                try testing.expect(std.mem.allEqual(u8, bytes[0..count], 'd'));
                received += count;
            }
            try testing.expectEqual(conformance.logical_stream_length, received);
            try operation.finish();
        }
        try backend.finish();
        try backend.assertQuiescent();
        try testing.expectEqual(@as(usize, 0), upload.remaining);
        try testing.expectEqual(conformance.logical_stream_length, backend.observe().body_length);
        std.debug.print("trusted HTTPS {s}: streamed {d} bytes each direction within {d}-byte adapter allocation budget\n", .{
            @tagName(version), conformance.logical_stream_length, conformance.streaming_allocation_budget,
        });
    }
}

test "trusted HTTPS fixture shutdown joins an idle peer and an incomplete handshake" {
    const owner = try https_fixture.Owner.create(testing.allocator, testing.io, .{});
    defer owner.deinit();
    for ([_]bool{ false, true }) |connect| {
        var backend = try owner.factory().create(testing.allocator, testing.io, .{
            .responses = &.{.{}},
            .expect_request = false,
        });
        defer backend.deinit();
        const state: *https_fixture.Backend = @ptrCast(@alignCast(backend.context));
        var socket = try httpx.Socket.create();
        defer socket.close();
        if (connect) {
            try socket.connectWithTimeout(try state.listener.getLocalAddress(), 1000);
            const start = std.Io.Timestamp.now(testing.io, .awake);
            while (true) {
                state.mutex.lockUncancelable(testing.io);
                const active = state.active != null;
                state.mutex.unlock(testing.io);
                if (active) break;
                if (std.Io.Timestamp.now(testing.io, .awake).toNanoseconds() - start.toNanoseconds() > 500 * std.time.ns_per_ms)
                    return error.FixtureHandshakeNotEntered;
                try std.Io.sleep(testing.io, .fromMilliseconds(1), .awake);
            }
        }
        const before = std.Io.Timestamp.now(testing.io, .awake);
        try backend.finish();
        const elapsed = std.Io.Timestamp.now(testing.io, .awake).toNanoseconds() - before.toNanoseconds();
        try testing.expect(elapsed <= std.time.ns_per_s);
        try testing.expect(state.thread == null and state.active == null);
        try backend.assertQuiescent();
    }
}
