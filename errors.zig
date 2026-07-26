//! Azure Tables error codes and OData/XML service error parsing.

const std = @import("std");
const protocol = @import("azure_rest_data_tables");

/// Documented Azure Tables service error codes.
///
/// `TableError.code` deliberately remains a string so new service codes do
/// not turn a valid service response into a local parse failure.
pub const TableErrorCode = struct {
    pub const unknown = "Unknown";
    pub const account_is_disabled = "AccountIsDisabled";
    pub const account_not_found = "AccountNotFound";
    pub const authentication_failed = "AuthenticationFailed";
    pub const authorization_failure = "AuthorizationFailure";
    pub const authorization_permission_mismatch = "AuthorizationPermissionMismatch";
    pub const condition_not_met = "ConditionNotMet";
    pub const duplicate_properties_specified = "DuplicatePropertiesSpecified";
    pub const entity_already_exists = "EntityAlreadyExists";
    pub const entity_not_found = "EntityNotFound";
    pub const entity_too_large = "EntityTooLarge";
    pub const host_information_not_present = "HostInformationNotPresent";
    pub const internal_error = "InternalError";
    pub const invalid_duplicate_row = "InvalidDuplicateRow";
    pub const invalid_header_value = "InvalidHeaderValue";
    pub const invalid_http_verb = "InvalidHttpVerb";
    pub const invalid_input = "InvalidInput";
    pub const invalid_query_parameter_value = "InvalidQueryParameterValue";
    pub const invalid_resource_name = "InvalidResourceName";
    pub const invalid_uri = "InvalidUri";
    pub const invalid_value_type = "InvalidValueType";
    pub const invalid_xml_document = "InvalidXmlDocument";
    pub const json_format_not_supported = "JsonFormatNotSupported";
    pub const method_not_allowed = "MethodNotAllowed";
    pub const missing_required_header = "MissingRequiredHeader";
    pub const not_implemented = "NotImplemented";
    pub const operation_timed_out = "OperationTimedOut";
    pub const out_of_range_input = "OutOfRangeInput";
    pub const out_of_range_query_parameter_value = "OutOfRangeQueryParameterValue";
    pub const property_value_too_large = "PropertyValueTooLarge";
    pub const properties_need_value = "PropertiesNeedValue";
    pub const property_name_invalid = "PropertyNameInvalid";
    pub const property_name_too_long = "PropertyNameTooLong";
    pub const request_body_too_large = "RequestBodyTooLarge";
    pub const request_timeout = "RequestTimeout";
    pub const resource_already_exists = "ResourceAlreadyExists";
    pub const resource_not_found = "ResourceNotFound";
    pub const resource_type_mismatch = "ResourceTypeMismatch";
    pub const server_busy = "ServerBusy";
    pub const table_already_exists = "TableAlreadyExists";
    pub const table_being_deleted = "TableBeingDeleted";
    pub const table_not_found = "TableNotFound";
    pub const too_many_properties = "TooManyProperties";
    pub const unsupported_header = "UnsupportedHeader";
    pub const unsupported_http_verb = "UnsupportedHttpVerb";
    pub const update_condition_not_satisfied = "UpdateConditionNotSatisfied";
    pub const x_method_incorrect_count = "XMethodIncorrectCount";
};

