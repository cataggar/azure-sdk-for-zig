///! Azure SDK Core — foundation module.
///!
///! Provides the HTTP pipeline, transport, policies, credential abstractions,
///! and common utilities that all Azure service SDKs build on.
///!
///! Backed by the Zig standard library + serde.zig:
///!   HTTP   → std.http.Client
///!   TLS    → std.crypto.tls
///!   JSON   → serde.json (typed schemas)
///!   XML    → serde.xml (typed schemas)
///!   Crypto → configured CryptoProvider (HMAC-SHA256, SHA-256, MD5)
///!   Base64 → std.base64

// Re-export sub-modules for `@import("azure_sdk_core").http`, etc.
pub const http = @import("http.zig");
pub const crypto = @import("crypto.zig");
pub const credentials = @import("credentials/token.zig");
pub const identity = @import("identity/root.zig");
pub const context = @import("context.zig");
pub const url = @import("url.zig");
pub const uuid = @import("uuid.zig");
pub const datetime = @import("datetime.zig");
pub const errors = @import("errors.zig");
pub const response = @import("response.zig");
pub const safe_debug = @import("safe_debug.zig");
pub const lro = @import("lro.zig");
pub const pager = @import("pager.zig");
pub const case_insensitive_map = @import("case_insensitive_map.zig");
pub const base64 = @import("base64.zig");
pub const cloud = @import("cloud.zig");
pub const tracing = @import("tracing/root.zig");
pub const perf = @import("perf/root.zig");
pub const dotenv = @import("dotenv.zig");
pub const arm = @import("arm/resource.zig");
pub const open_enum = @import("open_enum.zig");
pub const fixed_enum = @import("fixed_enum.zig");
pub const env_token = @import("credentials/env_token.zig");

pub const version: []const u8 = @import("build_options").version;
pub const user_agent_prefix: []const u8 = "azsdk-zig-core/" ++ version;

test {
    // Pull in tests from sub-modules.
    @import("std").testing.refAllDecls(@This());
}
