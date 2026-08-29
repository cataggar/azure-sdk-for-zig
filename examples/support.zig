//! Shared setup for the Azure DevOps examples.
//!
//! Every example needs the same three things — an organization, a
//! credential and an HTTP runtime — so they are resolved here from the
//! environment rather than repeated four times.
//!
//! Environment:
//!
//!   AZURE_DEVOPS_ORGANIZATION  organization name, e.g. `contoso`
//!   AZURE_DEVOPS_PAT           Personal Access Token
//!   AZURE_DEVOPS_PROJECT       project name or id (examples that need one)

const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");

pub const organization_environment = "AZURE_DEVOPS_ORGANIZATION";
pub const pat_environment = "AZURE_DEVOPS_PAT";
pub const project_environment = "AZURE_DEVOPS_PROJECT";

/// Values borrowed from the process environment; nothing here is owned.
pub const Settings = struct {
    organization: []const u8,
    pat: []const u8,
    project: ?[]const u8,
};

pub fn loadSettings(env: *const std.process.Environ.Map) !Settings {
    return .{
        .organization = try required(env, organization_environment),
        .pat = try required(env, pat_environment),
        .project = env.get(project_environment),
    };
}

pub fn required(
    env: *const std.process.Environ.Map,
    name: []const u8,
) ![]const u8 {
    const value = env.get(name) orelse {
        std.debug.print("Missing required environment variable: {s}\n", .{name});
        return error.DevOpsExampleEnvironmentRequired;
    };
    if (value.len == 0) return error.DevOpsExampleEnvironmentRequired;
    return value;
}

pub fn requireProject(settings: Settings) ![]const u8 {
    const project = settings.project orelse {
        std.debug.print(
            "Missing required environment variable: {s}\n",
            .{project_environment},
        );
        return error.DevOpsExampleEnvironmentRequired;
    };
    if (project.len == 0) return error.DevOpsExampleEnvironmentRequired;
    return project;
}

pub fn client(
    allocator: std.mem.Allocator,
    settings: Settings,
    runtime: core.http.HttpRuntime,
) !devops.DevOpsClient {
    return devops.DevOpsClient.init(allocator, .{
        .organization = settings.organization,
        .credential = .fromPat(settings.pat),
        .runtime = runtime,
    });
}
