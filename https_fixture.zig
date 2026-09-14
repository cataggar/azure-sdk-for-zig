//! Adapter-local TLS peer for the published Core factory contract. HTTP parsing
//! uses std.http.Server; response scripts and captured-request types are Core's.
const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
const httpx = adapter.httpx;
const IoContext = httpx.io_context.IoContext;
const Deadline = httpx.io_context.Deadline;
const data = @import("tls_fixture_data");
pub const conformance = @import("azure_sdk_core_http_conformance");
const Binding = @typeInfo(@typeInfo(@TypeOf(httpx.tls.TrustContext.bind)).@"fn".return_type.?).error_union.payload;
const Version = std.crypto.tls.ProtocolVersion;
const valid_host = "api.example.test";
const wrong_host = "wrong.example.test";
const io_timeout_ms = 2000;

pub const Options = struct {
    version: Version = .tls_1_3,
    wrong_hostname: bool = false,
    untrusted_root: bool = false,
    path_depth: usize = 8,
    parent_context: ?*const IoContext = null,
};

pub const Owner = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    standard: httpx.StandardCryptoProvider,
    table: httpx.CryptoProviderVTable = undefined,
    certificate_crypto: httpx.CryptoCertificateVerifier = undefined,
    roots: httpx.tls.TrustContext,
    binding: Binding = undefined,
    server_config: httpx.tls.ServerTLSConfig = undefined,
    dns: Dns = undefined,
    dns_servers: [1]httpx.dns.DnsServer = undefined,
    resolver: httpx.DNSResolver = undefined,
    live_backends: usize = 0,
    handshakes: usize = 0,
    requests: usize = 0,
    verified: std.atomic.Value(usize) = .init(0),
    rejected: std.atomic.Value(usize) = .init(0),

    pub fn create(allocator: std.mem.Allocator, io: std.Io, options: Options) !*Owner {
        const self = try allocator.create(Owner);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .io = io,
            .options = options,
            .standard = .init(io, allocator),
            .roots = try httpx.tls.TrustContext.init(allocator, io, .{
                .source = .{ .custom_only = .{ .der_certificates = &.{if (options.untrusted_root) data.other_root else data.root} } },
            }),
        };
        errdefer self.roots.deinit();
        self.table = self.standard.provider().vtable.*;
        self.table.capabilities = capabilities;
        self.certificate_crypto = .init(self.provider());
        self.binding = try self.roots.bind(&self.certificate_crypto, .{ .allow_sha1_identifiers = true });
        self.server_config = try httpx.tls.ServerTLSConfig.init(allocator, io, &.{ data.leaf, data.intermediate }, .{
            .algorithm = .ecdsa_p256,
            .encoding = .raw_secret,
            .bytes = data.leaf_key,
        }, null);
        errdefer self.server_config.deinit();
        self.dns = try Dns.init();
        errdefer self.dns.socket.close();
        self.dns_servers = .{.{ .ip = "127.0.0.1", .port = (try self.dns.socket.getLocalAddress()).getPort() }};
        self.resolver = .init(allocator, .{
            .dns_servers = &self.dns_servers,
            .address_family = .ipv4_only,
            .cache_enabled = false,
            .dedup_enabled = false,
            .udp_timeout_ms = 1000,
            .tcp_timeout_ms = 1000,
        });
        errdefer self.resolver.deinit();
        self.dns.thread = try std.Thread.spawn(.{}, Dns.run, .{&self.dns});
        return self;
    }

    pub fn deinit(self: *Owner) void {
        std.debug.assert(self.live_backends == 0);
        self.dns.deinit();
        self.resolver.deinit();
        self.server_config.deinit();
        self.roots.deinit();
        self.allocator.destroy(self);
    }

    pub fn factory(self: *Owner) conformance.BackendFactory {
        return .{
            .name = "azure_sdk_core_httpx trusted HTTPS",
            .context = self,
            .capabilities = .{
                .response_framing_validation = true,
                .response_body_limit = true,
                .decompression = true,
                .cancellation = .cooperative_upload,
                .automatic_request_headers = true,
                .bounded_memory_logical_large_upload = true,
                .bounded_memory_logical_large_download = true,
                .scripted_attempts = true,
                .https_redirects = true,
                .allocation_failure_cleanup = true,
                // H2/SOCKS5 interruption evidence does not qualify TLS stalls.
            },
            .createFn = Backend.create,
            .allocationFixtureFn = allocation,
        };
    }

    fn provider(self: *Owner) httpx.CryptoProvider {
        var result = self.standard.provider();
        result.vtable = &self.table;
        return result;
    }

    fn capabilities(context: *anyopaque) httpx.CryptoProviderCapabilities {
        const standard: *httpx.StandardCryptoProvider = @ptrCast(@alignCast(context));
        const self: *Owner = @fieldParentPtr("standard", standard);
        var result = standard.provider().vtable.capabilities(context);
        if (self.options.version == .tls_1_2) result.hkdf_hashes = 0;
        return result;
    }

    fn verify(context: *anyopaque, request: httpx.VerifyPeerRequest) httpx.TrustError!void {
        const self: *Owner = @ptrCast(@alignCast(context));
        if (request.role != .server or request.expected_identity == null or request.expected_identity.? != .dns_name)
            return error.TlsInvalidTrustConfiguration;
        self.binding.provider().verifyPeer(request) catch |err| {
            _ = self.rejected.fetchAdd(1, .monotonic);
            return err;
        };
        _ = self.verified.fetchAdd(1, .monotonic);
    }

    fn allocation(context: ?*anyopaque, allocator: std.mem.Allocator, fixture_allocator: std.mem.Allocator, io: std.Io, scenario: conformance.AllocationScenario) !void {
        const self: *Owner = @ptrCast(@alignCast(context.?));
        try conformance.runBackendAllocationScenario(allocator, fixture_allocator, io, self.factory(), scenario);
    }
};

