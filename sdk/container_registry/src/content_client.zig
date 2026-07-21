const std = @import("std");
const core = @import("azure_core");
const client_mod = @import("client.zig");
const blob_upload = @import("blob_upload.zig");
const digest_mod = @import("digest.zig");
const service_error = @import("service_error.zig");

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

pub const UploadManifestResponse = ContentResult(UploadManifestResult);
pub const DownloadManifestResponse = ContentResult(DownloadManifestResult);
pub const DeleteManifestResponse = ContentResult(client_mod.DeleteOutcome);

fn ContentResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: service_error.ServiceError,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .ok => |*payload| {
                    if (comptime hasPayloadDeinit(T)) payload.deinit(allocator);
                },
                .err => |*failure| failure.deinit(),
            }
            self.* = undefined;
        }

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn errorCode(self: Self) ?[]const u8 {
            return switch (self) {
                .ok => null,
                .err => |failure| failure.code,
            };
        }

        pub fn unwrap(self: *Self, fail_error: anyerror) anyerror!T {
            switch (self.*) {
                .ok => |value| return value,
                .err => |*failure| {
                    std.log.warn("{f}", .{failure.*});
                    failure.deinit();
                    return fail_error;
                },
            }
        }
    };
}

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
            return .{ .err = try self.serviceErrorFromOperation(operation) };
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
            return .{ .err = try self.serviceErrorFromOperation(operation) };
        }

        const body_encoding = try responseBodyEncoding(self.allocator, operation);
        const content_length = try responseContentLength(self.allocator, operation);
        const expected_length: ?usize = switch (body_encoding) {
            .identity => content_length orelse return error.MissingContentLength,
            .encoded => null,
        };
        if (expected_length) |length| {
            if (length > max_manifest_size) return error.ManifestTooLarge;
        }
        const capacity_hint = if (content_length) |length|
            if (length <= max_manifest_size) length else 0
        else
            0;

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
            capacity_hint,
            expected_length,
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
    ) !client_mod.DeleteOutcome {
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
        if (response.status_code == 202) return .{ .ok = .accepted };
        if (response.status_code == 404) return .{ .ok = .not_found };
        if (response.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = try service_error.ServiceError.fromResponse(
            self.allocator,
            &response,
        ) };
    }

    /// Uploads a blob from a seekable or non-seekable reader using bounded,
    /// sequential chunks.
    pub fn uploadBlob(
        self: *ContainerRegistryContentClient,
        reader: *std.Io.Reader,
        options: blob_upload.BlobUploadOptions,
    ) !blob_upload.BlobUploadResult {
        var result = try self.uploadBlobResult(reader, options);
        switch (result) {
            .ok => |value| return value,
            .err => |*failure| {
                std.log.warn("{f}", .{failure.*});
                failure.deinit();
                return error.BlobUploadFailed;
            },
        }
    }

    /// Structured-result variant of `uploadBlob`.
    pub fn uploadBlobResult(
        self: *ContainerRegistryContentClient,
        reader: *std.Io.Reader,
        options: blob_upload.BlobUploadOptions,
    ) !blob_upload.BlobUploadResponse {
        return blob_upload.upload(.{
            .allocator = self.allocator,
            .pipeline = self.pipeline(),
            .endpoint = self.registry_client.endpoint,
            .api_version = self.registry_client.api_version,
            .repository_name = self.repository_name,
        }, reader, options);
    }

    /// Convenience wrapper for in-memory blob bytes.
    pub fn uploadBlobBytes(
        self: *ContainerRegistryContentClient,
        bytes: []const u8,
        options: blob_upload.BlobUploadOptions,
    ) !blob_upload.BlobUploadResult {
        var reader = std.Io.Reader.fixed(bytes);
        return self.uploadBlob(&reader, options);
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

    fn serviceErrorFromOperation(
        self: *ContainerRegistryContentClient,
        operation: *core.http.HttpOperation,
    ) !service_error.ServiceError {
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
        var failure = try service_error.ServiceError.fromResponse(
            self.allocator,
            &response,
        );
        errdefer failure.deinit();
        try operation.finish();
        return failure;
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
    docker_content_digest,
    content_type,

    fn name(self: RequiredHeader) []const u8 {
        return switch (self) {
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
            .docker_content_digest => error.MissingDockerContentDigest,
            .content_type => error.MissingContentType,
        };
    }
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) {
        return switch (header) {
            .docker_content_digest => error.MalformedDigest,
            .content_type => error.InvalidContentType,
        };
    }
    return values[0];
}

