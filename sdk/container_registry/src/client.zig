const std = @import("std");
const core = @import("azure_core");
const protocol = @import("azure_rest_container_registry");
const auth = @import("auth_policy.zig");
const link_pager = @import("link_pager.zig");
const models = @import("models.zig");
const service_error = @import("service_error.zig");

pub const RepositoryPager = link_pager.LinkPager(models.RepositoryPage);
pub const ManifestPager = link_pager.LinkPager(models.ManifestPage);
pub const TagPager = link_pager.LinkPager(models.TagPage);

pub const RepositoryPropertiesResult =
    service_error.Result(models.ContainerRepositoryProperties);
pub const ManifestPropertiesResult =
    service_error.Result(models.ArtifactManifestProperties);
pub const TagPropertiesResult =
    service_error.Result(models.ArtifactTagProperties);
pub const DeleteOutcome = enum {
    accepted,
    not_found,
};
pub const DeleteResult = service_error.Result(DeleteOutcome);

pub const ListRepositoriesOptions = struct {
    max_results: ?u32 = null,
};

pub const ListManifestPropertiesOptions = struct {
    max_results: ?u32 = null,
    order: ?protocol.enums.ArtifactManifestOrder = null,
};

pub const ListTagPropertiesOptions = struct {
    max_results: ?u32 = null,
    order: ?protocol.enums.ArtifactTagOrder = null,
    digest: ?[]const u8 = null,
};

pub const ContainerRegistryClientOptions = struct {
    transport: *core.http.HttpTransport,
    authentication: auth.Authentication,
    api_version: []const u8 = "2021-07-01",
    authentication_options: auth.Options = .{},
};

