// SPDX-License-Identifier: MIT

const std = @import("std");
const cm = @import("codemodel");

const ProvenanceDocument = struct {
    provenance: struct {
        source_repository: []const u8,
        source_path: []const u8,
        source_commit: []const u8,
        stable_api_versions: [][]const u8,
        selected_api_version: []const u8,
        batch_operation: []const u8,
    },
};

fn findClient(model: cm.CodeModel, name: []const u8) ?cm.Client {
    for (model.clients) |client| {
        if (std.mem.eql(u8, client.name, name)) return client;
    }
    return null;
}

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

fn findField(model: cm.Model, name: []const u8) ?cm.Field {
    for (model.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return field;
    }
    return null;
}

fn findResponseHeader(method: cm.Method, wire_name: []const u8) ?cm.ResponseHeader {
    for (method.responses) |response| {
        for (response.headers) |header| {
            if (std.mem.eql(u8, header.wire_name, wire_name)) return header;
        }
    }
    return null;
}

fn hasWireParameter(parameters: []const cm.WireParameter, wire_name: []const u8) bool {
    for (parameters) |parameter| {
        if (std.mem.eql(u8, parameter.wire_name, wire_name)) return true;
    }
    return false;
}

fn expectMethodSet(methods: []const cm.Method, expected: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, methods.len);
    for (expected) |expected_name| {
        var matches: usize = 0;
        for (methods) |method| {
            if (std.mem.eql(u8, method.name, expected_name)) matches += 1;
        }
        try std.testing.expectEqual(@as(usize, 1), matches);
    }
}

fn expectStatus(status: std.json.Value, expected: i64) !void {
    try std.testing.expect(status == .integer);
    try std.testing.expectEqual(expected, status.integer);
}

test "Tables fixture pins canonical provenance and newest stable version" {
    const testing = std.testing;
    const fixture = @embedFile("data_tables.json");
    var provenance = try std.json.parseFromSlice(
        ProvenanceDocument,
        testing.allocator,
        fixture,
        .{ .ignore_unknown_fields = true },
    );
    defer provenance.deinit();

    const pinned = provenance.value.provenance;
    try testing.expectEqualStrings(
        "https://github.com/Azure/azure-rest-api-specs",
        pinned.source_repository,
    );
    try testing.expectEqualStrings(
        "specification/cosmos-db/data-plane/Tables/tspconfig.yaml",
        pinned.source_path,
    );
    try testing.expectEqualStrings(
        "0744f52a86919d243ba2225e55bdb9c87bf521a5",
        pinned.source_commit,
    );
    try testing.expectEqual(@as(usize, 1), pinned.stable_api_versions.len);
    try testing.expectEqualStrings("2019-02-02", pinned.stable_api_versions[0]);
    try testing.expectEqualStrings(
        pinned.stable_api_versions[pinned.stable_api_versions.len - 1],
        pinned.selected_api_version,
    );
    try testing.expectEqualStrings("absent", pinned.batch_operation);

    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        fixture,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    try testing.expectEqualStrings("data_tables", parsed.value.package_name);
    for (parsed.value.clients) |client| {
        try testing.expectEqualStrings(
            pinned.selected_api_version,
            client.api_version_default.?,
        );
    }
}

