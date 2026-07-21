const std = @import("std");
const core = @import("azure_core");
const client_mod = @import("client.zig");
const digest_mod = @import("digest.zig");

pub const max_manifest_size: usize = 4 * 1024 * 1024;

pub const manifest_accept =
    "*/*, " ++
    "application/vnd.docker.distribution.manifest.v2+json, " ++
    "application/vnd.docker.distribution.manifest.list.v2+json, " ++
    "application/vnd.docker.container.image.v1+json, " ++
    "application/vnd.oci.image.manifest.v1+json, " ++
    "application/vnd.oci.image.index.v1+json, " ++
    "application/vnd.cncf.oras.artifact.manifest.v1+json";

pub const ManifestMediaType = enum {
    oci_image_manifest,
    docker_v2_manifest,

    pub fn value(self: ManifestMediaType) []const u8 {
        return switch (self) {
            .oci_image_manifest => "application/vnd.oci.image.manifest.v1+json",
            .docker_v2_manifest => "application/vnd.docker.distribution.manifest.v2+json",
        };
    }
};

pub const UploadManifestOptions = struct {
    /// A tag or SHA-256 digest. When omitted, the exact-byte digest is used.
    reference: ?[]const u8 = null,
    media_type: ManifestMediaType = .oci_image_manifest,
};

pub const UploadManifestResult = struct {
    digest: []u8,

    pub fn deinit(self: *UploadManifestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.digest);
        self.* = undefined;
    }
};

pub const DownloadManifestResult = struct {
    bytes: []u8,
    digest: []u8,
    media_type: []u8,

    pub fn deinit(self: *DownloadManifestResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        allocator.free(self.digest);
        allocator.free(self.media_type);
        self.* = undefined;
    }
};

pub const UploadManifestResponse = core.errors.Result(UploadManifestResult);
pub const DownloadManifestResponse = core.errors.Result(DownloadManifestResult);
pub const DeleteManifestResponse = core.errors.Result(void);

pub const ContainerRegistryContentClientOptions = client_mod.ContainerRegistryClientOptions;

