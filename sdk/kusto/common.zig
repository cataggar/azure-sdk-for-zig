///! Shared types for Azure Kusto (Data Explorer) client libraries.
///!
///! Provides `KustoConnectionStringBuilder` for connection configuration
///! and common types used by both the data and ingest clients.
const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

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
        return deriveIngestEndpoint(allocator, std.mem.trimEnd(u8, self.cluster_url, "/"));
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

pub const KustoMetadataMode = enum {
    discover,
    disabled,
};

/// Auth metadata returned by a Kusto engine. All strings are allocator-owned.
pub const KustoCloudInfo = struct {
    login_endpoint: []u8,
    login_mfa_required: bool,
    kusto_client_app_id: []u8,
    kusto_client_redirect_uri: []u8,
    kusto_service_resource_id: []u8,
    first_party_authority_url: []u8,

    pub fn clone(self: *const KustoCloudInfo, allocator: std.mem.Allocator) !KustoCloudInfo {
        const login_endpoint = try allocator.dupe(u8, self.login_endpoint);
        errdefer allocator.free(login_endpoint);
        const app_id = try allocator.dupe(u8, self.kusto_client_app_id);
        errdefer allocator.free(app_id);
        const redirect_uri = try allocator.dupe(u8, self.kusto_client_redirect_uri);
        errdefer allocator.free(redirect_uri);
        const resource_id = try allocator.dupe(u8, self.kusto_service_resource_id);
        errdefer allocator.free(resource_id);
        const authority_url = try allocator.dupe(u8, self.first_party_authority_url);
        errdefer allocator.free(authority_url);
        return .{
            .login_endpoint = login_endpoint,
            .login_mfa_required = self.login_mfa_required,
            .kusto_client_app_id = app_id,
            .kusto_client_redirect_uri = redirect_uri,
            .kusto_service_resource_id = resource_id,
            .first_party_authority_url = authority_url,
        };
    }

    pub fn deinit(self: *KustoCloudInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.login_endpoint);
        allocator.free(self.kusto_client_app_id);
        allocator.free(self.kusto_client_redirect_uri);
        allocator.free(self.kusto_service_resource_id);
        allocator.free(self.first_party_authority_url);
    }
};

/// Caller-owned metadata cache. It is not synchronized; externally serialize
/// access and do not deinitialize it while a caller is using the cache.
pub const KustoCloudInfoCache = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(KustoCloudInfo),

    pub fn init(allocator: std.mem.Allocator) KustoCloudInfoCache {
        return .{ .allocator = allocator, .entries = std.StringHashMap(KustoCloudInfo).init(allocator) };
    }

    pub fn deinit(self: *KustoCloudInfoCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.entries.deinit();
    }

    pub fn invalidate(self: *KustoCloudInfoCache, endpoint: []const u8) void {
        const key = std.mem.trimEnd(u8, endpoint, "/");
        if (self.entries.fetchRemove(key)) |entry| {
            self.allocator.free(entry.key);
            var info = entry.value;
            info.deinit(self.allocator);
        }
    }

    pub fn lookup(self: *const KustoCloudInfoCache, normalized_endpoint: []const u8) ?*const KustoCloudInfo {
        return self.entries.getPtr(normalized_endpoint);
    }

    pub fn put(self: *KustoCloudInfoCache, normalized_endpoint: []const u8, info: *const KustoCloudInfo) !void {
        const key = try self.allocator.dupe(u8, normalized_endpoint);
        errdefer self.allocator.free(key);
        const copy = try info.clone(self.allocator);
        errdefer {
            var mutable_copy = copy;
            mutable_copy.deinit(self.allocator);
        }
        const result = try self.entries.getOrPut(key);
        if (result.found_existing) {
            self.allocator.free(key);
            var old = result.value_ptr.*;
            old.deinit(self.allocator);
        } else {
            result.key_ptr.* = key;
        }
        result.value_ptr.* = copy;
    }
};

