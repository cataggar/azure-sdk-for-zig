//! Opt-in live examples for Azure Data Explorer (Kusto).
//!
//! Run `zig build run-kusto-examples -- <scenario>` after configuring the
//! environment variables printed by `usage`.
const std = @import("std");
const core = @import("azure_core");
const common = @import("azure_kusto_common");
const data = @import("azure_kusto_data");
const ingest = @import("azure_kusto_ingest");

const default_ingest_data =
    \\{"Message":"azure-sdk-for-zig live example"}
    \\
;

pub const Scenario = enum {
    default_query,
    typed_query,
    management,
    progressive,
    streaming,
    queued,
    managed,
    status,
    all,

    fn requiresIngestion(self: Scenario) bool {
        return switch (self) {
            .streaming, .queued, .managed, .status, .all => true,
            else => false,
        };
    }
};

pub const Config = struct {
    cluster_url: []const u8,
    database: []const u8,
    target_table: ?[]const u8,
    target_mapping: ?[]const u8,
    ingest_data: []const u8,
    status_timeout_ms: u64,

    pub fn fromEnvironment(env: *const std.process.Environ.Map) !?Config {
        const cluster_url = nonEmpty(env.get("KUSTO_CLUSTER_URL")) orelse return null;
        const database = nonEmpty(env.get("KUSTO_DATABASE")) orelse return null;
        const timeout_ms = if (nonEmpty(env.get("KUSTO_STATUS_TIMEOUT_MS"))) |value|
            std.fmt.parseInt(u64, value, 10) catch return error.InvalidKustoStatusTimeout
        else
            2 * 60 * 1_000;
        if (timeout_ms == 0) return error.InvalidKustoStatusTimeout;
        return .{
            .cluster_url = cluster_url,
            .database = database,
            .target_table = nonEmpty(env.get("KUSTO_TARGET_TABLE")),
            .target_mapping = nonEmpty(env.get("KUSTO_TARGET_MAPPING")),
            .ingest_data = nonEmpty(env.get("KUSTO_INGEST_DATA")) orelse default_ingest_data,
            .status_timeout_ms = timeout_ms,
        };
    }

    pub fn ingestionTarget(self: Config) !ingest.StreamingIngestTarget {
        return .{
            .database = self.database,
            .table = self.target_table orelse return error.KustoTargetTableRequired,
        };
    }

    pub fn ingestionMapping(self: Config) ![]const u8 {
        return self.target_mapping orelse error.KustoTargetMappingRequired;
    }
};

