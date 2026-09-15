//! Independent-server qualification using the canonical Options-based trust engine.
//! The local root, intermediate and leaf never modify an operating-system trust store.
const std = @import("std");
const httpx = @import("httpx");
const binding = @import("azure_sdk_core_symcrypt_tls");
const p = httpx.crypto_provider;
const tls = httpx.tls;
const Version = std.crypto.tls.ProtocolVersion;

comptime {
    if (!@hasField(tls.TLSConfig, "certificate_crypto") or !@hasDecl(tls.TrustContext, "bind"))
        @compileError("TLS interoperability requires the paired canonical HTTPX runtime; use a qualified pin or explicit httpx_source development override");
}

const FixtureTrust = struct {
    parsed: std.crypto.Certificate.Parsed,
    roots: *tls.TrustContext,
    unrelated_roots: *tls.TrustContext,
    bound: tls.TrustProvider = undefined,
    reject_anchor: bool = false,
    calls: usize = 0,

    fn provider(self: *FixtureTrust) tls.TrustProvider {
        return .{ .context = self, .vtable = &.{ .verify_peer = verify } };
    }

    fn verify(context: *anyopaque, request: tls.VerifyPeerRequest) tls.TrustError!void {
        const self: *FixtureTrust = @ptrCast(@alignCast(context));
        self.calls += 1;
        return self.bound.verifyPeer(request);
    }
};

fn injectedError(operation: p.Operation) p.ProviderError {
    return switch (operation) {
        .verify => error.SignatureInvalid,
        .aead_open => error.AuthenticationFailed,
        else => error.OutOfMemory,
    };
}

fn expectedTlsError(operation: p.Operation, application: bool) anyerror {
    if (operation == .verify) return error.TlsCertificateSignatureInvalid;
    if (operation == .aead_open)
        return if (application) error.TlsDecryptError else error.TlsBadRecordMac;
    return injectedError(operation);
}