test "Tables fixture inventories every canonical operation" {
    const testing = std.testing;
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        @embedFile("data_tables.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    const model = parsed.value;

    try testing.expectEqual(@as(usize, 3), model.clients.len);
    const root = findClient(model, "TablesClient").?;
    try testing.expect(root.is_root);
    try testing.expectEqual(@as(usize, 0), root.methods.len);
    try testing.expectEqual(@as(usize, 2), root.sub_clients.len);
    try testing.expectEqual(@as(usize, 1), root.credential_scopes.len);
    try testing.expectEqualStrings(
        "https://storage.azure.com/.default",
        root.credential_scopes[0],
    );

    const table = findClient(model, "Table").?;
    try testing.expectEqualStrings("TablesClient", table.parent_name.?);
    try expectMethodSet(table.methods, &.{
        "query",
        "create",
        "delete",
        "query_entities",
        "query_entity_with_partition_and_row_key",
        "update_entity",
        "merge_entity",
        "delete_entity",
        "insert_entity",
        "get_access_policy",
        "set_access_policy",
    });

    const service = findClient(model, "Service").?;
    try testing.expectEqualStrings("TablesClient", service.parent_name.?);
    try expectMethodSet(service.methods, &.{
        "set_properties",
        "get_properties",
        "get_statistics",
    });

    var operation_count: usize = 0;
    for (model.clients) |client| {
        operation_count += client.methods.len;
        for (client.methods) |method| {
            try testing.expect(
                std.mem.indexOf(u8, method.name, "batch") == null,
            );
            try testing.expect(
                std.mem.indexOf(u8, method.path, "$batch") == null,
            );
        }
    }
    try testing.expectEqual(@as(usize, 14), operation_count);
}

test "Tables fixture preserves statuses headers routes and continuations" {
    const testing = std.testing;
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        @embedFile("data_tables.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    const model = parsed.value;

    const expected = [_]struct {
        name: []const u8,
        statuses: []const i64,
    }{
        .{ .name = "query", .statuses = &.{200} },
        .{ .name = "create", .statuses = &.{ 201, 204 } },
        .{ .name = "delete", .statuses = &.{204} },
        .{ .name = "query_entities", .statuses = &.{200} },
        .{ .name = "query_entity_with_partition_and_row_key", .statuses = &.{200} },
        .{ .name = "update_entity", .statuses = &.{204} },
        .{ .name = "merge_entity", .statuses = &.{204} },
        .{ .name = "delete_entity", .statuses = &.{204} },
        .{ .name = "insert_entity", .statuses = &.{ 201, 204 } },
        .{ .name = "get_access_policy", .statuses = &.{200} },
        .{ .name = "set_access_policy", .statuses = &.{204} },
        .{ .name = "set_properties", .statuses = &.{202} },
        .{ .name = "get_properties", .statuses = &.{200} },
        .{ .name = "get_statistics", .statuses = &.{200} },
    };
    for (expected) |item| {
        const method = findMethod(model, item.name).?;
        try testing.expectEqual(item.statuses.len, method.responses.len);
        for (item.statuses, method.responses) |status, response| {
            try testing.expectEqual(@as(usize, 1), response.status_codes.len);
            try expectStatus(response.status_codes[0], status);
        }
        try testing.expectEqual(@as(usize, 1), method.exceptions.len);
        try testing.expectEqual(@as(usize, 1), method.exceptions[0].status_codes.len);
        try testing.expectEqualStrings(
            "*",
            method.exceptions[0].status_codes[0].string,
        );
    }

    const query = findMethod(model, "query").?;
    try testing.expect(hasWireParameter(query.query_parameters, "NextTableName"));
    try testing.expect(findResponseHeader(
        query,
        "x-ms-continuation-NextTableName",
    ) != null);
    try testing.expectEqualStrings("value", query.paging.?.items_segments[0].?);
    try testing.expectEqualStrings(
        "TableProperties",
        query.paging.?.item_type.?.namedTypeName().?,
    );

    const query_entities = findMethod(model, "query_entities").?;
    for ([_][]const u8{ "NextPartitionKey", "NextRowKey" }) |name| {
        try testing.expect(hasWireParameter(query_entities.query_parameters, name));
    }
    for ([_][]const u8{
        "x-ms-continuation-NextPartitionKey",
        "x-ms-continuation-NextRowKey",
    }) |name| {
        try testing.expect(findResponseHeader(query_entities, name) != null);
    }

    for ([_][]const u8{
        "query_entity_with_partition_and_row_key",
        "update_entity",
        "merge_entity",
        "insert_entity",
    }) |name| {
        const header = findResponseHeader(findMethod(model, name).?, "ETag").?;
        try testing.expectEqualStrings("e_tag", header.name);
        try testing.expect(!header.optional);
    }
    try testing.expect(hasWireParameter(
        findMethod(model, "delete_entity").?.header_parameters,
        "If-Match",
    ));

    const route_expectations = [_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "get_access_policy", .path = "/{table}?comp=acl" },
        .{ .name = "set_access_policy", .path = "/{table}?comp=acl" },
        .{ .name = "set_properties", .path = "?restype=service&comp=properties" },
        .{ .name = "get_properties", .path = "?restype=service&comp=properties" },
        .{ .name = "get_statistics", .path = "?restype=service&comp=stats" },
    };
    for (route_expectations) |item| {
        try testing.expectEqualStrings(item.path, findMethod(model, item.name).?.path);
    }
}

test "Tables fixture preserves JSON open records OData XML and customizations" {
    const testing = std.testing;
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        testing.allocator,
        @embedFile("data_tables.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();
    const model = parsed.value;

    const entity_query = findModel(model, "TableEntityQueryResponse").?;
    const entities = findField(entity_query, "value").?.field_type;
    try testing.expect(entities.isArray());
    const entity_type = entities.value.object;
    try testing.expectEqualStrings("Map", entity_type.get("kind").?.string);
    const map_value = entity_type.get("value").?.object;
    try testing.expectEqualStrings("Scalar", map_value.get("kind").?.string);
    try testing.expectEqualStrings("unknown", map_value.get("value").?.string);

    const get_entity = findMethod(
        model,
        "query_entity_with_partition_and_row_key",
    ).?;
    try testing.expect(get_entity.responses[0].response_type.?.isMap());
    const open_value = get_entity.responses[0].response_type.?.value.object;
    try testing.expectEqualStrings("Scalar", open_value.get("kind").?.string);
    try testing.expectEqualStrings("unknown", open_value.get("value").?.string);

    const table_properties = findModel(model, "TableProperties").?;
    try testing.expectEqualStrings(
        "odata.type",
        findField(table_properties, "odata_type").?.serialized_name,
    );
    try testing.expectEqualStrings(
        "odata.id",
        findField(table_properties, "odata_id").?.serialized_name,
    );
    try testing.expectEqualStrings(
        "odata.editLink",
        findField(table_properties, "odata_edit_link").?.serialized_name,
    );
    try testing.expectEqualStrings(
        "odata.metadata",
        findField(findModel(model, "TableQueryResponse").?, "odata_metadata").?.serialized_name,
    );

    for ([_][]const u8{
        "SignedIdentifiers",
        "SignedIdentifier",
        "AccessPolicy",
        "TableServiceProperties",
        "Logging",
        "RetentionPolicy",
        "Metrics",
        "CorsRule",
        "TableServiceStats",
        "GeoReplication",
        "TablesServiceError",
    }) |name| {
        try testing.expect(findModel(model, name).?.is_xml);
    }
    try testing.expectEqualStrings(
        "SignedIdentifiers",
        findModel(model, "SignedIdentifiers").?.xml_name.?,
    );
    try testing.expectEqualStrings(
        "StorageServiceProperties",
        findModel(model, "TableServiceProperties").?.xml_name.?,
    );
    try testing.expectEqualStrings(
        "StorageServiceStats",
        findModel(model, "TableServiceStats").?.xml_name.?,
    );
    try testing.expectEqualStrings(
        "SignedIdentifier",
        findField(findModel(model, "SignedIdentifiers").?, "identifiers").?.xml.?.name,
    );
    try testing.expect(
        findField(findModel(model, "SignedIdentifiers").?, "identifiers").?.xml.?.unwrapped,
    );

    for ([_][]const u8{ "set_access_policy", "set_properties" }) |name| {
        const body = findMethod(model, name).?.body_parameter.?;
        try testing.expectEqualStrings("xml", body.serialization_kind);
        try testing.expectEqualStrings("application/xml", body.content_type);
    }
    for ([_][]const u8{
        "get_access_policy",
        "get_properties",
        "get_statistics",
    }) |name| {
        try testing.expectEqualStrings(
            "xml",
            findMethod(model, name).?.responses[0].body_kind,
        );
    }
    for ([_][]const u8{
        "query",
        "create",
        "query_entities",
        "query_entity_with_partition_and_row_key",
        "insert_entity",
    }) |name| {
        var json_seen = false;
        for (findMethod(model, name).?.responses) |response| {
            if (std.mem.eql(u8, response.body_kind, "json")) json_seen = true;
        }
        try testing.expect(json_seen);
    }

    const signed_identifier = findModel(model, "SignedIdentifier").?;
    const access_policy = findField(signed_identifier, "access_policy").?;
    try testing.expect(!access_policy.optional);
    try testing.expectEqualStrings(
        "AccessPolicy",
        access_policy.field_type.namedTypeName().?,
    );
    try testing.expectEqualStrings(
        "datetime",
        findField(findModel(model, "AccessPolicy").?, "start").?.field_type.value.string,
    );
    try testing.expectEqualStrings(
        "IncludeAPIs",
        findField(findModel(model, "Metrics").?, "include_apis").?.xml.?.name,
    );
}