/// High-level exact-byte manifest client for one ACR repository.
pub const ContainerRegistryContentClient = struct {
    allocator: std.mem.Allocator,
    repository_name: []u8,
    registry_client: client_mod.ContainerRegistryClient,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        repository_name: []const u8,
        options: ContainerRegistryContentClientOptions,
    ) !ContainerRegistryContentClient {
        try validateRepositoryName(repository_name);
        const owned_repository = try allocator.dupe(u8, repository_name);
        errdefer allocator.free(owned_repository);
        const registry_client = try client_mod.ContainerRegistryClient.init(
            allocator,
            endpoint,
            options,
        );
        return .{
            .allocator = allocator,
            .repository_name = owned_repository,
            .registry_client = registry_client,
        };
    }

    pub fn deinit(self: *ContainerRegistryContentClient) void {
        self.registry_client.deinit();
        self.allocator.free(self.repository_name);
        self.* = undefined;
    }

    /// Uploads exact manifest bytes without parsing or reserialization.
    pub fn uploadManifest(
        self: *ContainerRegistryContentClient,
        manifest: []const u8,
        options: UploadManifestOptions,
    ) !UploadManifestResult {
        var result = try self.uploadManifestResult(manifest, options);
        return result.unwrap(error.ManifestUploadFailed);
    }

    /// Structured-result variant of `uploadManifest`.
    pub fn uploadManifestResult(
        self: *ContainerRegistryContentClient,
        manifest: []const u8,
        options: UploadManifestOptions,
    ) !UploadManifestResponse {
        if (manifest.len > max_manifest_size) return error.ManifestTooLarge;

        const computed = digest_mod.computeSha256Digest(manifest);
        const reference = options.reference orelse computed[0..];
        const reference_kind = try validateManifestReference(reference);
        if (reference_kind == .digest and
            !(try digest_mod.sha256DigestsEqual(reference, &computed)))
        {
            return error.RequestedDigestMismatch;
        }

        const url = try self.buildManifestUrl(reference);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("Content-Type", options.media_type.value());

        var replayable = core.http.ReplayableBytes.init(manifest);
        var operation = try self.pipeline().open(
            &request,
            .{ .body = replayable.body() },
        );
        defer operation.deinit();

        if (operation.status_code != 201) {
            if (operation.isSuccess()) return error.UnexpectedResponseStatus;
            return .{ .err = try self.azureErrorFromOperation(operation) };
        }

        const returned_digest = try requiredHeader(
            self.allocator,
            operation,
            .docker_content_digest,
        );
        try digest_mod.validateSha256Digest(returned_digest);
        if (!(try digest_mod.sha256DigestsEqual(&computed, returned_digest)))
            return error.DigestMismatch;

        try operation.finish();
        const owned_digest = try self.allocator.dupe(u8, returned_digest);
        return .{ .ok = .{
            .digest = owned_digest,
        } };
    }

    /// Downloads a manifest by tag or digest and preserves its exact bytes.
    pub fn downloadManifest(
        self: *ContainerRegistryContentClient,
        reference: []const u8,
    ) !DownloadManifestResult {
        var result = try self.downloadManifestResult(reference);
        return result.unwrap(error.ManifestDownloadFailed);
    }

    /// Structured-result variant of `downloadManifest`.
    pub fn downloadManifestResult(
        self: *ContainerRegistryContentClient,
        reference: []const u8,
    ) !DownloadManifestResponse {
        const reference_kind = try validateManifestReference(reference);
        const url = try self.buildManifestUrl(reference);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("Accept", manifest_accept);

        var operation = try self.pipeline().open(&request, .{});
        defer operation.deinit();
        if (operation.status_code != 200) {
            if (operation.isSuccess()) return error.UnexpectedResponseStatus;
            return .{ .err = try self.azureErrorFromOperation(operation) };
        }

        const content_length_value = try requiredHeader(
            self.allocator,
            operation,
            .content_length,
        );
        const content_length = std.fmt.parseInt(
            usize,
            content_length_value,
            10,
        ) catch return error.InvalidContentLength;
        if (content_length == 0) return error.InvalidContentLength;
        if (content_length > max_manifest_size) return error.ManifestTooLarge;

        const returned_digest = try requiredHeader(
            self.allocator,
            operation,
            .docker_content_digest,
        );
        try digest_mod.validateSha256Digest(returned_digest);
        const media_type = try requiredHeader(
            self.allocator,
            operation,
            .content_type,
        );

        const buffered = try readManifestBody(
            self.allocator,
            operation,
            content_length,
        );
        errdefer self.allocator.free(buffered.bytes);
        try operation.finish();

        if (!(try digest_mod.sha256DigestsEqual(&buffered.digest, returned_digest)))
            return error.DigestMismatch;
        if (reference_kind == .digest and
            !(try digest_mod.sha256DigestsEqual(&buffered.digest, reference)))
        {
            return error.RequestedDigestMismatch;
        }

        const owned_digest = try self.allocator.dupe(u8, returned_digest);
        errdefer self.allocator.free(owned_digest);
        const owned_media_type = try self.allocator.dupe(u8, media_type);
        return .{ .ok = .{
            .bytes = buffered.bytes,
            .digest = owned_digest,
            .media_type = owned_media_type,
        } };
    }

    /// Deletes a manifest by SHA-256 digest.
    pub fn deleteManifest(
        self: *ContainerRegistryContentClient,
        digest: []const u8,
    ) !void {
        var result = try self.deleteManifestResult(digest);
        return result.unwrap(error.ManifestDeleteFailed);
    }

    /// Structured-result variant of `deleteManifest`.
    pub fn deleteManifestResult(
        self: *ContainerRegistryContentClient,
        digest: []const u8,
    ) !DeleteManifestResponse {
        try digest_mod.validateSha256Digest(digest);
        const url = try self.buildManifestUrl(digest);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .DELETE, url);
        defer request.deinit();

        var response = try self.pipeline().send(&request);
        defer response.deinit();
        if (response.status_code == 202) return .{ .ok = {} };
        if (response.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = core.errors.errorFromResponse(
            self.allocator,
            response,
        ).? };
    }

    fn pipeline(self: *ContainerRegistryContentClient) *core.pipeline.HttpPipeline {
        return &self.registry_client.protocolClient().pipeline;
    }

    fn buildManifestUrl(
        self: *ContainerRegistryContentClient,
        reference: []const u8,
    ) ![]u8 {
        const protocol_client = self.registry_client.protocolClient();
        const repository = try core.url.encodeRepositoryName(
            self.allocator,
            self.repository_name,
        );
        defer self.allocator.free(repository);
        const encoded_reference = try core.url.encodePathSegment(
            self.allocator,
            reference,
        );
        defer self.allocator.free(encoded_reference);
        const api_version = try core.url.percentEncode(
            self.allocator,
            protocol_client.api_version,
        );
        defer self.allocator.free(api_version);
        return std.fmt.allocPrint(
            self.allocator,
            "{s}/v2/{s}/manifests/{s}?api-version={s}",
            .{
                protocol_client.endpoint,
                repository,
                encoded_reference,
                api_version,
            },
        );
    }

    fn azureErrorFromOperation(
        self: *ContainerRegistryContentClient,
        operation: *core.http.HttpOperation,
    ) !core.errors.AzureError {
        const reader = try operation.reader();
        const body = reader.allocRemaining(
            self.allocator,
            .limited(1024 * 1024),
        ) catch |err| switch (err) {
            error.ReadFailed => return operation.bodyError() orelse error.ReadFailed,
            error.StreamTooLong => return error.ErrorResponseTooLarge,
            else => |other| return other,
        };
        var response = core.http.Response{
            .status_code = operation.status_code,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = body,
            .allocator = self.allocator,
        };
        defer response.deinit();
        try operation.finish();
        return core.errors.errorFromResponse(self.allocator, response).?;
    }
};

