//! Explicit opt-in probe. No credentials, payload logging, trust-store writes,
//! redirect following, certificate fallback, or verification bypass.
const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
const httpx = adapter.httpx;
const endpoint = "https://management.azure.com/";
const response_limit = 64 * 1024;

const Verification = struct {
    bound: httpx.TrustProvider,
    calls: std.atomic.Value(usize) = .init(0),

    fn verify(context: *anyopaque, request: httpx.VerifyPeerRequest) httpx.TrustError!void {
        const self: *@This() = @ptrCast(@alignCast(context));
        if (request.role != .server) return error.TlsInvalidTrustConfiguration;
        const identity = request.expected_identity orelse return error.TlsInvalidTrustConfiguration;
        switch (identity) {
            .dns_name => |name| {
                if (!std.ascii.eqlIgnoreCase(name, "management.azure.com"))
                    return error.TlsInvalidTrustConfiguration;
            },
            else => return error.TlsInvalidTrustConfiguration,
        }
        try self.bound.verifyPeer(request);
        _ = self.calls.fetchAdd(1, .monotonic);
    }
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.gpa);
    defer init.gpa.free(args);
    if (args.len != 2) return error.ExpectedConfiguredDnsServerIp;
    _ = try httpx.Address.parseIp(args[1], 53);
    std.debug.print("endpoint={s} method=GET http=HTTP/1.1-only provider=HTTPX.StandardCryptoProvider trust=canonical-system verification=required response_limit={d} request_ms=10000\n", .{
        endpoint, response_limit,
    });
    qualify(init, args[1]) catch |err| {
        std.debug.print("public_https_result=blocked error={s}\n", .{@errorName(err)});
        return err;
    };
}

fn qualify(init: std.process.Init, dns_server: []const u8) !void {
    const allocator = init.gpa;
    const io = init.io;
    var standard = httpx.StandardCryptoProvider.init(io, allocator);
    var roots = httpx.tls.TrustContext.init(allocator, io, .{ .source = .system }) catch |err| {
        std.debug.print("blocked_phase=system_root_discovery\n", .{});
        return err;
    };
    defer roots.deinit();
    std.debug.print("root_anchors={d} skipped_anchors={d} max_path_depth=8 max_peer_certificates=16 max_chain_der=1048576\n", .{
        roots.anchorCount(), roots.skipped_system_anchors,
    });
    var certificate_crypto = httpx.CryptoCertificateVerifier.init(standard.provider());
    var binding = try roots.bind(&certificate_crypto, .{ .allow_sha1_identifiers = true });
    var verification: Verification = .{ .bound = binding.provider() };
    var resolver = httpx.DNSResolver.init(allocator, .{
        .dns_servers = &.{.{ .ip = dns_server }},
        .udp_timeout_ms = 2000,
        .tcp_timeout_ms = 2000,
    });
    defer resolver.deinit();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{
            .tls_crypto_provider = standard.provider(),
            .tls_certificate_crypto = &certificate_crypto,
            .server_authentication = .{ .verify = .{ .provider = .{
                .context = &verification,
                .vtable = &.{ .verify_peer = Verification.verify },
            } } },
            .tls_trust_limits = .{},
            .dns_resolver = &resolver,
            .keep_alive = false,
            .pool_max_connections = 1,
            .pool_max_per_host = 1,
            .max_response_size = response_limit,
            .timeouts = .{
                .connect_ms = 5000,
                .read_ms = 5000,
                .write_ms = 5000,
                .request_ms = 10000,
            },
        },
        .operation = .{
            .version = .HTTP_1_1,
            .require_interruptible_dns = true,
            .response_limit = .{ .bytes = response_limit },
        },
    });
    defer transport.deinit();
    var request = adapter.core.http.Request.init(allocator, .GET, endpoint);
    defer request.deinit();
    request.redirect_policy = .not_allowed;
    const operation = transport.asTransport().open(&request, .{}) catch |err| {
        std.debug.print("blocked_phase=verified_open transport_started={} live={d} leased={d}\n", .{
            request.transport_started, transport.live_operations, transport.poolStats().active,
        });
        return err;
    };
    const status = operation.status_code;
    {
        defer operation.deinit();
        try operation.finish();
    }
    if (transport.live_operations != 0 or transport.poolStats().total != 0)
        return error.IncompleteTransportCleanup;
    if (verification.calls.load(.acquire) != 1) return error.ExpectedOneVerifiedHandshake;
    std.debug.print("public_https_result=verified status={d} transport_started={} live={d} leased={d} verified_handshakes=1 identity=management.azure.com payload_logged=false\n", .{
        status, request.transport_started, transport.live_operations, transport.poolStats().active,
    });
}
