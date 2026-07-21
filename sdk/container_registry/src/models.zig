const std = @import("std");

pub const ChangeableProperties = struct {
    can_delete: ?bool = null,
    can_write: ?bool = null,
    can_list: ?bool = null,
    can_read: ?bool = null,
};

pub const ContainerRepositoryProperties = struct {
    allocator: std.mem.Allocator,
    registry_login_server: []u8,
    name: []u8,
    created_on: []u8,
    last_updated_on: []u8,
    manifest_count: i32,
    tag_count: i32,
    can_delete: ?bool,
    can_write: ?bool,
    can_list: ?bool,
    can_read: ?bool,

    pub fn deinit(self: *ContainerRepositoryProperties) void {
        self.allocator.free(self.registry_login_server);
        self.allocator.free(self.name);
        self.allocator.free(self.created_on);
        self.allocator.free(self.last_updated_on);
        self.* = undefined;
    }
};

pub const ArtifactManifestPlatform = struct {
    allocator: std.mem.Allocator,
    digest: []u8,
    architecture: ?[]u8,
    operating_system: ?[]u8,

    pub fn deinit(self: *ArtifactManifestPlatform) void {
        self.allocator.free(self.digest);
        if (self.architecture) |value| self.allocator.free(value);
        if (self.operating_system) |value| self.allocator.free(value);
        self.* = undefined;
    }
};

pub const ArtifactManifestProperties = struct {
    allocator: std.mem.Allocator,
    registry_login_server: ?[]u8,
    repository_name: ?[]u8,
    digest: []u8,
    size_in_bytes: ?i64,
    created_on: []u8,
    last_updated_on: []u8,
    architecture: ?[]u8,
    operating_system: ?[]u8,
    related_artifacts: []ArtifactManifestPlatform,
    config_media_type: ?[]u8,
    media_type: ?[]u8,
    tags: [][]u8,
    can_delete: ?bool,
    can_write: ?bool,
    can_list: ?bool,
    can_read: ?bool,

    pub fn deinit(self: *ArtifactManifestProperties) void {
        if (self.registry_login_server) |value| self.allocator.free(value);
        if (self.repository_name) |value| self.allocator.free(value);
        self.allocator.free(self.digest);
        self.allocator.free(self.created_on);
        self.allocator.free(self.last_updated_on);
        if (self.architecture) |value| self.allocator.free(value);
        if (self.operating_system) |value| self.allocator.free(value);
        for (self.related_artifacts) |*artifact| artifact.deinit();
        self.allocator.free(self.related_artifacts);
        if (self.config_media_type) |value| self.allocator.free(value);
        if (self.media_type) |value| self.allocator.free(value);
        for (self.tags) |tag| self.allocator.free(tag);
        self.allocator.free(self.tags);
        self.* = undefined;
    }
};

pub const ArtifactTagProperties = struct {
    allocator: std.mem.Allocator,
    registry_login_server: []u8,
    repository_name: []u8,
    name: []u8,
    digest: []u8,
    created_on: []u8,
    last_updated_on: []u8,
    signed: ?bool,
    can_delete: ?bool,
    can_write: ?bool,
    can_list: ?bool,
    can_read: ?bool,

    pub fn deinit(self: *ArtifactTagProperties) void {
        self.allocator.free(self.registry_login_server);
        self.allocator.free(self.repository_name);
        self.allocator.free(self.name);
        self.allocator.free(self.digest);
        self.allocator.free(self.created_on);
        self.allocator.free(self.last_updated_on);
        self.* = undefined;
    }
};

pub const RepositoryPage = struct {
    allocator: std.mem.Allocator,
    names: [][]u8,

    pub fn deinit(self: *RepositoryPage) void {
        for (self.names) |name| self.allocator.free(name);
        self.allocator.free(self.names);
        self.* = undefined;
    }
};

