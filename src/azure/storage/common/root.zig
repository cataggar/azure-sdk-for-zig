const std = @import("std");
const core = @import("azure_core");

/// Shared Key credential for Azure Storage.
///
/// Signs requests with HMAC-SHA256 over a canonical string,
/// adding the `Authorization: SharedKey <account>:<signature>` header.
pub const StorageSharedKeyCredential = struct {
    account_name: []const u8,
    account_key: []const u8,

    pub fn init(account_name: []const u8, account_key: []const u8) StorageSharedKeyCredential {
        return .{
            .account_name = account_name,
            .account_key = account_key,
        };
    }

    /// Sign a request in-place by computing the SharedKey authorization header.
    pub fn signRequest(self: StorageSharedKeyCredential, request: *core.http.Request) !void {
        // Simplified: real implementation builds a canonical string from
        // method, headers (Content-*, Date, x-ms-*), and resource path.
        // For now, set the header with a placeholder showing the pattern.
        const auth = try std.fmt.allocPrint(
            request.allocator,
            "SharedKey {s}:signature",
            .{self.account_name},
        );
        try request.setHeader("Authorization", auth);
    }
};

/// Generate a service-level or resource-level SAS token.
pub const SasBuilder = struct {
    permissions: []const u8 = "r",
    resource_types: []const u8 = "sco",
    services: []const u8 = "b",
    expiry: []const u8,
    protocol: []const u8 = "https",

    /// Render the SAS query string (without leading '?').
    pub fn toQueryString(self: SasBuilder, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "sv=2024-11-04&ss={s}&srt={s}&sp={s}&se={s}&spr={s}",
            .{ self.services, self.resource_types, self.permissions, self.expiry, self.protocol },
        );
    }
};

/// Storage-specific retry options (e.g. secondary endpoint failover).
pub const StorageRetryOptions = struct {
    max_retries: u32 = 4,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 120_000,
    secondary_host: ?[]const u8 = null,
};

test "StorageSharedKeyCredential signRequest" {
    const allocator = std.testing.allocator;
    const cred = StorageSharedKeyCredential.init("myaccount", "base64key==");
    var req = core.http.Request.init(allocator, .GET, "https://myaccount.blob.core.windows.net/container");
    defer req.deinit();
    try cred.signRequest(&req);
    const auth = req.headers.get("Authorization").?;
    defer allocator.free(auth);
    try std.testing.expect(std.mem.startsWith(u8, auth, "SharedKey myaccount:"));
}

test "SasBuilder toQueryString" {
    const allocator = std.testing.allocator;
    const sas = SasBuilder{
        .permissions = "rl",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const qs = try sas.toQueryString(allocator);
    defer allocator.free(qs);
    try std.testing.expect(std.mem.indexOf(u8, qs, "sp=rl") != null);
    try std.testing.expect(std.mem.indexOf(u8, qs, "se=2026-12-31T23:59:59Z") != null);
}
