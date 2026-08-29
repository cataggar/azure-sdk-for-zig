//! Optional Microsoft SymCrypt provider for Azure SDK Core.
//!
//! This package changes only SDK hashing, signing, and secure-random
//! operations dispatched through `core.crypto.CryptoProvider`. It does not
//! replace the TLS cryptography or X.509 trust used by `std.http.Client`.
const std = @import("std");
const core = @import("azure_sdk_core");
const symcrypt = @import("symcrypt");
const build_options = @import("build_options");

pub const version: []const u8 = build_options.version;
pub const Linkage = symcrypt.Linkage;
pub const linkage: Linkage = symcrypt.linkage;
pub const checked: bool = build_options.symcrypt_checked;
pub const symcrypt_version: symcrypt.Version = symcrypt.header_version;
pub const InitError = symcrypt.InitError;
pub const PrimitiveError = symcrypt.Error;

comptime {
    if (!symcrypt.legacy_enabled) {
        @compileError("azure_sdk_core_symcrypt requires zig-symcrypt legacy MD5 support");
    }
}

/// Explicitly perform the process-global, thread-safe SymCrypt handshake.
///
/// Dynamic linkage returns `error.IncompatibleSymCryptVersion` for an
/// incompatible module and `error.SymCryptInitializationFailed` for other
/// initialization failures. Static linkage follows SymCrypt's process-global
/// initialization contract.
pub fn ensureInitialized() InitError!void {
    return symcrypt.ensureInitialized();
}

/// A single-owner context for a copyable Core crypto-provider descriptor.
///
/// Call `deinit` only after all concurrent descriptor calls have completed.
/// Descriptor copies borrow this value and return `error.ProviderDeinitialized`
/// after `deinit` while this storage remains alive. The value must not be
/// moved after `asProvider` is called and must outlive every descriptor copy.
///
/// Hash, HMAC, and default-provider random calls may execute concurrently.
/// A provider made with `initWithScratchAllocator` additionally requires that
/// allocator to permit concurrent allocation when `randomBytes` is concurrent.
/// Incremental SHA-256 operations own independent allocator-backed state and
/// remain valid after this provider is deinitialized.
pub const Provider = struct {
    scratch_allocator: std.mem.Allocator,
    backend: Backend,
    active: std.atomic.Value(bool),

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    /// Initialize a concurrent provider using the page allocator only for the
    /// temporary all-or-nothing random-output staging buffer.
    pub fn init() InitError!Provider {
        try ensureInitialized();
        return initialized(std.heap.page_allocator, symcrypt_backend);
    }

    /// Initialize with a caller-selected random-output scratch allocator.
    ///
    /// The allocator is borrowed until `deinit`. It is not used by incremental
    /// SHA-256, which always uses the allocator passed to `sha256Init`.
    pub fn initWithScratchAllocator(
        scratch_allocator: std.mem.Allocator,
    ) InitError!Provider {
        try ensureInitialized();
        return initialized(scratch_allocator, symcrypt_backend);
    }

    pub fn asProvider(self: *Provider) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    /// Invalidate borrowed descriptors. SymCrypt itself is process-global and
    /// has no matching shutdown operation.
    pub fn deinit(self: *Provider) void {
        self.active.store(false, .release);
    }

    fn initialized(
        scratch_allocator: std.mem.Allocator,
        backend: Backend,
    ) Provider {
        return .{
            .scratch_allocator = scratch_allocator,
            .backend = backend,
            .active = .init(true),
        };
    }

    fn requireActive(self: *Provider) !void {
        if (!self.active.load(.acquire)) return error.ProviderDeinitialized;
    }

    fn fromContext(context: *anyopaque) *Provider {
        return @ptrCast(@alignCast(context));
    }

    fn randomBytes(context: *anyopaque, output: []u8) !void {
        const self = fromContext(context);
        try self.requireActive();

        if (output.len == 0) {
            return self.backend.randomFill(output);
        }

        const temporary = try self.scratch_allocator.alloc(u8, output.len);
        defer wipeAndFree(self.scratch_allocator, temporary);
        try self.backend.randomFill(temporary);
        @memcpy(output, temporary);
    }

    fn md5(
        context: *anyopaque,
        data: []const u8,
        output: *core.crypto.Md5Digest,
    ) !void {
        const self = fromContext(context);
        try self.requireActive();

        var temporary: core.crypto.Md5Digest = undefined;
        defer wipe(std.mem.asBytes(&temporary));
        try self.backend.md5(data, &temporary);
        output.* = temporary;
    }

    fn sha256(
        context: *anyopaque,
        data: []const u8,
        output: *core.crypto.Sha256Digest,
    ) !void {
        const self = fromContext(context);
        try self.requireActive();

        var temporary: core.crypto.Sha256Digest = undefined;
        defer wipe(std.mem.asBytes(&temporary));
        try self.backend.sha256(data, &temporary);
        output.* = temporary;
    }

    fn hmacSha256(
        context: *anyopaque,
        key: []const u8,
        message: []const u8,
        output: *core.crypto.HmacSha256Digest,
    ) !void {
        const self = fromContext(context);
        try self.requireActive();

        var temporary: core.crypto.HmacSha256Digest = undefined;
        defer wipe(std.mem.asBytes(&temporary));
        try self.backend.hmacSha256(key, message, &temporary);
        output.* = temporary;
    }

    fn sha256Init(
        context: *anyopaque,
        allocator: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        const self = fromContext(context);
        try self.requireActive();

        const backend_hash = try self.backend.sha256Create(allocator);
        errdefer backend_hash.deinit();

        const state = try allocator.create(Sha256State);
        state.* = .{
            .allocator = allocator,
            .backend_hash = backend_hash,
        };
        return .{ .context = state, .vtable = &Sha256State.vtable };
    }
};

