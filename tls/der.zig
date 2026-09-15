//! Strict, bounded key framing only; cryptographic validation is SymCrypt's.
const std = @import("std");
const p = @import("httpx").crypto_provider;
const Error = p.ProviderError;

pub const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn take(self: *Reader, tag: u8) Error![]const u8 {
        const rest = self.bytes[self.offset..];
        if (rest.len < 2 or rest[0] != tag) return error.InvalidEncoding;
        var header: usize = 2;
        var length: usize = rest[1];
        if (rest[1] & 0x80 != 0) {
            const count = rest[1] & 0x7f;
            if (count == 0 or count > 4 or rest.len < 2 + @as(usize, count) or rest[2] == 0)
                return error.InvalidEncoding;
            length = 0;
            for (rest[2..][0..count]) |byte| {
                length = std.math.mul(usize, length, 256) catch return error.InvalidEncoding;
                length = std.math.add(usize, length, byte) catch return error.InvalidEncoding;
            }
            if (length < 128) return error.InvalidEncoding;
            header += count;
        }
        if (length > rest.len - header) return error.InvalidEncoding;
        self.offset += header + length;
        return rest[header..][0..length];
    }

    pub fn finish(self: Reader) Error!void {
        if (self.offset != self.bytes.len) return error.InvalidEncoding;
    }

    pub fn positive(self: *Reader) Error![]const u8 {
        const bytes = try self.take(2);
        if (bytes.len == 0 or bytes[0] & 0x80 != 0) return error.InvalidEncoding;
        if (bytes[0] == 0) {
            if (bytes.len == 1 or bytes[1] & 0x80 == 0) return error.InvalidEncoding;
            return bytes[1..];
        }
        return bytes;
    }

    pub fn version(self: *Reader, expected: u8) Error!void {
        const bytes = try self.take(2);
        if (bytes.len != 1 or bytes[0] != expected) return error.InvalidEncoding;
    }
};

pub fn sequence(bytes: []const u8) Error!Reader {
    var reader: Reader = .{ .bytes = bytes };
    const content = try reader.take(0x30);
    try reader.finish();
    return .{ .bytes = content };
}

pub fn exponent(bytes: []const u8) Error!u64 {
    if (bytes.len > 8) return error.InvalidEncoding;
    var value: u64 = 0;
    for (bytes) |byte| value = value * 256 + byte;
    return value;
}

fn curveOid(algorithm: p.SignatureKeyAlgorithm) Error![]const u8 {
    return switch (algorithm) {
        .ecdsa_p256 => "\x2a\x86\x48\xce\x3d\x03\x01\x07",
        .ecdsa_p384 => "\x2b\x81\x04\x00\x22",
        else => error.UnsupportedAlgorithm,
    };
}

pub fn privateBody(key: p.PrivateKey) Error![]const u8 {
    if (key.encoding != .pkcs8_der) return key.bytes;
    var reader = try sequence(key.bytes);
    try reader.version(0);
    var algorithm: Reader = .{ .bytes = try reader.take(0x30) };
    const oid = try algorithm.take(6);
    switch (key.algorithm) {
        .rsa => {
            if (!std.mem.eql(u8, oid, "\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01")) return error.InvalidEncoding;
            if (algorithm.offset != algorithm.bytes.len and (try algorithm.take(5)).len != 0) return error.InvalidEncoding;
        },
        .ecdsa_p256, .ecdsa_p384 => {
            if (!std.mem.eql(u8, oid, "\x2a\x86\x48\xce\x3d\x02\x01") or
                !std.mem.eql(u8, try algorithm.take(6), try curveOid(key.algorithm))) return error.InvalidEncoding;
        },
        .rsa_pss, .ed25519 => return error.UnsupportedAlgorithm,
    }
    try algorithm.finish();
    const body = try reader.take(4);
    try reader.finish();
    return body;
}

pub const EcPrivate = struct { scalar: []const u8, public_key: ?[]const u8 = null };

pub fn ecPrivate(key: p.PrivateKey) Error!EcPrivate {
    if (key.encoding == .raw_secret) return .{ .scalar = key.bytes };
    if (key.encoding != .pkcs8_der and key.encoding != .sec1_der) return error.InvalidEncoding;
    var reader = try sequence(try privateBody(key));
    try reader.version(1);
    var result: EcPrivate = .{ .scalar = try reader.take(4) };
    if (reader.offset != reader.bytes.len and reader.bytes[reader.offset] == 0xa0) {
        var params: Reader = .{ .bytes = try reader.take(0xa0) };
        if (!std.mem.eql(u8, try params.take(6), try curveOid(key.algorithm))) return error.InvalidEncoding;
        try params.finish();
    }
    if (reader.offset != reader.bytes.len) {
        var public: Reader = .{ .bytes = try reader.take(0xa1) };
        const bits = try public.take(3);
        if (bits.len == 0 or bits[0] != 0) return error.InvalidEncoding;
        result.public_key = bits[1..];
        try public.finish();
    }
    try reader.finish();
    return result;
}

test "strict key DER rejects truncation noncanonical lengths and trailing values" {
    for ([_][]const u8{ "", "\x30", "\x30\x80", "\x30\x81\x00", "\x30\x82\x00\x80", "\x30\x02\x00", "\x30\x00\x00", "\x30\xff" }) |input|
        try std.testing.expectError(error.InvalidEncoding, sequence(input));
}
