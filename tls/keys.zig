const std = @import("std");
const symcrypt = @import("symcrypt");
const p = @import("httpx").crypto_provider;
const native = @import("native.zig");
const der = @import("der.zig");
const mapError = native.mapError;
const Error = p.ProviderError;
const Allocator = std.mem.Allocator;

const Key = struct {
    algorithm: p.SignatureKeyAlgorithm,
    value: union(enum) {
        ecc: *symcrypt.asymmetric.ecc.PrivateKey,
        rsa: *symcrypt.asymmetric.rsa.PrivateKey,
    },
};

pub fn import(allocator: Allocator, input: p.PrivateKey) Error!*anyopaque {
    if (input.algorithm == .ed25519 or input.algorithm == .rsa_pss) return error.UnsupportedAlgorithm;
    const state = try allocator.create(Key);
    errdefer {
        p.secureWipeValue(state);
        allocator.destroy(state);
    }
    state.algorithm = input.algorithm;
    switch (input.algorithm) {
        .ecdsa_p256, .ecdsa_p384 => {
            const encoded = try der.ecPrivate(input);
            const key = symcrypt.asymmetric.ecc.PrivateKey.import(
                allocator,
                if (input.algorithm == .ecdsa_p256) .p256 else .p384,
                encoded.scalar,
                .signing,
            ) catch |err| return mapError(err);
            errdefer key.deinit();
            if (encoded.public_key) |provided| {
                var actual: [97]u8 = undefined;
                const bytes = actual[0..key.curve().publicLength()];
                key.exportPublic(bytes) catch |err| return mapError(err);
                if (!std.mem.eql(u8, provided, bytes)) return error.InvalidEncoding;
            }
            state.value = .{ .ecc = key };
        },
        .rsa => {
            if (input.encoding != .rsa_pkcs1_der and input.encoding != .pkcs8_der) return error.InvalidEncoding;
            var reader = try der.sequence(try der.privateBody(input));
            try reader.version(0);
            const modulus = try reader.positive();
            const exponent = try der.exponent(try reader.positive());
            const d = try reader.positive();
            // SymCrypt recovers and validates the private key from (n,e,d).
            // Parse all mandatory CRT fields, but never use unvalidated CRT
            // values supplied by an encoding for a signing operation.
            for (0..5) |_| _ = try reader.positive();
            try reader.finish();
            state.value = .{ .rsa = symcrypt.asymmetric.rsa.PrivateKey.importPrivateExponent(
                allocator,
                .{ .modulus_be = modulus, .public_exponent = exponent, .d_be = d },
                .signing,
            ) catch |err| return mapError(err) };
        },
        .rsa_pss, .ed25519 => unreachable,
    }
    return state;
}

pub fn destroy(allocator: Allocator, raw: *anyopaque) void {
    const state: *Key = @ptrCast(@alignCast(raw));
    switch (state.value) {
        inline else => |key| key.deinit(),
    }
    p.secureWipeValue(state);
    allocator.destroy(state);
}

fn digestParts(allocator: Allocator, algorithm: p.HashAlgorithm, parts: []const []const u8, out: []u8) Error!void {
    switch (algorithm) {
        .sha1, .md5 => return error.UnsupportedAlgorithm,
        inline else => |a| {
            const state = symcrypt.hash.Context(@field(symcrypt.hash.Algorithm, @tagName(a))).create(allocator) catch |err| return mapError(err);
            defer state.deinit();
            for (parts) |part| state.update(part) catch |err| return mapError(err);
            var digest = state.final() catch |err| return mapError(err);
            defer p.secureWipe(&digest);
            @memcpy(out, &digest);
        },
    }
}

fn hashAlgorithm(scheme: p.SignatureScheme) Error!p.HashAlgorithm {
    if (scheme.keyAlgorithm() == .rsa_pss) return error.UnsupportedAlgorithm;
    const algorithm = scheme.hashAlgorithm() orelse return error.UnsupportedAlgorithm;
    if (algorithm == .sha1 or algorithm == .md5) return error.UnsupportedAlgorithm;
    return algorithm;
}

