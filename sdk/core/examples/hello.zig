//! Main-owned Core SDK example.

const std = @import("std");
const core = @import("azure_sdk_core");

pub fn main() void {
    std.debug.print("Azure SDK for Zig {s}\n", .{core.version});

    // Quick demo: generate a UUID and format a timestamp.
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const id = core.uuid.Uuid.init(prng.random());
    std.debug.print("Request ID: {s}\n", .{id.toString()});

    const now = core.datetime.DateTime{
        .year = 2026,
        .month = 4,
        .day = 1,
        .hour = 14,
        .minute = 0,
        .second = 0,
    };
    var ts_buf: [32]u8 = undefined;
    const ts = now.toRfc3339(&ts_buf) catch "error";
    std.debug.print("Timestamp:  {s}\n", .{ts});

    // Demonstrate pipeline architecture.
    std.debug.print("\nHTTP Pipeline policies:\n", .{});
    const policies = [_][]const u8{
        "  1. RequestIdPolicy    (x-ms-client-request-id UUID)",
        "  2. TelemetryPolicy    (User-Agent header)",
        "  3. LoggingPolicy      (request/response logging)",
        "  4. RetryPolicy        (exponential backoff + jitter, 429/5xx)",
        "  5. BearerTokenAuth    (cached OAuth2 token)",
        "  6. DecompressionPolicy(Accept-Encoding: gzip, deflate)",
        "  7. Transport           (std.http.Client -> Azure)",
    };
    for (policies) |p| std.debug.print("{s}\n", .{p});

    std.debug.print("\nUsage: Set AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET\n", .{});
    std.debug.print("       then use DefaultAzureCredential with any service client.\n", .{});
}
