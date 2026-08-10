//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Symbol request.
pub const Request = struct {
    /// The ID of user who created this item. Optional.
    created_by: ?[]const u8 = null,
    /// The date time when this item is created. Optional.
    created_date: ?[]const u8 = null,
    /// An identifier for this item. Optional.
    id: ?[]const u8 = null,
    /// An opaque ETag used to synchronize with the version stored at server end. Optional.
    storage_e_tag: ?[]const u8 = null,
    /// A URI which can be used to retrieve this item in its raw format. Optional. Note this is distinguished from other URIs that are present in a derived resource.
    url: ?[]const u8 = null,
    /// An optional human-facing description.
    description: ?[]const u8 = null,
    domain_id: ?IDomainId = null,
    /// An optional expiration date for the request. The request will become inaccessible and get deleted after the date, regardless of its status. On an HTTP POST, if expiration date is null/missing, the server will assign a default expiration data (30 days unless overwridden in the registry at the account level). On PATCH, if expiration date is null/missing, the behavior is to not change whatever the request's current expiration date is.
    expiration_date: ?[]const u8 = null,
    /// Indicates if request should be chunk dedup
    is_chunked: ?bool = null,
    /// Date of the last change to the symbol request.
    key: ?[]const u8 = null,
    /// Date of the last change to the symbol request.
    last_operation_date: ?[]const u8 = null,
    /// Last Operation to symbol request.
    last_operation_name: ?[]const u8 = null,
    /// A human-facing name for the request. Required on POST, ignored on PATCH.
    name: ?[]const u8 = null,
    /// The total Size for this request.
    size: ?i64 = null,
    /// The status for this request.
    status: ?enums.RequestStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IDomainId = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of debug entry to create.
pub const DebugEntryCreateBatch = struct {
    /// Defines what to do when a debug entry in the batch already exists.
    create_behavior: ?enums.DebugEntryCreateBatchCreateBehavior = null,
    /// The debug entries.
    debug_entries: ?[]const DebugEntry = null,
    /// Serialized Proof nodes, used to verify uploads on server side for Chunk Dedup DebugEntry
    proof_nodes: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A dual-purpose data object, the debug entry is used by the client to publish the symbol file (with file's blob identifier, which can be calculated from VSTS hashing algorithm) or query the file (with a client key). Since the symbol server tries to return a matched symbol file with the richest information level, it may not always point to the same symbol file for different queries with same client key.
pub const DebugEntry = struct {
    /// The ID of user who created this item. Optional.
    created_by: ?[]const u8 = null,
    /// The date time when this item is created. Optional.
    created_date: ?[]const u8 = null,
    /// An identifier for this item. Optional.
    id: ?[]const u8 = null,
    /// An opaque ETag used to synchronize with the version stored at server end. Optional.
    storage_e_tag: ?[]const u8 = null,
    /// A URI which can be used to retrieve this item in its raw format. Optional. Note this is distinguished from other URIs that are present in a derived resource.
    url: ?[]const u8 = null,
    blob_details: ?JsonBlobIdentifierWithBlocks = null,
    blob_identifier: ?JsonBlobIdentifier = null,
    /// The URI to get the symbol file. Provided by the server, the URI contains authentication information and is readily accessible by plain HTTP GET request. The client is recommended to retrieve the file as soon as it can since the URI will expire in a short period.
    blob_uri: ?[]const u8 = null,
    /// A key the client (debugger, for example) uses to find the debug entry. Note it is not unique for each different symbol file as it does not distinguish between those which only differ by information level.
    client_key: ?[]const u8 = null,
    domain_id: ?IDomainId = null,
    /// The information level this debug entry contains.
    information_level: ?enums.DebugEntryInformationLevel = null,
    /// The identifier of symbol request to which this debug entry belongs.
    request_id: ?[]const u8 = null,
    /// The size for the debug entry.
    size: ?i64 = null,
    /// The status of debug entry.
    status: ?enums.DebugEntryStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// BlobIdentifier with block hashes formatted to be deserialzied for symbol service.
pub const JsonBlobIdentifierWithBlocks = struct {
    /// List of blob block hashes.
    block_hashes: ?[]const JsonBlobBlockHash = null,
    /// Array of blobId bytes.
    identifier_value: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// BlobBlock hash formatted to be deserialized for symbol service.
pub const JsonBlobBlockHash = struct {
    /// Array of hash bytes.
    hash_bytes: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const JsonBlobIdentifier = struct {
    identifier_value: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `DebugEntry` as returned by Azure DevOps.
pub const DebugEntryList = struct {
    count: ?i32 = null,
    value: ?[]const DebugEntry = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
