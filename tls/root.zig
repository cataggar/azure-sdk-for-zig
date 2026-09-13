//! Explicit HTTPX TLS primitive selection. This does not select SDK crypto,
//! certificate trust, or std.http TLS. No standard-crypto fallback is used.
const std = @import("std");
const symcrypt = @import("symcrypt");
const native = @import("native.zig");
const keys = @import("keys.zig");
pub const contract = @import("httpx").crypto_provider;
const p = contract;
const Error = p.ProviderError;
const Allocator = std.mem.Allocator;
const mapError = native.mapError;

pub const Provider = struct {
    scratch_allocator: Allocator,
    max_scratch_bytes: usize,
    allow_sha1_identifier_hash: bool,

    pub const Options = struct {
        /// Bounds concatenated AEAD AAD, HKDF info, PRF seed, and key encodings.
        /// Transcript hashes and HMAC inputs are processed incrementally.
        max_scratch_bytes: usize = 64 * 1024,
        /// Raw SHA-1 for explicitly permitted trust metadata identifiers only.
        /// Does not enable SHA-1 signatures, HMAC, HKDF, or TLS PRF.
        allow_sha1_identifier_hash: bool = false,
    };

    /// No native global shutdown is performed. Keep this owner and its
    /// thread-safe scratch allocator alive until all descriptors and handles
    /// are released. Mutable handles remain single-owner/single-threaded.
    pub fn init(scratch_allocator: Allocator, options: Options) symcrypt.InitError!Provider {
        try symcrypt.ensureInitialized();
        return .{
            .scratch_allocator = scratch_allocator,
            .max_scratch_bytes = options.max_scratch_bytes,
            .allow_sha1_identifier_hash = options.allow_sha1_identifier_hash,
        };
    }

    pub fn provider(self: *Provider) p.CryptoProvider {
        return p.CryptoProvider.init(self, &vtable);
    }
};

fn owner(context: *anyopaque) *const Provider {
    return @ptrCast(@alignCast(context));
}

fn cast(comptime T: type, handle: *anyopaque) *T {
    return @ptrCast(@alignCast(handle));
}

fn destroy(comptime T: type, allocator: Allocator, value: *T) void {
    p.secureWipeValue(value);
    allocator.destroy(value);
}

fn capabilities(context: *anyopaque) p.Capabilities {
    var result: p.Capabilities = .{ .random = true, .constant_time_equal = true };
    result.setHash(.sha1, owner(context).allow_sha1_identifier_hash);
    inline for (.{ p.HashAlgorithm.sha256, .sha384, .sha512 }) |a| {
        result.setHash(a, true);
        result.setHmac(a, true);
        result.setHkdf(a, true);
        result.setTls12Prf(a, true);
    }
    inline for ([_]p.AeadAlgorithm{ .aes_128_gcm, .aes_256_gcm, .chacha20_poly1305 }) |a| result.setAead(a, true);
    inline for ([_]p.KeyAgreementAlgorithm{ .x25519, .secp256r1, .secp384r1 }) |a| result.setKeyAgreement(a, true);
    inline for (.{
        p.SignatureScheme.ecdsa_secp256r1_sha256,
        .ecdsa_secp384r1_sha384,
        .rsa_pkcs1_sha256,
        .rsa_pkcs1_sha384,
        .rsa_pkcs1_sha512,
        .rsa_pss_rsae_sha256,
        .rsa_pss_rsae_sha384,
        .rsa_pss_rsae_sha512,
    }) |scheme| {
        result.setSign(scheme, true);
        result.setVerify(scheme, true);
    }
    return result;
}

fn random(_: *anyopaque, out: []u8) Error!void {
    symcrypt.random.fill(out) catch |err| return switch (err) {
        error.ExternalFailure, error.HardwareFailure => error.EntropyUnavailable,
        else => mapError(err),
    };
}

const HashState = union(p.HashAlgorithm) {
    sha1: *symcrypt.hash.Context(.sha1),
    sha256: *symcrypt.hash.Context(.sha256),
    sha384: *symcrypt.hash.Context(.sha384),
    sha512: *symcrypt.hash.Context(.sha512),
};

fn hashCreate(context: *anyopaque, allocator: Allocator, algorithm: p.HashAlgorithm, out: *?*anyopaque) Error!void {
    if (algorithm == .sha1 and !owner(context).allow_sha1_identifier_hash) return error.UnsupportedAlgorithm;
    const state = try allocator.create(HashState);
    errdefer destroy(HashState, allocator, state);
    state.* = switch (algorithm) {
        inline else => |a| @unionInit(HashState, @tagName(a), symcrypt.hash.Context(@field(symcrypt.hash.Algorithm, @tagName(a))).create(allocator) catch |err| return mapError(err)),
    };
    out.* = state;
}

