const std = @import("std");
const core = @import("azure_sdk_core");
const auth = @import("auth.zig");
const connection_string = @import("connection_string.zig");
const entity = @import("entity.zig");
const options = @import("options.zig");
const pipeline = @import("pipeline.zig");
const protocol_client = @import("protocol_client.zig");
const request = @import("request.zig");
const sas_types = @import("sas.zig");

/// Client for Azure Table Storage REST operations.
///
/// A direct token client owns stable pipeline state. A client returned by
/// `TableServiceClient.getTableClient` borrows that state and must be
/// deinitialized before its parent. The credential, transport, and caller
/// policy objects are always borrowed. Calls sharing pipeline state must be
/// serialized because the token cache and standard transport are mutable.
pub const TableClient = struct {
    allocator: std.mem.Allocator,
    protocol: protocol_client.ProtocolClient,
    table_name: []u8,
    pipeline_state: *pipeline.PipelineState,
    owns_pipeline_state: bool,
    owned_credential: ?*auth.SharedKeyCredential = null,

    pub const Options = options.TableClientOptions;

    pub fn initWithToken(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableClient {
        try request.validateTableName(table_name);
        try request.validateTokenEndpoint(endpoint);
        const state = try pipeline.PipelineState.create(
            allocator,
            credential,
            transport,
            init_options,
        );
        errdefer state.deinit();
        return initWithState(
            allocator,
            endpoint,
            table_name,
            init_options.api_version,
            state,
            true,
        );
    }

    /// Creates a SharedKeyLite-authenticated Table client. The credential is
    /// borrowed and must outlive the client.
    pub fn initWithSharedKey(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        credential: *auth.SharedKeyCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableClient {
        try request.validateTableName(table_name);
        try request.validateSharedKeyEndpoint(endpoint);
        const state = try pipeline.PipelineState.createSharedKey(
            allocator,
            credential,
            transport,
            init_options,
        );
        errdefer state.deinit();
        return initWithState(allocator, endpoint, table_name, init_options.api_version, state, true);
    }

    /// Creates a credential-free client from a complete, pre-signed SAS URL.
    /// The raw query is retained verbatim and no Authorization policy exists.
    pub fn initWithSasUrl(
        allocator: std.mem.Allocator,
        complete_sas_url: []const u8,
        table_name: []const u8,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableClient {
        try request.validateTableName(table_name);
        try request.validateSasEndpoint(complete_sas_url);
        const state = try pipeline.PipelineState.createNoAuth(allocator, transport, init_options);
        errdefer state.deinit();
        const service_endpoint = try serviceEndpointFromSasUrl(
            allocator,
            complete_sas_url,
            table_name,
        );
        defer allocator.free(service_endpoint);
        return initWithState(allocator, service_endpoint, table_name, init_options.api_version, state, true);
    }

    /// Parses a Storage or Azurite connection string and constructs the
    /// matching Shared Key or credential-free SAS client.
    pub fn initFromConnectionString(
        allocator: std.mem.Allocator,
        value: []const u8,
        table_name: []const u8,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableClient {
        var parsed = try connection_string.parse(allocator, value);
        defer parsed.deinit();
        if (parsed.account_key) |key| {
            const credential = try allocator.create(auth.SharedKeyCredential);
            errdefer allocator.destroy(credential);
            credential.* = try auth.SharedKeyCredential.init(allocator, parsed.account_name, key);
            errdefer credential.deinit();
            var result = try initWithSharedKey(allocator, parsed.endpoint, table_name, credential, transport, init_options);
            result.owned_credential = credential;
            return result;
        }
        return initWithSasUrl(allocator, parsed.endpoint, table_name, transport, init_options);
    }

    /// Internal constructor for service-derived clients.
    pub fn initBorrowed(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        api_version: []const u8,
        state: *pipeline.PipelineState,
    ) !TableClient {
        try request.validateTableName(table_name);
        return initWithState(
            allocator,
            endpoint,
            table_name,
            api_version,
            state,
            false,
        );
    }

    fn initWithState(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        api_version: []const u8,
        state: *pipeline.PipelineState,
        owns_state: bool,
    ) !TableClient {
        var protocol = try protocol_client.ProtocolClient.init(
            allocator,
            endpoint,
            state.pipeline,
            .{
                .api_version = api_version,
                .endpoint_query_is_sas = state.usesSas(),
            },
        );
        errdefer protocol.deinit();
        return .{
            .allocator = allocator,
            .protocol = protocol,
            .table_name = try allocator.dupe(u8, table_name),
            .pipeline_state = state,
            .owns_pipeline_state = owns_state,
            .owned_credential = null,
        };
    }

    pub fn deinit(self: *TableClient) void {
        self.protocol.deinit();
        self.allocator.free(self.table_name);
        if (self.owns_pipeline_state) self.pipeline_state.deinit();
        if (self.owned_credential) |credential| {
            credential.deinit();
            self.allocator.destroy(credential);
        }
        self.* = undefined;
    }

    /// Formats a query-redacted endpoint so SAS signatures never enter logs.
    pub fn format(self: TableClient, writer: anytype) !void {
        try writer.print("TableClient({s})", .{self.protocol.endpoint.base_url});
    }

    /// Generates a full table SAS URL. This is available only on a Shared Key
    /// client; the returned URL is secret and must be released by the caller.
    pub fn getTableSasUrl(
        self: *TableClient,
        allocator: std.mem.Allocator,
        signature_values: sas_types.TableSignatureValues,
    ) ![]u8 {
        const credential = self.pipeline_state.sharedKeyCredential() orelse
            return error.SasRequiresSharedKeyCredential;
        var values = signature_values;
        if (values.tableName.len == 0) {
            values.tableName = self.table_name;
        } else if (!std.ascii.eqlIgnoreCase(values.tableName, self.table_name)) {
            return error.SasTableNameMismatch;
        }
        var parameters = try values.sign(allocator, credential);
        defer parameters.deinit();
        const table_url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.protocol.endpoint.base_url, self.table_name },
        );
        defer allocator.free(table_url);
        return parameters.appendToUrl(allocator, table_url);
    }

    /// GET `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`.
    pub fn getEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try request.buildEntityUrl(
            allocator,
            self.protocol.endpoint.base_url,
            self.table_name,
            partition_key,
            row_key,
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json;odata=nometadata");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        return self.protocol.send(&req, .{});
    }

    /// POST `{endpoint}/{tableName}` with JSON entity body.
    pub fn createEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        table_entity: entity.TableEntity,
    ) !core.http.Response {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{
                self.protocol.endpoint.base_url,
                self.table_name,
            },
        );
        defer allocator.free(url);

        var body_buf: std.ArrayList(u8) = .empty;
        defer body_buf.deinit(allocator);
        const writer = body_buf.writer(allocator);
        try writer.writeAll("{\"PartitionKey\":\"");
        try request.writeJsonEscaped(writer, table_entity.partition_key);
        try writer.writeAll("\",\"RowKey\":\"");
        try request.writeJsonEscaped(writer, table_entity.row_key);
        try writer.writeByte('"');
        var it = table_entity.properties.iterator();
        while (it.next()) |entry| {
            try writer.writeAll(",\"");
            try request.writeJsonEscaped(writer, entry.key_ptr.*);
            try writer.writeAll("\":\"");
            try request.writeJsonEscaped(writer, entry.value_ptr.*);
            try writer.writeByte('"');
        }
        try writer.writeAll("}");

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json;odata=nometadata");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        req.body = body_buf.items;
        return self.protocol.send(&req, .{});
    }

    /// DELETE `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`.
    pub fn deleteEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try request.buildEntityUrl(
            allocator,
            self.protocol.endpoint.base_url,
            self.table_name,
            partition_key,
            row_key,
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try req.setHeader("If-Match", "*");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        return self.protocol.send(&req, .{});
    }
};

