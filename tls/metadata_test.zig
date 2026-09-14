const std = @import("std");
const testing = std.testing;
const httpx = @import("httpx");
const binding = @import("root.zig");
const native = @import("native.zig");
const symcrypt = @import("symcrypt");
const p = binding.contract;

fn expectMd5(input: []const u8, actual: []const u8) !void {
    var expected: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(input, &expected, .{});
    try testing.expectEqualSlices(u8, &expected, actual);
}

test "ABI2 MD5 permission is independent of native legacy availability and SHA1" {
    var legacy = try symcrypt.hash.Context(.md5).create(testing.allocator);
    defer legacy.deinit();
    try legacy.update("abc");
    const legacy_digest = try legacy.final();
    try expectMd5("abc", &legacy_digest);
    inline for (.{ false, true }) |sha1| {
        inline for (.{ false, true }) |md5| {
            var owner = try binding.Provider.init(testing.allocator, .{
                .allow_sha1_identifier_hash = sha1,
                .allow_md5_identifier_hash = md5,
            });
            const provider = owner.provider();
            try testing.expectEqual(@as(u32, 2), provider.abi_version);
            try testing.expectEqual(@as(u8, 4), @intFromEnum(p.HashAlgorithm.md5));
            const caps = try provider.capabilities();
            try testing.expectEqual(md5, caps.supportsHash(.md5));
            try testing.expectEqual(sha1, caps.supportsHash(.sha1));
            try testing.expectEqual(@as(u8, if (md5) 0x10 else 0), caps.hashes & 0x10);
            try testing.expectEqual(@as(u8, 0), (caps.hmac_hashes | caps.hkdf_hashes | caps.tls12_prf_hashes) & 0x10);
            if (!md5) {
                var fail = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
                try testing.expectError(error.UnsupportedAlgorithm, provider.hashCreate(fail.allocator(), .md5));
                var raw: ?*anyopaque = null;
                try testing.expectError(error.UnsupportedAlgorithm, provider.vtable.hashCreate(provider.context, fail.allocator(), .md5, &raw));
                try testing.expect(raw == null);
            } else {
                var hash = try provider.hashCreate(testing.allocator, .md5);
                defer hash.deinit();
                try hash.update("abc");
                var digest: [16]u8 = undefined;
                try hash.snapshot(&digest);
                try expectMd5("abc", &digest);
            }
        }
    }
}

