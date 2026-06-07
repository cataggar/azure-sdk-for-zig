const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

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

    /// Free allocated value/label/content_type/etag/last_modified.
    /// `key` is NOT freed (borrows caller input).
    pub fn deinit(self: ConfigurationSetting, allocator: std.mem.Allocator) void {
        if (self.value) |v| allocator.free(v);
        if (self.label) |l| allocator.free(l);
        if (self.content_type) |c| allocator.free(c);
        if (self.etag) |e| allocator.free(e);
        if (self.last_modified) |lm| allocator.free(lm);
    }
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
        var r = try self.getSettingResult(allocator, key, label);
        return r.unwrap(error.SettingNotFound);
    }

    /// Same as `getSetting` but returns `Result(ConfigurationSetting)`.
    pub fn getSettingResult(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
        label: ?[]const u8,
    ) !core.errors.Result(ConfigurationSetting) {
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
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseSetting(allocator, key, resp.body) };
    }

    /// PUT /kv/{key}?api-version=...
    pub fn setSetting(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
        label: ?[]const u8,
    ) !ConfigurationSetting {
        var r = try self.setSettingResult(allocator, key, value, label);
        return r.unwrap(error.SetSettingFailed);
    }

    /// Same as `setSetting` but returns `Result(ConfigurationSetting)`.
    pub fn setSettingResult(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
        label: ?[]const u8,
    ) !core.errors.Result(ConfigurationSetting) {
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
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseSetting(allocator, key, resp.body) };
    }

    /// DELETE /kv/{key}?api-version=...
    pub fn deleteSetting(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) !void {
        var r = try self.deleteSettingResult(allocator, key);
        try r.unwrap(error.DeleteSettingFailed);
    }

    /// Same as `deleteSetting` but returns `Result(void)`.
    pub fn deleteSettingResult(
        self: *ConfigurationClient,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) !core.errors.Result(void) {
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

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
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

const SettingSchema = struct {
    value: ?[]const u8 = null,
    label: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,
};

fn parseSetting(allocator: std.mem.Allocator, key: []const u8, body: []const u8) !ConfigurationSetting {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(SettingSchema, arena.allocator(), body) catch
        return .{ .key = key };

    var setting = ConfigurationSetting{ .key = key };
    if (parsed.value) |v| setting.value = try allocator.dupe(u8, v);
    if (parsed.label) |v| setting.label = try allocator.dupe(u8, v);
    if (parsed.content_type) |v| setting.content_type = try allocator.dupe(u8, v);
    if (parsed.etag) |v| setting.etag = try allocator.dupe(u8, v);
    if (parsed.last_modified) |v| setting.last_modified = try allocator.dupe(u8, v);
    return setting;
}

const SettingListEntrySchema = struct {
    key: ?[]const u8 = null,
    value: ?[]const u8 = null,
    label: ?[]const u8 = null,
};

const SettingListSchema = struct {
    items: ?[]const SettingListEntrySchema = null,
    @"@nextLink": ?[]const u8 = null,
};

fn parseSettingListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(ConfigurationSetting) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(SettingListSchema, arena.allocator(), body) catch
        return .{ .items = try allocator.alloc(ConfigurationSetting, 0) };

    var next_link: ?[]u8 = null;
    if (parsed.@"@nextLink") |nl| {
        if (nl.len > 0) next_link = try allocator.dupe(u8, nl);
    }

    const entries = parsed.items orelse
        return .{ .items = try allocator.alloc(ConfigurationSetting, 0), .next_link = next_link };

    var result = try allocator.alloc(ConfigurationSetting, entries.len);
    for (entries, 0..) |entry, i| {
        var setting = ConfigurationSetting{ .key = "" };
        if (entry.key) |v| setting.key = try allocator.dupe(u8, v);
        if (entry.value) |v| setting.value = try allocator.dupe(u8, v);
        if (entry.label) |v| setting.label = try allocator.dupe(u8, v);
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

    const identity = @import("azure_core").identity;
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

    const identity2 = @import("azure_core").identity;
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