/// No-credential table clients accept both an account SAS URL and the full
/// table SAS URL returned by `getTableSasUrl`.
fn serviceEndpointFromSasUrl(
    allocator: std.mem.Allocator,
    complete_sas_url: []const u8,
    table_name: []const u8,
) ![]u8 {
    var normalized = try request.NormalizedEndpoint.init(allocator, complete_sas_url);
    defer normalized.deinit();
    const signed_table_name = try tableNameFromSasQuery(allocator, normalized.raw_query);
    defer if (signed_table_name) |value| allocator.free(value);

    var base = normalized.base_url;
    if (signed_table_name) |value| {
        if (!std.ascii.eqlIgnoreCase(value, table_name))
            return error.SasTableNameMismatch;
        const slash = std.mem.lastIndexOfScalar(u8, normalized.base_url, '/') orelse
            return error.InvalidTableSasUrl;
        if (!std.ascii.eqlIgnoreCase(normalized.base_url[slash + 1 ..], table_name))
            return error.InvalidTableSasUrl;
        base = normalized.base_url[0..slash];
    }
    return std.fmt.allocPrint(
        allocator,
        "{s}?{s}",
        .{ base, normalized.raw_query },
    );
}

fn tableNameFromSasQuery(
    allocator: std.mem.Allocator,
    raw_query: []const u8,
) !?[]u8 {
    var result: ?[]u8 = null;
    errdefer if (result) |value| allocator.free(value);
    var parameters = std.mem.splitScalar(u8, raw_query, '&');
    while (parameters.next()) |parameter| {
        const equal = std.mem.indexOfScalar(u8, parameter, '=') orelse parameter.len;
        if (!try queryComponentEqlIgnoreCase(parameter[0..equal], "tn")) continue;
        if (result != null) return error.DuplicateSasTableName;
        const raw_value = if (equal < parameter.len) parameter[equal + 1 ..] else "";
        const value = try decodeQueryComponent(allocator, raw_value);
        errdefer allocator.free(value);
        request.validateTableName(value) catch return error.InvalidSasTableName;
        result = value;
    }
    return result;
}

