const std = @import("std");
const core = @import("azure_sdk_core");
const http = @import("azure_sdk_core_http_conformance");
const crypto = @import("azure_sdk_core_crypto_conformance");

test "manifest-filtered package exports usable conformance modules" {
    try http.runRawTransportContracts(
        std.testing.allocator,
        std.testing.io,
        http.mockBackendFactory(),
    );
    try crypto.runCryptoContracts(
        std.testing.allocator,
        std.testing.io,
        crypto.standardProviderFactory(),
    );
    try std.testing.expectEqualStrings("0.3.0", core.version);
}
