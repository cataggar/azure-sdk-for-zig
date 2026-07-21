///! Shared types for Azure Kusto (Data Explorer) client libraries.
///!
///! Provides `KustoConnectionStringBuilder` for connection configuration
///! and common types used by both the data and ingest clients.
const std = @import("std");
const core = @import("azure_core");

// ─────────────────────── Enums ───────────────────────

/// Supported data formats for ingestion.
pub const DataFormat = enum {
    csv,
    tsv,
    json,
    multi_json,
    avro,
    parquet,
    orc,
    scsv,
    sohsv,
    psv,

    pub fn toString(self: DataFormat) []const u8 {
        return switch (self) {
            .csv => "Csv",
            .tsv => "Tsv",
            .json => "Json",
            .multi_json => "MultiJson",
            .avro => "Avro",
            .parquet => "Parquet",
            .orc => "Orc",
            .scsv => "SCsv",
            .sohsv => "SOHsv",
            .psv => "PSV",
        };
    }
};

// ─────────────── Connection Properties ───────────────

/// Resolved connection properties for a Kusto cluster.
pub const ConnectionProperties = struct {
    cluster_url: []const u8,
    credential: ?*core.credentials.TokenCredential = null,
    authority_id: ?[]const u8 = null,
    application_client_id: ?[]const u8 = null,
    application_key: ?[]const u8 = null,

    /// Renders only the cluster endpoint and authentication mode.
    ///
    /// Credential and application-key material is intentionally omitted.
    pub fn format(self: ConnectionProperties, writer: anytype) !void {
        try writer.print(
            "ConnectionProperties(endpoint={s}, auth_mode={s})",
            .{ self.cluster_url, connectionAuthMode(self) },
        );
    }

    /// Get the data management (ingest) URL by prepending `ingest-` to the hostname.
    pub fn getIngestUrl(self: ConnectionProperties, allocator: std.mem.Allocator) ![]u8 {
        // https://cluster.region.kusto.windows.net → https://ingest-cluster.region.kusto.windows.net
        if (std.mem.find(u8, self.cluster_url, "://")) |scheme_end| {
            const scheme = self.cluster_url[0 .. scheme_end + 3];
            const host = self.cluster_url[scheme_end + 3 ..];
            return std.fmt.allocPrint(allocator, "{s}ingest-{s}", .{ scheme, host });
        }
        return std.fmt.allocPrint(allocator, "https://ingest-{s}", .{self.cluster_url});
    }
};

/// Fluent builder for Kusto cluster connections.
///
/// Follows the KustoConnectionStringBuilder (KCSB) pattern from Go/Python/Node SDKs.
pub const KustoConnectionStringBuilder = struct {
    cluster_url: []const u8,
    credential: ?*core.credentials.TokenCredential = null,
    authority_id: ?[]const u8 = null,
    application_client_id: ?[]const u8 = null,
    application_key: ?[]const u8 = null,

    pub fn init(cluster_url: []const u8) KustoConnectionStringBuilder {
        return .{ .cluster_url = cluster_url };
    }

    /// Authenticate with Azure AD application key (client secret).
    ///
    /// Deprecated: use `withTokenCredential`; app-key authentication is not
    /// supported by `KustoConnection`.
    pub fn withAadAppKey(self: *KustoConnectionStringBuilder, client_id: []const u8, client_secret: []const u8, authority_id: []const u8) *KustoConnectionStringBuilder {
        self.application_client_id = client_id;
        self.application_key = client_secret;
        self.authority_id = authority_id;
        return self;
    }

    /// Authenticate with an explicit TokenCredential (e.g. DefaultAzureCredential).
    pub fn withTokenCredential(self: *KustoConnectionStringBuilder, credential: *core.credentials.TokenCredential) *KustoConnectionStringBuilder {
        self.credential = credential;
        return self;
    }

    /// Build the resolved connection properties.
    pub fn build(self: KustoConnectionStringBuilder) ConnectionProperties {
        return .{
            .cluster_url = self.cluster_url,
            .credential = self.credential,
            .authority_id = self.authority_id,
            .application_client_id = self.application_client_id,
            .application_key = self.application_key,
        };
    }

    /// Renders only the cluster endpoint and authentication mode.
    ///
    /// Credential and application-key material is intentionally omitted.
    pub fn format(self: KustoConnectionStringBuilder, writer: anytype) !void {
        try writer.print(
            "KustoConnectionStringBuilder(endpoint={s}, auth_mode={s})",
            .{ self.cluster_url, connectionAuthMode(self.build()) },
        );
    }
};

fn connectionAuthMode(properties: ConnectionProperties) []const u8 {
    if (properties.application_key != null or
        properties.application_client_id != null or
        properties.authority_id != null)
    {
        return "legacy_app_key";
    }
    return if (properties.credential != null) "token_credential" else "none";
}

