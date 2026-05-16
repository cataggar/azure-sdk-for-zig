///! Azure Kusto (Data Explorer) data client — queries and management commands.
///!
///! Provides `KustoClient` for executing KQL queries via `/v2/rest/query`
///! and management commands via `/v1/rest/mgmt`.
const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");
const kusto_common = @import("azure_kusto_common");

pub const ConnectionProperties = kusto_common.ConnectionProperties;
pub const ClientRequestProperties = kusto_common.ClientRequestProperties;

// ─────────────────── Response Types ──────────────────

pub const KustoResultColumn = struct {
    name: []const u8,
    column_type: []const u8,
};

pub const KustoResultRow = struct {
    values: []const []const u8,
    columns: []const KustoResultColumn,

    /// Get a value by column name.
    pub fn getByName(self: KustoResultRow, name: []const u8) ?[]const u8 {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col.name, name)) {
                return if (i < self.values.len) self.values[i] else null;
            }
        }
        return null;
    }
};

pub const KustoResultTable = struct {
    name: []const u8,
    columns: []const KustoResultColumn,
    rows: []const KustoResultRow,
};

pub const KustoResponseDataSet = struct {
    tables: []KustoResultTable,

    /// Get the primary result table (first table named "PrimaryResult" or index 0).
    pub fn primaryTable(self: KustoResponseDataSet) ?KustoResultTable {
        for (self.tables) |t| {
            if (std.mem.eql(u8, t.name, "PrimaryResult")) return t;
        }
        return if (self.tables.len > 0) self.tables[0] else null;
    }
};

// ─────────────────── KustoClient ─────────────────────

pub const KustoClientOptions = struct {
    application_name: []const u8 = "azure-sdk-zig",
};

/// Client for executing KQL queries and management commands against a Kusto cluster.
pub const KustoClient = struct {
    connection: ConnectionProperties,
    pipeline: core.pipeline.HttpPipeline,
    application_name: []const u8,

    pub fn init(
        connection: ConnectionProperties,
        transport: *core.http.HttpTransport,
        options: KustoClientOptions,
    ) KustoClient {
        return .{
            .connection = connection,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
            .application_name = options.application_name,
        };
    }

    /// Execute a KQL query. Uses v2 REST endpoint.
    pub fn executeQuery(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query: []const u8, properties: ?ClientRequestProperties) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v2/rest/query", .{self.connection.cluster_url});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, query, properties);
    }

    /// Execute a management command (starts with `.`). Uses v1 REST endpoint.
    pub fn executeMgmt(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, command: []const u8, properties: ?ClientRequestProperties) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{self.connection.cluster_url});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, command, properties);
    }

    /// Auto-routing: commands starting with `.` go to mgmt, others to query.
    pub fn execute(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query_or_command: []const u8) !KustoResponseDataSet {
        const trimmed = std.mem.trimStart(u8, query_or_command, " \t\n\r");
        if (trimmed.len > 0 and trimmed[0] == '.') {
            return self.executeMgmt(allocator, database, query_or_command, null);
        }
        return self.executeQuery(allocator, database, query_or_command, null);
    }

    fn executeInternal(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        url: []const u8,
        database: []const u8,
        csl: []const u8,
        properties: ?ClientRequestProperties,
    ) !KustoResponseDataSet {
        const props_json = if (properties) |p| try p.toJson(allocator) else try allocator.dupe(u8, "{}");
        defer allocator.free(props_json);

        const body = try std.fmt.allocPrint(allocator,
            \\{{"db":"{s}","csl":"{s}","properties":{s}}}
        , .{ database, csl, props_json });
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json; charset=utf-8");
        try req.setHeader("Accept", "application/json");
        try req.setHeader("x-ms-app", self.application_name);
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.KustoQueryFailed;
        }

        return parseResponseDataSet(allocator, resp.body);
    }
};

// ─────────────────── Response Parsing ────────────────

/// Wire shape of a single column descriptor inside a Kusto v2 DataTable frame.
const KustoColumnSchema = struct {
    ColumnName: []const u8,
    ColumnType: ?[]const u8 = null,
};

