const std = @import("std");
const emitter = @import("emit");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.skip();
    const output_path = args.next() orelse return error.MissingOutputPath;
    var azure_sdk_core_commit: ?[]const u8 = null;
    var azure_sdk_core_hash: ?[]const u8 = null;
    var azure_sdk_core_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--azure-sdk-core-commit")) {
            azure_sdk_core_commit = args.next() orelse return error.MissingAzureSdkCoreCommit;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-hash")) {
            azure_sdk_core_hash = args.next() orelse return error.MissingAzureSdkCoreHash;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-path")) {
            azure_sdk_core_path = args.next() orelse return error.MissingAzureSdkCorePath;
        } else {
            return error.UnexpectedArgument;
        }
    }
    if ((azure_sdk_core_commit == null) != (azure_sdk_core_hash == null)) {
        return error.IncompleteAzureSdkCorePin;
    }
    if (azure_sdk_core_commit != null and azure_sdk_core_path != null) {
        return error.ConflictingAzureSdkCoreDependency;
    }

    var parsed = try std.json.parseFromSlice(
        emitter.CodeModel,
        allocator,
        @embedFile("container_registry.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const parent_path = std.fs.path.dirname(output_path) orelse ".";
    const directory_name = std.fs.path.basename(output_path);
    var parent = if (std.fs.path.isAbsolute(output_path))
        try std.Io.Dir.openDirAbsolute(io, parent_path, .{})
    else
        try std.Io.Dir.cwd().createDirPathOpen(io, parent_path, .{});
    defer parent.close(io);
    if (std.mem.eql(u8, directory_name, ".") or
        std.mem.eql(u8, directory_name, ".."))
    {
        return error.InvalidOutputPath;
    }
    try parent.deleteTree(io, directory_name);
    var output = try parent.createDirPathOpen(io, directory_name, .{});
    defer output.close(io);

    try emitter.emit(allocator, io, output, parsed.value, .{
        .package_name = "azure_rest_container_registry",
        .display_name = "container-registry",
        .azure_sdk_core_commit = azure_sdk_core_commit,
        .azure_sdk_core_hash = azure_sdk_core_hash,
        .azure_sdk_core_path = azure_sdk_core_path orelse "../../sdk/core",
    });
    const zon = try output.readFileAlloc(
        io,
        "build.zig.zon",
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(zon);
    const zon_with_license = try addLicensePath(allocator, zon);
    defer allocator.free(zon_with_license);
    try output.writeFile(io, .{
        .sub_path = "build.zig.zon",
        .data = zon_with_license,
    });
    const license = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        "../../LICENSE.txt",
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(license);
    try output.writeFile(io, .{
        .sub_path = "LICENSE.txt",
        .data = license,
    });
    try output.writeFile(io, .{
        .sub_path = "src/clients_test.zig",
        .data = generated_tests,
    });
    try output.writeFile(io, .{
        .sub_path = "README.md",
        .data = generated_readme,
    });
}

fn addLicensePath(allocator: std.mem.Allocator, zon: []const u8) ![]u8 {
    const marker = "        \"README.md\",\n";
    const index = std.mem.indexOf(u8, zon, marker) orelse
        return error.MissingReadmePath;
    const insertion = marker ++ "        \"LICENSE.txt\",\n";
    const output = try allocator.alloc(
        u8,
        zon.len - marker.len + insertion.len,
    );
    @memcpy(output[0..index], zon[0..index]);
    @memcpy(output[index .. index + insertion.len], insertion);
    @memcpy(
        output[index + insertion.len ..],
        zon[index + marker.len ..],
    );
    return output;
}

const generated_readme =
    \\# Azure Container Registry REST for Zig
    \\
    \\`azure_rest_container_registry` is the generated protocol package for
    \\Azure Container Registry data-plane API version **2021-07-01**.
    \\It is produced from the checked-in TypeSpec code model and is entirely
    \\generator-owned. Do not edit this package by hand; change the emitter or
    \\fixture and regenerate it instead.
    \\
    \\## Protocol surface
    \\
    \\The generated clients expose all 29 stable operations through:
    \\
    \\- `ContainerRegistryClient`
    \\- `ContainerRegistry`
    \\- `ContainerRegistryBlob`
    \\- `Authentication`
    \\
    \\This layer preserves raw protocol request/response types and status
    \\unions. It does not add challenge authentication, safe continuation
    \\validation, digest verification, transfer replay, or domain ownership
    \\helpers. Use `azure_sdk_container_registry` for those behaviors.
    \\
    \\The generated `initWithPipeline` constructor is the protocol escape
    \\hatch for callers that need custom policies or operations not surfaced
    \\by the hand-written package. The supplied pipeline and transport are
    \\borrowed and must outlive every generated client and active operation.
    \\Generated result fields follow their declared allocator ownership; free
    \\or deinitialize every owned body/header/model value shown by the type.
    \\
    \\## Media types
    \\
    \\The REST package transports caller-provided media types. The hand-written
    \\package has first-class upload support for OCI image manifests and Docker
    \\schema-2 manifests and accepts OCI image/index, Docker schema-2
    \\manifest/list/config, ORAS artifact manifest, and wildcard manifest
    \\responses.
    \\
    \\## Build and regeneration
    \\
    \\```bash
    \\zig build test --summary all
    \\gh workflow run generated-package-pr.yml \
    \\  -f target_branch=rest/container_registry \
    \\  -f generator_commit=<main-commit>
    \\```
    \\
    \\The package manifest pins `azure_sdk_core` by immutable commit and Zig
    \\package hash. See the
    \\[package branch model](https://github.com/cataggar/azure-sdk-for-zig/blob/main/doc/package-branch-model.md)
    \\and
    \\[Container Registry release staging](https://github.com/cataggar/azure-sdk-for-zig/blob/main/eng/container_registry_release/README.md).
    \\
;

const generated_tests =
    \\const std = @import("std");
    \\const core = @import("azure_sdk_core");
    \\const serde = @import("serde");
    \\const clients = @import("clients.zig");
    \\const models = @import("models.zig");
    \\
    \\test "all 29 stable operations are directly accessible" {
    \\    try expectPublicMethods(clients.ContainerRegistryClient, &.{
    \\        "containerRegistry",
    \\        "containerRegistryBlob",
    \\        "authentication",
    \\    });
    \\    try expectPublicMethods(clients.ContainerRegistry, &.{
    \\        "checkDockerV2Support",
    \\        "getManifest",
    \\        "createManifest",
    \\        "deleteManifest",
    \\        "getRepositories",
    \\        "getProperties",
    \\        "deleteRepository",
    \\        "updateProperties",
    \\        "getTags",
    \\        "getTagProperties",
    \\        "updateTagAttributes",
    \\        "deleteTag",
    \\        "getManifests",
    \\        "getManifestProperties",
    \\        "updateManifestProperties",
    \\    });
    \\    try expectPublicMethods(clients.ContainerRegistryBlob, &.{
    \\        "getBlob",
    \\        "checkBlobExists",
    \\        "deleteBlob",
    \\        "mountBlob",
    \\        "getUploadStatus",
    \\        "uploadChunk",
    \\        "completeUpload",
    \\        "cancelUpload",
    \\        "startUpload",
    \\        "getChunk",
    \\        "checkChunkExists",
    \\    });
    \\    try expectPublicMethods(clients.Authentication, &.{
    \\        "exchangeAadAccessTokenForAcrRefreshToken",
    \\        "exchangeAcrRefreshTokenForAcrAccessToken",
    \\        "getAcrAccessTokenFromLogin",
    \\    });
    \\}
    \\
    \\fn expectPublicMethods(comptime Client: type, comptime methods: []const []const u8) !void {
    \\    inline for (methods) |method| {
    \\        try std.testing.expect(@hasDecl(Client, method));
    \\    }
    \\}
    \\
    \\const Mock = struct {
    \\    allocator: std.mem.Allocator,
    \\    mode: enum { blob, redirect, multipart, cancel },
    \\    transport: core.http.HttpTransport = undefined,
    \\    calls: usize = 0,
    \\
    \\    fn init(allocator: std.mem.Allocator, mode: @FieldType(@This(), "mode")) @This() {
    \\        var result = @This(){ .allocator = allocator, .mode = mode };
    \\        result.transport = .{ .sendFn = send };
    \\        return result;
    \\    }
    \\
    \\    fn send(transport: *core.http.HttpTransport, request: *core.http.Request) !core.http.Response {
    \\        const self: *@This() = @alignCast(@fieldParentPtr("transport", transport));
    \\        self.calls += 1;
    \\        const headers = std.StringHashMap([]const u8).init(self.allocator);
    \\        var response_headers = core.http.ResponseHeaders.init(self.allocator);
    \\        const status: u16, const body: []u8 = switch (self.mode) {
    \\            .blob => .{
    \\                200,
    \\                try self.blobResponse(request, &response_headers),
    \\            },
    \\            .redirect => .{
    \\                307,
    \\                try self.redirectResponse(request, &response_headers),
    \\            },
    \\            .multipart => .{
    \\                200,
    \\                try self.multipartResponse(request),
    \\            },
    \\            .cancel => .{
    \\                204,
    \\                try self.cancelResponse(request),
    \\            },
    \\        };
    \\        return .{
    \\            .status_code = status,
    \\            .headers = headers,
    \\            .body = body,
    \\            .allocator = self.allocator,
    \\            .response_headers = response_headers,
    \\        };
    \\    }
    \\
    \\    fn blobResponse(
    \\        self: *@This(),
    \\        request: *core.http.Request,
    \\        response_headers: *core.http.ResponseHeaders,
    \\    ) ![]u8 {
    \\        try std.testing.expectEqualStrings(
    \\            "application/octet-stream",
    \\            request.getHeader("Accept").?,
    \\        );
    \\        try std.testing.expect(
    \\            std.mem.indexOf(u8, request.url, "/v2/team/app/blobs/sha256%3Aabc") != null,
    \\        );
    \\        try response_headers.append("Content-Length", "4");
    \\        try response_headers.append("Docker-Content-Digest", "sha256:abc");
    \\        return self.allocator.dupe(u8, "blob");
    \\    }
    \\
    \\    fn redirectResponse(
    \\        self: *@This(),
    \\        request: *core.http.Request,
    \\        response_headers: *core.http.ResponseHeaders,
    \\    ) ![]u8 {
    \\        try std.testing.expectEqual(
    \\            core.http.RedirectPolicy.not_allowed,
    \\            request.redirect_policy,
    \\        );
    \\        try response_headers.append("Location", "https://storage.example/blob");
    \\        return self.allocator.alloc(u8, 0);
    \\    }
    \\
    \\    fn multipartResponse(self: *@This(), request: *core.http.Request) ![]u8 {
    \\        try std.testing.expect(std.mem.startsWith(
    \\            u8,
    \\            request.getHeader("Content-Type").?,
    \\            "multipart/form-data; boundary=",
    \\        ));
    \\        try std.testing.expect(
    \\            std.mem.indexOf(u8, request.body.?, "name=\"grantType\"") != null,
    \\        );
    \\        try std.testing.expect(
    \\            std.mem.indexOf(u8, request.body.?, "access_token") != null,
    \\        );
    \\        return self.allocator.dupe(u8, "{\"refresh_token\":\"token\"}");
    \\    }
    \\
    \\    fn cancelResponse(self: *@This(), request: *core.http.Request) ![]u8 {
    \\        try std.testing.expectEqual(core.http.Method.DELETE, request.method);
    \\        try std.testing.expect(request.body == null);
    \\        try std.testing.expect(request.getHeader("Content-Length") == null);
    \\        try std.testing.expect(request.getHeader("Transfer-Encoding") == null);
    \\        return self.allocator.alloc(u8, 0);
    \\    }
    \\};
    \\
    \\test "generated ACR raw, multipart, statuses, and validated continuations" {
    \\    const allocator = std.testing.allocator;
    \\    var empty = [_]*core.pipeline.HttpPolicy{};
    \\
    \\    var blob_mock = Mock.init(allocator, .blob);
    \\    const blob_pipeline = core.pipeline.HttpPipeline{
    \\        .policies = &empty,
    \\        .transport_impl = &blob_mock.transport,
    \\    };
    \\    var root = clients.ContainerRegistryClient.initWithPipeline(
    \\        allocator,
    \\        blob_pipeline,
    \\        .{ .endpoint = "https://registry.example" },
    \\    );
    \\    var blob_client = root.containerRegistryBlob();
    \\    const blob_result = try blob_client.getBlob(allocator, "team/app", "sha256:abc");
    \\    switch (blob_result) {
    \\        .status_200 => |result| {
    \\            defer allocator.free(result.body);
    \\            defer allocator.free(result.headers.docker_content_digest);
    \\            try std.testing.expectEqualStrings("blob", result.body);
    \\        },
    \\        else => return error.UnexpectedStatus,
    \\    }
    \\
    \\    try std.testing.expectError(
    \\        error.UnexpectedHost,
    \\        blob_client.getUploadStatus(
    \\            allocator,
    \\            "https://evil.example/v2/team/app/blobs/uploads/id",
    \\        ),
    \\    );
    \\    try std.testing.expectEqual(@as(usize, 1), blob_mock.calls);
    \\
    \\    var redirect_mock = Mock.init(allocator, .redirect);
    \\    const redirect_pipeline = core.pipeline.HttpPipeline{
    \\        .policies = &empty,
    \\        .transport_impl = &redirect_mock.transport,
    \\    };
    \\    root = clients.ContainerRegistryClient.initWithPipeline(
    \\        allocator,
    \\        redirect_pipeline,
    \\        .{ .endpoint = "https://registry.example" },
    \\    );
    \\    blob_client = root.containerRegistryBlob();
    \\    const redirected_blob = try blob_client.getBlob(
    \\        allocator,
    \\        "team/app",
    \\        "sha256:abc",
    \\    );
    \\    switch (redirected_blob) {
    \\        .status_307 => |result| {
    \\            defer allocator.free(result.headers.location);
    \\            try std.testing.expectEqualStrings(
    \\                "https://storage.example/blob",
    \\                result.headers.location,
    \\            );
    \\        },
    \\        else => return error.UnexpectedStatus,
    \\    }
    \\    const redirected_exists = try blob_client.checkBlobExists(
    \\        allocator,
    \\        "team/app",
    \\        "sha256:abc",
    \\    );
    \\    switch (redirected_exists) {
    \\        .status_307 => |result| {
    \\            defer allocator.free(result.headers.location);
    \\            try std.testing.expectEqualStrings(
    \\                "https://storage.example/blob",
    \\                result.headers.location,
    \\            );
    \\        },
    \\        else => return error.UnexpectedStatus,
    \\    }
    \\    try std.testing.expectEqual(@as(usize, 2), redirect_mock.calls);
    \\
    \\    var multipart_mock = Mock.init(allocator, .multipart);
    \\    const multipart_pipeline = core.pipeline.HttpPipeline{
    \\        .policies = &empty,
    \\        .transport_impl = &multipart_mock.transport,
    \\    };
    \\    root = clients.ContainerRegistryClient.initWithPipeline(
    \\        allocator,
    \\        multipart_pipeline,
    \\        .{ .endpoint = "https://registry.example" },
    \\    );
    \\    var auth = root.authentication();
    \\    const token = try auth.exchangeAadAccessTokenForAcrRefreshToken(
    \\        allocator,
    \\        .{
    \\            .grant_type = .access_token,
    \\            .service = "registry.example",
    \\            .access_token = "aad-token",
    \\        },
    \\    );
    \\    defer allocator.free(token.refresh_token.?);
    \\    try std.testing.expectEqualStrings("token", token.refresh_token.?);
    \\
    \\    var cancel_mock = Mock.init(allocator, .cancel);
    \\    const cancel_pipeline = core.pipeline.HttpPipeline{
    \\        .policies = &empty,
    \\        .transport_impl = &cancel_mock.transport,
    \\    };
    \\    root = clients.ContainerRegistryClient.initWithPipeline(
    \\        allocator,
    \\        cancel_pipeline,
    \\        .{ .endpoint = "https://registry.example" },
    \\    );
    \\    blob_client = root.containerRegistryBlob();
    \\    try blob_client.cancelUpload(allocator, "/v2/team/app/blobs/uploads/id");
    \\}
    \\
    \\test "generated ACR open records round trip arbitrary JSON" {
    \\    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    \\    defer arena.deinit();
    \\    const allocator = arena.allocator();
    \\    const value = try serde.json.fromSlice(
    \\        models.Annotations,
    \\        allocator,
    \\        "{\"org.opencontainers.image.created\":\"2026-01-01T00:00:00Z\",\"count\":3,\"nested\":{\"ok\":true}}",
    \\    );
    \\    try std.testing.expectEqualStrings("2026-01-01T00:00:00Z", value.created.?);
    \\    try std.testing.expect(value.additional_properties.get("count").? == .integer);
    \\    try std.testing.expect(value.additional_properties.get("nested").? == .object);
    \\    const encoded = try serde.json.toSlice(allocator, value);
    \\    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"count\":3") != null);
    \\}
    \\
;