const Sha256State = struct {
    allocator: std.mem.Allocator,
    backend_hash: BackendSha256,
    finalized: bool = false,

    const vtable: core.crypto.Sha256Operation.VTable = .{
        .update = &update,
        .final = &final,
        .deinit = &deinit,
    };

    fn fromContext(context: *anyopaque) *Sha256State {
        return @ptrCast(@alignCast(context));
    }

    fn update(context: *anyopaque, data: []const u8) !void {
        const self = fromContext(context);
        if (self.finalized) return error.Sha256AlreadyFinalized;
        return self.backend_hash.update(data);
    }

    fn final(
        context: *anyopaque,
        output: *core.crypto.Sha256Digest,
    ) !void {
        const self = fromContext(context);
        if (self.finalized) return error.Sha256AlreadyFinalized;

        var temporary: core.crypto.Sha256Digest = undefined;
        defer wipe(std.mem.asBytes(&temporary));
        try self.backend_hash.final(&temporary);
        output.* = temporary;
        self.finalized = true;
    }

    fn deinit(context: *anyopaque) void {
        const self = fromContext(context);
        self.backend_hash.deinit();
        const allocator = self.allocator;
        wipe(std.mem.asBytes(self));
        allocator.destroy(self);
    }
};

const Backend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        ensure_initialized: *const fn (context: *anyopaque) anyerror!void,
        random_fill: *const fn (context: *anyopaque, output: []u8) anyerror!void,
        md5: *const fn (
            context: *anyopaque,
            data: []const u8,
            output: *core.crypto.Md5Digest,
        ) anyerror!void,
        sha256: *const fn (
            context: *anyopaque,
            data: []const u8,
            output: *core.crypto.Sha256Digest,
        ) anyerror!void,
        hmac_sha256: *const fn (
            context: *anyopaque,
            key: []const u8,
            message: []const u8,
            output: *core.crypto.HmacSha256Digest,
        ) anyerror!void,
        sha256_create: *const fn (
            context: *anyopaque,
            allocator: std.mem.Allocator,
        ) anyerror!BackendSha256,
    };

    fn ensureInitialized(self: Backend) !void {
        return self.vtable.ensure_initialized(self.context);
    }

    fn randomFill(self: Backend, output: []u8) !void {
        return self.vtable.random_fill(self.context, output);
    }

    fn md5(
        self: Backend,
        data: []const u8,
        output: *core.crypto.Md5Digest,
    ) !void {
        return self.vtable.md5(self.context, data, output);
    }

    fn sha256(
        self: Backend,
        data: []const u8,
        output: *core.crypto.Sha256Digest,
    ) !void {
        return self.vtable.sha256(self.context, data, output);
    }

    fn hmacSha256(
        self: Backend,
        key: []const u8,
        message: []const u8,
        output: *core.crypto.HmacSha256Digest,
    ) !void {
        return self.vtable.hmac_sha256(self.context, key, message, output);
    }

    fn sha256Create(
        self: Backend,
        allocator: std.mem.Allocator,
    ) !BackendSha256 {
        return self.vtable.sha256_create(self.context, allocator);
    }
};

