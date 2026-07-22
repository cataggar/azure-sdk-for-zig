//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// The secret set parameters.
pub const SecretSetParameters = struct {
    /// The value of the secret.
    value: []const u8,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// Type of the secret value such as a password.
    content_type: ?[]const u8 = null,
    /// The secret management attributes.
    secret_attributes: ?SecretAttributes = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .secret_attributes = "attributes",
        },
    };
};

/// The secret management attributes.
pub const SecretAttributes = struct {
    /// Determines whether the object is enabled.
    enabled: ?bool = null,
    /// Not before date in UTC.
    not_before: ?[]const u8 = null,
    /// Expiry date in UTC.
    expires: ?[]const u8 = null,
    /// Creation time in UTC.
    created: ?[]const u8 = null,
    /// Last updated time in UTC.
    updated: ?[]const u8 = null,
    /// softDelete data retention days. Value should be >=7 and <=90 when softDelete enabled, otherwise 0.
    recoverable_days: ?i32 = null,
    /// Reflects the deletion recovery level currently in effect for secrets in the current vault. If it contains 'Purgeable', the secret can be permanently deleted by a privileged user; otherwise, only the system can purge the secret, at the end of the retention interval.
    recovery_level: ?enums.DeletionRecoveryLevel = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .not_before = "nbf",
            .expires = "exp",
        },
    };
};

/// A secret consisting of a value, id and its attributes.
pub const SecretBundle = struct {
    /// The secret value.
    value: ?[]const u8 = null,
    /// The secret id.
    id: ?[]const u8 = null,
    /// The content type of the secret.
    content_type: ?[]const u8 = null,
    /// The secret management attributes.
    attributes: ?SecretAttributes = null,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// If this is a secret backing a KV certificate, then this field specifies the corresponding key backing the KV certificate.
    kid: ?[]const u8 = null,
    /// True if the secret's lifetime is managed by key vault. If this is a secret backing a certificate, then managed will be true.
    managed: ?bool = null,
    /// The version of the previous certificate, if applicable. Applies only to certificates created after June 1, 2025. Certificates created before this date are not retroactively updated.
    previous_version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The key vault error exception.
pub const KeyVaultError = struct {
    /// The key vault server error.
    @"error": ?KeyVaultErrorError = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const KeyVaultErrorError = struct {
    /// The error code.
    code: ?[]const u8 = null,
    /// The error message.
    message: ?[]const u8 = null,
    /// The key vault server error.
    inner_error: ?KeyVaultErrorError = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .inner_error = "innererror",
        },
    };
};

/// A Deleted Secret consisting of its previous id, attributes and its tags, as well as information on when it will be purged.
pub const DeletedSecretBundle = struct {
    /// The secret value.
    value: ?[]const u8 = null,
    /// The secret id.
    id: ?[]const u8 = null,
    /// The content type of the secret.
    content_type: ?[]const u8 = null,
    /// The secret management attributes.
    attributes: ?SecretAttributes = null,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// If this is a secret backing a KV certificate, then this field specifies the corresponding key backing the KV certificate.
    kid: ?[]const u8 = null,
    /// True if the secret's lifetime is managed by key vault. If this is a secret backing a certificate, then managed will be true.
    managed: ?bool = null,
    /// The version of the previous certificate, if applicable. Applies only to certificates created after June 1, 2025. Certificates created before this date are not retroactively updated.
    previous_version: ?[]const u8 = null,
    /// The url of the recovery object, used to identify and recover the deleted secret.
    recovery_id: ?[]const u8 = null,
    /// The time when the secret is scheduled to be purged, in UTC
    scheduled_purge_date: ?[]const u8 = null,
    /// The time when the secret was deleted, in UTC
    deleted_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The secret update parameters.
pub const SecretUpdateParameters = struct {
    /// Type of the secret value such as a password.
    content_type: ?[]const u8 = null,
    /// The secret management attributes.
    secret_attributes: ?SecretAttributes = null,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .secret_attributes = "attributes",
        },
    };
};

/// The secret list result.
pub const SecretListResult = struct {
    /// A response message containing a list of secrets in the key vault along with a link to the next page of secrets.
    value: ?[]const SecretItem = null,
    /// The URL to get the next set of secrets.
    next_link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The secret item containing secret metadata.
pub const SecretItem = struct {
    /// Secret identifier.
    id: ?[]const u8 = null,
    /// The secret management attributes.
    attributes: ?SecretAttributes = null,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// Type of the secret value such as a password.
    content_type: ?[]const u8 = null,
    /// True if the secret's lifetime is managed by key vault. If this is a key backing a certificate, then managed will be true.
    managed: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The deleted secret list result
pub const DeletedSecretListResult = struct {
    /// A response message containing a list of deleted secrets in the key vault along with a link to the next page of deleted secrets.
    value: ?[]const DeletedSecretItem = null,
    /// The URL to get the next set of deleted secrets.
    next_link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The deleted secret item containing metadata about the deleted secret.
pub const DeletedSecretItem = struct {
    /// Secret identifier.
    id: ?[]const u8 = null,
    /// The secret management attributes.
    attributes: ?SecretAttributes = null,
    /// Application specific metadata in the form of key-value pairs.
    tags: ?std.json.ArrayHashMap([]const u8) = null,
    /// Type of the secret value such as a password.
    content_type: ?[]const u8 = null,
    /// True if the secret's lifetime is managed by key vault. If this is a key backing a certificate, then managed will be true.
    managed: ?bool = null,
    /// The url of the recovery object, used to identify and recover the deleted secret.
    recovery_id: ?[]const u8 = null,
    /// The time when the secret is scheduled to be purged, in UTC
    scheduled_purge_date: ?[]const u8 = null,
    /// The time when the secret was deleted, in UTC
    deleted_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The backup secret result, containing the backup blob.
pub const BackupSecretResult = struct {
    /// The backup blob containing the backed up secret.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The secret restore parameters.
pub const SecretRestoreParameters = struct {
    /// The backup blob associated with a secret bundle.
    secret_bundle_backup: []const u8,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .secret_bundle_backup = "value",
        },
    };
};