const ResponseBodyEncoding = enum {
    identity,
    encoded,
};

fn responseBodyEncoding(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !ResponseBodyEncoding {
    const values = try operation.getHeaderValues(allocator, "Content-Encoding");
    defer allocator.free(values);
    if (values.len == 0) return .identity;

    var saw_encoding = false;
    var is_encoded = false;
    for (values) |value| {
        var encodings = std.mem.splitScalar(u8, value, ',');
        while (encodings.next()) |raw_encoding| {
            const encoding = std.mem.trim(u8, raw_encoding, " \t");
            if (encoding.len == 0) return error.InvalidContentEncoding;
            saw_encoding = true;
            if (!std.ascii.eqlIgnoreCase(encoding, "identity")) is_encoded = true;
        }
    }
    if (!saw_encoding) return error.InvalidContentEncoding;
    return if (is_encoded) .encoded else .identity;
}

fn responseContentLength(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !?usize {
    const values = try operation.getHeaderValues(allocator, "Content-Length");
    defer allocator.free(values);
    if (values.len == 0) return null;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) return error.InvalidContentLength;
    const length = std.fmt.parseInt(usize, values[0], 10) catch
        return error.InvalidContentLength;
    if (length == 0) return error.InvalidContentLength;
    return length;
}

const BufferedManifest = struct {
    bytes: []u8,
    digest: [digest_mod.sha256_formatted_length]u8,
};

fn readManifestBody(
    allocator: std.mem.Allocator,
    operation: *core.http.HttpOperation,
    capacity_hint: usize,
    expected_length: ?usize,
) !BufferedManifest {
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    if (capacity_hint > 0) {
        try body.ensureTotalCapacityPrecise(allocator, capacity_hint);
    }

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
        if (expected_length) |length| {
            if (count > length -| total) return error.ContentLengthMismatch;
        }
        try body.appendSlice(allocator, buffer[0..count]);
        digest.update(buffer[0..count]);
        total += count;
    }
    if (expected_length) |length| {
        if (total != length) return error.ContentLengthMismatch;
    }

    return .{
        .bytes = try body.toOwnedSlice(allocator),
        .digest = digest.final(),
    };
}

