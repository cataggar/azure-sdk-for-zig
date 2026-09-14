const std = @import("std");
const core_symcrypt = @import("azure_sdk_core_symcrypt");

test "manifest-filtered package exports a usable provider" {
    try std.testing.expectEqualStrings("0.3.0", core_symcrypt.version);
    try std.testing.expectEqual(@as(u32, 103), core_symcrypt.symcrypt_version.api);

    var provider = try core_symcrypt.Provider.init();
    defer provider.deinit();
    const digest = try provider.asProvider().sha256("package consumer");
    try std.testing.expectEqual(@as(usize, 32), digest.len);
}

test "manifest-filtered package exposes explicitly selected TLS binding" {
    if (!@import("consumer_options").enable_httpx_tls) return error.SkipZigTest;
    const binding = @import("azure_sdk_core_symcrypt_tls");
    var owner = try binding.Provider.init(std.testing.allocator, .{});
    const provider = owner.provider();
    var state = try provider.hashCreate(std.testing.allocator, .sha384);
    defer state.deinit();
    try state.update("package TLS consumer");
    var digest: [48]u8 = undefined;
    try state.snapshot(&digest);
    try std.testing.expect(!(try provider.capabilities()).supportsSign(.ed25519));
}