const ReferenceKind = enum { tag, digest };

fn validateManifestReference(reference: []const u8) !ReferenceKind {
    if (std.mem.indexOfScalar(u8, reference, ':') != null) {
        try digest_mod.validateSha256Digest(reference);
        return .digest;
    }
    try validateTag(reference);
    return .tag;
}

fn validateTag(tag: []const u8) !void {
    if (tag.len == 0 or tag.len > 128) return error.InvalidManifestTag;
    if (!isTagStart(tag[0])) return error.InvalidManifestTag;
    for (tag[1..]) |byte| {
        if (!isTagStart(byte) and byte != '.' and byte != '-')
            return error.InvalidManifestTag;
    }
}

fn isTagStart(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn validateRepositoryName(repository_name: []const u8) !void {
    if (repository_name.len == 0) return error.RepositoryNameRequired;
    if (repository_name.len > 255) return error.RepositoryNameTooLong;
    if (repository_name[0] == '/' or repository_name[repository_name.len - 1] == '/')
        return error.InvalidRepositoryName;

    var previous_slash = false;
    for (repository_name) |byte| {
        if (byte == '/') {
            if (previous_slash) return error.InvalidRepositoryName;
            previous_slash = true;
            continue;
        }
        previous_slash = false;
        if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte) and
            byte != '.' and byte != '_' and byte != '-')
        {
            return error.InvalidRepositoryName;
        }
    }
}

const RequiredHeader = enum {
    content_length,
    docker_content_digest,
    content_type,

    fn name(self: RequiredHeader) []const u8 {
        return switch (self) {
            .content_length => "Content-Length",
            .docker_content_digest => "Docker-Content-Digest",
            .content_type => "Content-Type",
        };
    }
};

fn requiredHeader(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    header: RequiredHeader,
) ![]const u8 {
    const values = try operation.getHeaderValues(allocator, header.name());
    defer allocator.free(values);
    if (values.len == 0) {
        return switch (header) {
            .content_length => error.MissingContentLength,
            .docker_content_digest => error.MissingDockerContentDigest,
            .content_type => error.MissingContentType,
        };
    }
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) {
        return switch (header) {
            .content_length => error.InvalidContentLength,
            .docker_content_digest => error.MalformedDigest,
            .content_type => error.InvalidContentType,
        };
    }
    return values[0];
}

const BufferedManifest = struct {
    bytes: []u8,
    digest: [digest_mod.sha256_formatted_length]u8,
};

