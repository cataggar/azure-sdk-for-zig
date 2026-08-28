const std = @import("std");
const crypto = @import("../crypto.zig");
const transport = @import("transport.zig");

/// Explicit HTTP dependencies copied into pipelines and passed to policies
/// and credentials.
///
/// Both descriptors are copied by value and borrow their backend contexts.
/// Those contexts must outlive every pipeline, client, credential call, and
/// open operation that uses this runtime. `StdHttpTransport` remains
/// caller-serialized. Crypto provider contexts must be concurrent-safe or
/// caller-serialized by the application.
pub const HttpRuntime = struct {
    transport: transport.HttpTransport,
    crypto: crypto.CryptoProvider,

    pub fn init(
        http_transport: transport.HttpTransport,
        crypto_provider: crypto.CryptoProvider,
    ) HttpRuntime {
        return .{
            .transport = http_transport,
            .crypto = crypto_provider,
        };
    }
};

test "HttpRuntime copies borrowed descriptors by value" {
    var mock = transport.MockTransport.init(std.testing.allocator, 200, "ok");
    defer mock.deinit();
    var provider = crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = HttpRuntime.init(mock.asTransport(), provider.asProvider());
    const copied = runtime;

    try std.testing.expectEqual(runtime.transport.context, copied.transport.context);
    try std.testing.expectEqual(runtime.transport.vtable, copied.transport.vtable);
    try std.testing.expectEqual(runtime.crypto.context, copied.crypto.context);
    try std.testing.expectEqual(runtime.crypto.vtable, copied.crypto.vtable);
}