const BackendSha256 = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        update: *const fn (context: *anyopaque, data: []const u8) anyerror!void,
        final: *const fn (
            context: *anyopaque,
            output: *core.crypto.Sha256Digest,
        ) anyerror!void,
        deinit: *const fn (context: *anyopaque) void,
    };

    fn update(self: BackendSha256, data: []const u8) !void {
        return self.vtable.update(self.context, data);
    }

    fn final(
        self: BackendSha256,
        output: *core.crypto.Sha256Digest,
    ) !void {
        return self.vtable.final(self.context, output);
    }

    fn deinit(self: BackendSha256) void {
        self.vtable.deinit(self.context);
    }
};

var symcrypt_backend_token: u8 = 0;

const symcrypt_backend: Backend = .{
    .context = &symcrypt_backend_token,
    .vtable = &.{
        .ensure_initialized = &SymCryptBackend.ensureInitialized,
        .random_fill = &SymCryptBackend.randomFill,
        .md5 = &SymCryptBackend.md5,
        .sha256 = &SymCryptBackend.sha256,
        .hmac_sha256 = &SymCryptBackend.hmacSha256,
        .sha256_create = &SymCryptBackend.sha256Create,
    },
};

const SymCryptBackend = struct {
    fn ensureInitialized(_: *anyopaque) !void {
        return symcrypt.ensureInitialized();
    }

    fn randomFill(_: *anyopaque, output: []u8) !void {
        return symcrypt.random.fill(output);
    }

    fn md5(
        _: *anyopaque,
        data: []const u8,
        output: *core.crypto.Md5Digest,
    ) !void {
        return symcrypt.hash.digestInto(.md5, data, output);
    }

    fn sha256(
        _: *anyopaque,
        data: []const u8,
        output: *core.crypto.Sha256Digest,
    ) !void {
        return symcrypt.hash.digestInto(.sha256, data, output);
    }

    fn hmacSha256(
        _: *anyopaque,
        key: []const u8,
        message: []const u8,
        output: *core.crypto.HmacSha256Digest,
    ) !void {
        return symcrypt.hmac.macInto(.sha256, key, message, output);
    }

    fn sha256Create(
        _: *anyopaque,
        allocator: std.mem.Allocator,
    ) !BackendSha256 {
        const state = try symcrypt.hash.Sha256.create(allocator);
        return .{ .context = state, .vtable = &SymCryptSha256.vtable };
    }
};

const SymCryptSha256 = struct {
    const vtable: BackendSha256.VTable = .{
        .update = &update,
        .final = &final,
        .deinit = &deinit,
    };

    fn state(context: *anyopaque) *symcrypt.hash.Sha256 {
        return @ptrCast(@alignCast(context));
    }

    fn update(context: *anyopaque, data: []const u8) !void {
        return state(context).update(data);
    }

    fn final(
        context: *anyopaque,
        output: *core.crypto.Sha256Digest,
    ) !void {
        var temporary = try state(context).final();
        defer wipe(std.mem.asBytes(&temporary));
        output.* = temporary;
    }

    fn deinit(context: *anyopaque) void {
        state(context).deinit();
    }
};

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

