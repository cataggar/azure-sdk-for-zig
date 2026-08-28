const std = @import("std");
const core = @import("azure_sdk_core");
const base64 = core.base64;
const crypto = core.crypto;

pub const sas = @import("sas.zig");

test {
    std.testing.refAllDecls(sas);
}

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

fn wipeAndFree(allocator: std.mem.Allocator, bytes: []u8) void {
    if (bytes.len == 0) return;
    wipe(bytes);
    allocator.rawFree(
        bytes,
        .fromByteUnits(@alignOf(u8)),
        @returnAddress(),
    );
}

fn decodeAccountKey(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (encoded.len == 0) return error.InvalidAccountKey;

    const decoder = std.base64.standard.Decoder;
    const decoded_size = try decoder.calcSizeForSlice(encoded);
    if (decoded_size == 0) return error.InvalidAccountKey;

    const decoded = try allocator.alloc(u8, decoded_size);
    errdefer wipeAndFree(allocator, decoded);
    try decoder.decode(decoded, encoded);
    return decoded;
}

/// Shared Key credential for Azure Storage.
///
/// This is a single-owner value because it owns decoded key material. Do not
/// copy it after initialization; call `deinit` exactly once.
pub const StorageSharedKeyCredential = struct {
    allocator: std.mem.Allocator,
    account_name: []const u8,
    decoded_account_key: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        account_name: []const u8,
        encoded_account_key: []const u8,
    ) !StorageSharedKeyCredential {
        const decoded_account_key = try decodeAccountKey(allocator, encoded_account_key);
        errdefer wipeAndFree(allocator, decoded_account_key);

        const owned_account_name = try allocator.dupe(u8, account_name);
        return .{
            .allocator = allocator,
            .account_name = owned_account_name,
            .decoded_account_key = decoded_account_key,
        };
    }

    pub fn deinit(self: *StorageSharedKeyCredential) void {
        self.allocator.free(self.account_name);
        wipeAndFree(self.allocator, self.decoded_account_key);
        self.* = undefined;
    }

    /// Replace the account key without exposing decoded key material.
    ///
    /// A decode or allocation failure leaves the existing key unchanged.
    pub fn replaceAccountKey(
        self: *StorageSharedKeyCredential,
        encoded_account_key: []const u8,
    ) !void {
        const replacement = try decodeAccountKey(self.allocator, encoded_account_key);
        wipeAndFree(self.allocator, self.decoded_account_key);
        self.decoded_account_key = replacement;
    }

    /// Sign a request in-place using the caller's configured crypto provider.
    ///
    /// Pipeline integrations should pass `runtime.crypto`. The provider is
    /// invoked before any authorization value is constructed or installed.
    pub fn signRequest(
        self: *const StorageSharedKeyCredential,
        request: *core.http.Request,
        crypto_provider: crypto.CryptoProvider,
    ) !void {
        const allocator = request.allocator;
        const method_str = @tagName(request.method);
        const content_length = request.headers.get("Content-Length") orelse "";
        const content_type = request.headers.get("Content-Type") orelse "";
        const date = request.headers.get("x-ms-date") orelse request.headers.get("Date") orelse "";
        const ms_version = request.headers.get("x-ms-version") orelse "";
        const resource = extractResource(request.url);

        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n\n\n{s}\n\n{s}\n\n\n\n\n\n\nx-ms-date:{s}\nx-ms-version:{s}\n/{s}{s}",
            .{
                method_str,
                content_length,
                content_type,
                date,
                ms_version,
                self.account_name,
                resource,
            },
        );
        defer allocator.free(string_to_sign);

        const signature = try base64.hmacSha256Base64(
            allocator,
            crypto_provider,
            self.decoded_account_key,
            string_to_sign,
        );
        defer allocator.free(signature);

        const authorization = try std.fmt.allocPrint(
            allocator,
            "SharedKey {s}:{s}",
            .{ self.account_name, signature },
        );
        defer allocator.free(authorization);
        try request.setHeader("Authorization", authorization);
    }
};

/// Extract the path portion from a URL for the canonicalized resource.
fn extractResource(url: []const u8) []const u8 {
    if (std.mem.find(u8, url, "://")) |schema_end| {
        const after_schema = url[schema_end + 3 ..];
        if (std.mem.findScalar(u8, after_schema, '/')) |slash| {
            return after_schema[slash..];
        }
    }
    return "/";
}

