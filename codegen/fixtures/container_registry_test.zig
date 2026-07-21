const std = @import("std");
const cm = @import("codemodel");
const emitter = @import("emit");

fn findMethod(model: cm.CodeModel, name: []const u8) ?cm.Method {
    for (model.clients) |client| {
        for (client.methods) |method| {
            if (std.mem.eql(u8, method.name, name)) return method;
        }
    }
    return null;
}

fn findModel(model: cm.CodeModel, name: []const u8) ?cm.Model {
    for (model.models) |item| {
        if (std.mem.eql(u8, item.name, name)) return item;
    }
    return null;
}

fn hasStatus(statuses: []const std.json.Value, expected: i64) bool {
    for (statuses) |status| {
        switch (status) {
            .integer => |value| if (value == expected) return true,
            else => {},
        }
    }
    return false;
}

fn expectMethodSet(
    methods: []const cm.Method,
    expected: []const []const u8,
) !void {
    const testing = std.testing;
    try testing.expectEqual(expected.len, methods.len);
    for (expected) |expected_name| {
        var matches: usize = 0;
        for (methods) |method| {
            if (std.mem.eql(u8, method.name, expected_name)) matches += 1;
        }
        try testing.expectEqual(@as(usize, 1), matches);
    }
    for (methods) |method| {
        var found = false;
        for (expected) |expected_name| {
            if (std.mem.eql(u8, method.name, expected_name)) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

fn renderWireContract(
    allocator: std.mem.Allocator,
    model: cm.CodeModel,
) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;

    for (model.clients) |client| {
        for (client.methods) |method| {
            try writer.print(
                "{s}|{s}|{s}|{s}|P[",
                .{
                    method.name,
                    method.http_method,
                    method.path,
                    method.uri_template orelse "-",
                },
            );
            try writeWireParameters(writer, method.path_parameters, true);
            try writer.writeAll("]|Q[");
            try writeWireParameters(writer, method.query_parameters, false);
            try writer.writeAll("]|H[");
            try writeWireParameters(writer, method.header_parameters, false);
            try writer.writeAll("]|B[");
            if (method.body_parameter) |body| {
                try writer.print(
                    "{s}:{s}:",
                    .{ body.serialization_kind, body.content_type },
                );
                try writeTypeRef(writer, body.body_type);
            } else {
                try writer.writeByte('-');
            }
            try writer.writeAll("]|R[");
            for (method.responses, 0..) |response, response_index| {
                if (response_index != 0) try writer.writeByte(';');
                for (response.status_codes, 0..) |status, status_index| {
                    if (status_index != 0) try writer.writeByte(',');
                    switch (status) {
                        .integer => |value| try writer.print("{d}", .{value}),
                        .string => |value| try writer.writeAll(value),
                        else => try writer.writeByte('?'),
                    }
                }
                try writer.print(":{s}:", .{response.body_kind});
                try writeTypeRef(writer, response.response_type);
                try writer.writeByte(':');
                if (response.headers.len == 0) {
                    try writer.writeByte('-');
                } else {
                    for (response.headers, 0..) |header, header_index| {
                        if (header_index != 0) try writer.writeByte(',');
                        try writer.print(
                            "{s}:{s}:",
                            .{
                                header.wire_name,
                                if (header.optional) "optional" else "required",
                            },
                        );
                        try writeTypeRef(writer, header.header_type);
                    }
                }
            }
            try writer.writeAll("]\n");
        }
    }

    return try output.toOwnedSlice();
}

fn writeWireParameters(
    writer: *std.Io.Writer,
    parameters: []const cm.WireParameter,
    include_path_metadata: bool,
) !void {
    if (parameters.len == 0) {
        try writer.writeByte('-');
        return;
    }
    for (parameters, 0..) |parameter, index| {
        if (index != 0) try writer.writeByte(',');
        const source_value = parameter.source.name orelse
            parameter.source.value orelse "-";
        try writer.print(
            "{s}={s}:{s}:{s}",
            .{
                parameter.wire_name,
                parameter.source.kind,
                source_value,
                if (parameter.optional) "optional" else "required",
            },
        );
        if (include_path_metadata) {
            try writer.print(
                ":{s}:{s}",
                .{
                    parameter.path_encoding orelse "-",
                    if (parameter.allow_reserved orelse false)
                        "reserved"
                    else
                        "encoded",
                },
            );
        }
    }
}

fn writeTypeRef(writer: *std.Io.Writer, type_ref: ?cm.TypeRef) !void {
    const value = type_ref orelse {
        try writer.writeByte('-');
        return;
    };
    try writer.writeAll(value.kind);
    switch (value.value) {
        .string => |name| try writer.print(":{s}", .{name}),
        else => {},
    }
}

test "Container Registry fixture pins every operation wire signature" {
    const testing = std.testing;
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        @embedFile("container_registry.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const actual = try renderWireContract(testing.allocator, parsed.value);
    defer testing.allocator.free(actual);
    const expected =
        \\check_docker_v2_support|get|/v2/|/v2/{?api%2Dversion}|P[-]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[200:none:-:-]
        \\get_manifest|get|/v2/{name}/manifests/{reference}|/v2/{name}/manifests/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[accept=user:accept:optional]|B[-]|R[200:json:Model:ManifestWrapper:-]
        \\create_manifest|put|/v2/{name}/manifests/{reference}|/v2/{name}/manifests/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Content-Type=constant:application/vnd.docker.distribution.manifest.v2+json:required]|B[json:application/vnd.docker.distribution.manifest.v2+json:Model:Manifest]|R[201:none:-:Location:required:Scalar:string,Content-Length:required:Scalar:int64,Docker-Content-Digest:required:Scalar:string]
        \\delete_manifest|delete|/v2/{name}/manifests/{reference}|/v2/{name}/manifests/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[202:none:-:-;404:none:-:-]
        \\get_repositories|get|/acr/v1/_catalog|/acr/v1/_catalog{?api%2Dversion,last,n}|P[-]|Q[api-version=client:api_version:required,last=user:last:optional,n=user:n:optional]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:Repositories:Link:optional:Scalar:string]
        \\get_properties|get|/acr/v1/{name}|/acr/v1/{name}{?api%2Dversion}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:ContainerRepositoryProperties:-]
        \\delete_repository|delete|/acr/v1/{name}|/acr/v1/{name}{?api%2Dversion}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[202:none:-:-;404:none:-:-]
        \\update_properties|patch|/acr/v1/{name}|/acr/v1/{name}{?api%2Dversion}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required]|H[Content-Type=constant:application/json:optional,Accept=constant:application/json:required]|B[json:application/json:Model:RepositoryChangeableAttributes]|R[200:json:Model:ContainerRepositoryProperties:-]
        \\get_tags|get|/acr/v1/{name}/_tags|/acr/v1/{name}/_tags{?api%2Dversion,last,n,orderby,digest}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required,last=user:last:optional,n=user:n:optional,orderby=user:orderby:optional,digest=user:digest:optional]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:TagList:Link:optional:Scalar:string]
        \\get_tag_properties|get|/acr/v1/{name}/_tags/{reference}|/acr/v1/{name}/_tags/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:ArtifactTagProperties:-]
        \\update_tag_attributes|patch|/acr/v1/{name}/_tags/{reference}|/acr/v1/{name}/_tags/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Content-Type=constant:application/json:optional,Accept=constant:application/json:required]|B[json:application/json:Model:TagChangeableAttributes]|R[200:json:Model:ArtifactTagProperties:-]
        \\delete_tag|delete|/acr/v1/{name}/_tags/{reference}|/acr/v1/{name}/_tags/{reference}{?api%2Dversion}|P[name=user:name:required:repository:encoded,reference=user:reference:required:segment:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[202:none:-:-;404:none:-:-]
        \\get_manifests|get|/acr/v1/{name}/_manifests|/acr/v1/{name}/_manifests{?api%2Dversion,last,n,orderby}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required,last=user:last:optional,n=user:n:optional,orderby=user:orderby:optional]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:AcrManifests:Link:optional:Scalar:string]
        \\get_manifest_properties|get|/acr/v1/{name}/_manifests/{digest}|/acr/v1/{name}/_manifests/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:ArtifactManifestProperties:-]
        \\update_manifest_properties|patch|/acr/v1/{name}/_manifests/{digest}|/acr/v1/{name}/_manifests/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Content-Type=constant:application/json:optional,Accept=constant:application/json:required]|B[json:application/json:Model:ManifestChangeableAttributes]|R[200:json:Model:ArtifactManifestProperties:-]
        \\get_blob|get|/v2/{name}/blobs/{digest}|/v2/{name}/blobs/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[Accept=constant:application/octet-stream:required]|B[-]|R[200:raw:Scalar:bytes:Content-Length:required:Scalar:int64,Docker-Content-Digest:required:Scalar:string;307:none:-:Location:required:Scalar:string]
        \\check_blob_exists|head|/v2/{name}/blobs/{digest}|/v2/{name}/blobs/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[200:none:-:Content-Length:required:Scalar:int64,Docker-Content-Digest:required:Scalar:string;307:none:-:Location:required:Scalar:string]
        \\delete_blob|delete|/v2/{name}/blobs/{digest}|/v2/{name}/blobs/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[202:none:-:Docker-Content-Digest:required:Scalar:string]
        \\mount_blob|post|/v2/{name}/blobs/uploads/|/v2/{name}/blobs/uploads/{?api%2Dversion,from,mount}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required,from=user:from:required,mount=user:mount:required]|H[-]|B[-]|R[201:none:-:Location:required:Scalar:string,Docker-Upload-UUID:required:Scalar:string,Docker-Content-Digest:required:Scalar:string]
        \\get_upload_status|get|/{nextBlobUuidLink}|/{+nextBlobUuidLink}{?api%2Dversion}|P[nextBlobUuidLink=user:next_blob_uuid_link:required:greedy:reserved]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[204:none:-:Range:required:Scalar:string,Docker-Upload-UUID:required:Scalar:string]
        \\upload_chunk|patch|/{nextBlobUuidLink}|/{+nextBlobUuidLink}{?api%2Dversion}|P[nextBlobUuidLink=user:next_blob_uuid_link:required:greedy:reserved]|Q[api-version=client:api_version:required]|H[Content-Type=constant:application/octet-stream:required]|B[raw:application/octet-stream:Scalar:bytes]|R[202:none:-:Location:required:Scalar:string,Range:required:Scalar:string,Docker-Upload-UUID:required:Scalar:string]
        \\complete_upload|put|/{nextBlobUuidLink}|/{+nextBlobUuidLink}{?api%2Dversion,digest}|P[nextBlobUuidLink=user:next_blob_uuid_link:required:greedy:reserved]|Q[api-version=client:api_version:required,digest=user:digest:required]|H[Content-Type=constant:application/octet-stream:optional]|B[raw:application/octet-stream:Scalar:bytes]|R[201:none:-:Location:required:Scalar:string,Range:required:Scalar:string,Docker-Content-Digest:required:Scalar:string]
        \\cancel_upload|delete|/{nextBlobUuidLink}|/{+nextBlobUuidLink}{?api%2Dversion}|P[nextBlobUuidLink=user:next_blob_uuid_link:required:greedy:reserved]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[204:none:-:-]
        \\start_upload|post|/v2/{name}/blobs/uploads/|/v2/{name}/blobs/uploads/{?api%2Dversion}|P[name=user:name:required:repository:encoded]|Q[api-version=client:api_version:required]|H[-]|B[-]|R[202:none:-:Location:required:Scalar:string,Range:required:Scalar:string,Docker-Upload-UUID:required:Scalar:string]
        \\get_chunk|get|/v2/{name}/blobs/{digest}|/v2/{name}/blobs/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[range=user:range:required,Accept=constant:application/octet-stream:required]|B[-]|R[206:raw:Scalar:bytes:Content-Length:required:Scalar:int64,Content-Range:required:Scalar:string]
        \\check_chunk_exists|head|/v2/{name}/blobs/{digest}|/v2/{name}/blobs/{digest}{?api%2Dversion}|P[name=user:name:required:repository:encoded,digest=user:digest:required:segment:encoded]|Q[api-version=client:api_version:required]|H[range=user:range:required]|B[-]|R[200:none:-:Content-Length:required:Scalar:int64,Content-Range:required:Scalar:string]
        \\exchange_aad_access_token_for_acr_refresh_token|post|/oauth2/exchange|/oauth2/exchange|P[-]|Q[-]|H[content-type=constant:multipart/form-data:required,Accept=constant:application/json:required]|B[multipart:multipart/form-data:Model:MultipartBodyParameter]|R[200:json:Model:AcrRefreshToken:-]
        \\exchange_acr_refresh_token_for_acr_access_token|post|/oauth2/token|/oauth2/token|P[-]|Q[-]|H[content-type=constant:multipart/form-data:required,Accept=constant:application/json:required]|B[multipart:multipart/form-data:Model:MultipartBodyParameter]|R[200:json:Model:AcrAccessToken:-]
        \\get_acr_access_token_from_login|get|/oauth2/token|/oauth2/token{?api%2Dversion,service,scope}|P[-]|Q[api-version=client:api_version:required,service=user:service:required,scope=user:scope:required]|H[Accept=constant:application/json:required]|B[-]|R[200:json:Model:AcrAccessToken:-]
    ++ "\n";
    try testing.expectEqualStrings(expected, actual);
}

