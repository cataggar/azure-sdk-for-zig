//! Compile-time typed entity validation and OData JSON serialization.

const std = @import("std");
const serde = @import("serde");
const edm = @import("edm.zig");
const entity = @import("entity.zig");
const request = @import("request.zig");

pub const EdmValue = entity.EdmValue;
pub const DynamicEntity = entity.DynamicEntity;

/// Returns a codec specialized for `T`. Instantiating this function validates
/// the complete entity schema at compile time.
pub fn EntityCodec(comptime T: type) type {
    comptime validateEntity(T);

    return struct {
        const Self = @This();
        const fields = std.meta.fields(T);

        /// Writes an OData JSON object. The caller owns no allocations.
        pub fn serialize(value: T, writer: anytype) !void {
            var first = true;
            try writer.writeByte('{');
            inline for (fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "timestamp")) continue;
                try writePropertyPrefix(writer, &first, wireName(T, field.name));
                try writeTypedValue(field.type, @field(value, field.name), writer);
                if (comptime annotationFor(field.type)) |annotation| {
                    try writeAnnotationPrefix(writer, &first, wireName(T, field.name));
                    try writeJsonString(writer, annotation);
                }
            }
            try writer.writeByte('}');
        }

        /// Allocates an OData JSON object. The caller owns the returned slice.
        pub fn toJson(allocator: std.mem.Allocator, value: T) ![]u8 {
            var output: std.Io.Writer.Allocating = .init(allocator);
            errdefer output.deinit();
            try Self.serialize(value, &output.writer);
            return output.toOwnedSlice();
        }

        /// Decodes a JSON object and owns all decoded strings and binary values.
        /// Release those allocations with `deinit`.
        pub fn deserialize(allocator: std.mem.Allocator, json: []const u8) !T {
            var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{
                .allocate = .alloc_always,
            });
            defer parsed.deinit();
            return deserializeObject(allocator, switch (parsed.value) {
                .object => |object| object,
                else => return error.ExpectedObject,
            });
        }

        /// Frees strings, binary values, GUIDs, and DateTimes allocated by
        /// `deserialize`. Calling this on caller-borrowed values is invalid.
        pub fn deinit(allocator: std.mem.Allocator, value: *T) void {
            inline for (fields) |field| {
                deinitTypedValue(field.type, allocator, &@field(value.*, field.name));
            }
        }

        fn deserializeObject(allocator: std.mem.Allocator, object: std.json.ObjectMap) !T {
            var result: T = undefined;
            var initialized: [fields.len]bool = .{false} ** fields.len;
            errdefer inline for (fields, 0..) |field, index| {
                if (initialized[index]) deinitTypedValue(field.type, allocator, &@field(result, field.name));
            };

            inline for (fields, 0..) |field, index| {
                const wire_name = wireName(T, field.name);
                const maybe_value = object.get(wire_name);
                if (maybe_value) |json_value| {
                    const annotation = getAnnotation(object, wire_name);
                    @field(result, field.name) = try decodeTypedValue(field.type, allocator, json_value, annotation, std.mem.eql(u8, field.name, "timestamp"));
                } else {
                    if (comptime isOptional(field.type)) {
                        @field(result, field.name) = null;
                    } else {
                        return error.MissingRequiredProperty;
                    }
                }
                initialized[index] = true;
            }
            return result;
        }
    };
}

/// Serializes a dynamic entity using the same OData JSON rules as typed
/// entities. The entity and all values remain borrowed for the call.
pub fn dynamicToJson(allocator: std.mem.Allocator, value: DynamicEntity) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    const writer = &output.writer;
    var first = true;
    try writer.writeByte('{');
    try writePropertyPrefix(writer, &first, "PartitionKey");
    try writeJsonString(writer, value.partition_key);
    try writePropertyPrefix(writer, &first, "RowKey");
    try writeJsonString(writer, value.row_key);

    var it = value.properties.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        const property = entry.value_ptr.*;
        try writePropertyPrefix(writer, &first, name);
        try writeEdmValue(writer, property);
        if (annotationForEdmValue(property)) |annotation| {
            try writeAnnotationPrefix(writer, &first, name);
            try writeJsonString(writer, annotation);
        }
    }
    if (value.timestamp) |timestamp| {
        try writePropertyPrefix(writer, &first, "Timestamp");
        try writeJsonString(writer, timestamp.value);
    }
    try writer.writeByte('}');
    return output.toOwnedSlice();
}