// ─────────────── Shared Connection ───────────────

pub const KustoRetryOptions = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 60_000,
};

pub const KustoConnectionOptions = struct {
    token_scope: []const u8 = "https://kusto.kusto.windows.net/.default",
    user_agent: []const u8 = "azsdk-zig-kusto/0.1.0",
    retry: KustoRetryOptions = .{},
};

/// Allocator-owned, stable HTTP connection shared by Kusto service clients.
///
/// The credential and transport are borrowed and must outlive this connection.
/// This connection must outlive all derived clients and their in-flight
/// requests. `HttpTransport` and the authentication cache are not thread-safe,
/// so callers must externally serialize use of this connection and its derived
/// clients.
pub const KustoConnection = struct {
    allocator: std.mem.Allocator,
    cluster_url: []u8,
    token_scope: []u8,
    user_agent: []u8,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,
    scopes: [1][]const u8,
    request_id: core.pipeline.RequestIdPolicy,
    telemetry: core.pipeline.TelemetryPolicy,
    retry: core.pipeline.RetryPolicy,
    auth: core.pipeline.BearerTokenAuthPolicy,
    decompression: core.decompression.DecompressionPolicy,
    policies: [5]*core.pipeline.HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,

    /// This type has mutable policy state and requires external serialization.
    pub const supports_concurrent_use = false;

    pub fn init(
        allocator: std.mem.Allocator,
        properties: ConnectionProperties,
        transport: *core.http.HttpTransport,
        options: KustoConnectionOptions,
    ) !*KustoConnection {
        if (properties.application_key != null or
            properties.application_client_id != null or
            properties.authority_id != null)
        {
            return error.AadAppKeyAuthenticationUnsupported;
        }
        const credential = properties.credential orelse return error.KustoCredentialRequired;

        const self = try allocator.create(KustoConnection);
        errdefer allocator.destroy(self);

        const normalized_cluster_url = std.mem.trimEnd(u8, properties.cluster_url, "/");
        const owned_cluster_url = try allocator.dupe(u8, normalized_cluster_url);
        errdefer allocator.free(owned_cluster_url);
        const owned_token_scope = try allocator.dupe(u8, options.token_scope);
        errdefer allocator.free(owned_token_scope);
        const owned_user_agent = try allocator.dupe(u8, options.user_agent);
        errdefer allocator.free(owned_user_agent);

        self.allocator = allocator;
        self.cluster_url = owned_cluster_url;
        self.token_scope = owned_token_scope;
        self.user_agent = owned_user_agent;
        self.credential = credential;
        self.transport = transport;
        self.scopes = .{self.token_scope};
        self.request_id = core.pipeline.RequestIdPolicy.init();
        self.telemetry = core.pipeline.TelemetryPolicy.init(self.user_agent);
        self.retry = core.pipeline.RetryPolicy.init();
        self.retry.max_retries = options.retry.max_retries;
        self.retry.initial_delay_ms = options.retry.initial_delay_ms;
        self.retry.max_delay_ms = options.retry.max_delay_ms;
        self.auth = core.pipeline.BearerTokenAuthPolicy.init(
            allocator,
            credential,
            &self.scopes,
        );
        self.decompression = core.decompression.DecompressionPolicy.init();
        self.policies = .{
            self.request_id.asPolicy(),
            self.telemetry.asPolicy(),
            self.retry.asPolicy(),
            self.auth.asPolicy(),
            self.decompression.asPolicy(),
        };
        self.pipeline = .{
            .policies = &self.policies,
            .transport_impl = transport,
        };
        return self;
    }

    pub fn deinit(self: *KustoConnection) void {
        const allocator = self.allocator;
        self.auth.deinit();
        allocator.free(self.cluster_url);
        allocator.free(self.token_scope);
        allocator.free(self.user_agent);
        allocator.destroy(self);
    }

    pub fn send(self: *KustoConnection, request: *core.http.Request) !core.http.Response {
        return self.pipeline.send(request);
    }

    pub fn clusterUrl(self: *const KustoConnection) []const u8 {
        return self.cluster_url;
    }

    /// Renders only the cluster endpoint and authentication mode.
    ///
    /// Credential, token, and legacy app-key material is intentionally omitted.
    pub fn format(self: *const KustoConnection, writer: anytype) !void {
        try writer.print(
            "KustoConnection(endpoint={s}, auth_mode=token_credential)",
            .{self.cluster_url},
        );
    }
};

// ─────────────── Request Properties ─────────────────