fn hashUpdate(_: *anyopaque, raw: *anyopaque, data: []const u8) Error!void {
    switch (cast(HashState, raw).*) {
        inline else => |state| state.update(data) catch |err| return mapError(err),
    }
}

fn hashSnapshot(_: *anyopaque, raw: *anyopaque, out: []u8) Error!void {
    switch (cast(HashState, raw).*) {
        inline else => |state| {
            var digest = state.snapshot() catch |err| return mapError(err);
            defer p.secureWipe(&digest);
            @memcpy(out, &digest);
        },
    }
}

fn hashClone(_: *anyopaque, raw: *anyopaque, allocator: Allocator, out: *?*anyopaque) Error!void {
    const state = try allocator.create(HashState);
    errdefer destroy(HashState, allocator, state);
    state.* = switch (cast(HashState, raw).*) {
        inline else => |source, a| @unionInit(HashState, @tagName(a), source.clone(allocator) catch |err| return mapError(err)),
    };
    out.* = state;
}

fn hashDestroy(_: *anyopaque, allocator: Allocator, raw: *anyopaque) void {
    const state = cast(HashState, raw);
    switch (state.*) {
        inline else => |hash| hash.deinit(),
    }
    destroy(HashState, allocator, state);
}

fn hmac(context: *anyopaque, algorithm: p.HashAlgorithm, key: []const u8, parts: []const []const u8, out: []u8) Error!void {
    switch (algorithm) {
        .sha1 => return error.UnsupportedAlgorithm,
        inline else => |a| {
            const Hmac = symcrypt.hmac.Context(@field(symcrypt.hmac.Algorithm, @tagName(a)));
            const state = Hmac.create(owner(context).scratch_allocator, key) catch |err| return mapError(err);
            defer state.deinit();
            for (parts) |part| state.update(part) catch |err| return mapError(err);
            var digest = state.final() catch |err| return mapError(err);
            defer p.secureWipe(&digest);
            @memcpy(out, &digest);
        },
    }
}

fn hkdfExtract(context: *anyopaque, algorithm: p.HashAlgorithm, salt: []const u8, parts: []const []const u8, out: []u8) Error!void {
    // RFC 5869 extract is exactly HMAC; empty salt has identical padding to
    // HashLen zero bytes. Parts never need concatenating.
    return hmac(context, algorithm, salt, parts, out);
}

fn joinParts(context: *anyopaque, parts: []const []const u8) Error![]u8 {
    const self = owner(context);
    var total: usize = 0;
    for (parts) |part| {
        total = std.math.add(usize, total, part.len) catch return error.InvalidInput;
        if (total > self.max_scratch_bytes) return error.InvalidInput;
    }
    const joined = try self.scratch_allocator.alloc(u8, total);
    var offset: usize = 0;
    for (parts) |part| {
        @memcpy(joined[offset..][0..part.len], part);
        offset += part.len;
    }
    return joined;
}

fn freeParts(context: *anyopaque, bytes: []u8) void {
    p.secureWipe(bytes);
    if (bytes.len != 0)
        owner(context).scratch_allocator.rawFree(bytes, .fromByteUnits(@alignOf(u8)), @returnAddress());
}

fn hkdfExpand(context: *anyopaque, algorithm: p.HashAlgorithm, prk: []const u8, parts: []const []const u8, out: []u8) Error!void {
    const mac = try native.mac(algorithm);
    const info = try joinParts(context, parts);
    defer freeParts(context, info);
    var expanded: native.c.SYMCRYPT_HKDF_EXPANDED_KEY = undefined;
    defer p.secureWipeValue(&expanded);
    try native.check(native.c.SymCryptHkdfPrkExpandKey(&expanded, mac, prk.ptr, prk.len));
    if (out.len != 0)
        try native.check(native.c.SymCryptHkdfDerive(&expanded, info.ptr, info.len, out.ptr, out.len));
}

fn tls12Prf(context: *anyopaque, algorithm: p.HashAlgorithm, secret: []const u8, label: []const u8, parts: []const []const u8, out: []u8) Error!void {
    const mac = try native.mac(algorithm);
    if (label.len > owner(context).max_scratch_bytes) return error.InvalidInput;
    const seed = try joinParts(context, parts);
    defer freeParts(context, seed);
    if (out.len != 0)
        try native.check(native.c.SymCryptTlsPrf1_2(mac, secret.ptr, secret.len, label.ptr, label.len, seed.ptr, seed.len, out.ptr, out.len));
}

