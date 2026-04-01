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
///!   Crypto → std.crypto (HMAC-SHA256, SHA-256, MD5)
///!   Base64 → std.base64

// Re-export sub-modules for `@import("azure_core").http`, etc.
pub const http = @import("http/transport.zig");
pub const pipeline = @import("http/pipeline.zig");
pub const credentials = @import("credentials/token.zig");
pub const context = @import("context.zig");
pub const url = @import("url.zig");
pub const uuid = @import("uuid.zig");
pub const datetime = @import("datetime.zig");
pub const errors = @import("errors.zig");
pub const response = @import("response.zig");
pub const case_insensitive_map = @import("case_insensitive_map.zig");
pub const base64 = @import("base64.zig");

pub const version: []const u8 = "0.1.0";
pub const user_agent_prefix: []const u8 = "azsdk-zig-core/" ++ version;

test {
    // Pull in tests from sub-modules.
    @import("std").testing.refAllDecls(@This());
}
