//! Explicit opt-in HTTP test tooling, not an SDK exporter. interop.sh verifies
//! child socket ownership and applies a process deadline before invoking this.
const std = @import("std");

pub const std_options: std.Options = .{ .http_disable_tls = true };

fn urlForPort(buffer: []u8, text: []const u8) ![]const u8 {
    const port = try std.fmt.parseInt(u16, text, 10);
    if (port == 0) return error.InvalidPort;
    return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}/v1/traces", .{port});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedProbeOrPostAndPort;
    const post = std.mem.eql(u8, args[1], "post");
    if (!post and !std.mem.eql(u8, args[1], "probe")) return error.ExpectedProbeOrPostAndPort;
    var url_buffer: [64]u8 = undefined;
    const url = try urlForPort(&url_buffer, args[2]);
    const payload = if (post)
        try std.Io.Dir.cwd().readFileAlloc(init.io, "request.json", init.gpa, .limited(64 * 1024))
    else
        null;
    defer if (payload) |bytes| init.gpa.free(bytes);
    var response_buffer: [4096]u8 = undefined;
    var response: std.Io.Writer = .fixed(&response_buffer);
    // No environment/proxy discovery, TLS, SDK pipeline, or external URL input.
    var client: std.http.Client = .{
        .allocator = init.gpa,
        .io = init.io,
        .http_proxy = null,
        .https_proxy = null,
    };
    defer client.deinit();
    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = if (post) .POST else .GET,
        .payload = payload,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .response_writer = &response,
        .redirect_behavior = .not_allowed,
        .keep_alive = false,
    });
    if (post) {
        const file = try std.Io.Dir.cwd().createFile(init.io, "response.json", .{ .exclusive = true });
        defer file.close(init.io);
        try file.writeStreamingAll(init.io, response.buffered());
    }
    const expected: std.http.Status = if (post) .ok else .method_not_allowed;
    if (result.status != expected) {
        std.debug.print("Collector {s}: HTTP {d}, expected {d}\n", .{
            args[1], @intFromEnum(result.status), @intFromEnum(expected),
        });
        return error.UnexpectedCollectorResponse;
    }
    std.debug.print("Collector {s}: HTTP {d}\n", .{ args[1], @intFromEnum(result.status) });
}

test "HTTP tooling accepts only a nonzero port on fixed loopback" {
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("http://127.0.0.1:4318/v1/traces", try urlForPort(&buffer, "4318"));
    try std.testing.expectError(error.InvalidPort, urlForPort(&buffer, "0"));
    try std.testing.expectError(error.Overflow, urlForPort(&buffer, "65536"));
    try std.testing.expectError(error.InvalidCharacter, urlForPort(&buffer, "example.com:4318"));
}
