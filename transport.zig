//! Byte transports for the AMQP connection driver.
//!
//! `azure-uamqp-zig` implements AMQP framing and the type system but owns no
//! sockets. This module supplies the missing byte layer: a small
//! function-pointer interface plus three implementations — TLS for `amqps`,
//! plaintext TCP for the Event Hubs emulator, and an in-memory duplex used by
//! tests to script a peer without touching the network.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Default port for AMQP over TLS.
pub const tls_port: u16 = 5671;

/// Default port for AMQP over plaintext TCP, used by the emulator.
pub const tcp_port: u16 = 5672;

pub const TransportError = error{
    ConnectionFailed,
    ConnectionClosed,
    ReadFailed,
    WriteFailed,
    TlsFailed,
    OutOfMemory,
};

/// A bidirectional byte stream.
///
/// `read` blocks until at least one byte is available and reports
/// `error.ConnectionClosed` at end of stream. It returns 0 only for a
/// non-blocking transport with nothing buffered, which callers treat as "try
/// again before the deadline". `write` buffers; nothing is guaranteed to reach
/// the peer until `flush` returns.
pub const Transport = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        read: *const fn (ptr: *anyopaque, buffer: []u8) TransportError!usize,
        write: *const fn (ptr: *anyopaque, bytes: []const u8) TransportError!void,
        flush: *const fn (ptr: *anyopaque) TransportError!void,
        close: *const fn (ptr: *anyopaque) void,
    };

    pub fn read(self: Transport, buffer: []u8) TransportError!usize {
        return self.vtable.read(self.ptr, buffer);
    }

    pub fn write(self: Transport, bytes: []const u8) TransportError!void {
        return self.vtable.write(self.ptr, bytes);
    }

    pub fn flush(self: Transport) TransportError!void {
        return self.vtable.flush(self.ptr);
    }

    pub fn close(self: Transport) void {
        self.vtable.close(self.ptr);
    }

    /// Fill `buffer` completely, failing if the peer closes first.
    pub fn readAll(self: Transport, buffer: []u8) TransportError!void {
        var filled: usize = 0;
        while (filled < buffer.len) {
            const n = try self.read(buffer[filled..]);
            if (n == 0) return error.ConnectionClosed;
            filled += n;
        }
    }

    /// Write and flush in one call.
    pub fn send(self: Transport, bytes: []const u8) TransportError!void {
        try self.write(bytes);
        try self.flush();
    }
};

/// Where the driver dials, and what identity it validates once there.
///
/// Splitting the two lets a caller front a namespace with a local proxy: the
/// connection goes to `host:port` while the certificate and SNI still name the
/// namespace.
pub const Endpoint = struct {
    host: []const u8,
    port: u16 = tls_port,
    tls: bool = true,
    /// Certificate identity, defaulting to `host`.
    server_name: ?[]const u8 = null,

    /// The normal case: dial the namespace directly over TLS.
    pub fn forNamespace(fqdn: []const u8) Endpoint {
        return .{ .host = fqdn, .port = tls_port, .tls = true };
    }

    /// The Event Hubs emulator, which speaks plaintext AMQP.
    pub fn forEmulator(host: []const u8, port: u16) Endpoint {
        return .{ .host = host, .port = port, .tls = false };
    }

    /// Dial somewhere else while keeping this endpoint's certificate identity.
    pub fn viaCustomEndpoint(self: Endpoint, host: []const u8, port: u16) Endpoint {
        return .{
            .host = host,
            .port = port,
            .tls = self.tls,
            .server_name = self.server_name orelse self.host,
        };
    }

    pub fn serverName(self: Endpoint) []const u8 {
        return self.server_name orelse self.host;
    }
};

/// A connected socket, either flavour.
pub const Socket = union(enum) {
    tls: *TlsTransport,
    tcp: *TcpTransport,

    pub fn transport(self: Socket) Transport {
        return switch (self) {
            .tls => |t| t.transport(),
            .tcp => |t| t.transport(),
        };
    }

    pub fn deinit(self: Socket) void {
        switch (self) {
            .tls => |t| t.deinit(),
            .tcp => |t| t.deinit(),
        }
    }
};

