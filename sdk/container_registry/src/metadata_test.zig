const std = @import("std");
const core = @import("azure_core");
const client_mod = @import("client.zig");
const models = @import("models.zig");
const service_error = @import("service_error.zig");

const repository_body =
    \\{"registry":"registry.example","imageName":"team/app","createdTime":"2026-01-01T00:00:00Z","lastUpdateTime":"2026-02-01T00:00:00Z","manifestCount":2,"tagCount":3,"changeableAttributes":{"deleteEnabled":true,"writeEnabled":false,"listEnabled":true,"readEnabled":true}}
;

const manifest_body =
    \\{"registry":"registry.example","imageName":"team/app","manifest":{"digest":"sha256:one","imageSize":42,"createdTime":"2026-01-01T00:00:00Z","lastUpdateTime":"2026-02-01T00:00:00Z","architecture":"amd64","os":"linux","references":[{"digest":"sha256:child","architecture":"arm64","os":"linux"}],"configMediaType":"application/vnd.oci.image.config.v1+json","mediaType":"application/vnd.oci.image.manifest.v1+json","tags":["v1","latest"],"changeableAttributes":{"deleteEnabled":true,"writeEnabled":false,"listEnabled":true,"readEnabled":true}}}
;

const tag_body =
    \\{"registry":"registry.example","imageName":"team/app","tag":{"name":"release/candidate","digest":"sha256:one","createdTime":"2026-01-01T00:00:00Z","lastUpdateTime":"2026-02-01T00:00:00Z","signed":false,"changeableAttributes":{"deleteEnabled":true,"writeEnabled":false,"listEnabled":true,"readEnabled":true}}}
;

test "metadata methods are public" {
    inline for (.{
        "listRepositories",
        "getRepositoryProperties",
        "updateRepositoryProperties",
        "deleteRepository",
        "listManifestProperties",
        "getManifestProperties",
        "updateManifestProperties",
        "deleteManifest",
        "listTagProperties",
        "getTagProperties",
        "updateTagProperties",
        "deleteTag",
    }) |method| {
        try std.testing.expect(@hasDecl(client_mod.ContainerRegistryClient, method));
    }
}