/// Decodes a runtime-schema entity. The returned entity owns its keys and
/// values and must be released with `DynamicEntity.deinit`.
pub fn dynamicFromJson(allocator: std.mem.Allocator, json: []const u8) !DynamicEntity {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();
    const object = switch (parsed.value) {
        .object => |object| object,
        else => return error.ExpectedObject,
    };
    const partition_key = try jsonString(object.get("PartitionKey") orelse return error.MissingRequiredProperty);
    const row_key = try jsonString(object.get("RowKey") orelse return error.MissingRequiredProperty);
    var result = try DynamicEntity.init(allocator, partition_key, row_key);
    errdefer result.deinit();

    if (object.get("Timestamp")) |timestamp| {
        const datetime = try edm.EdmDateTime.init(try jsonString(timestamp));
        try result.setTimestamp(datetime);
    }

    var it = object.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        if (std.mem.eql(u8, name, "PartitionKey") or std.mem.eql(u8, name, "RowKey") or
            std.mem.eql(u8, name, "Timestamp") or std.mem.endsWith(u8, name, "@odata.type")) continue;
        const annotation = getAnnotation(object, name);
        const property = try decodeEdmValue(allocator, entry.value_ptr.*, annotation);
        defer {
            var owned_property = property;
            owned_property.deinit(allocator);
        }
        try result.put(name, property);
    }
    return result;
}

fn validateEntity(comptime T: type) void {
    if (@typeInfo(T) != .@"struct") @compileError("EntityCodec requires a struct type");
    const fields = std.meta.fields(T);
    const partition_field = findField(T, "partition_key") orelse @compileError("EntityCodec requires a string partition_key field");
    const row_field = findField(T, "row_key") orelse @compileError("EntityCodec requires a string row_key field");
    if (!isString(partition_field.type)) @compileError("EntityCodec partition_key must be []const u8 or []u8");
    if (!isString(row_field.type)) @compileError("EntityCodec row_key must be []const u8 or []u8");

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, "timestamp")) {
            if (field.type != ?edm.EdmDateTime) @compileError("EntityCodec timestamp must be ?EdmDateTime");
        } else if (!isSupported(field.type)) {
            @compileError("EntityCodec field '" ++ field.name ++ "' has an unsupported EDM type");
        }

        const name = wireName(T, field.name);
        if (!std.mem.eql(u8, field.name, "partition_key") and
            !std.mem.eql(u8, field.name, "row_key") and
            !std.mem.eql(u8, field.name, "timestamp"))
        {
            if (std.mem.eql(u8, name, "PartitionKey") or
                std.mem.eql(u8, name, "RowKey") or
                std.mem.eql(u8, name, "Timestamp"))
            {
                @compileError("EntityCodec field '" ++ field.name ++ "' uses a reserved wire name");
            }
            comptime entity.validatePropertyName(name) catch @compileError("EntityCodec field '" ++ field.name ++ "' has an invalid wire name");
        }
    }
    inline for (fields, 0..) |field, index| {
        const name = wireName(T, field.name);
        inline for (fields[index + 1 ..]) |other| {
            if (std.mem.eql(u8, name, wireName(T, other.name))) {
                @compileError("EntityCodec has duplicate wire name '" ++ name ++ "'");
            }
        }
    }
}

fn findField(comptime T: type, comptime name: []const u8) ?std.builtin.Type.StructField {
    inline for (std.meta.fields(T)) |field| {
        if (std.mem.eql(u8, field.name, name)) return field;
    }
    return null;
}

fn wireName(comptime T: type, comptime field_name: []const u8) []const u8 {
    if (std.mem.eql(u8, field_name, "partition_key")) return "PartitionKey";
    if (std.mem.eql(u8, field_name, "row_key")) return "RowKey";
    if (std.mem.eql(u8, field_name, "timestamp")) return "Timestamp";
    if (@hasDecl(T, "table")) {
        const table = T.table;
        if (@hasField(@TypeOf(table), "rename")) {
            const renames = table.rename;
            if (@hasField(@TypeOf(renames), field_name)) return @field(renames, field_name);
        }
    }
    return field_name;
}

fn isString(comptime T: type) bool {
    return T == []const u8 or T == []u8;
}

fn isOptional(comptime T: type) bool {
    return @typeInfo(T) == .optional;
}