pub const KustoConnectionOptions = struct {
    /// Empty derives the scope from metadata, or uses the public default when
    /// metadata discovery is disabled.
    token_scope: []const u8 = "",
    engine_endpoint: ?[]const u8 = null,
    data_management_endpoint: ?[]const u8 = null,
    metadata_mode: KustoMetadataMode = .discover,
    cloud_info_cache: ?*KustoCloudInfoCache = null,
    additional_trusted_hosts: []const []const u8 = &.{},
    /// The connection never changes or inspects the credential's authority;
    /// configure any credential authority when constructing that credential.
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
    /// Engine endpoint retained under its #46 field name for source compatibility.
    cluster_url: []u8,
    data_management_url: ?[]u8,
    token_scope: []u8,
    user_agent: []u8,
    cloud_info: ?KustoCloudInfo,
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

        const configured_engine = options.engine_endpoint orelse properties.cluster_url;
        const normalized_engine = std.mem.trimEnd(u8, configured_engine, "/");
        const engine_uri = try validateHttpsOrigin(normalized_engine);

        var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const engine_host = try endpointHost(engine_uri, &host_buffer);

        var resolved_cloud_info: ?KustoCloudInfo = null;
        errdefer if (resolved_cloud_info) |*info| info.deinit(allocator);
        var builtin_rule: ?usize = null;
        var fetched_cloud_info = false;

        if (options.metadata_mode == .discover) {
            if (options.cloud_info_cache) |cache| {
                if (cache.lookup(normalized_engine)) |cached| {
                    resolved_cloud_info = try cached.clone(allocator);
                }
            }
            if (resolved_cloud_info == null) {
                var fetched = try discoverCloudInfo(allocator, transport, normalized_engine);
                errdefer fetched.deinit(allocator);
                try validateCloudInfo(&fetched);
                resolved_cloud_info = fetched;
                fetched_cloud_info = true;
            }
            builtin_rule = trustedRuleForAuthority(engine_host, resolved_cloud_info.?.login_endpoint);
            if (builtin_rule == null and !isAdditionalHost(engine_host, options.additional_trusted_hosts))
                return error.UntrustedKustoEndpoint;
            if (fetched_cloud_info) {
                if (options.cloud_info_cache) |cache| {
                    try cache.put(normalized_engine, &resolved_cloud_info.?);
                }
            }
        } else {
            builtin_rule = anyTrustedRule(engine_host);
            if (builtin_rule == null and !isAdditionalHost(engine_host, options.additional_trusted_hosts))
                return error.UntrustedKustoEndpoint;
        }

        const configured_dm = options.data_management_endpoint;
        var owned_dm: ?[]u8 = null;
        errdefer if (owned_dm) |url| allocator.free(url);
        if (configured_dm) |dm| {
            const normalized_dm = std.mem.trimEnd(u8, dm, "/");
            const dm_uri = try validateHttpsOrigin(normalized_dm);
            var dm_host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
            const dm_host = try endpointHost(dm_uri, &dm_host_buffer);
            const dm_builtin_ok = if (builtin_rule) |rule| hostMatchesRule(dm_host, rule) else false;
            if (!dm_builtin_ok and !isAdditionalHost(dm_host, options.additional_trusted_hosts))
                return error.UntrustedKustoEndpoint;
            owned_dm = try allocator.dupe(u8, normalized_dm);
        } else if (builtin_rule != null) {
            owned_dm = try deriveIngestEndpoint(allocator, normalized_engine);
        }

        const scope_is_derived = options.token_scope.len == 0 and resolved_cloud_info != null;
        const scope_source = if (options.token_scope.len != 0)
            options.token_scope
        else if (resolved_cloud_info) |info|
            try resourceScope(allocator, info.kusto_service_resource_id, info.login_mfa_required)
        else
            "https://kusto.kusto.windows.net/.default";
        defer if (scope_is_derived) allocator.free(scope_source);
        const owned_token_scope = try allocator.dupe(u8, scope_source);
        errdefer allocator.free(owned_token_scope);
        const owned_user_agent = try allocator.dupe(u8, options.user_agent);
        errdefer allocator.free(owned_user_agent);
        const owned_engine = try allocator.dupe(u8, normalized_engine);
        errdefer allocator.free(owned_engine);

        const self = try allocator.create(KustoConnection);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.cluster_url = owned_engine;
        self.data_management_url = owned_dm;
        self.token_scope = owned_token_scope;
        self.user_agent = owned_user_agent;
        self.cloud_info = resolved_cloud_info;
        resolved_cloud_info = null;
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
        if (self.data_management_url) |url| allocator.free(url);
        allocator.free(self.token_scope);
        allocator.free(self.user_agent);
        if (self.cloud_info) |*info| info.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn send(self: *KustoConnection, request: *core.http.Request) !core.http.Response {
        const targets_engine = sameHttpsOrigin(self.cluster_url, request.url);
        const targets_data_management = if (self.data_management_url) |url|
            sameHttpsOrigin(url, request.url)
        else
            false;
        if (!targets_engine and !targets_data_management) {
            return error.UntrustedKustoRequestEndpoint;
        }
        request.redirect_policy = .not_allowed;
        return self.pipeline.send(request);
    }

    pub fn clusterUrl(self: *const KustoConnection) []const u8 {
        return self.engineUrl();
    }

    pub fn engineUrl(self: *const KustoConnection) []const u8 {
        return self.cluster_url;
    }

    pub fn dataManagementUrl(self: *const KustoConnection) ?[]const u8 {
        return self.data_management_url;
    }

    pub fn cloudInfo(self: *const KustoConnection) ?*const KustoCloudInfo {
        if (self.cloud_info) |*info| return info;
        return null;
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

const MetadataWire = struct {
    AzureAD: ?CloudInfoWire = null,
};

const CloudInfoWire = struct {
    LoginEndpoint: ?[]const u8 = null,
    LoginMfaRequired: bool = false,
    KustoClientAppId: ?[]const u8 = null,
    KustoClientRedirectUri: ?[]const u8 = null,
    KustoServiceResourceId: ?[]const u8 = null,
    FirstPartyAuthorityUrl: ?[]const u8 = null,
};

const TrustRule = struct {
    login_endpoint: []const u8,
    suffixes: []const []const u8,
    hostnames: []const []const u8,
};

const public_suffixes = [_][]const u8{
    ".dxp.aad.azure.com",                  ".dxp-dev.aad.azure.com",             ".kusto.azuresynapse.net",
    ".kusto.windows.net",                  ".kustodev.azuresynapse-dogfood.net", ".kustodev.windows.net",
    ".kustomfa.windows.net",               ".playfabapi.com",                    ".playfab.com",
    ".azureplayfab.com",                   ".kusto.data.microsoft.com",          ".kusto.fabric.microsoft.com",
    ".api.securityplatform.microsoft.com", ".securitycenter.windows.com",        ".arg-int.core.windows.net",
    ".arg-df.core.windows.net",            ".arg.core.windows.net",
};
const public_hosts = [_][]const u8{
    "ade.applicationinsights.io",        "ade.loganalytics.io",                   "adx.aimon.applicationinsights.azure.com",
    "adx.applicationinsights.azure.com", "adx.int.applicationinsights.azure.com", "adx.int.loganalytics.azure.com",
    "adx.int.monitor.azure.com",         "adx.loganalytics.azure.com",            "adx.monitor.azure.com",
    "kusto.aria.microsoft.com",          "eu.kusto.aria.microsoft.com",
};
const usgov_suffixes = [_][]const u8{ ".kusto.usgovcloudapi.net", ".kustomfa.usgovcloudapi.net", ".arg.core.usgovcloudapi.net" };
const usgov_hosts = [_][]const u8{ "adx.applicationinsights.azure.us", "adx.loganalytics.azure.us", "adx.monitor.azure.us" };
const china_suffixes = [_][]const u8{ ".kusto.azuresynapse.azure.cn", ".kusto.chinacloudapi.cn", ".kustomfa.chinacloudapi.cn", ".playfab.cn", ".arg.core.chinacloudapi.cn" };
const china_hosts = [_][]const u8{ "adx.applicationinsights.azure.cn", "adx.loganalytics.azure.cn", "adx.monitor.azure.cn" };
const eaglex_suffixes = [_][]const u8{ ".kusto.core.eaglex.ic.gov", ".kustomfa.core.eaglex.ic.gov", ".arg.core.eaglex.ic.gov" };
const eaglex_hosts = [_][]const u8{ "adx.applicationinsights.azure.eaglex.ic.gov", "adx.loganalytics.azure.eaglex.ic.gov", "adx.monitor.azure.eaglex.ic.gov" };
const scloud_suffixes = [_][]const u8{ ".kusto.core.microsoft.scloud", ".kustomfa.core.microsoft.scloud", ".arg.core.microsoft.scloud" };
const scloud_hosts = [_][]const u8{ "adx.applicationinsights.azure.microsoft.scloud", "adx.loganalytics.azure.microsoft.scloud", "adx.monitor.azure.microsoft.scloud" };
const fr_suffixes = [_][]const u8{ ".kusto.sovcloud-api.fr", ".kustomfa.sovcloud-api.fr" };
const fr_hosts = [_][]const u8{ "adx.applicationinsights.azure.fr", "adx.loganalytics.azure.fr", "adx.monitor.azure.fr" };
const de_suffixes = [_][]const u8{ ".kusto.sovcloud-api.de", ".kustomfa.sovcloud-api.de" };
const de_hosts = [_][]const u8{ "adx.applicationinsights.azure.de", "adx.loganalytics.azure.de", "adx.monitor.azure.de" };
const sg_suffixes = [_][]const u8{ ".kusto.sovcloud-api.sg", ".kustomfa.sovcloud-api.sg" };
const sg_hosts = [_][]const u8{ "adx.applicationinsights.azure.sg", "adx.loganalytics.azure.sg", "adx.monitor.azure.sg" };

// Kept in sync with Azure/azure-kusto-go 7c44a0a6.
const trusted_rules = [_]TrustRule{
    .{ .login_endpoint = "https://login.microsoftonline.com", .suffixes = &public_suffixes, .hostnames = &public_hosts },
    .{ .login_endpoint = "https://login.microsoftonline.us", .suffixes = &usgov_suffixes, .hostnames = &usgov_hosts },
    .{ .login_endpoint = "https://login.partner.microsoftonline.cn", .suffixes = &china_suffixes, .hostnames = &china_hosts },
    .{ .login_endpoint = "https://login.microsoftonline.eaglex.ic.gov", .suffixes = &eaglex_suffixes, .hostnames = &eaglex_hosts },
    .{ .login_endpoint = "https://login.microsoftonline.microsoft.scloud", .suffixes = &scloud_suffixes, .hostnames = &scloud_hosts },
    .{ .login_endpoint = "https://login.sovcloud-identity.fr", .suffixes = &fr_suffixes, .hostnames = &fr_hosts },
    .{ .login_endpoint = "https://login.sovcloud-identity.de", .suffixes = &de_suffixes, .hostnames = &de_hosts },
    .{ .login_endpoint = "https://login.sovcloud-identity.sg", .suffixes = &sg_suffixes, .hostnames = &sg_hosts },
};

fn validateHttpsOrigin(endpoint: []const u8) !std.Uri {
    const uri = std.Uri.parse(endpoint) catch return error.InvalidKustoEndpoint;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https") or
        uri.host == null or
        uri.user != null or
        uri.password != null or
        !uri.path.isEmpty() or
        uri.query != null or
        uri.fragment != null)
    {
        return error.InvalidKustoEndpoint;
    }
    return uri;
}

fn endpointHost(uri: std.Uri, buffer: *[std.Io.net.HostName.max_len]u8) ![]const u8 {
    const host = uri.getHost(buffer) catch return error.InvalidKustoEndpoint;
    return host.bytes;
}

fn sameHttpsOrigin(expected_origin: []const u8, candidate_url: []const u8) bool {
    const expected = std.Uri.parse(expected_origin) catch return false;
    const candidate = std.Uri.parse(candidate_url) catch return false;
    if (!std.ascii.eqlIgnoreCase(candidate.scheme, "https") or
        candidate.host == null or
        candidate.user != null or
        candidate.password != null or
        candidate.fragment != null)
    {
        return false;
    }
    var expected_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    var candidate_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const expected_host = expected.getHost(&expected_buffer) catch return false;
    const candidate_host = candidate.getHost(&candidate_buffer) catch return false;
    return std.ascii.eqlIgnoreCase(expected_host.bytes, candidate_host.bytes) and
        (expected.port orelse 443) == (candidate.port orelse 443);
}

fn hostMatchesRule(host: []const u8, rule_index: usize) bool {
    const rule = trusted_rules[rule_index];
    for (rule.hostnames) |allowed| {
        if (std.ascii.eqlIgnoreCase(host, allowed)) return true;
    }
    for (rule.suffixes) |suffix| {
        if (host.len > suffix.len and std.ascii.endsWithIgnoreCase(host, suffix)) return true;
    }
    return false;
}

fn trustedRuleForAuthority(host: []const u8, login_endpoint: []const u8) ?usize {
    const normalized_login = std.mem.trimEnd(u8, login_endpoint, "/");
    for (trusted_rules, 0..) |rule, index| {
        if (std.ascii.eqlIgnoreCase(normalized_login, rule.login_endpoint) and hostMatchesRule(host, index))
            return index;
    }
    return null;
}

fn anyTrustedRule(host: []const u8) ?usize {
    for (trusted_rules, 0..) |_, index| {
        if (hostMatchesRule(host, index)) return index;
    }
    return null;
}

fn isAdditionalHost(host: []const u8, additional_hosts: []const []const u8) bool {
    for (additional_hosts) |allowed| {
        if (std.ascii.eqlIgnoreCase(host, allowed)) return true;
    }
    return false;
}

fn discoverCloudInfo(allocator: std.mem.Allocator, transport: *core.http.HttpTransport, engine_url: []const u8) !KustoCloudInfo {
    const metadata_url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/auth/metadata", .{engine_url});
    defer allocator.free(metadata_url);
    var request = core.http.Request.init(allocator, .GET, metadata_url);
    defer request.deinit();
    request.retryable = false;
    request.redirect_policy = .not_allowed;
    try request.setHeader("Accept", "application/json");
    try request.setHeader("Accept-Encoding", "gzip, deflate");
    var response = try transport.send(&request);
    defer response.deinit();

    const body = std.mem.trim(u8, response.body, " \t\r\n");
    if (response.status_code == 404 or (response.isSuccess() and body.len == 0))
        return publicCloudInfo(allocator);
    if (!response.isSuccess()) return error.KustoMetadataRequestFailed;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const wire = serde.json.fromSlice(MetadataWire, arena.allocator(), body) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.MalformedKustoMetadata,
    };
    const azure_ad = wire.AzureAD orelse return error.MalformedKustoMetadata;
    const login_endpoint = azure_ad.LoginEndpoint orelse return error.InvalidKustoMetadata;
    const resource_id = azure_ad.KustoServiceResourceId orelse return error.InvalidKustoMetadata;
    return cloudInfoFromWire(allocator, azure_ad, login_endpoint, resource_id);
}