test "repository pager follows a relative Link anonymously" {
    const allocator = std.testing.allocator;
    const first_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Link",
            .value = "</acr/v1/_catalog?api-version=2021-07-01&last=team%2Fapp&n=2>; rel=\"next\"",
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"repositories\":[\"alpha\",\"team/app\"]}",
            .headers = &first_headers,
        },
        .{ .status = 200, .body = "{\"repositories\":[\"zeta\"]}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var pager = try client.listRepositories(allocator, .{ .max_results = 2 });
    defer pager.deinit();

    var first = (try pager.next()).?;
    defer first.deinit();
    switch (first) {
        .ok => |page| {
            try std.testing.expectEqual(@as(usize, 2), page.names.len);
            try std.testing.expectEqualStrings("team/app", page.names[1]);
        },
        .err => return error.UnexpectedServiceError,
    }

    var second = (try pager.next()).?;
    defer second.deinit();
    switch (second) {
        .ok => |page| {
            try std.testing.expectEqual(@as(usize, 1), page.names.len);
            try std.testing.expectEqualStrings("zeta", page.names[0]);
        },
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expect((try pager.next()) == null);
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expect(!transport.captured_authorization[0]);
    try std.testing.expect(!transport.captured_authorization[1]);
    try std.testing.expectEqualStrings(
        "https://registry.example/acr/v1/_catalog?api-version=2021-07-01&last=team%2Fapp&n=2",
        capturedUrl(&transport, 1),
    );
}

test "Link pager accepts valueless extensions and quoted-pair escapes" {
    const allocator = std.testing.allocator;
    const first_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Link",
            .value =
            \\</acr/v1/_catalog?api-version=2021-07-01&last=alpha>; extension; rel="prev\" \\ next"; title="a \"quote\" and \\ slash"
            ,
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body = "{\"repositories\":[\"alpha\"]}",
            .headers = &first_headers,
        },
        .{ .status = 200, .body = "{\"repositories\":[\"omega\"]}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var pager = try client.listRepositories(allocator, .{});
    defer pager.deinit();

    var first = (try pager.next()).?;
    defer first.deinit();
    try expectOk(first);
    var second = (try pager.next()).?;
    defer second.deinit();
    switch (second) {
        .ok => |page| try std.testing.expectEqualStrings("omega", page.names[0]),
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expect((try pager.next()) == null);
    try std.testing.expectEqualStrings(
        "https://registry.example/acr/v1/_catalog?api-version=2021-07-01&last=alpha",
        capturedUrl(&transport, 1),
    );
}

test "anonymous metadata reads use challenge authentication" {
    const allocator = std.testing.allocator;
    const challenge =
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"registry:catalog:*\"";
    const challenge_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &challenge_headers },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{ .status = 200, .body = "{\"repositories\":[\"private\"]}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var pager = try client.listRepositories(allocator, .{});
    defer pager.deinit();
    var result = (try pager.next()).?;
    defer result.deinit();
    switch (result) {
        .ok => |page| try std.testing.expectEqualStrings("private", page.names[0]),
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expect(!transport.captured_authorization[0]);
    try std.testing.expect(transport.captured_authorization[2]);
}

test "manifest pager follows an absolute same-origin Link" {
    const allocator = std.testing.allocator;
    const first_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Link",
            .value = "<https://registry.example:443/acr/v1/team/app/_manifests?api-version=2021-07-01&last=sha256%3Aone&n=1>; rel=\"next\"",
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body =
            \\{"registry":"registry.example","imageName":"team/app","manifests":[{"digest":"sha256:one","imageSize":42,"createdTime":"2026-01-01T00:00:00Z","lastUpdateTime":"2026-02-01T00:00:00Z","architecture":"amd64","os":"linux","references":[{"digest":"sha256:child","architecture":"arm64","os":"linux"}],"tags":["v1"],"changeableAttributes":{"deleteEnabled":true,"writeEnabled":false,"listEnabled":true,"readEnabled":true}}]}
            ,
            .headers = &first_headers,
        },
        .{
            .status = 200,
            .body =
            \\{"registry":"registry.example","imageName":"team/app","manifests":[{"digest":"sha256:two","createdTime":"2026-03-01T00:00:00Z","lastUpdateTime":"2026-03-02T00:00:00Z","tags":[],"changeableAttributes":{"deleteEnabled":false}}]}
            ,
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var pager = try client.listManifestProperties(
        allocator,
        "team/app",
        .{ .max_results = 1, .order = .last_updated_on_descending },
    );
    defer pager.deinit();

    var first = (try pager.next()).?;
    defer first.deinit();
    switch (first) {
        .ok => |page| {
            try std.testing.expectEqual(@as(usize, 1), page.items.len);
            try std.testing.expectEqualStrings("sha256:one", page.items[0].digest);
            try std.testing.expectEqualStrings(
                "registry.example",
                page.items[0].registry_login_server.?,
            );
            try std.testing.expectEqual(@as(?bool, true), page.items[0].can_delete);
            try std.testing.expectEqual(@as(usize, 1), page.items[0].related_artifacts.len);
        },
        .err => return error.UnexpectedServiceError,
    }

    var second = (try pager.next()).?;
    defer second.deinit();
    switch (second) {
        .ok => |page| {
            try std.testing.expectEqualStrings("sha256:two", page.items[0].digest);
            try std.testing.expectEqual(@as(?bool, null), page.items[0].can_read);
        },
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expect((try pager.next()) == null);
    try std.testing.expectEqualStrings(
        "https://registry.example:443/acr/v1/team/app/_manifests?api-version=2021-07-01&last=sha256%3Aone&n=1",
        capturedUrl(&transport, 1),
    );
}

test "tag pager follows a query-relative Link" {
    const allocator = std.testing.allocator;
    const first_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Link",
            .value = "<?api-version=2021-07-01&last=one&n=1>; rel=next",
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 200,
            .body =
            \\{"registry":"registry.example","imageName":"team/app","tags":[{"name":"one","digest":"sha256:one","createdTime":"2026-01-01T00:00:00Z","lastUpdateTime":"2026-01-02T00:00:00Z","changeableAttributes":{"deleteEnabled":true,"writeEnabled":true,"listEnabled":true,"readEnabled":true}}]}
            ,
            .headers = &first_headers,
        },
        .{
            .status = 200,
            .body =
            \\{"registry":"registry.example","imageName":"team/app","tags":[{"name":"two","digest":"sha256:two","createdTime":"2026-02-01T00:00:00Z","lastUpdateTime":"2026-02-02T00:00:00Z","signed":true,"changeableAttributes":{"deleteEnabled":false,"writeEnabled":false,"listEnabled":true,"readEnabled":true}}]}
            ,
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var pager = try client.listTagProperties(
        allocator,
        "team/app",
        .{
            .max_results = 1,
            .order = .last_updated_on_ascending,
            .digest = "sha256:one",
        },
    );
    defer pager.deinit();

    var first = (try pager.next()).?;
    defer first.deinit();
    switch (first) {
        .ok => |page| try std.testing.expectEqualStrings("one", page.items[0].name),
        .err => return error.UnexpectedServiceError,
    }
    var second = (try pager.next()).?;
    defer second.deinit();
    switch (second) {
        .ok => |page| {
            try std.testing.expectEqualStrings("two", page.items[0].name);
            try std.testing.expectEqual(@as(?bool, true), page.items[0].signed);
        },
        .err => return error.UnexpectedServiceError,
    }
    try std.testing.expect((try pager.next()) == null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedUrl(&transport, 0),
        "&digest=sha256%3Aone",
    ) != null);
    try std.testing.expectEqualStrings(
        "https://registry.example/acr/v1/team/app/_tags?api-version=2021-07-01&last=one&n=1",
        capturedUrl(&transport, 1),
    );
}

test "Link pager rejects unsafe and malformed continuations before sending" {
    const cases = [_]struct {
        link: []const u8,
        expected: anyerror,
    }{
        .{
            .link = "<https://evil.example/acr/v1/_catalog>; rel=\"next\"",
            .expected = error.UntrustedContinuation,
        },
        .{
            .link = "<http://registry.example/acr/v1/_catalog>; rel=\"next\"",
            .expected = error.ContinuationHttpsRequired,
        },
        .{
            .link = "<https://registry.example:444/acr/v1/_catalog>; rel=\"next\"",
            .expected = error.UntrustedContinuation,
        },
        .{
            .link = "not-a-link",
            .expected = error.MalformedLinkHeader,
        },
        .{
            .link = "<https://registry.example/acr/v1/bad path>; rel=\"next\"",
            .expected = error.MalformedLinkHeader,
        },
        .{
            .link = "<https://registry.example/acr/v1/%ZZ>; rel=\"next\"",
            .expected = error.MalformedLinkHeader,
        },
        .{
            .link = "<https://registry.example/acr/v1/_catalog>; rel=\"next\"; title=\"unterminated",
            .expected = error.MalformedLinkHeader,
        },
        .{
            .link = "<https://registry.example/acr/v1/_catalog?n=1>; rel=\"next\", </acr/v1/_catalog?n=2>; rel=next",
            .expected = error.AmbiguousContinuationLink,
        },
    };
    for (cases) |case| {
        const headers = [_]core.http.MockTransport.HeaderPair{
            .{ .name = "Link", .value = case.link },
        };
        const responses = [_]core.http.SequenceMockTransport.CannedResponse{
            .{
                .status = 200,
                .body = "{\"repositories\":[\"safe\"]}",
                .headers = &headers,
            },
        };
        var transport = core.http.SequenceMockTransport.init(
            std.testing.allocator,
            &responses,
        );
        var client = try client_mod.ContainerRegistryClient.init(
            std.testing.allocator,
            "https://registry.example",
            .{
                .transport = transport.asTransport(),
                .authentication = .anonymous,
            },
        );
        defer client.deinit();
        var pager = try client.listRepositories(std.testing.allocator, .{});
        defer pager.deinit();
        try std.testing.expectError(case.expected, pager.next());
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
}

test "Link pager never sends credentials to an additionally trusted origin" {
    const allocator = std.testing.allocator;
    const challenge =
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"registry:catalog:*\"";
    const challenge_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const link_headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "Link",
            .value = "<https://evil.example/acr/v1/_catalog>; rel=\"next\"",
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &challenge_headers },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{
            .status = 200,
            .body = "{\"repositories\":[\"private\"]}",
            .headers = &link_headers,
        },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
            .authentication_options = .{
                .expected_hosts = &.{"evil.example"},
            },
        },
    );
    defer client.deinit();
    var pager = try client.listRepositories(allocator, .{});
    defer pager.deinit();
    try std.testing.expectError(error.UntrustedContinuation, pager.next());
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expect(transport.captured_authorization[2]);
}

test "metadata deletes return idempotent outcomes on every surface" {
    const allocator = std.testing.allocator;
    const conflict =
        \\{"errors":[{"code":"DENIED","message":"delete denied"}]}
    ;
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 202, .body = "" },
        .{ .status = 404, .body = "" },
        .{ .status = 202, .body = "" },
        .{ .status = 404, .body = "" },
        .{ .status = 202, .body = "" },
        .{ .status = 404, .body = "" },
        .{ .status = 409, .body = conflict },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();

    var repository_accepted = try client.deleteRepository(allocator, "team/app");
    defer repository_accepted.deinit();
    try expectDeleteOutcome(repository_accepted, .accepted);
    var repository_missing = try client.deleteRepository(allocator, "team/app");
    defer repository_missing.deinit();
    try expectDeleteOutcome(repository_missing, .not_found);

    var manifest_accepted = try client.deleteManifest(
        allocator,
        "team/app",
        "sha256:one",
    );
    defer manifest_accepted.deinit();
    try expectDeleteOutcome(manifest_accepted, .accepted);
    var manifest_missing = try client.deleteManifest(
        allocator,
        "team/app",
        "sha256:one",
    );
    defer manifest_missing.deinit();
    try expectDeleteOutcome(manifest_missing, .not_found);

    var tag_accepted = try client.deleteTag(allocator, "team/app", "v1");
    defer tag_accepted.deinit();
    try expectDeleteOutcome(tag_accepted, .accepted);
    var tag_missing = try client.deleteTag(allocator, "team/app", "v1");
    defer tag_missing.deinit();
    try expectDeleteOutcome(tag_missing, .not_found);

    var tag_conflict = try client.deleteTag(allocator, "team/app", "protected");
    defer tag_conflict.deinit();
    switch (tag_conflict) {
        .ok => return error.ExpectedServiceError,
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 409), failure.status_code);
            try std.testing.expect(failure.isCode("denied"));
        },
    }

    for (transport.captured_methods[0..responses.len]) |method| {
        try std.testing.expectEqual(core.http.Method.DELETE, method.?);
    }
}