fn childType(comptime T: type) type {
    return @typeInfo(T).optional.child;
}

fn isSupported(comptime T: type) bool {
    const Value = if (comptime isOptional(T)) childType(T) else T;
    return Value == bool or Value == i32 or Value == f64 or isString(Value) or
        Value == edm.EdmBinary or Value == edm.EdmDateTime or Value == edm.EdmGuid or Value == edm.EdmInt64;
}

fn annotationFor(comptime T: type) ?[]const u8 {
    const Value = if (comptime isOptional(T)) childType(T) else T;
    if (Value == edm.EdmBinary) return "Edm.Binary";
    if (Value == edm.EdmDateTime) return "Edm.DateTime";
    if (Value == edm.EdmGuid) return "Edm.Guid";
    if (Value == edm.EdmInt64) return "Edm.Int64";
    return null;
}

fn writePropertyPrefix(writer: anytype, first: *bool, name: []const u8) !void {
    if (!first.*) try writer.writeByte(',');
    first.* = false;
    try writeJsonString(writer, name);
    try writer.writeByte(':');
}

fn writeAnnotationPrefix(writer: anytype, first: *bool, name: []const u8) !void {
    if (!first.*) try writer.writeByte(',');
    first.* = false;
    try writer.writeByte('"');
    try request.writeJsonEscaped(writer, name);
    try writer.writeAll("@odata.type\":");
}

fn writeJsonString(writer: anytype, value: []const u8) !void {
    try writer.writeByte('"');
    try request.writeJsonEscaped(writer, value);
    try writer.writeByte('"');
}

fn writeTypedValue(comptime T: type, value: T, writer: anytype) !void {
    if (comptime isOptional(T)) {
        if (value) |inner| return writeTypedValue(childType(T), inner, writer);
        return writer.writeAll("null");
    }
    if (T == bool) return writer.writeAll(if (value) "true" else "false");
    if (T == i32 or T == f64) return writer.print("{d}", .{value});
    if (comptime isString(T)) return writeJsonString(writer, value);
    if (T == edm.EdmBinary) {
        const encoded = try serde.helpers.Base64.serializeAlloc(value.bytes, std.heap.page_allocator);
        defer std.heap.page_allocator.free(encoded);
        return writeJsonString(writer, encoded);
    }
    if (T == edm.EdmDateTime) {
        _ = try edm.EdmDateTime.init(value.value);
        return writeJsonString(writer, value.value);
    }
    if (T == edm.EdmGuid) {
        _ = try edm.EdmGuid.init(value.value);
        return writeJsonString(writer, value.value);
    }
    if (T == edm.EdmInt64) {
        var text: [std.fmt.count("{d}", .{std.math.minInt(i64)})]u8 = undefined;
        const rendered = try std.fmt.bufPrint(&text, "{d}", .{value.value});
        return writeJsonString(writer, rendered);
    }
    unreachable;
}

fn decodeTypedValue(comptime T: type, allocator: std.mem.Allocator, value: std.json.Value, annotation: ?std.json.Value, is_timestamp: bool) !T {
    if (comptime isOptional(T)) {
        if (value == .null) return null;
        return try decodeTypedValue(childType(T), allocator, value, annotation, is_timestamp);
    }
    if (T == bool) return switch (value) {
        .bool => |inner| inner,
        else => error.InvalidPropertyType,
    };
    if (T == i32) return switch (value) {
        .integer => |inner| std.math.cast(i32, inner) orelse error.InvalidPropertyType,
        else => error.InvalidPropertyType,
    };
    if (T == f64) return switch (value) {
        .integer => |inner| @floatFromInt(inner),
        .float => |inner| inner,
        else => error.InvalidPropertyType,
    };
    if (comptime isString(T)) return allocator.dupe(u8, try jsonString(value));
    if (T == edm.EdmBinary) {
        try requireAnnotation(annotation, "Edm.Binary");
        const bytes = try serde.helpers.Base64.deserializeAlloc(try jsonString(value), allocator);
        return .{ .bytes = bytes };
    }
    if (T == edm.EdmDateTime) {
        if (!is_timestamp) try requireAnnotation(annotation, "Edm.DateTime");
        const copied = try allocator.dupe(u8, try jsonString(value));
        errdefer allocator.free(copied);
        return .{ .value = (try edm.EdmDateTime.init(copied)).value };
    }
    if (T == edm.EdmGuid) {
        try requireAnnotation(annotation, "Edm.Guid");
        const copied = try allocator.dupe(u8, try jsonString(value));
        errdefer allocator.free(copied);
        return .{ .value = (try edm.EdmGuid.init(copied)).value };
    }
    if (T == edm.EdmInt64) {
        try requireAnnotation(annotation, "Edm.Int64");
        return .{ .value = try std.fmt.parseInt(i64, try jsonString(value), 10) };
    }
    unreachable;
}