fn cloudInfoFromWire(allocator: std.mem.Allocator, wire: CloudInfoWire, login_endpoint: []const u8, resource_id: []const u8) !KustoCloudInfo {
    const login = try allocator.dupe(u8, std.mem.trimEnd(u8, login_endpoint, "/"));
    errdefer allocator.free(login);
    const app_id = try allocator.dupe(u8, wire.KustoClientAppId orelse "");
    errdefer allocator.free(app_id);
    const redirect_uri = try allocator.dupe(u8, wire.KustoClientRedirectUri orelse "");
    errdefer allocator.free(redirect_uri);
    const resource = try allocator.dupe(u8, std.mem.trimEnd(u8, resource_id, "/"));
    errdefer allocator.free(resource);
    const authority_url = try allocator.dupe(u8, wire.FirstPartyAuthorityUrl orelse "");
    errdefer allocator.free(authority_url);
    return .{
        .login_endpoint = login,
        .login_mfa_required = wire.LoginMfaRequired,
        .kusto_client_app_id = app_id,
        .kusto_client_redirect_uri = redirect_uri,
        .kusto_service_resource_id = resource,
        .first_party_authority_url = authority_url,
    };
}

fn publicCloudInfo(allocator: std.mem.Allocator) !KustoCloudInfo {
    return cloudInfoFromWire(allocator, .{
        .LoginEndpoint = "https://login.microsoftonline.com",
        .KustoClientAppId = "db662dc1-0cfe-4e1c-a843-19a68e65be58",
        .KustoClientRedirectUri = "https://microsoft/kustoclient",
        .KustoServiceResourceId = "https://kusto.kusto.windows.net",
        .FirstPartyAuthorityUrl = "https://login.microsoftonline.com/f8cdef31-a31e-4b4a-93e4-5f571e91255a",
    }, "https://login.microsoftonline.com", "https://kusto.kusto.windows.net");
}