/// Dial `endpoint`, running the TLS handshake when the endpoint requires it.
pub fn connect(
    allocator: Allocator,
    io: std.Io,
    endpoint: Endpoint,
    options: TlsOptions,
) TransportError!Socket {
    if (!endpoint.tls) {
        return .{ .tcp = try TcpTransport.connect(allocator, io, endpoint.host, endpoint.port) };
    }
    var tls_options = options;
    if (tls_options.server_name == null) tls_options.server_name = endpoint.serverName();
    return .{ .tls = try TlsTransport.connect(
        allocator,
        io,
        endpoint.host,
        endpoint.port,
        tls_options,
    ) };
}

// ─────────────────────── In-memory transport ───────────────────────

/// A scripted duplex stream.
///
/// Tests preload the bytes the peer will return with `pushPeerBytes` and then
/// inspect everything the driver emitted with `written`. Setting `chunk` forces
/// short reads so the frame codec's partial-read path is exercised.
pub const MemoryTransport = struct {
    allocator: Allocator,
    inbound: std.ArrayList(u8) = .empty,
    inbound_pos: usize = 0,
    /// Flushed output. Writes land in `pending` first, exactly as a socket
    /// buffers them, so a missing flush shows up as missing bytes here.
    outbound: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    /// Counts reads attempted while output was still buffered. Against a real
    /// socket that is a deadlock: the peer cannot answer bytes it never got.
    /// Tests assert this stays zero.
    reads_with_pending_writes: usize = 0,
    /// Maximum bytes returned by a single `read`. Zero means unlimited.
    chunk: usize = 0,
    /// When set, an exhausted script reads as 0 bytes instead of end of
    /// stream, which is how a deadline is exercised without a real socket.
    starve: bool = false,
    closed: bool = false,
    /// Set by tests to make the next `write` fail.
    fail_write: bool = false,

    pub fn init(allocator: Allocator) MemoryTransport {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *MemoryTransport) void {
        self.inbound.deinit(self.allocator);
        self.outbound.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    /// Queue bytes for the driver to read.
    pub fn pushPeerBytes(self: *MemoryTransport, bytes: []const u8) Allocator.Error!void {
        try self.inbound.appendSlice(self.allocator, bytes);
    }

    /// Everything the driver has written and flushed.
    pub fn written(self: *const MemoryTransport) []const u8 {
        return self.outbound.items;
    }

    /// Discard the recorded output without disturbing the queued input.
    pub fn clearWritten(self: *MemoryTransport) void {
        self.outbound.clearRetainingCapacity();
    }

    pub fn transport(self: *MemoryTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .read = memRead,
        .write = memWrite,
        .flush = memFlush,
        .close = memClose,
    };

    fn memRead(ptr: *anyopaque, buffer: []u8) TransportError!usize {
        const self: *MemoryTransport = @ptrCast(@alignCast(ptr));
        if (self.pending.items.len != 0) self.reads_with_pending_writes += 1;
        if (self.closed) return error.ConnectionClosed;
        const remaining = self.inbound.items.len - self.inbound_pos;
        if (remaining == 0) return if (self.starve) 0 else error.ConnectionClosed;
        var n = @min(remaining, buffer.len);
        if (self.chunk != 0) n = @min(n, self.chunk);
        @memcpy(buffer[0..n], self.inbound.items[self.inbound_pos..][0..n]);
        self.inbound_pos += n;
        return n;
    }

    fn memWrite(ptr: *anyopaque, bytes: []const u8) TransportError!void {
        const self: *MemoryTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        if (self.fail_write) return error.WriteFailed;
        try self.pending.appendSlice(self.allocator, bytes);
    }

    fn memFlush(ptr: *anyopaque) TransportError!void {
        const self: *MemoryTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        try self.outbound.appendSlice(self.allocator, self.pending.items);
        self.pending.clearRetainingCapacity();
    }

    fn memClose(ptr: *anyopaque) void {
        const self: *MemoryTransport = @ptrCast(@alignCast(ptr));
        self.closed = true;
    }
};

// ─────────────────────── Plaintext TCP transport ───────────────────────

/// Buffer size used for the socket reader and writer.
///
/// TLS requires at least `std.crypto.tls.max_ciphertext_record_len` on the
/// underlying reader, so both transports use it for consistency.
pub const socket_buffer_len = std.crypto.tls.max_ciphertext_record_len;

/// AMQP over plaintext TCP.
///
/// Heap allocated because `std.Io.net.Stream.Reader` and `Writer` expose an
/// `Io.Reader`/`Io.Writer` interface by address; the owning struct must not
/// move once those addresses have been taken.
pub const TcpTransport = struct {
    allocator: Allocator,
    io: std.Io,
    stream: std.Io.net.Stream,
    reader: std.Io.net.Stream.Reader,
    writer: std.Io.net.Stream.Writer,
    read_buffer: []u8,
    write_buffer: []u8,
    closed: bool = false,

    pub fn connect(
        allocator: Allocator,
        io: std.Io,
        host: []const u8,
        port: u16,
    ) TransportError!*TcpTransport {
        const host_name = std.Io.net.HostName.init(host) catch return error.ConnectionFailed;
        const stream = host_name.connect(io, port, .{ .mode = .stream }) catch
            return error.ConnectionFailed;
        errdefer stream.close(io);
        return initFromStream(allocator, io, stream);
    }

    /// Wrap an already-connected stream. Takes ownership of `stream`.
    pub fn initFromStream(
        allocator: Allocator,
        io: std.Io,
        stream: std.Io.net.Stream,
    ) TransportError!*TcpTransport {
        const self = try allocator.create(TcpTransport);
        errdefer allocator.destroy(self);

        const read_buffer = try allocator.alloc(u8, socket_buffer_len);
        errdefer allocator.free(read_buffer);
        const write_buffer = try allocator.alloc(u8, socket_buffer_len);
        errdefer allocator.free(write_buffer);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .stream = stream,
            .reader = undefined,
            .writer = undefined,
            .read_buffer = read_buffer,
            .write_buffer = write_buffer,
        };
        self.reader = stream.reader(io, read_buffer);
        self.writer = stream.writer(io, write_buffer);
        return self;
    }

    pub fn deinit(self: *TcpTransport) void {
        if (!self.closed) self.stream.close(self.io);
        const allocator = self.allocator;
        allocator.free(self.read_buffer);
        allocator.free(self.write_buffer);
        allocator.destroy(self);
    }

    pub fn transport(self: *TcpTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .read = tcpRead,
        .write = tcpWrite,
        .flush = tcpFlush,
        .close = tcpClose,
    };

    fn tcpRead(ptr: *anyopaque, buffer: []u8) TransportError!usize {
        const self: *TcpTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        const n = self.reader.interface.readSliceShort(buffer) catch return error.ReadFailed;
        return if (n == 0) error.ConnectionClosed else n;
    }

    fn tcpWrite(ptr: *anyopaque, bytes: []const u8) TransportError!void {
        const self: *TcpTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        self.writer.interface.writeAll(bytes) catch return error.WriteFailed;
    }

    fn tcpFlush(ptr: *anyopaque) TransportError!void {
        const self: *TcpTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        self.writer.interface.flush() catch return error.WriteFailed;
    }

    fn tcpClose(ptr: *anyopaque) void {
        const self: *TcpTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return;
        self.closed = true;
        self.stream.close(self.io);
    }
};

