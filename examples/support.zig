const std = @import("std");
const core = @import("azure_core");
const acr = @import("azure_sdk_container_registry");

pub const endpoint_environment = "AZURE_CONTAINER_REGISTRY_ENDPOINT";
pub const repository_environment = "AZURE_CONTAINER_REGISTRY_REPOSITORY";

pub const AuthenticatedSession = struct {
    allocator: std.mem.Allocator,
    transport: core.http.StdHttpTransport,
    credential: core.identity.DefaultAzureCredential,

    pub fn create(
        allocator: std.mem.Allocator,
        io: std.Io,
        env: *const std.process.Environ.Map,
    ) !*AuthenticatedSession {
        const self = try allocator.create(AuthenticatedSession);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.transport = core.http.StdHttpTransport.init(allocator, io);
        errdefer self.transport.deinit();
        self.credential = try core.identity.DefaultAzureCredential.init(
            allocator,
            io,
            self.transport.asTransport(),
            env,
        );
        return self;
    }

    pub fn clientOptions(
        self: *AuthenticatedSession,
    ) acr.ContainerRegistryClientOptions {
        return .{
            .transport = self.transport.asTransport(),
            .authentication = .{ .credential = self.credential.asCredential() },
        };
    }

    pub fn deinit(self: *AuthenticatedSession) void {
        self.credential.deinit();
        self.transport.deinit();
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

pub fn required(
    env: *const std.process.Environ.Map,
    name: []const u8,
) ![]const u8 {
    const value = env.get(name) orelse {
        std.debug.print("Missing required environment variable: {s}\n", .{name});
        return error.ContainerRegistryExampleEnvironmentRequired;
    };
    if (value.len == 0) return error.ContainerRegistryExampleEnvironmentRequired;
    return value;
}

pub fn requireOptIn(
    env: *const std.process.Environ.Map,
    name: []const u8,
) !void {
    const value = try required(env, name);
    if (!std.mem.eql(u8, value, "1")) {
        std.debug.print("{s} must be exactly 1\n", .{name});
        return error.ContainerRegistryExampleOptInRequired;
    }
}

pub fn expectDelete(result: *acr.DeleteResult) !acr.DeleteOutcome {
    return switch (result.*) {
        .ok => |outcome| outcome,
        .err => |failure| {
            std.log.err("{f}", .{failure});
            return error.ContainerRegistryDeleteFailed;
        },
    };
}
