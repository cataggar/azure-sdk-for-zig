const core = @import("azure_sdk_core");
const protocol = @import("azure_rest_data_tables");

pub const latest_api_version = "2019-02-02";
pub const MetadataFormat = protocol.enums.OdataMetadataFormat;

/// SDK settings shared by generated protocol calls.
pub const ProtocolOptions = struct {
    metadata: ?MetadataFormat = null,
    client_request_id: ?[]const u8 = null,
    /// Server-side timeout, in seconds.
    timeout: ?i32 = null,
    /// End-to-end client budget. A blocking in-flight send may exceed it.
    operation_timeout_ms: ?u64 = null,
    /// Per-call policies run before the client's configured pipeline.
    policies: []const *core.pipeline.HttpPolicy = &.{},
};

pub const QueryEntitiesOptions = struct {
    protocol: ProtocolOptions = .{},
    top: ?i32 = null,
    select: ?[]const u8 = null,
    filter: ?[]const u8 = null,
    next_partition_key: ?[]const u8 = null,
    next_row_key: ?[]const u8 = null,
};

pub const QueryEntityOptions = struct {
    protocol: ProtocolOptions = .{},
    select: ?[]const u8 = null,
    filter: ?[]const u8 = null,
};

/// Options accepted by the compatibility `TableClient.init` constructor.
pub const TableClientOptions = struct {
    api_version: []const u8 = latest_api_version,
};