// ─────────────────────── TLS transport ───────────────────────

pub const TlsOptions = struct {
    /// Certificate bundle to validate the server against. When null the
    /// transport rescans the system trust store, which is slow enough that a
    /// long-lived client should hoist it out and share one bundle.
    bundle: ?*std.crypto.Certificate.Bundle = null,
    /// Name presented in SNI and matched against the certificate. Defaults to
    /// the connect host, which differs when fronting a namespace with a proxy.
    server_name: ?[]const u8 = null,
};

/// AMQP over TLS, the transport Event Hubs requires.
pub const TlsTransport = struct {
    allocator: Allocator,
    io: std.Io,
    stream: std.Io.net.Stream,
    reader: std.Io.net.Stream.Reader,
    writer: std.Io.net.Stream.Writer,
    client: std.crypto.tls.Client,
    owned_bundle: ?std.crypto.Certificate.Bundle,
    bundle_lock: std.Io.RwLock,
    buffers: []u8,
    closed: bool = false,

    /// The socket reader, socket writer, TLS plaintext reader, and TLS record
    /// writer buffers are carved out of one allocation in this order.
    const total_buffer_len = socket_buffer_len * 4;

    pub fn connect(
        allocator: Allocator,
        io: std.Io,
        host: []const u8,
        port: u16,
        options: TlsOptions,
    ) TransportError!*TlsTransport {
        const host_name = std.Io.net.HostName.init(host) catch return error.ConnectionFailed;
        const stream = host_name.connect(io, port, .{ .mode = .stream }) catch
            return error.ConnectionFailed;
        errdefer stream.close(io);
        return initFromStream(allocator, io, stream, options.server_name orelse host, options);
    }

    /// Run the TLS handshake over an already-connected stream. Takes ownership
    /// of `stream`.
    pub fn initFromStream(
        allocator: Allocator,
        io: std.Io,
        stream: std.Io.net.Stream,
        server_name: []const u8,
        options: TlsOptions,
    ) TransportError!*TlsTransport {
        const self = try allocator.create(TlsTransport);
        errdefer allocator.destroy(self);

        const buffers = try allocator.alloc(u8, total_buffer_len);
        errdefer allocator.free(buffers);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .stream = stream,
            .reader = undefined,
            .writer = undefined,
            .client = undefined,
            .owned_bundle = null,
            .bundle_lock = .init,
            .buffers = buffers,
        };

        const socket_read = buffers[0..socket_buffer_len];
        const socket_write = buffers[socket_buffer_len..][0..socket_buffer_len];
        const tls_read = buffers[socket_buffer_len * 2 ..][0..socket_buffer_len];
        const tls_write = buffers[socket_buffer_len * 3 ..][0..socket_buffer_len];

        self.reader = stream.reader(io, socket_read);
        self.writer = stream.writer(io, socket_write);

        const bundle = options.bundle orelse blk: {
            self.owned_bundle = .empty;
            self.owned_bundle.?.rescan(allocator, io, .now(io, .real)) catch
                return error.TlsFailed;
            break :blk &self.owned_bundle.?;
        };
        errdefer if (self.owned_bundle) |*b| b.deinit(allocator);

        var entropy: [std.crypto.tls.Client.Options.entropy_len]u8 = undefined;
        io.random(&entropy);

        self.client = std.crypto.tls.Client.init(
            &self.reader.interface,
            &self.writer.interface,
            .{
                .host = .{ .explicit = server_name },
                .ca = .{ .bundle = .{
                    .gpa = allocator,
                    .io = io,
                    .lock = &self.bundle_lock,
                    .bundle = bundle,
                } },
                .read_buffer = tls_read,
                .write_buffer = tls_write,
                .entropy = &entropy,
                .realtime_now = .now(io, .real),
            },
        ) catch return error.TlsFailed;

        return self;
    }

    pub fn deinit(self: *TlsTransport) void {
        if (!self.closed) {
            self.client.end() catch {};
            self.writer.interface.flush() catch {};
            self.stream.close(self.io);
        }
        if (self.owned_bundle) |*b| b.deinit(self.allocator);
        const allocator = self.allocator;
        allocator.free(self.buffers);
        allocator.destroy(self);
    }

    pub fn transport(self: *TlsTransport) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .read = tlsRead,
        .write = tlsWrite,
        .flush = tlsFlush,
        .close = tlsClose,
    };

    fn tlsRead(ptr: *anyopaque, buffer: []u8) TransportError!usize {
        const self: *TlsTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        const n = self.client.reader.readSliceShort(buffer) catch return error.ReadFailed;
        return if (n == 0) error.ConnectionClosed else n;
    }

    fn tlsWrite(ptr: *anyopaque, bytes: []const u8) TransportError!void {
        const self: *TlsTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        self.client.writer.writeAll(bytes) catch return error.WriteFailed;
    }

    fn tlsFlush(ptr: *anyopaque) TransportError!void {
        const self: *TlsTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return error.ConnectionClosed;
        // The TLS writer emits records into the socket writer's buffer, so the
        // socket writer has to be flushed too or nothing reaches the peer.
        self.client.writer.flush() catch return error.WriteFailed;
        self.writer.interface.flush() catch return error.WriteFailed;
    }

    fn tlsClose(ptr: *anyopaque) void {
        const self: *TlsTransport = @ptrCast(@alignCast(ptr));
        if (self.closed) return;
        self.closed = true;
        self.client.end() catch {};
        self.writer.interface.flush() catch {};
        self.stream.close(self.io);
    }
};