/// Client request properties for query/management commands.
pub const ClientRequestProperties = struct {
    client_request_id: ?[]const u8 = null,
    application: ?[]const u8 = null,
    server_timeout_ms: ?i64 = null,

    /// Serialize to JSON for the "properties" field in the REST body.
    pub fn toJson(self: ClientRequestProperties, allocator: std.mem.Allocator) ![]u8 {
        if (self.server_timeout_ms) |timeout| {
            const minutes = @divTrunc(timeout, 60000);
            return std.fmt.allocPrint(allocator, "{{\"Options\":{{\"servertimeout\":\"{d}m\"}}}}", .{minutes});
        }
        return allocator.dupe(u8, "{}");
    }
};

/// Ingestion properties for data upload.
pub const IngestionProperties = struct {
    database: []const u8,
    table: []const u8,
    format: DataFormat = .csv,
    mapping_name: ?[]const u8 = null,
    flush_immediately: bool = false,
    drop_by_tags: ?[]const []const u8 = null,
};

// ─────────────────────── Tests ───────────────────────

const TestTokenCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },
    call_count: u32 = 0,
    last_scope: ?[]const u8 = null,

    fn asCredential(self: *TestTokenCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestTokenCredential = @alignCast(@fieldParentPtr("credential", credential));
        self.call_count += 1;
        self.last_scope = request_context.scopes[0];
        return .{
            .token = "connection-test-token",
            .expires_on = std.math.maxInt(i64),
        };
    }
};

test "KustoConnectionStringBuilder build" {
    var kcsb = KustoConnectionStringBuilder.init("https://mycluster.eastus.kusto.windows.net");
    _ = kcsb.withAadAppKey("app-id", "secret", "tenant-id");
    const props = kcsb.build();
    try std.testing.expectEqualStrings("https://mycluster.eastus.kusto.windows.net", props.cluster_url);
    try std.testing.expectEqualStrings("app-id", props.application_client_id.?);
    try std.testing.expectEqualStrings("secret", props.application_key.?);
    try std.testing.expectEqualStrings("tenant-id", props.authority_id.?);
}

test "KustoConnection owns normalized configuration" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var credential = TestTokenCredential{};
    var cluster_url = "https://cluster.kusto.windows.net///".*;
    var token_scope = "scope-value".*;
    var user_agent = "user-agent-value".*;

    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = cluster_url[0..],
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{
            .token_scope = token_scope[0..],
            .user_agent = user_agent[0..],
        },
    );
    defer connection.deinit();

    cluster_url[0] = 'x';
    token_scope[0] = 'x';
    user_agent[0] = 'x';
    try std.testing.expectEqualStrings("https://cluster.kusto.windows.net", connection.clusterUrl());
    try std.testing.expectEqualStrings("scope-value", connection.token_scope);
    try std.testing.expectEqualStrings("user-agent-value", connection.user_agent);
}

test "KustoConnection rejects unsupported and missing authentication" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();

    try std.testing.expectError(
        error.AadAppKeyAuthenticationUnsupported,
        KustoConnection.init(
            allocator,
            .{ .cluster_url = "https://cluster.kusto.windows.net", .application_key = "secret" },
            mock.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.AadAppKeyAuthenticationUnsupported,
        KustoConnection.init(
            allocator,
            .{ .cluster_url = "https://cluster.kusto.windows.net", .application_client_id = "client-id" },
            mock.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.AadAppKeyAuthenticationUnsupported,
        KustoConnection.init(
            allocator,
            .{ .cluster_url = "https://cluster.kusto.windows.net", .authority_id = "tenant-id" },
            mock.asTransport(),
            .{},
        ),
    );
    try std.testing.expectError(
        error.KustoCredentialRequired,
        KustoConnection.init(
            allocator,
            .{ .cluster_url = "https://cluster.kusto.windows.net" },
            mock.asTransport(),
            .{},
        ),
    );
}

test "Kusto connection formatting omits authentication material" {
    const allocator = std.testing.allocator;
    const sentinel_secret = "connection-format-sentinel-secret";
    var builder = KustoConnectionStringBuilder.init("https://cluster.kusto.windows.net");
    _ = builder.withAadAppKey("client-id", sentinel_secret, "tenant-id");
    const properties = builder.build();
    var buffer: [256]u8 = undefined;

    const builder_rendered = try std.fmt.bufPrint(&buffer, "{f}", .{builder});
    try std.testing.expect(std.mem.indexOf(u8, builder_rendered, sentinel_secret) == null);
    try std.testing.expect(std.mem.indexOf(u8, builder_rendered, "legacy_app_key") != null);
    const properties_rendered = try std.fmt.bufPrint(&buffer, "{f}", .{properties});
    try std.testing.expect(std.mem.indexOf(u8, properties_rendered, sentinel_secret) == null);
    try std.testing.expect(std.mem.indexOf(u8, properties_rendered, "legacy_app_key") != null);

    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var credential = TestTokenCredential{};
    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = properties.cluster_url, .credential = credential.asCredential() },
        mock.asTransport(),
        .{},
    );
    defer connection.deinit();

    const connection_rendered = try std.fmt.bufPrint(&buffer, "{f}", .{connection});
    try std.testing.expect(std.mem.indexOf(u8, connection_rendered, sentinel_secret) == null);
    try std.testing.expect(std.mem.indexOf(u8, connection_rendered, "token_credential") != null);
}

