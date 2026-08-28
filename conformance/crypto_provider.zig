const std = @import("std");
const core = @import("azure_sdk_core");
pub const fakes = @import("azure_sdk_core_conformance_fakes");

pub const Concurrency = enum {
    caller_serialized,
    concurrent_safe,
};

pub const Capabilities = struct {
    random_bytes: bool = true,
    incremental_sha256: bool = true,
    incremental_uses_allocator: bool = true,
    concurrency: Concurrency = .caller_serialized,
};

pub const ProviderInstance = struct {
    provider: core.crypto.CryptoProvider,
    context: *anyopaque,
    deinitFn: *const fn (context: *anyopaque) void,

    pub fn deinit(self: *ProviderInstance) void {
        self.deinitFn(self.context);
        self.* = undefined;
    }
};

pub const ProviderFactory = struct {
    name: []const u8,
    capabilities: Capabilities,
    context: ?*anyopaque = null,
    createFn: *const fn (
        context: ?*anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
    ) anyerror!ProviderInstance,

    pub fn create(
        self: ProviderFactory,
        allocator: std.mem.Allocator,
        io: std.Io,
    ) !ProviderInstance {
        return self.createFn(self.context, allocator, io);
    }
};

/// Run the deterministic SDK crypto-provider contract.
///
/// Adapter packages should expose their provider through `ProviderFactory`
/// and invoke this runner from their own tests.
pub fn runCryptoContracts(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: ProviderFactory,
) !void {
    var instance = try factory.create(allocator, io);
    defer instance.deinit();
    const provider = instance.provider;

    try expectHex(
        "d41d8cd98f00b204e9800998ecf8427e",
        &(try provider.md5("")),
    );
    try expectHex(
        "900150983cd24fb0d6963f7d28e17f72",
        &(try provider.md5("abc")),
    );
    try expectHex(
        "e3b0c44298fc1c149afbf4c8996fb924" ++ "27ae41e4649b934ca495991b7852b855",
        &(try provider.sha256("")),
    );
    try expectHex(
        "ba7816bf8f01cfea414140de5dae2223" ++ "b00361a396177a9cb410ff61f20015ad",
        &(try provider.sha256("abc")),
    );

    var key_0b: [20]u8 = undefined;
    @memset(&key_0b, 0x0b);
    try expectHex(
        "b0344c61d8db38535ca8afceaf0bf12b" ++ "881dc200c9833da726e9376c2e32cff7",
        &(try provider.hmacSha256(&key_0b, "Hi There")),
    );
    try expectHex(
        "5bdcc146bf60754e6a042426089575c7" ++ "5a003f089d2739839dec58b964ec3843",
        &(try provider.hmacSha256("Jefe", "what do ya want for nothing?")),
    );
    var key_aa: [20]u8 = undefined;
    @memset(&key_aa, 0xaa);
    var data_dd: [50]u8 = undefined;
    @memset(&data_dd, 0xdd);
    try expectHex(
        "773ea91e36800e46854db8ebd09181a7" ++ "2959098b3ef8c122d9635514ced565fe",
        &(try provider.hmacSha256(&key_aa, &data_dd)),
    );
    try expectHex(
        "b613679a0814d9ec772f95d778c35fc5" ++ "ff1697c493715653c6c712144292c5ad",
        &(try provider.hmacSha256("", "")),
    );

    if (factory.capabilities.random_bytes) {
        var empty: [0]u8 = .{};
        try provider.randomBytes(&empty);
        var random: [32]u8 = undefined;
        try provider.randomBytes(&random);
    }

    if (factory.capabilities.incremental_sha256) {
        var operation = try provider.sha256Init(allocator);
        defer operation.deinit();
        try operation.update("");
        try operation.update("a");
        try operation.update("b");
        try operation.update("c");
        try expectHex(
            "ba7816bf8f01cfea414140de5dae2223" ++ "b00361a396177a9cb410ff61f20015ad",
            &(try operation.final()),
        );
        try std.testing.expectError(
            error.Sha256AlreadyFinalized,
            operation.update("after-final"),
        );

        var empty_operation = try provider.sha256Init(allocator);
        defer empty_operation.deinit();
        try expectHex(
            "e3b0c44298fc1c149afbf4c8996fb924" ++ "27ae41e4649b934ca495991b7852b855",
            &(try empty_operation.final()),
        );
    }

    if (factory.capabilities.incremental_sha256 and
        factory.capabilities.incremental_uses_allocator)
    {
        try std.testing.expectError(
            error.OutOfMemory,
            provider.sha256Init(std.testing.failing_allocator),
        );
    }

    if (factory.capabilities.concurrency == .concurrent_safe) {
        try runConcurrencyContract(provider);
    }
}

