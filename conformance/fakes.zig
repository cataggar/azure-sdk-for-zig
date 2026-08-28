const std = @import("std");
const core = @import("azure_sdk_core");

pub const FaultCryptoProvider = struct {
    calls: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    pub fn asProvider(self: *FaultCryptoProvider) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn record(self: *FaultCryptoProvider) !void {
        _ = self.calls.fetchAdd(1, .monotonic);
        return error.ProviderFailure;
    }

    fn randomBytes(context: *anyopaque, out: []u8) !void {
        const self: *FaultCryptoProvider = @ptrCast(@alignCast(context));
        if (out.len > 0) out[0] = 0xa5;
        return self.record();
    }

    fn md5(
        context: *anyopaque,
        _: []const u8,
        out: *core.crypto.Md5Digest,
    ) !void {
        const self: *FaultCryptoProvider = @ptrCast(@alignCast(context));
        @memset(out, 0xa5);
        return self.record();
    }

    fn sha256(
        context: *anyopaque,
        _: []const u8,
        out: *core.crypto.Sha256Digest,
    ) !void {
        const self: *FaultCryptoProvider = @ptrCast(@alignCast(context));
        @memset(out, 0xa5);
        return self.record();
    }

    fn hmacSha256(
        context: *anyopaque,
        _: []const u8,
        _: []const u8,
        out: *core.crypto.HmacSha256Digest,
    ) !void {
        const self: *FaultCryptoProvider = @ptrCast(@alignCast(context));
        @memset(out, 0xa5);
        return self.record();
    }

    fn sha256Init(
        context: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        const self: *FaultCryptoProvider = @ptrCast(@alignCast(context));
        try self.record();
        unreachable;
    }
};

pub const SpyCryptoProvider = struct {
    pub const Operation = enum {
        none,
        random_bytes,
        md5,
        sha256,
        hmac_sha256,
        sha256_init,
    };

    calls: usize = 0,
    operation: Operation = .none,
    data: []const u8 = "",
    key: []const u8 = "",
    message: []const u8 = "",

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    pub fn asProvider(self: *SpyCryptoProvider) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn record(self: *SpyCryptoProvider, operation: Operation) void {
        self.calls += 1;
        self.operation = operation;
    }

    fn randomBytes(context: *anyopaque, out: []u8) !void {
        const self: *SpyCryptoProvider = @ptrCast(@alignCast(context));
        self.record(.random_bytes);
        @memset(out, 0x5a);
    }

    fn md5(
        context: *anyopaque,
        data: []const u8,
        out: *core.crypto.Md5Digest,
    ) !void {
        const self: *SpyCryptoProvider = @ptrCast(@alignCast(context));
        self.record(.md5);
        self.data = data;
        @memset(out, 0x5a);
    }

    fn sha256(
        context: *anyopaque,
        data: []const u8,
        out: *core.crypto.Sha256Digest,
    ) !void {
        const self: *SpyCryptoProvider = @ptrCast(@alignCast(context));
        self.record(.sha256);
        self.data = data;
        @memset(out, 0x5a);
    }

    fn hmacSha256(
        context: *anyopaque,
        key: []const u8,
        message: []const u8,
        out: *core.crypto.HmacSha256Digest,
    ) !void {
        const self: *SpyCryptoProvider = @ptrCast(@alignCast(context));
        self.record(.hmac_sha256);
        self.key = key;
        self.message = message;
        @memset(out, 0x5a);
    }

    fn sha256Init(
        context: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        const self: *SpyCryptoProvider = @ptrCast(@alignCast(context));
        self.record(.sha256_init);
        return error.SpyIncrementalUnsupported;
    }
};

pub const RepeatingReader = struct {
    interface: std.Io.Reader,
    byte: u8,
    remaining: usize,

    pub fn init(byte: u8, length: usize) RepeatingReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .byte = byte,
            .remaining = length,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *RepeatingReader = @alignCast(
            @fieldParentPtr("interface", interface),
        );
        if (self.remaining == 0) return error.EndOfStream;
        var bytes: [4096]u8 = undefined;
        @memset(&bytes, self.byte);
        const count = @min(self.remaining, limit.minInt(bytes.len));
        try writer.writeAll(bytes[0..count]);
        self.remaining -= count;
        return count;
    }
};

pub const CancellingReader = struct {
    interface: std.Io.Reader,
    token: *core.http.CancellationToken,
    emitted: bool = false,

    pub fn init(token: *core.http.CancellationToken) CancellingReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .token = token,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *CancellingReader = @alignCast(
            @fieldParentPtr("interface", interface),
        );
        if (self.emitted) return error.EndOfStream;
        const bytes = limit.sliceConst("part");
        try writer.writeAll(bytes);
        self.emitted = true;
        self.token.cancel();
        return bytes.len;
    }
};
