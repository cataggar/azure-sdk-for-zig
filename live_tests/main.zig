//! Opt-in Azure DevOps live tests.
//!
//! These run against a real organization and are skipped unless the
//! environment is configured:
//!
//!   AZURE_DEVOPS_ORGANIZATION  organization name
//!   AZURE_DEVOPS_PAT           Personal Access Token
//!   AZURE_DEVOPS_PROJECT       project name or id
//!
//! They are read-only: nothing here creates, updates or deletes.

const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");

/// Values borrowed from `env`, which the caller keeps alive.
const Settings = struct {
    organization: []const u8,
    pat: []const u8,
    project: ?[]const u8,
};

fn load(env: *const std.process.Environ.Map) !Settings {
    const organization = env.get("AZURE_DEVOPS_ORGANIZATION") orelse
        return error.SkipZigTest;
    const pat = env.get("AZURE_DEVOPS_PAT") orelse return error.SkipZigTest;
    if (organization.len == 0 or pat.len == 0) return error.SkipZigTest;
    return .{
        .organization = organization,
        .pat = pat,
        .project = env.get("AZURE_DEVOPS_PROJECT"),
    };
}

test "live: the organization's projects can be listed with a PAT" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat(settings.pat),
        .runtime = runtime,
    });
    defer client.deinit();

    var core_area = client.core_area();
    var projects = core_area.projects();
    const result = try projects.list(
        allocator,
        settings.organization,
        null,
        null,
        null,
        null,
        null,
    );
    // Azure DevOps wraps every collection in a `{count, value}` envelope.
    const list = result.value orelse return error.MissingCollectionEnvelope;
    try std.testing.expect(list.len > 0);
}

test "live: a project's Git repositories can be listed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);
    const project = settings.project orelse return error.SkipZigTest;

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat(settings.pat),
        .runtime = runtime,
    });
    defer client.deinit();

    var git = client.git();
    var repositories = git.repositories();
    const result = try repositories.list(
        allocator,
        settings.organization,
        project,
        null,
        null,
        null,
    );
    const list = result.value orelse return error.MissingCollectionEnvelope;
    for (list) |repository| {
        try std.testing.expect(repository.id != null);
    }
}

test "live: an invalid PAT is rejected rather than silently succeeding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat("this-is-not-a-valid-pat"),
        .runtime = runtime,
    });
    defer client.deinit();

    var core_area = client.core_area();
    var projects = core_area.projects();
    const result = projects.list(
        allocator,
        settings.organization,
        null,
        null,
        null,
        null,
        null,
    );
    // Azure DevOps answers a bad credential with 203 and a sign-in page
    // as often as with 401; either way the operation must not succeed.
    try std.testing.expectError(error.AzureRequestFailed, result);
}
