//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const JsonValue = union(enum) {
    null_value: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringArrayHashMapUnmanaged(JsonValue),

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        const saved = deserializer.*;
        if (deserializer.deserializeVoid()) |_| {
            return .{ .null_value = {} };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeBool()) |value| {
            return .{ .boolean = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeInt(i64)) |value| {
            return .{ .integer = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeFloat(f64)) |value| {
            return .{ .float = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeString(allocator)) |value| {
            return .{ .string = value };
        } else |_| deserializer.* = saved;

        if (deserializer.deserializeSeqAccess()) |sequence_value| {
            var sequence = sequence_value;
            var values: std.ArrayList(JsonValue) = .empty;
            errdefer values.deinit(allocator);
            while (try sequence.nextElement(JsonValue, allocator)) |value| {
                values.append(allocator, value) catch
                    return deserializer.raiseError(error.OutOfMemory);
            }
            return .{ .array = values.toOwnedSlice(allocator) catch
                return deserializer.raiseError(error.OutOfMemory) };
        } else |_| deserializer.* = saved;

        var map = deserializer.deserializeStruct(T) catch
            return deserializer.raiseError(error.UnexpectedToken);
        var values: std.StringArrayHashMapUnmanaged(JsonValue) = .empty;
        errdefer values.deinit(allocator);
        while (try map.nextKey(allocator)) |key| {
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            values.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return .{ .object = values };
    }

    pub fn zerdeSerialize(self: JsonValue, serializer: anytype) @TypeOf(serializer.*).Error!void {
        switch (self) {
            .null_value => return serializer.serializeNull(),
            .boolean => |value| return serializer.serializeBool(value),
            .integer => |value| return serializer.serializeInt(value),
            .float => |value| return serializer.serializeFloat(value),
            .string => |value| return serializer.serializeString(value),
            .array => |values| {
                var array = try serializer.beginArray();
                for (values) |value| try value.zerdeSerialize(&array);
                return array.end();
            },
            .object => |values| {
                var object = try serializer.beginStruct();
                var iterator = values.iterator();
                while (iterator.next()) |entry| {
                    try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
                }
                return object.end();
            },
        }
    }
};

/// The blob service properties.
pub const BlobServiceProperties = struct {
    /// The logging properties.
    logging: ?Logging = null,
    /// The hour metrics properties.
    hour_metrics: ?Metrics = null,
    /// The minute metrics properties.
    minute_metrics: ?Metrics = null,
    /// The CORS properties.
    cors: ?CorsXml = null,
    /// The default service version.
    default_service_version: ?[]const u8 = null,
    /// The delete retention policy.
    delete_retention_policy: ?RetentionPolicy = null,
    /// The static website properties.
    static_website: ?StaticWebsite = null,
    pub const CorsXml = struct {
        items: []const CorsRule = &.{},
        pub const serde = .{ .rename = .{ .items = "CorsRule" } };
    };

    pub const serde = .{
        .xml_root = "StorageServiceProperties",
        .rename = .{
            .logging = "Logging",
            .hour_metrics = "HourMetrics",
            .minute_metrics = "MinuteMetrics",
            .cors = "Cors",
            .default_service_version = "DefaultServiceVersion",
            .delete_retention_policy = "DeleteRetentionPolicy",
            .static_website = "StaticWebsite",
        },
    };
};

/// Azure Analytics logging settings.
pub const Logging = struct {
    /// The version of the logging properties.
    version: []const u8,
    /// Whether delete operation is logged.
    delete: bool,
    /// Whether read operation is logged.
    read: bool,
    /// Whether write operation is logged.
    write: bool,
    /// The retention policy of the logs.
    retention_policy: RetentionPolicy,

    pub const serde = .{
        .xml_root = "Logging",
        .rename = .{
            .version = "Version",
            .delete = "Delete",
            .read = "Read",
            .write = "Write",
            .retention_policy = "RetentionPolicy",
        },
    };
};

/// The retention policy.
pub const RetentionPolicy = struct {
    /// Whether the policy is enabled.
    enabled: bool,
    /// The number of days to retain the logs.
    days: ?i32 = null,
    /// Whether to allow permanent delete.
    allow_permanent_delete: ?bool = null,

    pub const serde = .{
        .xml_root = "RetentionPolicy",
        .rename = .{
            .enabled = "Enabled",
            .days = "Days",
            .allow_permanent_delete = "AllowPermanentDelete",
        },
    };
};

/// The metrics properties.
pub const Metrics = struct {
    /// The version of the metrics properties.
    version: ?[]const u8 = null,
    /// Whether the metrics are enabled.
    enabled: bool,
    /// Whether to include API in the metrics.
    include_apis: ?bool = null,
    /// The retention policy of the metrics.
    retention_policy: ?RetentionPolicy = null,

    pub const serde = .{
        .xml_root = "Metrics",
        .rename = .{
            .version = "Version",
            .enabled = "Enabled",
            .include_apis = "IncludeAPIs",
            .retention_policy = "RetentionPolicy",
        },
    };
};

/// A Cross-Origin Resource Sharing (CORS) rule.
pub const CorsRule = struct {
    /// The allowed origins.
    allowed_origins: []const u8,
    /// The allowed methods.
    allowed_methods: []const u8,
    /// The allowed headers.
    allowed_headers: []const u8,
    /// The exposed headers.
    exposed_headers: []const u8,
    /// The maximum age in seconds.
    max_age_in_seconds: i32,

    pub const serde = .{
        .xml_root = "CorsRule",
        .rename = .{
            .allowed_origins = "AllowedOrigins",
            .allowed_methods = "AllowedMethods",
            .allowed_headers = "AllowedHeaders",
            .exposed_headers = "ExposedHeaders",
            .max_age_in_seconds = "MaxAgeInSeconds",
        },
    };
};

/// The properties that enable an account to host a static website.
pub const StaticWebsite = struct {
    /// Indicates whether this account is hosting a static website.
    enabled: bool,
    /// The index document.
    index_document: ?[]const u8 = null,
    /// The error document.
    error_document404_path: ?[]const u8 = null,
    /// Absolute path of the default index page.
    default_index_document_path: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "StaticWebsite",
        .rename = .{
            .enabled = "Enabled",
            .index_document = "IndexDocument",
            .error_document404_path = "ErrorDocument404Path",
            .default_index_document_path = "DefaultIndexDocumentPath",
        },
    };
};

/// The error response.
///
/// This defines the wire format only. Language SDKs wrap this in idiomatic error types.
pub const Error = struct {
    /// The error code.
    error_code: ?[]const u8 = null,
    /// The error code for the copy source.
    x_ms_copy_source_error_code: ?[]const u8 = null,
    /// The status code for the copy source.
    x_ms_copy_source_status_code: ?i32 = null,
    /// The error code.
    code: ?enums.StorageErrorCode = null,
    /// The error message.
    message: ?[]const u8 = null,
    /// The copy source status code.
    copy_source_status_code: ?i32 = null,
    /// The copy source error code.
    copy_source_error_code: ?[]const u8 = null,
    /// The copy source error message.
    copy_source_error_message: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "Error",
        .rename = .{
            .error_code = "errorCode",
            .x_ms_copy_source_error_code = "xMsCopySourceErrorCode",
            .x_ms_copy_source_status_code = "xMsCopySourceStatusCode",
            .code = "Code",
            .message = "Message",
            .copy_source_status_code = "CopySourceStatusCode",
            .copy_source_error_code = "CopySourceErrorCode",
            .copy_source_error_message = "CopySourceErrorMessage",
        },
    };
};