/// Authenticated wrapper over the generated Container Registry protocol client.
pub const ContainerRegistryClient = struct {
    allocator: std.mem.Allocator,
    auth_policy: *auth.ChallengeAuthenticationPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,
    endpoint: []const u8,
    api_version: []const u8,
    protocol_client: protocol.ContainerRegistryClient,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        options: ContainerRegistryClientOptions,
    ) !ContainerRegistryClient {
        var authentication_options = options.authentication_options;
        authentication_options.api_version = options.api_version;
        const auth_policy = try allocator.create(auth.ChallengeAuthenticationPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = try auth.ChallengeAuthenticationPolicy.init(
            allocator,
            endpoint,
            options.authentication,
            authentication_options,
        );
        errdefer auth_policy.deinit();

        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = auth_policy.asPolicy();

        const pipeline = core.pipeline.HttpPipeline{
            .policies = policy_ptrs,
            .transport_impl = options.transport,
        };
        return .{
            .allocator = allocator,
            .auth_policy = auth_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = pipeline,
            .endpoint = auth_policy.endpoint,
            .api_version = auth_policy.api_version,
            .protocol_client = protocol.ContainerRegistryClient.initWithPipeline(
                allocator,
                pipeline,
                .{
                    .endpoint = auth_policy.endpoint,
                    .api_version = auth_policy.api_version,
                },
            ),
        };
    }

    pub fn deinit(self: *ContainerRegistryClient) void {
        self.protocol_client.deinit();
        self.allocator.free(self.policy_ptrs);
        self.auth_policy.deinit();
        self.allocator.destroy(self.auth_policy);
        self.* = undefined;
    }

    /// Access the generated protocol client using the prepared challenge-auth
    /// pipeline. The returned pointer borrows from this client.
    pub fn protocolClient(self: *ContainerRegistryClient) *protocol.ContainerRegistryClient {
        return &self.protocol_client;
    }

    /// List repository names. The returned pager and client must be kept alive
    /// together because page requests use this client's authentication policy.
    pub fn listRepositories(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        options: ListRepositoriesOptions,
    ) !RepositoryPager {
        const url = try self.buildListUrl(
            allocator,
            "/acr/v1/_catalog",
            options.max_results,
            null,
            null,
        );
        defer allocator.free(url);
        return RepositoryPager.init(
            allocator,
            self.pipeline,
            self.endpoint,
            url,
            &models.parseRepositoryPage,
        );
    }

    pub fn getRepositoryProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
    ) !RepositoryPropertiesResult {
        const url = try self.buildRepositoryUrl(allocator, repository_name, "");
        defer allocator.free(url);
        return self.sendRepositoryProperties(allocator, .GET, url, null);
    }

    pub fn updateRepositoryProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        properties: models.ChangeableProperties,
    ) !RepositoryPropertiesResult {
        const url = try self.buildRepositoryUrl(allocator, repository_name, "");
        defer allocator.free(url);
        const body = try serializeChangeableProperties(allocator, properties);
        defer allocator.free(body);
        return self.sendRepositoryProperties(allocator, .PATCH, url, body);
    }

    pub fn deleteRepository(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
    ) !DeleteResult {
        const url = try self.buildRepositoryUrl(allocator, repository_name, "");
        defer allocator.free(url);
        return self.sendDelete(allocator, url);
    }

    pub fn listManifestProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        options: ListManifestPropertiesOptions,
    ) !ManifestPager {
        const encoded_name = try core.url.encodeRepositoryName(allocator, repository_name);
        defer allocator.free(encoded_name);
        const path = try std.fmt.allocPrint(
            allocator,
            "/acr/v1/{s}/_manifests",
            .{encoded_name},
        );
        defer allocator.free(path);
        const order = if (options.order) |value| value.toWire() else null;
        const url = try self.buildListUrl(
            allocator,
            path,
            options.max_results,
            order,
            null,
        );
        defer allocator.free(url);
        return ManifestPager.init(
            allocator,
            self.pipeline,
            self.endpoint,
            url,
            &models.parseManifestPage,
        );
    }

    pub fn getManifestProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        digest: []const u8,
    ) !ManifestPropertiesResult {
        const suffix = try encodedSuffix(allocator, "/_manifests/", digest);
        defer allocator.free(suffix);
        const url = try self.buildRepositoryUrl(allocator, repository_name, suffix);
        defer allocator.free(url);
        return self.sendManifestProperties(allocator, .GET, url, null);
    }

    pub fn updateManifestProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        digest: []const u8,
        properties: models.ChangeableProperties,
    ) !ManifestPropertiesResult {
        const suffix = try encodedSuffix(allocator, "/_manifests/", digest);
        defer allocator.free(suffix);
        const url = try self.buildRepositoryUrl(allocator, repository_name, suffix);
        defer allocator.free(url);
        const body = try serializeChangeableProperties(allocator, properties);
        defer allocator.free(body);
        return self.sendManifestProperties(allocator, .PATCH, url, body);
    }

    pub fn deleteManifest(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        digest: []const u8,
    ) !DeleteResult {
        const encoded_name = try core.url.encodeRepositoryName(allocator, repository_name);
        defer allocator.free(encoded_name);
        const encoded_digest = try core.url.encodePathSegment(allocator, digest);
        defer allocator.free(encoded_digest);
        const path = try std.fmt.allocPrint(
            allocator,
            "/v2/{s}/manifests/{s}",
            .{ encoded_name, encoded_digest },
        );
        defer allocator.free(path);
        const url = try self.buildUrl(allocator, path);
        defer allocator.free(url);
        return self.sendDelete(allocator, url);
    }

    pub fn listTagProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        options: ListTagPropertiesOptions,
    ) !TagPager {
        const encoded_name = try core.url.encodeRepositoryName(allocator, repository_name);
        defer allocator.free(encoded_name);
        const path = try std.fmt.allocPrint(
            allocator,
            "/acr/v1/{s}/_tags",
            .{encoded_name},
        );
        defer allocator.free(path);
        const order = if (options.order) |value| value.toWire() else null;
        const url = try self.buildListUrl(
            allocator,
            path,
            options.max_results,
            order,
            options.digest,
        );
        defer allocator.free(url);
        return TagPager.init(
            allocator,
            self.pipeline,
            self.endpoint,
            url,
            &models.parseTagPage,
        );
    }

    pub fn getTagProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        tag: []const u8,
    ) !TagPropertiesResult {
        const suffix = try encodedSuffix(allocator, "/_tags/", tag);
        defer allocator.free(suffix);
        const url = try self.buildRepositoryUrl(allocator, repository_name, suffix);
        defer allocator.free(url);
        return self.sendTagProperties(allocator, .GET, url, null);
    }

    pub fn updateTagProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        tag: []const u8,
        properties: models.ChangeableProperties,
    ) !TagPropertiesResult {
        const suffix = try encodedSuffix(allocator, "/_tags/", tag);
        defer allocator.free(suffix);
        const url = try self.buildRepositoryUrl(allocator, repository_name, suffix);
        defer allocator.free(url);
        const body = try serializeChangeableProperties(allocator, properties);
        defer allocator.free(body);
        return self.sendTagProperties(allocator, .PATCH, url, body);
    }

    pub fn deleteTag(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        tag: []const u8,
    ) !DeleteResult {
        const suffix = try encodedSuffix(allocator, "/_tags/", tag);
        defer allocator.free(suffix);
        const url = try self.buildRepositoryUrl(allocator, repository_name, suffix);
        defer allocator.free(url);
        return self.sendDelete(allocator, url);
    }

    fn sendRepositoryProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        method: core.http.Method,
        url: []const u8,
        body: ?[]const u8,
    ) !RepositoryPropertiesResult {
        var response = try self.sendJson(allocator, method, url, body);
        defer response.deinit();
        if (response.status_code == 200) {
            return .{ .ok = try models.parseRepositoryProperties(
                allocator,
                response.body,
            ) };
        }
        return .{ .err = try service_error.ServiceError.fromResponse(
            allocator,
            &response,
        ) };
    }

    fn sendManifestProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        method: core.http.Method,
        url: []const u8,
        body: ?[]const u8,
    ) !ManifestPropertiesResult {
        var response = try self.sendJson(allocator, method, url, body);
        defer response.deinit();
        if (response.status_code == 200) {
            return .{ .ok = try models.parseManifestProperties(
                allocator,
                response.body,
            ) };
        }
        return .{ .err = try service_error.ServiceError.fromResponse(
            allocator,
            &response,
        ) };
    }

    fn sendTagProperties(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        method: core.http.Method,
        url: []const u8,
        body: ?[]const u8,
    ) !TagPropertiesResult {
        var response = try self.sendJson(allocator, method, url, body);
        defer response.deinit();
        if (response.status_code == 200) {
            return .{ .ok = try models.parseTagProperties(
                allocator,
                response.body,
            ) };
        }
        return .{ .err = try service_error.ServiceError.fromResponse(
            allocator,
            &response,
        ) };
    }

    fn sendDelete(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        url: []const u8,
    ) !DeleteResult {
        var response = try self.sendJson(allocator, .DELETE, url, null);
        defer response.deinit();
        if (response.status_code == 202) return .{ .ok = .accepted };
        if (response.status_code == 404) return .{ .ok = .not_found };
        return .{ .err = try service_error.ServiceError.fromResponse(
            allocator,
            &response,
        ) };
    }

    fn sendJson(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        method: core.http.Method,
        url: []const u8,
        body: ?[]const u8,
    ) !core.http.Response {
        var request = core.http.Request.init(allocator, method, url);
        defer request.deinit();
        try request.setHeader("Accept", "application/json");
        if (body) |value| {
            try request.setHeader("Content-Type", "application/json");
            request.body = value;
        }
        return self.pipeline.send(&request);
    }

    fn buildRepositoryUrl(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        repository_name: []const u8,
        suffix: []const u8,
    ) ![]u8 {
        const encoded_name = try core.url.encodeRepositoryName(allocator, repository_name);
        defer allocator.free(encoded_name);
        const path = try std.fmt.allocPrint(
            allocator,
            "/acr/v1/{s}{s}",
            .{ encoded_name, suffix },
        );
        defer allocator.free(path);
        return self.buildUrl(allocator, path);
    }

    fn buildUrl(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        const encoded_version = try core.url.percentEncode(allocator, self.api_version);
        defer allocator.free(encoded_version);
        return std.fmt.allocPrint(
            allocator,
            "{s}{s}?api-version={s}",
            .{ self.endpoint, path, encoded_version },
        );
    }

    fn buildListUrl(
        self: *ContainerRegistryClient,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_results: ?u32,
        order: ?[]const u8,
        digest: ?[]const u8,
    ) ![]u8 {
        if (max_results) |value| {
            if (value == 0 or value > std.math.maxInt(i32))
                return error.InvalidMaxResults;
        }
        const encoded_version = try core.url.percentEncode(allocator, self.api_version);
        defer allocator.free(encoded_version);
        var url: std.ArrayList(u8) = .empty;
        errdefer url.deinit(allocator);
        try url.print(
            allocator,
            "{s}{s}?api-version={s}",
            .{ self.endpoint, path, encoded_version },
        );
        if (max_results) |value| try url.print(allocator, "&n={d}", .{value});
        if (order) |value| {
            const encoded_order = try core.url.percentEncode(allocator, value);
            defer allocator.free(encoded_order);
            try url.print(allocator, "&orderby={s}", .{encoded_order});
        }
        if (digest) |value| {
            const encoded_digest = try core.url.percentEncode(allocator, value);
            defer allocator.free(encoded_digest);
            try url.print(allocator, "&digest={s}", .{encoded_digest});
        }
        return url.toOwnedSlice(allocator);
    }
};

