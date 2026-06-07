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
        var r = try self.sendMessageResult(allocator, message_text);
        try r.unwrap(error.SendMessageFailed);
    }

    /// Same as `sendMessage` but returns `Result(void)`.
    pub fn sendMessageResult(self: *QueueClient, allocator: std.mem.Allocator, message_text: []const u8) !core.errors.Result(void) {
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

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /queue/messages
    pub fn receiveMessages(self: *QueueClient, allocator: std.mem.Allocator) ![]QueueMessage {
        var r = try self.receiveMessagesResult(allocator);
        return r.unwrap(error.ReceiveMessagesFailed);
    }

    /// Same as `receiveMessages` but returns `Result([]QueueMessage)`.
    pub fn receiveMessagesResult(self: *QueueClient, allocator: std.mem.Allocator) !core.errors.Result([]QueueMessage) {
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
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseMessages(allocator, resp.body) };
    }

    /// DELETE /queue/messages/{messageId}?popreceipt={popReceipt}
    pub fn deleteMessage(self: *QueueClient, allocator: std.mem.Allocator, message_id: []const u8, pop_receipt: []const u8) !void {
        var r = try self.deleteMessageResult(allocator, message_id, pop_receipt);
        try r.unwrap(error.DeleteMessageFailed);
    }

    /// Same as `deleteMessage` but returns `Result(void)`.
    pub fn deleteMessageResult(self: *QueueClient, allocator: std.mem.Allocator, message_id: []const u8, pop_receipt: []const u8) !core.errors.Result(void) {
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

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /queue/messages?peekonly=true
    pub fn peekMessages(self: *QueueClient, allocator: std.mem.Allocator) ![]QueueMessage {
        var r = try self.peekMessagesResult(allocator);
        return r.unwrap(error.PeekMessagesFailed);
    }

    /// Same as `peekMessages` but returns `Result([]QueueMessage)`.
    pub fn peekMessagesResult(self: *QueueClient, allocator: std.mem.Allocator) !core.errors.Result([]QueueMessage) {
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
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseMessages(allocator, resp.body) };
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
        var r = try self.createQueueResult(allocator, queue_name);
        try r.unwrap(error.CreateQueueFailed);
    }

    /// Same as `createQueue` but returns `Result(void)`.
    pub fn createQueueResult(self: *QueueServiceClient, allocator: std.mem.Allocator, queue_name: []const u8) !core.errors.Result(void) {
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

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// DELETE /queue
    pub fn deleteQueue(self: *QueueServiceClient, allocator: std.mem.Allocator, queue_name: []const u8) !void {
        var r = try self.deleteQueueResult(allocator, queue_name);
        try r.unwrap(error.DeleteQueueFailed);
    }

    /// Same as `deleteQueue` but returns `Result(void)`.
    pub fn deleteQueueResult(self: *QueueServiceClient, allocator: std.mem.Allocator, queue_name: []const u8) !core.errors.Result(void) {
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

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    pub fn getQueueClient(self: *QueueServiceClient, queue_name: []const u8) QueueClient {
        return QueueClient.init(self.endpoint, queue_name, self.credential, self.transport, .{});
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseMessages(allocator: std.mem.Allocator, body: []const u8) ![]QueueMessage {
    const serde = @import("serde");

    const QueueMessageSchema = struct {
        MessageId: []const u8,
        MessageText: ?[]const u8 = null,
        InsertionTime: ?[]const u8 = null,
        ExpirationTime: ?[]const u8 = null,
    };
    const QueueMessagesListSchema = struct {
        QueueMessage: ?[]const QueueMessageSchema = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(QueueMessagesListSchema, arena.allocator(), body) catch
        return allocator.alloc(QueueMessage, 0);

    const msgs = parsed.QueueMessage orelse return allocator.alloc(QueueMessage, 0);

    var result = try allocator.alloc(QueueMessage, msgs.len);
    for (msgs, 0..) |m, i| {
        result[i] = .{
            .message_id = try allocator.dupe(u8, m.MessageId),
            .message_text = if (m.MessageText) |t| try allocator.dupe(u8, t) else null,
            .insertion_time = if (m.InsertionTime) |t| try allocator.dupe(u8, t) else null,
            .expiration_time = if (m.ExpirationTime) |t| try allocator.dupe(u8, t) else null,
        };
    }
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

test "QueueClient sendMessage" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();

    const identity = @import("azure_core").identity;
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
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "myqueue/messages") != null);
}

test "QueueClient receiveMessages" {
    const allocator = std.testing.allocator;
    const body =
        \\<QueueMessagesList><QueueMessage><MessageId>msg-001</MessageId><MessageText>Hello</MessageText><InsertionTime>2025-01-01T00:00:00Z</InsertionTime><ExpirationTime>2025-01-08T00:00:00Z</ExpirationTime></QueueMessage></QueueMessagesList>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity2 = @import("azure_core").identity;
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