fn hasPayloadDeinit(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "deinit")) return false;
    const info = @typeInfo(@TypeOf(T.deinit));
    return info == .@"fn" and info.@"fn".params.len == 2;
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

    const identity_mismatch_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Encoding", .value = "identity" },
        .{ .name = "Content-Length", .value = "18" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &identity_mismatch_headers;
    try std.testing.expectError(
        error.ContentLengthMismatch,
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
    try std.testing.expectEqual(@as(usize, 6), transport.call_count);
}

test "download treats compressed content length as an encoded hint" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}";
    const expected_digest = digest_mod.computeSha256Digest(manifest);
    const gzip_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Encoding", .value = "gzip" },
        .{ .name = "Content-Length", .value = "11" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    var transport = core.http.MockTransport.init(allocator, 200, manifest);
    defer transport.deinit();
    transport.response_headers_list = &gzip_headers;
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var gzip_result = try client.downloadManifest("gzip");
    defer gzip_result.deinit(allocator);
    try std.testing.expectEqualStrings(manifest, gzip_result.bytes);

    const other_encoding_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Encoding", .value = "br" },
        .{ .name = "Content-Length", .value = "4194305" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &other_encoding_headers;
    var other_result = try client.downloadManifest("other");
    defer other_result.deinit(allocator);
    try std.testing.expectEqualStrings(manifest, other_result.bytes);

    const chunked_encoded_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Encoding", .value = "gzip" },
        .{ .name = "Docker-Content-Digest", .value = &expected_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_headers_list = &chunked_encoded_headers;
    var chunked_result = try client.downloadManifest("chunked");
    defer chunked_result.deinit(allocator);
    try std.testing.expectEqualStrings(manifest, chunked_result.bytes);
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

    const compressed_boundary_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Encoding", .value = "gzip" },
        .{ .name = "Content-Length", .value = "1024" },
        .{ .name = "Docker-Content-Digest", .value = &boundary_digest },
        .{
            .name = "Content-Type",
            .value = "application/vnd.oci.image.manifest.v1+json",
        },
    };
    transport.response_body = boundary;
    transport.response_headers_list = &compressed_boundary_headers;
    var compressed_boundary = try client.downloadManifest("compressed-boundary");
    defer compressed_boundary.deinit(allocator);
    try std.testing.expectEqual(max_manifest_size, compressed_boundary.bytes.len);

    transport.response_body = streamed_excess;
    try std.testing.expectError(
        error.ManifestTooLarge,
        client.downloadManifest("compressed-too-large"),
    );

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

test "delete requires digest and treats missing manifests as success" {
    const allocator = std.testing.allocator;
    const digest = digest_mod.computeSha256Digest("manifest");
    var transport = core.http.MockTransport.init(allocator, 202, "");
    defer transport.deinit();
    var client = try testClient(allocator, transport.asTransport());
    defer client.deinit();

    var accepted_response = try client.deleteManifestResult(&digest);
    defer accepted_response.deinit(allocator);
    switch (accepted_response) {
        .ok => |outcome| try std.testing.expectEqual(
            client_mod.DeleteOutcome.accepted,
            outcome,
        ),
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expectEqual(
        client_mod.DeleteOutcome.accepted,
        try client.deleteManifest(&digest),
    );
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
        "{\"errors\":[{\"code\":\"MANIFEST_UNKNOWN\",\"message\":\"not found\"}]}";
    try std.testing.expectEqual(
        client_mod.DeleteOutcome.not_found,
        try client.deleteManifest(&digest),
    );
    var missing_response = try client.deleteManifestResult(&digest);
    defer missing_response.deinit(allocator);
    switch (missing_response) {
        .ok => |outcome| try std.testing.expectEqual(
            client_mod.DeleteOutcome.not_found,
            outcome,
        ),
        .err => return error.UnexpectedServiceError,
    }

    transport.response_status = 500;
    transport.response_body =
        "{\"errors\":[{\"code\":\"UNAVAILABLE\",\"message\":\"try later\"}]}";
    var failure_response = try client.deleteManifestResult(&digest);
    defer failure_response.deinit(allocator);
    switch (failure_response) {
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 500), failure.status_code);
            try std.testing.expectEqualStrings("UNAVAILABLE", failure.code.?);
            try std.testing.expectEqualStrings("try later", failure.message.?);
        },
        .ok => return error.ExpectedServiceError,
    }
}

test "streaming manifest operations expose shared structured ACR errors" {
    const allocator = std.testing.allocator;
    const manifest = "{\"schemaVersion\":2}";
    var transport = core.http.MockTransport.init(
        allocator,
        400,
        "{\"errors\":[{\"code\":\"MANIFEST_INVALID\",\"message\":\"bad manifest\",\"detail\":{\"field\":\"schemaVersion\"}}]}",
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
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 400), failure.status_code);
            try std.testing.expectEqualStrings("MANIFEST_INVALID", failure.code.?);
            try std.testing.expectEqualStrings("bad manifest", failure.message.?);
            try std.testing.expectEqual(@as(usize, 1), failure.errors.len);
            try std.testing.expectEqualStrings(
                "{\"field\":\"schemaVersion\"}",
                failure.errors[0].detail.?,
            );
        },
        .ok => return error.ExpectedServiceError,
    }

    transport.response_status = 404;
    transport.response_body =
        "{\"errors\":[{\"code\":\"MANIFEST_UNKNOWN\",\"message\":\"not found\"}]}";
    var download_response = try client.downloadManifestResult("missing");
    defer download_response.deinit(allocator);
    switch (download_response) {
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 404), failure.status_code);
            try std.testing.expectEqualStrings("MANIFEST_UNKNOWN", failure.code.?);
            try std.testing.expectEqualStrings("not found", failure.message.?);
        },
        .ok => return error.ExpectedServiceError,
    }

    const malformed_body =
        "{\"error\":{\"code\":\"MANIFEST_INVALID\",\"message\":\"legacy shape\"}}";
    transport.response_status = 400;
    transport.response_body = malformed_body;
    var malformed_response = try client.uploadManifestResult(
        manifest,
        .{ .reference = "malformed" },
    );
    defer malformed_response.deinit(allocator);
    switch (malformed_response) {
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 400), failure.status_code);
            try std.testing.expect(failure.malformed);
            try std.testing.expect(failure.code == null);
            try std.testing.expectEqualStrings(malformed_body, failure.raw_body.?);
        },
        .ok => return error.ExpectedServiceError,
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