fn validateCloudInfo(info: *const KustoCloudInfo) !void {
    _ = try validateHttpsOrigin(info.login_endpoint);
    _ = try validateHttpsOrigin(info.kusto_service_resource_id);
}

fn resourceScope(allocator: std.mem.Allocator, resource_id: []const u8, mfa_required: bool) ![]u8 {
    const resource = std.mem.trimEnd(u8, resource_id, "/");
    if (!mfa_required) return std.fmt.allocPrint(allocator, "{s}/.default", .{resource});
    if (std.mem.indexOf(u8, resource, ".kusto.")) |index| {
        return std.fmt.allocPrint(
            allocator,
            "{s}.kustomfa.{s}/.default",
            .{ resource[0..index], resource[index + ".kusto.".len ..] },
        );
    }
    return std.fmt.allocPrint(allocator, "{s}/.default", .{resource});
}

fn deriveIngestEndpoint(allocator: std.mem.Allocator, engine_url: []const u8) ![]u8 {
    const uri = try validateHttpsOrigin(engine_url);
    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = try endpointHost(uri, &host_buffer);
    if (std.ascii.startsWithIgnoreCase(host, "ingest-"))
        return allocator.dupe(u8, engine_url);
    const scheme_end = std.mem.indexOf(u8, engine_url, "://") orelse return error.InvalidKustoEndpoint;
    return std.fmt.allocPrint(allocator, "{s}://ingest-{s}", .{ engine_url[0..scheme_end], engine_url[scheme_end + 3 ..] });
}

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