fn wipeAndFree(allocator: std.mem.Allocator, bytes: []u8) void {
    if (bytes.len == 0) return;
    wipe(bytes);
    allocator.rawFree(bytes, .fromByteUnits(1), @returnAddress());
}

fn initWithBackend(
    scratch_allocator: std.mem.Allocator,
    backend: Backend,
) !Provider {
    try backend.ensureInitialized();
    return Provider.initialized(scratch_allocator, backend);
}

const ConformanceState = struct {
    allocator: std.mem.Allocator,
    provider: Provider,

    fn destroy(context: *anyopaque) void {
        const self: *ConformanceState = @ptrCast(@alignCast(context));
        self.provider.deinit();
        const allocator = self.allocator;
        wipe(std.mem.asBytes(self));
        allocator.destroy(self);
    }
};

fn createConformanceProvider(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    _: std.Io,
) !@import("azure_sdk_core_crypto_conformance").ProviderInstance {
    const state = try allocator.create(ConformanceState);
    errdefer allocator.destroy(state);
    state.* = .{
        .allocator = allocator,
        .provider = try Provider.init(),
    };
    return .{
        .provider = state.provider.asProvider(),
        .context = state,
        .deinitFn = &ConformanceState.destroy,
    };
}

fn conformanceFactory() @import("azure_sdk_core_crypto_conformance").ProviderFactory {
    return .{
        .name = "Microsoft SymCrypt 103.13.0",
        .capabilities = .{
            .concurrency = .concurrent_safe,
        },
        .createFn = &createConformanceProvider,
    };
}

test "Core CryptoProvider contracts pass with SymCrypt" {
    const conformance = @import("azure_sdk_core_crypto_conformance");
    try conformance.runCryptoContracts(
        std.testing.allocator,
        std.testing.io,
        conformanceFactory(),
    );
    try conformance.runProviderBoundaryContracts();
}

test "build identity is the pinned SymCrypt configuration" {
    try std.testing.expectEqual(@as(u32, 103), symcrypt_version.api);
    try std.testing.expectEqual(@as(u32, 13), symcrypt_version.minor);
    try std.testing.expectEqual(@as(u32, 0), symcrypt_version.patch);
    try std.testing.expect(symcrypt.legacy_enabled);
    try std.testing.expectEqual(linkage, symcrypt.linkage);
}

test "provider initialization errors propagate unchanged" {
    var fault = FaultBackend{ .initialization_fails = true };
    try std.testing.expectError(
        error.IncompatibleSymCryptVersion,
        initWithBackend(std.testing.allocator, fault.backend()),
    );
    try std.testing.expectEqual(@as(usize, 1), fault.initialization_calls);
}

test "primitive failures leave caller output unchanged" {
    var fault = FaultBackend{};
    var provider = try initWithBackend(std.testing.allocator, fault.backend());
    defer provider.deinit();
    const descriptor = provider.asProvider();

    var random = [_]u8{0x11} ** 8;
    try std.testing.expectError(
        error.ProviderFailure,
        descriptor.vtable.random_bytes(descriptor.context, &random),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x11} ** 8), &random);

    var md5_output = [_]u8{0x22} ** 16;
    try std.testing.expectError(
        error.ProviderFailure,
        descriptor.vtable.md5(descriptor.context, "data", &md5_output),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x22} ** 16), &md5_output);

    var sha256_output = [_]u8{0x33} ** 32;
    try std.testing.expectError(
        error.ProviderFailure,
        descriptor.vtable.sha256(descriptor.context, "data", &sha256_output),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x33} ** 32), &sha256_output);

    var hmac_output = [_]u8{0x44} ** 32;
    try std.testing.expectError(
        error.ProviderFailure,
        descriptor.vtable.hmac_sha256(
            descriptor.context,
            "key",
            "message",
            &hmac_output,
        ),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x44} ** 32), &hmac_output);

    try std.testing.expectError(
        error.ProviderFailure,
        descriptor.sha256Init(std.testing.allocator),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        core.base64.hmacSha256Base64(
            std.testing.allocator,
            descriptor,
            "key",
            "message",
        ),
    );
}

