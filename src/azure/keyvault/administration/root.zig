const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

/// Pager type returned by `listSettings`.
pub const AdminSettingPager = core.pager.PipelinePager(AdminSetting);

pub const AdminSetting = struct {
    name: []const u8,
    value: ?[]const u8 = null,
};

// ──────────────────────── BackupClient ────────────────────────

pub const BackupClientOptions = struct {
    api_version: []const u8 = "7.6-preview.2",
};

pub const BackupClient = struct {
    vault_url: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: BackupClientOptions,
    ) BackupClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// POST /backup?api-version=... — begins a full backup (LRO stub returning operation ID).
    pub fn beginBackup(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        storage_uri: []const u8,
        sas_token: []const u8,
    ) ![]const u8 {
        const r = try self.beginBackupResult(allocator, storage_uri, sas_token);
        return switch (r) {
            .ok => |v| v,
            .err => blk: {
                var e = r.err;
                defer e.deinit();
                std.log.warn("{f}", .{e});
                break :blk error.BeginBackupFailed;
            },
        };
    }

    /// Same as `beginBackup` but returns `Result([]const u8)`.
    pub fn beginBackupResult(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        storage_uri: []const u8,
        sas_token: []const u8,
    ) !core.errors.Result([]const u8) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/backup?api-version={s}",
            .{ self.vault_url, self.api_version },
        );
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"storageResourceUri\":\"{s}\",\"token\":\"{s}\"}}",
            .{ storage_uri, sas_token },
        );
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseOperationId(allocator, resp.body) };
    }

    /// POST /restore?api-version=... — begins a restore (LRO stub returning operation ID).
    pub fn beginRestore(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        backup_uri: []const u8,
        sas_token: []const u8,
    ) ![]const u8 {
        const r = try self.beginRestoreResult(allocator, backup_uri, sas_token);
        return switch (r) {
            .ok => |v| v,
            .err => blk: {
                var e = r.err;
                defer e.deinit();
                std.log.warn("{f}", .{e});
                break :blk error.BeginRestoreFailed;
            },
        };
    }

    /// Same as `beginRestore` but returns `Result([]const u8)`.
    pub fn beginRestoreResult(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        backup_uri: []const u8,
        sas_token: []const u8,
    ) !core.errors.Result([]const u8) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/restore?api-version={s}",
            .{ self.vault_url, self.api_version },
        );
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"sasTokenParameters\":{{\"storageResourceUri\":\"{s}\",\"token\":\"{s}\"}}}}",
            .{ backup_uri, sas_token },
        );
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseOperationId(allocator, resp.body) };
    }

    /// Wait for a backup operation to complete by polling the operation URL.
    pub fn waitForBackup(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        operation_url: []const u8,
    ) !core.lro.PollResult {
        return core.lro.pollUntilDone(allocator, &self.pipeline, operation_url, 2000, 60);
    }

    /// Wait for a restore operation to complete by polling the operation URL.
    pub fn waitForRestore(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        operation_url: []const u8,
    ) !core.lro.PollResult {
        return core.lro.pollUntilDone(allocator, &self.pipeline, operation_url, 2000, 60);
    }
};

// ──────────────────────── SettingsClient ──────────────────────

pub const SettingsClient = struct {
    vault_url: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
    ) SettingsClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .api_version = "7.6-preview.2",
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET /settings/{name}?api-version=...
    pub fn getSetting(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![]const u8 {
        const r = try self.getSettingResult(allocator, name);
        return switch (r) {
            .ok => |v| v,
            .err => blk: {
                var e = r.err;
                defer e.deinit();
                std.log.warn("{f}", .{e});
                break :blk error.GetSettingFailed;
            },
        };
    }

    /// Same as `getSetting` but returns `Result([]const u8)`.
    pub fn getSettingResult(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !core.errors.Result([]const u8) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/settings/{s}?api-version={s}",
            .{ self.vault_url, name, self.api_version },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseSettingValue(allocator, resp.body) };
    }

    /// PATCH /settings/{name}?api-version=...
    pub fn updateSetting(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        value: []const u8,
    ) !void {
        const r = try self.updateSettingResult(allocator, name, value);
        switch (r) {
            .ok => {},
            .err => {
                var e = r.err;
                defer e.deinit();
                std.log.warn("{f}", .{e});
                return error.UpdateSettingFailed;
            },
        }
    }

    /// Same as `updateSetting` but returns `Result(void)`.
    pub fn updateSettingResult(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        value: []const u8,
    ) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/settings/{s}?api-version={s}",
            .{ self.vault_url, name, self.api_version },
        );
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator, "{{\"value\":\"{s}\"}}", .{value});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /settings?api-version=... — returns a pager over admin settings.
    pub fn listSettings(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
    ) !AdminSettingPager {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/settings?api-version={s}",
            .{ self.vault_url, self.api_version },
        );
        defer allocator.free(url);

        return AdminSettingPager.init(
            self.pipeline,
            url,
            allocator,
            &parseAdminSettingListPage,
            "application/json",
        );
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseOperationId(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    const Schema = struct { jobId: ?[]const u8 = null };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(Schema, arena.allocator(), body) catch
        return error.ParseFailed;
    const job_id = parsed.jobId orelse return error.ParseFailed;
    return allocator.dupe(u8, job_id);
}

fn parseSettingValue(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    const Schema = struct { value: ?[]const u8 = null };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(Schema, arena.allocator(), body) catch
        return error.ParseFailed;
    const value = parsed.value orelse return error.ParseFailed;
    return allocator.dupe(u8, value);
}

const AdminSettingEntrySchema = struct {
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,
};

const AdminSettingListSchema = struct {
    value: ?[]const AdminSettingEntrySchema = null,
};

fn parseAdminSettingListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(AdminSetting) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(AdminSettingListSchema, arena.allocator(), body) catch
        return .{ .items = try allocator.alloc(AdminSetting, 0) };

    const entries = parsed.value orelse return .{ .items = try allocator.alloc(AdminSetting, 0) };

    var result = try allocator.alloc(AdminSetting, entries.len);
    for (entries, 0..) |entry, i| {
        var setting = AdminSetting{ .name = "" };
        if (entry.name) |n| setting.name = try allocator.dupe(u8, n);
        if (entry.value) |v| setting.value = try allocator.dupe(u8, v);
        result[i] = setting;
    }
    return .{ .items = result };
}

// ─────────────────────────── Tests ────────────────────────────

test "BackupClient beginBackup" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 202,
        \\{"jobId":"backup-op-001","status":"InProgress"}
    );
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = BackupClient.init(
        "https://vault.managedhsm.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const op_id = try client.beginBackup(allocator, "https://storage.blob.core.windows.net/backup", "sas-token");
    defer allocator.free(op_id);

    try std.testing.expectEqualStrings("backup-op-001", op_id);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/backup?api-version=") != null);
}

test "SettingsClient getSetting" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"value":"true","name":"AllowKeyManagementOperationsThroughARM"}
    );
    defer mock.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = SettingsClient.init(
        "https://vault.managedhsm.azure.net",
        cred.asCredential(),
        mock.asTransport(),
    );

    const value = try client.getSetting(allocator, "AllowKeyManagementOperationsThroughARM");
    defer allocator.free(value);

    try std.testing.expectEqualStrings("true", value);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "settings/AllowKeyManagementOperationsThroughARM") != null);
}