const DiscoveryTestTransport = struct {
    const CannedResponse = struct { status: u16, body: []const u8 };

    allocator: std.mem.Allocator,
    responses: []const CannedResponse,
    transport: core.http.HttpTransport,
    call_count: usize = 0,
    bootstrap_has_authorization: ?bool = null,
    bootstrap_retryable: ?bool = null,
    bootstrap_redirect_policy: ?core.http.RedirectPolicy = null,
    service_has_authorization: ?bool = null,
    service_redirect_policy: ?core.http.RedirectPolicy = null,

    fn init(allocator: std.mem.Allocator, responses: []const CannedResponse) DiscoveryTestTransport {
        return .{
            .allocator = allocator,
            .responses = responses,
            .transport = .{ .sendFn = &send },
        };
    }

    fn asTransport(self: *DiscoveryTestTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn send(transport: *core.http.HttpTransport, request: *core.http.Request) !core.http.Response {
        const self: *DiscoveryTestTransport = @alignCast(@fieldParentPtr("transport", transport));
        if (self.call_count == 0) {
            self.bootstrap_has_authorization = request.getHeader("Authorization") != null;
            self.bootstrap_retryable = request.retryable;
            self.bootstrap_redirect_policy = request.redirect_policy;
        } else {
            self.service_has_authorization = request.getHeader("Authorization") != null;
            self.service_redirect_policy = request.redirect_policy;
        }
        const index = @min(self.call_count, self.responses.len - 1);
        self.call_count += 1;
        return .{
            .status_code = self.responses[index].status,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = try self.allocator.dupe(u8, self.responses[index].body),
            .allocator = self.allocator,
        };
    }
};

const public_metadata =
    \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.com","LoginMfaRequired":false,"KustoClientAppId":"app","KustoClientRedirectUri":"https://redirect","KustoServiceResourceId":"https://cluster.kusto.windows.net","FirstPartyAuthorityUrl":"https://authority"}}
;

test "KustoConnection discovers metadata and bootstraps without authentication" {
    const allocator = std.testing.allocator;
    var transport = DiscoveryTestTransport.init(allocator, &.{
        .{ .status = 200, .body = public_metadata },
        .{ .status = 200, .body = "ok" },
    });
    var credential = TestTokenCredential{};
    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        transport.asTransport(),
        .{},
    );
    defer connection.deinit();

    const info = connection.cloudInfo().?;
    try std.testing.expectEqualStrings("https://login.microsoftonline.com", info.login_endpoint);
    try std.testing.expectEqualStrings("app", info.kusto_client_app_id);
    try std.testing.expectEqualStrings("https://cluster.kusto.windows.net/.default", connection.token_scope);
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(false, transport.bootstrap_has_authorization.?);
    try std.testing.expectEqual(false, transport.bootstrap_retryable.?);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.bootstrap_redirect_policy.?);

    var request = core.http.Request.init(allocator, .GET, "https://cluster.kusto.windows.net/v2/rest/query");
    defer request.deinit();
    var response = try connection.send(&request);
    defer response.deinit();
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqual(true, transport.service_has_authorization.?);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.service_redirect_policy.?);
}