test "random allocation failure and primitive failure are all-or-nothing" {
    var provider = try Provider.initWithScratchAllocator(std.testing.failing_allocator);
    defer provider.deinit();
    const descriptor = provider.asProvider();
    var output = [_]u8{0x7c} ** 32;
    try std.testing.expectError(error.OutOfMemory, descriptor.randomBytes(&output));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x7c} ** 32), &output);

    var tracker = WipeCheckingAllocator.init(std.testing.allocator);
    var fault = FaultBackend{};
    var failing_provider = try initWithBackend(tracker.allocator(), fault.backend());
    defer failing_provider.deinit();
    var failed_output = [_]u8{0x6d} ** 32;
    try std.testing.expectError(
        error.ProviderFailure,
        failing_provider.asProvider().randomBytes(&failed_output),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x6d} ** 32), &failed_output);
    try std.testing.expectEqual(@as(usize, 1), tracker.allocations);
    try std.testing.expectEqual(@as(usize, 1), tracker.frees);
    try std.testing.expect(tracker.all_frees_zero);
}

test "incremental SHA-256 owns wiped state and enforces finalization" {
    var provider = try Provider.init();
    defer provider.deinit();

    var tracker = WipeCheckingAllocator.init(std.testing.allocator);
    var operation = try provider.asProvider().sha256Init(tracker.allocator());
    try operation.update("secret data");
    _ = try operation.final();
    try std.testing.expectError(error.Sha256AlreadyFinalized, operation.final());
    try std.testing.expectError(
        error.Sha256AlreadyFinalized,
        operation.update("after final"),
    );
    operation.deinit();

    try std.testing.expectEqual(@as(usize, 2), tracker.allocations);
    try std.testing.expectEqual(@as(usize, 2), tracker.frees);
    try std.testing.expect(tracker.all_frees_zero);

    var fail_second = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 1 },
    );
    try std.testing.expectError(
        error.OutOfMemory,
        provider.asProvider().sha256Init(fail_second.allocator()),
    );
}

test "incremental provider failure leaves output and lifetime intact" {
    var fault = FaultBackend{ .sha_create_fails = false };
    var provider = try initWithBackend(std.testing.allocator, fault.backend());
    defer provider.deinit();
    var operation = try provider.asProvider().sha256Init(std.testing.allocator);

    var output = [_]u8{0x5c} ** 32;
    try std.testing.expectError(
        error.ProviderFailure,
        operation.vtable.final(operation.context, &output),
    );
    try std.testing.expectEqualSlices(u8, &([_]u8{0x5c} ** 32), &output);
    try operation.update("retry remains permitted after failed final");
    operation.deinit();
    try std.testing.expectEqual(@as(usize, 1), fault.sha_deinits);
}

test "incremental operation is independent after provider deinit" {
    var provider = try Provider.init();
    const descriptor = provider.asProvider();
    var operation = try descriptor.sha256Init(std.testing.allocator);
    defer operation.deinit();

    provider.deinit();
    try operation.update("abc");
    const digest = try operation.final();
    try expectHex(
        "ba7816bf8f01cfea414140de5dae2223" ++
            "b00361a396177a9cb410ff61f20015ad",
        &digest,
    );
    try std.testing.expectError(
        error.ProviderDeinitialized,
        descriptor.sha256("abc"),
    );
    provider.deinit();
}