/// Stats for the storage service.
pub const StorageServiceStats = struct {
    /// The geo-replication stats.
    geo_replication: ?GeoReplication = null,

    pub const serde = .{
        .xml_root = "StorageServiceStats",
        .rename = .{
            .geo_replication = "GeoReplication",
        },
    };
};

/// Geo-replication information for the secondary storage service.
pub const GeoReplication = struct {
    /// The status of the secondary location.
    status: ?enums.GeoReplicationStatusType = null,
    /// A date-time value that indicates where all primary writes preceding this value are guaranteed to be available for read operations at the secondary. Primary writes after this point in time may or may not be available for reads.
    last_sync_time: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "GeoReplication",
        .rename = .{
            .status = "Status",
            .last_sync_time = "LastSyncTime",
        },
    };
};

/// The result of the List Containers API.
pub const ListContainersResponse = struct {
    /// The service endpoint.
    service_endpoint: ?[]const u8 = null,
    /// The prefix of the containers.
    prefix: ?[]const u8 = null,
    /// An opaque string value that identifies the portion of the result set returned with this operation.
    marker: ?[]const u8 = null,
    /// The maximum number of containers to be returned with this operation.
    max_results: ?i32 = null,
    /// The list of containers.
    container_items: ContainerItemsXml = .{},
    /// An opaque string value that identifies the portion of the result set to be returned with the next operation. Use this value in the next request to continue the listing operation.
    next_marker: ?[]const u8 = null,
    pub const ContainerItemsXml = struct {
        items: []const ContainerItem = &.{},
        pub const serde = .{ .rename = .{ .items = "Container" } };
    };

    pub const serde = .{
        .xml_root = "EnumerationResults",
        .xml_attribute = .{.service_endpoint},
        .rename = .{
            .service_endpoint = "ServiceEndpoint",
            .prefix = "Prefix",
            .marker = "Marker",
            .max_results = "MaxResults",
            .container_items = "Containers",
            .next_marker = "NextMarker",
        },
    };
};

