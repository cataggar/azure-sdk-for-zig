const std = @import("std");
const binding = @import("root.zig");
const symcrypt = @import("symcrypt");
const p = binding.contract;
const testing = std.testing;

test "optional TLS capabilities exclude unimplemented and legacy algorithms" {
    var owner = try binding.Provider.init(std.testing.allocator, .{});
    const caps = try owner.provider().capabilities();
    try std.testing.expect(caps.supportsHash(.sha256));
    try std.testing.expect(!caps.supportsHash(.sha1));
    try std.testing.expect(!caps.supportsSign(.ed25519));
    try std.testing.expect(!caps.supportsVerify(.rsa_pss_pss_sha256));
    try std.testing.expect(!caps.supportsKem(.ml_kem_768));
}

test "SHA2 transcripts clone snapshot and HMAC agree with independent primitives" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    const provider = owner.provider();
    inline for (.{ p.HashAlgorithm.sha256, .sha384, .sha512 }) |algorithm| {
        const Hash = switch (algorithm) {
            .sha256 => std.crypto.hash.sha2.Sha256,
            .sha384 => std.crypto.hash.sha2.Sha384,
            .sha512 => std.crypto.hash.sha2.Sha512,
            else => unreachable,
        };
        var state = try provider.hashCreate(testing.allocator, algorithm);
        defer state.deinit();
        try state.update("a");
        var clone = try state.clone(testing.allocator);
        defer clone.deinit();
        try state.update("bc");
        try clone.update(" different");
        var actual: [Hash.digest_length]u8 = undefined;
        var expected: [Hash.digest_length]u8 = undefined;
        try state.snapshot(&actual);
        Hash.hash("abc", &expected, .{});
        try testing.expectEqualSlices(u8, &expected, &actual);
        try clone.snapshot(&actual);
        Hash.hash("a different", &expected, .{});
        try testing.expectEqualSlices(u8, &expected, &actual);
        try provider.hmac(algorithm, "key", &.{ "a", "bc" }, &actual);
        std.crypto.auth.hmac.Hmac(Hash).create(&expected, "abc", "key");
        try testing.expectEqualSlices(u8, &expected, &actual);
    }
}

fn hex(comptime text: []const u8) [text.len / 2]u8 {
    var bytes: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, text) catch unreachable;
    return bytes;
}

test "RFC5869 HKDF and independent OpenSSL TLS12 PRF vectors" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    const provider = owner.provider();
    var prk: [32]u8 = undefined;
    var output: [42]u8 = undefined;
    const ikm = [_]u8{0x0b} ** 22;
    const salt = hex("000102030405060708090a0b0c");
    const info = hex("f0f1f2f3f4f5f6f7f8f9");
    try provider.hkdfExtract(.sha256, &salt, &.{ ikm[0..11], ikm[11..] }, &prk);
    try testing.expectEqualSlices(u8, &hex("077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5"), &prk);
    try provider.hkdfExpand(.sha256, &prk, &.{ info[0..5], info[5..] }, &output);
    try testing.expectEqualSlices(u8, &hex("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"), &output);
    var prf: [64]u8 = undefined;
    try provider.tls12Prf(.sha256, "secret", "test label", &.{ "se", "ed" }, &prf);
    try testing.expectEqualSlices(u8, &hex("bfc72aea54e12f176b7549dc7d0082fecd2be093284636015f9149017f433669e453c27d2993bfb7cd5abd8c655edc7a7ab65b8e3f9f5272de648904d9fdc247"), &prf);
}

