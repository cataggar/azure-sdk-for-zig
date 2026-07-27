const std = @import("std");
const core = @import("azure_sdk_core");
const auth = @import("auth.zig");
const connection_string = @import("connection_string.zig");
const client = @import("client.zig");
const options = @import("options.zig");
const pipeline = @import("pipeline.zig");
const protocol_client = @import("protocol_client.zig");
const request = @import("request.zig");
const sas = @import("sas.zig");
const pager = @import("pager.zig");
const responses = @import("responses.zig");
const service_models = @import("service_models.zig");

/// Client for Azure Table Service operations (list/create/delete tables).
///
/// The credential, transport, and configured policy objects are borrowed and
/// must outlive the client. The client owns its endpoint, API version, policy
/// pointer list, and bearer-token cache. Calls must be serialized because the
/// token cache and standard transport are mutable and not thread-safe.
pub const TableServiceClient = struct {
    allocator: std.mem.Allocator,
    protocol: protocol_client.ProtocolClient,
    pipeline_state: *pipeline.PipelineState,
    owned_credential: ?*auth.SharedKeyCredential = null,

    pub const Options = options.TableServiceClientOptions;

    pub fn initWithToken(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableServiceClient {
        try request.validateTokenEndpoint(endpoint);
        const state = try pipeline.PipelineState.create(
            allocator,
            credential,
            transport,
            init_options,
        );
        errdefer state.deinit();
        const protocol = try protocol_client.ProtocolClient.init(
            allocator,
            endpoint,
            state.pipeline,
            .{
                .api_version = init_options.api_version,
                .endpoint_query_is_sas = state.usesSas(),
            },
        );
        return .{
            .allocator = allocator,
            .protocol = protocol,
            .pipeline_state = state,
        };
    }

    /// Creates a SharedKeyLite-authenticated service client. The credential is
    /// borrowed and must outlive the client.
    pub fn initWithSharedKey(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        credential: *auth.SharedKeyCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableServiceClient {
        try request.validateSharedKeyEndpoint(endpoint);
        const state = try pipeline.PipelineState.createSharedKey(allocator, credential, transport, init_options);
        errdefer state.deinit();
        const protocol = try protocol_client.ProtocolClient.init(
            allocator,
            endpoint,
            state.pipeline,
            .{
                .api_version = init_options.api_version,
                .endpoint_query_is_sas = state.usesSas(),
            },
        );
        return .{ .allocator = allocator, .protocol = protocol, .pipeline_state = state };
    }

    /// Creates a credential-free service client from a complete SAS URL.
    pub fn initWithSasUrl(
        allocator: std.mem.Allocator,
        complete_sas_url: []const u8,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableServiceClient {
        try request.validateSasEndpoint(complete_sas_url);
        const state = try pipeline.PipelineState.createNoAuth(allocator, transport, init_options);
        errdefer state.deinit();
        const protocol = try protocol_client.ProtocolClient.init(
            allocator,
            complete_sas_url,
            state.pipeline,
            .{
                .api_version = init_options.api_version,
                .endpoint_query_is_sas = state.usesSas(),
            },
        );
        return .{ .allocator = allocator, .protocol = protocol, .pipeline_state = state };
    }

    /// Parses a Storage or Azurite connection string before constructing the
    /// pipeline. Account-key credentials are owned by the returned client.
    pub fn initFromConnectionString(
        allocator: std.mem.Allocator,
        value: []const u8,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableServiceClient {
        var parsed = try connection_string.parse(allocator, value);
        defer parsed.deinit();
        if (parsed.account_key) |key| {
            const credential = try allocator.create(auth.SharedKeyCredential);
            errdefer allocator.destroy(credential);
            credential.* = try auth.SharedKeyCredential.init(allocator, parsed.account_name, key);
            errdefer credential.deinit();
            var result = try initWithSharedKey(allocator, parsed.endpoint, credential, transport, init_options);
            result.owned_credential = credential;
            return result;
        }
        return initWithSasUrl(allocator, parsed.endpoint, transport, init_options);
    }

    /// Creates a table client that shares this service client's pipeline,
    /// bearer-token cache, and transport. The returned client must be
    /// deinitialized before, and may not outlive, this service client.
    pub fn getTableClient(
        self: *TableServiceClient,
        table_name: []const u8,
    ) !client.TableClient {
        if (self.protocol.endpoint.has_query) {
            const endpoint = try std.fmt.allocPrint(
                self.allocator,
                "{s}?{s}",
                .{
                    self.protocol.endpoint.base_url,
                    self.protocol.endpoint.raw_query,
                },
            );
            defer self.allocator.free(endpoint);
            return client.TableClient.initBorrowed(
                self.allocator,
                endpoint,
                table_name,
                self.protocol.api_version,
                self.pipeline_state,
            );
        }
        return client.TableClient.initBorrowed(
            self.allocator,
            self.protocol.endpoint.base_url,
            table_name,
            self.protocol.api_version,
            self.pipeline_state,
        );
    }

    pub fn deinit(self: *TableServiceClient) void {
        self.protocol.deinit();
        self.pipeline_state.deinit();
        if (self.owned_credential) |credential| {
            credential.deinit();
            self.allocator.destroy(credential);
        }
        self.* = undefined;
    }

    /// Formats a query-redacted endpoint so SAS signatures never enter logs.
    pub fn format(self: TableServiceClient, writer: anytype) !void {
        try writer.print("TableServiceClient({s})", .{self.protocol.endpoint.base_url});
    }

    /// Generates a full Table-service account SAS URL. This is available only
    /// on a Shared Key client; the returned URL is secret and caller-owned.
    pub fn getAccountSasUrl(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        signature_values: sas.AccountSignatureValues,
    ) ![]u8 {
        const credential = self.pipeline_state.sharedKeyCredential() orelse
            return error.SasRequiresSharedKeyCredential;
        var parameters = try signature_values.sign(allocator, credential);
        defer parameters.deinit();
        const service_url = try std.fmt.allocPrint(
            allocator,
            "{s}/",
            .{self.protocol.endpoint.base_url},
        );
        defer allocator.free(service_url);
        return parameters.appendToUrl(allocator, service_url);
    }
    pub fn createTableResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        create_options: options.CreateTableOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.CreateTableResponse)) {
        return self.protocol.createTable(allocator, table_name, create_options);
    }

    pub fn createTable(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        create_options: options.CreateTableOptions,
    ) !responses.SdkResponse(protocol_client.CreateTableResponse) {
        return responses.unwrapCreateTable(
            responses.SdkResponse(protocol_client.CreateTableResponse),
            try self.createTableResult(allocator, table_name, create_options),
        );
    }

    pub fn deleteTableResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        delete_options: options.DeleteTableOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.DeleteTableResponse)) {
        return self.protocol.deleteTable(allocator, table_name, delete_options);
    }

    pub fn deleteTable(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        delete_options: options.DeleteTableOptions,
    ) !responses.SdkResponse(protocol_client.DeleteTableResponse) {
        return responses.unwrapDeleteTable(
            responses.SdkResponse(protocol_client.DeleteTableResponse),
            try self.deleteTableResult(allocator, table_name, delete_options),
        );
    }

    pub fn setServicePropertiesResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        properties: service_models.ServiceProperties,
        set_options: options.SetServicePropertiesOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.SetServicePropertiesResponse)) {
        return self.protocol.setServiceProperties(allocator, properties, set_options.protocol);
    }

    pub fn setServiceProperties(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        properties: service_models.ServiceProperties,
        set_options: options.SetServicePropertiesOptions,
    ) !responses.SdkResponse(protocol_client.SetServicePropertiesResponse) {
        return responses.unwrapSetServiceProperties(
            responses.SdkResponse(protocol_client.SetServicePropertiesResponse),
            try self.setServicePropertiesResult(allocator, properties, set_options),
        );
    }

    /// Compatibility spelling for the Table service's service-properties API.
    pub fn setPropertiesResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        properties: service_models.ServiceProperties,
        set_options: options.SetServicePropertiesOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.SetServicePropertiesResponse)) {
        return self.setServicePropertiesResult(allocator, properties, set_options);
    }

    /// Compatibility spelling for the Table service's service-properties API.
    pub fn setProperties(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        properties: service_models.ServiceProperties,
        set_options: options.SetServicePropertiesOptions,
    ) !responses.SdkResponse(protocol_client.SetServicePropertiesResponse) {
        return self.setServiceProperties(allocator, properties, set_options);
    }

    pub fn getServicePropertiesResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetServicePropertiesOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.GetServicePropertiesResponse)) {
        return self.protocol.getServiceProperties(allocator, get_options.protocol);
    }

    pub fn getServiceProperties(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetServicePropertiesOptions,
    ) !responses.SdkResponse(protocol_client.GetServicePropertiesResponse) {
        return responses.unwrapGetServiceProperties(
            responses.SdkResponse(protocol_client.GetServicePropertiesResponse),
            try self.getServicePropertiesResult(allocator, get_options),
        );
    }

    /// Compatibility spelling for the Table service's service-properties API.
    pub fn getPropertiesResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetServicePropertiesOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.GetServicePropertiesResponse)) {
        return self.getServicePropertiesResult(allocator, get_options);
    }

    /// Compatibility spelling for the Table service's service-properties API.
    pub fn getProperties(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetServicePropertiesOptions,
    ) !responses.SdkResponse(protocol_client.GetServicePropertiesResponse) {
        return self.getServiceProperties(allocator, get_options);
    }

    pub fn getStatisticsResult(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetStatisticsOptions,
    ) !responses.TableResult(responses.SdkResponse(protocol_client.GetStatisticsResponse)) {
        return self.protocol.getStatistics(allocator, get_options.protocol);
    }

    pub fn getStatistics(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        get_options: options.GetStatisticsOptions,
    ) !responses.SdkResponse(protocol_client.GetStatisticsResponse) {
        return responses.unwrapGetStatistics(
            responses.SdkResponse(protocol_client.GetStatisticsResponse),
            try self.getStatisticsResult(allocator, get_options),
        );
    }

    pub fn listTables(
        self: *TableServiceClient,
        allocator: std.mem.Allocator,
        list_options: options.ListTablesOptions,
    ) !pager.TablePager {
        return pager.TablePager.init(allocator, &self.protocol, list_options);
    }
};