test "Storage content hash and Shared Key vectors" {
    const allocator = std.testing.allocator;
    var provider = try Provider.init();
    defer provider.deinit();
    const descriptor = provider.asProvider();

    const md5 = try core.base64.md5Base64(allocator, descriptor, "");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("1B2M2Y8AsgTpgAmY7PhCfg==", md5);

    const sha256 = try core.base64.sha256Base64(allocator, descriptor, "hello");
    defer allocator.free(sha256);
    try std.testing.expectEqualStrings(
        "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=",
        sha256,
    );

    const key = try core.base64.decode(allocator, "YWNjb3VudEtleQ==");
    defer wipeAndFree(allocator, key);
    const canonical =
        "GET\n" ++
        "\n" ** 11 ++
        "x-ms-blob-content-md5:2OD7XGeI0jSOrsBn8ZwHTw==\n" ++
        "x-ms-client-request-id:8f978611-738a-4cd4-a318-33b2f31068d9\n" ++
        "x-ms-creation-time:Tue, 25 Oct 2022 16:47:17 GMT\n" ++
        "x-ms-date:Wed, 23 Feb 2022 02:39:43 GMT\n" ++
        "x-ms-enabled-protocols:NFS\n" ++
        "x-ms-enable-snapshot-virtual-directory-access:true\n" ++
        "x-ms-lease-status:unlocked\n" ++
        "x-ms-meta-capital:letter\n" ++
        "x-ms-meta-foo:bar\n" ++
        "x-ms-meta-meta:data\n" ++
        "x-ms-meta-upper:case\n" ++
        "x-ms-request-id:a12bc899-001e-003a-3a91-e8439e000000\n" ++
        "x-ms-return-client-request-id:true\n" ++
        "x-ms-version:2021-10-04\n" ++
        "/accountName/";
    const signature = try core.base64.hmacSha256Base64(
        allocator,
        descriptor,
        key,
        canonical,
    );
    defer wipeAndFree(allocator, signature);
    try std.testing.expectEqualStrings(
        "Wjhed5+kLPnT9/EhIgKd7e0y/AEau6G4KKxrUqZxA8s=",
        signature,
    );
}

test "Tables SharedKeyLite vectors" {
    const allocator = std.testing.allocator;
    var provider = try Provider.init();
    defer provider.deinit();
    const descriptor = provider.asProvider();

    const published = try core.base64.hmacSha256Base64(
        allocator,
        descriptor,
        "account-key",
        "Thu, 23 Apr 2020 09:43:37 GMT\n/account-name/?comp=properties",
    );
    defer wipeAndFree(allocator, published);
    try std.testing.expectEqualStrings(
        "tW8SGePdivpFOEJfTxikbSwjdDWkpxSTfFtqUMED3v8=",
        published,
    );

    const azurite_key = try core.base64.decode(
        allocator,
        "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/" ++
            "K1SZFPTOtr/KBHBeksoGMGw==",
    );
    defer wipeAndFree(allocator, azurite_key);
    const azurite = try core.base64.hmacSha256Base64(
        allocator,
        descriptor,
        azurite_key,
        "Thu, 23 Apr 2020 09:43:37 GMT\n/devstoreaccount1/?comp=properties",
    );
    defer wipeAndFree(allocator, azurite);
    try std.testing.expectEqualStrings(
        "DKy2WIvWLvpXbgT2cc0NqjkcHYoV3AdwfcMHgV8UYd8=",
        azurite,
    );
}