test "all advertised AEADs interoperate and wipe disjoint and in-place tag failures" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    const provider = owner.provider();
    inline for (comptime std.meta.tags(p.AeadAlgorithm)) |algorithm| {
        const Aead = switch (algorithm) {
            .aes_128_gcm => std.crypto.aead.aes_gcm.Aes128Gcm,
            .aes_256_gcm => std.crypto.aead.aes_gcm.Aes256Gcm,
            .chacha20_poly1305 => std.crypto.aead.chacha_poly.ChaCha20Poly1305,
        };
        const key = [_]u8{0x42} ** Aead.key_length;
        const nonce = [_]u8{0x24} ** Aead.nonce_length;
        const message = "record bytes";
        var ciphertext: [message.len]u8 = undefined;
        var tag: [16]u8 = undefined;
        var expected: [message.len]u8 = undefined;
        var expected_tag: [16]u8 = undefined;
        Aead.encrypt(&expected, &expected_tag, message, "AAD", nonce, key);
        try provider.aeadSeal(algorithm, &key, &nonce, &.{ "A", "AD" }, message, &ciphertext, &tag);
        try testing.expectEqualSlices(u8, &expected, &ciphertext);
        try testing.expectEqualSlices(u8, &expected_tag, &tag);
        var plaintext: [message.len]u8 = undefined;
        try provider.aeadOpen(algorithm, &key, &nonce, &.{"AAD"}, &ciphertext, &tag, &plaintext);
        try testing.expectEqualStrings(message, &plaintext);
        tag[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, provider.aeadOpen(algorithm, &key, &nonce, &.{"AAD"}, &ciphertext, &tag, &plaintext));
        try testing.expectEqualSlices(u8, &([_]u8{0} ** message.len), &plaintext);
        try testing.expectError(error.AuthenticationFailed, provider.aeadOpen(algorithm, &key, &nonce, &.{"AAD"}, &ciphertext, &tag, &ciphertext));
        try testing.expectEqualSlices(u8, &([_]u8{0} ** message.len), &ciphertext);
        @memcpy(&plaintext, message);
        try provider.aeadSeal(algorithm, &key, &nonce, &.{"AAD"}, &plaintext, &plaintext, &tag);
        try testing.expectEqualSlices(u8, &expected, &plaintext);
        try provider.aeadOpen(algorithm, &key, &nonce, &.{"AAD"}, &plaintext, &tag, &plaintext);
        try testing.expectEqualStrings(message, &plaintext);
    }
}

test "X25519 P256 and P384 agreements interoperate with independent keys" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    inline for (comptime std.meta.tags(p.KeyAgreementAlgorithm)) |algorithm| {
        var key = try owner.provider().keyAgreementGenerate(testing.allocator, algorithm);
        defer key.deinit();
        var public: [algorithm.publicKeyLength()]u8 = undefined;
        var actual: [algorithm.sharedSecretLength()]u8 = undefined;
        try key.publicKey(&public);
        if (algorithm == .x25519) {
            const X = std.crypto.dh.X25519;
            const peer = try X.KeyPair.generateDeterministic([_]u8{9} ** X.seed_length);
            const expected = try X.scalarmult(peer.secret_key, public);
            try key.agree(&peer.public_key, &actual);
            try testing.expectEqualSlices(u8, &expected, &actual);
        } else {
            const Curve = if (algorithm == .secp256r1) std.crypto.ecc.P256 else std.crypto.ecc.P384;
            const Ecdsa = if (algorithm == .secp256r1) std.crypto.sign.ecdsa.EcdsaP256Sha256 else std.crypto.sign.ecdsa.EcdsaP384Sha384;
            const peer = try Ecdsa.KeyPair.generateDeterministic([_]u8{9} ** Ecdsa.KeyPair.seed_length);
            const point = try Curve.fromSec1(&public);
            const shared = try point.mul(peer.secret_key.bytes, .big);
            const expected = shared.affineCoordinates().x.toBytes(.big);
            try key.agree(&peer.public_key.toUncompressedSec1(), &actual);
            try testing.expectEqualSlices(u8, &expected, &actual);
        }
    }
}

test "ECDSA signing owns imported scalar and produces strict independently verifiable DER" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    inline for ([_]p.SignatureScheme{ .ecdsa_secp256r1_sha256, .ecdsa_secp384r1_sha384 }) |scheme| {
        const Ecdsa = if (scheme == .ecdsa_secp256r1_sha256) std.crypto.sign.ecdsa.EcdsaP256Sha256 else std.crypto.sign.ecdsa.EcdsaP384Sha384;
        var scalar = [_]u8{0} ** Ecdsa.SecretKey.encoded_length;
        scalar[scalar.len - 1] = 1;
        const independent = try Ecdsa.KeyPair.fromSecretKey(.{ .bytes = scalar });
        var key = try owner.provider().signingKeyImport(testing.allocator, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .raw_secret,
            .bytes = &scalar,
        });
        defer key.deinit();
        @memset(&scalar, 0);
        var storage: [scheme.signatureCapacity().?]u8 = undefined;
        const signature = try key.sign(scheme, &.{ "mes", "sage" }, &storage);
        const decoded = try Ecdsa.Signature.fromDer(signature);
        var verifier = try decoded.verifier(independent.public_key);
        verifier.update("message");
        try verifier.verify();
        const public = independent.public_key.toUncompressedSec1();
        try owner.provider().verify(scheme, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .sec1_uncompressed,
            .bytes = &public,
        }, &.{"message"}, signature);
        try testing.expectError(error.SignatureInvalid, owner.provider().verify(scheme, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .sec1_uncompressed,
            .bytes = &public,
        }, &.{"wrong"}, signature));
    }
}

