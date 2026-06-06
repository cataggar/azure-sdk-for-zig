//! Generated service clients.

const std = @import("std");
const serde = @import("serde");
const core = @import("azure_core");
const models = @import("models.zig");
const enums = @import("enums.zig");

const default_api_version = "2026-03-01-preview";
const auth_scopes: []const []const u8 = &.{"https://vault.azure.net/.default"};

/// The key vault client performs cryptographic key operations and vault operations against the Key Vault service.
pub const KeyVaultClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,
    allocator: std.mem.Allocator,
    auth_policy: *core.pipeline.BearerTokenAuthPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,

    pub const InitOptions = struct {
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        endpoint: []const u8,
        api_version: []const u8 = default_api_version,
    };

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !KeyVaultClient {
        const auth_policy = try allocator.create(core.pipeline.BearerTokenAuthPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = core.pipeline.BearerTokenAuthPolicy.init(
            allocator,
            options.credential,
            auth_scopes,
        );

        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = auth_policy.asPolicy();

        return .{
            .allocator = allocator,
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .auth_policy = auth_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = .{
                .policies = policy_ptrs,
                .transport_impl = options.transport,
            },
        };
    }

    pub fn deinit(self: *@This()) void {
        self.auth_policy.deinit();
        self.allocator.destroy(self.auth_policy);
        self.allocator.free(self.policy_ptrs);
    }
    /// The SET operation adds a secret to the Azure Key Vault. If the named secret already exists, Azure Key Vault creates a new version of that secret. This operation requires the secrets/set permission.
    pub fn setSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8, parameters: models.SecretSetParameters) !models.SecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/secrets/{s}?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, parameters);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.setSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SecretBundle, alloc, resp.body);
    }
    /// The DELETE operation applies to any secret stored in Azure Key Vault. DELETE cannot be applied to an individual version of a secret. This operation requires the secrets/delete permission.
    pub fn deleteSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8) !models.DeletedSecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/secrets/{s}?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.deleteSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.DeletedSecretBundle, alloc, resp.body);
    }
    /// The UPDATE operation changes specified attributes of an existing stored secret. Attributes that are not specified in the request are left unchanged. The value of a secret itself cannot be changed. This operation requires the secrets/set permission.
    pub fn updateSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8, secret_version: []const u8, parameters: models.SecretUpdateParameters) !models.SecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/secrets/{s}/{s}?api-version={s}", .{ self.endpoint, secret_name, secret_version, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .PATCH, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, parameters);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.updateSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SecretBundle, alloc, resp.body);
    }
    /// The GET operation is applicable to any secret stored in Azure Key Vault. This operation requires the secrets/get permission.
    pub fn getSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8, secret_version: []const u8, out_content_type: ?enums.ContentType) !models.SecretBundle {
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.print(alloc, "{s}/secrets/{s}/{s}?api-version={s}", .{ self.endpoint, secret_name, secret_version, self.api_version });
        if (out_content_type) |v| {
            const enc = try core.url.percentEncode(alloc, v.toWire());
            defer alloc.free(enc);
            try url_buf.print(alloc, "&outContentType={s}", .{enc});
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.getSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SecretBundle, alloc, resp.body);
    }
    /// The Get Secrets operation is applicable to the entire vault. However, only the base secret identifier and its attributes are provided in the response. Individual secret versions are not listed in the response. This operation requires the secrets/list permission.
    pub fn getSecrets(self: *@This(), alloc: std.mem.Allocator, maxresults: ?i32) !core.pager.PipelinePager(models.SecretItem) {
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.print(alloc, "{s}/secrets?api-version={s}", .{ self.endpoint, self.api_version });
        if (maxresults) |v| {
            try url_buf.print(alloc, "&maxresults={d}", .{v});
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.PipelinePager(models.SecretItem).init(
            self.pipeline,
            url,
            alloc,
            core.pager.listPageParser(models.SecretItem),
            "application/json",
        );
    }
    /// The full secret identifier and attributes are provided in the response. No values are returned for the secrets. This operations requires the secrets/list permission.
    pub fn getSecretVersions(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8, maxresults: ?i32) !core.pager.PipelinePager(models.SecretItem) {
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.print(alloc, "{s}/secrets/{s}/versions?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        if (maxresults) |v| {
            try url_buf.print(alloc, "&maxresults={d}", .{v});
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.PipelinePager(models.SecretItem).init(
            self.pipeline,
            url,
            alloc,
            core.pager.listPageParser(models.SecretItem),
            "application/json",
        );
    }
    /// The Get Deleted Secrets operation returns the secrets that have been deleted for a vault enabled for soft-delete. This operation requires the secrets/list permission.
    pub fn getDeletedSecrets(self: *@This(), alloc: std.mem.Allocator, maxresults: ?i32) !core.pager.PipelinePager(models.DeletedSecretItem) {
        var url_buf: std.ArrayList(u8) = .empty;
        defer url_buf.deinit(alloc);
        try url_buf.print(alloc, "{s}/deletedsecrets?api-version={s}", .{ self.endpoint, self.api_version });
        if (maxresults) |v| {
            try url_buf.print(alloc, "&maxresults={d}", .{v});
        }
        const url = try url_buf.toOwnedSlice(alloc);
        defer alloc.free(url);
        return core.pager.PipelinePager(models.DeletedSecretItem).init(
            self.pipeline,
            url,
            alloc,
            core.pager.listPageParser(models.DeletedSecretItem),
            "application/json",
        );
    }
    /// The Get Deleted Secret operation returns the specified deleted secret along with its attributes. This operation requires the secrets/get permission.
    pub fn getDeletedSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8) !models.DeletedSecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/deletedsecrets/{s}?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.getDeletedSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.DeletedSecretBundle, alloc, resp.body);
    }
    /// The purge deleted secret operation removes the secret permanently, without the possibility of recovery. This operation can only be enabled on a soft-delete enabled vault. This operation requires the secrets/purge permission.
    pub fn purgeDeletedSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8) !void {
        const url = try std.fmt.allocPrint(alloc, "{s}/deletedsecrets/{s}?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.purgeDeletedSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return;
    }
    /// Recovers the deleted secret in the specified vault. This operation can only be performed on a soft-delete enabled vault. This operation requires the secrets/recover permission.
    pub fn recoverDeletedSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8) !models.SecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/deletedsecrets/{s}/recover?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.recoverDeletedSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SecretBundle, alloc, resp.body);
    }
    /// Requests that a backup of the specified secret be downloaded to the client. All versions of the secret will be downloaded. This operation requires the secrets/backup permission.
    pub fn backupSecret(self: *@This(), alloc: std.mem.Allocator, secret_name: []const u8) !models.BackupSecretResult {
        const url = try std.fmt.allocPrint(alloc, "{s}/secrets/{s}/backup?api-version={s}", .{ self.endpoint, secret_name, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.backupSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.BackupSecretResult, alloc, resp.body);
    }
    /// Restores a backed up secret, and all its versions, to a vault. This operation requires the secrets/restore permission.
    pub fn restoreSecret(self: *@This(), alloc: std.mem.Allocator, parameters: models.SecretRestoreParameters) !models.SecretBundle {
        const url = try std.fmt.allocPrint(alloc, "{s}/secrets/restore?api-version={s}", .{ self.endpoint, self.api_version });
        defer alloc.free(url);
        var req = core.http.Request.init(alloc, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        const body_json = try serde.json.toSlice(alloc, parameters);
        defer alloc.free(body_json);
        req.body = body_json;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.pager.logHttpError("KeyVaultClient.restoreSecret", resp.status_code, resp.body);
            return error.AzureRequestFailed;
        }
        return try serde.json.fromSlice(models.SecretBundle, alloc, resp.body);
    }
};
