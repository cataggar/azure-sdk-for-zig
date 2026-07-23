//! Opt-in ingestion and status examples for Azure Data Explorer (Kusto).
const std = @import("std");
const core = @import("azure_sdk_core");
const common = @import("azure_sdk_kusto_common");
const ingest = @import("azure_sdk_kusto_ingest");

const default_ingest_data =
    \\{"Message":"azure-sdk-for-zig live example"}
    \\
;

pub const Scenario = enum {
    streaming,
    queued,
    managed,
    status,
    all,
};

pub const Config = struct {
    cluster_url: []const u8,
    database: []const u8,
    target_table: []const u8,
    target_mapping: []const u8,
    ingest_data: []const u8,
    status_timeout_ms: u64,

    pub fn fromEnvironment(env: *const std.process.Environ.Map) !?Config {
        const cluster_url = nonEmpty(env.get("KUSTO_CLUSTER_URL")) orelse return null;
        const database = nonEmpty(env.get("KUSTO_DATABASE")) orelse return null;
        const target_table = nonEmpty(env.get("KUSTO_TARGET_TABLE")) orelse return null;
        const target_mapping = nonEmpty(env.get("KUSTO_TARGET_MAPPING")) orelse return null;
        const timeout_ms = if (nonEmpty(env.get("KUSTO_STATUS_TIMEOUT_MS"))) |value|
            std.fmt.parseInt(u64, value, 10) catch return error.InvalidKustoStatusTimeout
        else
            2 * 60 * 1_000;
        if (timeout_ms == 0) return error.InvalidKustoStatusTimeout;
        return .{
            .cluster_url = cluster_url,
            .database = database,
            .target_table = target_table,
            .target_mapping = target_mapping,
            .ingest_data = nonEmpty(env.get("KUSTO_INGEST_DATA")) orelse default_ingest_data,
            .status_timeout_ms = timeout_ms,
        };
    }

    pub fn ingestionTarget(self: Config) ingest.StreamingIngestTarget {
        return .{ .database = self.database, .table = self.target_table };
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

pub fn runStreamingIngestion(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !ingest.IngestionStatus {
    var client = ingest.StreamingIngestClient.initWithConnection(session.connection);
    var result = try client.ingestResult(
        allocator,
        config.ingestionTarget(),
        .{ .bytes = config.ingest_data },
        .{ .format = .json, .mapping_name = config.target_mapping },
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
    var client = ingest.QueuedIngestClient.initWithConnection(session.connection);
    var result = try client.ingest(
        allocator,
        config.ingestionTarget(),
        .{ .bytes = config.ingest_data },
        .{ .format = .json, .mapping_name = config.target_mapping },
    );
    defer result.deinit(allocator);
    return result.outcome;
}

pub fn runManagedIngestion(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
) !ingest.ManagedIngestionRoute {
    var client = ingest.ManagedIngestClient.initWithConnection(session.connection);
    var result = try client.ingestResult(
        allocator,
        config.ingestionTarget(),
        .{ .bytes = config.ingest_data },
        .{
            .format = .json,
            .mapping_name = config.target_mapping,
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
    var client = ingest.QueuedIngestClient.initWithConnection(session.connection);
    var submission = try client.ingest(
        allocator,
        config.ingestionTarget(),
        .{ .bytes = config.ingest_data },
        .{
            .format = .json,
            .mapping_name = config.target_mapping,
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
        return error.KustoIngestExampleScenarioRequired;
    };
    if (args.next() != null) {
        usage();
        return error.UnexpectedKustoIngestExampleArgument;
    }
    const scenario = parseScenario(scenario_text) orelse {
        usage();
        return error.UnknownKustoIngestExampleScenario;
    };
    const config = (try Config.fromEnvironment(init.environ_map)) orelse {
        environmentUsage();
        return error.KustoIngestionEnvironmentRequired;
    };
    const session = try Session.create(
        init.gpa,
        init.io,
        init.environ_map,
        config.cluster_url,
    );
    defer session.deinit();
    try runAndPrint(init.gpa, session, config, scenario);
}

fn runAndPrint(
    allocator: std.mem.Allocator,
    session: *Session,
    config: Config,
    scenario: Scenario,
) !void {
    switch (scenario) {
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
        .all => inline for ([_]Scenario{
            .streaming,
            .queued,
            .managed,
            .status,
        }) |item| try runAndPrint(allocator, session, config, item),
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
        \\Usage: zig build run-example -- <scenario>
        \\Scenarios: streaming, queued, managed, status, all
        \\
    , .{});
    environmentUsage();
}

fn environmentUsage() void {
    std.debug.print(
        \\Required environment:
        \\  KUSTO_CLUSTER_URL
        \\  KUSTO_DATABASE
        \\  KUSTO_TARGET_TABLE
        \\  KUSTO_TARGET_MAPPING
        \\Optional:
        \\  KUSTO_INGEST_DATA
        \\  KUSTO_STATUS_TIMEOUT_MS
        \\
    , .{});
}