test "KustoConnection sends authenticated request with default and override scopes" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var credential = TestTokenCredential{};

    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        mock.asTransport(),
        .{},
    );
    defer connection.deinit();

    var request = core.http.Request.init(allocator, .GET, "https://cluster.kusto.windows.net/v2/rest/query");
    defer request.deinit();
    var response = try connection.send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(u32, 1), credential.call_count);
    try std.testing.expectEqualStrings("https://kusto.kusto.windows.net/.default", credential.last_scope.?);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_headers.get("Authorization").?, "connection-test-token"));
    try std.testing.expectEqualStrings("azsdk-zig-kusto/0.1.0", mock.last_headers.get("User-Agent").?);
    try std.testing.expectEqualStrings("gzip, deflate", mock.last_headers.get("Accept-Encoding").?);
    const request_id = mock.last_headers.get("x-ms-client-request-id").?;
    try std.testing.expectEqual(@as(usize, 36), request_id.len);
    try std.testing.expect(request_id[8] == '-' and request_id[13] == '-' and
        request_id[18] == '-' and request_id[23] == '-');

    var override_mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer override_mock.deinit();
    const override_connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        override_mock.asTransport(),
        .{ .token_scope = "https://custom.kusto.windows.net/.default" },
    );
    defer override_connection.deinit();
    var override_request = core.http.Request.init(allocator, .GET, "https://cluster.kusto.windows.net/v2/rest/query");
    defer override_request.deinit();
    var override_response = try override_connection.send(&override_request);
    defer override_response.deinit();

    try std.testing.expectEqual(@as(u32, 2), credential.call_count);
    try std.testing.expectEqualStrings("https://custom.kusto.windows.net/.default", credential.last_scope.?);
    try std.testing.expect(std.mem.endsWith(u8, override_mock.last_headers.get("Authorization").?, "connection-test-token"));
}

test "KustoConnection applies retry options" {
    const allocator = std.testing.allocator;
    var transport = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 500, .body = "retry" },
        .{ .status = 200, .body = "ok" },
    });
    var credential = TestTokenCredential{};
    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        transport.asTransport(),
        .{ .retry = .{ .max_retries = 1, .initial_delay_ms = 0 } },
    );
    defer connection.deinit();
    var request = core.http.Request.init(allocator, .GET, "https://cluster.kusto.windows.net/v2/rest/query");
    defer request.deinit();
    var response = try connection.send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}

fn initializeConnection(
    allocator: std.mem.Allocator,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,
) !void {
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net/",
            .credential = credential,
        },
        transport,
        .{},
    );
    connection.deinit();
}

test "KustoConnection handles every initialization allocation failure" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var credential = TestTokenCredential{};

    try std.testing.checkAllAllocationFailures(
        allocator,
        initializeConnection,
        .{ credential.asCredential(), mock.asTransport() },
    );
}

test "KustoConnectionStringBuilder withTokenCredential" {
    const identity = @import("azure_core").identity;
    const allocator = std.testing.allocator;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var kcsb = KustoConnectionStringBuilder.init("https://cluster.kusto.windows.net");
    _ = kcsb.withTokenCredential(cred.asCredential());
    const props = kcsb.build();
    try std.testing.expect(props.credential != null);
}

test "ConnectionProperties getIngestUrl" {
    const allocator = std.testing.allocator;
    const props = ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    const ingest_url = try props.getIngestUrl(allocator);
    defer allocator.free(ingest_url);
    try std.testing.expectEqualStrings("https://ingest-mycluster.eastus.kusto.windows.net", ingest_url);
}

test "DataFormat toString" {
    try std.testing.expectEqualStrings("Csv", DataFormat.csv.toString());
    try std.testing.expectEqualStrings("Json", DataFormat.json.toString());
    try std.testing.expectEqualStrings("MultiJson", DataFormat.multi_json.toString());
    try std.testing.expectEqualStrings("Parquet", DataFormat.parquet.toString());
}

test "ClientRequestProperties toJson default" {
    const allocator = std.testing.allocator;
    const props = ClientRequestProperties{};
    const json = try props.toJson(allocator);
    defer allocator.free(json);
    try std.testing.expectEqualStrings("{}", json);
}

test "ClientRequestProperties toJson with timeout" {
    const allocator = std.testing.allocator;
    const props = ClientRequestProperties{ .server_timeout_ms = 300000 };
    const json = try props.toJson(allocator);
    defer allocator.free(json);
    try std.testing.expectEqualStrings("{\"Options\":{\"servertimeout\":\"5m\"}}", json);
}