/// An owned Azure Tables HTTP failure.
///
/// Values returned by the parsing and generated-model adapters own their
/// strings and must be released with `deinit`. This is distinct from local
/// errors such as allocation failure or a malformed response body.
pub const TableError = struct {
    status: u16,
    code: []const u8,
    message: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    operation_index: ?usize = null,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        status: u16,
        code: ?[]const u8,
        message: ?[]const u8,
        request_id: ?[]const u8,
        operation_index: ?usize,
    ) !TableError {
        const owned_code = try allocator.dupe(u8, code orelse TableErrorCode.unknown);
        errdefer allocator.free(owned_code);
        const owned_message = if (message) |value| try allocator.dupe(u8, value) else null;
        errdefer if (owned_message) |value| allocator.free(value);
        const owned_request_id = if (request_id) |value| try allocator.dupe(u8, value) else null;

        return .{
            .status = status,
            .code = owned_code,
            .message = owned_message,
            .request_id = owned_request_id,
            .operation_index = operation_index,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TableError) void {
        self.allocator.free(self.code);
        if (self.message) |value| self.allocator.free(value);
        if (self.request_id) |value| self.allocator.free(value);
        self.* = undefined;
    }

    /// Converts the generated OData JSON error model into the SDK error.
    pub fn fromGeneratedJson(
        allocator: std.mem.Allocator,
        status: u16,
        request_id: ?[]const u8,
        operation_index: ?usize,
        source: protocol.models.TablesError,
    ) !TableError {
        return init(allocator, status, source.error_code, source.message, request_id, operation_index);
    }

    /// Converts the generated XML error model into the SDK error.
    pub fn fromGeneratedXml(
        allocator: std.mem.Allocator,
        status: u16,
        request_id: ?[]const u8,
        operation_index: ?usize,
        source: protocol.models.TablesServiceError,
    ) !TableError {
        return init(
            allocator,
            status,
            source.error_code orelse source.code,
            source.message,
            request_id,
            operation_index,
        );
    }

    /// Parses a JSON/OData service error. JSON syntax and allocation errors
    /// are intentionally returned to the caller as local failures.
    pub fn fromJson(
        allocator: std.mem.Allocator,
        status: u16,
        request_id: ?[]const u8,
        operation_index: ?usize,
        body: []const u8,
    ) !TableError {
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{
            .allocate = .alloc_always,
        });
        defer parsed.deinit();

        const root = switch (parsed.value) {
            .object => |object| object,
            else => return error.InvalidErrorPayload,
        };
        const error_object = jsonObject(root.get("odata.error") orelse root.get("error")) orelse root;
        const code = jsonString(error_object.get("code") orelse error_object.get("errorCode"));
        const message_value = error_object.get("message") orelse error_object.get("Message");
        const normalized_message = try jsonMessage(message_value);

        return init(allocator, status, code, normalized_message, request_id, operation_index);
    }

    /// Parses the generated Tables XML service error envelope.
    pub fn fromXml(
        allocator: std.mem.Allocator,
        status: u16,
        request_id: ?[]const u8,
        operation_index: ?usize,
        body: []const u8,
    ) !TableError {
        if (!isXmlErrorEnvelope(body)) return error.InvalidErrorPayload;
        const code = try xmlElement(body, "Code");
        const message = try xmlElement(body, "Message");
        return init(allocator, status, code, message, request_id, operation_index);
    }

    /// Selects a service-error parser based on content type. Unknown content
    /// types remain structured HTTP failures without attempting lossy parsing.
    pub fn fromResponse(
        allocator: std.mem.Allocator,
        status: u16,
        content_type: ?[]const u8,
        request_id: ?[]const u8,
        operation_index: ?usize,
        body: []const u8,
    ) !TableError {
        if (status >= 200 and status < 300) return error.ExpectedFailureStatus;
        const value = content_type orelse return init(allocator, status, null, null, request_id, operation_index);
        if (containsIgnoreCase(value, "json")) {
            return fromJson(allocator, status, request_id, operation_index, body);
        }
        if (containsIgnoreCase(value, "xml")) {
            return fromXml(allocator, status, request_id, operation_index, body);
        }
        return init(allocator, status, null, null, request_id, operation_index);
    }

    /// Formats only redacted diagnostic data. URLs have their complete query
    /// strings removed, and Authorization values are never written.
    pub fn format(self: TableError, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("TableError(status={d}, code=", .{self.status});
        try writeRedacted(writer, self.code);
        if (self.message) |message| {
            try writer.writeAll(", message=");
            try writeRedacted(writer, message);
        }
        if (self.request_id) |request_id| {
            try writer.writeAll(", request_id=");
            try writeRedacted(writer, request_id);
        }
        if (self.operation_index) |index| try writer.print(", operation_index={d}", .{index});
        try writer.writeByte(')');
    }
};

fn jsonObject(value: ?std.json.Value) ?std.json.ObjectMap {
    if (value) |item| switch (item) {
        .object => |object| return object,
        else => {},
    };
    return null;
}

fn jsonString(value: ?std.json.Value) ?[]const u8 {
    if (value) |item| switch (item) {
        .string => |string| return string,
        else => {},
    };
    return null;
}

fn jsonMessage(value: ?std.json.Value) !?[]const u8 {
    const item = value orelse return null;
    if (jsonString(item)) |message| return message;
    const object = jsonObject(item) orelse return error.InvalidErrorPayload;
    return jsonString(object.get("value") orelse object.get("Value")) orelse error.InvalidErrorPayload;
}

fn isXmlErrorEnvelope(body: []const u8) bool {
    const opening = std.mem.indexOf(u8, body, "<Error") orelse return false;
    const opening_end = std.mem.indexOfPos(u8, body, opening, ">") orelse return false;
    return opening_end > opening and std.mem.indexOfPos(u8, body, opening_end, "</Error>") != null;
}