const FaultBackend = struct {
    initialization_fails: bool = false,
    sha_create_fails: bool = true,
    initialization_calls: usize = 0,
    primitive_calls: usize = 0,
    sha_deinits: usize = 0,

    fn backend(self: *FaultBackend) Backend {
        return .{
            .context = self,
            .vtable = &.{
                .ensure_initialized = &FaultBackend.ensureInitialized,
                .random_fill = &FaultBackend.randomFill,
                .md5 = &FaultBackend.md5,
                .sha256 = &FaultBackend.sha256,
                .hmac_sha256 = &FaultBackend.hmacSha256,
                .sha256_create = &FaultBackend.sha256Create,
            },
        };
    }

    fn fromContext(context: *anyopaque) *FaultBackend {
        return @ptrCast(@alignCast(context));
    }

    fn ensureInitialized(context: *anyopaque) !void {
        const self = fromContext(context);
        self.initialization_calls += 1;
        if (self.initialization_fails) {
            return error.IncompatibleSymCryptVersion;
        }
    }

    fn randomFill(context: *anyopaque, output: []u8) !void {
        const self = fromContext(context);
        self.primitive_calls += 1;
        @memset(output, 0xa5);
        return error.ProviderFailure;
    }

    fn md5(
        context: *anyopaque,
        _: []const u8,
        output: *core.crypto.Md5Digest,
    ) !void {
        const self = fromContext(context);
        self.primitive_calls += 1;
        @memset(output, 0xa5);
        return error.ProviderFailure;
    }

    fn sha256(
        context: *anyopaque,
        _: []const u8,
        output: *core.crypto.Sha256Digest,
    ) !void {
        const self = fromContext(context);
        self.primitive_calls += 1;
        @memset(output, 0xa5);
        return error.ProviderFailure;
    }

    fn hmacSha256(
        context: *anyopaque,
        _: []const u8,
        _: []const u8,
        output: *core.crypto.HmacSha256Digest,
    ) !void {
        const self = fromContext(context);
        self.primitive_calls += 1;
        @memset(output, 0xa5);
        return error.ProviderFailure;
    }

    fn sha256Create(
        context: *anyopaque,
        _: std.mem.Allocator,
    ) !BackendSha256 {
        const self = fromContext(context);
        self.primitive_calls += 1;
        if (self.sha_create_fails) return error.ProviderFailure;
        return .{
            .context = self,
            .vtable = &.{
                .update = &FaultBackend.shaUpdate,
                .final = &FaultBackend.shaFinal,
                .deinit = &FaultBackend.shaDeinit,
            },
        };
    }

    fn shaUpdate(_: *anyopaque, _: []const u8) !void {}

    fn shaFinal(
        _: *anyopaque,
        output: *core.crypto.Sha256Digest,
    ) !void {
        @memset(output, 0xa5);
        return error.ProviderFailure;
    }

    fn shaDeinit(context: *anyopaque) void {
        fromContext(context).sha_deinits += 1;
    }
};

const WipeCheckingAllocator = struct {
    backing: std.mem.Allocator,
    allocations: usize = 0,
    frees: usize = 0,
    all_frees_zero: bool = true,

    fn init(backing: std.mem.Allocator) WipeCheckingAllocator {
        return .{ .backing = backing };
    }

    fn allocator(self: *WipeCheckingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = &alloc,
                .resize = &resize,
                .remap = &remap,
                .free = &free,
            },
        };
    }

    fn alloc(
        context: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        const self: *WipeCheckingAllocator = @ptrCast(@alignCast(context));
        const result = self.backing.rawAlloc(
            len,
            alignment,
            return_address,
        ) orelse return null;
        self.allocations += 1;
        return result;
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) bool {
        const self: *WipeCheckingAllocator = @ptrCast(@alignCast(context));
        return self.backing.rawResize(
            memory,
            alignment,
            new_len,
            return_address,
        );
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        const self: *WipeCheckingAllocator = @ptrCast(@alignCast(context));
        return self.backing.rawRemap(
            memory,
            alignment,
            new_len,
            return_address,
        );
    }

    fn free(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) void {
        const self: *WipeCheckingAllocator = @ptrCast(@alignCast(context));
        for (memory) |byte| {
            if (byte != 0) self.all_frees_zero = false;
        }
        self.frees += 1;
        self.backing.rawFree(memory, alignment, return_address);
    }
};

fn expectHex(expected: []const u8, actual: []const u8) !void {
    const digits = "0123456789abcdef";
    try std.testing.expectEqual(actual.len * 2, expected.len);
    for (actual, 0..) |byte, index| {
        try std.testing.expectEqual(digits[byte >> 4], expected[index * 2]);
        try std.testing.expectEqual(
            digits[byte & 0x0f],
            expected[index * 2 + 1],
        );
    }
}