test "ABI2 MD5 never permits keyed operations even with all capability bits or empty output" {
    const AllBits = struct {
        fn capabilities(_: *anyopaque) p.Capabilities {
            var caps = p.Capabilities.all();
            caps.hashes = 0xff;
            caps.hmac_hashes = 0xff;
            caps.hkdf_hashes = 0xff;
            caps.tls12_prf_hashes = 0xff;
            return caps;
        }
    };
    inline for (.{ false, true }) |permission| {
        var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = permission });
        var provider = owner.provider();
        var table = provider.vtable.*;
        table.capabilities = AllBits.capabilities;
        provider.vtable = &table;
        for ([_]usize{ 0, 16 }) |length| {
            var storage = [_]u8{0xa5} ** 16;
            const output = storage[0..length];
            try testing.expectError(error.UnsupportedAlgorithm, provider.hmac(.md5, "key", &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, provider.hkdfExtract(.md5, "salt", &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, provider.hkdfExpand(.md5, &.{}, &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, provider.tls12Prf(.md5, "secret", "", &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, table.hmac(provider.context, .md5, "key", &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, table.hkdfExtract(provider.context, .md5, "salt", &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, table.hkdfExpand(provider.context, .md5, &.{}, &.{}, output));
            try testing.expectError(error.UnsupportedAlgorithm, table.tls12Prf(provider.context, .md5, "secret", "", &.{}, output));
            try testing.expect(std.mem.allEqual(u8, &storage, 0xa5));
        }
        try testing.expectError(error.UnsupportedAlgorithm, native.mac(.md5));
        inline for (std.meta.tags(p.SignatureScheme)) |scheme| {
            try testing.expect(scheme.hashAlgorithm() != .md5);
        }
        var adapter = httpx.CryptoCertificateVerifier.init(provider);
        try testing.expectError(error.UnsupportedAlgorithm, adapter.verifier().verify(.{
            .algorithm = .{ .oid = "\x2a\x86\x48\x86\xf7\x0d\x01\x01\x04" },
            .issuer_spki_der = &.{},
            .tbs_certificate_der = "metadata",
            .signature = &.{},
        }));
    }
}

test "ABI2 native MD5 snapshots clone transfer and exact direct or facade lengths" {
    var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true });
    var hash = try owner.provider().hashCreate(testing.allocator, .md5);
    defer hash.deinit();
    var digest: [16]u8 = undefined;
    try hash.snapshot(&digest);
    try expectMd5("", &digest);
    try hash.update("a");
    var clone = try hash.clone(testing.allocator);
    defer clone.deinit();
    try hash.update("bc");
    try hash.snapshot(&digest);
    try expectMd5("abc", &digest);
    try clone.update(" different");
    try clone.snapshot(&digest);
    try expectMd5("a different", &digest);
    for ([_]usize{ 0, 15, 17 }) |length| {
        var storage = [_]u8{0xa5} ** 17;
        const output = storage[0..length];
        try testing.expectError(error.InvalidDigestLength, hash.snapshot(output));
        try testing.expect(std.mem.allEqual(u8, &storage, 0xa5));
        const provider = owner.provider();
        try testing.expectError(error.InvalidDigestLength, provider.vtable.hashSnapshot(provider.context, hash.raw_handle.?, output));
        try testing.expect(std.mem.allEqual(u8, output, 0));
        try testing.expect(std.mem.allEqual(u8, storage[length..], 0xa5));
    }
    var moved = try hash.take();
    defer moved.deinit();
    try testing.expectError(error.InvalidHandle, hash.snapshot(&digest));
    try moved.snapshot(&digest);
    try expectMd5("abc", &digest);
    moved.deinit();
    try testing.expectError(error.InvalidHandle, moved.snapshot(&digest));
}

test "ABI2 native MD5 streams with no scratch or post-create allocation" {
    var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true, .max_scratch_bytes = 0 });
    var fail = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 2 });
    var hash = try owner.provider().hashCreate(fail.allocator(), .md5);
    defer hash.deinit();
    const chunk = [_]u8{'a'} ** 1000;
    for (0..1000) |_| try hash.update(&chunk);
    var digest: [16]u8 = undefined;
    try hash.snapshot(&digest);
    var expected: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "7707d6ae4e027c70eea2a935c2296f21");
    try testing.expectEqualSlices(u8, &expected, &digest);
}