/// Stable heap allocation is required because credentials and connections
/// borrow the transport stored in this session.
pub const Session = struct {
    allocator: std.mem.Allocator,
    transport: core.http.StdHttpTransport,
    credential: core.identity.DefaultAzureCredential,
    connection: *common.KustoConnection,

    pub fn create(
        allocator: std.mem.Allocator,
        io: std.Io,
        env: *const std.process.Environ.Map,
        cluster_url: []const u8,
    ) !*Session {
        const self = try allocator.create(Session);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.transport = core.http.StdHttpTransport.init(allocator, io);
        errdefer self.transport.deinit();
        self.credential = try core.identity.DefaultAzureCredential.init(
            allocator,
            io,
            self.transport.asTransport(),
            env,
        );
        errdefer self.credential.deinit();
        var builder = common.KustoConnectionStringBuilder.init(cluster_url);
        _ = builder.withTokenCredential(self.credential.asCredential());
        self.connection = try common.KustoConnection.init(
            allocator,
            builder.build(),
            self.transport.asTransport(),
            .{},
        );
        return self;
    }

    pub fn deinit(self: *Session) void {
        self.connection.deinit();
        self.credential.deinit();
        self.transport.deinit();
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

pub const PollSummary = union(enum) {
    status: ingest.QueuedIngestionStatus,
    stopped: ingest.StatusPollingStopReason,
};

pub fn runDefaultCredentialQuery(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !usize {
    var client = data.KustoClient.initWithConnection(session.connection, .{});
    var result = try client.executeQueryResult(
        allocator,
        config.database,
        "print SDK='azure-sdk-for-zig'",
        null,
    );
    defer result.deinit(allocator);
    return completedTableCount(&result);
}

pub fn runTypedQuery(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !usize {
    const Binding = data.kql.QueryParameters(struct {
        sdk_name: []const u8,
        minimum: i64,
    });
    var properties = try Binding.bind(allocator, .{
        .sdk_name = "azure-sdk-for-zig",
        .minimum = 1,
    });
    defer properties.deinit(allocator);
    var query = try data.kql.Builder(Binding).init(allocator);
    defer query.deinit();
    try query.literal("print SDK=");
    try query.parameter(.sdk_name);
    try query.literal(", Minimum=");
    try query.parameter(.minimum);

    var client = data.KustoClient.initWithConnection(session.connection, .{});
    var result = try client.executeQueryResult(
        allocator,
        config.database,
        query.bytes(),
        properties,
    );
    defer result.deinit(allocator);
    return completedTableCount(&result);
}

pub fn runManagement(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !usize {
    var client = data.KustoClient.initWithConnection(session.connection, .{});
    var result = try client.executeMgmtResult(
        allocator,
        config.database,
        ".show version",
        null,
    );
    defer result.deinit(allocator);
    return completedTableCount(&result);
}

pub fn runProgressiveQuery(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !usize {
    var client = data.KustoClient.initWithConnection(session.connection, .{});
    var opened = try client.executeProgressiveQuery(
        allocator,
        config.database,
        "range ExampleValue from 1 to 3 step 1",
        null,
        .{ .deadline_ms = 30_000 },
    );
    return switch (opened) {
        .ok => |stream| blk: {
            defer stream.deinit();
            var count: usize = 0;
            while (try stream.next()) |frame| {
                var owned = frame;
                const failed = progressiveFrameFailed(&owned);
                owned.deinit(allocator);
                if (failed) return error.KustoProgressiveQueryFailed;
                count += 1;
            }
            try stream.finish();
            break :blk count;
        },
        .partial => unreachable,
        .err => |*failure| {
            failure.deinit();
            return error.KustoProgressiveQueryFailed;
        },
    };
}

pub fn runStreamingIngestion(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !ingest.IngestionStatus {
    const target = try config.ingestionTarget();
    const mapping = try config.ingestionMapping();
    var client = ingest.StreamingIngestClient.initWithConnection(session.connection);
    var result = try client.ingestResult(
        allocator,
        target,
        .{ .bytes = config.ingest_data },
        .{ .format = .json, .mapping_name = mapping },
    );
    defer result.deinit(allocator);
    return switch (result) {
        .ok => |value| value.status,
        .partial => unreachable,
        .err => error.KustoStreamingIngestionFailed,
    };
}

pub fn runQueuedIngestion(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !ingest.QueuedSubmissionOutcome {
    const target = try config.ingestionTarget();
    const mapping = try config.ingestionMapping();
    var client = ingest.QueuedIngestClient.initWithConnection(session.connection);
    var result = try client.ingest(
        allocator,
        target,
        .{ .bytes = config.ingest_data },
        .{ .format = .json, .mapping_name = mapping },
    );
    defer result.deinit(allocator);
    return result.outcome;
}

pub fn runManagedIngestion(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !ingest.ManagedIngestionRoute {
    const target = try config.ingestionTarget();
    const mapping = try config.ingestionMapping();
    var client = ingest.ManagedIngestClient.initWithConnection(session.connection);
    var result = try client.ingestResult(
        allocator,
        target,
        .{ .bytes = config.ingest_data },
        .{
            .format = .json,
            .mapping_name = mapping,
            // Extent tags are Queue-only, so this deterministically
            // demonstrates managed preflight routing. Sources without
            // Queue-only properties remain eligible for safe direct fallback.
            .tags = &.{"azure-sdk-for-zig-managed-example"},
        },
    );
    defer result.deinit(allocator);
    return switch (result) {
        .ok => |*managed_result| switch (managed_result.*) {
            .streaming => .streaming,
            .queued => |submission| if (submission.outcome == .queue_accepted)
                .queued
            else
                error.KustoManagedQueueSubmissionFailed,
        },
        .partial => unreachable,
        .err => error.KustoManagedIngestionFailed,
    };
}

pub fn runStatusPolling(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !PollSummary {
    const target = try config.ingestionTarget();
    const mapping = try config.ingestionMapping();
    var client = ingest.QueuedIngestClient.initWithConnection(session.connection);
    var submission = try client.ingest(
        allocator,
        target,
        .{ .bytes = config.ingest_data },
        .{
            .format = .json,
            .mapping_name = mapping,
            .report_level = .failures_and_successes,
            .report_method = .queue_and_table,
        },
    );
    defer submission.deinit(allocator);
    if (submission.outcome != .queue_accepted)
        return error.KustoStatusSubmissionFailed;
    var tracking = submission.takeTracking() orelse
        return error.KustoStatusTrackingUnavailable;
    defer tracking.deinit();
    var polled = try tracking.poll(allocator, .{
        .poll_interval_ms = 5_000,
        .timeout_ms = config.status_timeout_ms,
    });
    defer polled.deinit(allocator);
    return switch (polled) {
        .status => |status_result| .{ .status = status_result.status },
        .stopped => |stopped| .{ .stopped = stopped.reason },
    };
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    _ = args.next();
    const scenario_text = args.next() orelse {
        usage();
        return error.KustoExampleScenarioRequired;
    };
    if (args.next() != null) {
        usage();
        return error.UnexpectedKustoExampleArgument;
    }
    const scenario = parseScenario(scenario_text) orelse {
        usage();
        return error.UnknownKustoExampleScenario;
    };
    const config = (try Config.fromEnvironment(init.environ_map)) orelse {
        environmentUsage(false);
        return error.KustoLiveEnvironmentRequired;
    };
    if (scenario.requiresIngestion() and
        (config.target_table == null or config.target_mapping == null))
    {
        environmentUsage(true);
        return error.KustoIngestionEnvironmentRequired;
    }

    const session = try Session.create(
        init.gpa,
        init.io,
        init.environ_map,
        config.cluster_url,
    );
    defer session.deinit();
    try runAndPrint(init.gpa, session, config, scenario);
}

fn completedTableCount(
    result: *data.KustoResult(data.KustoResponseDataSet),
) !usize {
    return switch (result.*) {
        .ok => |dataset| dataset.tables.len,
        .partial => error.KustoPartialResult,
        .err => error.KustoRequestFailed,
    };
}

fn progressiveFrameFailed(frame: *const data.ProgressiveFrame) bool {
    return switch (frame.payload) {
        .data_table, .table_fragment => |batch| batch.failure != null,
        .table_completion => |completion| completion.failure != null or
            completion.has_errors or completion.cancelled,
        .data_set_completion => |completion| completion.failure != null or
            completion.has_errors or completion.cancelled,
        else => false,
    };
}

fn runAndPrint(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
    scenario: Scenario,
) !void {
    switch (scenario) {
        .default_query => std.debug.print(
            "default-query: {d} result table(s)\n",
            .{try runDefaultCredentialQuery(allocator, session, config)},
        ),
        .typed_query => std.debug.print(
            "typed-query: {d} result table(s)\n",
            .{try runTypedQuery(allocator, session, config)},
        ),
        .management => std.debug.print(
            "management: {d} result table(s)\n",
            .{try runManagement(allocator, session, config)},
        ),
        .progressive => std.debug.print(
            "progressive: {d} frame(s)\n",
            .{try runProgressiveQuery(allocator, session, config)},
        ),
        .streaming => std.debug.print(
            "streaming: {s}\n",
            .{@tagName(try runStreamingIngestion(allocator, session, config))},
        ),
        .queued => std.debug.print(
            "queued: {s}\n",
            .{@tagName(try runQueuedIngestion(allocator, session, config))},
        ),
        .managed => std.debug.print(
            "managed: {s}\n",
            .{@tagName(try runManagedIngestion(allocator, session, config))},
        ),
        .status => printPollSummary(
            try runStatusPolling(allocator, session, config),
        ),
        .all => {
            inline for ([_]Scenario{
                .default_query,
                .typed_query,
                .management,
                .progressive,
                .streaming,
                .queued,
                .managed,
                .status,
            }) |item| try runAndPrint(allocator, session, config, item);
        },
    }
}

fn printPollSummary(summary: PollSummary) void {
    switch (summary) {
        .status => |status_value| std.debug.print(
            "status: terminal {s}\n",
            .{@tagName(status_value)},
        ),
        .stopped => |reason| std.debug.print(
            "status: stopped ({s})\n",
            .{@tagName(reason)},
        ),
    }
}

fn parseScenario(value: []const u8) ?Scenario {
    if (std.mem.eql(u8, value, "default-query")) return .default_query;
    if (std.mem.eql(u8, value, "typed-query")) return .typed_query;
    if (std.mem.eql(u8, value, "management")) return .management;
    if (std.mem.eql(u8, value, "progressive")) return .progressive;
    if (std.mem.eql(u8, value, "streaming")) return .streaming;
    if (std.mem.eql(u8, value, "queued")) return .queued;
    if (std.mem.eql(u8, value, "managed")) return .managed;
    if (std.mem.eql(u8, value, "status")) return .status;
    if (std.mem.eql(u8, value, "all")) return .all;
    return null;
}

fn nonEmpty(value: ?[]const u8) ?[]const u8 {
    const present = value orelse return null;
    return if (present.len == 0) null else present;
}

fn usage() void {
    std.debug.print(
        \\Usage: zig build run-kusto-examples -- <scenario>
        \\Scenarios: default-query, typed-query, management, progressive,
        \\           streaming, queued, managed, status, all
        \\
    , .{});
    environmentUsage(true);
}

fn environmentUsage(include_ingestion: bool) void {
    std.debug.print(
        \\Required environment:
        \\  KUSTO_CLUSTER_URL
        \\  KUSTO_DATABASE
        \\
    , .{});
    if (include_ingestion) {
        std.debug.print(
            \\Ingestion scenarios also require:
            \\  KUSTO_TARGET_TABLE
            \\  KUSTO_TARGET_MAPPING
            \\Optional:
            \\  KUSTO_INGEST_DATA
            \\  KUSTO_STATUS_TIMEOUT_MS
            \\
        , .{});
    }
}