test "metadata CRUD preserves flags paths and structured not-found errors" {
    const allocator = std.testing.allocator;
    const not_found =
        \\{"errors":[{"code":"TAG_UNKNOWN","message":"tag missing","detail":{"name":"missing"}}]}
    ;
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = repository_body },
        .{ .status = 200, .body = repository_body },
        .{ .status = 202, .body = "" },
        .{ .status = 200, .body = manifest_body },
        .{ .status = 200, .body = manifest_body },
        .{ .status = 202, .body = "" },
        .{ .status = 200, .body = tag_body },
        .{ .status = 200, .body = tag_body },
        .{ .status = 202, .body = "" },
        .{ .status = 404, .body = not_found },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();

    var repository = try client.getRepositoryProperties(allocator, "team/app");
    defer repository.deinit();
    switch (repository) {
        .ok => |properties| {
            try std.testing.expectEqual(@as(?bool, true), properties.can_delete);
            try std.testing.expectEqual(@as(?bool, false), properties.can_write);
        },
        .err => return error.UnexpectedServiceError,
    }
    var updated_repository = try client.updateRepositoryProperties(
        allocator,
        "team/app",
        .{ .can_delete = false, .can_read = true },
    );
    defer updated_repository.deinit();
    try expectOk(updated_repository);
    var deleted_repository = try client.deleteRepository(allocator, "team/app");
    defer deleted_repository.deinit();
    try expectOk(deleted_repository);

    var manifest = try client.getManifestProperties(
        allocator,
        "team/app",
        "sha256:one",
    );
    defer manifest.deinit();
    switch (manifest) {
        .ok => |properties| {
            try std.testing.expectEqualStrings("sha256:one", properties.digest);
            try std.testing.expectEqual(@as(?i64, 42), properties.size_in_bytes);
            try std.testing.expectEqual(@as(usize, 2), properties.tags.len);
        },
        .err => return error.UnexpectedServiceError,
    }
    var updated_manifest = try client.updateManifestProperties(
        allocator,
        "team/app",
        "sha256:one",
        .{ .can_write = false, .can_list = true },
    );
    defer updated_manifest.deinit();
    try expectOk(updated_manifest);
    var deleted_manifest = try client.deleteManifest(
        allocator,
        "team/app",
        "sha256:one",
    );
    defer deleted_manifest.deinit();
    try expectOk(deleted_manifest);

    var tag = try client.getTagProperties(
        allocator,
        "team/app",
        "release/candidate",
    );
    defer tag.deinit();
    switch (tag) {
        .ok => |properties| {
            try std.testing.expectEqualStrings("release/candidate", properties.name);
            try std.testing.expectEqual(@as(?bool, false), properties.signed);
        },
        .err => return error.UnexpectedServiceError,
    }
    var updated_tag = try client.updateTagProperties(
        allocator,
        "team/app",
        "release/candidate",
        .{ .can_delete = true, .can_read = false },
    );
    defer updated_tag.deinit();
    try expectOk(updated_tag);
    var deleted_tag = try client.deleteTag(
        allocator,
        "team/app",
        "release/candidate",
    );
    defer deleted_tag.deinit();
    try expectOk(deleted_tag);

    var missing = try client.getTagProperties(allocator, "team/app", "missing");
    defer missing.deinit();
    switch (missing) {
        .ok => return error.ExpectedServiceError,
        .err => |failure| {
            try std.testing.expect(failure.isNotFound());
            try std.testing.expect(failure.isCode("tag_unknown"));
            try std.testing.expectEqualStrings("TAG_UNKNOWN", failure.code.?);
            try std.testing.expectEqualStrings("tag missing", failure.message.?);
            try std.testing.expectEqualStrings("{\"name\":\"missing\"}", failure.detail.?);
            try std.testing.expectEqual(@as(usize, 1), failure.errors.len);
        },
    }

    try std.testing.expectEqualStrings(
        "{\"deleteEnabled\":false,\"readEnabled\":true}",
        capturedBody(&transport, 1),
    );
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedUrl(&transport, 3),
        "/_manifests/sha256%3Aone",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedUrl(&transport, 5),
        "/v2/team/app/manifests/sha256%3Aone",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedUrl(&transport, 6),
        "/_tags/release%2Fcandidate",
    ) != null);
}