const Dns = struct {
    socket: httpx.UdpSocket,
    thread: ?std.Thread = null,
    stopping: std.atomic.Value(bool) = .init(false),
    failure_code: std.atomic.Value(u16) = .init(0),

    fn init() !Dns {
        var socket = try httpx.UdpSocket.createV4();
        errdefer socket.close();
        try socket.bind(try httpx.Address.parseIp("127.0.0.1", 0));
        try socket.setRecvTimeout(50);
        try socket.setSendTimeout(1000);
        return .{ .socket = socket };
    }

    fn deinit(self: *Dns) void {
        self.stopping.store(true, .release);
        if (self.thread) |thread| thread.join();
        self.socket.close();
    }

    fn run(self: *Dns) void {
        self.serve() catch |err| {
            self.failure_code.store(@intFromError(err), .release);
        };
    }

    fn serve(self: *Dns) !void {
        var bytes: [512]u8 = undefined;
        while (!self.stopping.load(.acquire)) {
            const received = self.socket.recvFrom(&bytes) catch |err| switch (err) {
                error.WouldBlock, error.ConnectionTimedOut => continue,
                else => return err,
            };
            if (received.n < 17 or std.mem.readInt(u16, bytes[4..6], .big) != 1)
                return error.FixtureDnsQuestion;
            var end: usize = 12;
            while (end < received.n and bytes[end] != 0) {
                if (bytes[end] > 63 or bytes[end] > received.n - end - 1) return error.FixtureDnsQuestion;
                end += 1 + bytes[end];
            }
            const question_end = end + 5;
            if (question_end > received.n) return error.FixtureDnsQuestion;
            const extra = std.mem.readInt(u16, bytes[10..12], .big);
            if (extra == 1) {
                if (!std.mem.eql(u8, bytes[question_end..received.n], "\x00\x00\x29\x10\x00\x00\x00\x00\x00\x00\x00"))
                    return error.FixtureDnsQuestion;
            } else if (extra != 0 or question_end != received.n) return error.FixtureDnsQuestion;
            const name = bytes[12 .. end + 1];
            const known = std.mem.eql(u8, name, "\x03api\x07example\x04test\x00") or
                std.mem.eql(u8, name, "\x05wrong\x07example\x04test\x00");
            const address_query = std.mem.readInt(u16, bytes[end + 1 ..][0..2], .big) == 1 and
                std.mem.readInt(u16, bytes[end + 3 ..][0..2], .big) == 1;
            std.mem.writeInt(u16, bytes[2..4], if (known and address_query) 0x8180 else 0x8183, .big);
            std.mem.writeInt(u16, bytes[6..8], @intFromBool(known and address_query), .big);
            @memset(bytes[8..12], 0);
            var length = question_end;
            if (known and address_query) {
                const answer = "\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x7f\x00\x00\x01";
                if (length + answer.len > bytes.len) return error.FixtureDnsQuestion;
                @memcpy(bytes[length..][0..answer.len], answer);
                length += answer.len;
            }
            _ = try self.socket.sendTo(received.addr, bytes[0..length]);
        }
    }
};