fn aeadSeal(context: *anyopaque, algorithm: p.AeadAlgorithm, key: []const u8, nonce: []const u8, parts: []const []const u8, plaintext: []const u8, ciphertext: []u8, tag: []u8) Error!void {
    const aad = try joinParts(context, parts);
    defer freeParts(context, aad);
    const in_place = plaintext.ptr == ciphertext.ptr;
    switch (algorithm) {
        .aes_128_gcm, .aes_256_gcm => inline for (.{ p.AeadAlgorithm.aes_128_gcm, .aes_256_gcm }) |a| {
            if (algorithm == a) {
                const Aes = if (a == .aes_128_gcm) symcrypt.aead.Aes128Gcm else symcrypt.aead.Aes256Gcm;
                const expanded = Aes.init(owner(context).scratch_allocator, key) catch |err| return mapError(err);
                defer expanded.deinit();
                if (in_place) {
                    expanded.sealInPlace(nonce, aad, ciphertext, tag) catch |err| return mapError(err);
                } else {
                    expanded.seal(nonce, aad, plaintext, ciphertext, tag) catch |err| return mapError(err);
                }
                return;
            }
        },
        .chacha20_poly1305 => {
            const chacha = symcrypt.aead.ChaCha20Poly1305;
            if (in_place) {
                chacha.sealInPlace(key, nonce, aad, ciphertext, tag) catch |err| return mapError(err);
            } else {
                chacha.seal(key, nonce, aad, plaintext, ciphertext, tag) catch |err| return mapError(err);
            }
        },
    }
}

fn aeadOpen(context: *anyopaque, algorithm: p.AeadAlgorithm, key: []const u8, nonce: []const u8, parts: []const []const u8, ciphertext: []const u8, tag: []const u8, plaintext: []u8) Error!void {
    const aad = try joinParts(context, parts);
    defer freeParts(context, aad);
    const in_place = plaintext.ptr == ciphertext.ptr;
    switch (algorithm) {
        .aes_128_gcm, .aes_256_gcm => inline for (.{ p.AeadAlgorithm.aes_128_gcm, .aes_256_gcm }) |a| {
            if (algorithm == a) {
                const Aes = if (a == .aes_128_gcm) symcrypt.aead.Aes128Gcm else symcrypt.aead.Aes256Gcm;
                const expanded = Aes.init(owner(context).scratch_allocator, key) catch |err| return mapError(err);
                defer expanded.deinit();
                if (in_place) {
                    expanded.openInPlace(nonce, aad, plaintext, tag) catch |err| return mapError(err);
                } else {
                    expanded.open(nonce, aad, ciphertext, plaintext, tag) catch |err| return mapError(err);
                }
                return;
            }
        },
        .chacha20_poly1305 => {
            const chacha = symcrypt.aead.ChaCha20Poly1305;
            if (in_place) {
                chacha.openInPlace(key, nonce, aad, plaintext, tag) catch |err| return mapError(err);
            } else {
                chacha.open(key, nonce, aad, ciphertext, plaintext, tag) catch |err| return mapError(err);
            }
        },
    }
}

const Agreement = struct {
    allocator: Allocator,
    key: union(enum) {
        x25519: *symcrypt.asymmetric.x25519.PrivateKey,
        ecc: *symcrypt.asymmetric.ecc.PrivateKey,
    },
};

fn keyAgreementGenerate(_: *anyopaque, allocator: Allocator, algorithm: p.KeyAgreementAlgorithm, out: *?*anyopaque) Error!void {
    const state = try allocator.create(Agreement);
    errdefer destroy(Agreement, allocator, state);
    state.* = .{
        .allocator = allocator,
        .key = switch (algorithm) {
            .x25519 => .{ .x25519 = symcrypt.asymmetric.x25519.PrivateKey.generate(allocator) catch |err| return mapError(err) },
            .secp256r1, .secp384r1 => .{ .ecc = symcrypt.asymmetric.ecc.PrivateKey.generate(allocator, if (algorithm == .secp256r1) .p256 else .p384, .agreement) catch |err| return mapError(err) },
        },
    };
    out.* = state;
}

fn keyAgreementPublicKey(_: *anyopaque, raw: *anyopaque, out: []u8) Error!void {
    switch (cast(Agreement, raw).key) {
        inline else => |key| key.exportPublic(out) catch |err| return mapError(err),
    }
}