test "authenticated metadata writes use challenge authentication" {
    const allocator = std.testing.allocator;
    const challenge =
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"repository:team/app:metadata_write\"";
    const challenge_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &challenge_headers },
        .{
            .status = 200,
            .body = "{\"refresh_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{ .status = 200, .body = repository_body },
    };
    var credential = TestCredential.init();
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try client_mod.ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .{ .credential = &credential.credential },
        },
    );
    defer client.deinit();

    var result = try client.updateRepositoryProperties(
        allocator,
        "team/app",
        .{ .can_write = false },
    );
    defer result.deinit();
    try expectOk(result);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqual(core.http.Method.PATCH, transport.captured_methods[0].?);
    try std.testing.expectEqual(core.http.Method.POST, transport.captured_methods[1].?);
    try std.testing.expectEqual(core.http.Method.POST, transport.captured_methods[2].?);
    try std.testing.expectEqual(core.http.Method.PATCH, transport.captured_methods[3].?);
    try std.testing.expect(!transport.captured_authorization[0]);
    try std.testing.expect(transport.captured_authorization[3]);
    try std.testing.expectEqualStrings(
        "{\"writeEnabled\":false}",
        capturedBody(&transport, 3),
    );
}

test "malformed ACR errors retain status and raw body" {
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 502, .body = "gateway said no" },
    };
    var transport = core.http.SequenceMockTransport.init(
        std.testing.allocator,
        &responses,
    );
    var client = try client_mod.ContainerRegistryClient.init(
        std.testing.allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();
    var result = try client.getRepositoryProperties(
        std.testing.allocator,
        "team/app",
    );
    defer result.deinit();
    switch (result) {
        .ok => return error.ExpectedServiceError,
        .err => |failure| {
            try std.testing.expectEqual(@as(u16, 502), failure.status_code);
            try std.testing.expect(failure.malformed);
            try std.testing.expectEqualStrings("gateway said no", failure.raw_body.?);
            try std.testing.expect(failure.code == null);
        },
    }
}

