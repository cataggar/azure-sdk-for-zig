const std = @import("std");
const core_symcrypt = @import("azure_sdk_core_symcrypt");

pub fn main() !void {
    var provider = try core_symcrypt.Provider.init();
    defer provider.deinit();

    const digest = try provider.asProvider().sha256("Azure SDK for Zig");
    std.debug.print(
        "SymCrypt {d}.{d}.{d} ({s}) SHA-256: {x}\n",
        .{
            core_symcrypt.symcrypt_version.api,
            core_symcrypt.symcrypt_version.minor,
            core_symcrypt.symcrypt_version.patch,
            @tagName(core_symcrypt.linkage),
            digest,
        },
    );
}
