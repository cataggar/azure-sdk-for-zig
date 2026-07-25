//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

/// Error codes returned by the Azure Blob Storage service.
pub const StorageErrorCode = union(enum) {
    account_already_exists,
    account_being_created,
    account_is_disabled,
    authentication_failed,
    authorization_failure,
    condition_headers_not_supported,
    condition_not_met,
    empty_metadata_key,
    incremental_copy_of_earlier_snapshot_not_allowed,
    insufficient_account_permissions,
    internal_error,
    invalid_authentication_info,
    invalid_header_value,
    invalid_http_verb,
    invalid_input,
    invalid_md5,
    invalid_metadata,
    invalid_query_parameter_value,
    invalid_range,
    invalid_request_url,
    invalid_resource_name,
    invalid_uri,
    invalid_xml_document,
    invalid_xml_node_value,
    md5mismatch,
    metadata_too_large,
    missing_content_length_header,
    missing_required_xml_node,
    missing_required_header,
    missing_required_query_parameter,
    multiple_condition_headers_not_supported,
    no_authentication_information,
    operation_timed_out,
    out_of_range_input,
    out_of_range_query_parameter_value,
    request_body_too_large,
    resource_type_mismatch,
    request_url_failed_to_parse,
    resource_already_exists,
    resource_not_found,
    server_busy,
    unsupported_header,
    unsupported_xml_node,
    unsupported_query_parameter,
    unsupported_http_verb,
    append_position_condition_not_met,
    blob_already_exists,
    blob_immutable_due_to_policy,
    blob_not_found,
    blob_overwritten,
    blob_tier_inadequate_for_content_length,
    blob_uses_customer_specified_encryption,
    block_count_exceeds_limit,
    block_list_too_long,
    cannot_change_to_lower_tier,
    cannot_verify_copy_source,
    container_already_exists,
    container_being_deleted,
    container_disabled,
    container_not_found,
    content_length_larger_than_tier_limit,
    copy_across_accounts_not_supported,
    copy_id_mismatch,
    feature_version_mismatch,
    incremental_copy_blob_mismatch,
    incremental_copy_of_earlier_version_snapshot_not_allowed,
    incremental_copy_source_must_be_snapshot,
    infinite_lease_duration_required,
    invalid_blob_or_block,
    invalid_blob_tier,
    invalid_blob_type,
    invalid_block_id,
    invalid_block_list,
    invalid_operation,
    invalid_page_range,
    invalid_source_blob_type,
    invalid_source_blob_url,
    invalid_version_for_page_blob_operation,
    lease_already_present,
    lease_already_broken,
    lease_id_mismatch_with_blob_operation,
    lease_id_mismatch_with_container_operation,
    lease_id_mismatch_with_lease_operation,
    lease_id_missing,
    lease_is_breaking_and_cannot_be_acquired,
    lease_is_breaking_and_cannot_be_changed,
    lease_is_broken_and_cannot_be_renewed,
    lease_lost,
    lease_not_present_with_blob_operation,
    lease_not_present_with_container_operation,
    lease_not_present_with_lease_operation,
    max_blob_size_condition_not_met,
    no_pending_copy_operation,
    operation_not_allowed_on_incremental_copy_blob,
    pending_copy_operation,
    previous_snapshot_not_found,
    previous_snapshot_operation_not_supported,
    previous_snapshot_cannot_be_newer,
    sequence_number_condition_not_met,
    sequence_number_increment_too_large,
    snapshot_count_exceeded,
    snapshot_operation_rate_exceeded,
    snapshots_present,
    source_condition_not_met,
    system_in_use,
    target_condition_not_met,
    unauthorized_blob_overwrite,
    blob_being_rehydrated,
    blob_archived,
    blob_not_archived,
    authorization_source_ip_mismatch,
    authorization_protocol_mismatch,
    authorization_permission_mismatch,
    authorization_service_mismatch,
    authorization_resource_type_mismatch,
    blob_access_tier_not_supported_for_account_type,
    unrecognized: []const u8,

    const wire_names = .{
        .account_already_exists = "AccountAlreadyExists",
        .account_being_created = "AccountBeingCreated",
        .account_is_disabled = "AccountIsDisabled",
        .authentication_failed = "AuthenticationFailed",
        .authorization_failure = "AuthorizationFailure",
        .condition_headers_not_supported = "ConditionHeadersNotSupported",
        .condition_not_met = "ConditionNotMet",
        .empty_metadata_key = "EmptyMetadataKey",
        .incremental_copy_of_earlier_snapshot_not_allowed = "IncrementalCopyOfEarlierSnapshotNotAllowed",
        .insufficient_account_permissions = "InsufficientAccountPermissions",
        .internal_error = "InternalError",
        .invalid_authentication_info = "InvalidAuthenticationInfo",
        .invalid_header_value = "InvalidHeaderValue",
        .invalid_http_verb = "InvalidHttpVerb",
        .invalid_input = "InvalidInput",
        .invalid_md5 = "InvalidMd5",
        .invalid_metadata = "InvalidMetadata",
        .invalid_query_parameter_value = "InvalidQueryParameterValue",
        .invalid_range = "InvalidRange",
        .invalid_request_url = "InvalidRequestUrl",
        .invalid_resource_name = "InvalidResourceName",
        .invalid_uri = "InvalidUri",
        .invalid_xml_document = "InvalidXmlDocument",
        .invalid_xml_node_value = "InvalidXmlNodeValue",
        .md5mismatch = "Md5Mismatch",
        .metadata_too_large = "MetadataTooLarge",
        .missing_content_length_header = "MissingContentLengthHeader",
        .missing_required_xml_node = "MissingRequiredXmlNode",
        .missing_required_header = "MissingRequiredHeader",
        .missing_required_query_parameter = "MissingRequiredQueryParameter",
        .multiple_condition_headers_not_supported = "MultipleConditionHeadersNotSupported",
        .no_authentication_information = "NoAuthenticationInformation",
        .operation_timed_out = "OperationTimedOut",
        .out_of_range_input = "OutOfRangeInput",
        .out_of_range_query_parameter_value = "OutOfRangeQueryParameterValue",
        .request_body_too_large = "RequestBodyTooLarge",
        .resource_type_mismatch = "ResourceTypeMismatch",
        .request_url_failed_to_parse = "RequestUrlFailedToParse",
        .resource_already_exists = "ResourceAlreadyExists",
        .resource_not_found = "ResourceNotFound",
        .server_busy = "ServerBusy",
        .unsupported_header = "UnsupportedHeader",
        .unsupported_xml_node = "UnsupportedXmlNode",
        .unsupported_query_parameter = "UnsupportedQueryParameter",
        .unsupported_http_verb = "UnsupportedHttpVerb",
        .append_position_condition_not_met = "AppendPositionConditionNotMet",
        .blob_already_exists = "BlobAlreadyExists",
        .blob_immutable_due_to_policy = "BlobImmutableDueToPolicy",
        .blob_not_found = "BlobNotFound",
        .blob_overwritten = "BlobOverwritten",
        .blob_tier_inadequate_for_content_length = "BlobTierInadequateForContentLength",
        .blob_uses_customer_specified_encryption = "BlobUsesCustomerSpecifiedEncryption",
        .block_count_exceeds_limit = "BlockCountExceedsLimit",
        .block_list_too_long = "BlockListTooLong",
        .cannot_change_to_lower_tier = "CannotChangeToLowerTier",
        .cannot_verify_copy_source = "CannotVerifyCopySource",
        .container_already_exists = "ContainerAlreadyExists",
        .container_being_deleted = "ContainerBeingDeleted",
        .container_disabled = "ContainerDisabled",
        .container_not_found = "ContainerNotFound",
        .content_length_larger_than_tier_limit = "ContentLengthLargerThanTierLimit",
        .copy_across_accounts_not_supported = "CopyAcrossAccountsNotSupported",
        .copy_id_mismatch = "CopyIdMismatch",
        .feature_version_mismatch = "FeatureVersionMismatch",
        .incremental_copy_blob_mismatch = "IncrementalCopyBlobMismatch",
        .incremental_copy_of_earlier_version_snapshot_not_allowed = "IncrementalCopyOfEarlierVersionSnapshotNotAllowed",
        .incremental_copy_source_must_be_snapshot = "IncrementalCopySourceMustBeSnapshot",
        .infinite_lease_duration_required = "InfiniteLeaseDurationRequired",
        .invalid_blob_or_block = "InvalidBlobOrBlock",
        .invalid_blob_tier = "InvalidBlobTier",
        .invalid_blob_type = "InvalidBlobType",
        .invalid_block_id = "InvalidBlockId",
        .invalid_block_list = "InvalidBlockList",
        .invalid_operation = "InvalidOperation",
        .invalid_page_range = "InvalidPageRange",
        .invalid_source_blob_type = "InvalidSourceBlobType",
        .invalid_source_blob_url = "InvalidSourceBlobUrl",
        .invalid_version_for_page_blob_operation = "InvalidVersionForPageBlobOperation",
        .lease_already_present = "LeaseAlreadyPresent",
        .lease_already_broken = "LeaseAlreadyBroken",
        .lease_id_mismatch_with_blob_operation = "LeaseIdMismatchWithBlobOperation",
        .lease_id_mismatch_with_container_operation = "LeaseIdMismatchWithContainerOperation",
        .lease_id_mismatch_with_lease_operation = "LeaseIdMismatchWithLeaseOperation",
        .lease_id_missing = "LeaseIdMissing",
        .lease_is_breaking_and_cannot_be_acquired = "LeaseIsBreakingAndCannotBeAcquired",
        .lease_is_breaking_and_cannot_be_changed = "LeaseIsBreakingAndCannotBeChanged",
        .lease_is_broken_and_cannot_be_renewed = "LeaseIsBrokenAndCannotBeRenewed",
        .lease_lost = "LeaseLost",
        .lease_not_present_with_blob_operation = "LeaseNotPresentWithBlobOperation",
        .lease_not_present_with_container_operation = "LeaseNotPresentWithContainerOperation",
        .lease_not_present_with_lease_operation = "LeaseNotPresentWithLeaseOperation",
        .max_blob_size_condition_not_met = "MaxBlobSizeConditionNotMet",
        .no_pending_copy_operation = "NoPendingCopyOperation",
        .operation_not_allowed_on_incremental_copy_blob = "OperationNotAllowedOnIncrementalCopyBlob",
        .pending_copy_operation = "PendingCopyOperation",
        .previous_snapshot_not_found = "PreviousSnapshotNotFound",
        .previous_snapshot_operation_not_supported = "PreviousSnapshotOperationNotSupported",
        .previous_snapshot_cannot_be_newer = "PreviousSnapshotCannotBeNewer",
        .sequence_number_condition_not_met = "SequenceNumberConditionNotMet",
        .sequence_number_increment_too_large = "SequenceNumberIncrementTooLarge",
        .snapshot_count_exceeded = "SnapshotCountExceeded",
        .snapshot_operation_rate_exceeded = "SnapshotOperationRateExceeded",
        .snapshots_present = "SnapshotsPresent",
        .source_condition_not_met = "SourceConditionNotMet",
        .system_in_use = "SystemInUse",
        .target_condition_not_met = "TargetConditionNotMet",
        .unauthorized_blob_overwrite = "UnauthorizedBlobOverwrite",
        .blob_being_rehydrated = "BlobBeingRehydrated",
        .blob_archived = "BlobArchived",
        .blob_not_archived = "BlobNotArchived",
        .authorization_source_ip_mismatch = "AuthorizationSourceIPMismatch",
        .authorization_protocol_mismatch = "AuthorizationProtocolMismatch",
        .authorization_permission_mismatch = "AuthorizationPermissionMismatch",
        .authorization_service_mismatch = "AuthorizationServiceMismatch",
        .authorization_resource_type_mismatch = "AuthorizationResourceTypeMismatch",
        .blob_access_tier_not_supported_for_account_type = "BlobAccessTierNotSupportedForAccountType",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The geo-replication status.
pub const GeoReplicationStatusType = union(enum) {
    live,
    bootstrap,
    unavailable,
    unrecognized: []const u8,

    const wire_names = .{
        .live = "live",
        .bootstrap = "bootstrap",
        .unavailable = "unavailable",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// Specifies what additional information should be returned as part of the list operation.
pub const ListContainersIncludeType = enum {
    metadata,
    deleted,
    system,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .metadata => "metadata",
            .deleted => "deleted",
            .system => "system",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "metadata")) return .metadata;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "system")) return .system;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The lease status.
pub const LeaseStatus = enum {
    unlocked,
    locked,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unlocked => "unlocked",
            .locked => "locked",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unlocked")) return .unlocked;
        if (std.mem.eql(u8, s, "locked")) return .locked;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The lease state.
pub const LeaseState = enum {
    available,
    leased,
    expired,
    breaking,
    broken,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .available => "available",
            .leased => "leased",
            .expired => "expired",
            .breaking => "breaking",
            .broken => "broken",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "available")) return .available;
        if (std.mem.eql(u8, s, "leased")) return .leased;
        if (std.mem.eql(u8, s, "expired")) return .expired;
        if (std.mem.eql(u8, s, "breaking")) return .breaking;
        if (std.mem.eql(u8, s, "broken")) return .broken;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The lease duration.
pub const LeaseDuration = enum {
    infinite,
    fixed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .infinite => "infinite",
            .fixed => "fixed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "infinite")) return .infinite;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The public access type.
pub const PublicAccessType = union(enum) {
    blob,
    container,
    unrecognized: []const u8,

    const wire_names = .{
        .blob = "blob",
        .container = "container",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The account SKU.
pub const SkuName = enum {
    standard_lrs,
    standard_grs,
    standard_ragrs,
    standard_zrs,
    premium_lrs,
    standard_gzrs,
    premium_zrs,
    standard_ragzrs,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .standard_lrs => "Standard_LRS",
            .standard_grs => "Standard_GRS",
            .standard_ragrs => "Standard_RAGRS",
            .standard_zrs => "Standard_ZRS",
            .premium_lrs => "Premium_LRS",
            .standard_gzrs => "Standard_GZRS",
            .premium_zrs => "Premium_ZRS",
            .standard_ragzrs => "Standard_RAGZRS",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "Standard_LRS")) return .standard_lrs;
        if (std.mem.eql(u8, s, "Standard_GRS")) return .standard_grs;
        if (std.mem.eql(u8, s, "Standard_RAGRS")) return .standard_ragrs;
        if (std.mem.eql(u8, s, "Standard_ZRS")) return .standard_zrs;
        if (std.mem.eql(u8, s, "Premium_LRS")) return .premium_lrs;
        if (std.mem.eql(u8, s, "Standard_GZRS")) return .standard_gzrs;
        if (std.mem.eql(u8, s, "Premium_ZRS")) return .premium_zrs;
        if (std.mem.eql(u8, s, "Standard_RAGZRS")) return .standard_ragzrs;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The account kind.
pub const AccountKind = enum {
    storage,
    blob_storage,
    storage_v2,
    file_storage,
    block_blob_storage,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .storage => "Storage",
            .blob_storage => "BlobStorage",
            .storage_v2 => "StorageV2",
            .file_storage => "FileStorage",
            .block_blob_storage => "BlockBlobStorage",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "Storage")) return .storage;
        if (std.mem.eql(u8, s, "BlobStorage")) return .blob_storage;
        if (std.mem.eql(u8, s, "StorageV2")) return .storage_v2;
        if (std.mem.eql(u8, s, "FileStorage")) return .file_storage;
        if (std.mem.eql(u8, s, "BlockBlobStorage")) return .block_blob_storage;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// Specifies what type of blobs should be returned as part of the filter operation.
pub const FilterBlobsIncludeItem = enum {
    none,
    versions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .versions => "versions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "versions")) return .versions;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// Specifies additional datasets to include when listing blobs in a container.
pub const ListBlobsIncludeItem = enum {
    copy,
    deleted,
    metadata,
    snapshots,
    uncommitted_blobs,
    versions,
    tags,
    immutability_policy,
    legal_hold,
    deleted_with_versions,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .copy => "copy",
            .deleted => "deleted",
            .metadata => "metadata",
            .snapshots => "snapshots",
            .uncommitted_blobs => "uncommittedblobs",
            .versions => "versions",
            .tags => "tags",
            .immutability_policy => "immutabilitypolicy",
            .legal_hold => "legalhold",
            .deleted_with_versions => "deletedwithversions",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "copy")) return .copy;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "metadata")) return .metadata;
        if (std.mem.eql(u8, s, "snapshots")) return .snapshots;
        if (std.mem.eql(u8, s, "uncommittedblobs")) return .uncommitted_blobs;
        if (std.mem.eql(u8, s, "versions")) return .versions;
        if (std.mem.eql(u8, s, "tags")) return .tags;
        if (std.mem.eql(u8, s, "immutabilitypolicy")) return .immutability_policy;
        if (std.mem.eql(u8, s, "legalhold")) return .legal_hold;
        if (std.mem.eql(u8, s, "deletedwithversions")) return .deleted_with_versions;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The blob type.