fn deinitTypedValue(comptime T: type, allocator: std.mem.Allocator, value: *T) void {
    if (comptime isOptional(T)) {
        if (value.*) |*inner| deinitTypedValue(childType(T), allocator, inner);
        return;
    }
    if (comptime isString(T)) allocator.free(value.*);
    if (T == edm.EdmBinary) allocator.free(value.bytes);
    if (T == edm.EdmDateTime or T == edm.EdmGuid) allocator.free(value.value);
}

fn requireAnnotation(annotation: ?std.json.Value, expected: []const u8) !void {
    const raw = annotation orelse return error.MissingODataTypeAnnotation;
    if (!std.mem.eql(u8, try jsonString(raw), expected)) return error.InvalidODataTypeAnnotation;
}

fn jsonString(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |inner| inner,
        else => error.InvalidPropertyType,
    };
}

fn getAnnotation(object: std.json.ObjectMap, name: []const u8) ?std.json.Value {
    var it = object.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.endsWith(u8, key, "@odata.type") and
            key.len == name.len + "@odata.type".len and
            std.mem.eql(u8, key[0..name.len], name))
        {
            return entry.value_ptr.*;
        }
    }
    return null;
}

fn writeEdmValue(writer: anytype, value: EdmValue) !void {
    return switch (value) {
        .null => writer.writeAll("null"),
        .boolean => |inner| writer.writeAll(if (inner) "true" else "false"),
        .int32 => |inner| writer.print("{d}", .{inner}),
        .float64 => |inner| writer.print("{d}", .{inner}),
        .string => |inner| writeJsonString(writer, inner),
        .binary => |inner| writeTypedValue(edm.EdmBinary, inner, writer),
        .datetime => |inner| writeTypedValue(edm.EdmDateTime, inner, writer),
        .guid => |inner| writeTypedValue(edm.EdmGuid, inner, writer),
        .int64 => |inner| writeTypedValue(edm.EdmInt64, inner, writer),
    };
}

fn annotationForEdmValue(value: EdmValue) ?[]const u8 {
    return switch (value) {
        .binary => "Edm.Binary",
        .datetime => "Edm.DateTime",
        .guid => "Edm.Guid",
        .int64 => "Edm.Int64",
        else => null,
    };
}

fn decodeEdmValue(allocator: std.mem.Allocator, value: std.json.Value, annotation: ?std.json.Value) !EdmValue {
    if (value == .null) return .null;
    if (annotation) |raw_annotation| {
        const annotation_name = try jsonString(raw_annotation);
        if (std.mem.eql(u8, annotation_name, "Edm.Binary")) return .{ .binary = try decodeTypedValue(edm.EdmBinary, allocator, value, annotation, false) };
        if (std.mem.eql(u8, annotation_name, "Edm.DateTime")) return .{ .datetime = try decodeTypedValue(edm.EdmDateTime, allocator, value, annotation, false) };
        if (std.mem.eql(u8, annotation_name, "Edm.Guid")) return .{ .guid = try decodeTypedValue(edm.EdmGuid, allocator, value, annotation, false) };
        if (std.mem.eql(u8, annotation_name, "Edm.Int64")) return .{ .int64 = try decodeTypedValue(edm.EdmInt64, allocator, value, annotation, false) };
        return error.UnsupportedEdmType;
    }
    return switch (value) {
        .bool => |inner| .{ .boolean = inner },
        .integer => |inner| .{ .int32 = std.math.cast(i32, inner) orelse return error.InvalidPropertyType },
        .float => |inner| .{ .float64 = inner },
        .string => |inner| .{ .string = try allocator.dupe(u8, inner) },
        else => error.InvalidPropertyType,
    };
}

