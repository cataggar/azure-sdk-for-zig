//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `Account` as returned by Azure DevOps.
pub const AccountList = struct {
    count: ?i32 = null,
    value: ?[]const Account = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Account = struct {
    /// Identifier for an Account
    account_id: ?[]const u8 = null,
    /// Name for an account
    account_name: ?[]const u8 = null,
    /// Owner of account
    account_owner: ?[]const u8 = null,
    /// Current account status
    account_status: ?enums.AccountAccountStatus = null,
    /// Type of account: Personal, Organization
    account_type: ?enums.AccountAccountType = null,
    /// Uri for an account
    account_uri: ?[]const u8 = null,
    /// Who created the account
    created_by: ?[]const u8 = null,
    /// Date account was created
    created_date: ?[]const u8 = null,
    has_moved: ?bool = null,
    /// Identity of last person to update the account
    last_updated_by: ?[]const u8 = null,
    /// Date account was last updated
    last_updated_date: ?[]const u8 = null,
    /// Namespace for an account
    namespace_id: ?[]const u8 = null,
    new_collection_id: ?[]const u8 = null,
    /// Organization that created the account
    organization_name: ?[]const u8 = null,
    properties: ?PropertiesCollection = null,
    /// Reason for current status
    status_reason: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class represents a property bag as a collection of key-value pairs. Values of all primitive types (any type with a `TypeCode != TypeCode.Object`) except for `DBNull` are accepted. Values of type Byte[], Int32, Double, DateType and String preserve their type, other primitives are retuned as a String. Byte[] expected as base64 encoded string.
pub const PropertiesCollection = struct {
    /// The count of properties in the collection.
    count: ?i32 = null,
    item: ?PropertiesCollectionItem = null,
    /// The set of keys in the collection.
    keys: ?[]const []const u8 = null,
    /// The set of values in the collection.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PropertiesCollectionItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};