pub const BlobType = enum {
    block_blob,
    page_blob,
    append_blob,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .block_blob => "BlockBlob",
            .page_blob => "PageBlob",
            .append_blob => "AppendBlob",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "BlockBlob")) return .block_blob;
        if (std.mem.eql(u8, s, "PageBlob")) return .page_blob;
        if (std.mem.eql(u8, s, "AppendBlob")) return .append_blob;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The copy status.
pub const CopyStatus = enum {
    pending,
    success,
    failed,
    aborted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .success => "success",
            .failed => "failed",
            .aborted => "aborted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "success")) return .success;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "aborted")) return .aborted;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The access tiers.
pub const AccessTier = union(enum) {
    p4,
    p6,
    p10,
    p15,
    p20,
    p30,
    p40,
    p50,
    p60,
    p70,
    p80,
    hot,
    cool,
    archive,
    premium,
    cold,
    smart,
    unrecognized: []const u8,

    const wire_names = .{
        .p4 = "P4",
        .p6 = "P6",
        .p10 = "P10",
        .p15 = "P15",
        .p20 = "P20",
        .p30 = "P30",
        .p40 = "P40",
        .p50 = "P50",
        .p60 = "P60",
        .p70 = "P70",
        .p80 = "P80",
        .hot = "Hot",
        .cool = "Cool",
        .archive = "Archive",
        .premium = "Premium",
        .cold = "Cold",
        .smart = "Smart",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The archive status.
pub const ArchiveStatus = union(enum) {
    rehydrate_pending_to_hot,
    rehydrate_pending_to_cool,
    rehydrate_pending_to_cold,
    rehydrate_pending_to_smart,
    unrecognized: []const u8,

    const wire_names = .{
        .rehydrate_pending_to_hot = "rehydrate-pending-to-hot",
        .rehydrate_pending_to_cool = "rehydrate-pending-to-cool",
        .rehydrate_pending_to_cold = "rehydrate-pending-to-cold",
        .rehydrate_pending_to_smart = "rehydrate-pending-to-smart",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The priority of the rehydrate operation.
pub const RehydratePriority = union(enum) {
    high,
    standard,
    unrecognized: []const u8,

    const wire_names = .{
        .high = "High",
        .standard = "Standard",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The immutability policy mode.
pub const ImmutabilityPolicyMode = enum {
    mutable,
    locked,
    unlocked,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .mutable => "mutable",
            .locked => "locked",
            .unlocked => "unlocked",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "mutable")) return .mutable;
        if (std.mem.eql(u8, s, "locked")) return .locked;
        if (std.mem.eql(u8, s, "unlocked")) return .unlocked;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The algorithm used to produce the encryption key hash.
pub const EncryptionAlgorithmType = enum {
    aes256,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .aes256 => "AES256",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "AES256")) return .aes256;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// Specifies the delete behavior of blob snapshots.
pub const DeleteSnapshotsOptionType = enum {
    only,
    include,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .only => "only",
            .include => "include",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "only")) return .only;
        if (std.mem.eql(u8, s, "include")) return .include;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The type of blob deletions.
pub const BlobDeleteType = enum {
    permanent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .permanent => "Permanent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "Permanent")) return .permanent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The blob expiry options.
pub const BlobExpiryOptions = union(enum) {
    never_expire,
    relative_to_creation,
    relative_to_now,
    absolute,
    unrecognized: []const u8,

    const wire_names = .{
        .never_expire = "NeverExpire",
        .relative_to_creation = "RelativeToCreation",
        .relative_to_now = "RelativeToNow",
        .absolute = "Absolute",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The blob copy source tags types.
pub const BlobCopySourceTags = enum {
    replace,
    copy,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .replace => "REPLACE",
            .copy => "COPY",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "REPLACE")) return .replace;
        if (std.mem.eql(u8, s, "COPY")) return .copy;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The file share token intent types.
pub const FileShareTokenIntent = union(enum) {
    backup,
    unrecognized: []const u8,

    const wire_names = .{
        .backup = "backup",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The block list types.
pub const BlockListType = enum {
    committed,
    uncommitted,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .committed => "committed",
            .uncommitted => "uncommitted",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "committed")) return .committed;
        if (std.mem.eql(u8, s, "uncommitted")) return .uncommitted;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The query request type.
pub const QueryRequestType = enum {
    sql,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .sql => "SQL",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "SQL")) return .sql;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The query format type.
pub const QueryType = enum {
    delimited,
    json,
    arrow,
    parquet,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .delimited => "delimited",
            .json => "json",
            .arrow => "arrow",
            .parquet => "parquet",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "delimited")) return .delimited;
        if (std.mem.eql(u8, s, "json")) return .json;
        if (std.mem.eql(u8, s, "arrow")) return .arrow;
        if (std.mem.eql(u8, s, "parquet")) return .parquet;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The premium page blob access tier types.
pub const PremiumPageBlobAccessTier = union(enum) {
    p4,
    p6,
    p10,
    p15,
    p20,
    p30,
    p40,
    p50,
    p60,
    p70,
    p80,
    unrecognized: []const u8,

    const wire_names = .{
        .p4 = "P4",
        .p6 = "P6",
        .p10 = "P10",
        .p15 = "P15",
        .p20 = "P20",
        .p30 = "P30",
        .p40 = "P40",
        .p50 = "P50",
        .p60 = "P60",
        .p70 = "P70",
        .p80 = "P80",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

/// The sequence number actions.
pub const SequenceNumberActionType = enum {
    increment,
    max,
    update,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .increment => "increment",
            .max => "max",
            .update => "update",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "increment")) return .increment;
        if (std.mem.eql(u8, s, "max")) return .max;
        if (std.mem.eql(u8, s, "update")) return .update;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

/// The Azure.Storage.Blob service versions.
pub const Versions = enum {
    v2025_11_05,
    v2026_02_06,
    v2026_04_06,
    v2026_06_06,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .v2025_11_05 => "2025-11-05",
            .v2026_02_06 => "2026-02-06",
            .v2026_04_06 => "2026-04-06",
            .v2026_06_06 => "2026-06-06",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "2025-11-05")) return .v2025_11_05;
        if (std.mem.eql(u8, s, "2026-02-06")) return .v2026_02_06;
        if (std.mem.eql(u8, s, "2026-04-06")) return .v2026_04_06;
        if (std.mem.eql(u8, s, "2026-06-06")) return .v2026_06_06;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};