test "native provider failures propagate without primitive fallback and wipe outputs" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    var digest = [_]u8{0xaa} ** 32;
    symcrypt.testing.failNextHmacCreateAfterAllocation();
    try testing.expectError(error.OutOfMemory, owner.provider().hmac(.sha256, "key", &.{"data"}, &digest));
    try testing.expectEqualSlices(u8, &([_]u8{0} ** 32), &digest);
    var ciphertext = [_]u8{0xaa} ** 4;
    var tag = [_]u8{0xaa} ** 16;
    symcrypt.testing.failNextAesGcmCreateAfterAllocation();
    try testing.expectError(error.OutOfMemory, owner.provider().aeadSeal(.aes_128_gcm, &([_]u8{0} ** 16), &([_]u8{0} ** 12), &.{}, "data", &ciphertext, &tag));
    try testing.expectEqualSlices(u8, &([_]u8{0} ** 4), &ciphertext);
    try testing.expectEqualSlices(u8, &([_]u8{0} ** 16), &tag);
}

fn allocationFixture(allocator: std.mem.Allocator) !void {
    var owner = try binding.Provider.init(allocator, .{});
    const provider = owner.provider();
    var hash = try provider.hashCreate(allocator, .sha384);
    defer hash.deinit();
    try hash.update("transcript");
    var clone = try hash.clone(allocator);
    defer clone.deinit();
    var digest: [48]u8 = undefined;
    try clone.snapshot(&digest);
    try provider.hmac(.sha384, "key", &.{"input"}, &digest);
    var expanded: [48]u8 = undefined;
    try provider.hkdfExpand(.sha384, &digest, &.{"info"}, &expanded);
    var key = try provider.keyAgreementGenerate(allocator, .secp256r1);
    defer key.deinit();
    var public: [65]u8 = undefined;
    try key.publicKey(&public);
    var shared: [32]u8 = undefined;
    try key.agree(&public, &shared);
    var scalar = [_]u8{0} ** 32;
    scalar[31] = 1;
    var signing = try provider.signingKeyImport(allocator, .{ .algorithm = .ecdsa_p256, .encoding = .raw_secret, .bytes = &scalar });
    defer signing.deinit();
    var signature: [72]u8 = undefined;
    _ = try signing.sign(.ecdsa_secp256r1_sha256, &.{"data"}, &signature);
    var ciphertext: [4]u8 = undefined;
    var tag: [16]u8 = undefined;
    try provider.aeadSeal(.aes_128_gcm, &([_]u8{1} ** 16), &([_]u8{2} ** 12), &.{"aad"}, "data", &ciphertext, &tag);
}

test "every injected allocation failure releases partial native and adapter ownership" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFixture, .{});
}

test "bounded concatenation rejects excess scratch rather than truncating inputs" {
    var owner = try binding.Provider.init(testing.allocator, .{ .max_scratch_bytes = 3 });
    var output = [_]u8{0xaa} ** 32;
    try testing.expectError(error.InvalidInput, owner.provider().hkdfExpand(.sha256, &([_]u8{1} ** 32), &.{ "ab", "cd" }, &output));
    try testing.expectEqualSlices(u8, &([_]u8{0} ** 32), &output);
    try testing.expect(try owner.provider().constantTimeEqual("same", "same"));
    try testing.expect(!try owner.provider().constantTimeEqual("same", "diff"));
}