fn parseErrorAllocationFixture(allocator: std.mem.Allocator) !void {
    var response = core.http.Response{
        .status_code = 404,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(
            u8,
            "{\"errors\":[{\"code\":\"MANIFEST_UNKNOWN\",\"message\":\"missing\",\"detail\":{\"digest\":\"sha256:none\"}},{\"code\":\"NAME_UNKNOWN\",\"message\":\"repository missing\"}]}",
        ),
        .allocator = allocator,
    };
    defer response.deinit();
    var failure = try service_error.ServiceError.fromResponse(allocator, &response);
    defer failure.deinit();
    try std.testing.expectEqual(@as(usize, 2), failure.errors.len);
}

fn parsePageAllocationFixture(allocator: std.mem.Allocator) !void {
    var missing_repositories = try models.parseRepositoryPage(allocator, "{}");
    defer missing_repositories.deinit();
    var null_repositories = try models.parseRepositoryPage(
        allocator,
        "{\"repositories\":null}",
    );
    defer null_repositories.deinit();
    var page = try models.parseManifestPage(
        allocator,
        "{\"registry\":\"registry.example\",\"imageName\":\"team/app\",\"manifests\":[{\"digest\":\"sha256:one\",\"createdTime\":\"2026-01-01T00:00:00Z\",\"lastUpdateTime\":\"2026-01-02T00:00:00Z\",\"references\":[{\"digest\":\"sha256:child\",\"architecture\":\"arm64\",\"os\":\"linux\"}],\"tags\":[\"v1\",\"latest\"],\"changeableAttributes\":{\"deleteEnabled\":true}}]}",
    );
    defer page.deinit();
    try std.testing.expectEqual(@as(usize, 1), page.items.len);
}