pub const ManifestPage = struct {
    allocator: std.mem.Allocator,
    items: []ArtifactManifestProperties,

    pub fn deinit(self: *ManifestPage) void {
        for (self.items) |*item| item.deinit();
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

pub const TagPage = struct {
    allocator: std.mem.Allocator,
    items: []ArtifactTagProperties,

    pub fn deinit(self: *TagPage) void {
        for (self.items) |*item| item.deinit();
        self.allocator.free(self.items);
        self.* = undefined;
    }
};

pub fn parseRepositoryProperties(
    allocator: std.mem.Allocator,
    body: []const u8,
) !ContainerRepositoryProperties {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    return parseRepositoryPropertiesValue(allocator, parsed.value);
}

pub fn parseManifestProperties(
    allocator: std.mem.Allocator,
    body: []const u8,
) !ArtifactManifestProperties {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidContainerRegistryResponse;
    const registry = try optionalString(parsed.value.object, "registry");
    const repository = try optionalString(parsed.value.object, "imageName");
    const manifest = parsed.value.object.get("manifest") orelse
        return error.InvalidContainerRegistryResponse;
    return parseManifestValue(allocator, manifest, registry, repository);
}

pub fn parseTagProperties(
    allocator: std.mem.Allocator,
    body: []const u8,
) !ArtifactTagProperties {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidContainerRegistryResponse;
    const registry = try requiredString(parsed.value.object, "registry");
    const repository = try requiredString(parsed.value.object, "imageName");
    const tag = parsed.value.object.get("tag") orelse
        return error.InvalidContainerRegistryResponse;
    return parseTagValue(allocator, tag, registry, repository);
}

pub fn parseRepositoryPage(
    allocator: std.mem.Allocator,
    body: []const u8,
) !RepositoryPage {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidContainerRegistryResponse;
    const repositories_value = parsed.value.object.get("repositories");
    const repository_values = if (repositories_value) |value| switch (value) {
        .null => &[_]std.json.Value{},
        .array => |array| array.items,
        else => return error.InvalidContainerRegistryResponse,
    } else &[_]std.json.Value{};

    const names = try allocator.alloc([]u8, repository_values.len);
    var initialized: usize = 0;
    errdefer {
        for (names[0..initialized]) |name| allocator.free(name);
        allocator.free(names);
    }
    for (repository_values, 0..) |value, index| {
        if (value != .string) return error.InvalidContainerRegistryResponse;
        names[index] = try allocator.dupe(u8, value.string);
        initialized += 1;
    }
    return .{ .allocator = allocator, .names = names };
}

pub fn parseManifestPage(
    allocator: std.mem.Allocator,
    body: []const u8,
) !ManifestPage {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidContainerRegistryResponse;

    const registry = try optionalString(parsed.value.object, "registry");
    const repository = try optionalString(parsed.value.object, "imageName");
    const manifests_value = parsed.value.object.get("manifests");
    const manifest_values = if (manifests_value) |value| switch (value) {
        .null => &[_]std.json.Value{},
        .array => |array| array.items,
        else => return error.InvalidContainerRegistryResponse,
    } else &[_]std.json.Value{};

    const items = try allocator.alloc(ArtifactManifestProperties, manifest_values.len);
    var initialized: usize = 0;
    errdefer {
        for (items[0..initialized]) |*item| item.deinit();
        allocator.free(items);
    }
    for (manifest_values, 0..) |value, index| {
        items[index] = try parseManifestValue(
            allocator,
            value,
            registry,
            repository,
        );
        initialized += 1;
    }
    return .{ .allocator = allocator, .items = items };
}

pub fn parseTagPage(
    allocator: std.mem.Allocator,
    body: []const u8,
) !TagPage {
    const parsed = try parseJson(allocator, body);
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidContainerRegistryResponse;

    const registry = try requiredString(parsed.value.object, "registry");
    const repository = try requiredString(parsed.value.object, "imageName");
    const tags = parsed.value.object.get("tags") orelse
        return error.InvalidContainerRegistryResponse;
    if (tags != .array) return error.InvalidContainerRegistryResponse;

    const items = try allocator.alloc(ArtifactTagProperties, tags.array.items.len);
    var initialized: usize = 0;
    errdefer {
        for (items[0..initialized]) |*item| item.deinit();
        allocator.free(items);
    }
    for (tags.array.items, 0..) |value, index| {
        items[index] = try parseTagValue(
            allocator,
            value,
            registry,
            repository,
        );
        initialized += 1;
    }
    return .{ .allocator = allocator, .items = items };
}

fn parseRepositoryPropertiesValue(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) !ContainerRepositoryProperties {
    if (value != .object) return error.InvalidContainerRegistryResponse;
    const registry = try requiredOwnedString(allocator, value.object, "registry");
    errdefer allocator.free(registry);
    const name = try requiredOwnedString(allocator, value.object, "imageName");
    errdefer allocator.free(name);
    const created_on = try requiredOwnedString(allocator, value.object, "createdTime");
    errdefer allocator.free(created_on);
    const last_updated_on = try requiredOwnedString(
        allocator,
        value.object,
        "lastUpdateTime",
    );
    errdefer allocator.free(last_updated_on);
    const attributes = value.object.get("changeableAttributes") orelse
        return error.InvalidContainerRegistryResponse;
    const flags = try parseChangeableProperties(attributes);

    return .{
        .allocator = allocator,
        .registry_login_server = registry,
        .name = name,
        .created_on = created_on,
        .last_updated_on = last_updated_on,
        .manifest_count = try requiredI32(value.object, "manifestCount"),
        .tag_count = try requiredI32(value.object, "tagCount"),
        .can_delete = flags.can_delete,
        .can_write = flags.can_write,
        .can_list = flags.can_list,
        .can_read = flags.can_read,
    };
}

fn parseManifestValue(
    allocator: std.mem.Allocator,
    value: std.json.Value,
    registry: ?[]const u8,
    repository: ?[]const u8,
) !ArtifactManifestProperties {
    if (value != .object) return error.InvalidContainerRegistryResponse;
    const owned_registry = if (registry) |field|
        try allocator.dupe(u8, field)
    else
        null;
    errdefer if (owned_registry) |field| allocator.free(field);
    const owned_repository = if (repository) |field|
        try allocator.dupe(u8, field)
    else
        null;
    errdefer if (owned_repository) |field| allocator.free(field);

    const digest = try requiredOwnedString(allocator, value.object, "digest");
    errdefer allocator.free(digest);
    const created_on = try requiredOwnedString(allocator, value.object, "createdTime");
    errdefer allocator.free(created_on);
    const last_updated_on = try requiredOwnedString(
        allocator,
        value.object,
        "lastUpdateTime",
    );
    errdefer allocator.free(last_updated_on);
    const architecture = try optionalOwnedString(allocator, value.object, "architecture");
    errdefer if (architecture) |field| allocator.free(field);
    const operating_system = try optionalOwnedString(allocator, value.object, "os");
    errdefer if (operating_system) |field| allocator.free(field);
    const related_artifacts = try parseRelatedArtifacts(allocator, value.object);
    errdefer {
        for (related_artifacts) |*artifact| artifact.deinit();
        allocator.free(related_artifacts);
    }
    const config_media_type = try optionalOwnedString(
        allocator,
        value.object,
        "configMediaType",
    );
    errdefer if (config_media_type) |field| allocator.free(field);
    const media_type = try optionalOwnedString(allocator, value.object, "mediaType");
    errdefer if (media_type) |field| allocator.free(field);
    const tags = try parseStringArray(allocator, value.object, "tags");
    errdefer {
        for (tags) |tag| allocator.free(tag);
        allocator.free(tags);
    }
    const flags = if (value.object.get("changeableAttributes")) |attributes|
        try parseChangeableProperties(attributes)
    else
        ChangeableProperties{};

    return .{
        .allocator = allocator,
        .registry_login_server = owned_registry,
        .repository_name = owned_repository,
        .digest = digest,
        .size_in_bytes = try optionalI64(value.object, "imageSize"),
        .created_on = created_on,
        .last_updated_on = last_updated_on,
        .architecture = architecture,
        .operating_system = operating_system,
        .related_artifacts = related_artifacts,
        .config_media_type = config_media_type,
        .media_type = media_type,
        .tags = tags,
        .can_delete = flags.can_delete,
        .can_write = flags.can_write,
        .can_list = flags.can_list,
        .can_read = flags.can_read,
    };
}

fn parseTagValue(
    allocator: std.mem.Allocator,
    value: std.json.Value,
    registry: []const u8,
    repository: []const u8,
) !ArtifactTagProperties {
    if (value != .object) return error.InvalidContainerRegistryResponse;
    const owned_registry = try allocator.dupe(u8, registry);
    errdefer allocator.free(owned_registry);
    const owned_repository = try allocator.dupe(u8, repository);
    errdefer allocator.free(owned_repository);
    const name = try requiredOwnedString(allocator, value.object, "name");
    errdefer allocator.free(name);
    const digest = try requiredOwnedString(allocator, value.object, "digest");
    errdefer allocator.free(digest);
    const created_on = try requiredOwnedString(allocator, value.object, "createdTime");
    errdefer allocator.free(created_on);
    const last_updated_on = try requiredOwnedString(
        allocator,
        value.object,
        "lastUpdateTime",
    );
    errdefer allocator.free(last_updated_on);
    const attributes = value.object.get("changeableAttributes") orelse
        return error.InvalidContainerRegistryResponse;
    const flags = try parseChangeableProperties(attributes);

    return .{
        .allocator = allocator,
        .registry_login_server = owned_registry,
        .repository_name = owned_repository,
        .name = name,
        .digest = digest,
        .created_on = created_on,
        .last_updated_on = last_updated_on,
        .signed = try optionalBool(value.object, "signed"),
        .can_delete = flags.can_delete,
        .can_write = flags.can_write,
        .can_list = flags.can_list,
        .can_read = flags.can_read,
    };
}

fn parseRelatedArtifacts(
    allocator: std.mem.Allocator,
    object: std.json.ObjectMap,
) ![]ArtifactManifestPlatform {
    const value = object.get("references") orelse
        return allocator.alloc(ArtifactManifestPlatform, 0);
    if (value == .null) return allocator.alloc(ArtifactManifestPlatform, 0);
    if (value != .array) return error.InvalidContainerRegistryResponse;

    const artifacts = try allocator.alloc(ArtifactManifestPlatform, value.array.items.len);
    var initialized: usize = 0;
    errdefer {
        for (artifacts[0..initialized]) |*artifact| artifact.deinit();
        allocator.free(artifacts);
    }
    for (value.array.items, 0..) |item, index| {
        if (item != .object) return error.InvalidContainerRegistryResponse;
        const digest = try requiredOwnedString(allocator, item.object, "digest");
        errdefer allocator.free(digest);
        const architecture = try optionalOwnedString(
            allocator,
            item.object,
            "architecture",
        );
        errdefer if (architecture) |field| allocator.free(field);
        const operating_system = try optionalOwnedString(allocator, item.object, "os");
        errdefer if (operating_system) |field| allocator.free(field);
        artifacts[index] = .{
            .allocator = allocator,
            .digest = digest,
            .architecture = architecture,
            .operating_system = operating_system,
        };
        initialized += 1;
    }
    return artifacts;
}

fn parseStringArray(
    allocator: std.mem.Allocator,
    object: std.json.ObjectMap,
    field: []const u8,
) ![][]u8 {
    const value = object.get(field) orelse return allocator.alloc([]u8, 0);
    if (value == .null) return allocator.alloc([]u8, 0);
    if (value != .array) return error.InvalidContainerRegistryResponse;

    const items = try allocator.alloc([]u8, value.array.items.len);
    var initialized: usize = 0;
    errdefer {
        for (items[0..initialized]) |item| allocator.free(item);
        allocator.free(items);
    }
    for (value.array.items, 0..) |item, index| {
        if (item != .string) return error.InvalidContainerRegistryResponse;
        items[index] = try allocator.dupe(u8, item.string);
        initialized += 1;
    }
    return items;
}

fn parseChangeableProperties(value: std.json.Value) !ChangeableProperties {
    if (value == .null) return .{};
    if (value != .object) return error.InvalidContainerRegistryResponse;
    return .{
        .can_delete = try optionalBool(value.object, "deleteEnabled"),
        .can_write = try optionalBool(value.object, "writeEnabled"),
        .can_list = try optionalBool(value.object, "listEnabled"),
        .can_read = try optionalBool(value.object, "readEnabled"),
    };
}

fn parseJson(
    allocator: std.mem.Allocator,
    body: []const u8,
) !std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch |err|
        switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidContainerRegistryResponse,
        };
}