/// Exercise dispatch spies and providers that write output before failing.
///
/// A provider failure must remain an error through Core's direct and
/// base64-allocating helpers; callers must never receive a partial digest as a
/// successful result or an allocation-produced wrapper value.
pub fn runProviderBoundaryContracts() !void {
    var spy = fakes.SpyCryptoProvider{};
    const copied = spy.asProvider();
    const provider = copied;

    var random: [4]u8 = undefined;
    try provider.randomBytes(&random);
    try std.testing.expectEqualSlices(u8, &.{ 0x5a, 0x5a, 0x5a, 0x5a }, &random);
    _ = try provider.md5("md5");
    try std.testing.expectEqual(fakes.SpyCryptoProvider.Operation.md5, spy.operation);
    try std.testing.expectEqualStrings("md5", spy.data);
    _ = try provider.sha256("sha");
    try std.testing.expectEqual(fakes.SpyCryptoProvider.Operation.sha256, spy.operation);
    try std.testing.expectEqualStrings("sha", spy.data);
    _ = try provider.hmacSha256("key", "message");
    try std.testing.expectEqual(
        fakes.SpyCryptoProvider.Operation.hmac_sha256,
        spy.operation,
    );
    try std.testing.expectEqualStrings("key", spy.key);
    try std.testing.expectEqualStrings("message", spy.message);
    try std.testing.expectError(
        error.SpyIncrementalUnsupported,
        provider.sha256Init(std.testing.allocator),
    );
    try std.testing.expectEqual(
        fakes.SpyCryptoProvider.Operation.sha256_init,
        spy.operation,
    );
    try std.testing.expectEqual(@as(usize, 5), spy.calls);

    var fault = fakes.FaultCryptoProvider{};
    const failing = fault.asProvider();
    var failed_random: [4]u8 = @splat(0);
    try std.testing.expectError(
        error.ProviderFailure,
        failing.randomBytes(&failed_random),
    );
    try std.testing.expectEqual(@as(u8, 0xa5), failed_random[0]);
    try std.testing.expectError(error.ProviderFailure, failing.md5("data"));
    try std.testing.expectError(error.ProviderFailure, failing.sha256("data"));
    try std.testing.expectError(
        error.ProviderFailure,
        failing.hmacSha256("key", "message"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        failing.sha256Init(std.testing.allocator),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        core.base64.md5Base64(std.testing.failing_allocator, failing, "data"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        core.base64.sha256Base64(std.testing.failing_allocator, failing, "data"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        core.base64.hmacSha256Base64(
            std.testing.failing_allocator,
            failing,
            "key",
            "message",
        ),
    );
    try std.testing.expectEqual(@as(usize, 8), fault.calls.load(.monotonic));
}

fn expectHex(expected: []const u8, actual: []const u8) !void {
    const digits = "0123456789abcdef";
    try std.testing.expectEqual(actual.len * 2, expected.len);
    for (actual, 0..) |byte, index| {
        try std.testing.expectEqual(
            digits[byte >> 4],
            expected[index * 2],
        );
        try std.testing.expectEqual(
            digits[byte & 0x0f],
            expected[index * 2 + 1],
        );
    }
}

fn runConcurrencyContract(provider: core.crypto.CryptoProvider) !void {
    const Worker = struct {
        provider: core.crypto.CryptoProvider,
        failed: *std.atomic.Value(bool),

        fn run(self: @This()) void {
            for (0..256) |_| {
                const digest = self.provider.sha256("concurrent") catch {
                    self.failed.store(true, .release);
                    return;
                };
                var expected: core.crypto.Sha256Digest = undefined;
                std.crypto.hash.sha2.Sha256.hash("concurrent", &expected, .{});
                if (!std.mem.eql(u8, &digest, &expected)) {
                    self.failed.store(true, .release);
                    return;
                }
                _ = self.provider.hmacSha256("key", "message") catch {
                    self.failed.store(true, .release);
                    return;
                };
            }
        }
    };

    var failed = std.atomic.Value(bool).init(false);
    const worker = Worker{ .provider = provider, .failed = &failed };
    var threads: [4]std.Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, Worker.run, .{worker});
    }
    for (threads) |thread| thread.join();
    try std.testing.expect(!failed.load(.acquire));
}

const StdProviderState = struct {
    allocator: std.mem.Allocator,
    provider: core.crypto.StdCryptoProvider,

    fn destroy(context: *anyopaque) void {
        const self: *StdProviderState = @ptrCast(@alignCast(context));
        self.allocator.destroy(self);
    }
};

fn createStdProvider(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
) !ProviderInstance {
    const state = try allocator.create(StdProviderState);
    state.* = .{
        .allocator = allocator,
        .provider = core.crypto.StdCryptoProvider.init(io),
    };
    return .{
        .provider = state.provider.asProvider(),
        .context = state,
        .deinitFn = &StdProviderState.destroy,
    };
}

pub fn standardProviderFactory() ProviderFactory {
    return .{
        .name = "std.crypto",
        .capabilities = .{
            .concurrency = .concurrent_safe,
        },
        .createFn = &createStdProvider,
    };
}

test "standard crypto provider conforms" {
    try runCryptoContracts(
        std.testing.allocator,
        std.testing.io,
        standardProviderFactory(),
    );
}

test "crypto provider boundaries reject partial success" {
    try runProviderBoundaryContracts();
}