fn Observed(comptime Backend: type) type {
    return struct {
        const Self = @This();
        inner: Backend,
        aead: p.AeadAlgorithm,
        group: p.KeyAgreementAlgorithm,
        table: p.VTable,
        failure: ?p.Operation = null,
        injected: usize = 0,
        calls: [std.meta.fields(p.Operation).len]usize = @splat(0),

        fn init(backend: Backend, aead: p.AeadAlgorithm, group: p.KeyAgreementAlgorithm) Self {
            var inner = backend;
            var table = inner.provider().vtable.*;
            table.capabilities = capabilities;
            table.random = random;
            table.hashCreate = hashCreate;
            table.hashUpdate = hashUpdate;
            table.hashSnapshot = hashSnapshot;
            table.hmac = hmac;
            table.hkdfExtract = extract;
            table.hkdfExpand = expand;
            table.tls12Prf = prf;
            table.keyAgreementGenerate = generate;
            table.keyAgreementPublicKey = publicKey;
            table.keyAgreementAgree = agree;
            table.verify = verify;
            table.aeadSeal = seal;
            table.aeadOpen = open;
            table.constantTimeEqual = equal;
            return .{ .inner = inner, .aead = aead, .group = group, .table = table };
        }

        fn provider(self: *Self) p.CryptoProvider {
            return p.CryptoProvider.init(&self.inner, &self.table);
        }

        fn owner(context: *anyopaque) *Self {
            const inner: *Backend = @ptrCast(@alignCast(context));
            return @fieldParentPtr("inner", inner);
        }

        fn count(self: *const Self, operation: p.Operation) usize {
            return self.calls[@intFromEnum(operation)];
        }

        fn observe(self: *Self, operation: p.Operation) p.ProviderError!void {
            self.calls[@intFromEnum(operation)] += 1;
            if (self.failure == operation) {
                self.injected += 1;
                return injectedError(operation);
            }
        }

        fn capabilities(context: *anyopaque) p.Capabilities {
            const self = owner(context);
            var caps = self.inner.provider().vtable.capabilities(context);
            caps.aeads = 0;
            caps.key_agreements = 0;
            caps.setAead(self.aead, true);
            caps.setKeyAgreement(self.group, true);
            return caps;
        }

        fn random(context: *anyopaque, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.random);
            return self.inner.provider().vtable.random(context, out);
        }

        fn hashCreate(context: *anyopaque, allocator: std.mem.Allocator, algorithm: p.HashAlgorithm, out: *?*anyopaque) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hash_create);
            return self.inner.provider().vtable.hashCreate(context, allocator, algorithm, out);
        }

        fn hashUpdate(context: *anyopaque, handle: *anyopaque, data: []const u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hash_update);
            return self.inner.provider().vtable.hashUpdate(context, handle, data);
        }

        fn hashSnapshot(context: *anyopaque, handle: *anyopaque, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hash_snapshot);
            return self.inner.provider().vtable.hashSnapshot(context, handle, out);
        }

        fn hmac(context: *anyopaque, algorithm: p.HashAlgorithm, key: []const u8, parts: []const []const u8, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hmac);
            return self.inner.provider().vtable.hmac(context, algorithm, key, parts, out);
        }

        fn extract(context: *anyopaque, algorithm: p.HashAlgorithm, salt: []const u8, parts: []const []const u8, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hkdf_extract);
            return self.inner.provider().vtable.hkdfExtract(context, algorithm, salt, parts, out);
        }

        fn expand(context: *anyopaque, algorithm: p.HashAlgorithm, prk: []const u8, parts: []const []const u8, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.hkdf_expand);
            return self.inner.provider().vtable.hkdfExpand(context, algorithm, prk, parts, out);
        }

        fn prf(context: *anyopaque, algorithm: p.HashAlgorithm, secret: []const u8, label: []const u8, seed: []const []const u8, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.tls12_prf);
            return self.inner.provider().vtable.tls12Prf(context, algorithm, secret, label, seed, out);
        }

        fn generate(context: *anyopaque, allocator: std.mem.Allocator, algorithm: p.KeyAgreementAlgorithm, out: *?*anyopaque) p.ProviderError!void {
            const self = owner(context);
            if (algorithm != self.group) return error.UnsupportedAlgorithm;
            try self.observe(.key_agreement_generate);
            return self.inner.provider().vtable.keyAgreementGenerate(context, allocator, algorithm, out);
        }

        fn agree(context: *anyopaque, handle: *anyopaque, peer: []const u8, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.key_agreement_agree);
            return self.inner.provider().vtable.keyAgreementAgree(context, handle, peer, out);
        }

        fn publicKey(context: *anyopaque, handle: *anyopaque, out: []u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.key_agreement_public_key);
            return self.inner.provider().vtable.keyAgreementPublicKey(context, handle, out);
        }

        fn verify(context: *anyopaque, scheme: p.SignatureScheme, key: p.PublicKey, parts: []const []const u8, signature: []const u8) p.ProviderError!void {
            const self = owner(context);
            try self.observe(.verify);
            return self.inner.provider().vtable.verify(context, scheme, key, parts, signature);
        }

        fn seal(context: *anyopaque, algorithm: p.AeadAlgorithm, key: []const u8, nonce: []const u8, aad: []const []const u8, plaintext: []const u8, ciphertext: []u8, tag: []u8) p.ProviderError!void {
            const self = owner(context);
            if (algorithm != self.aead) return error.UnsupportedAlgorithm;
            try self.observe(.aead_seal);
            return self.inner.provider().vtable.aeadSeal(context, algorithm, key, nonce, aad, plaintext, ciphertext, tag);
        }

        fn open(context: *anyopaque, algorithm: p.AeadAlgorithm, key: []const u8, nonce: []const u8, aad: []const []const u8, ciphertext: []const u8, tag: []const u8, plaintext: []u8) p.ProviderError!void {
            const self = owner(context);
            if (algorithm != self.aead) return error.UnsupportedAlgorithm;
            try self.observe(.aead_open);
            return self.inner.provider().vtable.aeadOpen(context, algorithm, key, nonce, aad, ciphertext, tag, plaintext);
        }

        fn equal(context: *anyopaque, a: []const u8, b: []const u8) p.ProviderError!bool {
            const self = owner(context);
            try self.observe(.constant_time_equal);
            return self.inner.provider().vtable.constantTimeEqual(context, a, b);
        }
    };
}

