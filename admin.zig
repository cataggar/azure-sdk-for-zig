//! Azure Service Bus administration — queues, topics, and subscriptions over
//! the management REST API.
//!
//! Split from `root.zig` so the messaging path and the control path stay
//! separately readable; the client is re-exported from the package root.
const std = @import("std");
const core = @import("azure_sdk_core");
const serde = @import("serde");

// ─────────────── Administration Models ───────────────

pub const QueueProperties = struct {
    name: []const u8,
    max_delivery_count: ?u32 = null,
    lock_duration: ?[]const u8 = null,
    max_size_in_megabytes: ?u32 = null,
    requires_session: bool = false,
    dead_lettering_on_message_expiration: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

pub const TopicProperties = struct {
    name: []const u8,
    max_size_in_megabytes: ?u32 = null,
    requires_duplicate_detection: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

pub const SubscriptionProperties = struct {
    name: []const u8,
    topic_name: []const u8,
    max_delivery_count: ?u32 = null,
    lock_duration: ?[]const u8 = null,
    requires_session: bool = false,
    dead_lettering_on_message_expiration: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

// ─────────────── Administration Client ───────────────

pub const AdministrationClientOptions = struct {
    api_version: []const u8 = "2021-05",
};

/// Manages Service Bus queues, topics, and subscriptions via REST API.
pub const ServiceBusAdministrationClient = struct {
    fully_qualified_namespace: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        fully_qualified_namespace: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: AdministrationClientOptions,
    ) ServiceBusAdministrationClient {
        _ = credential;
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    // ── Queue operations ──

    pub fn createQueue(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        var r = try self.createQueueResult(allocator, name);
        try r.unwrap(error.CreateQueueFailed);
    }

    /// Same as `createQueue` but returns `Result(void)`.
    pub fn createQueueResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !core.errors.Result(void) {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <QueueDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    pub fn deleteQueue(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        var r = try self.deleteQueueResult(allocator, name);
        try r.unwrap(error.DeleteQueueFailed);
    }

    /// Same as `deleteQueue` but returns `Result(void)`.
    pub fn deleteQueueResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !core.errors.Result(void) {
        const url = try self.buildEntityUrl(allocator, name);
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

    pub fn listQueues(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) ![]QueueProperties {
        var r = try self.listQueuesResult(allocator);
        return r.unwrap(error.ListQueuesFailed);
    }

    /// Same as `listQueues` but returns `Result([]QueueProperties)`.
    pub fn listQueuesResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) !core.errors.Result([]QueueProperties) {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/$Resources/queues?api-version={s}", .{ self.fully_qualified_namespace, self.api_version });
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

        return .{ .ok = try parseEntityNames(allocator, resp.body, "Queue") };
    }

    // ── Topic operations ──

    pub fn createTopic(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        var r = try self.createTopicResult(allocator, name);
        try r.unwrap(error.CreateTopicFailed);
    }

    /// Same as `createTopic` but returns `Result(void)`.
    pub fn createTopicResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !core.errors.Result(void) {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <TopicDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    pub fn deleteTopic(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        var r = try self.deleteTopicResult(allocator, name);
        try r.unwrap(error.DeleteTopicFailed);
    }

    /// Same as `deleteTopic` but returns `Result(void)`.
    pub fn deleteTopicResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !core.errors.Result(void) {
        const url = try self.buildEntityUrl(allocator, name);
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

    pub fn listTopics(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) ![]TopicProperties {
        var r = try self.listTopicsResult(allocator);
        return r.unwrap(error.ListTopicsFailed);
    }

    /// Same as `listTopics` but returns `Result([]TopicProperties)`.
    pub fn listTopicsResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) !core.errors.Result([]TopicProperties) {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/$Resources/topics?api-version={s}", .{ self.fully_qualified_namespace, self.api_version });
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

        return .{ .ok = try parseEntityNames(allocator, resp.body, "Topic") };
    }

    // ── Subscription operations ──

    pub fn createSubscription(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !void {
        var r = try self.createSubscriptionResult(allocator, topic_name, subscription_name);
        try r.unwrap(error.CreateSubscriptionFailed);
    }

    /// Same as `createSubscription` but returns `Result(void)`.
    pub fn createSubscriptionResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions/{s}?api-version={s}", .{ self.fully_qualified_namespace, topic_name, subscription_name, self.api_version });
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <SubscriptionDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    pub fn deleteSubscription(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !void {
        var r = try self.deleteSubscriptionResult(allocator, topic_name, subscription_name);
        try r.unwrap(error.DeleteSubscriptionFailed);
    }

    /// Same as `deleteSubscription` but returns `Result(void)`.
    pub fn deleteSubscriptionResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions/{s}?api-version={s}", .{ self.fully_qualified_namespace, topic_name, subscription_name, self.api_version });
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

    pub fn listSubscriptions(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8) ![]SubscriptionProperties {
        var r = try self.listSubscriptionsResult(allocator, topic_name);
        return r.unwrap(error.ListSubscriptionsFailed);
    }

    /// Same as `listSubscriptions` but returns `Result([]SubscriptionProperties)`.
    pub fn listSubscriptionsResult(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8) !core.errors.Result([]SubscriptionProperties) {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions?api-version={s}", .{ self.fully_qualified_namespace, topic_name, self.api_version });
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

        return .{ .ok = try parseSubscriptionNames(allocator, resp.body, topic_name) };
    }

    fn buildEntityUrl(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://{s}/{s}?api-version={s}", .{ self.fully_qualified_namespace, name, self.api_version });
    }
};

// ─────────────────── Atom XML Parsing ────────────────

const AtomEntrySchema = struct {
    title: []const u8,
};

const AtomFeedSchema = struct {
    entry: ?[]const AtomEntrySchema = null,
};

/// Parse entity names from Atom feed response.
fn parseEntityNames(allocator: std.mem.Allocator, body: []const u8, comptime entity_type: []const u8) !switch (entity_type.len) {
    5 => []QueueProperties,
    else => []TopicProperties,
} {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(AtomFeedSchema, arena.allocator(), body) catch {
        if (entity_type.len == 5)
            return allocator.alloc(QueueProperties, 0)
        else
            return allocator.alloc(TopicProperties, 0);
    };

    const entries = parsed.entry orelse {
        if (entity_type.len == 5)
            return allocator.alloc(QueueProperties, 0)
        else
            return allocator.alloc(TopicProperties, 0);
    };

    if (entity_type.len == 5) { // "Queue"
        var result = try allocator.alloc(QueueProperties, entries.len);
        for (entries, 0..) |e, i| {
            result[i] = .{ .name = try allocator.dupe(u8, e.title) };
        }
        return result;
    } else { // "Topic"
        var result = try allocator.alloc(TopicProperties, entries.len);
        for (entries, 0..) |e, i| {
            result[i] = .{ .name = try allocator.dupe(u8, e.title) };
        }
        return result;
    }
}

fn parseSubscriptionNames(allocator: std.mem.Allocator, body: []const u8, topic_name: []const u8) ![]SubscriptionProperties {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(AtomFeedSchema, arena.allocator(), body) catch
        return allocator.alloc(SubscriptionProperties, 0);
    const entries = parsed.entry orelse return allocator.alloc(SubscriptionProperties, 0);

    var result = try allocator.alloc(SubscriptionProperties, entries.len);
    for (entries, 0..) |e, i| {
        result[i] = .{ .name = try allocator.dupe(u8, e.title), .topic_name = topic_name };
    }
    return result;
}

// ───────────────────── Tests ─────────────────────

test "AdministrationClient createQueue" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "<entry/>");
    defer mock.deinit();
    const identity = @import("azure_sdk_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.createQueue(allocator, "testqueue");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "testqueue") != null);
    try std.testing.expectEqual(core.http.Method.PUT, mock.last_method.?);
}

test "AdministrationClient deleteQueue" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    const identity = @import("azure_sdk_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.deleteQueue(allocator, "testqueue");
    try std.testing.expectEqual(core.http.Method.DELETE, mock.last_method.?);
}

test "AdministrationClient listQueues" {
    const allocator = std.testing.allocator;
    const body =
        \\<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>queue1</title></entry><entry><title>queue2</title></entry></feed>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();
    const identity = @import("azure_sdk_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    const queues = try admin.listQueues(allocator);
    defer {
        for (queues) |q| allocator.free(q.name);
        allocator.free(queues);
    }
    try std.testing.expectEqual(@as(usize, 2), queues.len);
    try std.testing.expectEqualStrings("queue1", queues[0].name);
    try std.testing.expectEqualStrings("queue2", queues[1].name);
}

test "AdministrationClient createSubscription" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "<entry/>");
    defer mock.deinit();
    const identity = @import("azure_sdk_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.createSubscription(allocator, "mytopic", "mysub");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "mytopic/subscriptions/mysub") != null);
}