// ─────────────────────── Tests ───────────────────────

test "MemoryTransport round trips bytes" {
    const allocator = std.testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    try mem.pushPeerBytes("AMQP\x00\x01\x00\x00");

    const t = mem.transport();
    try t.send("hello");
    try std.testing.expectEqualStrings("hello", mem.written());

    var buf: [8]u8 = undefined;
    try t.readAll(&buf);
    try std.testing.expectEqualStrings("AMQP\x00\x01\x00\x00", &buf);

    try std.testing.expectError(error.ConnectionClosed, t.read(&buf));
    mem.starve = true;
    try std.testing.expectEqual(@as(usize, 0), try t.read(&buf));
}

test "MemoryTransport honours the chunk size" {
    const allocator = std.testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    mem.chunk = 3;
    try mem.pushPeerBytes("abcdefgh");

    const t = mem.transport();
    var buf: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 3), try t.read(&buf));
    try std.testing.expectEqualStrings("abc", buf[0..3]);
    try t.readAll(buf[0..5]);
    try std.testing.expectEqualStrings("defgh", buf[0..5]);
}

test "readAll fails when the peer closes early" {
    const allocator = std.testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    try mem.pushPeerBytes("abc");

    const t = mem.transport();
    var buf: [8]u8 = undefined;
    try std.testing.expectError(error.ConnectionClosed, t.readAll(&buf));
}

