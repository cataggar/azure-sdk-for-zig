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

    /// Get the data management (ingest) URL by prepending `ingest-` to the hostname.
    pub fn getIngestUrl(self: ConnectionProperties, allocator: std.mem.Allocator) ![]u8 {
        // https://cluster.region.kusto.windows.net → https://ingest-cluster.region.kusto.windows.net
        if (std.mem.indexOf(u8, self.cluster_url, "://")) |scheme_end| {
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

test "KustoConnectionStringBuilder build" {
    var kcsb = KustoConnectionStringBuilder.init("https://mycluster.eastus.kusto.windows.net");
    _ = kcsb.withAadAppKey("app-id", "secret", "tenant-id");
    const props = kcsb.build();
    try std.testing.expectEqualStrings("https://mycluster.eastus.kusto.windows.net", props.cluster_url);
    try std.testing.expectEqualStrings("app-id", props.application_client_id.?);
    try std.testing.expectEqualStrings("secret", props.application_key.?);
    try std.testing.expectEqualStrings("tenant-id", props.authority_id.?);
}

test "KustoConnectionStringBuilder withTokenCredential" {
    const identity = @import("azure_identity");
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
