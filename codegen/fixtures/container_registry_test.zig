const std = @import("std");
const cm = @import("codemodel");

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
