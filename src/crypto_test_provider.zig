const std = @import("std");
const core = @import("azure_sdk_core");

pub const FailurePoint = enum {
    none,
    sha256,
    sha256_init,
    update,
    final,
};

pub const Spy = struct {
    standard: core.crypto.StdCryptoProvider,
    failure: FailurePoint = .none,
    sha256_calls: usize = 0,
    sha256_init_calls: usize = 0,
    update_calls: usize = 0,
    final_calls: usize = 0,

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    pub fn init(io: std.Io) Spy {
        return .{ .standard = core.crypto.StdCryptoProvider.init(io) };
    }

    pub fn asProvider(self: *Spy) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn randomBytes(context: *anyopaque, out: []u8) !void {
        const self: *Spy = @ptrCast(@alignCast(context));
        try self.standard.asProvider().randomBytes(out);
    }

    fn md5(
        context: *anyopaque,
        data: []const u8,
        out: *core.crypto.Md5Digest,
    ) !void {
        const self: *Spy = @ptrCast(@alignCast(context));
        out.* = try self.standard.asProvider().md5(data);
    }

    fn sha256(
        context: *anyopaque,
        data: []const u8,
        out: *core.crypto.Sha256Digest,
    ) !void {
        const self: *Spy = @ptrCast(@alignCast(context));
        self.sha256_calls += 1;
        if (self.failure == .sha256) return error.InjectedCryptoFailure;
        out.* = try self.standard.asProvider().sha256(data);
    }

    fn hmacSha256(
        context: *anyopaque,
        key: []const u8,
        message: []const u8,
        out: *core.crypto.HmacSha256Digest,
    ) !void {
        const self: *Spy = @ptrCast(@alignCast(context));
        out.* = try self.standard.asProvider().hmacSha256(key, message);
    }

    fn sha256Init(
        context: *anyopaque,
        allocator: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        const self: *Spy = @ptrCast(@alignCast(context));
        self.sha256_init_calls += 1;
        if (self.failure == .sha256_init) return error.InjectedCryptoFailure;

        var inner = try self.standard.asProvider().sha256Init(allocator);
        errdefer inner.deinit();
        const state = try allocator.create(Operation);
        state.* = .{
            .allocator = allocator,
            .owner = self,
            .inner = inner,
        };
        return .{ .context = state, .vtable = &Operation.vtable };
    }
};

const Operation = struct {
    allocator: std.mem.Allocator,
    owner: *Spy,
    inner: core.crypto.Sha256Operation,

    const vtable: core.crypto.Sha256Operation.VTable = .{
        .update = &update,
        .final = &final,
        .deinit = &deinit,
    };

    fn update(context: *anyopaque, data: []const u8) !void {
        const self: *Operation = @ptrCast(@alignCast(context));
        self.owner.update_calls += 1;
        if (self.owner.failure == .update) return error.InjectedCryptoFailure;
        try self.inner.update(data);
    }

    fn final(context: *anyopaque, out: *core.crypto.Sha256Digest) !void {
        const self: *Operation = @ptrCast(@alignCast(context));
        self.owner.final_calls += 1;
        if (self.owner.failure == .final) return error.InjectedCryptoFailure;
        out.* = try self.inner.final();
    }

    fn deinit(context: *anyopaque) void {
        const self: *Operation = @ptrCast(@alignCast(context));
        self.inner.deinit();
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};