/// Represents a container.
pub const ContainerItem = struct {
    /// The name of the container.
    name: ?[]const u8 = null,
    /// Whether the container is soft-deleted.
    deleted: ?bool = null,
    /// The version of the container.
    version: ?[]const u8 = null,
    /// The properties of the container.
    properties: ?ContainerProperties = null,
    /// The metadata of the container.
    metadata: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .xml_root = "Container",
        .rename = .{
            .name = "Name",
            .deleted = "Deleted",
            .version = "Version",
            .properties = "Properties",
            .metadata = "Metadata",
        },
    };
};

/// The properties of a container.
pub const ContainerProperties = struct {
    /// The date-time that the container was last modified.
    last_modified: ?[]const u8 = null,
    /// The ETag of the container.
    e_tag: ?[]const u8 = null,
    /// The lease status of the container.
    lease_status: ?enums.LeaseStatus = null,
    /// The lease state of the container.
    lease_state: ?enums.LeaseState = null,
    /// The lease duration of the container.
    lease_duration: ?enums.LeaseDuration = null,
    /// The public access type of the container.
    public_access: ?enums.PublicAccessType = null,
    /// Whether the container has an immutability policy.
    has_immutability_policy: ?bool = null,
    /// Whether the container has a legal hold.
    has_legal_hold: ?bool = null,
    /// The default encryption scope of the container.
    default_encryption_scope: ?[]const u8 = null,
    /// Whether to prevent encryption scope override.
    prevent_encryption_scope_override: ?bool = null,
    /// The date-time the container was deleted.
    deleted_time: ?[]const u8 = null,
    /// The remaining retention days of the container.
    remaining_retention_days: ?i32 = null,
    /// Whether immutable storage with versioning is enabled.
    is_immutable_storage_with_versioning_enabled: ?bool = null,

    pub const serde = .{
        .xml_root = "ContainerProperties",
        .rename = .{
            .last_modified = "Last-Modified",
            .e_tag = "Etag",
            .lease_status = "LeaseStatus",
            .lease_state = "LeaseState",
            .lease_duration = "LeaseDuration",
            .public_access = "PublicAccess",
            .has_immutability_policy = "HasImmutabilityPolicy",
            .has_legal_hold = "HasLegalHold",
            .default_encryption_scope = "DefaultEncryptionScope",
            .prevent_encryption_scope_override = "DenyEncryptionScopeOverride",
            .deleted_time = "DeletedTime",
            .remaining_retention_days = "RemainingRetentionDays",
            .is_immutable_storage_with_versioning_enabled = "ImmutableStorageWithVersioningEnabled",
        },
    };
};

/// Key information.
pub const KeyInfo = struct {
    /// The date-time the key is active.
    start: []const u8,
    /// The date-time the key expires.
    expiry: []const u8,
    /// The delegated user tenant ID in Entra ID.
    delegated_user_tid: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "KeyInfo",
        .rename = .{
            .start = "Start",
            .expiry = "Expiry",
            .delegated_user_tid = "DelegatedUserTid",
        },
    };
};

/// A user delegation key.
pub const UserDelegationKey = struct {
    /// The Entra ID object ID in GUID format.
    signed_oid: ?[]const u8 = null,
    /// The Entra ID tenant ID in GUID format.
    signed_tid: ?[]const u8 = null,
    /// The date-time the key is active.
    signed_start: ?[]const u8 = null,
    /// The date-time the key expires.
    signed_expiry: ?[]const u8 = null,
    /// Abbreviation of the Azure Storage service that accepts the key.
    signed_service: ?[]const u8 = null,
    /// The service version that created the key.
    signed_version: ?[]const u8 = null,
    /// The delegated user tenant ID in Entra ID. Returned if DelegatedUserTid is specified.
    signed_delegated_user_tid: ?[]const u8 = null,
    /// The base64 encoded key value.
    value: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "UserDelegationKey",
        .rename = .{
            .signed_oid = "SignedOid",
            .signed_tid = "SignedTid",
            .signed_start = "SignedStart",
            .signed_expiry = "SignedExpiry",
            .signed_service = "SignedService",
            .signed_version = "SignedVersion",
            .signed_delegated_user_tid = "SignedDelegatedUserTid",
            .value = "Value",
        },
    };
};