const TlsIo = struct {
    connection: *httpx.tls.Connection,
    context: *const IoContext,
    reader: std.Io.Reader,
    writer: std.Io.Writer,
    failure: ?anyerror = null,

    fn init(connection: *httpx.tls.Connection, context: *const IoContext, read_buffer: []u8, write_buffer: []u8) TlsIo {
        return .{
            .connection = connection,
            .context = context,
            .reader = .{ .vtable = &.{ .stream = stream }, .buffer = read_buffer, .seek = 0, .end = 0 },
            .writer = .{ .vtable = &.{ .drain = drain }, .buffer = write_buffer },
        };
    }

    fn operationContext(self: *const TlsIo) IoContext {
        return .init(.{ .parent = self.context, .phase_deadline = Deadline.afterMs(io_timeout_ms) });
    }

    fn stream(reader: *std.Io.Reader, writer: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const self: *TlsIo = @fieldParentPtr("reader", reader);
        const output = limit.slice(try writer.writableSliceGreedy(1));
        const context = self.operationContext();
        const count = self.connection.readWithContext(output, &context) catch |err| {
            if (self.failure == null) self.failure = err;
            return error.ReadFailed;
        };
        if (count == 0) return error.EndOfStream;
        writer.advance(count);
        return count;
    }

    fn drain(writer: *std.Io.Writer, bytes: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *TlsIo = @fieldParentPtr("writer", writer);
        // One budget spans buffered bytes, all vector parts and every splat.
        const context = self.operationContext();
        var count: usize = writer.buffered().len;
        self.writeAll(writer.buffered(), &context) catch return error.WriteFailed;
        for (bytes[0 .. bytes.len - 1]) |part| {
            self.writeAll(part, &context) catch return error.WriteFailed;
            count += part.len;
        }
        for (0..splat) |_| {
            self.writeAll(bytes[bytes.len - 1], &context) catch return error.WriteFailed;
            count += bytes[bytes.len - 1].len;
        }
        return writer.consume(count);
    }

    fn writeAll(self: *TlsIo, bytes: []const u8, context: *const IoContext) !void {
        self.connection.writeAllWithContext(bytes, context) catch |err| {
            if (self.failure == null) self.failure = err;
            return err;
        };
    }
};