const BodyCapturePolicy = struct {
    allocator: std.mem.Allocator,
    body: ?[]u8 = null,
    policy: core.pipeline.HttpPolicy = .{ .processFn = &process },

    fn deinit(self: *BodyCapturePolicy) void {
        if (self.body) |body| self.allocator.free(body);
        self.* = undefined;
    }

    fn process(
        policy: *core.pipeline.HttpPolicy,
        req: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) anyerror!core.http.Response {
        const self: *BodyCapturePolicy = @alignCast(@fieldParentPtr("policy", policy));
        const response = if (next.len == 0) try transport.send(req) else try next[0].process(req, next[1..], transport);
        if (self.body) |body| self.allocator.free(body);
        self.body = if (req.body) |body| try self.allocator.dupe(u8, body) else null;
        return response;
    }
};

const CountingCredential = struct {
    calls: usize = 0,
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },

    fn asCredential(self: *CountingCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        context: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *CountingCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        if (context.scopes.len != 1 or
            !std.mem.eql(u8, context.scopes[0], @import("auth.zig").storage_scope))
        {
            return error.UnexpectedTokenScope;
        }
        self.calls += 1;
        return .{ .token = "shared-token", .expires_on = std.math.maxInt(i64) };
    }
};

const MovedServicePager = struct {
    service: TableServiceClient,
    table_pager: pager.TablePager,
};