fn keyAgreementAgree(_: *anyopaque, raw: *anyopaque, peer_bytes: []const u8, out: []u8) Error!void {
    const state = cast(Agreement, raw);
    switch (state.key) {
        .x25519 => |key| {
            const peer = symcrypt.asymmetric.x25519.PublicKey.import(state.allocator, peer_bytes) catch |err| return mapError(err);
            defer peer.deinit();
            const secret = key.agree(state.allocator, peer) catch |err| return mapError(err);
            defer secret.deinit();
            @memcpy(out, secret.bytes());
        },
        .ecc => |key| {
            const peer = symcrypt.asymmetric.ecc.PublicKey.import(state.allocator, key.curve(), peer_bytes, .agreement) catch |err| return mapError(err);
            defer peer.deinit();
            const secret = key.agree(state.allocator, peer) catch |err| return mapError(err);
            defer secret.deinit();
            @memcpy(out, secret.bytes());
        },
    }
}

fn keyAgreementDestroy(_: *anyopaque, allocator: Allocator, raw: *anyopaque) void {
    const state = cast(Agreement, raw);
    switch (state.key) {
        inline else => |key| key.deinit(),
    }
    destroy(Agreement, allocator, state);
}

fn signingKeyImport(context: *anyopaque, allocator: Allocator, key: p.PrivateKey, out: *?*anyopaque) Error!void {
    if (key.bytes.len > owner(context).max_scratch_bytes) return error.InvalidInput;
    out.* = try keys.import(allocator, key);
}

fn sign(context: *anyopaque, raw: *anyopaque, scheme: p.SignatureScheme, parts: []const []const u8, out: []u8) Error!usize {
    return keys.sign(owner(context).scratch_allocator, raw, scheme, parts, out);
}

fn signingKeyDestroy(_: *anyopaque, allocator: Allocator, raw: *anyopaque) void {
    keys.destroy(allocator, raw);
}

fn verify(context: *anyopaque, scheme: p.SignatureScheme, key: p.PublicKey, parts: []const []const u8, signature: []const u8) Error!void {
    if (key.bytes.len > owner(context).max_scratch_bytes) return error.InvalidInput;
    return keys.verify(owner(context).scratch_allocator, scheme, key, parts, signature);
}

fn constantTimeEqual(_: *anyopaque, a: []const u8, b: []const u8) Error!bool {
    if (a.len != b.len) return false;
    if (a.len == 0) return true;
    return native.c.SymCryptEqual(a.ptr, b.ptr, a.len) != 0;
}

fn kemGenerate(_: *anyopaque, _: Allocator, _: p.KemAlgorithm, _: *?*anyopaque) Error!void {
    return error.UnsupportedAlgorithm;
}
fn kemPublicKey(_: *anyopaque, _: *anyopaque, _: []u8) Error!void {
    return error.UnsupportedAlgorithm;
}
fn kemEncapsulate(_: *anyopaque, _: p.KemAlgorithm, _: []const u8, _: []u8, _: []u8) Error!void {
    return error.UnsupportedAlgorithm;
}
fn kemDecapsulate(_: *anyopaque, _: *anyopaque, _: []const u8, _: []u8) Error!void {
    return error.UnsupportedAlgorithm;
}
fn kemDestroy(_: *anyopaque, _: Allocator, _: *anyopaque) void {}

const vtable: p.VTable = .{
    .capabilities = capabilities,
    .random = random,
    .hashCreate = hashCreate,
    .hashUpdate = hashUpdate,
    .hashSnapshot = hashSnapshot,
    .hashClone = hashClone,
    .hashDestroy = hashDestroy,
    .hmac = hmac,
    .hkdfExtract = hkdfExtract,
    .hkdfExpand = hkdfExpand,
    .tls12Prf = tls12Prf,
    .aeadSeal = aeadSeal,
    .aeadOpen = aeadOpen,
    .keyAgreementGenerate = keyAgreementGenerate,
    .keyAgreementPublicKey = keyAgreementPublicKey,
    .keyAgreementAgree = keyAgreementAgree,
    .keyAgreementDestroy = keyAgreementDestroy,
    .kemGenerate = kemGenerate,
    .kemPublicKey = kemPublicKey,
    .kemEncapsulate = kemEncapsulate,
    .kemDecapsulate = kemDecapsulate,
    .kemDestroy = kemDestroy,
    .signingKeyImport = signingKeyImport,
    .sign = sign,
    .signingKeyDestroy = signingKeyDestroy,
    .verify = verify,
    .constantTimeEqual = constantTimeEqual,
};

comptime {
    std.testing.refAllDecls(@This());
}

test {
    _ = @import("tests.zig");
}