fn readManifestBody(
    allocator: std.mem.Allocator,
    operation: *core.http.HttpOperation,
    expected_length: usize,
) !BufferedManifest {
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    try body.ensureTotalCapacityPrecise(allocator, expected_length);

    var digest = digest_mod.Sha256Digest{};
    const reader = try operation.reader();
    var buffer: [16 * 1024]u8 = undefined;
    var total: usize = 0;
    while (true) {
        const count = reader.readSliceShort(&buffer) catch |err| switch (err) {
            error.ReadFailed => return operation.bodyError() orelse error.ReadFailed,
            else => |other| return other,
        };
        if (count == 0) break;
        if (count > max_manifest_size - total) return error.ManifestTooLarge;
        if (count > expected_length -| total) return error.ContentLengthMismatch;
        try body.appendSlice(allocator, buffer[0..count]);
        digest.update(buffer[0..count]);
        total += count;
    }
    if (total != expected_length) return error.ContentLengthMismatch;

    return .{
        .bytes = try body.toOwnedSlice(allocator),
        .digest = digest.final(),
    };
}

fn testClient(
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
) !ContainerRegistryContentClient {
    return ContainerRegistryContentClient.init(
        allocator,
        "https://registry.example",
        "team/app",
        .{
            .transport = transport,
            .authentication = .anonymous,
        },
    );
}

fn capturedHeader(
    headers: *const std.StringHashMap([]const u8),
    name: []const u8,
) ?[]const u8 {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name))
            return entry.value_ptr.*;
    }
    return null;
}

test "upload preserves exact bytes with OCI default and tag reference" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2, \"layers\":[]}\n";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.uploadManifest(manifest, .{ .reference = "v1" });
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings(&expected_digest, result.digest);
    try std.testing.expectEqualStrings(manifest, transport.last_body.?);
    try std.testing.expectEqualStrings(
        ManifestMediaType.oci_image_manifest.value(),
        capturedHeader(&transport.last_headers, "Content-Type").?,
    );
    try std.testing.expectEqual(core.http.Method.PUT, transport.last_method.?);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.last_url.?, "/manifests/v1?") != null,
    );
}

test "upload supports Docker media type and digest reference" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2,\"mediaType\":\"docker\"}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.uploadManifest(manifest, .{
        .reference = &expected_digest,
        .media_type = .docker_v2_manifest,
    });
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings(
        ManifestMediaType.docker_v2_manifest.value(),
        capturedHeader(&transport.last_headers, "Content-Type").?,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, transport.last_url.?, "sha256%3A") != null,
    );
    try std.testing.expectEqualStrings(manifest, transport.last_body.?);
}

test "upload validates references and returned digest" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const other_digest = digest_mod.computeSha256Digest("{\"schemaVersion\":1}");
    var returned_digest: []const u8 = &other_digest;
    var headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = returned_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    try std.testing.expectError(
        error.RequestedDigestMismatch,
        client.uploadManifest(manifest, .{ .reference = &other_digest }),
    );
    try std.testing.expectError(
        error.InvalidManifestTag,
        client.uploadManifest(manifest, .{ .reference = ".invalid" }),
    );
    try std.testing.expectError(
        error.UnsupportedDigestAlgorithm,
        client.uploadManifest(
            manifest,
            .{
                .reference = "sha512:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);

    try std.testing.expectError(
        error.DigestMismatch,
        client.uploadManifest(manifest, .{ .reference = "v1" }),
    );
    returned_digest = "sha256:bad";
    headers[0].value = returned_digest;
    try std.testing.expectError(
        error.MalformedDigest,
        client.uploadManifest(manifest, .{ .reference = "v2" }),
    );
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expect(!std.mem.eql(u8, &expected_digest, &other_digest));
}

test "download sends mature Accept list and preserves owned metadata" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}\n";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const content_length = "20";
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = content_length },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.index.v1+json",
        },
    };
    var transport = core.http.MockTransport.init(allocator, 200, manifest);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.downloadManifest("latest");
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings(manifest, result.bytes);
    try std.testing.expectEqualStrings(&expected_digest, result.digest);
    try std.testing.expectEqualStrings(
        "application/vnd.oci.image.index.v1+json",
        result.media_type,
    );
    try std.testing.expectEqualStrings(
        manifest_accept,
        capturedHeader(&transport.last_headers, "Accept").?,
    );

    transport.response_headers_list = &headers;
    var digest_result = try client.downloadManifest(&expected_digest);
    defer digest_result.deinit(allocator);
    try std.testing.expectEqualStrings(manifest, digest_result.bytes);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.last_url.?, "sha256%3A") != null,
    );
}