/// Generate a service-level or resource-level SAS token.
pub const SasBuilder = struct {
    permissions: []const u8 = "r",
    resource_types: []const u8 = "sco",
    services: []const u8 = "b",
    expiry: []const u8,
    protocol: []const u8 = "https",
    version: []const u8 = "2024-11-04",

    /// Render the SAS query string (without leading '?'), unsigned.
    pub fn toQueryString(self: SasBuilder, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "sv={s}&ss={s}&srt={s}&sp={s}&se={s}&spr={s}",
            .{
                self.version,
                self.services,
                self.resource_types,
                self.permissions,
                self.expiry,
                self.protocol,
            },
        );
    }

    /// Build and sign an account SAS query with the selected crypto provider.
    pub fn sign(
        self: SasBuilder,
        allocator: std.mem.Allocator,
        crypto_provider: crypto.CryptoProvider,
        encoded_account_key: []const u8,
    ) ![]u8 {
        const decoded_account_key = try decodeAccountKey(allocator, encoded_account_key);
        defer wipeAndFree(allocator, decoded_account_key);

        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n{s}\n{s}\n{s}\n\n{s}\n\n{s}\n",
            .{
                self.permissions,
                self.services,
                self.resource_types,
                self.expiry,
                self.protocol,
                self.version,
            },
        );
        defer allocator.free(string_to_sign);

        const signature = try base64.hmacSha256Base64(
            allocator,
            crypto_provider,
            decoded_account_key,
            string_to_sign,
        );
        defer allocator.free(signature);

        const query = try self.toQueryString(allocator);
        defer allocator.free(query);
        return std.fmt.allocPrint(allocator, "{s}&sig={s}", .{ query, signature });
    }
};

/// Storage-specific retry options (e.g. secondary endpoint failover).
pub const StorageRetryOptions = struct {
    max_retries: u32 = 4,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 120_000,
    secondary_host: ?[]const u8 = null,
};

/// Compute Content-MD5 for a blob body (base64-encoded MD5).
///
/// MD5 is provided only for integrity and compatibility, not as a security
/// primitive.
pub fn contentMd5(
    allocator: std.mem.Allocator,
    crypto_provider: crypto.CryptoProvider,
    body: []const u8,
) ![]u8 {
    return base64.md5Base64(allocator, crypto_provider, body);
}

/// Compute x-ms-content-sha256 header value (base64-encoded SHA-256).
pub fn contentSha256(
    allocator: std.mem.Allocator,
    crypto_provider: crypto.CryptoProvider,
    body: []const u8,
) ![]u8 {
    return base64.sha256Base64(allocator, crypto_provider, body);
}

const TestCryptoProvider = struct {
    const Operation = enum {
        none,
        md5,
        sha256,
        hmac_sha256,
    };

    calls: usize = 0,
    operation: Operation = .none,
    fail: bool = false,
    data: [128]u8 = undefined,
    data_len: usize = 0,
    key: [128]u8 = undefined,
    key_len: usize = 0,
    message: [512]u8 = undefined,
    message_len: usize = 0,

    const vtable: crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    fn provider(self: *@This()) crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn record(self: *@This(), operation: Operation) !void {
        self.calls += 1;
        self.operation = operation;
        if (self.fail) return error.ProviderFailure;
    }

    fn randomBytes(_: *anyopaque, _: []u8) !void {
        return error.Unused;
    }

    fn md5(context: *anyopaque, data: []const u8, out: *crypto.Md5Digest) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        @memcpy(self.data[0..data.len], data);
        self.data_len = data.len;
        @memset(out, 0xa5);
        try self.record(.md5);
    }

    fn sha256(context: *anyopaque, data: []const u8, out: *crypto.Sha256Digest) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        @memcpy(self.data[0..data.len], data);
        self.data_len = data.len;
        @memset(out, 0xa5);
        try self.record(.sha256);
    }

    fn hmacSha256(
        context: *anyopaque,
        key: []const u8,
        message: []const u8,
        out: *crypto.HmacSha256Digest,
    ) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        @memcpy(self.key[0..key.len], key);
        self.key_len = key.len;
        @memcpy(self.message[0..message.len], message);
        self.message_len = message.len;
        @memset(out, 0xa5);
        try self.record(.hmac_sha256);
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !crypto.Sha256Operation {
        return error.Unused;
    }
};