const DerBuilder = struct {
    buffer: [4096]u8 = undefined,
    used: usize = 0,

    fn bytes(self: *const DerBuilder) []const u8 {
        return self.buffer[0..self.used];
    }

    fn field(self: *DerBuilder, tag: u8, value: []const u8) !void {
        const header: usize = if (value.len < 128) 2 else if (value.len < 256) 3 else 4;
        if (value.len > 65535 or self.used + header + value.len > self.buffer.len) return error.NoSpaceLeft;
        const out = self.buffer[self.used..];
        out[0] = tag;
        if (header == 2) {
            out[1] = @intCast(value.len);
        } else if (header == 3) {
            out[1] = 0x81;
            out[2] = @intCast(value.len);
        } else {
            out[1] = 0x82;
            out[2] = @intCast(value.len >> 8);
            out[3] = @truncate(value.len);
        }
        @memcpy(out[header..][0..value.len], value);
        self.used += header + value.len;
    }

    fn integer(self: *DerBuilder, input: []const u8) !void {
        var value = input;
        while (value.len > 1 and value[0] == 0) value = value[1..];
        var padded: [2049]u8 = undefined;
        defer p.secureWipe(&padded);
        if (value.len == 0 or value.len > padded.len - 1) return error.NoSpaceLeft;
        if (value[0] & 0x80 == 0) return self.field(2, value);
        padded[0] = 0;
        @memcpy(padded[1..][0..value.len], value);
        try self.field(2, padded[0 .. value.len + 1]);
    }
};

test "RSA private ownership PKCS1 and PKCS8 import PSS and PKCS1 signatures" {
    const original = try symcrypt.asymmetric.rsa.PrivateKey.generate(testing.allocator, 2048, 65537, .signing);
    defer original.deinit();
    var components = try original.exportPrivate(testing.allocator);
    defer components.deinit();
    var fields: DerBuilder = .{};
    defer p.secureWipeValue(&fields);
    try fields.integer(&.{0});
    try fields.integer(components.modulus_be.bytes());
    try fields.integer(&.{ 1, 0, 1 });
    for ([_][]const u8{
        components.d_be.bytes(),   components.p_be.bytes(),   components.q_be.bytes(),
        components.d_p_be.bytes(), components.d_q_be.bytes(), components.q_inv_be.bytes(),
    }) |part| try fields.integer(part);
    var encoded: DerBuilder = .{};
    defer p.secureWipeValue(&encoded);
    try encoded.field(0x30, fields.bytes());
    var owner = try binding.Provider.init(testing.allocator, .{});
    var key = try owner.provider().signingKeyImport(testing.allocator, .{
        .algorithm = .rsa,
        .encoding = .rsa_pkcs1_der,
        .bytes = encoded.bytes(),
    });
    defer key.deinit();
    var pkcs8_fields: DerBuilder = .{};
    defer p.secureWipeValue(&pkcs8_fields);
    try pkcs8_fields.integer(&.{0});
    try pkcs8_fields.field(0x30, &hex("06092a864886f70d0101010500"));
    try pkcs8_fields.field(4, encoded.bytes());
    var pkcs8: DerBuilder = .{};
    defer p.secureWipeValue(&pkcs8);
    try pkcs8.field(0x30, pkcs8_fields.bytes());
    var imported_pkcs8 = try owner.provider().signingKeyImport(testing.allocator, .{
        .algorithm = .rsa,
        .encoding = .pkcs8_der,
        .bytes = pkcs8.bytes(),
    });
    defer imported_pkcs8.deinit();
    p.secureWipeValue(&encoded);
    p.secureWipeValue(&pkcs8);
    var public_fields: DerBuilder = .{};
    try public_fields.integer(components.modulus_be.bytes());
    try public_fields.integer(&.{ 1, 0, 1 });
    var public: DerBuilder = .{};
    try public.field(0x30, public_fields.bytes());
    const Rsa = std.crypto.Certificate.rsa;
    const independent = try Rsa.PublicKey.fromBytes(&.{ 1, 0, 1 }, components.modulus_be.bytes());
    inline for ([_]p.SignatureScheme{
        .rsa_pkcs1_sha256,    .rsa_pkcs1_sha384,    .rsa_pkcs1_sha512,
        .rsa_pss_rsae_sha256, .rsa_pss_rsae_sha384, .rsa_pss_rsae_sha512,
    }) |scheme| {
        const Hash = switch (comptime scheme.hashAlgorithm().?) {
            .sha256 => std.crypto.hash.sha2.Sha256,
            .sha384 => std.crypto.hash.sha2.Sha384,
            .sha512 => std.crypto.hash.sha2.Sha512,
            else => unreachable,
        };
        const Signature = switch (scheme) {
            .rsa_pkcs1_sha256, .rsa_pkcs1_sha384, .rsa_pkcs1_sha512 => Rsa.PKCS1v1_5Signature,
            else => Rsa.PSSSignature,
        };
        var output: [256]u8 = undefined;
        const signature = try key.sign(scheme, &.{ "mes", "sage" }, &output);
        try Signature.concatVerify(256, Signature.fromBytes(256, signature), &.{"message"}, independent, Hash);
        const public_key: p.PublicKey = .{ .algorithm = .rsa, .encoding = .rsa_pkcs1_der, .bytes = public.bytes() };
        try owner.provider().verify(scheme, public_key, &.{"message"}, signature);
        try testing.expectError(error.SignatureInvalid, owner.provider().verify(scheme, public_key, &.{"wrong"}, signature));
        _ = try imported_pkcs8.sign(scheme, &.{"message"}, &output);
        try Signature.concatVerify(256, Signature.fromBytes(256, &output), &.{"message"}, independent, Hash);
    }
}

