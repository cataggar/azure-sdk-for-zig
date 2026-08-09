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
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat(settings.pat),
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    var core_area = client.core_area();
    var projects = core_area.projects();
    const list = try projects.list(
        allocator,
        settings.organization,
        null,
        null,
        null,
        null,
        null,
    );
    defer allocator.free(list);
    try std.testing.expect(list.len > 0);
}

test "live: a project's Git repositories can be listed" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);
    const project = settings.project orelse return error.SkipZigTest;

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat(settings.pat),
        .transport = transport.asTransport(),
    });
    defer client.deinit();

    var git = client.git();
    var repositories = git.repositories();
    const list = try repositories.list(
        allocator,
        settings.organization,
        project,
        null,
        null,
        null,
    );
    defer allocator.free(list);
    for (list) |repository| {
        try std.testing.expect(repository.id != null);
    }
}

test "live: an invalid PAT is rejected rather than silently succeeding" {
    const allocator = std.testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const settings = try load(&env);

    var transport = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer transport.deinit();

    var client = try devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat("this-is-not-a-valid-pat"),
        .transport = transport.asTransport(),
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
