const std = @import("std");
const core = @import("azure_core");

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

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.BeginBackupFailed; }

        return parseOperationId(allocator, resp.body);
    }

    /// POST /restore?api-version=... — begins a restore (LRO stub returning operation ID).
    pub fn beginRestore(
        self: *BackupClient,
        allocator: std.mem.Allocator,
        backup_uri: []const u8,
        sas_token: []const u8,
    ) ![]const u8 {
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

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.BeginRestoreFailed; }

        return parseOperationId(allocator, resp.body);
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

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.GetSettingFailed; }

        return parseSettingValue(allocator, resp.body);
    }

    /// PATCH /settings/{name}?api-version=...
    pub fn updateSetting(
        self: *SettingsClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        value: []const u8,
    ) !void {
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

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.UpdateSettingFailed; }
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseOperationId(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return error.ParseFailed;
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return error.ParseFailed;

    if (obj.get("jobId")) |v| {
        if (v == .string) return allocator.dupe(u8, v.string);
    }

    return error.ParseFailed;
}

fn parseSettingValue(allocator: std.mem.Allocator, body: []const u8) ![]const u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return error.ParseFailed;
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return error.ParseFailed;

    if (obj.get("value")) |v| {
        if (v == .string) return allocator.dupe(u8, v.string);
    }

    return error.ParseFailed;
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
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "/backup?api-version=") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "settings/AllowKeyManagementOperationsThroughARM") != null);
}