pub fn sign(allocator: Allocator, raw: *anyopaque, scheme: p.SignatureScheme, parts: []const []const u8, out: []u8) Error!usize {
    const state: *Key = @ptrCast(@alignCast(raw));
    if (scheme.keyAlgorithm() != state.algorithm) return error.InvalidInput;
    const algorithm = try hashAlgorithm(scheme);
    var storage: [64]u8 = undefined;
    defer p.secureWipe(&storage);
    const digest = storage[0..algorithm.digestLength()];
    try digestParts(allocator, algorithm, parts, digest);
    switch (algorithm) {
        .sha1, .md5 => unreachable,
        inline else => |a| {
            const hash = @field(symcrypt.hash.Algorithm, @tagName(a));
            switch (state.value) {
                .ecc => |key| return key.sign(hash, digest, out) catch |err| return mapError(err),
                .rsa => |key| {
                    const length = key.modulusLength();
                    if (out.len < length) return error.OutputTooSmall;
                    switch (scheme) {
                        .rsa_pkcs1_sha256, .rsa_pkcs1_sha384, .rsa_pkcs1_sha512 => key.signPkcs1v15(hash, digest, out[0..length]) catch |err| return mapError(err),
                        .rsa_pss_rsae_sha256, .rsa_pss_rsae_sha384, .rsa_pss_rsae_sha512 => key.signPss(hash, digest, digest.len, out[0..length]) catch |err| return mapError(err),
                        else => return error.UnsupportedAlgorithm,
                    }
                    return length;
                },
            }
        },
    }
}

pub fn verify(allocator: Allocator, scheme: p.SignatureScheme, input: p.PublicKey, parts: []const []const u8, signature: []const u8) Error!void {
    if (scheme.keyAlgorithm() != input.algorithm) return error.InvalidInput;
    const algorithm = try hashAlgorithm(scheme);
    var storage: [64]u8 = undefined;
    defer p.secureWipe(&storage);
    const digest = storage[0..algorithm.digestLength()];
    try digestParts(allocator, algorithm, parts, digest);
    switch (algorithm) {
        .sha1, .md5 => unreachable,
        inline else => |a| {
            const hash = @field(symcrypt.hash.Algorithm, @tagName(a));
            switch (input.algorithm) {
                .ecdsa_p256, .ecdsa_p384 => {
                    if (input.encoding != .sec1_uncompressed) return error.InvalidEncoding;
                    const key = symcrypt.asymmetric.ecc.PublicKey.import(
                        allocator,
                        if (input.algorithm == .ecdsa_p256) .p256 else .p384,
                        input.bytes,
                        .signing,
                    ) catch |err| return mapError(err);
                    defer key.deinit();
                    key.verify(hash, digest, signature) catch |err| return mapError(err);
                },
                .rsa => {
                    if (input.encoding != .rsa_pkcs1_der) return error.InvalidEncoding;
                    var reader = try der.sequence(input.bytes);
                    const modulus = try reader.positive();
                    const exponent = try der.exponent(try reader.positive());
                    try reader.finish();
                    const key = symcrypt.asymmetric.rsa.PublicKey.import(allocator, modulus, exponent, .signing) catch |err| return mapError(err);
                    defer key.deinit();
                    if (signature.len != modulus.len) return error.InvalidSignatureLength;
                    switch (scheme) {
                        .rsa_pkcs1_sha256, .rsa_pkcs1_sha384, .rsa_pkcs1_sha512 => key.verifyPkcs1v15(hash, digest, signature) catch |err| return mapError(err),
                        .rsa_pss_rsae_sha256, .rsa_pss_rsae_sha384, .rsa_pss_rsae_sha512 => key.verifyPss(hash, digest, .digest_length, signature) catch |err| return mapError(err),
                        else => return error.UnsupportedAlgorithm,
                    }
                },
                .rsa_pss, .ed25519 => return error.UnsupportedAlgorithm,
            }
        },
    }
}
