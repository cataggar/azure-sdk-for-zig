const std = @import("std");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Response = struct {
    status_code: u16 = 200,
    reason: []const u8 = "OK",
    headers: []const Header = &.{},
    body: []const u8 = "",
    chunked: bool = false,
    advertised_content_length: ?usize = null,
    omit_body: bool = false,
};

/// A one-request loopback HTTP/1.1 server for deterministic transport tests.
///
/// Request bodies are counted while only a bounded prefix is retained, so
/// conformance tests can exercise logical-large streams without allocating
/// storage proportional to the upload.
pub const ScriptedHttpServer = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    listener: std.Io.net.Server,
    response: Response,
    thread: ?std.Thread = null,
    joined: bool = false,
    allow_peer_failure: bool = false,
    failure: ?anyerror = null,
    request_line: []u8 = &.{},
    header_lines: std.ArrayList([]u8) = .empty,
    body_prefix: [4096]u8 = undefined,
    body_prefix_len: usize = 0,
    body_length: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        response: Response,
    ) !ScriptedHttpServer {
        var address: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
        return .{
            .allocator = allocator,
            .io = io,
            .listener = try address.listen(io, .{ .reuse_address = true }),
            .response = response,
        };
    }

    pub fn start(self: *ScriptedHttpServer) !void {
        self.thread = try std.Thread.spawn(.{}, run, .{self});
    }

    pub fn allocUrl(
        self: *const ScriptedHttpServer,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "http://127.0.0.1:{d}{s}",
            .{ self.listener.socket.address.getPort(), path },
        );
    }

    pub fn join(self: *ScriptedHttpServer) !void {
        if (!self.joined) {
            if (self.thread) |thread| thread.join();
            self.joined = true;
        }
        if (self.failure) |failure| {
            if (!self.allow_peer_failure) return failure;
        }
    }

    pub fn deinit(self: *ScriptedHttpServer) void {
        if (!self.joined) {
            if (self.thread) |thread| thread.join();
        }
        self.listener.deinit(self.io);
        if (self.request_line.len > 0) self.allocator.free(self.request_line);
        for (self.header_lines.items) |line| self.allocator.free(line);
        self.header_lines.deinit(self.allocator);
    }

    pub fn body(self: *const ScriptedHttpServer) []const u8 {
        return self.body_prefix[0..self.body_prefix_len];
    }

    pub fn headerCount(self: *const ScriptedHttpServer, name: []const u8) usize {
        var count: usize = 0;
        for (self.header_lines.items) |line| {
            const header = splitHeader(line) orelse continue;
            if (std.ascii.eqlIgnoreCase(header.name, name)) count += 1;
        }
        return count;
    }

    pub fn headerValue(
        self: *const ScriptedHttpServer,
        name: []const u8,
    ) ?[]const u8 {
        for (self.header_lines.items) |line| {
            const header = splitHeader(line) orelse continue;
            if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
        }
        return null;
    }

    fn splitHeader(line: []const u8) ?Header {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
        return .{
            .name = line[0..colon],
            .value = std.mem.trim(u8, line[colon + 1 ..], " \t"),
        };
    }

    fn run(self: *ScriptedHttpServer) void {
        self.serve() catch |err| {
            self.failure = err;
        };
    }

    fn serve(self: *ScriptedHttpServer) !void {
        const stream = try self.listener.accept(self.io);
        defer stream.close(self.io);

        var read_buffer: [16 * 1024]u8 = undefined;
        var reader = std.Io.net.Stream.Reader.init(stream, self.io, &read_buffer);
        var write_buffer: [16 * 1024]u8 = undefined;
        var writer = std.Io.net.Stream.Writer.init(stream, self.io, &write_buffer);

        const first = (reader.interface.takeDelimiter('\n') catch
            return error.ServerHeaderReadFailed) orelse
            return error.ServerHeaderReadFailed;
        const first_line = std.mem.trimEnd(u8, first, "\r");
        self.request_line = try self.allocator.dupe(u8, first_line);

        var content_length: ?usize = null;
        var chunked = false;
        while (true) {
            const raw_line = (reader.interface.takeDelimiter('\n') catch
                return error.ServerHeaderReadFailed) orelse
                return error.ServerHeaderReadFailed;
            const line = std.mem.trimEnd(u8, raw_line, "\r");
            if (line.len == 0) break;
            try self.header_lines.append(
                self.allocator,
                try self.allocator.dupe(u8, line),
            );
            const header = splitHeader(line) orelse continue;
            if (std.ascii.eqlIgnoreCase(header.name, "content-length")) {
                content_length = try std.fmt.parseInt(usize, header.value, 10);
            } else if (std.ascii.eqlIgnoreCase(header.name, "transfer-encoding")) {
                chunked = std.ascii.eqlIgnoreCase(header.value, "chunked");
            }
        }

        if (chunked) {
            try self.readChunkedBody(&reader.interface);
        } else if (content_length) |length| {
            try self.readBody(&reader.interface, length);
        }

        try writer.interface.print(
            "HTTP/1.1 {d} {s}\r\n",
            .{ self.response.status_code, self.response.reason },
        );
        for (self.response.headers) |header| {
            try writer.interface.print(
                "{s}: {s}\r\n",
                .{ header.name, header.value },
            );
        }
        if (self.response.chunked) {
            try writer.interface.writeAll(
                "Transfer-Encoding: chunked\r\nConnection: close\r\n\r\n",
            );
            if (!self.response.omit_body and self.response.body.len > 0) {
                const midpoint = (self.response.body.len + 1) / 2;
                try writer.interface.print("{x}\r\n", .{midpoint});
                try writer.interface.writeAll(self.response.body[0..midpoint]);
                if (midpoint < self.response.body.len) {
                    try writer.interface.print(
                        "\r\n{x}\r\n",
                        .{self.response.body.len - midpoint},
                    );
                    try writer.interface.writeAll(self.response.body[midpoint..]);
                }
                try writer.interface.writeAll("\r\n");
            }
            try writer.interface.writeAll("0\r\n\r\n");
        } else {
            const content_length_value = self.response.advertised_content_length orelse
                self.response.body.len;
            try writer.interface.print(
                "Content-Length: {d}\r\nConnection: close\r\n\r\n",
                .{content_length_value},
            );
            if (!self.response.omit_body) {
                try writer.interface.writeAll(self.response.body);
            }
        }
        try writer.interface.flush();
    }

    fn readChunkedBody(
        self: *ScriptedHttpServer,
        reader: *std.Io.Reader,
    ) !void {
        while (true) {
            const raw_size = (reader.takeDelimiter('\n') catch
                return error.ServerChunkHeaderReadFailed) orelse
                return error.ServerChunkHeaderReadFailed;
            const size_text = std.mem.trim(u8, raw_size, "\r \t");
            const semicolon = std.mem.indexOfScalar(u8, size_text, ';') orelse
                size_text.len;
            const size = try std.fmt.parseInt(usize, size_text[0..semicolon], 16);
            if (size == 0) {
                while (true) {
                    const trailer = (reader.takeDelimiter('\n') catch
                        return error.ServerChunkTrailerReadFailed) orelse
                        return error.ServerChunkTrailerReadFailed;
                    if (std.mem.trimEnd(u8, trailer, "\r").len == 0) break;
                }
                return;
            }
            try self.readBody(reader, size);
            var crlf: [2]u8 = undefined;
            reader.readSliceAll(&crlf) catch
                return error.ServerChunkTerminatorReadFailed;
            if (!std.mem.eql(u8, &crlf, "\r\n")) return error.InvalidChunkTerminator;
        }
    }

    fn readBody(
        self: *ScriptedHttpServer,
        reader: *std.Io.Reader,
        length: usize,
    ) !void {
        var remaining = length;
        var buffer: [16 * 1024]u8 = undefined;
        while (remaining > 0) {
            const amount = @min(remaining, buffer.len);
            reader.readSliceAll(buffer[0..amount]) catch
                return error.ServerBodyReadFailed;
            const prefix_remaining = self.body_prefix.len - self.body_prefix_len;
            const copy_len = @min(prefix_remaining, amount);
            if (copy_len > 0) {
                @memcpy(
                    self.body_prefix[self.body_prefix_len..][0..copy_len],
                    buffer[0..copy_len],
                );
                self.body_prefix_len += copy_len;
            }
            self.body_length += amount;
            remaining -= amount;
        }
    }
};