fn requiredString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const value = object.get(field) orelse return error.InvalidContainerRegistryResponse;
    if (value != .string) return error.InvalidContainerRegistryResponse;
    return value.string;
}

fn optionalString(
    object: std.json.ObjectMap,
    field: []const u8,
) !?[]const u8 {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .null => null,
        .string => |string| string,
        else => error.InvalidContainerRegistryResponse,
    };
}

fn requiredOwnedString(
    allocator: std.mem.Allocator,
    object: std.json.ObjectMap,
    field: []const u8,
) ![]u8 {
    return allocator.dupe(u8, try requiredString(object, field));
}

fn optionalOwnedString(
    allocator: std.mem.Allocator,
    object: std.json.ObjectMap,
    field: []const u8,
) !?[]u8 {
    const value = try optionalString(object, field);
    return if (value) |string| try allocator.dupe(u8, string) else null;
}

fn requiredI32(object: std.json.ObjectMap, field: []const u8) !i32 {
    const value = object.get(field) orelse return error.InvalidContainerRegistryResponse;
    if (value != .integer) return error.InvalidContainerRegistryResponse;
    return std.math.cast(i32, value.integer) orelse
        error.InvalidContainerRegistryResponse;
}

fn optionalI64(object: std.json.ObjectMap, field: []const u8) !?i64 {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .null => null,
        .integer => |integer| integer,
        else => error.InvalidContainerRegistryResponse,
    };
}

fn optionalBool(object: std.json.ObjectMap, field: []const u8) !?bool {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .null => null,
        .bool => |boolean| boolean,
        else => error.InvalidContainerRegistryResponse,
    };
}