test "shared borrowed provider supports concurrent independent operations" {
    const Worker = struct {
        fn operation(provider: p.CryptoProvider) p.ProviderError!void {
            var hash = try provider.hashCreate(std.heap.page_allocator, .sha256);
            defer hash.deinit();
            try hash.update("parallel transcript");
            var digest: [32]u8 = undefined;
            try hash.snapshot(&digest);
            try provider.hmac(.sha256, "parallel key", &.{"message"}, &digest);
            try provider.random(&digest);
        }
        fn run(provider: p.CryptoProvider, result: *?p.ProviderError) void {
            for (0..8) |_| operation(provider) catch |err| {
                result.* = err;
                return;
            };
        }
    };
    var owner = try binding.Provider.init(std.heap.page_allocator, .{});
    var results = [_]?p.ProviderError{null} ** 4;
    {
        var threads: [4]std.Thread = undefined;
        var started: usize = 0;
        defer for (threads[0..started]) |thread| thread.join();
        for (&threads, &results) |*thread, *result| {
            thread.* = try std.Thread.spawn(.{}, Worker.run, .{ owner.provider(), result });
            started += 1;
        }
    }
    for (results) |result| if (result) |err| return err;
}

test "SHA384 and SHA512 HKDF and PRF match independent OpenSSL outputs" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    const cases = [_]struct { algorithm: p.HashAlgorithm, hkdf: []const u8, prf: []const u8 }{
        .{
            .algorithm = .sha384,
            .hkdf = "bcc9cf3bfe49a117d0c0107591c7db2ba8747eccf8fad6e88bf71e8b25bedfd3a3dbbcbbf332ceef9fbee86312e6c7b0",
            .prf = "cdd47dc0124953e293a71e0f3fcc02ab44f08334cb2ca2136fafc00d82a403080ec07bb017728d8d7e2ad075878bed7a",
        },
        .{
            .algorithm = .sha512,
            .hkdf = "93976f7542be922e353cf5440313ab4a877870039432e019c3b87b806713980b0781ec4dbe263624a45768d1e957750c",
            .prf = "1ce9f69e8fea87f0c3cf974128f4fe0de98602938846bf412f11265539879c808f7fa42fcf4c50b7226209f96e7b22f9",
        },
    };
    inline for (cases) |case| {
        var prk: [case.algorithm.digestLength()]u8 = undefined;
        var output: [48]u8 = undefined;
        try owner.provider().hkdfExtract(case.algorithm, "salt", &.{ "in", "put" }, &prk);
        try owner.provider().hkdfExpand(case.algorithm, &prk, &.{ "in", "fo" }, &output);
        try testing.expectEqualSlices(u8, &hex(case.hkdf), &output);
        try owner.provider().tls12Prf(case.algorithm, "secret", "test label", &.{"seed"}, &output);
        try testing.expectEqualSlices(u8, &hex(case.prf), &output);
    }
}

