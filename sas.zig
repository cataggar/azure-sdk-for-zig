//! Complete-URL SAS Queue message submission without credentials or retries.
const std = @import("std");
const core = @import("azure_core");
const storage_common = @import("azure_storage_common");

const sas = storage_common.sas;

/// Azure Queue permits a 64 KiB encoded `MessageText`; standard Base64 makes
/// 48 KiB the largest raw message that can always fit.
pub const max_queue_message_bytes: usize = 48 * 1024;
pub const storage_api_version = "2024-11-04";

/// A Queue client constructed only from an allocator, a complete queue SAS
/// URL, and a transport. It never accepts a credential or an external
/// pipeline, so Kusto bearer authentication cannot reach Queue Storage.
pub const SasQueueClient = struct {
    allocator: std.mem.Allocator,
    uri: sas.CompleteSasUri,
    transport: *core.http.HttpTransport,

    pub fn init(
        allocator: std.mem.Allocator,
        complete_queue_sas_uri: []const u8,
        transport: *core.http.HttpTransport,
    ) !SasQueueClient {
        var uri = try sas.CompleteSasUri.init(allocator, complete_queue_sas_uri);
        errdefer uri.deinit();
        if (!uri.hasAzureStorageServiceHost("queue"))
            return error.UnexpectedQueueSasHost;
        return .{
            .allocator = allocator,
            .uri = uri,
            .transport = transport,
        };
    }

    pub fn deinit(self: *SasQueueClient) void {
        self.uri.deinit();
        self.* = undefined;
    }

    /// Renders a query-redacted SAS URL only.
    pub fn format(self: SasQueueClient, writer: anytype) !void {
        try writer.print("SasQueueClient({f})", .{self.uri});
    }

    /// POSTs a raw message as standard Base64 inside Azure Queue's required
    /// XML `MessageText` envelope. All local allocations finish before the
    /// transport starts, so an accepted response cannot later be replaced by
    /// an allocation failure in this method.
    pub fn sendMessage(
        self: *SasQueueClient,
        message: []const u8,
    ) !sas.RequestOutcome {
        if (message.len > max_queue_message_bytes)
            return error.QueueMessageTooLarge;

        const encoded = try core.base64.encode(self.allocator, message);
        defer self.allocator.free(encoded);
        const body = try messageXml(self.allocator, encoded);
        defer self.allocator.free(body);
        const url = try self.uri.appendPathSegment(self.allocator, "messages");
        defer self.allocator.free(url);

        var request = core.http.Request.init(self.allocator, .POST, url);
        defer request.deinit();
        try request.setHeader("Content-Type", "application/xml");
        try request.setHeader("x-ms-version", storage_api_version);
        request.body = body;
        return sas.send(self.transport, &request, null);
    }
};

/// Compatibility spelling emphasizing that `init` accepts a complete SAS URL.
pub const CompleteSasQueueClient = SasQueueClient;
pub const QueueMessageOutcome = sas.RequestOutcome;

fn messageXml(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "<QueueMessage><MessageText>");
    try appendXmlEscaped(&output, allocator, encoded);
    try output.appendSlice(allocator, "</MessageText></QueueMessage>");
    return output.toOwnedSlice(allocator);
}

fn appendXmlEscaped(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) !void {
    for (value) |byte| {
        switch (byte) {
            '&' => try output.appendSlice(allocator, "&amp;"),
            '<' => try output.appendSlice(allocator, "&lt;"),
            '>' => try output.appendSlice(allocator, "&gt;"),
            '"' => try output.appendSlice(allocator, "&quot;"),
            '\'' => try output.appendSlice(allocator, "&apos;"),
            else => try output.append(allocator, byte),
        }
    }
}

test "SAS queue message preserves SAS, base64 encodes special bytes, and isolates credentials" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = try SasQueueClient.init(
        allocator,
        "https://account.queue.core.windows.net/queue?sig=a%2Bb%3D&sp=a",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.sendMessage("<&>\"'\x00");
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(core.http.Method.POST, transport.last_method.?);
    try std.testing.expectEqualStrings(
        "https://account.queue.core.windows.net/queue/messages?sig=a%2Bb%3D&sp=a",
        transport.last_url.?,
    );
    try std.testing.expectEqualStrings(
        "<QueueMessage><MessageText>PCY+IicA</MessageText></QueueMessage>",
        transport.last_body.?,
    );
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.last_redirect_policy.?);
    try std.testing.expectEqual(@as(usize, 1), transport.stream_finish_count);
}

test "SAS queue reports received rejection and validates message size" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 403, "denied");
    defer transport.deinit();
    var client = try SasQueueClient.init(
        allocator,
        "https://account.queue.core.windows.net/queue?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const rejected = try client.sendMessage("message");
    switch (rejected) {
        .rejected => |value| try std.testing.expectEqual(@as(u16, 403), value.status_code),
        else => return error.TestUnexpectedResult,
    }

    const too_large = [_]u8{0} ** (max_queue_message_bytes + 1);
    try std.testing.expectError(error.QueueMessageTooLarge, client.sendMessage(&too_large));
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
}

test "SAS queue preserves accepted status when response draining fails" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 201, "response");
    defer transport.deinit();
    transport.stream_fail_response_after = 0;
    var client = try SasQueueClient.init(
        allocator,
        "https://account.queue.core.windows.net/queue?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.sendMessage("message");
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(@as(usize, 1), transport.stream_abort_count);
}

test "Queue XML escaping and client diagnostics redact sensitive queries" {
    const allocator = std.testing.allocator;
    var escaped = std.ArrayList(u8).empty;
    defer escaped.deinit(allocator);
    try appendXmlEscaped(&escaped, allocator, "<&>\"'");
    try std.testing.expectEqualStrings("&lt;&amp;&gt;&quot;&apos;", escaped.items);

    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = try SasQueueClient.init(
        allocator,
        "https://account.queue.core.windows.net/queue?sig=secret",
        transport.asTransport(),
    );
    defer client.deinit();
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.print("{f}", .{client});
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "secret") == null);
    try std.testing.expectError(
        error.UnexpectedQueueSasHost,
        SasQueueClient.init(
            allocator,
            "https://account.blob.core.windows.net/container/blob?sig=opaque",
            transport.asTransport(),
        ),
    );
}

fn queueBodyAllocationTest(allocator: std.mem.Allocator) !void {
    const encoded = try core.base64.encode(allocator, "allocation test");
    defer allocator.free(encoded);
    const body = try messageXml(allocator, encoded);
    defer allocator.free(body);
}

test "SAS queue cleans up on every pre-transport allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        queueBodyAllocationTest,
        .{},
    );
}
