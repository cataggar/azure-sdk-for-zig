//! Optional HTTPX implementation of Azure Core's borrowed transport contract.
pub const core = @import("azure_sdk_core");
/// Canonical module identity, also exported by build.zig for optional providers.
pub const httpx = @import("httpx");
pub const HttpxTransport = @import("transport.zig").HttpxTransport;
pub const Options = @import("transport.zig").Options;