test "ABI2 metadata keeps independent backend gates and captured none SHA1 MD5 both ceilings" {
    inline for (.{ false, true }) |backend_md5| {
        inline for (.{ false, true }) |backend_sha1| {
            var owner = try binding.Provider.init(testing.allocator, .{
                .allow_md5_identifier_hash = backend_md5,
                .allow_sha1_identifier_hash = backend_sha1,
            });
            var adapter = httpx.CryptoCertificateVerifier.init(owner.provider());
            inline for (.{ false, true }) |metadata_md5| {
                inline for (.{ false, true }) |metadata_sha1| {
                    var descriptor = adapter.metadataHasher(.{
                        .allow_md5_identifiers = metadata_md5,
                        .allow_sha1_identifiers = metadata_sha1,
                    });
                    try testing.expectEqual(adapter.verifier().context, descriptor.context);
                    inline for ([_]p.HashAlgorithm{ .md5, .sha1, .sha256 }) |algorithm| {
                        const allowed = switch (algorithm) {
                            .md5 => backend_md5 and metadata_md5,
                            .sha1 => backend_sha1 and metadata_sha1,
                            else => true,
                        };
                        var digest: [algorithm.digestLength()]u8 = @splat(0xa5);
                        if (allowed) {
                            try descriptor.hash(testing.allocator, algorithm, "abc", &digest);
                            if (algorithm == .md5) try expectMd5("abc", &digest);
                            var direct: @TypeOf(digest) = undefined;
                            try descriptor.digest_fn(descriptor.context, testing.allocator, algorithm, "abc", &direct);
                            try testing.expectEqualSlices(u8, &digest, &direct);
                        } else {
                            try testing.expectError(error.UnsupportedAlgorithm, descriptor.hash(testing.allocator, algorithm, "abc", &digest));
                            try testing.expect(std.mem.allEqual(u8, &digest, 0));
                            @memset(&digest, 0xa5);
                            try testing.expectError(error.UnsupportedAlgorithm, descriptor.digest_fn(descriptor.context, testing.allocator, algorithm, "abc", &digest));
                            try testing.expect(std.mem.allEqual(u8, &digest, 0));
                        }
                    }
                    descriptor.options = .{ .allow_md5_identifiers = true, .allow_sha1_identifiers = true };
                    inline for ([_]p.HashAlgorithm{ .md5, .sha1 }) |algorithm| {
                        const allowed = if (algorithm == .md5) backend_md5 and metadata_md5 else backend_sha1 and metadata_sha1;
                        var digest: [algorithm.digestLength()]u8 = @splat(0xa5);
                        if (allowed) {
                            try descriptor.hash(testing.allocator, algorithm, "abc", &digest);
                        } else {
                            try testing.expectError(error.UnsupportedAlgorithm, descriptor.hash(testing.allocator, algorithm, "abc", &digest));
                            try testing.expect(std.mem.allEqual(u8, &digest, 0));
                        }
                    }
                    descriptor.options = .{};
                    var digest: [16]u8 = @splat(0xa5);
                    try testing.expectError(error.UnsupportedAlgorithm, descriptor.hash(testing.allocator, .md5, "abc", &digest));
                    try testing.expect(std.mem.allEqual(u8, &digest, 0));
                }
            }
        }
    }
}

test "ABI2 metadata length failures clear outputs before allocation including direct callbacks" {
    var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true });
    var adapter = httpx.CryptoCertificateVerifier.init(owner.provider());
    const descriptor = adapter.metadataHasher(.{ .allow_md5_identifiers = true });
    var fail = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    for ([_]usize{ 0, 15, 17 }) |length| {
        var storage: [17]u8 = @splat(0xa5);
        const output = storage[0..length];
        try testing.expectError(error.InvalidDigestLength, descriptor.hash(fail.allocator(), .md5, "abc", output));
        try testing.expect(std.mem.allEqual(u8, output, 0));
        @memset(output, 0xa5);
        try testing.expectError(error.InvalidDigestLength, descriptor.digest_fn(descriptor.context, fail.allocator(), .md5, "abc", output));
        try testing.expect(std.mem.allEqual(u8, output, 0));
    }
}

fn allocationFixture(allocator: std.mem.Allocator) !void {
    var owner = try binding.Provider.init(allocator, .{ .allow_md5_identifier_hash = true });
    var hash = try owner.provider().hashCreate(allocator, .md5);
    defer hash.deinit();
    try hash.update("abc");
    var clone = try hash.clone(allocator);
    defer clone.deinit();
    var digest: [16]u8 = undefined;
    try clone.snapshot(&digest);
    try expectMd5("abc", &digest);
    var adapter = httpx.CryptoCertificateVerifier.init(owner.provider());
    const descriptor = adapter.metadataHasher(.{ .allow_md5_identifiers = true });
    descriptor.hash(allocator, .md5, "abc", &digest) catch |err| {
        try testing.expect(std.mem.allEqual(u8, &digest, 0));
        return err;
    };
}