fn queryComponentEqlIgnoreCase(raw: []const u8, expected: []const u8) !bool {
    var raw_index: usize = 0;
    var expected_index: usize = 0;
    while (raw_index < raw.len) : (expected_index += 1) {
        const byte = try decodeQueryByte(raw, &raw_index);
        if (expected_index >= expected.len or
            std.ascii.toLower(byte) != std.ascii.toLower(expected[expected_index]))
        {
            return false;
        }
    }
    return expected_index == expected.len;
}

fn decodeQueryComponent(
    allocator: std.mem.Allocator,
    raw: []const u8,
) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var index: usize = 0;
    while (index < raw.len)
        try decoded.append(allocator, try decodeQueryByte(raw, &index));
    return decoded.toOwnedSlice(allocator);
}

fn decodeQueryByte(raw: []const u8, index: *usize) !u8 {
    const byte = raw[index.*];
    if (byte == '+') {
        index.* += 1;
        return ' ';
    }
    if (byte != '%') {
        index.* += 1;
        return byte;
    }
    if (index.* + 2 >= raw.len) return error.InvalidSasQueryEncoding;
    const high = queryHexDigit(raw[index.* + 1]) orelse
        return error.InvalidSasQueryEncoding;
    const low = queryHexDigit(raw[index.* + 2]) orelse
        return error.InvalidSasQueryEncoding;
    index.* += 3;
    return high * 16 + low;
}

fn queryHexDigit(byte: u8) ?u8 {
    if (byte >= '0' and byte <= '9') return byte - '0';
    if (byte >= 'a' and byte <= 'f') return byte - 'a' + 10;
    if (byte >= 'A' and byte <= 'F') return byte - 'A' + 10;
    return null;
}

const TestCredential = struct {
    calls: usize = 0,
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },

    fn asCredential(self: *TestCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        self.calls += 1;
        return .{ .token = "table-token", .expires_on = std.math.maxInt(i64) };
    }
};

fn moveClient(client: TableClient) TableClient {
    return client;
}

test "token client survives moves and applies all client options" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    var table_client = moveClient(try TableClient.initWithToken(
        allocator,
        "https://myaccount.table.core.windows.net",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{
            .api_version = "2020-test",
            .telemetry = .{ .application_id = "my-app/1.0" },
            .client_request_id = "fixed-request-id",
            .operation_timeout_ms = 4321,
        },
    ));
    defer table_client.deinit();
    const stable_address = table_client.pipeline_state;
    table_client = moveClient(table_client);
    try std.testing.expect(table_client.pipeline_state == stable_address);

    var response = try table_client.getEntity(allocator, "pk1", "rk1");
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(mock.last_headers.get("Authorization") != null);
    try std.testing.expectEqualStrings(
        "fixed-request-id",
        mock.last_headers.get("x-ms-client-request-id").?,
    );
    try std.testing.expectEqualStrings(
        "my-app/1.0 azsdk-zig-data-tables/0.1.0",
        mock.last_headers.get("User-Agent").?,
    );
    try std.testing.expectEqualStrings(
        "2020-test",
        mock.last_headers.get("x-ms-version").?,
    );
    try std.testing.expectEqual(@as(?u64, 4321), mock.last_operation_timeout_ms);
}