fn moveServiceWithPager(
    service: TableServiceClient,
    allocator: std.mem.Allocator,
) !MovedServicePager {
    var relocated = service;
    const table_pager = try relocated.listTables(allocator, .{});
    return .{ .service = relocated, .table_pager = table_pager };
}

test "derived clients share token cache and transport and borrow pipeline state" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = CountingCredential{};

    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();
    const shared_state = service.pipeline_state;

    var first = try service.getTableClient("FirstTable");
    try std.testing.expect(first.pipeline_state == shared_state);
    var first_response = try first.getEntity(allocator, "pk", "rk");
    first_response.deinit();
    first.deinit();

    var second = try service.getTableClient("SecondTable");
    defer second.deinit();
    var second_response = try second.getEntity(allocator, "pk", "rk");
    second_response.deinit();

    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}

test "table pager survives a service client move across continuation pages" {
    const allocator = std.testing.allocator;
    const pages = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"value\":[{\"TableName\":\"First\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-ms-continuation-NextTableName", .value = "Second" },
            },
        },
        .{
            .status = 200,
            .body = "{\"value\":[{\"TableName\":\"Second\"}]}",
            .headers = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
                .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
                .{ .name = "Content-Type", .value = "application/json" },
            },
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &pages);
    var credential = CountingCredential{};
    var source = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    var moved = try moveServiceWithPager(source, allocator);
    source = undefined;
    defer moved.service.deinit();
    defer moved.table_pager.deinit();

    const first = try moved.table_pager.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqualStrings("First", switch (first.?.value) {
        .status_200 => |value| value.body.value.?[0].table_name.?,
    });
    const second = try moved.table_pager.next();
    try std.testing.expect(second != null);
    try std.testing.expectEqualStrings("Second", switch (second.?.value) {
        .status_200 => |value| value.body.value.?[0].table_name.?,
    });
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
}