test "ABI2 MD5 allocation failures release wiped native and metadata ownership" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFixture, .{});
    var wipe: symcrypt.asymmetric.testing.WipeAllocator = .{ .backing = testing.allocator };
    try allocationFixture(wipe.allocator());
    try testing.expect(wipe.frees >= 6);
    try testing.expectEqual(@as(usize, 0), wipe.nonzero_frees);
}

test "ABI2 MD5 partial create clone and every metadata provider error clean up and wipe" {
    const Fault = struct {
        var base: p.CryptoProvider = undefined;
        var stage: enum { create, update, snapshot, clone } = .create;
        var failure: p.ProviderError = error.InternalError;
        var live: usize = 0;
        fn create(context: *anyopaque, allocator: std.mem.Allocator, algorithm: p.HashAlgorithm, output: *?*anyopaque) p.ProviderError!void {
            try base.vtable.hashCreate(context, allocator, algorithm, output);
            live += 1;
            if (stage == .create) return failure;
        }
        fn update(context: *anyopaque, raw: *anyopaque, data: []const u8) p.ProviderError!void {
            try base.vtable.hashUpdate(context, raw, data);
            if (stage == .update) return failure;
        }
        fn snapshot(context: *anyopaque, raw: *anyopaque, output: []u8) p.ProviderError!void {
            try base.vtable.hashSnapshot(context, raw, output);
            output[0] = 0x55;
            return failure;
        }
        fn clone(context: *anyopaque, raw: *anyopaque, allocator: std.mem.Allocator, output: *?*anyopaque) p.ProviderError!void {
            try base.vtable.hashClone(context, raw, allocator, output);
            live += 1;
            return failure;
        }
        fn destroy(context: *anyopaque, allocator: std.mem.Allocator, raw: *anyopaque) void {
            base.vtable.hashDestroy(context, allocator, raw);
            live -= 1;
        }
    };
    var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true });
    Fault.base = owner.provider();
    var table = Fault.base.vtable.*;
    table.hashCreate = Fault.create;
    table.hashUpdate = Fault.update;
    table.hashSnapshot = Fault.snapshot;
    table.hashClone = Fault.clone;
    table.hashDestroy = Fault.destroy;
    const provider = p.CryptoProvider.init(&owner, &table);
    var adapter = httpx.CryptoCertificateVerifier.init(provider);
    const descriptor = adapter.metadataHasher(.{ .allow_md5_identifiers = true });
    var wipe: symcrypt.asymmetric.testing.WipeAllocator = .{ .backing = testing.allocator };
    inline for (@typeInfo(p.ProviderError).error_set.?) |failure| {
        Fault.failure = @field(p.ProviderError, failure.name);
        inline for (.{ .create, .update, .snapshot }) |stage| {
            Fault.stage = stage;
            var output: [16]u8 = @splat(0xa5);
            try testing.expectError(Fault.failure, descriptor.hash(wipe.allocator(), .md5, "abc", &output));
            try testing.expect(std.mem.allEqual(u8, &output, 0));
            @memset(&output, 0xa5);
            try testing.expectError(Fault.failure, descriptor.digest_fn(descriptor.context, wipe.allocator(), .md5, "abc", &output));
            try testing.expect(std.mem.allEqual(u8, &output, 0));
            try testing.expectEqual(@as(usize, 0), Fault.live);
        }
    }
    Fault.stage = .clone;
    Fault.failure = error.OutOfMemory;
    var hash = try provider.hashCreate(wipe.allocator(), .md5);
    try testing.expectError(error.OutOfMemory, hash.clone(wipe.allocator()));
    try testing.expectEqual(@as(usize, 1), Fault.live);
    hash.deinit();
    try testing.expectEqual(@as(usize, 0), Fault.live);
    try testing.expectEqual(@as(usize, 0), wipe.nonzero_frees);
}

