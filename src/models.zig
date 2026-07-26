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

/// The properties for the table query response.
pub const TableQueryResponse = struct {
    /// The metadata response of the table.
    odata_metadata: ?[]const u8 = null,
    /// The requested list of tables.
    value: ?[]const TableProperties = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .odata_metadata = "odata.metadata",
        },
    };
};

/// The properties for the table response.
pub const TableProperties = struct {
    /// The name of the table.
    table_name: ?[]const u8 = null,
    /// The odata type of the table.
    odata_type: ?[]const u8 = null,
    /// The id of the table.
    odata_id: ?[]const u8 = null,
    /// The edit link of the table.
    odata_edit_link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .table_name = "TableName",
            .odata_type = "odata.type",
            .odata_id = "odata.id",
            .odata_edit_link = "odata.editLink",
        },
    };
};

/// Table JSON error.
pub const TablesError = struct {
    /// Content-Type header
    content_type: []const u8,
    /// The error code.
    error_code: ?[]const u8 = null,
    /// The error message.
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .message = "Message",
        },
    };
};

/// The table properties as returned in an echo response.
pub const TableResponse = struct {
    /// The name of the table.
    table_name: ?[]const u8 = null,
    /// The odata type of the table.
    odata_type: ?[]const u8 = null,
    /// The id of the table.
    odata_id: ?[]const u8 = null,
    /// The edit link of the table.
    odata_edit_link: ?[]const u8 = null,
    /// The metadata response of the table.
    odata_metadata: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .table_name = "TableName",
            .odata_type = "odata.type",
            .odata_id = "odata.id",
            .odata_edit_link = "odata.editLink",
            .odata_metadata = "odata.metadata",
        },
    };
};

/// The properties for the table entity query response.
pub const TableEntityQueryResponse = struct {
    /// The metadata response of the table.
    odata_metadata: ?[]const u8 = null,
    /// List of table entities.
    value: ?[]const std.json.ArrayHashMap(JsonValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .odata_metadata = "odata.metadata",
        },
    };
};

/// Table signed identifiers.
pub const SignedIdentifiers = struct {
    /// An array of signed identifiers
    identifiers: []const SignedIdentifier,

    pub const serde = .{
        .xml_root = "SignedIdentifiers",
        .rename = .{
            .identifiers = "SignedIdentifier",
        },
    };
};

/// The signed identifier.
pub const SignedIdentifier = struct {
    /// The unique ID for the signed identifier.
    id: []const u8,
    /// The access policy for the signed identifier.
    access_policy: AccessPolicy,

    pub const serde = .{
        .xml_root = "SignedIdentifier",
        .rename = .{
            .id = "Id",
            .access_policy = "AccessPolicy",
        },
    };
};

/// An access policy.
pub const AccessPolicy = struct {
    /// The date-time the policy is active.
    start: []const u8,
    /// The date-time the policy expires.
    expiry: []const u8,
    /// The permissions for acl the policy.
    permission: []const u8,

    pub const serde = .{
        .xml_root = "AccessPolicy",
        .rename = .{
            .start = "Start",
            .expiry = "Expiry",
            .permission = "Permission",
        },
    };
};

/// The Tables service XML error.
pub const TablesServiceError = struct {
    /// The error code.
    error_code: ?[]const u8 = null,
    /// The error code.
    code: ?[]const u8 = null,
    /// The error message.
    message: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "TablesServiceError",
        .rename = .{
            .error_code = "errorCode",
            .code = "Code",
            .message = "Message",
        },
    };
};

/// The service properties.
pub const TableServiceProperties = struct {
    /// The logging properties.
    logging: ?Logging = null,
    /// The hour metrics properties.
    hour_metrics: ?Metrics = null,
    /// The minute metrics properties.
    minute_metrics: ?Metrics = null,
    /// The CORS properties.
    cors: ?CorsXml = null,
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
        },
    };
};

/// Azure Analytics Logging settings.
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
    /// Whether to enable the retention policy.
    enabled: bool,
    /// Indicates the number of days that metrics or logging or soft-deleted data
    /// should be retained. All data older than this value will be deleted.
    days: ?i32 = null,

    pub const serde = .{
        .xml_root = "RetentionPolicy",
        .rename = .{
            .enabled = "Enabled",
            .days = "Days",
        },
    };
};

/// The metrics properties.
pub const Metrics = struct {
    /// The version of the metrics properties.
    version: ?[]const u8 = null,
    /// Indicates whether metrics are enabled for the Table service.
    enabled: bool,
    /// Indicates whether metrics should generate summary statistics for called API
    /// operations.
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

/// CORS is an HTTP feature that enables a web application running under one domain to access resources in another domain. Web browsers implement a security restriction known as same-origin policy that prevents a web page from calling APIs in a different domain; CORS provides a secure way to allow one domain (the origin domain) to call APIs in another domain
pub const CorsRule = struct {
    /// The origin domains that are permitted to make a request against the service via
    /// CORS. The origin domain is the domain from which the request originates. Note
    /// that the origin must be an exact case-sensitive match with the origin that the
    /// user age sends to the service. You can also use the wildcard character '*' to
    /// allow all origin domains to make requests via CORS.
    allowed_origins: []const u8,
    /// The methods (HTTP request verbs) that the origin domain may use for a CORS
    /// request.
    allowed_methods: []const u8,
    /// The request headers that the origin domain may specify on the CORS request.
    allowed_headers: []const u8,
    /// The response headers that may be sent in the response to the CORS request and
    /// exposed by the browser to the request issuer.
    exposed_headers: []const u8,
    /// The maximum amount time that a browser should cache the preflight OPTIONS
    /// request.
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

/// Stats for the table service.
pub const TableServiceStats = struct {
    /// Geo-Replication information for the Secondary Storage Service.
    geo_replication: ?GeoReplication = null,

    pub const serde = .{
        .xml_root = "StorageServiceStats",
        .rename = .{
            .geo_replication = "GeoReplication",
        },
    };
};

/// Geo-Replication information for the Secondary Storage Service
pub const GeoReplication = struct {
    /// The status of the secondary location
    status: ?enums.GeoReplicationStatusType = null,
    /// A GMT date/time value, to the second. All primary writes preceding this value are guaranteed to be available for read operations at the secondary. Primary writes after this point in time may or may not be available for reads.
    last_sync_time: ?[]const u8 = null,

    pub const serde = .{
        .xml_root = "GeoReplication",
        .rename = .{
            .status = "Status",
            .last_sync_time = "LastSyncTime",
        },
    };
};