/// Wire shape of a single Kusto v2 frame, columns only. Rows are dynamic
/// JSON arrays of mixed-type values (string, int, bool, null, nested
/// objects), which serde cannot deserialize into a uniform Zig type, so
/// we parse `Rows` separately by walking the raw body.
const KustoFrameSchema = struct {
    FrameType: ?[]const u8 = null,
    TableName: ?[]const u8 = null,
    Columns: ?[]const KustoColumnSchema = null,
};

fn parseResponseDataSet(allocator: std.mem.Allocator, body: []const u8) !KustoResponseDataSet {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const frames = serde.json.fromSlice([]const KustoFrameSchema, arena.allocator(), body) catch
        return .{ .tables = try allocator.alloc(KustoResultTable, 0) };

    var tables = std.ArrayList(KustoResultTable).empty;
    errdefer tables.deinit(allocator);

    // Walk the raw body alongside the typed frames to grab `Rows`. We
    // assume frames appear in the body in the same order they do in the
    // typed slice.
    var body_pos: usize = 0;
    for (frames) |frame| {
        const table_name_src = frame.TableName orelse continue;
        const cols_src = frame.Columns orelse &[_]KustoColumnSchema{};

        const table_name = try allocator.dupe(u8, table_name_src);
        errdefer allocator.free(table_name);

        const cols_slice = try allocator.alloc(KustoResultColumn, cols_src.len);
        errdefer allocator.free(cols_slice);
        for (cols_src, 0..) |col, i| {
            cols_slice[i] = .{
                .name = try allocator.dupe(u8, col.ColumnName),
                .column_type = if (col.ColumnType) |ct| try allocator.dupe(u8, ct) else try allocator.dupe(u8, "string"),
            };
        }

        const rows = try extractRows(allocator, body, &body_pos, cols_slice);

        try tables.append(allocator, .{
            .name = table_name,
            .columns = cols_slice,
            .rows = rows,
        });
    }

    return .{ .tables = try tables.toOwnedSlice(allocator) };
}

/// Extract the next `"Rows":[[...],[...],...]` array starting at or after
/// `*body_pos`. Advances `*body_pos` past the consumed array. Each row's
/// values are returned as raw JSON strings (unquoted if originally
/// JSON-string typed) so the existing API surface is preserved.
fn extractRows(
    allocator: std.mem.Allocator,
    body: []const u8,
    body_pos: *usize,
    columns: []const KustoResultColumn,
) ![]KustoResultRow {
    var rows = std.ArrayList(KustoResultRow).empty;
    errdefer rows.deinit(allocator);

    const rows_idx = std.mem.findPos(u8, body, body_pos.*, "\"Rows\":[") orelse {
        return rows.toOwnedSlice(allocator);
    };
    const array_start = rows_idx + "\"Rows\":[".len;
    var depth: u32 = 1;
    var i = array_start;
    while (i < body.len and depth > 0) : (i += 1) {
        if (body[i] == '[') depth += 1;
        if (body[i] == ']') depth -= 1;
    }
    const rows_content = body[array_start .. i - 1];
    body_pos.* = i;

    var row_depth: u32 = 0;
    var row_start: ?usize = null;
    for (rows_content, 0..) |ch, ri| {
        if (ch == '[') {
            if (row_depth == 0) row_start = ri + 1;
            row_depth += 1;
        } else if (ch == ']') {
            row_depth -= 1;
            if (row_depth == 0) {
                if (row_start) |rs| {
                    const row_text = rows_content[rs..ri];
                    const values = try parseRowValues(allocator, row_text);
                    try rows.append(allocator, .{ .values = values, .columns = columns });
                }
                row_start = null;
            }
        }
    }
    return rows.toOwnedSlice(allocator);
}