fn encodedSuffix(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    value: []const u8,
) ![]u8 {
    const encoded = try core.url.encodePathSegment(allocator, value);
    defer allocator.free(encoded);
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ prefix, encoded });
}

fn serializeChangeableProperties(
    allocator: std.mem.Allocator,
    properties: models.ChangeableProperties,
) ![]u8 {
    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(allocator);
    try body.append(allocator, '{');
    var first = true;
    try appendBooleanField(
        allocator,
        &body,
        &first,
        "deleteEnabled",
        properties.can_delete,
    );
    try appendBooleanField(
        allocator,
        &body,
        &first,
        "writeEnabled",
        properties.can_write,
    );
    try appendBooleanField(
        allocator,
        &body,
        &first,
        "listEnabled",
        properties.can_list,
    );
    try appendBooleanField(
        allocator,
        &body,
        &first,
        "readEnabled",
        properties.can_read,
    );
    try body.append(allocator, '}');
    return body.toOwnedSlice(allocator);
}

fn appendBooleanField(
    allocator: std.mem.Allocator,
    body: *std.ArrayList(u8),
    first: *bool,
    name: []const u8,
    value: ?bool,
) !void {
    const boolean = value orelse return;
    try body.print(
        allocator,
        "{s}\"{s}\":{s}",
        .{
            if (first.*) "" else ",",
            name,
            if (boolean) "true" else "false",
        },
    );
    first.* = false;
}

test "ContainerRegistryClient drives generated protocol APIs through challenge auth" {
    const allocator = std.testing.allocator;
    const challenge =
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"registry:catalog:*\"";
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{ .status = 200, .body = "" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();

    var service = client.protocolClient().containerRegistry();
    try service.checkDockerV2Support(allocator);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expect(transport.captured_authorization[2]);
}