test "token service client rejects HTTP before credential and transport use" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = CountingCredential{};

    try std.testing.expectError(
        error.TokenAuthenticationRequiresHttps,
        TableServiceClient.initWithToken(
            allocator,
            "http://tables.private.example:10002/account",
            credential.asCredential(),
            transport.asTransport(),
            .{},
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "token service client accepts HTTPS custom private endpoint" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = CountingCredential{};

    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://tables.private.example:8443/account/path/",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();

    try std.testing.expectEqualStrings(
        "https://tables.private.example:8443/account/path",
        service.protocol.endpoint.base_url,
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "account SAS URL is exact and works with a credential-free service client" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = try auth.SharedKeyCredential.init(
        allocator,
        "fakeaccount",
        "ZmFrZS1rZXk=",
    );
    defer credential.deinit();
    var shared = try TableServiceClient.initWithSharedKey(
        allocator,
        "https://fakeaccount.table.core.windows.net",
        &credential,
        transport.asTransport(),
        .{},
    );
    defer shared.deinit();

    const sas_url = try shared.getAccountSasUrl(allocator, .{
        .permissions = .{ .read = true, .list = true },
        .resourceTypes = .{ .service = true, .container = true },
        .startTime = .fromUnixSeconds(1_699_455_845),
        .expiryTime = .fromUnixSeconds(1_699_459_445),
    });
    defer allocator.free(sas_url);
    try std.testing.expectEqualStrings(
        "https://fakeaccount.table.core.windows.net/?se=2023-11-08T16%3A04%3A05Z&sig=%2BUBePkRnknhwbw%2FT4HuUIu0YAlJlq7mt6Lrfwpestjo%3D&sp=rl&spr=https&srt=sc&ss=t&st=2023-11-08T15%3A04%3A05Z&sv=2019-02-02",
        sas_url,
    );

    var anonymous = try TableServiceClient.initWithSasUrl(
        allocator,
        sas_url,
        transport.asTransport(),
        .{},
    );
    defer anonymous.deinit();
    try std.testing.expectError(
        error.SasRequiresSharedKeyCredential,
        anonymous.getAccountSasUrl(allocator, .{
            .permissions = .{ .read = true },
            .resourceTypes = .{ .service = true },
            .expiryTime = .fromUnixSeconds(1_699_459_445),
        }),
    );
    var table = try anonymous.getTableClient("People");
    defer table.deinit();
    var response = try table.getEntity(allocator, "p", "r");
    response.deinit();
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    const signed_query = sas_url[(std.mem.indexOfScalar(u8, sas_url, '?').? + 1)..];
    const sent_query = transport.last_url.?[(std.mem.indexOfScalar(u8, transport.last_url.?, '?').? + 1)..];
    try std.testing.expectEqualStrings(signed_query, sent_query);
}

test "table lifecycle result variants preserve generated responses and service errors" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 204, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
        .{ .name = "x-ms-request-id", .value = "create-id" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{ .client_request_id = "lifecycle-request" },
    );
    defer service.deinit();

    var created = try service.createTable(allocator, "Table123", .{
        .protocol = .{ .metadata = .full_metadata, .timeout = 13 },
    });
    defer created.deinit();
    try std.testing.expectEqual(@as(u16, 204), created.status);
    try std.testing.expectEqualStrings("create-id", created.headers.getFirst("x-ms-request-id").?);
    try std.testing.expect(std.mem.startsWith(u8, transport.last_headers.get("Authorization").?, "Bearer "));
    try std.testing.expectEqualStrings("lifecycle-request", transport.last_headers.get("x-ms-client-request-id").?);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables?$format=application%2Fjson%3Bodata%3Dfullmetadata&timeout=13",
        transport.last_url.?,
    );

    transport.response_status = 409;
    transport.response_body = "{\"odata.error\":{\"code\":\"TableAlreadyExists\",\"message\":{\"value\":\"exists\"}}}";
    transport.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "x-ms-request-id", .value = "already-exists" },
    };
    var duplicate = try service.createTableResult(allocator, "Table123", .{});
    defer duplicate.deinit(allocator);
    switch (duplicate) {
        .failure => |failure| {
            try std.testing.expectEqualStrings("TableAlreadyExists", failure.code);
            try std.testing.expectEqual(@as(u16, 409), failure.status);
            try std.testing.expectEqualStrings("already-exists", failure.request_id.?);
        },
        .success => return error.TestUnexpectedResult,
    }
}