fn parseRowValues(allocator: std.mem.Allocator, row_text: []const u8) ![]const []const u8 {
    var values = std.ArrayList([]const u8).empty;
    errdefer values.deinit(allocator);

    var in_string = false;
    var val_start: usize = 0;
    var i: usize = 0;

    while (i < row_text.len) : (i += 1) {
        const ch = row_text[i];
        if (ch == '"' and (i == 0 or row_text[i - 1] != '\\')) {
            in_string = !in_string;
        } else if (ch == ',' and !in_string) {
            const raw = std.mem.trim(u8, row_text[val_start..i], " \t");
            try values.append(allocator, try unquote(allocator, raw));
            val_start = i + 1;
        }
    }
    if (val_start <= row_text.len) {
        const raw = std.mem.trim(u8, row_text[val_start..], " \t");
        if (raw.len > 0) {
            try values.append(allocator, try unquote(allocator, raw));
        }
    }

    return values.toOwnedSlice(allocator);
}

fn unquote(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    if (raw.len >= 2 and raw[0] == '"' and raw[raw.len - 1] == '"') {
        return allocator.dupe(u8, raw[1 .. raw.len - 1]);
    }
    return allocator.dupe(u8, raw);
}

// ─────────────────────── Tests ───────────────────────

test "KustoClient executeQuery" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[{"FrameType":"DataTable","TableName":"PrimaryResult","Columns":[{"ColumnName":"Count","ColumnType":"long"}],"Rows":[[42]]}]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    const result = try client.executeQuery(allocator, "TestDB", "StormEvents | count", null);
    defer {
        for (result.tables) |t| {
            allocator.free(t.name);
            for (t.columns) |c| {
                allocator.free(c.name);
                allocator.free(c.column_type);
            }
            allocator.free(t.columns);
            for (t.rows) |r| {
                for (r.values) |v| allocator.free(v);
                allocator.free(r.values);
            }
            allocator.free(t.rows);
        }
        allocator.free(result.tables);
    }

    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v2/rest/query") != null);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);

    const primary = result.primaryTable().?;
    try std.testing.expectEqualStrings("PrimaryResult", primary.name);
    try std.testing.expectEqual(@as(usize, 1), primary.columns.len);
    try std.testing.expectEqualStrings("Count", primary.columns[0].name);
    try std.testing.expectEqual(@as(usize, 1), primary.rows.len);
    try std.testing.expectEqualStrings("42", primary.rows[0].values[0]);
}

test "KustoClient executeMgmt" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[{"FrameType":"DataTable","TableName":"Table_0","Columns":[{"ColumnName":"DatabaseName","ColumnType":"string"}],"Rows":[["TestDB"]]}]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    const result = try client.executeMgmt(allocator, "TestDB", ".show databases", null);
    defer {
        for (result.tables) |t| {
            allocator.free(t.name);
            for (t.columns) |c| {
                allocator.free(c.name);
                allocator.free(c.column_type);
            }
            allocator.free(t.columns);
            for (t.rows) |r| {
                for (r.values) |v| allocator.free(v);
                allocator.free(r.values);
            }
            allocator.free(t.rows);
        }
        allocator.free(result.tables);
    }

    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/mgmt") != null);
    const table = result.tables[0];
    try std.testing.expectEqualStrings("TestDB", table.rows[0].values[0]);
}

test "KustoClient execute auto-routes to mgmt" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    _ = try client.execute(allocator, "db", ".show databases");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/mgmt") != null);
}

test "KustoClient execute auto-routes to query" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    _ = try client.execute(allocator, "db", "StormEvents | count");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v2/rest/query") != null);
}

test "KustoClient query failure returns error" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid query"}}
    );
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    const result = client.executeQuery(allocator, "db", "INVALID", null);
    try std.testing.expectError(error.KustoQueryFailed, result);
}

test "KustoResultRow getByName" {
    const cols = [_]KustoResultColumn{
        .{ .name = "Name", .column_type = "string" },
        .{ .name = "Age", .column_type = "long" },
    };
    const vals = [_][]const u8{ "Alice", "30" };
    const row = KustoResultRow{ .values = &vals, .columns = &cols };
    try std.testing.expectEqualStrings("Alice", row.getByName("Name").?);
    try std.testing.expectEqualStrings("30", row.getByName("Age").?);
    try std.testing.expect(row.getByName("Missing") == null);
}