test "KustoConnection derives MFA scope from metadata" {
    const allocator = std.testing.allocator;
    var transport = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body =
        \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.com","LoginMfaRequired":true,"KustoServiceResourceId":"https://cluster.kusto.windows.net"}}
    }});
    var credential = TestTokenCredential{};
    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        transport.asTransport(),
        .{},
    );
    defer connection.deinit();
    try std.testing.expectEqualStrings("https://cluster.kustomfa.windows.net/.default", connection.token_scope);
}

test "KustoConnection uses public defaults for 404 and empty metadata" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var missing = DiscoveryTestTransport.init(allocator, &.{.{ .status = 404, .body = "" }});
    const from_404 = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        missing.asTransport(),
        .{},
    );
    defer from_404.deinit();
    try std.testing.expectEqualStrings("db662dc1-0cfe-4e1c-a843-19a68e65be58", from_404.cloudInfo().?.kusto_client_app_id);

    var empty = DiscoveryTestTransport.init(allocator, &.{.{ .status = 204, .body = " \r\n" }});
    const from_empty = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        empty.asTransport(),
        .{},
    );
    defer from_empty.deinit();
    try std.testing.expectEqualStrings("https://kusto.kusto.windows.net/.default", from_empty.token_scope);
}

test "KustoConnection rejects malformed metadata and metadata failures" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var malformed = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body = "not json" }});
    try std.testing.expectError(error.MalformedKustoMetadata, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        malformed.asTransport(),
        .{},
    ));
    var empty_object = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body = "{}" }});
    try std.testing.expectError(error.MalformedKustoMetadata, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        empty_object.asTransport(),
        .{},
    ));
    var failed = DiscoveryTestTransport.init(allocator, &.{.{ .status = 500, .body = "no" }});
    try std.testing.expectError(error.KustoMetadataRequestFailed, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        failed.asTransport(),
        .{},
    ));
    var redirected = DiscoveryTestTransport.init(allocator, &.{.{ .status = 302, .body = "" }});
    try std.testing.expectError(error.KustoMetadataRequestFailed, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        redirected.asTransport(),
        .{},
    ));
}

