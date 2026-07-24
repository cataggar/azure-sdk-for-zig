//! Explicit opt-in Kusto Data live tests.
const std = @import("std");
const examples = @import("main.zig");

test "live Kusto query management and progressive examples" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = examples.Config.fromEnvironment(&env) orelse
        return error.SkipZigTest;
    const session = try examples.Session.create(
        allocator,
        std.testing.io,
        &env,
        config.cluster_url,
    );
    defer session.deinit();

    try std.testing.expect(try examples.runDefaultCredentialQuery(
        allocator,
        session,
        config,
    ) != 0);
    try std.testing.expect(try examples.runTypedQuery(
        allocator,
        session,
        config,
    ) != 0);
    try std.testing.expect(try examples.runManagement(
        allocator,
        session,
        config,
    ) != 0);
    try std.testing.expect(try examples.runProgressiveQuery(
        allocator,
        session,
        config,
    ) != 0);
}