pub const SubmitBatchRequest = struct {
    body: []const u8,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The result of the Find Blobs by Tags API.
pub const FilteredBlobResponse = struct {
    /// The service endpoint.
    service_endpoint: ?[]const u8 = null,
    /// The filter expression for the blobs.
    where: ?[]const u8 = null,
    /// The list of filtered blobs.
    blob_items: BlobItemsXml = .{},
    /// An opaque string value that identifies the portion of the result set to be returned with the next operation. Use this value in the next request to continue the listing operation.
    next_marker: ?[]const u8 = null,
    pub const BlobItemsXml = struct {
        items: []const FilterBlobItem = &.{},
        pub const serde = .{ .rename = .{ .items = "Blob" } };
    };

    pub const serde = .{
        .xml_root = "EnumerationResults",
        .xml_attribute = .{.service_endpoint},
        .rename = .{
            .service_endpoint = "ServiceEndpoint",
            .where = "Where",
            .blob_items = "Blobs",
            .next_marker = "NextMarker",
        },
    };
};

/// The filtered blob item.
pub const FilterBlobItem = struct {
    /// The name of the blob.
    name: ?[]const u8 = null,
    /// The name of the container.
    container_name: ?[]const u8 = null,
    /// The tags of the blob.
    tags: ?BlobTags = null,
    /// The version ID of the blob.
    version_id: ?[]const u8 = null,
    /// Whether it is the current version of the blob.
    is_current_version: ?bool = null,

    pub const serde = .{
        .xml_root = "Blob",
        .rename = .{
            .name = "Name",
            .container_name = "ContainerName",
            .tags = "Tags",
            .version_id = "VersionId",
            .is_current_version = "IsCurrentVersion",
        },
    };
};

/// A list of blob tags.
pub const BlobTags = struct {
    /// A list of blob tags.
    blob_tag_set: BlobTagSetXml = .{},
    pub const BlobTagSetXml = struct {
        items: []const BlobTag = &.{},
        pub const serde = .{ .rename = .{ .items = "Tag" } };
    };

    pub const serde = .{
        .xml_root = "Tags",
        .rename = .{
            .blob_tag_set = "TagSet",
        },
    };
};

/// A key-value pair associated with a blob.
pub const BlobTag = struct {
    /// The key of the tag.
    key: []const u8,
    /// The value of the tag.
    value: []const u8,

    pub const serde = .{
        .xml_root = "Tag",
        .rename = .{
            .key = "Key",
            .value = "Value",
        },
    };
};

/// List of signed identifiers.
pub const SignedIdentifiers = struct {
    /// The list of signed identifiers.
    items: []const SignedIdentifier,

    pub const serde = .{
        .xml_root = "SignedIdentifiers",
        .rename = .{
            .items = "SignedIdentifier",
        },
    };
};

/// A signed identifier.
pub const SignedIdentifier = struct {
    /// The unique ID for the signed identifier.
    id: []const u8,
    /// The access policy for the signed identifier.
    access_policy: ?AccessPolicy = null,

    pub const serde = .{
        .xml_root = "SignedIdentifier",
        .rename = .{
            .id = "Id",
            .access_policy = "AccessPolicy",
        },
    };
};

/// Represents an access policy.
pub const AccessPolicy = struct {
    /// The date-time the policy is active.
    start: ?[]const u8 = null,
    /// The date-time the policy expires.
    expiry: ?[]const u8 = null,
    /// The permissions for the policy.
    permission: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "AccessPolicy",
        .rename = .{
            .start = "Start",
            .expiry = "Expiry",
            .permission = "Permission",
        },
    };
};

/// The result of the List Blobs API.
pub const ListBlobsResponse = struct {
    /// The service endpoint.
    service_endpoint: ?[]const u8 = null,
    /// The container name.
    container_name: ?[]const u8 = null,
    /// The prefix of the list operation.
    prefix: ?[]const u8 = null,
    /// An opaque string value that identifies the portion of the result set returned with this operation.
    marker: ?[]const u8 = null,
    /// The maximum number of blobs to be returned with this operation.
    max_results: ?i32 = null,
    /// The list of blobs.
    blob_items: BlobItemsXml = .{},
    /// An opaque string value that identifies the portion of the result set to be returned with the next operation. Use this value in the next request to continue the listing operation.
    next_marker: ?[]const u8 = null,
    pub const BlobItemsXml = struct {
        items: []const BlobItem = &.{},
        pub const serde = .{ .rename = .{ .items = "Blob" } };
    };

    pub const serde = .{
        .xml_root = "EnumerationResults",
        .xml_attribute = .{ .service_endpoint, .container_name },
        .rename = .{
            .service_endpoint = "ServiceEndpoint",
            .container_name = "ContainerName",
            .prefix = "Prefix",
            .marker = "Marker",
            .max_results = "MaxResults",
            .blob_items = "Blobs",
            .next_marker = "NextMarker",
        },
    };
};

