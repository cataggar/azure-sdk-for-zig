const std = @import("std");
const core = @import("azure_core");

// ─────────────────────────── Models ───────────────────────────

/// Pager type returned by `listSettings`.
pub const SettingPager = core.pager.PipelinePager(ConfigurationSetting);

pub const ConfigurationSetting = struct {
    key: []const u8,
    value: ?[]const u8 = null,
    label: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,
};

// ─────────────────────── ConfigurationClient ──────────────────

pub const ConfigurationClientOptions = struct {
    api_version: []const u8 = "2023-11-01",
};

pub const ConfigurationClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: ConfigurationClientOptions,
    ) ConfigurationClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET /kv/{key}?label={label}&api-version=...
    pub fn getSetting(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
        label: ?[]const u8,
    ) !ConfigurationSetting {
        const url = if (label) |l|
            try std.fmt.allocPrint(
                allocator,
                "{s}/kv/{s}?label={s}&api-version={s}",
                .{ self.endpoint, key, l, self.api_version },
            )
        else
            try std.fmt.allocPrint(
                allocator,
                "{s}/kv/{s}?api-version={s}",
                .{ self.endpoint, key, self.api_version },
            );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/vnd.microsoft.appconfig.kv+json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.SettingNotFound;
        }

        return parseSetting(allocator, key, resp.body);
    }

    /// PUT /kv/{key}?api-version=...
    pub fn setSetting(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
        label: ?[]const u8,
    ) !ConfigurationSetting {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/kv/{s}?api-version={s}",
            .{ self.endpoint, key, self.api_version },
        );
        defer allocator.free(url);

        const body = if (label) |l|
            try std.fmt.allocPrint(allocator, "{{\"value\":\"{s}\",\"label\":\"{s}\"}}", .{ value, l })
        else
            try std.fmt.allocPrint(allocator, "{{\"value\":\"{s}\"}}", .{value});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/vnd.microsoft.appconfig.kv+json");
        try req.setHeader("Accept", "application/vnd.microsoft.appconfig.kv+json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.SetSettingFailed;
        }

        return parseSetting(allocator, key, resp.body);
    }

    /// DELETE /kv/{key}?api-version=...
    pub fn deleteSetting(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) !void {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/kv/{s}?api-version={s}",
            .{ self.endpoint, key, self.api_version },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteSettingFailed;
        }
    }

    /// GET /kv?key={filter}&api-version=... — returns a pager over settings.
    ///
    /// Usage:
    ///   var pager = try client.listSettings(allocator, "app.*");
    ///   defer pager.deinit();
    ///   while (try pager.next()) |settings| {
    ///       defer allocator.free(settings);
    ///       for (settings) |s| { ... }
    ///   }
    pub fn listSettings(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key_filter: ?[]const u8,
    ) !SettingPager {
        const url = if (key_filter) |f|
            try std.fmt.allocPrint(
                allocator,
                "{s}/kv?key={s}&api-version={s}",
                .{ self.endpoint, f, self.api_version },
            )
        else
            try std.fmt.allocPrint(
                allocator,
                "{s}/kv?api-version={s}",
                .{ self.endpoint, self.api_version },
            );
        defer allocator.free(url);

        return SettingPager.init(
            self.pipeline,
            url,
            allocator,
            &parseSettingListPage,
            "application/vnd.microsoft.appconfig.kvset+json",
        );
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseSetting(allocator: std.mem.Allocator, key: []const u8, body: []const u8) !ConfigurationSetting {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .key = key };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return .{ .key = key };

    var setting = ConfigurationSetting{ .key = key };

    if (obj.get("value")) |v| {
        if (v == .string) setting.value = try allocator.dupe(u8, v.string);
    }
    if (obj.get("label")) |v| {
        if (v == .string) setting.label = try allocator.dupe(u8, v.string);
    }
    if (obj.get("content_type")) |v| {
        if (v == .string) setting.content_type = try allocator.dupe(u8, v.string);
    }
    if (obj.get("etag")) |v| {
        if (v == .string) setting.etag = try allocator.dupe(u8, v.string);
    }
    if (obj.get("last_modified")) |v| {
        if (v == .string) setting.last_modified = try allocator.dupe(u8, v.string);
    }

    return setting;
}

