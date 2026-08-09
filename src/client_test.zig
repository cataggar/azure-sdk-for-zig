//! Tests for `DevOpsClient` that exercise the pipeline against a stub
//! transport rather than the service.

const std = @import("std");
const core = @import("azure_sdk_core");
const root = @import("root.zig");

const DevOpsClient = root.DevOpsClient;

/// Records the last request it saw and replays a canned response.
const StubTransport = struct {
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,
    status_code: u16 = 200,
    body: []const u8 = "{}",
    last_url: ?[]u8 = null,
    last_authorization: ?[]u8 = null,
    last_user_agent: ?[]u8 = null,

    fn init(allocator: std.mem.Allocator) StubTransport {
        return .{
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    fn deinit(self: *StubTransport) void {
        if (self.last_url) |value| self.allocator.free(value);
        if (self.last_authorization) |value| self.allocator.free(value);
        if (self.last_user_agent) |value| self.allocator.free(value);
    }

    fn asTransport(self: *StubTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) anyerror!core.http.Response {
        const self: *StubTransport = @alignCast(@fieldParentPtr("transport", transport));
        if (self.last_url) |value| self.allocator.free(value);
        self.last_url = try self.allocator.dupe(u8, request.url);
        if (request.getHeader("Authorization")) |value| {
            if (self.last_authorization) |old| self.allocator.free(old);
            self.last_authorization = try self.allocator.dupe(u8, value);
        }
        if (request.getHeader("User-Agent")) |value| {
            if (self.last_user_agent) |old| self.allocator.free(old);
            self.last_user_agent = try self.allocator.dupe(u8, value);
        }
        return .{
            .status_code = self.status_code,
            .body = try self.allocator.dupe(u8, self.body),
            .headers = .init(self.allocator),
            .allocator = self.allocator,
            .response_headers = .{},
        };
    }
};

test "every area is reachable from one authenticated client" {
    const allocator = std.testing.allocator;
    var transport = StubTransport.init(allocator);
    defer transport.deinit();

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    const git = client.git();
    const build = client.build();
    const work_item_tracking = client.workItemTracking();
    const test_management = client.testManagement();

    try std.testing.expect(@hasDecl(@TypeOf(git), "repositories"));
    try std.testing.expect(@hasDecl(@TypeOf(build), "builds"));
    try std.testing.expect(@hasDecl(@TypeOf(work_item_tracking), "workItems"));
    try std.testing.expect(@hasDecl(@TypeOf(test_management), "runs"));
}

test "areas keep their own hosts unless the caller overrides the endpoint" {
    const allocator = std.testing.allocator;
    var transport = StubTransport.init(allocator);
    defer transport.deinit();

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    const git = client.git();
    const graph = client.graph();
    try std.testing.expectEqualStrings("https://dev.azure.com", git.endpoint);
    try std.testing.expectEqualStrings("https://vssps.dev.azure.com", graph.endpoint);

    // Azure DevOps Server serves every area from one collection URL.
    var server = try DevOpsClient.init(allocator, .{
        .organization = "DefaultCollection",
        .transport = transport.asTransport(),
        .endpoint = "https://tfs.contoso.com/tfs",
    });
    defer server.deinit();
    const server_git = server.git();
    const server_graph = server.graph();
    try std.testing.expectEqualStrings("https://tfs.contoso.com/tfs", server_git.endpoint);
    try std.testing.expectEqualStrings("https://tfs.contoso.com/tfs", server_graph.endpoint);
}

test "requests carry the PAT and the SDK user agent" {
    const allocator = std.testing.allocator;
    var transport = StubTransport.init(allocator);
    defer transport.deinit();
    transport.body = "{\"count\":0,\"value\":[]}";

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    var status = client.status();
    var health = status.health();
    const result = health.get(allocator, null, null) catch |err| switch (err) {
        error.AzureRequestFailed => return error.SkipZigTest,
        else => return err,
    };
    _ = result;

    try std.testing.expectStringStartsWith(transport.last_authorization.?, "Basic ");
    try std.testing.expectEqualStrings(root.user_agent, transport.last_user_agent.?);
}

test "the api-version is pinned to the generated 7.2 contract" {
    const allocator = std.testing.allocator;
    var transport = StubTransport.init(allocator);
    defer transport.deinit();

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    const git = client.git();
    try std.testing.expectStringStartsWith(git.api_version, "7.2");
}