fn testAllocationFailures(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};
    var table_client = try TableClient.initWithToken(
        allocator,
        "https://myaccount.table.core.windows.net",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{
            .telemetry = .{ .application_id = "allocation-test" },
            .client_request_id = "allocation-request-id",
        },
    );
    table_client.deinit();
}

test "token client construction failure paths are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testAllocationFailures,
        .{},
    );
}

test "token client rejects HTTP before credential and transport use" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    try std.testing.expectError(
        error.TokenAuthenticationRequiresHttps,
        TableClient.initWithToken(
            allocator,
            "http://127.0.0.1:10002/devstoreaccount1",
            "MyTable",
            credential.asCredential(),
            mock.asTransport(),
            .{},
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "token client accepts HTTPS custom private endpoint" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    var table_client = try TableClient.initWithToken(
        allocator,
        "HTTPS://tables.internal.example:8443/private/path",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{},
    );
    defer table_client.deinit();

    try std.testing.expectEqualStrings(
        "HTTPS://tables.internal.example:8443/private/path",
        table_client.protocol.endpoint.base_url,
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "Shared Key and SAS constructors have isolated authentication behavior" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = try auth.SharedKeyCredential.init(
        allocator,
        "account",
        "YWNjb3VudC1rZXk=",
    );
    defer credential.deinit();

    var shared = try TableClient.initWithSharedKey(
        allocator,
        "https://account.table.core.windows.net",
        "Table123",
        &credential,
        mock.asTransport(),
        .{},
    );
    defer shared.deinit();
    var shared_response = try shared.getEntity(allocator, "pk", "rk");
    shared_response.deinit();
    try std.testing.expect(std.mem.startsWith(
        u8,
        mock.last_headers.get("Authorization").?,
        "SharedKeyLite account:",
    ));
    try std.testing.expect(mock.last_headers.get("x-ms-date") != null);

    var sas = try TableClient.initWithSasUrl(
        allocator,
        "https://account.table.core.windows.net?sv=1%2F2&sig=a+b%3D&sp=r",
        "Table123",
        mock.asTransport(),
        .{},
    );
    defer sas.deinit();
    var sas_response = try sas.getEntity(allocator, "pk", "rk");
    sas_response.deinit();
    try std.testing.expect(mock.last_headers.get("Authorization") == null);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "sv=1%2F2&sig=a+b%3D&sp=r") != null);
}

fn testSasOperationAllocationFailures(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var sas = try TableClient.initWithSasUrl(
        allocator,
        "https://account.table.core.windows.net/Table123?sv=1%2F2&sig=allocation+SECRET%3D&sp=r&tn=Table123",
        "Table123",
        mock.asTransport(),
        .{},
    );
    defer sas.deinit();
    var response = try sas.getEntity(allocator, "pk", "rk");
    response.deinit();
}

test "SAS operation allocation failure paths are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testSasOperationAllocationFailures,
        .{},
    );
}

test "table SAS URL is exact and full URL initializes a credential-free client" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = try auth.SharedKeyCredential.init(
        allocator,
        "fakeaccount",
        "ZmFrZS1rZXk=",
    );
    defer credential.deinit();
    var shared = try TableClient.initWithSharedKey(
        allocator,
        "https://fakeaccount.table.core.windows.net",
        "People",
        &credential,
        transport.asTransport(),
        .{},
    );
    defer shared.deinit();
    const sas_url = try shared.getTableSasUrl(allocator, .{
        .accessPolicy = .{ .adHoc = .{
            .permissions = .{ .read = true },
            .startTime = .fromUnixSeconds(1_699_455_845),
            .expiryTime = .fromUnixSeconds(1_699_459_445),
        } },
        .startPartitionKey = "A",
        .startRowKey = "0",
        .endPartitionKey = "Z",
        .endRowKey = "9",
    });
    defer allocator.free(sas_url);
    try std.testing.expectEqualStrings(
        "https://fakeaccount.table.core.windows.net/People?epk=Z&erk=9&se=2023-11-08T16%3A04%3A05Z&sig=de3WKX%2BV7n%2BdT7OWKCwFJ%2BNDUwN7F6My1aWUKN2M%2B6Q%3D&sp=r&spk=A&spr=https&srk=0&st=2023-11-08T15%3A04%3A05Z&sv=2019-02-02&tn=people",
        sas_url,
    );

    var anonymous = try TableClient.initWithSasUrl(
        allocator,
        sas_url,
        "People",
        transport.asTransport(),
        .{},
    );
    defer anonymous.deinit();
    try std.testing.expectEqualStrings(
        "https://fakeaccount.table.core.windows.net",
        anonymous.protocol.endpoint.base_url,
    );
    try std.testing.expectError(
        error.SasRequiresSharedKeyCredential,
        anonymous.getTableSasUrl(allocator, .{
            .accessPolicy = .{ .adHoc = .{
                .permissions = .{ .read = true },
                .expiryTime = .fromUnixSeconds(1_699_459_445),
            } },
        }),
    );
    var formatted: std.Io.Writer.Allocating = .init(allocator);
    defer formatted.deinit();
    try formatted.writer.print("{f}", .{anonymous});
    try std.testing.expectEqualStrings(
        "TableClient(https://fakeaccount.table.core.windows.net)",
        formatted.written(),
    );
    var response = try anonymous.getEntity(allocator, "A", "0");
    response.deinit();
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expect(std.mem.startsWith(
        u8,
        transport.last_url.?,
        "https://fakeaccount.table.core.windows.net/People(PartitionKey='A',RowKey='0')?",
    ));
    try std.testing.expect(std.mem.endsWith(
        u8,
        transport.last_url.?,
        sas_url[(std.mem.indexOfScalar(u8, sas_url, '?').? + 1)..],
    ));
}