test "repository pages map missing and null repositories to owned empty slices" {
    for ([_][]const u8{
        "{}",
        "{\"repositories\":null}",
    }) |body| {
        var page = try models.parseRepositoryPage(std.testing.allocator, body);
        defer page.deinit();
        try std.testing.expectEqual(@as(usize, 0), page.names.len);
    }
    try std.testing.expectError(
        error.InvalidContainerRegistryResponse,
        models.parseRepositoryPage(
            std.testing.allocator,
            "{\"repositories\":{}}",
        ),
    );
}

test "metadata parsers release every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parseErrorAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parsePageAllocationFixture,
        .{},
    );
}

const TestCredential = struct {
    credential: core.credentials.TokenCredential,
    calls: usize = 0,

    fn init() TestCredential {
        return .{ .credential = .{ .getTokenFn = &getToken } };
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestCredential =
            @alignCast(@fieldParentPtr("credential", credential));
        self.calls += 1;
        return .{ .token = "aad-token", .expires_on = 4_102_444_800 };
    }
};

fn capturedUrl(
    transport: *const core.http.SequenceMockTransport,
    index: usize,
) []const u8 {
    return transport.captured_urls[index][0..transport.captured_url_lengths[index]];
}

fn capturedBody(
    transport: *const core.http.SequenceMockTransport,
    index: usize,
) []const u8 {
    return transport.captured_bodies[index][0..transport.captured_body_lengths[index]];
}

fn expectOk(result: anytype) !void {
    switch (result) {
        .ok => {},
        .err => return error.UnexpectedServiceError,
    }
}

fn expectDeleteOutcome(
    result: client_mod.DeleteResult,
    expected: client_mod.DeleteOutcome,
) !void {
    switch (result) {
        .ok => |outcome| try std.testing.expectEqual(expected, outcome),
        .err => return error.UnexpectedServiceError,
    }
}