test "Container Registry fixture preserves the complete wire contract" {
    const testing = std.testing;
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        @embedFile("container_registry.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    const model = parsed.value;

    try testing.expectEqualStrings("container_registry", model.package_name);
    try testing.expectEqual(@as(usize, 4), model.clients.len);
    try testing.expectEqualStrings("ContainerRegistryClient", model.clients[0].name);

    var operation_group_count: usize = 0;
    var operation_count: usize = 0;
    var registry_group_seen = false;
    var blob_group_seen = false;
    var authentication_group_seen = false;
    for (model.clients) |client| {
        try testing.expectEqualStrings("2021-07-01", client.api_version_default.?);
        operation_count += client.methods.len;
        if (!client.is_root) {
            operation_group_count += 1;
            if (std.mem.eql(u8, client.name, "ContainerRegistry")) {
                try expectMethodSet(client.methods, &.{
                    "check_docker_v2_support",
                    "get_manifest",
                    "create_manifest",
                    "delete_manifest",
                    "get_repositories",
                    "get_properties",
                    "delete_repository",
                    "update_properties",
                    "get_tags",
                    "get_tag_properties",
                    "update_tag_attributes",
                    "delete_tag",
                    "get_manifests",
                    "get_manifest_properties",
                    "update_manifest_properties",
                });
                registry_group_seen = true;
            } else if (std.mem.eql(u8, client.name, "ContainerRegistryBlob")) {
                try expectMethodSet(client.methods, &.{
                    "get_blob",
                    "check_blob_exists",
                    "delete_blob",
                    "mount_blob",
                    "get_upload_status",
                    "upload_chunk",
                    "complete_upload",
                    "cancel_upload",
                    "start_upload",
                    "get_chunk",
                    "check_chunk_exists",
                });
                blob_group_seen = true;
            } else if (std.mem.eql(u8, client.name, "Authentication")) {
                try expectMethodSet(client.methods, &.{
                    "exchange_aad_access_token_for_acr_refresh_token",
                    "exchange_acr_refresh_token_for_acr_access_token",
                    "get_acr_access_token_from_login",
                });
                authentication_group_seen = true;
            } else {
                return error.UnexpectedOperationGroup;
            }
        }
    }
    try testing.expectEqual(@as(usize, 3), operation_group_count);
    try testing.expectEqual(@as(usize, 29), operation_count);
    try testing.expect(registry_group_seen);
    try testing.expect(blob_group_seen);
    try testing.expect(authentication_group_seen);

    const upload_chunk = findMethod(model, "upload_chunk").?;
    try testing.expectEqualStrings("raw", upload_chunk.body_parameter.?.serialization_kind);
    try testing.expectEqualStrings(
        "/{+nextBlobUuidLink}{?api%2Dversion}",
        upload_chunk.uri_template.?,
    );
    try testing.expect(upload_chunk.path_parameters[0].allow_reserved.?);
    try testing.expectEqualStrings(
        "greedy",
        upload_chunk.path_parameters[0].path_encoding.?,
    );

    const get_blob_path = findMethod(model, "get_blob").?;
    try testing.expectEqualStrings(
        "repository",
        get_blob_path.path_parameters[0].path_encoding.?,
    );
    try testing.expectEqualStrings(
        "segment",
        get_blob_path.path_parameters[1].path_encoding.?,
    );

    const exchange = findMethod(
        model,
        "exchange_aad_access_token_for_acr_refresh_token",
    ).?;
    try testing.expectEqualStrings("multipart", exchange.body_parameter.?.serialization_kind);
    try testing.expectEqualStrings(
        "MultipartBodyParameter",
        exchange.body_parameter.?.body_type.?.namedTypeName().?,
    );

    const multipart = findModel(model, "MultipartBodyParameter").?;
    try testing.expect(multipart.is_input);
    try testing.expect(!multipart.is_output);
    try testing.expectEqual(@as(usize, 5), multipart.fields.len);
    for (multipart.fields) |field| {
        try testing.expect(field.multipart != null);
        try testing.expectEqualStrings("text/plain", field.multipart.?.content_types[0]);
    }

    const manifest = findModel(model, "Manifest").?;
    try testing.expect(manifest.is_input);
    try testing.expect(!manifest.is_output);

    for ([_][]const u8{
        "RepositoryChangeableAttributes",
        "TagChangeableAttributes",
        "ManifestChangeableAttributes",
    }) |name| {
        try testing.expect(findModel(model, name).?.is_input);
    }

    const access_token = findModel(model, "AcrAccessToken").?;
    try testing.expect(!access_token.is_input);
    try testing.expect(access_token.is_output);

    const get_manifest = findMethod(model, "get_manifest").?;
    try testing.expectEqualStrings("user", get_manifest.header_parameters[0].source.kind);
    try testing.expectEqualStrings("accept", get_manifest.header_parameters[0].source.name.?);

    const create_manifest = findMethod(model, "create_manifest").?;
    try testing.expect(hasStatus(create_manifest.response.status_codes, 201));
    try testing.expectEqual(@as(usize, 3), create_manifest.responses[0].headers.len);
    try testing.expectEqualStrings(
        "Docker-Content-Digest",
        create_manifest.responses[0].headers[2].wire_name,
    );

    const get_blob = findMethod(model, "get_blob").?;
    try testing.expectEqual(@as(usize, 2), get_blob.responses.len);
    try testing.expect(hasStatus(get_blob.responses[0].status_codes, 200));
    try testing.expect(hasStatus(get_blob.responses[1].status_codes, 307));
    try testing.expectEqualStrings("raw", get_blob.responses[0].body_kind);
    try testing.expectEqualStrings("Location", get_blob.responses[1].headers[0].wire_name);

    const repositories = findMethod(model, "get_repositories").?;
    try testing.expectEqualStrings("repositories", repositories.paging.?.items_segments[0].?);
    try testing.expectEqualStrings("link", repositories.paging.?.next_link_segments[0].?);
    try testing.expectEqualStrings("Link", repositories.responses[0].headers[0].wire_name);

    var union_enum_count: usize = 0;
    for (model.enums) |item| {
        if (item.is_union) union_enum_count += 1;
    }
    try testing.expectEqual(@as(usize, 6), union_enum_count);

    const annotations = findModel(model, "Annotations").?;
    try testing.expect(annotations.additional_properties.?.isMap());
    const map_value = annotations.additional_properties.?.value.object.get("value").?;
    try testing.expectEqualStrings("unknown", map_value.string);
}

test "Container Registry golden preserves protocol fidelity" {
    const testing = std.testing;
    const allocator = testing.allocator;
    var parsed = try std.json.parseFromSlice(
        emitter.CodeModel,
        allocator,
        @embedFile("container_registry.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const clients = try emitter.renderClients(allocator, parsed.value);
    defer allocator.free(clients);
    try expectValidZig(allocator, clients);
    try testing.expect(std.mem.indexOf(u8, clients, "pub fn initWithPipeline(") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "core.url.encodeRepositoryName(alloc, name)") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "core.url.expandGreedyPathValue(alloc, next_blob_uuid_link)") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "core.url.resolveAndValidateUrl(") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "&.{endpoint_host.bytes}") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "core.url.resolveUrl(") == null);
    try testing.expect(std.mem.indexOf(u8, clients, "try req.setHeader(\"range\", range);") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "if (accept) |value| try req.setHeader(\"accept\", value);") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "req.body = value;") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "multipart/form-data; boundary=azure-sdk-for-zig-acr-boundary") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "pub const GetBlobResult = union(enum)") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "status_307: struct") != null);
    try testing.expectEqual(
        @as(usize, 2),
        std.mem.count(u8, clients, "req.redirect_policy = .not_allowed;"),
    );
    try testing.expect(std.mem.indexOf(u8, clients, "status_404: struct") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "status_206: struct") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "pub const CancelUploadResult") == null);
    try testing.expect(std.mem.indexOf(u8, clients, "pub fn cancelUpload(") != null);
    try testing.expect(std.mem.indexOf(u8, clients, "const response_body = try bufferRawResponseBody(alloc, resp.body);") != null);

    const models = try emitter.renderModels(allocator, parsed.value);
    defer allocator.free(models);
    try expectValidZig(allocator, models);
    try testing.expect(std.mem.indexOf(u8, models, "pub const JsonValue = union(enum)") != null);
    try testing.expect(std.mem.indexOf(u8, models, "additional_properties: std.StringArrayHashMapUnmanaged(JsonValue) = .empty") != null);
    try testing.expect(std.mem.indexOf(u8, models, ".created = \"org.opencontainers.image.created\"") != null);
}

fn expectValidZig(allocator: std.mem.Allocator, source: []const u8) !void {
    const zsource = try allocator.dupeZ(u8, source);
    defer allocator.free(zsource);
    var tree = try std.zig.Ast.parse(allocator, zsource, .zig);
    defer tree.deinit(allocator);
    for (tree.errors) |parse_error| {
        const location = tree.tokenLocation(0, parse_error.token);
        std.debug.print(
            "generated parse error {s} at {d}:{d}: {s}\n",
            .{
                @tagName(parse_error.tag),
                location.line + 1,
                location.column + 1,
                sourceLine(source, location.line),
            },
        );
    }

    try std.testing.expectEqual(@as(usize, 0), tree.errors.len);
}

fn sourceLine(source: []const u8, target_line: usize) []const u8 {
    var lines = std.mem.splitScalar(u8, source, '\n');
    var line: usize = 0;
    while (lines.next()) |value| : (line += 1) {
        if (line == target_line) return value;
    }
    return "";
}