fn xmlElement(body: []const u8, comptime name: []const u8) !?[]const u8 {
    const opening = "<" ++ name ++ ">";
    const closing = "</" ++ name ++ ">";
    const start = std.mem.indexOf(u8, body, opening) orelse return null;
    const value_start = start + opening.len;
    const end = std.mem.indexOfPos(u8, body, value_start, closing) orelse return error.InvalidErrorPayload;
    const value = body[value_start..end];
    if (std.mem.indexOfScalar(u8, value, '<') != null) return error.InvalidErrorPayload;
    return value;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn writeRedacted(writer: *std.Io.Writer, value: []const u8) std.Io.Writer.Error!void {
    var index: usize = 0;
    while (index < value.len) {
        if (value[index] == '?') {
            try writer.writeAll("?[REDACTED]");
            while (index < value.len and !std.ascii.isWhitespace(value[index]) and value[index] != '"' and value[index] != '\'') : (index += 1) {}
            continue;
        }
        if (index + "Authorization".len <= value.len and
            std.ascii.eqlIgnoreCase(value[index .. index + "Authorization".len], "Authorization"))
        {
            try writer.writeAll("Authorization=[REDACTED]");
            index += "Authorization".len;
            while (index < value.len and (value[index] == ':' or value[index] == '=' or std.ascii.isWhitespace(value[index]))) : (index += 1) {}
            while (index < value.len and value[index] != ',' and value[index] != ';' and value[index] != '\n') : (index += 1) {}
            continue;
        }
        try writer.writeByte(value[index]);
        index += 1;
    }
}

test "JSON OData error retains unknown code and request metadata" {
    var table_error = try TableError.fromJson(std.testing.allocator, 409, "request-id", 3,
        \\{"odata.error":{"code":"FutureTableCode","message":{"lang":"en-US","value":"new service failure"}}}
    );
    defer table_error.deinit();

    try std.testing.expectEqual(@as(u16, 409), table_error.status);
    try std.testing.expectEqualStrings("FutureTableCode", table_error.code);
    try std.testing.expectEqualStrings("new service failure", table_error.message.?);
    try std.testing.expectEqualStrings("request-id", table_error.request_id.?);
    try std.testing.expectEqual(@as(?usize, 3), table_error.operation_index);
}

test "XML error retains generated service shape" {
    var table_error = try TableError.fromXml(
        std.testing.allocator,
        404,
        "request-id",
        null,
        "<Error><Code>TableNotFound</Code><Message>table does not exist</Message></Error>",
    );
    defer table_error.deinit();

    try std.testing.expectEqualStrings(TableErrorCode.table_not_found, table_error.code);
    try std.testing.expectEqualStrings("table does not exist", table_error.message.?);
}

test "generated JSON and XML adapters retain fields" {
    var json_error = try TableError.fromGeneratedJson(std.testing.allocator, 400, "json-id", null, .{
        .content_type = "application/json",
        .error_code = "InvalidInput",
        .message = "bad input",
    });
    defer json_error.deinit();
    try std.testing.expectEqualStrings("InvalidInput", json_error.code);

    var xml_error = try TableError.fromGeneratedXml(std.testing.allocator, 500, "xml-id", 1, .{
        .error_code = null,
        .code = "InternalError",
        .message = "server failed",
    });
    defer xml_error.deinit();
    try std.testing.expectEqualStrings(TableErrorCode.internal_error, xml_error.code);
    try std.testing.expectEqual(@as(?usize, 1), xml_error.operation_index);
}

test "non-2xx responses are always failures" {
    var table_error = try TableError.fromResponse(std.testing.allocator, 503, "application/json", null, null,
        \\{"code":"ServerBusy","message":"try again"}
    );
    defer table_error.deinit();
    try std.testing.expectEqualStrings(TableErrorCode.server_busy, table_error.code);
    try std.testing.expectError(
        error.ExpectedFailureStatus,
        TableError.fromResponse(std.testing.allocator, 200, "application/json", null, null, "{}"),
    );
}

test "malformed error payloads return local errors" {
    try std.testing.expectError(
        error.UnexpectedEndOfInput,
        TableError.fromJson(std.testing.allocator, 400, null, null, "{"),
    );
    try std.testing.expectError(
        error.InvalidErrorPayload,
        TableError.fromXml(std.testing.allocator, 400, null, null, "<Error><Code>Bad</Code>"),
    );
}

test "unknown error payload remains a safe structured failure" {
    var table_error = try TableError.fromResponse(
        std.testing.allocator,
        502,
        "text/plain",
        "request-id",
        null,
        "upstream response was not a Tables envelope",
    );
    defer table_error.deinit();
    try std.testing.expectEqualStrings(TableErrorCode.unknown, table_error.code);
    try std.testing.expect(table_error.message == null);
}

test "formatted errors redact authorization and complete query strings" {
    var table_error = try TableError.init(
        std.testing.allocator,
        403,
        "Authorization: Bearer secret",
        "https://example.table.core.windows.net/Tables?sv=2024-01-01&sig=secret&sp=r",
        null,
        null,
    );
    defer table_error.deinit();

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try output.writer.print("{}", .{table_error});
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "sv=") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "sig=") == null);
}