/// Represents a blob.
pub const BlobItem = struct {
    /// The name of the blob.
    name: ?BlobName = null,
    /// Whether the blob is deleted.
    deleted: ?bool = null,
    /// The snapshot of the blob.
    snapshot: ?[]const u8 = null,
    /// The version ID of the blob.
    version_id: ?[]const u8 = null,
    /// Whether the blob is the current version.
    is_current_version: ?bool = null,
    /// The properties of the blob.
    properties: ?BlobProperties = null,
    /// The metadata of the blob.
    metadata: ?BlobMetadata = null,
    /// The tags of the blob.
    blob_tags: ?BlobTags = null,
    /// The object replication metadata of the blob.
    object_replication_metadata: ?ObjectReplicationMetadata = null,
    /// Whether the blob has versions only.
    has_versions_only: ?bool = null,

    pub const serde = .{
        .xml_root = "Blob",
        .rename = .{
            .name = "Name",
            .deleted = "Deleted",
            .snapshot = "Snapshot",
            .version_id = "VersionId",
            .is_current_version = "IsCurrentVersion",
            .properties = "Properties",
            .metadata = "Metadata",
            .blob_tags = "Tags",
            .object_replication_metadata = "OrMetadata",
            .has_versions_only = "HasVersionsOnly",
        },
    };
};

/// Represents a blob name.
pub const BlobName = struct {
    /// Whether the blob name is encoded.
    encoded: ?bool = null,
    /// The blob name.
    content: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "BlobName",
        .xml_attribute = .{.encoded},
        .xml_text = .content,
        .rename = .{
            .encoded = "Encoded",
        },
    };
};

