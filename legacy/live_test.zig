//! Explicit opt-in Kusto live tests.
//!
//! `zig build kusto-live-test` skips cleanly unless the documented Kusto
//! environment is present. It is not part of the deterministic default suite.
const std = @import("std");
const examples = @import("main.zig");
const ingest = @import("azure_sdk_kusto_ingest");

test "live Kusto query management and progressive examples" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try examples.Config.fromEnvironment(&env)) orelse
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

test "live Kusto ingestion and status examples" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try examples.Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;
    if (config.target_table == null or config.target_mapping == null)
        return error.SkipZigTest;
    const session = try examples.Session.create(
        allocator,
        std.testing.io,
        &env,
        config.cluster_url,
    );
    defer session.deinit();

    try std.testing.expectEqual(
        ingest.IngestionStatus.success,
        try examples.runStreamingIngestion(allocator, session, config),
    );
    try std.testing.expectEqual(
        ingest.QueuedSubmissionOutcome.queue_accepted,
        try examples.runQueuedIngestion(allocator, session, config),
    );
    try std.testing.expectEqual(
        ingest.ManagedIngestionRoute.queued,
        try examples.runManagedIngestion(allocator, session, config),
    );
    const polled = try examples.runStatusPolling(allocator, session, config);
    switch (polled) {
        .status => |status_value| try std.testing.expectEqual(
            ingest.QueuedIngestionStatus.succeeded,
            status_value,
        ),
        .stopped => return error.KustoStatusPollingStopped,
    }
}
