const std = @import("std");

pub const Md5Digest = [16]u8;
pub const Sha256Digest = [32]u8;
pub const HmacSha256Digest = [32]u8;

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

/// A single-owner incremental SHA-256 operation.
///
/// The provider allocates stable operation state with the allocator passed to
/// `CryptoProvider.sha256Init`. The caller must call `deinit` exactly once and
/// must not copy this value after beginning to use it. Unless an
/// implementation documents otherwise, its provider context must remain alive
/// until the operation is deinitialized.
pub const Sha256Operation = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        update: *const fn (context: *anyopaque, data: []const u8) anyerror!void,
        final: *const fn (context: *anyopaque, out: *Sha256Digest) anyerror!void,
        deinit: *const fn (context: *anyopaque) void,
    };

    pub fn update(self: *Sha256Operation, data: []const u8) !void {
        return self.vtable.update(self.context, data);
    }

    pub fn final(self: *Sha256Operation) !Sha256Digest {
        var out: Sha256Digest = undefined;
        errdefer wipe(&out);
        try self.vtable.final(self.context, &out);
        return out;
    }

    pub fn deinit(self: *Sha256Operation) void {
        self.vtable.deinit(self.context);
        self.* = undefined;
    }
};

/// Copyable descriptor for SDK cryptographic operations.
///
/// The descriptor borrows `context`; copies remain valid only while that
/// context is alive. Provider implementations must either make their context
/// concurrent-safe or require callers to serialize every descriptor copy.
/// Failures are returned directly and are never replaced with a fallback
/// provider.
pub const CryptoProvider = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        random_bytes: *const fn (context: *anyopaque, out: []u8) anyerror!void,
        md5: *const fn (context: *anyopaque, data: []const u8, out: *Md5Digest) anyerror!void,
        sha256: *const fn (
            context: *anyopaque,
            data: []const u8,
            out: *Sha256Digest,
        ) anyerror!void,
        hmac_sha256: *const fn (
            context: *anyopaque,
            key: []const u8,
            message: []const u8,
            out: *HmacSha256Digest,
        ) anyerror!void,
        sha256_init: *const fn (
            context: *anyopaque,
            allocator: std.mem.Allocator,
        ) anyerror!Sha256Operation,
    };

    pub fn randomBytes(self: CryptoProvider, out: []u8) !void {
        return self.vtable.random_bytes(self.context, out);
    }

    pub fn md5(self: CryptoProvider, data: []const u8) !Md5Digest {
        var out: Md5Digest = undefined;
        errdefer wipe(&out);
        try self.vtable.md5(self.context, data, &out);
        return out;
    }

    pub fn sha256(self: CryptoProvider, data: []const u8) !Sha256Digest {
        var out: Sha256Digest = undefined;
        errdefer wipe(&out);
        try self.vtable.sha256(self.context, data, &out);
        return out;
    }

    pub fn hmacSha256(
        self: CryptoProvider,
        key: []const u8,
        message: []const u8,
    ) !HmacSha256Digest {
        var out: HmacSha256Digest = undefined;
        errdefer wipe(&out);
        try self.vtable.hmac_sha256(self.context, key, message, &out);
        return out;
    }

    pub fn sha256Init(
        self: CryptoProvider,
        allocator: std.mem.Allocator,
    ) !Sha256Operation {
        return self.vtable.sha256_init(self.context, allocator);
    }
};

/// Pure-Zig provider backed by `std.Io.randomSecure` and `std.crypto`.
///
/// `std.Io.randomSecure` is fallible and is used directly, without falling
/// back to process-local pseudorandomness. The provider context is
/// concurrent-safe when its `std.Io` implementation honors the standard
/// library's thread-safety contract.
pub const StdCryptoProvider = struct {
    io: std.Io,

    const vtable: CryptoProvider.VTable = .{
        .random_bytes = &randomBytesImpl,
        .md5 = &md5Impl,
        .sha256 = &sha256Impl,
        .hmac_sha256 = &hmacSha256Impl,
        .sha256_init = &sha256InitImpl,
    };

    pub fn init(io: std.Io) StdCryptoProvider {
        return .{ .io = io };
    }

    pub fn asProvider(self: *StdCryptoProvider) CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn randomBytesImpl(context: *anyopaque, out: []u8) !void {
        const self: *StdCryptoProvider = @ptrCast(@alignCast(context));
        return self.io.randomSecure(out);
    }

    fn md5Impl(_: *anyopaque, data: []const u8, out: *Md5Digest) !void {
        std.crypto.hash.Md5.hash(data, out, .{});
    }

    fn sha256Impl(_: *anyopaque, data: []const u8, out: *Sha256Digest) !void {
        std.crypto.hash.sha2.Sha256.hash(data, out, .{});
    }

    fn hmacSha256Impl(
        _: *anyopaque,
        key: []const u8,
        message: []const u8,
        out: *HmacSha256Digest,
    ) !void {
        std.crypto.auth.hmac.sha2.HmacSha256.create(out, message, key);
    }

    fn sha256InitImpl(
        _: *anyopaque,
        allocator: std.mem.Allocator,
    ) !Sha256Operation {
        const state = try allocator.create(StdSha256State);
        state.* = .{
            .allocator = allocator,
            .hasher = std.crypto.hash.sha2.Sha256.init(.{}),
        };
        return .{ .context = state, .vtable = &StdSha256State.vtable };
    }
};