pub const Backend = struct {
    owner: *Owner,
    allocator: std.mem.Allocator,
    fixture_allocator: std.mem.Allocator,
    options: conformance.BackendOptions,
    listener: httpx.TcpListener,
    transport: adapter.HttpxTransport = undefined,
    url: []u8 = undefined,
    thread: ?std.Thread = null,
    shutdown_token: httpx.CancellationToken = .{},
    io_context: IoContext = undefined,
    done: std.atomic.Value(bool) = .init(false),
    mutex: std.Io.Mutex = .init,
    active: ?*httpx.Socket = null,
    failure: ?anyerror = null,
    handshakes: usize = 0,
    requests: std.ArrayList(conformance.scripted.CapturedRequest) = .empty,

    fn create(context: ?*anyopaque, allocator: std.mem.Allocator, io: std.Io, options: conformance.BackendOptions) !conformance.BackendInstance {
        const owner: *Owner = @ptrCast(@alignCast(context.?));
        const self = try allocator.create(Backend);
        errdefer allocator.destroy(self);
        self.* = .{
            .owner = owner,
            .allocator = allocator,
            .fixture_allocator = options.fixture_allocator orelse owner.allocator,
            .options = options,
            .listener = try httpx.TcpListener.init(try httpx.Address.parseIp("127.0.0.1", 0)),
        };
        errdefer self.listener.deinit();
        self.io_context = .init(.{
            .parent = owner.options.parent_context,
            .external_cancel = &self.shutdown_token,
        });
        self.url = try std.fmt.allocPrint(allocator, "https://{s}:{d}/conformance", .{
            if (owner.options.wrong_hostname) wrong_host else valid_host,
            (try self.listener.getLocalAddress()).getPort(),
        });
        errdefer allocator.free(self.url);
        self.transport = try adapter.HttpxTransport.init(allocator, io, .{
            .client = .{
                .tls_crypto_provider = owner.provider(),
                .tls_certificate_crypto = &owner.certificate_crypto,
                .server_authentication = .{ .verify = .{ .provider = .{
                    .context = owner,
                    .vtable = &.{ .verify_peer = Owner.verify },
                } } },
                .tls_trust_limits = .{ .max_path_depth = owner.options.path_depth },
                .dns_resolver = &owner.resolver,
                .max_request_size = 0,
                .max_response_size = 0,
                .timeouts = .{ .request_ms = 10000, .connect_ms = 2000, .read_ms = 2000, .write_ms = 2000 },
            },
            .operation = .{ .version = .HTTP_1_1, .require_interruptible_dns = true },
            .max_buffered_response = if (options.max_response_body) |limit| .limited(limit) else .unlimited,
        });
        errdefer self.transport.deinit();
        self.thread = try std.Thread.spawn(.{}, run, .{self});
        owner.live_backends += 1;
        return .{
            .transport = self.transport.asTransport(),
            .url = self.url,
            .context = self,
            .finishFn = finish,
            .observeFn = observe,
            .attemptFn = attempt,
            .assertQuiescentFn = quiescent,
            .deinitFn = destroy,
        };
    }

    fn stop(self: *Backend) void {
        self.shutdown_token.cancel();
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    fn finish(context: *anyopaque) !void {
        const self: *Backend = @ptrCast(@alignCast(context));
        const completion = self.waitForExpectedPeer();
        self.stop();
        try completion;
        const dns_error = self.owner.dns.failure_code.load(.acquire);
        if (dns_error != 0) return @errorFromInt(dns_error);
        if (self.failure) |err| {
            if (!self.options.allow_peer_failure) return err;
        }
    }

    fn waitForExpectedPeer(self: *Backend) !void {
        if (!self.options.expect_request or self.options.responses.len != 0) return;
        // Core's one-request factory joins naturally before observing captures.
        // Cancelling first can discard an already queued early-abort request.
        const bound = IoContext.init(.{ .phase_deadline = Deadline.afterMs(io_timeout_ms) });
        while (!self.done.load(.acquire)) try bound.waitForMs(1);
    }

    fn quiescent(context: *anyopaque) !void {
        const self: *Backend = @ptrCast(@alignCast(context));
        try std.testing.expectEqual(@as(usize, 0), self.transport.live_operations);
        try std.testing.expectEqual(@as(usize, 0), self.transport.poolStats().active);
        try std.testing.expectEqual(@as(usize, 0), self.transport.poolStats().total);
    }

    fn destroy(context: *anyopaque) void {
        const self: *Backend = @ptrCast(@alignCast(context));
        self.stop();
        self.transport.deinit();
        self.listener.deinit();
        self.owner.handshakes += self.handshakes;
        self.owner.requests += self.requests.items.len;
        self.owner.live_backends -= 1;
        for (self.requests.items) |*request| {
            self.fixture_allocator.free(request.request_line);
            for (request.header_lines.items) |line| self.fixture_allocator.free(line);
            request.header_lines.deinit(self.fixture_allocator);
        }
        self.requests.deinit(self.fixture_allocator);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    fn observation(request: *const conformance.scripted.CapturedRequest) conformance.Observation {
        var result: conformance.Observation = .{
            .request_count = 1,
            .request_line = request.request_line,
            .body = request.body_prefix[0..request.body_prefix_len],
            .body_length = request.body_length,
            .body_hash = request.body_hash,
            .authorization = request.headerValue("Authorization"),
            .cookie = request.headerValue("Cookie"),
            .proxy_authorization = request.headerValue("Proxy-Authorization"),
            .host = request.headerValue("Host"),
            .policy_marker = request.headerValue("X-Conformance-Policy"),
            .content_length = request.headerValue("Content-Length"),
        };
        for (request.header_lines.items) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const name = line[0..colon];
            if (std.ascii.eqlIgnoreCase(name, "Host")) result.host_count += 1;
            if (std.ascii.eqlIgnoreCase(name, "Connection")) result.connection_count += 1;
            if (std.ascii.eqlIgnoreCase(name, "User-Agent")) result.user_agent_count += 1;
            if (std.ascii.eqlIgnoreCase(name, "Accept-Encoding")) result.accept_encoding_count += 1;
            if (std.ascii.eqlIgnoreCase(name, "Accept")) result.accept_count += 1;
        }
        return result;
    }

    fn observe(context: *anyopaque) conformance.Observation {
        const self: *Backend = @ptrCast(@alignCast(context));
        if (self.requests.items.len == 0) return .{};
        var result = observation(&self.requests.items[0]);
        result.request_count = self.requests.items.len;
        return result;
    }

    fn attempt(context: *anyopaque, index: usize) ?conformance.Observation {
        const self: *Backend = @ptrCast(@alignCast(context));
        if (index >= self.requests.items.len) return null;
        return observation(&self.requests.items[index]);
    }

    fn run(self: *Backend) void {
        defer self.done.store(true, .release);
        for (0..64) |_| {
            self.serve() catch |err| {
                if (self.shutdown_token.isCancelled()) return;
                if (self.failure == null) self.failure = err;
                if (!self.options.allow_peer_failure or self.io_context.isCancelled() or self.io_context.expiredDeadline() != null)
                    return;
            };
            if (self.options.responses.len == 0) return;
        }
        self.failure = error.FixtureConnectionLimit;
    }

    fn serve(self: *Backend) !void {
        while (true) {
            try self.io_context.check();
            if (self.listener.socket.waitReadable(20)) break;
        }
        try self.io_context.check();
        var accepted = try self.listener.accept();
        defer accepted.socket.close();
        self.mutex.lockUncancelable(self.owner.io);
        if (self.shutdown_token.isCancelled()) {
            self.mutex.unlock(self.owner.io);
            return;
        }
        self.active = &accepted.socket;
        self.mutex.unlock(self.owner.io);
        defer {
            self.mutex.lockUncancelable(self.owner.io);
            self.active = null;
            self.mutex.unlock(self.owner.io);
        }
        try accepted.socket.setRecvTimeout(io_timeout_ms);
        try accepted.socket.setSendTimeout(io_timeout_ms);
        var connection = try httpx.tls.acceptServerWithIo(self.fixture_allocator, &accepted.socket, &.{"http/1.1"}, self.owner.server_config, .{
            .context = &self.io_context,
            .read_timeout_ms = io_timeout_ms,
            .write_timeout_ms = io_timeout_ms,
        });
        defer connection.deinit();
        self.handshakes += 1;
        try std.testing.expectEqual(self.owner.options.version, connection.tlsVersion());
        try std.testing.expectEqualStrings("http/1.1", connection.negotiatedAlpn().?);
        try std.testing.expectEqualStrings(if (self.owner.options.wrong_hostname) wrong_host else valid_host, connection.sniHostname().?);
        var read_buffer: [16384]u8 = undefined;
        var write_buffer: [16384]u8 = undefined;
        var tls_io = TlsIo.init(&connection, &self.io_context, &read_buffer, &write_buffer);
        errdefer if (!self.shutdown_token.isCancelled() and self.failure == null) {
            self.failure = tls_io.failure;
        };
        var server = std.http.Server.init(&tls_io.reader, &tls_io.writer);
        var incoming = try server.receiveHead();
        var captured: conformance.scripted.CapturedRequest = .{
            .request_line = try self.fixture_allocator.dupe(u8, std.mem.sliceTo(incoming.head_buffer, '\r')),
            .header_lines = .empty,
            .body_prefix = undefined,
            .body_prefix_len = 0,
            .body_length = 0,
            .body_hash = 0,
        };
        var captured_owned = true;
        defer if (captured_owned) {
            self.fixture_allocator.free(captured.request_line);
            for (captured.header_lines.items) |line| self.fixture_allocator.free(line);
            captured.header_lines.deinit(self.fixture_allocator);
        };
        var headers = incoming.iterateHeaders();
        while (headers.next()) |header| {
            const line = try std.fmt.allocPrint(self.fixture_allocator, "{s}: {s}", .{ header.name, header.value });
            captured.header_lines.append(self.fixture_allocator, line) catch |err| {
                self.fixture_allocator.free(line);
                return err;
            };
        }
        const index = self.requests.items.len;
        try self.requests.append(self.fixture_allocator, captured);
        captured_owned = false;
        const capture = &self.requests.items[index];
        var body_buffer: [16384]u8 = undefined;
        const expect_continue = incoming.head.expect != null;
        try incoming.writeExpectContinue();
        if (expect_continue) try tls_io.writer.flush();
        var empty_body = std.Io.Reader.fixed(&.{});
        // Request framing, including an explicit GET body, is independent of
        // std.http.Method.requestHasBody's convenience classification.
        const reader: *std.Io.Reader = if (incoming.head.content_length == null and incoming.head.transfer_encoding == .none)
            &empty_body
        else
            server.reader.bodyReader(&body_buffer, incoming.head.transfer_encoding, incoming.head.content_length);
        var hasher = std.hash.Wyhash.init(0);
        defer capture.body_hash = hasher.final();
        var chunk: [16384]u8 = undefined;
        while (true) {
            const count = try reader.readSliceShort(&chunk);
            if (count == 0) break;
            const retained = @min(count, capture.body_prefix.len - capture.body_prefix_len);
            @memcpy(capture.body_prefix[capture.body_prefix_len..][0..retained], chunk[0..retained]);
            capture.body_prefix_len += retained;
            capture.body_length += count;
            hasher.update(chunk[0..count]);
        }
        const response = if (self.options.responses.len == 0)
            self.options.response
        else if (index < self.options.responses.len)
            self.options.responses[index]
        else
            conformance.scripted.Response{ .status_code = 418, .reason = "Unexpected attempt" };
        try emit(&tls_io.writer, response);
        try tls_io.writer.flush();
        connection.closeNotify();
    }
};

fn emit(writer: *std.Io.Writer, response: conformance.scripted.Response) !void {
    try writer.print("HTTP/1.1 {d} {s}\r\n", .{ response.status_code, response.reason });
    for (response.headers) |header| try writer.print("{s}: {s}\r\n", .{ header.name, header.value });
    const body_length = if (response.generated_body) |body| body.length else response.body.len;
    if (response.chunked)
        try writer.writeAll("Transfer-Encoding: chunked\r\n")
    else
        try writer.print("Content-Length: {d}\r\n", .{response.advertised_content_length orelse body_length});
    try writer.writeAll("Connection: close\r\n\r\n");
    if (!response.omit_body) {
        if (response.generated_body) |body| {
            if (body.chunk_size == 0) return error.InvalidGeneratedChunkSize;
            var bytes: [16384]u8 = undefined;
            @memset(&bytes, body.byte);
            var remaining = body.length;
            while (remaining > 0) {
                const count = @min(remaining, bytes.len, body.chunk_size);
                try emitChunk(writer, bytes[0..count], response.chunked);
                remaining -= count;
            }
        } else try emitChunk(writer, response.body, response.chunked);
    }
    if (response.chunked) try writer.writeAll("0\r\n\r\n");
}

fn emitChunk(writer: *std.Io.Writer, bytes: []const u8, chunked: bool) !void {
    if (bytes.len == 0) return;
    if (chunked) try writer.print("{x}\r\n", .{bytes.len});
    try writer.writeAll(bytes);
    if (chunked) try writer.writeAll("\r\n");
}