test "table lifecycle validates names before transport and table clients are convenient" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 204, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();

    try std.testing.expectError(
        error.InvalidTableName,
        service.deleteTableResult(allocator, "not-valid", .{}),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);

    var table_client = try service.getTableClient("Table123");
    defer table_client.deinit();
    var deleted = try table_client.deleteTable(allocator, .{
        .protocol = .{ .timeout = 11 },
    });
    defer deleted.deinit();
    try std.testing.expectEqual(@as(u16, 204), deleted.status);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Tables('Table123')?timeout=11",
        transport.last_url.?,
    );
}

test "table lifecycle uses Shared Key and SAS pipeline authentication" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 204, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
    };
    var shared_credential = try auth.SharedKeyCredential.init(
        allocator,
        "account",
        "YWNjb3VudC1rZXk=",
    );
    defer shared_credential.deinit();
    var shared = try TableServiceClient.initWithSharedKey(
        allocator,
        "https://account.table.core.windows.net",
        &shared_credential,
        transport.asTransport(),
        .{},
    );
    defer shared.deinit();
    var created = try shared.createTable(allocator, "Table123", .{});
    created.deinit();
    try std.testing.expect(std.mem.startsWith(
        u8,
        transport.last_headers.get("Authorization").?,
        "SharedKeyLite account:",
    ));

    var sas_client = try TableServiceClient.initWithSasUrl(
        allocator,
        "https://account.table.core.windows.net?sv=1%2F2&sig=secret%3D&sp=r",
        transport.asTransport(),
        .{},
    );
    defer sas_client.deinit();
    var deleted = try sas_client.deleteTable(allocator, "Table123", .{});
    deleted.deinit();
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        transport.last_url.?,
        "sv=1%2F2&sig=secret%3D&sp=r",
    ) != null);
}