/// The properties of a blob.
pub const BlobProperties = struct {
    /// The date-time the blob was created.
    creation_time: ?[]const u8 = null,
    /// The date-time the blob was last modified.
    last_modified: ?[]const u8 = null,
    /// The blob ETag.
    e_tag: ?[]const u8 = null,
    /// The content length of the blob.
    content_length: ?i64 = null,
    /// The content type of the blob.
    content_type: ?[]const u8 = null,
    /// The content encoding of the blob.
    content_encoding: ?[]const u8 = null,
    /// The content language of the blob.
    content_language: ?[]const u8 = null,
    /// The content MD5 of the blob.
    content_md5: ?[]const u8 = null,
    /// The content disposition of the blob.
    content_disposition: ?[]const u8 = null,
    /// The cache control of the blob.
    cache_control: ?[]const u8 = null,
    /// The sequence number of the blob.
    blob_sequence_number: ?i64 = null,
    /// The blob type.
    blob_type: ?enums.BlobType = null,
    /// The lease status of the blob.
    lease_status: ?enums.LeaseStatus = null,
    /// The lease state of the blob.
    lease_state: ?enums.LeaseState = null,
    /// The lease duration of the blob.
    lease_duration: ?enums.LeaseDuration = null,
    /// The copy ID of the blob.
    copy_id: ?[]const u8 = null,
    /// The copy status of the blob.
    copy_status: ?enums.CopyStatus = null,
    /// The copy source of the blob.
    copy_source: ?[]const u8 = null,
    /// The copy progress of the blob.
    copy_progress: ?[]const u8 = null,
    /// The copy completion date-time of the blob.
    copy_completion_time: ?[]const u8 = null,
    /// The copy status description of the blob.
    copy_status_description: ?[]const u8 = null,
    /// Whether the blob is encrypted on the server.
    server_encrypted: ?bool = null,
    /// Whether the blob is an incremental copy.
    incremental_copy: ?bool = null,
    /// The name of the destination snapshot.
    destination_snapshot: ?[]const u8 = null,
    /// The date-time the blob was deleted.
    deleted_time: ?[]const u8 = null,
    /// The remaining retention days of the blob.
    remaining_retention_days: ?i32 = null,
    /// The access tier of the blob.
    access_tier: ?enums.AccessTier = null,
    /// Whether the access tier is inferred.
    access_tier_inferred: ?bool = null,
    /// The archive status of the blob.
    archive_status: ?enums.ArchiveStatus = null,
    /// The smart access tier of the blob.
    smart_access_tier: ?enums.AccessTier = null,
    /// The SHA-256 hash of the blob's encryption key, if provided.
    customer_provided_key_sha256: ?[]const u8 = null,
    /// The encryption scope of the blob.
    encryption_scope: ?[]const u8 = null,
    /// The date-time that the access tier of the blob changed.
    access_tier_change_time: ?[]const u8 = null,
    /// The number of tags for the blob.
    tag_count: ?i32 = null,
    /// The expiry time of the blob.
    expires_on: ?[]const u8 = null,
    /// Whether the blob is sealed.
    is_sealed: ?bool = null,
    /// The rehydrate priority of the blob.
    rehydrate_priority: ?enums.RehydratePriority = null,
    /// The date-time the blob was last accessed.
    last_accessed_on: ?[]const u8 = null,
    /// The date-time the immutability policy of the blob expires.
    immutability_policy_expires_on: ?[]const u8 = null,
    /// The immutability policy mode of the blob.
    immutability_policy_mode: ?enums.ImmutabilityPolicyMode = null,
    /// Whether the blob is under legal hold.
    legal_hold: ?bool = null,

    pub const serde = .{
        .xml_root = "Properties",
        .rename = .{
            .creation_time = "Creation-Time",
            .last_modified = "Last-Modified",
            .e_tag = "Etag",
            .content_length = "Content-Length",
            .content_type = "Content-Type",
            .content_encoding = "Content-Encoding",
            .content_language = "Content-Language",
            .content_md5 = "Content-MD5",
            .content_disposition = "Content-Disposition",
            .cache_control = "Cache-Control",
            .blob_sequence_number = "x-ms-blob-sequence-number",
            .blob_type = "BlobType",
            .lease_status = "LeaseStatus",
            .lease_state = "LeaseState",
            .lease_duration = "LeaseDuration",
            .copy_id = "CopyId",
            .copy_status = "CopyStatus",
            .copy_source = "CopySource",
            .copy_progress = "CopyProgress",
            .copy_completion_time = "CopyCompletionTime",
            .copy_status_description = "CopyStatusDescription",
            .server_encrypted = "ServerEncrypted",
            .incremental_copy = "IncrementalCopy",
            .destination_snapshot = "DestinationSnapshot",
            .deleted_time = "DeletedTime",
            .remaining_retention_days = "RemainingRetentionDays",
            .access_tier = "AccessTier",
            .access_tier_inferred = "AccessTierInferred",
            .archive_status = "ArchiveStatus",
            .smart_access_tier = "SmartAccessTier",
            .customer_provided_key_sha256 = "CustomerProvidedKeySha256",
            .encryption_scope = "EncryptionScope",
            .access_tier_change_time = "AccessTierChangeTime",
            .tag_count = "TagCount",
            .expires_on = "Expiry-Time",
            .is_sealed = "Sealed",
            .rehydrate_priority = "RehydratePriority",
            .last_accessed_on = "LastAccessTime",
            .immutability_policy_expires_on = "ImmutabilityPolicyUntilDate",
            .immutability_policy_mode = "ImmutabilityPolicyMode",
            .legal_hold = "LegalHold",
        },
    };
};