test "closing a MemoryTransport rejects further io" {
    const allocator = std.testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();

    const t = mem.transport();
    t.close();
    var buf: [4]u8 = undefined;
    try std.testing.expectError(error.ConnectionClosed, t.read(&buf));
    try std.testing.expectError(error.ConnectionClosed, t.write("x"));
    try std.testing.expectError(error.ConnectionClosed, t.flush());
}

test "Endpoint defaults to TLS on 5671" {
    const endpoint = Endpoint.forNamespace("ns.servicebus.windows.net");
    try std.testing.expect(endpoint.tls);
    try std.testing.expectEqual(tls_port, endpoint.port);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", endpoint.serverName());
}

test "Endpoint for the emulator is plaintext" {
    const endpoint = Endpoint.forEmulator("localhost", 5672);
    try std.testing.expect(!endpoint.tls);
    try std.testing.expectEqual(tcp_port, endpoint.port);
}

test "a custom endpoint keeps the namespace certificate identity" {
    const endpoint = Endpoint.forNamespace("ns.servicebus.windows.net")
        .viaCustomEndpoint("proxy.internal", 8443);
    try std.testing.expectEqualStrings("proxy.internal", endpoint.host);
    try std.testing.expectEqual(@as(u16, 8443), endpoint.port);
    try std.testing.expect(endpoint.tls);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", endpoint.serverName());
}

test "type check the socket transports" {
    // Neither TLS nor TCP can be exercised without a peer, but both must still
    // compile; Zig would otherwise never analyze them.
    std.testing.refAllDecls(TcpTransport);
    std.testing.refAllDecls(TlsTransport);
    _ = &connect;
}