const TestWipeAllocator = struct {
    backing: std.mem.Allocator,
    free_count: usize = 0,
    freed_was_zero: [16]bool = [_]bool{false} ** 16,

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = &alloc,
        .resize = &resize,
        .remap = &remap,
        .free = &free,
    };

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn alloc(
        context: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        var all_zero = true;
        for (memory) |byte| {
            if (byte != 0) {
                all_zero = false;
                break;
            }
        }
        self.freed_was_zero[self.free_count] = all_zero;
        self.free_count += 1;
        self.backing.rawFree(memory, alignment, ret_addr);
    }
};

const zero_account_key = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

test "StorageSharedKeyCredential standard provider vector" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        zero_account_key,
    );
    defer credential.deinit();

    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();
    try request.setHeader("x-ms-date", "Sun, 01 Apr 2026 12:00:00 GMT");
    try request.setHeader("x-ms-version", "2024-11-04");

    try credential.signRequest(&request, provider);
    try std.testing.expectEqualStrings(
        "SharedKey myaccount:D11Jhk5PBTOi/UBho44/gLCuSN1yiDiRY+LGm5Nt6t0=",
        request.headers.get("Authorization").?,
    );
}

test "StorageSharedKeyCredential dispatches to selected provider" {
    const allocator = std.testing.allocator;
    var spy = TestCryptoProvider{};
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        "AQID",
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();

    try credential.signRequest(&request, spy.provider());
    try std.testing.expectEqual(.hmac_sha256, spy.operation);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, spy.key[0..spy.key_len]);
    try std.testing.expectEqualStrings(
        "SharedKey myaccount:paWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaU=",
        request.headers.get("Authorization").?,
    );
}

test "StorageSharedKeyCredential provider failure leaves authorization unchanged" {
    const allocator = std.testing.allocator;
    var fault = TestCryptoProvider{ .fail = true };
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        zero_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");

    try std.testing.expectError(
        error.ProviderFailure,
        credential.signRequest(&request, fault.provider()),
    );
    try std.testing.expectEqualStrings(
        "unchanged",
        request.headers.get("Authorization").?,
    );
}

test "decoded credential keys are wiped on failure replacement and deinit" {
    try std.testing.expectError(
        error.InvalidAccountKey,
        StorageSharedKeyCredential.init(std.testing.allocator, "account", ""),
    );

    var invalid_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    try std.testing.expectError(
        error.InvalidCharacter,
        StorageSharedKeyCredential.init(invalid_allocator.allocator(), "account", "QU!D"),
    );
    try std.testing.expectEqual(@as(usize, 1), invalid_allocator.free_count);
    try std.testing.expect(invalid_allocator.freed_was_zero[0]);

    var init_wipe_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    var init_failing_allocator = std.testing.FailingAllocator.init(
        init_wipe_allocator.allocator(),
        .{ .fail_index = 1 },
    );
    try std.testing.expectError(
        error.OutOfMemory,
        StorageSharedKeyCredential.init(
            init_failing_allocator.allocator(),
            "account",
            "AQID",
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), init_wipe_allocator.free_count);
    try std.testing.expect(init_wipe_allocator.freed_was_zero[0]);

    var allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    var credential = try StorageSharedKeyCredential.init(
        allocator.allocator(),
        "a",
        "AQID",
    );

    try std.testing.expectError(
        error.InvalidCharacter,
        credential.replaceAccountKey("QU!D"),
    );
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, credential.decoded_account_key);
    try std.testing.expectEqual(@as(usize, 1), allocator.free_count);
    try std.testing.expect(allocator.freed_was_zero[0]);

    try credential.replaceAccountKey("BAUG");
    try std.testing.expectEqual(@as(usize, 2), allocator.free_count);
    try std.testing.expect(allocator.freed_was_zero[1]);
    credential.deinit();
    try std.testing.expectEqual(@as(usize, 4), allocator.free_count);
    try std.testing.expect(!allocator.freed_was_zero[2]);
    try std.testing.expect(allocator.freed_was_zero[3]);
}

test "SasBuilder standard provider vector" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const builder = SasBuilder{
        .permissions = "rl",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const query = try builder.sign(
        allocator,
        provider_impl.asProvider(),
        zero_account_key,
    );
    defer allocator.free(query);
    try std.testing.expectEqualStrings(
        "sv=2024-11-04&ss=b&srt=sco&sp=rl&se=2026-12-31T23:59:59Z&spr=https&sig=75UtD4FYkG6TWw426Imzj8aCtpniyx8++LQO8UYUevU=",
        query,
    );
}

