//! Explicit opt-in Kusto Ingest live tests.
const std = @import("std");
const examples = @import("main.zig");
const ingest = @import("azure_sdk_kusto_ingest");

test "live Kusto ingestion and status examples" {
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
