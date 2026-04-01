///! Azure SDK Core — foundation module.
///!
///! Provides the HTTP pipeline, transport, policies, credential abstractions,
///! and common utilities that all Azure service SDKs build on.
///!
///! Backed entirely by the Zig standard library:
///!   HTTP  → std.http.Client
///!   TLS   → std.crypto.tls
///!   JSON  → std.json
///!   XML   → std.xml (Zig 0.14+)
///!   Crypto → std.crypto

// Re-export sub-modules for `@import("azure_core").http`, etc.
pub const http = @import("http/transport.zig");
pub const credentials = @import("credentials/token.zig");
pub const context = @import("context.zig");
pub const url = @import("url.zig");
pub const uuid = @import("uuid.zig");
pub const datetime = @import("datetime.zig");

pub const version: []const u8 = "0.1.0";
pub const user_agent_prefix: []const u8 = "azsdk-zig-core/" ++ version;

test {
    // Pull in tests from sub-modules.
    @import("std").testing.refAllDecls(@This());
}