test "table lifecycle retains all documented table service failure codes" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { status: u16, code: []const u8 }{
        .{ .status = 409, .code = "TableAlreadyExists" },
        .{ .status = 409, .code = "TableBeingDeleted" },
        .{ .status = 404, .code = "TableNotFound" },
    };
    for (cases) |case| {
        var transport = core.http.MockTransport.init(
            allocator,
            case.status,
            "{\"odata.error\":{\"code\":\"TablePlaceholder\",\"message\":{\"value\":\"failed\"}}}",
        );
        defer transport.deinit();
        transport.response_body = try std.fmt.allocPrint(
            allocator,
            "{{\"odata.error\":{{\"code\":\"{s}\",\"message\":{{\"value\":\"failed\"}}}}}}",
            .{case.code},
        );
        defer allocator.free(transport.response_body);
        transport.response_headers_list = &.{
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "x-ms-request-id", .value = "failure-id" },
        };
        var credential = CountingCredential{};
        var service = try TableServiceClient.initWithToken(
            allocator,
            "https://account.table.core.windows.net",
            credential.asCredential(),
            transport.asTransport(),
            .{},
        );
        defer service.deinit();

        var result = try service.createTableResult(allocator, "Table123", .{});
        defer result.deinit(allocator);
        switch (result) {
            .failure => |failure| {
                try std.testing.expectEqualStrings(case.code, failure.code);
                try std.testing.expectEqual(case.status, failure.status);
                try std.testing.expectEqualStrings("failure-id", failure.request_id.?);
            },
            .success => return error.TestUnexpectedResult,
        }
    }
}

fn testLifecycleAllocationFailures(allocator: std.mem.Allocator) !void {
    var transport = core.http.MockTransport.init(allocator, 204, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{ .retry = .{ .max_retries = 0 } },
    );
    defer service.deinit();
    var result = try service.createTableResult(allocator, "Table123", .{});
    result.deinit(allocator);
}

test "table lifecycle result allocation failures are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testLifecycleAllocationFailures,
        .{},
    );
}