test "KustoConnection enforces authority keyed and custom endpoint trust" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var sovereign = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body =
        \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.us","KustoServiceResourceId":"https://cluster.kusto.usgovcloudapi.net"}}
    }});
    const sovereign_connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.usgovcloudapi.net", .credential = credential.asCredential() },
        sovereign.asTransport(),
        .{},
    );
    defer sovereign_connection.deinit();

    var mismatch = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body =
        \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.us","KustoServiceResourceId":"https://cluster.kusto.windows.net"}}
    }});
    try std.testing.expectError(error.UntrustedKustoEndpoint, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        mismatch.asTransport(),
        .{},
    ));

    var custom = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body =
        \\{"AzureAD":{"LoginEndpoint":"https://custom.authority","KustoServiceResourceId":"https://custom.example"}}
    }});
    const custom_connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://custom.example", .credential = credential.asCredential() },
        custom.asTransport(),
        .{ .additional_trusted_hosts = &.{"custom.example"} },
    );
    defer custom_connection.deinit();
    try std.testing.expect(custom_connection.dataManagementUrl() == null);

    var custom_dm_mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer custom_dm_mock.deinit();
    const explicit_custom_dm = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://custom.example", .credential = credential.asCredential() },
        custom_dm_mock.asTransport(),
        .{
            .metadata_mode = .disabled,
            .data_management_endpoint = "https://custom-ingest.example",
            .additional_trusted_hosts = &.{ "custom.example", "custom-ingest.example" },
        },
    );
    defer explicit_custom_dm.deinit();
    try std.testing.expectEqualStrings("https://custom-ingest.example", explicit_custom_dm.dataManagementUrl().?);
}

test "KustoConnection honors explicit endpoints and derives ingest endpoint" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    const explicit = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://ignored.kusto.windows.net", .credential = credential.asCredential() },
        mock.asTransport(),
        .{
            .metadata_mode = .disabled,
            .engine_endpoint = "https://query.kusto.windows.net/",
            .data_management_endpoint = "https://ingest.query.kusto.windows.net/",
            .token_scope = "scope",
        },
    );
    defer explicit.deinit();
    try std.testing.expectEqualStrings("https://query.kusto.windows.net", explicit.engineUrl());
    try std.testing.expectEqualStrings("https://ingest.query.kusto.windows.net", explicit.dataManagementUrl().?);
    try std.testing.expectEqualStrings("scope", explicit.token_scope);

    const derived = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://query.kusto.windows.net", .credential = credential.asCredential() },
        mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer derived.deinit();
    try std.testing.expectEqualStrings("https://ingest-query.kusto.windows.net", derived.dataManagementUrl().?);
}