const Scenario = union(enum) {
    success,
    trust_failure: tls.TrustError,
    handshake_failure: p.Operation,
    record_failure: p.Operation,
};

const CasePhase = enum {
    bind_trust,
    connect,
    handshake,
    authenticate,
    write_request,
    read_response,
    validate_response,
};

fn expectError(expected: anyerror, result: anyerror!void) !void {
    if (result) |_| return error.UnexpectedSuccess else |actual| {
        if (actual != expected) {
            std.debug.print("expected {s}, got {s}\n", .{ @errorName(expected), @errorName(actual) });
            return error.UnexpectedFailure;
        }
    }
}

fn runCase(comptime Backend: type, backend: Backend, allocator: std.mem.Allocator, trust: *FixtureTrust, port: u16, version: Version, aead: p.AeadAlgorithm, group: p.KeyAgreementAlgorithm, host: []const u8, scenario: Scenario) !void {
    var observed = Observed(Backend).init(backend, aead, group);
    var phase: CasePhase = .bind_trust;
    var handshake_complete = false;
    var total: usize = 0;
    var read_calls: usize = 0;
    var last_read: usize = 0;
    errdefer std.debug.print("interop phase={s} handshake_complete={} response_read_calls={d} response_bytes={d} last_read_bytes={d} trust_calls={d} random_calls={d} hash_create_calls={d} verify_calls={d} prf_calls={d} seal_calls={d} open_calls={d} injected={d}\n", .{
        @tagName(phase),
        handshake_complete,
        read_calls,
        total,
        last_read,
        trust.calls,
        observed.count(.random),
        observed.count(.hash_create),
        observed.count(.verify),
        observed.count(.tls12_prf),
        observed.count(.aead_seal),
        observed.count(.aead_open),
        observed.injected,
    });
    errdefer std.debug.print("{s} {s} {s} {s} {s} failed\n", .{
        if (Backend == binding.Provider) "SymCrypt" else "standard",
        @tagName(version),
        @tagName(aead),
        @tagName(group),
        @tagName(scenario),
    });
    if (scenario == .handshake_failure) observed.failure = scenario.handshake_failure;
    trust.calls = 0;
    var adapter = tls.CryptoCertificateVerifier.init(observed.provider());
    var paired = try (if (trust.reject_anchor) trust.unrelated_roots else trust.roots).bind(&adapter, .{
        .allow_sha1_identifiers = true,
    });
    trust.bound = paired.provider();
    phase = .connect;
    var socket = try httpx.Socket.create();
    defer socket.close();
    try socket.connectWithTimeout(.initIp4(.{ 127, 0, 0, 1 }, port), 5000);
    try socket.setRecvTimeout(5000);
    try socket.setSendTimeout(5000);
    var session = tls.TLSSession.init(.{
        .allocator = allocator,
        .crypto_provider = observed.provider(),
        .certificate_crypto = &adapter,
        .server_authentication = .{ .verify = .{ .provider = trust.provider() } },
    });
    defer session.deinit();
    session.attachSocket(&socket);
    // Capture only counters/flags before the caller's teardown wipes session state.
    errdefer std.debug.print("interop session failed={} close_notify={} read_seq={d} write_seq={d} encrypted_buffer_pos={d} encrypted_buffer_len={d} plaintext_buffer_pos={d} plaintext_buffer_len={d} post_handshake_bytes={d}\n", .{
        session.failed,
        session.received_close_notify,
        session.read_seq,
        session.write_seq,
        session.encrypted_buf_pos,
        session.encrypted_buf_len,
        session.read_buf_pos,
        session.read_buf_len,
        session.post_handshake_len,
    });
    phase = .handshake;
    switch (scenario) {
        .trust_failure => |expected| {
            const result = session.handshake(host);
            handshake_complete = if (result) |_| true else |_| false;
            try expectError(expected, result);
            if (trust.calls != 1) return error.TrustFailureRetried;
            return;
        },
        .handshake_failure => |operation| {
            const result = session.handshake(host);
            handshake_complete = if (result) |_| true else |_| false;
            try expectError(expectedTlsError(operation, false), result);
            if (observed.injected != 1) return error.ProviderFailureRetried;
            return;
        },
        .success, .record_failure => {},
    }
    try session.handshake(host);
    handshake_complete = true;
    phase = .authenticate;
    if (session.tls_version != version or trust.calls != 1) return error.InvalidAuthenticatedSession;
    const request = "GET / HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n";
    var response: [4096]u8 = undefined;
    phase = .write_request;
    if (scenario == .record_failure) {
        const operation = scenario.record_failure;
        if (operation == .aead_seal) {
            observed.failure = operation;
            try expectError(expectedTlsError(operation, true), session.writeAll(request));
        } else {
            try session.writeAll(request);
            observed.failure = operation;
            phase = .read_response;
            read_calls += 1;
            const result: anyerror!void = if (session.read(&response)) |count| {
                last_read = count;
            } else |err| err;
            try expectError(expectedTlsError(operation, true), result);
        }
        if (observed.injected != 1) return error.RecordFailureRetried;
        return;
    }
    try session.writeAll(request);
    phase = .read_response;
    while (true) {
        read_calls += 1;
        const count = session.read(&response) catch |err| switch (err) {
            error.TlsCloseNotify => break,
            else => return err,
        };
        last_read = count;
        if (count == 0) break;
        if (total == 0 and !std.mem.startsWith(u8, response[0..count], "HTTP/1.")) return error.InvalidHttpResponse;
        total += count;
        if (total > 512 * 1024) return error.ResponseLimitExceeded;
    }
    phase = .validate_response;
    if (total < 1024) return error.IncompleteHttpResponse;
    if (observed.count(.random) == 0 or observed.count(.hash_create) == 0 or
        observed.count(.hash_update) == 0 or observed.count(.hash_snapshot) == 0 or
        observed.count(.key_agreement_public_key) == 0 or observed.count(.constant_time_equal) == 0 or
        observed.count(.key_agreement_generate) != 1 or observed.count(.key_agreement_agree) != 1 or
        observed.count(.verify) == 0 or observed.count(.aead_seal) < 2 or observed.count(.aead_open) < 2)
        return error.MissingProviderDispatch;
    if (version == .tls_1_2 and observed.count(.tls12_prf) < 4) return error.MissingTls12Prf;
    if (version == .tls_1_3 and (observed.count(.hmac) < 2 or observed.count(.hkdf_extract) < 3 or observed.count(.hkdf_expand) < 10))
        return error.MissingTls13Kdf;
}