test "download validates reference returned digest and required headers" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const other_digest = digest_mod.computeSha256Digest("{\"schemaVersion\":1}");
    const valid_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "19" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    var transport = core.http.MockTransport.init(allocator, 200, manifest);
    defer transport.deinit();
    transport.response_headers_list = &valid_headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    try std.testing.expectError(
        error.RequestedDigestMismatch,
        client.downloadManifest(&other_digest),
    );

    const mismatch_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "19" },
        .{ .name = "Docker-Content-Digest", .value = &other_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &mismatch_headers;
    try std.testing.expectError(
        error.DigestMismatch,
        client.downloadManifest("latest"),
    );

    const malformed_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "19" },
        .{ .name = "Docker-Content-Digest", .value = "sha256:bad" },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &malformed_headers;
    try std.testing.expectError(
        error.MalformedDigest,
        client.downloadManifest("latest"),
    );

    const missing_media_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "19" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    transport.response_headers_list = &missing_media_headers;
    try std.testing.expectError(
        error.MissingContentType,
        client.downloadManifest("latest"),
    );

    const missing_length_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &missing_length_headers;
    try std.testing.expectError(
        error.MissingContentLength,
        client.downloadManifest("latest"),
    );

    try std.testing.expectError(
        error.UnsupportedDigestAlgorithm,
        client.downloadManifest(
            "sha512:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        ),
    );
    try std.testing.expectError(
        error.MalformedDigest,
        client.downloadManifest("sha256:bad"),
    );
    try std.testing.expectEqual(@as(usize, 5), transport.call_count);
}

test "manifest size limit allows boundary and rejects declared and streamed excess" {
    const allocator = std.testing.allocator;
    const boundary = try allocator.alloc(u8, max_manifest_size);
    defer allocator.free(boundary);
    @memset(boundary, 'x');
    const boundary_digest = digest_mod.computeSha256Digest(boundary);
    const boundary_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "4194304" },
        .{ .name = "Docker-Content-Digest", .value = &boundary_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    var transport = core.http.MockTransport.init(allocator, 200, boundary);
    defer transport.deinit();
    transport.response_headers_list = &boundary_headers;
    transport.stream_response_chunk_size = 64 * 1024;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.downloadManifest("boundary");
    defer result.deinit(allocator);
    try std.testing.expectEqual(max_manifest_size, result.bytes.len);
    try std.testing.expectEqual(@as(usize, 1), transport.stream_finish_count);

    const declared_too_large = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "4194305" },
        .{ .name = "Docker-Content-Digest", .value = &boundary_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_body = "{}";
    transport.response_headers_list = &declared_too_large;
    try std.testing.expectError(
        error.ManifestTooLarge,
        client.downloadManifest("declared-too-large"),
    );

    const streamed_excess = try allocator.alloc(u8, max_manifest_size + 1);
    defer allocator.free(streamed_excess);
    @memset(streamed_excess, 'y');
    transport.response_body = streamed_excess;
    transport.response_headers_list = &boundary_headers;
    try std.testing.expectError(
        error.ManifestTooLarge,
        client.downloadManifest("streamed-too-large"),
    );
    try std.testing.expectEqual(@as(usize, 2), transport.stream_abort_count);

    transport.response_status = 201;
    transport.response_body = "";
    const upload_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &boundary_digest },
    };
    transport.response_headers_list = &upload_headers;
    var upload_result = try client.uploadManifest(boundary, .{});
    defer upload_result.deinit(allocator);
    try std.testing.expectEqualStrings(&boundary_digest, upload_result.digest);

    try std.testing.expectError(
        error.ManifestTooLarge,
        client.uploadManifest(streamed_excess, .{}),
    );
}

test "delete requires digest and exposes structured Azure errors" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("manifest");
    var transport = core.http.MockTransport.init(allocator, 202, "");
    defer transport.deinit();
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    try client.deleteManifest(&digest);
    try std.testing.expectEqual(core.http.Method.DELETE, transport.last_method.?);
    try std.testing.expect(
        std.mem.indexOf(u8, transport.last_url.?, "sha256%3A") != null,
    );
    try std.testing.expectError(
        error.MalformedDigest,
        client.deleteManifest("latest"),
    );

    transport.response_status = 404;
    transport.response_body =
        "{\"error\":{\"code\":\"ManifestUnknown\",\"message\":\"not found\"}}";
    var response = try client.deleteManifestResult(&digest);
    defer response.deinit(allocator);
    switch (response) {
        .err => |azure_error| {
            try std.testing.expectEqual(@as(u16, 404), azure_error.status_code);
            try std.testing.expectEqualStrings(
                "ManifestUnknown",
                azure_error.error_code.?,
            );
            try std.testing.expectEqualStrings("not found", azure_error.message.?);
        },
        .ok => return error.ExpectedAzureError,
    }
}