test "KustoConnection caches successful metadata but retries failed discovery" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var cache = KustoCloudInfoCache.init(allocator);
    defer cache.deinit();
    var cached_transport = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body = public_metadata }});
    const first = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        cached_transport.asTransport(),
        .{ .cloud_info_cache = &cache },
    );
    defer first.deinit();
    const second = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        cached_transport.asTransport(),
        .{ .cloud_info_cache = &cache },
    );
    defer second.deinit();
    try std.testing.expectEqual(@as(usize, 1), cached_transport.call_count);

    var retry_transport = DiscoveryTestTransport.init(allocator, &.{
        .{ .status = 500, .body = "" },
        .{ .status = 404, .body = "" },
    });
    var retry_cache = KustoCloudInfoCache.init(allocator);
    defer retry_cache.deinit();
    try std.testing.expectError(error.KustoMetadataRequestFailed, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://retry.kusto.windows.net", .credential = credential.asCredential() },
        retry_transport.asTransport(),
        .{ .cloud_info_cache = &retry_cache },
    ));
    const retried = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://retry.kusto.windows.net", .credential = credential.asCredential() },
        retry_transport.asTransport(),
        .{ .cloud_info_cache = &retry_cache },
    );
    defer retried.deinit();
    try std.testing.expectEqual(@as(usize, 2), retry_transport.call_count);

    var untrusted_then_valid = DiscoveryTestTransport.init(allocator, &.{
        .{ .status = 200, .body =
        \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.us","KustoServiceResourceId":"https://cluster.kusto.windows.net"}}
        },
        .{ .status = 200, .body = public_metadata },
    });
    var trust_cache = KustoCloudInfoCache.init(allocator);
    defer trust_cache.deinit();
    try std.testing.expectError(error.UntrustedKustoEndpoint, KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        untrusted_then_valid.asTransport(),
        .{ .cloud_info_cache = &trust_cache },
    ));
    const trusted_retry = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        untrusted_then_valid.asTransport(),
        .{ .cloud_info_cache = &trust_cache },
    );
    defer trusted_retry.deinit();
    try std.testing.expectEqual(@as(usize, 2), untrusted_then_valid.call_count);
}

test "KustoConnection authenticates only validated service origins" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    const connection = try KustoConnection.init(
        allocator,
        .{ .cluster_url = "https://cluster.kusto.windows.net", .credential = credential.asCredential() },
        mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var request = core.http.Request.init(allocator, .GET, "https://attacker.example/query");
    defer request.deinit();
    try std.testing.expectError(error.UntrustedKustoRequestEndpoint, connection.send(&request));
    try std.testing.expectEqual(@as(u32, 0), credential.call_count);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

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
            .metadata_mode = .disabled,
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
            .{ .metadata_mode = .disabled },
        ),
    );
    try std.testing.expectError(
        error.AadAppKeyAuthenticationUnsupported,
        KustoConnection.init(
            allocator,
            .{ .cluster_url = "https://cluster.kusto.windows.net", .application_client_id = "client-id" },
            mock.asTransport(),
            .{ .metadata_mode = .disabled },
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
        .{ .metadata_mode = .disabled },
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
        .{ .metadata_mode = .disabled },
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
        .{
            .token_scope = "https://custom.kusto.windows.net/.default",
            .metadata_mode = .disabled,
        },
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
        .{
            .metadata_mode = .disabled,
            .retry = .{ .max_retries = 1, .initial_delay_ms = 0 },
        },
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
        .{ .metadata_mode = .disabled },
    );
    connection.deinit();
}

fn initializeDiscoveredConnection(
    allocator: std.mem.Allocator,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,
) !void {
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
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

test "KustoConnection cleans up discovery initialization allocation failures" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var transport = DiscoveryTestTransport.init(allocator, &.{.{ .status = 200, .body = public_metadata }});

    try std.testing.checkAllAllocationFailures(
        allocator,
        initializeDiscoveredConnection,
        .{ credential.asCredential(), transport.asTransport() },
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
