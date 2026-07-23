//! Opt-in query and management examples for Azure Data Explorer (Kusto).
const std = @import("std");
const core = @import("azure_sdk_core");
const common = @import("azure_sdk_kusto_common");
const data = @import("azure_sdk_kusto_data");

pub const Scenario = enum {
    default_query,
    typed_query,
    management,
    progressive,
    all,
};

pub const Config = struct {
    cluster_url: []const u8,
    database: []const u8,

    pub fn fromEnvironment(env: *const std.process.Environ.Map) ?Config {
        return .{
            .cluster_url = nonEmpty(env.get("KUSTO_CLUSTER_URL")) orelse return null,
            .database = nonEmpty(env.get("KUSTO_DATABASE")) orelse return null,
        };
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

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    _ = args.next();
    const scenario_text = args.next() orelse {
        usage();
        return error.KustoDataExampleScenarioRequired;
    };
    if (args.next() != null) {
        usage();
        return error.UnexpectedKustoDataExampleArgument;
    }
    const scenario = parseScenario(scenario_text) orelse {
        usage();
        return error.UnknownKustoDataExampleScenario;
    };
    const config = Config.fromEnvironment(init.environ_map) orelse {
        environmentUsage();
        return error.KustoLiveEnvironmentRequired;
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
        .all => inline for ([_]Scenario{
            .default_query,
            .typed_query,
            .management,
            .progressive,
        }) |item| try runAndPrint(allocator, session, config, item),
    }
}

fn parseScenario(value: []const u8) ?Scenario {
    if (std.mem.eql(u8, value, "default-query")) return .default_query;
    if (std.mem.eql(u8, value, "typed-query")) return .typed_query;
    if (std.mem.eql(u8, value, "management")) return .management;
    if (std.mem.eql(u8, value, "progressive")) return .progressive;
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
        \\Scenarios: default-query, typed-query, management, progressive, all
        \\
    , .{});
    environmentUsage();
}

fn environmentUsage() void {
    std.debug.print(
        \\Required environment:
        \\  KUSTO_CLUSTER_URL
        \\  KUSTO_DATABASE
        \\
    , .{});
}