test "typed entity codec writes annotations and round trips owned values" {
    const Product = struct {
        partition_key: []const u8,
        row_key: []const u8,
        name: []const u8,
        count: edm.EdmInt64,
        id: edm.EdmGuid,
        created: edm.EdmDateTime,
        data: ?edm.EdmBinary,
        active: ?bool,
        timestamp: ?edm.EdmDateTime = null,

        pub const table = .{ .rename = .{ .name = "ProductName" } };
    };
    const Codec = EntityCodec(Product);
    const allocator = std.testing.allocator;
    const json = try Codec.toJson(allocator, .{
        .partition_key = "part\"ition",
        .row_key = "row",
        .name = "A\nB",
        .count = .{ .value = 9_223_372_036_854_775_807 },
        .id = try edm.EdmGuid.init("01234567-89ab-cdef-0123-456789abcdef"),
        .created = try edm.EdmDateTime.init("2024-02-29T12:34:56.789Z"),
        .data = .{ .bytes = "hi" },
        .active = null,
    });
    defer allocator.free(json);
    try std.testing.expectEqualStrings(
        "{\"PartitionKey\":\"part\\\"ition\",\"RowKey\":\"row\",\"ProductName\":\"A\\nB\",\"count\":\"9223372036854775807\",\"count@odata.type\":\"Edm.Int64\",\"id\":\"01234567-89ab-cdef-0123-456789abcdef\",\"id@odata.type\":\"Edm.Guid\",\"created\":\"2024-02-29T12:34:56.789Z\",\"created@odata.type\":\"Edm.DateTime\",\"data\":\"aGk=\",\"data@odata.type\":\"Edm.Binary\",\"active\":null}",
        json,
    );

    var decoded = try Codec.deserialize(allocator, json);
    defer Codec.deinit(allocator, &decoded);
    try std.testing.expectEqualStrings("A\nB", decoded.name);
    try std.testing.expectEqual(@as(i64, 9_223_372_036_854_775_807), decoded.count.value);
    try std.testing.expectEqualStrings("hi", decoded.data.?.bytes);
    try std.testing.expect(decoded.active == null);
}

test "dynamic entity codec preserves annotations and ownership" {
    const allocator = std.testing.allocator;
    var value = try DynamicEntity.init(allocator, "pk", "rk");
    defer value.deinit();
    try value.put("Blob", .{ .binary = .{ .bytes = "hello" } });
    try value.put("Id", .{ .guid = try edm.EdmGuid.init("01234567-89ab-cdef-0123-456789abcdef") });
    const json = try dynamicToJson(allocator, value);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Blob@odata.type\":\"Edm.Binary\"") != null);
    var decoded = try dynamicFromJson(allocator, json);
    defer decoded.deinit();
    try std.testing.expectEqualStrings("hello", decoded.properties.get("Blob").?.binary.bytes);
    try std.testing.expectError(error.InvalidPropertyName, value.put("not-valid", .{ .boolean = true }));
}

test "entity codec rejects invalid EDM wire values" {
    const Value = struct {
        partition_key: []const u8,
        row_key: []const u8,
        id: edm.EdmGuid,
        created: edm.EdmDateTime,
    };
    const Codec = EntityCodec(Value);
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidGuid,
        Codec.deserialize(allocator,
            \\{"PartitionKey":"p","RowKey":"r","id":"not-a-guid","id@odata.type":"Edm.Guid","created":"2024-01-01T00:00:00Z","created@odata.type":"Edm.DateTime"}
        ),
    );
    try std.testing.expectError(
        error.MissingODataTypeAnnotation,
        Codec.deserialize(allocator,
            \\{"PartitionKey":"p","RowKey":"r","id":"01234567-89ab-cdef-0123-456789abcdef","created":"2024-01-01T00:00:00Z","created@odata.type":"Edm.DateTime"}
        ),
    );
    try std.testing.expectError(
        error.InvalidDateTime,
        Codec.deserialize(allocator,
            \\{"PartitionKey":"p","RowKey":"r","id":"01234567-89ab-cdef-0123-456789abcdef","id@odata.type":"Edm.Guid","created":"2024-02-30T00:00:00Z","created@odata.type":"Edm.DateTime"}
        ),
    );

    const Boolean = struct {
        partition_key: []const u8,
        row_key: []const u8,
        active: bool,
    };
    try std.testing.expectError(
        error.InvalidPropertyType,
        EntityCodec(Boolean).deserialize(allocator,
            \\{"PartitionKey":"p","RowKey":"r","active":"true"}
        ),
    );
}