fn parseSettingListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(ConfigurationSetting) {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .items = try allocator.alloc(ConfigurationSetting, 0) };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return .{ .items = try allocator.alloc(ConfigurationSetting, 0) };

    var next_link: ?[]u8 = null;
    if (obj.get("@nextLink")) |nl| {
        if (nl == .string and nl.string.len > 0)
            next_link = try allocator.dupe(u8, nl.string);
    }

    const items_arr = if (obj.get("items")) |v| (if (v == .array) v.array.items else null) else null;
    const items = items_arr orelse return .{ .items = try allocator.alloc(ConfigurationSetting, 0), .next_link = next_link };

    var result = try allocator.alloc(ConfigurationSetting, items.len);
    for (items, 0..) |item, i| {
        var setting = ConfigurationSetting{ .key = "" };
        if (item == .object) {
            if (item.object.get("key")) |v| {
                if (v == .string) setting.key = try allocator.dupe(u8, v.string);
            }
            if (item.object.get("value")) |v| {
                if (v == .string) setting.value = try allocator.dupe(u8, v.string);
            }
            if (item.object.get("label")) |v| {
                if (v == .string) setting.label = try allocator.dupe(u8, v.string);
            }
        }
        result[i] = setting;
    }
    return .{ .items = result, .next_link = next_link };
}

// ─────────────────────────── Tests ────────────────────────────

test "ConfigurationClient getSetting" {
    const allocator = std.testing.allocator;
    const body =
        \\{"key":"mykey","value":"myvalue","label":"prod","etag":"etag-1","last_modified":"2025-01-01T00:00:00Z"}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = ConfigurationClient.init(
        "https://myconfig.azconfig.io",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const setting = try client.getSetting(allocator, "mykey", "prod");
    defer allocator.free(setting.value.?);
    defer allocator.free(setting.label.?);
    defer allocator.free(setting.etag.?);
    defer allocator.free(setting.last_modified.?);

    try std.testing.expectEqualStrings("mykey", setting.key);
    try std.testing.expectEqualStrings("myvalue", setting.value.?);
    try std.testing.expectEqualStrings("prod", setting.label.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "kv/mykey?label=prod") != null);
}

test "ConfigurationClient setSetting and listSettings" {
    const allocator = std.testing.allocator;
    var mock_set = core.http.MockTransport.init(allocator, 200,
        \\{"key":"app.color","value":"blue"}
    );
    defer mock_set.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = ConfigurationClient.init(
        "https://myconfig.azconfig.io",
        cred.asCredential(),
        mock_set.asTransport(),
        .{},
    );

    const setting = try client.setSetting(allocator, "app.color", "blue", null);
    defer allocator.free(setting.value.?);

    try std.testing.expectEqualStrings("blue", setting.value.?);
    try std.testing.expectEqual(core.http.Method.PUT, mock_set.last_method.?);

    // Switch to list mock
    var mock_list = core.http.MockTransport.init(allocator, 200,
        \\{"items":[{"key":"app.color","value":"blue"},{"key":"app.size","value":"large"}]}
    );
    defer mock_list.deinit();
    client.pipeline = .{ .policies = &.{}, .transport_impl = mock_list.asTransport() };

    var pager = try client.listSettings(allocator, "app.*");
    defer pager.deinit();

    const settings = (try pager.next()) orelse return error.ExpectedPage;
    defer {
        for (settings) |s| {
            if (s.key.len > 0) allocator.free(s.key);
            if (s.value) |v| allocator.free(v);
        }
        allocator.free(settings);
    }

    try std.testing.expectEqual(@as(usize, 2), settings.len);
    try std.testing.expectEqualStrings("app.color", settings[0].key);
}