test "SasBuilder dispatches provider and rejects invalid keys without output" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{ .expiry = "2026-12-31T23:59:59Z" };
    var spy = TestCryptoProvider{};
    const query = try builder.sign(allocator, spy.provider(), "AQID");
    defer allocator.free(query);
    try std.testing.expectEqual(.hmac_sha256, spy.operation);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, spy.key[0..spy.key_len]);

    var fault = TestCryptoProvider{ .fail = true };
    try std.testing.expectError(
        error.ProviderFailure,
        builder.sign(allocator, fault.provider(), "AQID"),
    );
    try std.testing.expectError(
        error.InvalidAccountKey,
        builder.sign(allocator, spy.provider(), ""),
    );

    var wipe_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    try std.testing.expectError(
        error.InvalidCharacter,
        builder.sign(wipe_allocator.allocator(), spy.provider(), "QU!D"),
    );
    try std.testing.expectEqual(@as(usize, 1), wipe_allocator.free_count);
    try std.testing.expect(wipe_allocator.freed_was_zero[0]);
}

test "SasBuilder toQueryString unsigned" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{
        .permissions = "rl",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const query = try builder.toQueryString(allocator);
    defer allocator.free(query);
    try std.testing.expectEqualStrings(
        "sv=2024-11-04&ss=b&srt=sco&sp=rl&se=2026-12-31T23:59:59Z&spr=https",
        query,
    );
}

test "content hash standard vectors include empty bodies" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();

    const md5 = try contentMd5(allocator, provider, "hello");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("XUFAKrxLKna5cZ2REBfFkg==", md5);

    const empty_md5 = try contentMd5(allocator, provider, "");
    defer allocator.free(empty_md5);
    try std.testing.expectEqualStrings("1B2M2Y8AsgTpgAmY7PhCfg==", empty_md5);

    const sha256 = try contentSha256(allocator, provider, "hello");
    defer allocator.free(sha256);
    try std.testing.expectEqualStrings(
        "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=",
        sha256,
    );

    const empty_sha256 = try contentSha256(allocator, provider, "");
    defer allocator.free(empty_sha256);
    try std.testing.expectEqualStrings(
        "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",
        empty_sha256,
    );
}

test "content hashes dispatch provider and propagate failures without output" {
    const allocator = std.testing.allocator;
    var spy = TestCryptoProvider{};

    const md5 = try contentMd5(allocator, spy.provider(), "md5-data");
    defer allocator.free(md5);
    try std.testing.expectEqual(.md5, spy.operation);
    try std.testing.expectEqualStrings("md5-data", spy.data[0..spy.data_len]);

    const sha256 = try contentSha256(allocator, spy.provider(), "sha-data");
    defer allocator.free(sha256);
    try std.testing.expectEqual(.sha256, spy.operation);
    try std.testing.expectEqualStrings("sha-data", spy.data[0..spy.data_len]);

    const empty_sha256 = try contentSha256(allocator, spy.provider(), "");
    defer allocator.free(empty_sha256);
    try std.testing.expectEqual(.sha256, spy.operation);
    try std.testing.expectEqual(@as(usize, 0), spy.data_len);

    var fault = TestCryptoProvider{ .fail = true };
    try std.testing.expectError(
        error.ProviderFailure,
        contentMd5(allocator, fault.provider(), "body"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        contentSha256(allocator, fault.provider(), "body"),
    );
}

fn sharedKeyAllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        zero_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");

    credential.signRequest(&request, provider_impl.asProvider()) catch |err| {
        try std.testing.expectEqualStrings(
            "unchanged",
            request.headers.get("Authorization").?,
        );
        return err;
    };
}

fn sasAllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const builder = SasBuilder{ .expiry = "2026-12-31T23:59:59Z" };
    const query = try builder.sign(
        allocator,
        provider_impl.asProvider(),
        zero_account_key,
    );
    defer allocator.free(query);
}

fn contentMd5AllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const value = try contentMd5(allocator, provider_impl.asProvider(), "body");
    defer allocator.free(value);
}

fn contentSha256AllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const value = try contentSha256(allocator, provider_impl.asProvider(), "body");
    defer allocator.free(value);
}

test "crypto operations clean up on every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        sharedKeyAllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        sasAllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        contentMd5AllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        contentSha256AllocationCase,
        .{},
    );
}

test "extractResource" {
    const resource = extractResource(
        "https://myaccount.blob.core.windows.net/container/blob?x=1",
    );
    try std.testing.expect(std.mem.startsWith(u8, resource, "/container/blob"));
}