/// The blob metadata.
pub const BlobMetadata = struct {
    /// Whether the blob metadata is encrypted.
    encrypted: ?[]const u8 = null,
    additional_properties: std.StringArrayHashMapUnmanaged(JsonValue) = .empty,

    pub const serde = .{
        .xml_root = "BlobMetadata",
        .xml_attribute = .{.encrypted},
        .rename = .{
            .encrypted = "Encrypted",
        },
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        var result: T = .{};
        var map = try deserializer.deserializeStruct(T);
        while (try map.nextKey(allocator)) |key| {
            if (std.mem.eql(u8, key, "encrypted")) {
                result.encrypted = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            result.additional_properties.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return result;
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) @TypeOf(serializer.*).Error!void {
        var object = try serializer.beginStruct();
        if (self.encrypted) |value| try object.serializeField("encrypted", value);
        var iterator = self.additional_properties.iterator();
        while (iterator.next()) |entry| {
            try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
        }
        return object.end();
    }
};

/// The object replication metadata.
pub const ObjectReplicationMetadata = struct {
    additional_properties: std.StringArrayHashMapUnmanaged(JsonValue) = .empty,

    pub const serde = .{
        .rename_all = .camel_case,
        .skip = .{ .additional_properties = .always },
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        var result: T = .{};
        var map = try deserializer.deserializeStruct(T);
        while (try map.nextKey(allocator)) |key| {
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            result.additional_properties.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return result;
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) @TypeOf(serializer.*).Error!void {
        var object = try serializer.beginStruct();
        var iterator = self.additional_properties.iterator();
        while (iterator.next()) |entry| {
            try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
        }
        return object.end();
    }
};

/// The result of the List Blobs Hierarchical API.
pub const ListBlobsHierarchicalResponse = struct {
    /// The service endpoint.
    service_endpoint: ?[]const u8 = null,
    /// The container name.
    container_name: ?[]const u8 = null,
    /// The delimiter of the blobs.
    delimiter: ?[]const u8 = null,
    /// The prefix of the blobs.
    prefix: ?[]const u8 = null,
    /// An opaque string value that identifies the portion of the result set returned with this operation.
    marker: ?[]const u8 = null,
    /// The maximum number of blobs to be returned with this operation.
    max_results: ?i32 = null,
    /// The list of hierarchical blobs.
    hierarchical_list: ?BlobHierarchyList = null,
    /// An opaque string value that identifies the portion of the result set to be returned with the next operation. Use this value in the next request to continue the listing operation.
    next_marker: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "EnumerationResults",
        .xml_attribute = .{ .service_endpoint, .container_name },
        .rename = .{
            .service_endpoint = "ServiceEndpoint",
            .container_name = "ContainerName",
            .delimiter = "Delimiter",
            .prefix = "Prefix",
            .marker = "Marker",
            .max_results = "MaxResults",
            .hierarchical_list = "Blobs",
            .next_marker = "NextMarker",
        },
    };
};

/// Represents an array of blobs.
pub const BlobHierarchyList = struct {
    /// The blob items.
    blob_items: ?[]const BlobItem = null,
    /// The blob prefixes.
    blob_prefixes: ?[]const BlobPrefix = null,

    pub const serde = .{
        .xml_root = "BlobHierarchyList",
        .rename = .{
            .blob_items = "Blob",
            .blob_prefixes = "BlobPrefix",
        },
    };
};

/// Represents a blob prefix.
pub const BlobPrefix = struct {
    /// The blob name.
    name: ?BlobName = null,

    pub const serde = .{
        .xml_root = "BlobPrefix",
        .rename = .{
            .name = "Name",
        },
    };
};

/// The block lookup list.
pub const BlockLookupList = struct {
    /// The committed blocks.
    committed: ?[]const []const u8 = null,
    /// The uncommitted blocks.
    uncommitted: ?[]const []const u8 = null,
    /// The latest blocks.
    latest: ?[]const []const u8 = null,

    pub const serde = .{
        .xml_root = "BlockList",
        .rename = .{
            .committed = "Committed",
            .uncommitted = "Uncommitted",
            .latest = "Latest",
        },
    };
};

/// Contains the committed and uncommitted blocks in a block blob.
pub const BlockList = struct {
    /// The list of committed blocks.
    committed_blocks: ?CommittedBlocksXml = null,
    /// The list of uncommitted blocks.
    uncommitted_blocks: ?UncommittedBlocksXml = null,
    pub const CommittedBlocksXml = struct {
        items: []const Block = &.{},
        pub const serde = .{ .rename = .{ .items = "Block" } };
    };
    pub const UncommittedBlocksXml = struct {
        items: []const Block = &.{},
        pub const serde = .{ .rename = .{ .items = "Block" } };
    };

    pub const serde = .{
        .xml_root = "BlockList",
        .rename = .{
            .committed_blocks = "CommittedBlocks",
            .uncommitted_blocks = "UncommittedBlocks",
        },
    };
};

/// Represents a single block in a block blob.
pub const Block = struct {
    /// The base64 encoded block ID.
    name: ?[]const u8 = null,
    /// The block size in bytes.
    size: ?i64 = null,

    pub const serde = .{
        .xml_root = "Block",
        .rename = .{
            .name = "Name",
            .size = "Size",
        },
    };
};

/// Groups the set of query request settings.
pub const QueryRequest = struct {
    /// Required. The type of the provided query expression.
    query_type: enums.QueryRequestType,
    /// The query expression. The maximum size of the query expression is 256KiB.
    expression: []const u8,
    /// The input serialization settings.
    input_serialization: ?QuerySerialization = null,
    /// The output serialization settings.
    output_serialization: ?QuerySerialization = null,

    pub const serde = .{
        .xml_root = "QueryRequest",
        .rename = .{
            .query_type = "QueryType",
            .expression = "Expression",
            .input_serialization = "InputSerialization",
            .output_serialization = "OutputSerialization",
        },
    };
};

/// The query serialization settings.
pub const QuerySerialization = struct {
    /// The query format.
    format: QueryFormat,

    pub const serde = .{
        .xml_root = "QuerySerialization",
        .rename = .{
            .format = "Format",
        },
    };
};

/// The query format settings.
pub const QueryFormat = struct {
    /// The query type.
    type: enums.QueryType,
    /// The delimited text configuration.
    delimited_text_configuration: ?DelimitedTextConfiguration = null,
    /// The JSON text configuration.
    json_text_configuration: ?JsonTextConfiguration = null,
    /// The Apache Arrow configuration.
    arrow_configuration: ?ArrowConfiguration = null,
    /// The Parquet configuration.
    parquet_text_configuration: ?ParquetConfiguration = null,

    pub const serde = .{
        .xml_root = "QueryFormat",
        .rename = .{
            .type = "Type",
            .delimited_text_configuration = "DelimitedTextConfiguration",
            .json_text_configuration = "JsonTextConfiguration",
            .arrow_configuration = "ArrowConfiguration",
            .parquet_text_configuration = "ParquetTextConfiguration",
        },
    };
};

/// Represents the delimited text configuration.
pub const DelimitedTextConfiguration = struct {
    /// The string used to separate columns.
    column_separator: ?[]const u8 = null,
    /// The string used to quote a specific field.
    field_quote: ?[]const u8 = null,
    /// The string used to separate records.
    record_separator: ?[]const u8 = null,
    /// The string used to escape a quote character in a field.
    escape_char: ?[]const u8 = null,
    /// Represents whether the data has headers.
    headers_present: ?bool = null,

    pub const serde = .{
        .xml_root = "DelimitedTextConfiguration",
        .rename = .{
            .column_separator = "ColumnSeparator",
            .field_quote = "FieldQuote",
            .record_separator = "RecordSeparator",
            .escape_char = "EscapeChar",
            .headers_present = "HasHeaders",
        },
    };
};

/// Represents the JSON text configuration.
pub const JsonTextConfiguration = struct {
    /// The string used to separate records.
    record_separator: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "JsonTextConfiguration",
        .rename = .{
            .record_separator = "RecordSeparator",
        },
    };
};

/// Represents the Apache Arrow configuration.
pub const ArrowConfiguration = struct {
    /// The Apache Arrow schema.
    schema: SchemaXml = .{},
    pub const SchemaXml = struct {
        items: []const ArrowField = &.{},
        pub const serde = .{ .rename = .{ .items = "Field" } };
    };

    pub const serde = .{
        .xml_root = "ArrowConfiguration",
        .rename = .{
            .schema = "Schema",
        },
    };
};

/// Represents an Apache Arrow field.
pub const ArrowField = struct {
    /// The arrow field type.
    type: []const u8,
    /// The arrow field name.
    name: ?[]const u8 = null,
    /// The arrow field precision.
    precision: ?i32 = null,
    /// The arrow field scale.
    scale: ?i32 = null,

    pub const serde = .{
        .xml_root = "Field",
        .rename = .{
            .type = "Type",
            .name = "Name",
            .precision = "Precision",
            .scale = "Scale",
        },
    };
};

/// Represents the Parquet configuration.
pub const ParquetConfiguration = struct {
    additional_properties: std.StringArrayHashMapUnmanaged(JsonValue) = .empty,

    pub const serde = .{
        .rename_all = .camel_case,
        .skip = .{ .additional_properties = .always },
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        var result: T = .{};
        var map = try deserializer.deserializeStruct(T);
        while (try map.nextKey(allocator)) |key| {
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            result.additional_properties.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return result;
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) @TypeOf(serializer.*).Error!void {
        var object = try serializer.beginStruct();
        var iterator = self.additional_properties.iterator();
        while (iterator.next()) |entry| {
            try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
        }
        return object.end();
    }
};

/// The result of the Get Pages API.
pub const PageList = struct {
    /// The page ranges.
    page_range: ?[]const PageRange = null,
    /// The clear ranges.
    clear_range: ?[]const ClearRange = null,
    /// An opaque string value that identifies the portion of the result set to be returned with the next operation. Use this value in the next request to continue the listing operation.
    next_marker: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "PageList",
        .rename = .{
            .page_range = "PageRange",
            .clear_range = "ClearRange",
            .next_marker = "NextMarker",
        },
    };
};

/// A page range.
pub const PageRange = struct {
    /// The start of the byte range.
    start: ?i64 = null,
    /// The end of the byte range.
    end: ?i64 = null,

    pub const serde = .{
        .xml_root = "PageRange",
        .rename = .{
            .start = "Start",
            .end = "End",
        },
    };
};

/// A clear range.
pub const ClearRange = struct {
    /// The start of the byte range.
    start: ?i64 = null,
    /// The end of the byte range.
    end: ?i64 = null,

    pub const serde = .{
        .xml_root = "ClearRange",
        .rename = .{
            .start = "Start",
            .end = "End",
        },
    };
};
