const std = @import("std");
const core = @import("azure_core");

// ─────────────────────────── Models ───────────────────────────

pub const QueueMessage = struct {
    message_id: ?[]const u8 = null,
    message_text: ?[]const u8 = null,
    insertion_time: ?[]const u8 = null,
    expiration_time: ?[]const u8 = null,
};

// ──────────────────────── QueueClient ─────────────────────────

pub const QueueClientOptions = struct {
    api_version: []const u8 = "2024-11-04",
};

pub const QueueClient = struct {
    endpoint: []const u8,
    queue_name: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        queue_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: QueueClientOptions,
    ) QueueClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .queue_name = queue_name,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// POST /queue/messages
    pub fn sendMessage(self: *QueueClient, allocator: std.mem.Allocator, message_text: []const u8) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/messages",
            .{ self.endpoint, self.queue_name },
        );
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(
            allocator,
            "<QueueMessage><MessageText>{s}</MessageText></QueueMessage>",
            .{message_text},
        );
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/xml");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.SendMessageFailed;
        }
    }

    /// GET /queue/messages
    pub fn receiveMessages(self: *QueueClient, allocator: std.mem.Allocator) ![]QueueMessage {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/messages",
            .{ self.endpoint, self.queue_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.ReceiveMessagesFailed;
        }

        return parseMessages(allocator, resp.body);
    }

    /// DELETE /queue/messages/{messageId}?popreceipt={popReceipt}
    pub fn deleteMessage(self: *QueueClient, allocator: std.mem.Allocator, message_id: []const u8, pop_receipt: []const u8) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/messages/{s}?popreceipt={s}",
            .{ self.endpoint, self.queue_name, message_id, pop_receipt },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.DeleteMessageFailed;
        }
    }

    /// GET /queue/messages?peekonly=true
    pub fn peekMessages(self: *QueueClient, allocator: std.mem.Allocator) ![]QueueMessage {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/messages?peekonly=true",
            .{ self.endpoint, self.queue_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.PeekMessagesFailed;
        }

        return parseMessages(allocator, resp.body);
    }
};

// ──────────────────── QueueServiceClient ──────────────────────

pub const QueueServiceClient = struct {
    endpoint: []const u8,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
    ) QueueServiceClient {
        return .{
            .endpoint = endpoint,
            .credential = credential,
            .transport = transport,
            .api_version = "2024-11-04",
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// PUT /queue?comp=metadata (create queue)
    pub fn createQueue(self: *QueueServiceClient, allocator: std.mem.Allocator, queue_name: []const u8) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.endpoint, queue_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.CreateQueueFailed;
        }
    }

    /// DELETE /queue
    pub fn deleteQueue(self: *QueueServiceClient, allocator: std.mem.Allocator, queue_name: []const u8) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.endpoint, queue_name },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.DeleteQueueFailed;
        }
    }

    pub fn getQueueClient(self: *QueueServiceClient, queue_name: []const u8) QueueClient {
        return QueueClient.init(self.endpoint, queue_name, self.credential, self.transport, .{});
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseMessages(allocator: std.mem.Allocator, body: []const u8) ![]QueueMessage {
    const xml = core.xml;

    const ids = try xml.findAllText(allocator, body, "MessageId");
    defer {
        for (ids) |id| allocator.free(id);
        allocator.free(ids);
    }

    const texts = try xml.findAllText(allocator, body, "MessageText");
    defer {
        for (texts) |t| allocator.free(t);
        allocator.free(texts);
    }

    const ins_times = try xml.findAllText(allocator, body, "InsertionTime");
    defer {
        for (ins_times) |t| allocator.free(t);
        allocator.free(ins_times);
    }

    const exp_times = try xml.findAllText(allocator, body, "ExpirationTime");
    defer {
        for (exp_times) |t| allocator.free(t);
        allocator.free(exp_times);
    }

    const count = ids.len;
    var result = try allocator.alloc(QueueMessage, count);
    for (0..count) |i| {
        result[i] = .{
            .message_id = try allocator.dupe(u8, ids[i]),
            .message_text = if (i < texts.len) try allocator.dupe(u8, texts[i]) else null,
            .insertion_time = if (i < ins_times.len) try allocator.dupe(u8, ins_times[i]) else null,
            .expiration_time = if (i < exp_times.len) try allocator.dupe(u8, exp_times[i]) else null,
        };
    }
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

test "QueueClient sendMessage" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = QueueClient.init(
        "https://myaccount.queue.core.windows.net",
        "myqueue",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    try client.sendMessage(allocator, "Hello Queue!");
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "myqueue/messages") != null);
}

test "QueueClient receiveMessages" {
    const allocator = std.testing.allocator;
    const body =
        \\<QueueMessagesList><QueueMessage><MessageId>msg-001</MessageId><MessageText>Hello</MessageText><InsertionTime>2025-01-01T00:00:00Z</InsertionTime><ExpirationTime>2025-01-08T00:00:00Z</ExpirationTime></QueueMessage></QueueMessagesList>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = QueueClient.init(
        "https://myaccount.queue.core.windows.net",
        "myqueue",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const messages = try client.receiveMessages(allocator);
    defer {
        for (messages) |m| {
            if (m.message_id) |v| allocator.free(v);
            if (m.message_text) |v| allocator.free(v);
            if (m.insertion_time) |v| allocator.free(v);
            if (m.expiration_time) |v| allocator.free(v);
        }
        allocator.free(messages);
    }

    try std.testing.expectEqual(@as(usize, 1), messages.len);
    try std.testing.expectEqualStrings("msg-001", messages[0].message_id.?);
    try std.testing.expectEqualStrings("Hello", messages[0].message_text.?);
    try std.testing.expectEqualStrings("2025-01-01T00:00:00Z", messages[0].insertion_time.?);
    try std.testing.expectEqualStrings("2025-01-08T00:00:00Z", messages[0].expiration_time.?);
}