const StdSha256State = struct {
    allocator: std.mem.Allocator,
    hasher: std.crypto.hash.sha2.Sha256,
    finalized: bool = false,

    const vtable: Sha256Operation.VTable = .{
        .update = &update,
        .final = &final,
        .deinit = &deinit,
    };

    fn update(context: *anyopaque, data: []const u8) !void {
        const self: *StdSha256State = @ptrCast(@alignCast(context));
        if (self.finalized) return error.Sha256AlreadyFinalized;
        self.hasher.update(data);
    }

    fn final(context: *anyopaque, out: *Sha256Digest) !void {
        const self: *StdSha256State = @ptrCast(@alignCast(context));
        if (self.finalized) return error.Sha256AlreadyFinalized;
        self.hasher.final(out);
        self.finalized = true;
    }

    fn deinit(context: *anyopaque) void {
        const self: *StdSha256State = @ptrCast(@alignCast(context));
        const allocator = self.allocator;
        wipe(std.mem.asBytes(self));
        allocator.destroy(self);
    }
};

test "StdCryptoProvider standard vectors" {
    var provider_impl = StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();

    try std.testing.expectEqualSlices(u8, &.{
        0x90, 0x01, 0x50, 0x98, 0x3c, 0xd2, 0x4f, 0xb0,
        0xd6, 0x96, 0x3f, 0x7d, 0x28, 0xe1, 0x7f, 0x72,
    }, &(try provider.md5("abc")));
    try std.testing.expectEqualSlices(u8, &.{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    }, &(try provider.sha256("abc")));
    try std.testing.expectEqualSlices(u8, &.{
        0xf7, 0xbc, 0x83, 0xf4, 0x30, 0x53, 0x84, 0x24,
        0xb1, 0x32, 0x98, 0xe6, 0xaa, 0x6f, 0xb1, 0x43,
        0xef, 0x4d, 0x59, 0xa1, 0x49, 0x46, 0x17, 0x59,
        0x97, 0x47, 0x9d, 0xbc, 0x2d, 0x1a, 0x3c, 0xd8,
    }, &(try provider.hmacSha256("key", "The quick brown fox jumps over the lazy dog")));
}

test "StdCryptoProvider incremental SHA-256 has stable allocated state" {
    var provider_impl = StdCryptoProvider.init(std.testing.io);
    var operation = try provider_impl.asProvider().sha256Init(std.testing.allocator);
    defer operation.deinit();

    try operation.update("a");
    try operation.update("b");
    try operation.update("c");
    const digest = try operation.final();
    try std.testing.expectEqualSlices(u8, &.{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    }, &digest);
    try std.testing.expectError(error.Sha256AlreadyFinalized, operation.update("d"));
}

test "StdCryptoProvider incremental SHA-256 handles empty input" {
    var provider_impl = StdCryptoProvider.init(std.testing.io);
    var operation = try provider_impl.asProvider().sha256Init(std.testing.allocator);
    defer operation.deinit();

    const digest = try operation.final();
    try std.testing.expectEqualSlices(u8, &.{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    }, &digest);
}

test "StdCryptoProvider incremental SHA-256 propagates allocation failure" {
    var provider_impl = StdCryptoProvider.init(std.testing.io);
    try std.testing.expectError(
        error.OutOfMemory,
        provider_impl.asProvider().sha256Init(std.testing.failing_allocator),
    );
}

test "CryptoProvider descriptors copy and dispatch through borrowed context" {
    const Spy = struct {
        calls: usize = 0,

        const vtable: CryptoProvider.VTable = .{
            .random_bytes = &randomBytes,
            .md5 = &md5,
            .sha256 = &sha256,
            .hmac_sha256 = &hmacSha256,
            .sha256_init = &sha256Init,
        };

        fn provider(self: *@This()) CryptoProvider {
            return .{ .context = self, .vtable = &vtable };
        }

        fn randomBytes(context: *anyopaque, out: []u8) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            @memset(out, 0xa5);
        }

        fn md5(_: *anyopaque, _: []const u8, _: *Md5Digest) !void {
            return error.Unused;
        }

        fn sha256(_: *anyopaque, _: []const u8, _: *Sha256Digest) !void {
            return error.Unused;
        }

        fn hmacSha256(
            _: *anyopaque,
            _: []const u8,
            _: []const u8,
            _: *HmacSha256Digest,
        ) !void {
            return error.Unused;
        }

        fn sha256Init(_: *anyopaque, _: std.mem.Allocator) !Sha256Operation {
            return error.Unused;
        }
    };

    var spy = Spy{};
    const first = spy.provider();
    const copied = first;
    var bytes: [4]u8 = undefined;
    try copied.randomBytes(&bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0xa5, 0xa5, 0xa5, 0xa5 }, &bytes);
    try std.testing.expectEqual(@as(usize, 1), spy.calls);
}

test "StdCryptoProvider does not fall back after secure randomness failure" {
    var provider_impl = StdCryptoProvider.init(std.Io.failing);
    var bytes: [16]u8 = undefined;
    try std.testing.expectError(
        error.EntropyUnavailable,
        provider_impl.asProvider().randomBytes(&bytes),
    );
}