test "account SAS preserves a custom account path equal to the table name" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    const account_sas =
        "http://127.0.0.1:10002/People?sv=2019-02-02&ss=t&srt=o&sig=opaque%2Bvalue%3D";
    var table = try TableClient.initWithSasUrl(
        allocator,
        account_sas,
        "People",
        transport.asTransport(),
        .{},
    );
    defer table.deinit();
    try std.testing.expectEqualStrings(
        "http://127.0.0.1:10002/People",
        table.protocol.endpoint.base_url,
    );
    try std.testing.expectEqualStrings(
        "sv=2019-02-02&ss=t&srt=o&sig=opaque%2Bvalue%3D",
        table.protocol.endpoint.raw_query,
    );
    var response = try table.getEntity(allocator, "p", "r");
    response.deinit();
    try std.testing.expect(std.mem.startsWith(
        u8,
        transport.last_url.?,
        "http://127.0.0.1:10002/People/People(PartitionKey='p',RowKey='r')?",
    ));
}

test "table SAS scope uses decoded case-insensitive tn without changing query bytes" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    const table_sas =
        "http://127.0.0.1:10002/People/People?sv=2019-02-02&%54%6E=%50eople&sig=opaque%2Bvalue%3D";
    var table = try TableClient.initWithSasUrl(
        allocator,
        table_sas,
        "People",
        transport.asTransport(),
        .{},
    );
    defer table.deinit();
    try std.testing.expectEqualStrings(
        "http://127.0.0.1:10002/People",
        table.protocol.endpoint.base_url,
    );
    try std.testing.expectEqualStrings(
        "sv=2019-02-02&%54%6E=%50eople&sig=opaque%2Bvalue%3D",
        table.protocol.endpoint.raw_query,
    );
    var response = try table.getEntity(allocator, "p", "r");
    response.deinit();
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.last_url.?,
        "?sv=2019-02-02&%54%6E=%50eople&sig=opaque%2Bvalue%3D",
    ) != null);
}

test "table SAS scope rejects mismatched duplicate and malformed tn" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    try std.testing.expectError(
        error.SasTableNameMismatch,
        TableClient.initWithSasUrl(
            allocator,
            "https://account.table.core.windows.net/Other?sv=1&tn=Other&sig=x",
            "People",
            transport.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.DuplicateSasTableName,
        TableClient.initWithSasUrl(
            allocator,
            "https://account.table.core.windows.net/People?tn=People&TN=%50eople&sig=x",
            "People",
            transport.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.InvalidTableSasUrl,
        TableClient.initWithSasUrl(
            allocator,
            "https://account.table.core.windows.net?tn=People&sig=x",
            "People",
            transport.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.InvalidSasQueryEncoding,
        TableClient.initWithSasUrl(
            allocator,
            "https://account.table.core.windows.net/People?t%ZZ=People&sig=x",
            "People",
            transport.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.InvalidSasQueryEncoding,
        TableClient.initWithSasUrl(
            allocator,
            "https://account.table.core.windows.net/People?tn=Peop%ZZle&sig=x",
            "People",
            transport.asTransport(),
            .{},
        ),
    );
}