test "ABI2 native metadata pairing keeps exact provider context table and version" {
    var owner = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true });
    var other = try binding.Provider.init(testing.allocator, .{ .allow_md5_identifier_hash = true });
    const provider = owner.provider();
    var adapter = httpx.CryptoCertificateVerifier.init(provider);
    try testing.expect(adapter.matchesProvider(provider));
    const other_provider = other.provider();
    try testing.expectEqual(provider.abi_version, other_provider.abi_version);
    try testing.expectEqual(provider.vtable, other_provider.vtable);
    try testing.expectEqualDeep(try provider.capabilities(), try other_provider.capabilities());
    try testing.expect(!adapter.matchesProvider(other_provider));
    var table = provider.vtable.*;
    var changed = provider;
    changed.vtable = &table;
    try testing.expectEqual(provider.context, changed.context);
    try testing.expectEqualDeep(try provider.capabilities(), try changed.capabilities());
    try testing.expect(!adapter.matchesProvider(changed));
    changed = provider;
    changed.abi_version = 1;
    try testing.expect(!adapter.matchesProvider(changed));
    changed.abi_version = 3;
    try testing.expect(!adapter.matchesProvider(changed));
    var invalid = httpx.CryptoCertificateVerifier.init(changed);
    const descriptor = invalid.metadataHasher(.{ .allow_md5_identifiers = true });
    var digest: [16]u8 = @splat(0xa5);
    try testing.expectError(error.IncompatibleAbiVersion, descriptor.hash(testing.allocator, .md5, "abc", &digest));
    try testing.expect(std.mem.allEqual(u8, &digest, 0));
    @memset(&digest, 0xa5);
    try testing.expectError(error.IncompatibleAbiVersion, descriptor.digest_fn(descriptor.context, testing.allocator, .md5, "abc", &digest));
    try testing.expect(std.mem.allEqual(u8, &digest, 0));
    var another_adapter = httpx.CryptoCertificateVerifier.init(provider);
    const first = adapter.metadataHasher(.{ .allow_md5_identifiers = true });
    const second = another_adapter.metadataHasher(.{ .allow_md5_identifiers = true });
    try testing.expectEqual(adapter.verifier().context, first.context);
    try testing.expectEqual(another_adapter.verifier().context, second.context);
    try testing.expect(first.context != second.context);
}

test "ABI2 borrowed metadata adapter supports concurrent independent MD5 and SHA1 states" {
    var owner = try binding.Provider.init(std.heap.page_allocator, .{
        .allow_md5_identifier_hash = true,
        .allow_sha1_identifier_hash = true,
    });
    var adapter = httpx.CryptoCertificateVerifier.init(owner.provider());
    const descriptor = adapter.metadataHasher(.{ .allow_md5_identifiers = true, .allow_sha1_identifiers = true });
    const Worker = struct {
        fn run(digest: @TypeOf(descriptor)) void {
            for (0..32) |_| {
                var md5: [16]u8 = undefined;
                digest.hash(std.heap.page_allocator, .md5, "abc", &md5) catch @panic("MD5 metadata failed");
                expectMd5("abc", &md5) catch @panic("wrong native MD5");
                var direct: [16]u8 = undefined;
                digest.digest_fn(digest.context, std.heap.page_allocator, .md5, "abc", &direct) catch @panic("direct MD5 failed");
                std.debug.assert(std.mem.eql(u8, &md5, &direct));
                var sha1: [20]u8 = undefined;
                digest.hash(std.heap.page_allocator, .sha1, "abc", &sha1) catch @panic("SHA1 metadata failed");
                var expected: [20]u8 = undefined;
                std.crypto.hash.Sha1.hash("abc", &expected, .{});
                std.debug.assert(std.mem.eql(u8, &sha1, &expected));
            }
        }
    };
    var workers: [4]std.Thread = undefined;
    var started: usize = 0;
    defer for (workers[0..started]) |worker| worker.join();
    for (&workers) |*worker| {
        worker.* = try std.Thread.spawn(.{}, Worker.run, .{descriptor});
        started += 1;
    }
}