fn compatibleGroup(trust: *const FixtureTrust) !p.KeyAgreementAlgorithm {
    return switch (trust.parsed.pub_key_algo) {
        .X9_62_id_ecPublicKey => |curve| switch (curve) {
            .X9_62_prime256v1 => .secp256r1,
            .secp384r1 => .secp384r1,
            else => error.UnsupportedFixtureCurve,
        },
        else => .x25519,
    };
}

pub fn main(init: std.process.Init) !void {
    var checking: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(checking.deinit() == .ok);
    const allocator = checking.allocator();
    var args_arena = std.heap.ArenaAllocator.init(allocator);
    defer args_arena.deinit();
    const args = try init.minimal.args.toSlice(args_arena.allocator());
    if (args.len != 7) return error.ExpectedLeafPortsValidityAndRootCertificates;
    const der = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(256 * 1024));
    defer allocator.free(der);
    const root_der = try std.Io.Dir.cwd().readFileAlloc(init.io, args[5], allocator, .limited(256 * 1024));
    defer allocator.free(root_der);
    const unrelated_der = try std.Io.Dir.cwd().readFileAlloc(init.io, args[6], allocator, .limited(256 * 1024));
    defer allocator.free(unrelated_der);
    var roots = try tls.TrustContext.init(allocator, init.io, .{
        .source = .{ .custom_only = .{ .der_certificates = &.{root_der} } },
    });
    defer roots.deinit();
    var unrelated_roots = try tls.TrustContext.init(allocator, init.io, .{
        .source = .{ .custom_only = .{ .der_certificates = &.{unrelated_der} } },
    });
    defer unrelated_roots.deinit();
    const Snapshot = @typeInfo(@FieldType(tls.TrustContext, "platform_snapshot")).optional.child;
    roots.platform_snapshot = Snapshot.init(allocator, .{});
    var identifier: [64]u8 = @splat(0);
    std.crypto.hash.Sha1.hash(der, identifier[0..20], .{});
    try roots.platform_snapshot.?.addFingerprintList(.{
        .algorithm = .sha1,
        .this_update = 1_700_000_000,
        .next_update = 2_524_608_000,
        .entries = &.{.{ .identifier = identifier, .identifier_length = std.crypto.hash.Sha1.digest_length, .policy = .{} }},
    });
    var trust: FixtureTrust = .{
        .parsed = try (std.crypto.Certificate{ .buffer = der, .index = 0 }).parse(),
        .roots = &roots,
        .unrelated_roots = &unrelated_roots,
    };
    const expected_time: ?tls.TrustError = if (std.mem.eql(u8, args[4], "valid")) null else if (std.mem.eql(u8, args[4], "expired"))
        error.TlsCertificateExpired
    else if (std.mem.eql(u8, args[4], "future"))
        error.TlsCertificateNotYetValid
    else
        return error.InvalidValidityCase;
    const ports = [_]u16{ try std.fmt.parseInt(u16, args[2], 10), try std.fmt.parseInt(u16, args[3], 10) };
    var successes: usize = 0;
    var negatives: usize = 0;
    inline for (.{ false, true }) |native| {
        const Backend = if (native) binding.Provider else httpx.StandardCryptoProvider;
        const backend = if (native) try binding.Provider.init(allocator, .{ .allow_sha1_identifier_hash = true }) else httpx.StandardCryptoProvider.init(init.io, allocator);
        for ([_]Version{ .tls_1_2, .tls_1_3 }, ports) |version, port| {
            const certificate_group = try compatibleGroup(&trust);
            if (expected_time) |expected| {
                try runCase(Backend, backend, allocator, &trust, port, version, .aes_128_gcm, certificate_group, "localhost", .{ .trust_failure = expected });
                negatives += 1;
                continue;
            }
            for ([_]p.AeadAlgorithm{ .aes_128_gcm, .aes_256_gcm, .chacha20_poly1305 }) |aead| {
                for ([_]p.KeyAgreementAlgorithm{ .x25519, .secp256r1, .secp384r1 }) |group| {
                    if (version == .tls_1_2 and trust.parsed.pub_key_algo == .X9_62_id_ecPublicKey and group != certificate_group) continue;
                    try runCase(Backend, backend, allocator, &trust, port, version, aead, group, "localhost", .success);
                    successes += 1;
                }
            }
            try runCase(Backend, backend, allocator, &trust, port, version, .aes_128_gcm, certificate_group, "wrong.invalid", .{ .trust_failure = error.TlsHostnameMismatch });
            trust.reject_anchor = true;
            try runCase(Backend, backend, allocator, &trust, port, version, .aes_128_gcm, certificate_group, "localhost", .{ .trust_failure = error.TlsUnknownCa });
            trust.reject_anchor = false;
            negatives += 2;
            for ([_]p.Operation{
                .random,                 .hash_create,              .hash_update,         .hash_snapshot,
                .key_agreement_generate, .key_agreement_public_key, .key_agreement_agree, .verify,
                .hmac,                   .hkdf_extract,             .hkdf_expand,         .tls12_prf,
                .aead_seal,              .aead_open,                .constant_time_equal,
            }) |operation| {
                if (version == .tls_1_2 and (operation == .hmac or operation == .hkdf_extract or operation == .hkdf_expand)) continue;
                if (version == .tls_1_3 and operation == .tls12_prf) continue;
                try runCase(Backend, backend, allocator, &trust, port, version, .aes_128_gcm, certificate_group, "localhost", .{ .handshake_failure = operation });
                negatives += 1;
            }
            for ([_]p.Operation{ .aead_seal, .aead_open }) |operation| {
                try runCase(Backend, backend, allocator, &trust, port, version, .aes_128_gcm, certificate_group, "localhost", .{ .record_failure = operation });
                negatives += 1;
            }
        }
    }
    std.debug.print("authenticated sessions={d}; trust/provider failure cases={d}; both standard and SymCrypt\n", .{ successes, negatives });
}
