const std = @import("std");
const core = @import("azure_sdk_core");

var crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);

pub fn init(transport: core.http.HttpTransport) core.http.HttpRuntime {
    return .init(transport, crypto_provider.asProvider());
}

pub fn crypto() core.crypto.CryptoProvider {
    return crypto_provider.asProvider();
}