test "service properties use generated XML and preserve response metadata" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 202, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "x-ms-request-id", .value = "set-properties-id" },
    };
    var capture = BodyCapturePolicy{ .allocator = allocator };
    defer capture.deinit();
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{ .policies = &.{&capture.policy} },
    );
    defer service.deinit();

    var set_response = try service.setServiceProperties(allocator, .{
        .logging = .{
            .version = "1.0",
            .delete = true,
            .read = false,
            .write = true,
            .retention_policy = .{ .enabled = true, .days = 7 },
        },
        .hour_metrics = .{
            .version = "1.0",
            .enabled = true,
            .include_apis = true,
            .retention_policy = .{ .enabled = false },
        },
        .cors = .{ .items = &.{.{
            .allowed_origins = "https://example.test",
            .allowed_methods = "GET,PUT",
            .allowed_headers = "x-ms-meta-*",
            .exposed_headers = "x-ms-request-id",
            .max_age_in_seconds = 60,
        }} },
    }, .{ .protocol = .{ .client_request_id = "set-client-id", .timeout = 30 } });
    defer set_response.deinit();
    try std.testing.expectEqual(@as(u16, 202), set_response.status);
    try std.testing.expectEqualStrings("set-properties-id", set_response.headers.getFirst("x-ms-request-id").?);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net?restype=service&comp=properties&timeout=30",
        transport.last_url.?,
    );
    try std.testing.expectEqualStrings("set-client-id", transport.last_headers.get("x-ms-client-request-id").?);
    try std.testing.expect(std.mem.startsWith(u8, transport.last_headers.get("Authorization").?, "Bearer "));
    try std.testing.expectEqualStrings(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties><Logging><Version>1.0</Version><Delete>true</Delete><Read>false</Read><Write>true</Write><RetentionPolicy><Enabled>true</Enabled><Days>7</Days></RetentionPolicy></Logging><HourMetrics><Version>1.0</Version><Enabled>true</Enabled><IncludeAPIs>true</IncludeAPIs><RetentionPolicy><Enabled>false</Enabled></RetentionPolicy></HourMetrics><Cors><CorsRule><AllowedOrigins>https://example.test</AllowedOrigins><AllowedMethods>GET,PUT</AllowedMethods><AllowedHeaders>x-ms-meta-*</AllowedHeaders><ExposedHeaders>x-ms-request-id</ExposedHeaders><MaxAgeInSeconds>60</MaxAgeInSeconds></CorsRule></Cors></StorageServiceProperties>",
        capture.body.?,
    );

    transport.response_status = 200;
    transport.response_body =
        "<StorageServiceProperties><Logging><Version>1.0</Version><Delete>true</Delete><Read>false</Read><Write>true</Write><RetentionPolicy><Enabled>true</Enabled><Days>7</Days></RetentionPolicy></Logging><HourMetrics><Version>1.0</Version><Enabled>false</Enabled><IncludeAPIs>false</IncludeAPIs><RetentionPolicy><Enabled>false</Enabled><Days>7</Days></RetentionPolicy></HourMetrics><Cors><CorsRule><AllowedOrigins>https://example.test</AllowedOrigins><AllowedMethods>GET</AllowedMethods><AllowedHeaders>*</AllowedHeaders><ExposedHeaders>x-ms-request-id</ExposedHeaders><MaxAgeInSeconds>60</MaxAgeInSeconds></CorsRule></Cors></StorageServiceProperties>";
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "x-ms-request-id", .value = "get-properties-id" },
        .{ .name = "Content-Type", .value = "application/xml" },
    };
    var get_response = try service.getServiceProperties(allocator, .{});
    defer get_response.deinit();
    try std.testing.expectEqual(@as(u16, 200), get_response.status);
    try std.testing.expectEqualStrings("get-properties-id", get_response.headers.getFirst("x-ms-request-id").?);
    switch (get_response.value) {
        .status_200 => |response| {
            try std.testing.expectEqual(@as(usize, 1), response.body.cors.?.items.len);
            try std.testing.expectEqualStrings("https://example.test", response.body.cors.?.items[0].allowed_origins);
            try std.testing.expectEqual(@as(?i32, 7), response.body.logging.?.retention_policy.days);
            try std.testing.expectEqual(false, response.body.hour_metrics.?.enabled);
            try std.testing.expectEqual(@as(?bool, false), response.body.hour_metrics.?.include_apis);
            try std.testing.expectEqual(@as(?i32, 7), response.body.hour_metrics.?.retention_policy.?.days);

            transport.response_status = 202;
            transport.response_body = "";
            transport.response_headers_list = &.{
                .{ .name = "x-ms-version", .value = "2019-02-02" },
            };
            var roundtrip = try service.setServiceProperties(allocator, response.body, .{});
            defer roundtrip.deinit();
            try std.testing.expectEqualStrings(
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties><Logging><Version>1.0</Version><Delete>true</Delete><Read>false</Read><Write>true</Write><RetentionPolicy><Enabled>true</Enabled><Days>7</Days></RetentionPolicy></Logging><HourMetrics><Version>1.0</Version><Enabled>false</Enabled><RetentionPolicy><Enabled>false</Enabled><Days>7</Days></RetentionPolicy></HourMetrics><Cors><CorsRule><AllowedOrigins>https://example.test</AllowedOrigins><AllowedMethods>GET</AllowedMethods><AllowedHeaders>*</AllowedHeaders><ExposedHeaders>x-ms-request-id</ExposedHeaders><MaxAgeInSeconds>60</MaxAgeInSeconds></CorsRule></Cors></StorageServiceProperties>",
                capture.body.?,
            );
        },
    }
}

