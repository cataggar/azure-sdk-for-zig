//! Tests for the generated `clients.zig`.
//!
//! Kept in a separate file so the emitter can overwrite
//! `clients.zig` without losing test coverage. Wired into the
//! package's test step via `root.zig`.
//!
//! This file is **operator-owned**: `codegen/scripts/sync.sh`
//! marks it as operator-managed and never overwrites an
//! existing copy. Add tests freely.

const std = @import("std");
const core = @import("azure_sdk_core");
const clients = @import("clients.zig");

const CryptoSpy = struct {
    random_calls: usize = 0,
    fail_random: bool = false,

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    fn asProvider(self: *CryptoSpy) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn randomBytes(context: *anyopaque, out: []u8) !void {
        const self: *CryptoSpy = @ptrCast(@alignCast(context));
        self.random_calls += 1;
        if (self.fail_random) return error.SelectedCryptoFailure;
        @memset(out, 0xa5);
    }

    fn md5(_: *anyopaque, _: []const u8, _: *core.crypto.Md5Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn sha256(_: *anyopaque, _: []const u8, _: *core.crypto.Sha256Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn hmacSha256(
        _: *anyopaque,
        _: []const u8,
        _: []const u8,
        _: *core.crypto.HmacSha256Digest,
    ) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        return error.UnexpectedCryptoOperation;
    }
};

const RuntimeCredential = struct {
    credential: core.credentials.TokenCredential = .{
        .getTokenFn = &getToken,
    },
    calls: usize = 0,

    fn asCredential(self: *RuntimeCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
        runtime: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        const self: *RuntimeCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        self.calls += 1;
        var byte: [1]u8 = undefined;
        try runtime.crypto.randomBytes(&byte);
        return .{
            .token = "runtime-token",
            .expires_on = 7_258_118_400,
        };
    }
};

fn authenticatedPipeline(
    allocator: std.mem.Allocator,
    runtime: core.http.HttpRuntime,
    credential: *RuntimeCredential,
    auth_policy: *core.http.BearerTokenAuthPolicy,
    policies: *[1]*core.http.HttpPolicy,
) core.http.HttpPipeline {
    auth_policy.* = core.http.BearerTokenAuthPolicy.init(
        allocator,
        credential.asCredential(),
        &.{"https://storage.azure.com/.default"},
    );
    policies[0] = auth_policy.asPolicy();
    return core.http.HttpPipeline.init(runtime, policies);
}

test "generated client preserves runtime and routes selected crypto provider" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "");
    defer transport.deinit();
    var crypto_spy = CryptoSpy{};
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto_spy.asProvider(),
    );
    var credential = RuntimeCredential{};
    var auth_policy: core.http.BearerTokenAuthPolicy = undefined;
    defer auth_policy.deinit();
    var policies: [1]*core.http.HttpPolicy = undefined;
    const pipeline = authenticatedPipeline(
        allocator,
        runtime,
        &credential,
        &auth_policy,
        &policies,
    );

    var client = clients.BlobClient.init(pipeline, .{
        .endpoint = "https://account.blob.core.windows.net",
    });
    inline for (.{
        client.service(),
        client.container(),
        client.blob(),
        client.appendBlob(),
        client.blockBlob(),
        client.pageBlob(),
    }) |derived| {
        try std.testing.expectEqual(
            runtime.transport.context,
            derived.pipeline.runtime.transport.context,
        );
        try std.testing.expectEqual(
            runtime.crypto.context,
            derived.pipeline.runtime.crypto.context,
        );
    }

    var request = core.http.Request.init(
        allocator,
        .HEAD,
        "https://account.blob.core.windows.net?comp=properties",
    );
    defer request.deinit();
    var response = try client.pipeline.send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(usize, 1), crypto_spy.random_calls);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqualStrings(
        "Bearer " ++ "runtime-token",
        transport.last_headers.get("Authorization").?,
    );
}

test "generated client propagates selected provider failure before transport" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "");
    defer transport.deinit();
    var crypto_spy = CryptoSpy{ .fail_random = true };
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto_spy.asProvider(),
    );
    var credential = RuntimeCredential{};
    var auth_policy: core.http.BearerTokenAuthPolicy = undefined;
    defer auth_policy.deinit();
    var policies: [1]*core.http.HttpPolicy = undefined;
    const pipeline = authenticatedPipeline(
        allocator,
        runtime,
        &credential,
        &auth_policy,
        &policies,
    );
    var client = clients.BlobClient.init(pipeline, .{
        .endpoint = "https://account.blob.core.windows.net",
    });

    var request = core.http.Request.init(
        allocator,
        .HEAD,
        "https://account.blob.core.windows.net?comp=properties",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");
    try std.testing.expectError(
        error.SelectedCryptoFailure,
        client.pipeline.send(&request),
    );

    try std.testing.expectEqualStrings(
        "unchanged",
        request.getHeader("Authorization").?,
    );
    try std.testing.expectEqual(@as(usize, 1), crypto_spy.random_calls);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}
