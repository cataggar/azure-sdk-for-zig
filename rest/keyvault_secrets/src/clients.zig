//! Generated service clients.

const std = @import("std");
const core = @import("azure_core");
const models = @import("models.zig");
const enums = @import("enums.zig");

/// The key vault client performs cryptographic key operations and vault operations against the Key Vault service.
pub const KeyVaultClient = struct {
    allocator: std.mem.Allocator,
    pipeline: core.pipeline.HttpPipeline,
    endpoint: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        credential: core.credentials.TokenCredential,
        transport: core.http.Transport,
        options: ClientOptions,
    ) KeyVaultClient {
        _ = options;
        _ = credential;
        return .{
            .allocator = allocator,
            .endpoint = endpoint,
            .pipeline = core.pipeline.HttpPipeline.init(allocator, transport),
        };
    }

    pub const ClientOptions = struct {};
    /// The SET operation adds a secret to the Azure Key Vault. If the named secret already exists, Azure Key Vault creates a new version of that secret. This operation requires the secrets/set permission.
    pub fn setSecret(self: *@This(), secret_name: []const u8, parameters: models.SecretSetParameters, content_type: std.json.Value, accept: std.json.Value) !models.SecretBundle {
        _ = self;
        _ = secret_name;
        _ = parameters;
        _ = content_type;
        _ = accept;
        return error.NotImplemented;
    }
    /// The DELETE operation applies to any secret stored in Azure Key Vault. DELETE cannot be applied to an individual version of a secret. This operation requires the secrets/delete permission.
    pub fn deleteSecret(self: *@This(), secret_name: []const u8, accept: std.json.Value) !models.DeletedSecretBundle {
        _ = self;
        _ = secret_name;
        _ = accept;
        return error.NotImplemented;
    }
    /// The UPDATE operation changes specified attributes of an existing stored secret. Attributes that are not specified in the request are left unchanged. The value of a secret itself cannot be changed. This operation requires the secrets/set permission.
    pub fn updateSecret(self: *@This(), secret_name: []const u8, secret_version: []const u8, parameters: models.SecretUpdateParameters, content_type: std.json.Value, accept: std.json.Value) !models.SecretBundle {
        _ = self;
        _ = secret_name;
        _ = secret_version;
        _ = parameters;
        _ = content_type;
        _ = accept;
        return error.NotImplemented;
    }
    /// The GET operation is applicable to any secret stored in Azure Key Vault. This operation requires the secrets/get permission.
    pub fn getSecret(self: *@This(), secret_name: []const u8, secret_version: []const u8, out_content_type: ?enums.ContentType, accept: std.json.Value) !models.SecretBundle {
        _ = self;
        _ = secret_name;
        _ = secret_version;
        _ = out_content_type;
        _ = accept;
        return error.NotImplemented;
    }
    /// The Get Secrets operation is applicable to the entire vault. However, only the base secret identifier and its attributes are provided in the response. Individual secret versions are not listed in the response. This operation requires the secrets/list permission.
    pub fn getSecrets(self: *@This(), maxresults: ?i32, accept: std.json.Value) ![]const models.SecretItem {
        _ = self;
        _ = maxresults;
        _ = accept;
        return error.NotImplemented;
    }
    /// The full secret identifier and attributes are provided in the response. No values are returned for the secrets. This operations requires the secrets/list permission.
    pub fn getSecretVersions(self: *@This(), secret_name: []const u8, maxresults: ?i32, accept: std.json.Value) ![]const models.SecretItem {
        _ = self;
        _ = secret_name;
        _ = maxresults;
        _ = accept;
        return error.NotImplemented;
    }
    /// The Get Deleted Secrets operation returns the secrets that have been deleted for a vault enabled for soft-delete. This operation requires the secrets/list permission.
    pub fn getDeletedSecrets(self: *@This(), maxresults: ?i32, accept: std.json.Value) ![]const models.DeletedSecretItem {
        _ = self;
        _ = maxresults;
        _ = accept;
        return error.NotImplemented;
    }
    /// The Get Deleted Secret operation returns the specified deleted secret along with its attributes. This operation requires the secrets/get permission.
    pub fn getDeletedSecret(self: *@This(), secret_name: []const u8, accept: std.json.Value) !models.DeletedSecretBundle {
        _ = self;
        _ = secret_name;
        _ = accept;
        return error.NotImplemented;
    }
    /// The purge deleted secret operation removes the secret permanently, without the possibility of recovery. This operation can only be enabled on a soft-delete enabled vault. This operation requires the secrets/purge permission.
    pub fn purgeDeletedSecret(self: *@This(), secret_name: []const u8) !void {
        _ = self;
        _ = secret_name;
        return error.NotImplemented;
    }
    /// Recovers the deleted secret in the specified vault. This operation can only be performed on a soft-delete enabled vault. This operation requires the secrets/recover permission.
    pub fn recoverDeletedSecret(self: *@This(), secret_name: []const u8, accept: std.json.Value) !models.SecretBundle {
        _ = self;
        _ = secret_name;
        _ = accept;
        return error.NotImplemented;
    }
    /// Requests that a backup of the specified secret be downloaded to the client. All versions of the secret will be downloaded. This operation requires the secrets/backup permission.
    pub fn backupSecret(self: *@This(), secret_name: []const u8, accept: std.json.Value) !models.BackupSecretResult {
        _ = self;
        _ = secret_name;
        _ = accept;
        return error.NotImplemented;
    }
    /// Restores a backed up secret, and all its versions, to a vault. This operation requires the secrets/restore permission.
    pub fn restoreSecret(self: *@This(), parameters: models.SecretRestoreParameters, content_type: std.json.Value, accept: std.json.Value) !models.SecretBundle {
        _ = self;
        _ = parameters;
        _ = content_type;
        _ = accept;
        return error.NotImplemented;
    }
};