test "SEC1 and PKCS8 EC imports check curve identifiers and embedded public points" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    inline for ([_]p.SignatureScheme{ .ecdsa_secp256r1_sha256, .ecdsa_secp384r1_sha384 }) |scheme| {
        const Ecdsa = if (scheme == .ecdsa_secp256r1_sha256) std.crypto.sign.ecdsa.EcdsaP256Sha256 else std.crypto.sign.ecdsa.EcdsaP384Sha384;
        var scalar = [_]u8{0} ** Ecdsa.SecretKey.encoded_length;
        scalar[scalar.len - 1] = 1;
        const independent = try Ecdsa.KeyPair.fromSecretKey(.{ .bytes = scalar });
        const public = independent.public_key.toUncompressedSec1();
        const curve_oid: []const u8 = if (scheme == .ecdsa_secp256r1_sha256)
            &hex("06082a8648ce3d030107")
        else
            &hex("06052b81040022");
        var fields: DerBuilder = .{};
        defer p.secureWipeValue(&fields);
        try fields.integer(&.{1});
        try fields.field(4, &scalar);
        try fields.field(0xa0, curve_oid);
        var public_bits: DerBuilder = .{};
        try public_bits.field(3, &([_]u8{0} ++ public));
        try fields.field(0xa1, public_bits.bytes());
        var sec1: DerBuilder = .{};
        defer p.secureWipeValue(&sec1);
        try sec1.field(0x30, fields.bytes());
        var key = try owner.provider().signingKeyImport(testing.allocator, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .sec1_der,
            .bytes = sec1.bytes(),
        });
        defer key.deinit();
        var algorithms: DerBuilder = .{};
        try algorithms.field(6, &hex("2a8648ce3d0201"));
        try algorithms.field(6, curve_oid[2..]);
        var pkcs8_fields: DerBuilder = .{};
        defer p.secureWipeValue(&pkcs8_fields);
        try pkcs8_fields.integer(&.{0});
        try pkcs8_fields.field(0x30, algorithms.bytes());
        try pkcs8_fields.field(4, sec1.bytes());
        var pkcs8: DerBuilder = .{};
        defer p.secureWipeValue(&pkcs8);
        try pkcs8.field(0x30, pkcs8_fields.bytes());
        var key2 = try owner.provider().signingKeyImport(testing.allocator, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .pkcs8_der,
            .bytes = pkcs8.bytes(),
        });
        defer key2.deinit();
        var output: [scheme.signatureCapacity().?]u8 = undefined;
        const signed = try key2.sign(scheme, &.{"message"}, &output);
        const signature = try Ecdsa.Signature.fromDer(signed);
        var verifier = try signature.verifier(independent.public_key);
        verifier.update("message");
        try verifier.verify();
        sec1.buffer[sec1.used - 1] ^= 1;
        try testing.expectError(error.InvalidEncoding, owner.provider().signingKeyImport(testing.allocator, .{
            .algorithm = scheme.keyAlgorithm(),
            .encoding = .sec1_der,
            .bytes = sec1.bytes(),
        }));
        try testing.expectError(error.InvalidEncoding, owner.provider().signingKeyImport(testing.allocator, .{
            .algorithm = if (scheme == .ecdsa_secp256r1_sha256) .ecdsa_p384 else .ecdsa_p256,
            .encoding = .pkcs8_der,
            .bytes = pkcs8.bytes(),
        }));
    }
}

test "zero X25519 agreement is rejected and wipes output" {
    var owner = try binding.Provider.init(testing.allocator, .{});
    var key = try owner.provider().keyAgreementGenerate(testing.allocator, .x25519);
    defer key.deinit();
    var output = [_]u8{0xaa} ** 32;
    try testing.expectError(error.InvalidEncoding, key.agree(&([_]u8{0} ** 32), &output));
    try testing.expectEqualSlices(u8, &([_]u8{0} ** 32), &output);
}

test "handle and scratch allocations are zeroed before release" {
    var allocator: symcrypt.asymmetric.testing.WipeAllocator = .{ .backing = testing.allocator };
    try allocationFixture(allocator.allocator());
    try testing.expect(allocator.frees > 0);
    try testing.expectEqual(@as(usize, 0), allocator.nonzero_frees);
}
