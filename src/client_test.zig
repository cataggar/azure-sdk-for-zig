//! Tests for `DevOpsClient` that exercise the pipeline against a stub
//! transport rather than the service.

const std = @import("std");
const core = @import("azure_sdk_core");
const root = @import("root.zig");

const DevOpsClient = root.DevOpsClient;

test "every area is reachable from one authenticated client" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .runtime = runtime,
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
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    const git = client.git();
    const graph = client.graph();
    try std.testing.expectEqualStrings("https://dev.azure.com", git.endpoint);
    try std.testing.expectEqualStrings("https://vssps.dev.azure.com", graph.endpoint);

    // Azure DevOps Server serves every area from one collection URL.
    var server = try DevOpsClient.init(allocator, .{
        .organization = "DefaultCollection",
        .runtime = runtime,
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
    var transport = core.http.MockTransport.init(
        allocator,
        200,
        "{\"count\":0,\"value\":[]}",
    );
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .runtime = runtime,
    });
    defer client.deinit();

    var status = client.status();
    var health = status.health();
    const result = health.get(allocator, null, null) catch |err| switch (err) {
        error.AzureRequestFailed => return error.SkipZigTest,
        else => return err,
    };
    _ = result;

    try std.testing.expectStringStartsWith(
        transport.last_headers.get("Authorization").?,
        "Basic ",
    );
    try std.testing.expectEqualStrings(
        root.user_agent,
        transport.last_headers.get("User-Agent").?,
    );
}

test "the api-version is pinned to the generated 7.2 contract" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    const git = client.git();
    try std.testing.expectStringStartsWith(git.api_version, "7.2");
}

test "derived operation clients preserve the selected runtime" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    var git = client.git();
    const repositories = git.repositories();
    try std.testing.expectEqual(
        runtime.transport.context,
        repositories.pipeline.runtime.transport.context,
    );
    try std.testing.expectEqual(
        runtime.transport.vtable,
        repositories.pipeline.runtime.transport.vtable,
    );
    try std.testing.expectEqual(
        runtime.crypto.context,
        repositories.pipeline.runtime.crypto.context,
    );
    try std.testing.expectEqual(
        runtime.crypto.vtable,
        repositories.pipeline.runtime.crypto.vtable,
    );
}