test "streaming manifest operations expose structured Azure errors" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}";
    var transport = core.http.MockTransport.init(
        allocator,
        400,
        "{\"error\":{\"code\":\"ManifestInvalid\",\"message\":\"bad manifest\"}}",
    );
    defer transport.deinit();
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var upload_response = try client.uploadManifestResult(
        manifest,
        .{ .reference = "v1" },
    );
    defer upload_response.deinit(allocator);
    switch (upload_response) {
        .err => |azure_error| {
            try std.testing.expectEqual(@as(u16, 400), azure_error.status_code);
            try std.testing.expectEqualStrings(
                "ManifestInvalid",
                azure_error.error_code.?,
            );
        },
        .ok => return error.ExpectedAzureError,
    }

    transport.response_status = 404;
    transport.response_body =
        "{\"error\":{\"code\":\"ManifestUnknown\",\"message\":\"not found\"}}";
    var download_response = try client.downloadManifestResult("missing");
    defer download_response.deinit(allocator);
    switch (download_response) {
        .err => |azure_error| {
            try std.testing.expectEqual(@as(u16, 404), azure_error.status_code);
            try std.testing.expectEqualStrings(
                "ManifestUnknown",
                azure_error.error_code.?,
            );
        },
        .ok => return error.ExpectedAzureError,
    }

    transport.response_status = 204;
    transport.response_body = "";
    try std.testing.expectError(
        error.UnexpectedResponseStatus,
        client.uploadManifest(manifest, .{ .reference = "v2" }),
    );
    try std.testing.expectError(
        error.UnexpectedResponseStatus,
        client.downloadManifest("missing"),
    );
}

test "replayable upload integrates challenge auth and same-origin redirects" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2,\"redirected\":true}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const redirect_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Location",
            .value = "https://registry.example/redirected/manifest",
        },
    };
    const challenge_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "WWW-Authenticate",
            .value = "Bear" ++ "er realm=\"https://registry.example/oauth2/token\"," ++
                "service=\"registry.example\"," ++
                "scope=\"repository:team/app:pull,push\"",
        },
    };
    const success_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 307, .body = "", .headers = &redirect_headers },
        .{ .status = 401, .body = "", .headers = &challenge_headers },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxNDI0NDQ4MDB9.signature\"}",
        },
        .{ .status = 307, .body = "", .headers = &redirect_headers },
        .{ .status = 201, .body = "", .headers = &success_headers },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var result = try client.uploadManifest(manifest, .{ .reference = "v1" });
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 5), transport.call_count);
    for ([_]usize{ 0, 1, 3, 4 }) |index| {
        try std.testing.expectEqual(core.http.Method.PUT, transport.captured_methods[index].?);
        try std.testing.expectEqual(manifest.len, transport.captured_body_lengths[index]);
        try std.testing.expectEqualStrings(
            manifest,
            transport.captured_bodies[index][0..manifest.len],
        );
    }
    try std.testing.expect(!transport.captured_authorization[0]);
    try std.testing.expect(!transport.captured_authorization[1]);
    try std.testing.expect(transport.captured_authorization[3]);
    try std.testing.expect(transport.captured_authorization[4]);
}

fn uploadAllocationTest(allocator: std.mem.Allocator) !void {
    const manifest = "{\"schemaVersion\":2}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
    };
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var result = try client.uploadManifest(manifest, .{ .reference = "v1" });
    result.deinit(allocator);
}

test "manifest upload is leak free across allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        uploadAllocationTest,
        .{},
    );
}

fn downloadAllocationTest(allocator: std.mem.Allocator) !void {
    const manifest = "{\"schemaVersion\":2}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "19" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    var transport = core.http.MockTransport.init(allocator, 200, manifest);
    defer transport.deinit();
    transport.response_headers_list = &headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();
    var result = try client.downloadManifest("v1");
    result.deinit(allocator);
}

test "manifest download is leak free across allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        downloadAllocationTest,
        .{},
    );
}