test "service administration validates before transport and returns structured failures" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 202, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();

    try std.testing.expectError(
        error.InvalidRetentionDays,
        service.setServiceProperties(allocator, .{
            .minute_metrics = .{
                .version = "1.0",
                .enabled = true,
                .include_apis = false,
                .retention_policy = .{ .enabled = true, .days = 0 },
            },
        }, .{}),
    );
    try std.testing.expectError(
        error.InvalidTimeout,
        service.getServiceProperties(allocator, .{ .protocol = .{ .timeout = 0 } }),
    );
    try std.testing.expectError(error.StatisticsRequireSecondaryEndpoint, service.getStatistics(allocator, .{}));
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);

    transport.response_status = 400;
    transport.response_body = "<Error><Code>InvalidXmlDocument</Code><Message>bad XML</Message></Error>";
    transport.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/xml" },
        .{ .name = "x-ms-request-id", .value = "bad-properties-id" },
    };
    var result = try service.getServicePropertiesResult(allocator, .{});
    defer result.deinit(allocator);
    switch (result) {
        .failure => |failure| {
            try std.testing.expectEqual(@as(u16, 400), failure.status);
            try std.testing.expectEqualStrings("InvalidXmlDocument", failure.code);
            try std.testing.expectEqualStrings("bad-properties-id", failure.request_id.?);
        },
        .success => return error.TestUnexpectedResult,
    }
}

test "secondary statistics preserve unknown replication status and UTC time" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(
        allocator,
        200,
        "<StorageServiceStats><GeoReplication><Status>future-status</Status><LastSyncTime>Wed, 23 Oct 2013 22:05:54 GMT</LastSyncTime></GeoReplication></StorageServiceStats>",
    );
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 18:32:16 GMT" },
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "x-ms-request-id", .value = "stats-id" },
        .{ .name = "Content-Type", .value = "application/xml" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account-secondary.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();

    var response = try service.getStatistics(allocator, .{ .protocol = .{ .timeout = 5 } });
    defer response.deinit();
    try std.testing.expectEqualStrings(
        "https://account-secondary.table.core.windows.net?restype=service&comp=stats&timeout=5",
        transport.last_url.?,
    );
    try std.testing.expectEqualStrings("stats-id", response.headers.getFirst("x-ms-request-id").?);
    switch (response.value) {
        .status_200 => |stats| switch (stats.body.geo_replication.?.status.?) {
            .unrecognized => |value| try std.testing.expectEqualStrings("future-status", value),
            else => return error.TestUnexpectedResult,
        },
    }

    transport.response_body =
        "<StorageServiceStats><GeoReplication><Status>bootstrap</Status><LastSyncTime></LastSyncTime></GeoReplication></StorageServiceStats>";
    var unavailable = try service.getStatistics(allocator, .{});
    defer unavailable.deinit();
    switch (unavailable.value) {
        .status_200 => |stats| {
            try std.testing.expectEqual(@as(usize, 0), stats.body.geo_replication.?.last_sync_time.?.len);
        },
    }
}

test "malformed service properties XML is released on decode failure" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "<StorageServiceProperties><Logging>");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Content-Type", .value = "application/xml" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{},
    );
    defer service.deinit();

    if (service.getServiceProperties(allocator, .{})) |value| {
        var response = value;
        response.deinit();
        return error.TestUnexpectedResult;
    } else |_| {}
}

fn testServiceAdminAllocationFailures(allocator: std.mem.Allocator) !void {
    var transport = core.http.MockTransport.init(allocator, 202, "");
    defer transport.deinit();
    transport.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
    };
    var credential = CountingCredential{};
    var service = try TableServiceClient.initWithToken(
        allocator,
        "https://account.table.core.windows.net",
        credential.asCredential(),
        transport.asTransport(),
        .{ .retry = .{ .max_retries = 0 } },
    );
    defer service.deinit();
    var response = try service.setServiceProperties(allocator, .{
        .logging = .{
            .version = "1.0",
            .delete = false,
            .read = true,
            .write = false,
            .retention_policy = .{ .enabled = false },
        },
    }, .{});
    response.deinit();
}

test "service administration allocation failures are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testServiceAdminAllocationFailures,
        .{},
    );
}
