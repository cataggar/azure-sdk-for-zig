const std = @import("std");
const core = @import("azure_sdk_core");

pub const sha256_digest_length = @sizeOf(core.crypto.Sha256Digest);
pub const sha256_formatted_length = "sha256:".len + (sha256_digest_length * 2);

/// Single-owner incremental SHA-256 computation using the selected runtime
/// crypto provider. Call `deinit` exactly once.
pub const Sha256Digest = struct {
    operation: core.crypto.Sha256Operation,

    pub fn init(
        allocator: std.mem.Allocator,
        provider: core.crypto.CryptoProvider,
    ) !Sha256Digest {
        return .{ .operation = try provider.sha256Init(allocator) };
    }

    pub fn deinit(self: *Sha256Digest) void {
        self.operation.deinit();
        self.* = undefined;
    }

    pub fn update(self: *Sha256Digest, bytes: []const u8) !void {
        try self.operation.update(bytes);
    }

    pub fn finalBytes(self: *Sha256Digest) !core.crypto.Sha256Digest {
        return self.operation.final();
    }

    pub fn final(self: *Sha256Digest) ![sha256_formatted_length]u8 {
        return formatSha256Digest(try self.finalBytes());
    }
};

/// Computes the canonical lowercase `sha256:<hex>` digest for exact bytes.
pub fn computeSha256Digest(
    provider: core.crypto.CryptoProvider,
    bytes: []const u8,
) ![sha256_formatted_length]u8 {
    return formatSha256Digest(try provider.sha256(bytes));
}

/// Formats a SHA-256 hash as canonical lowercase `sha256:<hex>`.
pub fn formatSha256Digest(
    hash: core.crypto.Sha256Digest,
) [sha256_formatted_length]u8 {
    const hex = "0123456789abcdef";
    var formatted: [sha256_formatted_length]u8 = undefined;
    @memcpy(formatted[0.."sha256:".len], "sha256:");
    for (hash, 0..) |byte, index| {
        const offset = "sha256:".len + (index * 2);
        formatted[offset] = hex[byte >> 4];
        formatted[offset + 1] = hex[byte & 0x0f];
    }
    return formatted;
}

/// Validates a SHA-256 OCI/Docker content digest.
///
/// The algorithm and hexadecimal digits are accepted case-insensitively;
/// formatting helpers always emit the canonical lowercase representation.
pub fn validateSha256Digest(value: []const u8) !void {
    const separator = std.mem.indexOfScalar(u8, value, ':') orelse
        return error.MalformedDigest;
    if (separator == 0) return error.MalformedDigest;
    if (!std.ascii.eqlIgnoreCase(value[0..separator], "sha256"))
        return error.UnsupportedDigestAlgorithm;

    const encoded = value[separator + 1 ..];
    if (encoded.len != sha256_digest_length * 2) return error.MalformedDigest;
    for (encoded) |byte| {
        if (!std.ascii.isHex(byte)) return error.MalformedDigest;
    }
}

/// Compares two validated SHA-256 digests case-insensitively.
pub fn sha256DigestsEqual(left: []const u8, right: []const u8) !bool {
    try validateSha256Digest(left);
    try validateSha256Digest(right);
    return std.ascii.eqlIgnoreCase(left, right);
}

test "incremental digest preserves exact bytes through provider" {
    var provider_impl = core.crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();
    var incremental = try Sha256Digest.init(std.testing.allocator, provider);
    defer incremental.deinit();
    try incremental.update("{\"schemaVersion\":");
    try incremental.update("2}\n");
    const actual = try incremental.final();

    const expected = try computeSha256Digest(provider, "{\"schemaVersion\":2}\n");
    try std.testing.expectEqualSlices(u8, &expected, &actual);

    const without_newline = try computeSha256Digest(provider, "{\"schemaVersion\":2}");
    try std.testing.expect(!std.mem.eql(u8, &expected, &without_newline));
}

test "digest formatting is canonical and validation is case insensitive" {
    var provider_impl = core.crypto.StdCryptoProvider.init(std.testing.io);
    const digest = try computeSha256Digest(provider_impl.asProvider(), "");
    try std.testing.expectEqualStrings(
        "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        &digest,
    );
    try validateSha256Digest(
        "SHA256:E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
    );
    try std.testing.expect(try sha256DigestsEqual(
        &digest,
        "SHA256:E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
    ));
}

test "digest validation distinguishes malformed and unsupported values" {
    try std.testing.expectError(error.MalformedDigest, validateSha256Digest("sha256"));
    try std.testing.expectError(error.MalformedDigest, validateSha256Digest(":abcd"));
    try std.testing.expectError(error.MalformedDigest, validateSha256Digest("sha256:abcd"));
    try std.testing.expectError(
        error.MalformedDigest,
        validateSha256Digest(
            "sha256:g3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        ),
    );
    try std.testing.expectError(
        error.UnsupportedDigestAlgorithm,
        validateSha256Digest(
            "sha512:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        ),
    );
}
