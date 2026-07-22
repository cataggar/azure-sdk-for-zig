const std = @import("std");
const serde = @import("serde");
const kusto_common = @import("azure_sdk_kusto_common");
const KustoErrorSource = kusto_common.KustoErrorSource;

pub const DecodeOptions = struct {
    allow_varying_row_widths: bool = false,
};

pub const KustoResponseProtocol = enum {
    v1,
    v2,
};

pub const KustoScalarKind = enum {
    string,
    bool,
    int,
    long,
    real,
    decimal,
    datetime,
    timespan,
    guid,
    dynamic,
    unknown,
};

pub const KustoTableKind = enum {
    primary_result,
    query_result,
    query_properties,
    query_status,
    query_completion_information,
    query_trace_log,
    query_perf_log,
    query_plan,
    table_of_contents,
    unknown,
};

/// A decoded, allocator-owned Kusto scalar. `dynamic`, `unknown`, and
/// `real_raw` retain their original JSON token rather than a lossy rendering.
pub const KustoValue = union(enum) {
    null,
    string: []u8,
    bool: bool,
    int: i32,
    long: i64,
    real: f64,
    real_raw: []u8,
    decimal: []u8,
    datetime: []u8,
    timespan: []u8,
    guid: []u8,
    dynamic: []u8,
    unknown: []u8,

    pub fn deinit(self: *KustoValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string,
            .real_raw,
            .decimal,
            .datetime,
            .timespan,
            .guid,
            .dynamic,
            .unknown,
            => |value| allocator.free(value),
            else => {},
        }
        self.* = .null;
    }

    /// Duplicates every allocator-owned payload so the result survives its
    /// source dataset's `deinit`.
    pub fn clone(self: KustoValue, allocator: std.mem.Allocator) !KustoValue {
        return switch (self) {
            .null => .null,
            .string => |value| .{ .string = try allocator.dupe(u8, value) },
            .bool => |value| .{ .bool = value },
            .int => |value| .{ .int = value },
            .long => |value| .{ .long = value },
            .real => |value| .{ .real = value },
            .real_raw => |value| .{ .real_raw = try allocator.dupe(u8, value) },
            .decimal => |value| .{ .decimal = try allocator.dupe(u8, value) },
            .datetime => |value| .{ .datetime = try allocator.dupe(u8, value) },
            .timespan => |value| .{ .timespan = try allocator.dupe(u8, value) },
            .guid => |value| .{ .guid = try allocator.dupe(u8, value) },
            .dynamic => |value| .{ .dynamic = try allocator.dupe(u8, value) },
            .unknown => |value| .{ .unknown = try allocator.dupe(u8, value) },
        };
    }

    pub fn asString(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .string => |value| value,
            else => null,
        };
    }

    pub fn isNull(self: KustoValue) bool {
        return switch (self) {
            .null => true,
            else => false,
        };
    }

    pub fn asBool(self: KustoValue) ?bool {
        return switch (self) {
            .bool => |value| value,
            else => null,
        };
    }

    pub fn asI32(self: KustoValue) ?i32 {
        return switch (self) {
            .int => |value| value,
            else => null,
        };
    }

    pub fn asI64(self: KustoValue) ?i64 {
        return switch (self) {
            .int => |value| value,
            .long => |value| value,
            else => null,
        };
    }

    pub fn asF64(self: KustoValue) ?f64 {
        return switch (self) {
            .real => |value| value,
            else => null,
        };
    }

    pub fn asDecimal(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .decimal => |value| value,
            else => null,
        };
    }

    pub fn asDateTime(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .datetime => |value| value,
            else => null,
        };
    }

    pub fn asTimespan(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .timespan => |value| value,
            else => null,
        };
    }

    pub fn asGuid(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .guid => |value| value,
            else => null,
        };
    }

    pub fn asDynamic(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .dynamic => |value| value,
            else => null,
        };
    }

    /// Returns an owned lexical value for string-like scalar types.
    pub fn lexical(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .string,
            .decimal,
            .datetime,
            .timespan,
            .guid,
            => |value| value,
            else => null,
        };
    }

    /// Returns the exact original JSON token for raw JSON values.
    pub fn rawJson(self: KustoValue) ?[]const u8 {
        return switch (self) {
            .real_raw,
            .dynamic,
            .unknown,
            => |value| value,
            else => null,
        };
    }
};

pub const KustoResultColumn = struct {
    name: []u8,
    column_type: []u8,
    scalar_kind: KustoScalarKind,
    // ColumnType is authoritative. A V1 DataType-only column is advisory and
    // may fall back to raw JSON when the wire value does not match its alias.
    has_declared_type: bool = true,

    pub fn deinit(self: *KustoResultColumn, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.column_type);
        self.* = undefined;
    }
};

pub const KustoResultRow = struct {
    values: []KustoValue,
    // This is the table's separately allocated column array, not a pointer to
    // a movable table struct, so row name lookup remains valid after reallocation.
    columns: []const KustoResultColumn,

    pub fn deinit(self: *KustoResultRow, allocator: std.mem.Allocator) void {
        for (self.values) |*value| value.deinit(allocator);
        allocator.free(self.values);
        self.* = undefined;
    }

    pub fn get(self: *const KustoResultRow, index: usize) ?*const KustoValue {
        if (index >= self.values.len) return null;
        return &self.values[index];
    }

    pub fn getByName(self: *const KustoResultRow, name: []const u8) ?*const KustoValue {
        for (self.columns, 0..) |column, index| {
            if (std.mem.eql(u8, column.name, name))
                return self.get(index);
        }
        return null;
    }
};

pub const RowIterator = struct {
    rows: []const KustoResultRow,
    index: usize = 0,

    pub fn next(self: *RowIterator) ?*const KustoResultRow {
        if (self.index >= self.rows.len) return null;
        defer self.index += 1;
        return &self.rows[self.index];
    }
};

pub const KustoResultTable = struct {
    id: ?i64 = null,
    ordinal: ?i64 = null,
    name: []u8,
    kind: ?[]u8 = null,
    known_kind: KustoTableKind = .unknown,
    toc_name: ?[]u8 = null,
    toc_id: ?[]u8 = null,
    pretty_name: ?[]u8 = null,
    columns: []KustoResultColumn,
    rows: []KustoResultRow,
    progress: ?f64 = null,
    reported_row_count: ?i64 = null,
    completed: bool = true,

    pub fn deinit(self: *KustoResultTable, allocator: std.mem.Allocator) void {
        deinitRows(self.rows, allocator);
        allocator.free(self.rows);
        deinitTableMetadata(self, allocator);
        self.* = undefined;
    }

    pub fn rowIterator(self: *const KustoResultTable) RowIterator {
        return .{ .rows = self.rows };
    }

    /// Creates a decoder which resolves the requested schema once.
    pub fn rowDecoder(self: *const KustoResultTable, comptime T: type) !KustoRowDecoder(T) {
        return KustoRowDecoder(T).init(self);
    }

    /// Returns an iterator which borrows this table and yields owned rows.
    pub fn typedRows(
        self: *const KustoResultTable,
        comptime T: type,
        allocator: std.mem.Allocator,
    ) !KustoTypedRowIterator(T) {
        return .{
            .decoder = try self.rowDecoder(T),
            .rows = self.rows,
            .allocator = allocator,
        };
    }
};

/// An owned decoded datetime lexical value. Unlike `kql.DateTime`, this owns
/// its bytes and therefore remains valid after the source dataset is freed.
pub const KustoDateTime = struct {
    value: []u8,

    pub fn deinit(self: *KustoDateTime, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.* = undefined;
    }
};

/// An owned decoded timespan lexical value.
pub const KustoTimespan = struct {
    value: []u8,

    pub fn deinit(self: *KustoTimespan, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.* = undefined;
    }
};

/// An owned decoded decimal lexical value.
pub const KustoDecimal = struct {
    value: []u8,

    pub fn deinit(self: *KustoDecimal, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.* = undefined;
    }
};

/// An owned decoded GUID lexical value.
pub const KustoGuid = struct {
    value: []u8,

    pub fn deinit(self: *KustoGuid, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        self.* = undefined;
    }
};

/// Exact owned JSON for a Kusto `dynamic` cell.
pub const KustoDynamic = struct {
    raw_json: []u8,

    pub fn deinit(self: *KustoDynamic, allocator: std.mem.Allocator) void {
        allocator.free(self.raw_json);
        self.* = undefined;
    }
};

/// A schema-validated, allocation-free mapping from Zig fields to table cells.
pub fn KustoRowDecoder(comptime T: type) type {
    validateRowType(T);
    const fields = std.meta.fields(T);

    return struct {
        const Self = @This();

        columns: []const KustoResultColumn,
        mapping: [fields.len]usize,

        /// Resolves all requested columns once and rejects ambiguous schemas.
        pub fn init(table: *const KustoResultTable) !Self {
            const missing_column = std.math.maxInt(usize);
            var mapping: [fields.len]usize = [_]usize{missing_column} ** fields.len;
            for (table.columns, 0..) |column, column_index| {
                inline for (fields, 0..) |meta_field, field_index| {
                    if (std.mem.eql(u8, column.name, rowColumnName(T, meta_field.name))) {
                        if (mapping[field_index] != missing_column)
                            return error.DuplicateKustoColumn;
                        mapping[field_index] = column_index;
                    }
                }
            }
            inline for (mapping) |column_index| {
                if (column_index == missing_column)
                    return error.MissingKustoColumn;
            }
            return .{ .columns = table.columns, .mapping = mapping };
        }

        /// Converts a borrowed result row into a wholly allocator-owned `T`.
        pub fn rowAs(
            self: *const Self,
            row: *const KustoResultRow,
            allocator: std.mem.Allocator,
        ) !T {
            if (row.columns.ptr != self.columns.ptr or row.columns.len != self.columns.len)
                return error.KustoRowSchemaMismatch;

            var result: T = undefined;
            var initialized: [fields.len]bool = [_]bool{false} ** fields.len;
            errdefer {
                inline for (fields, 0..) |meta_field, field_index| {
                    if (initialized[field_index])
                        deinitDecodedField(meta_field.type, &@field(result, meta_field.name), allocator);
                }
            }

            inline for (fields, 0..) |meta_field, field_index| {
                const column_index = self.mapping[field_index];
                if (column_index >= row.values.len) return error.MissingKustoCell;
                @field(result, meta_field.name) = try decodeField(
                    meta_field.type,
                    allocator,
                    &row.values[column_index],
                );
                initialized[field_index] = true;
            }
            return result;
        }

        pub fn deinitRow(value: *T, allocator: std.mem.Allocator) void {
            deinitDecodedRow(T, value, allocator);
        }
    };
}

/// Deinitializes all allocations owned by an owned typed result row.
pub fn deinitRow(value: anytype, allocator: std.mem.Allocator) void {
    const pointer = @typeInfo(@TypeOf(value));
    const T = switch (pointer) {
        .pointer => |item| item.child,
        else => @compileError("result.deinitRow requires a pointer to a row struct"),
    };
    validateRowType(T);
    deinitDecodedRow(T, value, allocator);
}

/// An iterator that owns its precomputed decoder and borrows table rows.
pub fn KustoTypedRowIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        decoder: KustoRowDecoder(T),
        rows: []const KustoResultRow,
        allocator: std.mem.Allocator,
        index: usize = 0,

        /// Returns one owned row at a time; call `deinitRow` for every result.
        pub fn next(self: *Self) !?T {
            if (self.index >= self.rows.len) return null;
            defer self.index += 1;
            return try self.decoder.rowAs(&self.rows[self.index], self.allocator);
        }

        pub fn deinitRow(value: *T, allocator: std.mem.Allocator) void {
            deinitDecodedRow(T, value, allocator);
        }
    };
}

fn validateRowType(comptime T: type) void {
    const info = switch (@typeInfo(T)) {
        .@"struct" => |item| item,
        else => @compileError("KustoRowDecoder requires a non-tuple struct row type"),
    };
    if (info.is_tuple)
        @compileError("KustoRowDecoder requires a non-tuple struct row type");
    validateKustoColumnMappings(T);
    inline for (std.meta.fields(T), 0..) |meta_field, field_index| {
        validateDecodedFieldType(T, meta_field.name, meta_field.type);
        const requested_name = rowColumnName(T, meta_field.name);
        inline for (std.meta.fields(T)[field_index + 1 ..]) |other| {
            if (std.mem.eql(u8, requested_name, rowColumnName(T, other.name))) {
                @compileError(std.fmt.comptimePrint(
                    "Kusto row fields '{s}' and '{s}' both request column '{s}'",
                    .{ meta_field.name, other.name, requested_name },
                ));
            }
        }
    }
}

fn validateKustoColumnMappings(comptime T: type) void {
    if (!@hasDecl(T, "kusto_columns")) return;
    const Mapping = @TypeOf(@field(T, "kusto_columns"));
    const mapping_info = switch (@typeInfo(Mapping)) {
        .@"struct" => |item| item,
        else => @compileError("kusto_columns must be a non-tuple struct literal"),
    };
    if (mapping_info.is_tuple)
        @compileError("kusto_columns must be a non-tuple struct literal");
    inline for (std.meta.fields(Mapping)) |mapping_field| {
        if (!hasRowField(T, mapping_field.name)) {
            @compileError(std.fmt.comptimePrint(
                "kusto_columns contains unknown Zig field '{s}'",
                .{mapping_field.name},
            ));
        }
        const name = comptimeByteString(@field(T.kusto_columns, mapping_field.name));
        if (name.len == 0) {
            @compileError(std.fmt.comptimePrint(
                "kusto_columns target for '{s}' must not be empty",
                .{mapping_field.name},
            ));
        }
    }
}

fn hasRowField(comptime T: type, comptime name: []const u8) bool {
    inline for (std.meta.fields(T)) |meta_field| {
        if (std.mem.eql(u8, meta_field.name, name)) return true;
    }
    return false;
}

fn rowColumnName(comptime T: type, comptime field_name: []const u8) []const u8 {
    if (!@hasDecl(T, "kusto_columns")) return field_name;
    inline for (std.meta.fields(@TypeOf(T.kusto_columns))) |mapping_field| {
        if (std.mem.eql(u8, mapping_field.name, field_name))
            return comptimeByteString(@field(T.kusto_columns, mapping_field.name));
    }
    return field_name;
}

fn comptimeByteString(comptime value: anytype) []const u8 {
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .array => |array| if (array.child == u8)
            value[0..]
        else
            @compileError("kusto_columns targets must be byte strings"),
        .pointer => |pointer| switch (pointer.size) {
            .slice => if (pointer.child == u8)
                value
            else
                @compileError("kusto_columns targets must be byte strings"),
            .one => switch (@typeInfo(pointer.child)) {
                .array => |array| if (array.child == u8)
                    value[0..]
                else
                    @compileError("kusto_columns targets must be byte strings"),
                else => @compileError("kusto_columns targets must be byte strings"),
            },
            else => @compileError("kusto_columns targets must be byte strings"),
        },
        else => @compileError("kusto_columns targets must be byte strings"),
    };
}

fn validateDecodedFieldType(
    comptime Row: type,
    comptime field_name: []const u8,
    comptime T: type,
) void {
    switch (@typeInfo(T)) {
        .optional => |item| {
            if (@typeInfo(item.child) == .optional) {
                @compileError(std.fmt.comptimePrint(
                    "Kusto row field '{s}.{s}' cannot use nested optional type {s}",
                    .{ @typeName(Row), field_name, @typeName(T) },
                ));
            }
            validateDecodedFieldType(Row, field_name, item.child);
            return;
        },
        else => {},
    }
    if (hasCustomDecode(T)) {
        validateCustomDecode(T);
        validateCustomDeinit(T);
        return;
    }
    if (T == bool or T == i32 or T == i64 or T == f64 or
        T == []u8 or T == []const u8 or T == KustoValue or
        T == KustoDateTime or T == KustoTimespan or T == KustoDecimal or
        T == KustoGuid or T == KustoDynamic)
        return;
    @compileError(std.fmt.comptimePrint(
        "Kusto row field '{s}.{s}' has unsupported type {s}; supported types are bool, i32, i64, f64, []u8, []const u8, KustoValue, KustoDateTime, KustoTimespan, KustoDecimal, KustoGuid, KustoDynamic, optional forms, or a kustoDecode hook",
        .{ @typeName(Row), field_name, @typeName(T) },
    ));
}

fn hasCustomDecode(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "kustoDecode"),
        .@"union" => @hasDecl(T, "kustoDecode"),
        .@"enum" => @hasDecl(T, "kustoDecode"),
        .@"opaque" => @hasDecl(T, "kustoDecode"),
        else => false,
    };
}

fn hasCustomDeinit(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "deinit"),
        .@"union" => @hasDecl(T, "deinit"),
        .@"enum" => @hasDecl(T, "deinit"),
        .@"opaque" => @hasDecl(T, "deinit"),
        else => false,
    };
}

fn validateCustomDecode(comptime T: type) void {
    const function_info = switch (@typeInfo(@TypeOf(T.kustoDecode))) {
        .@"fn" => |item| item,
        else => @compileError("kustoDecode must be a function"),
    };
    if (function_info.params.len != 2 or
        function_info.params[0].type != std.mem.Allocator or
        function_info.params[1].type != *const KustoValue)
    {
        @compileError(std.fmt.comptimePrint(
            "{s}.kustoDecode must have signature fn (std.mem.Allocator, *const KustoValue) !@This()",
            .{@typeName(T)},
        ));
    }
    const return_type = function_info.return_type orelse @compileError("kustoDecode must return an error union");
    const error_union = switch (@typeInfo(return_type)) {
        .error_union => |item| item,
        else => @compileError("kustoDecode must return an error union"),
    };
    if (error_union.payload != T) {
        @compileError(std.fmt.comptimePrint(
            "{s}.kustoDecode must return !@This()",
            .{@typeName(T)},
        ));
    }
}

fn validateCustomDeinit(comptime T: type) void {
    if (!hasCustomDeinit(T)) return;
    const function_info = switch (@typeInfo(@TypeOf(T.deinit))) {
        .@"fn" => |item| item,
        else => @compileError("deinit must be a function"),
    };
    if (function_info.params.len != 2 or
        function_info.params[0].type != *T or
        function_info.params[1].type != std.mem.Allocator or
        function_info.return_type != void)
    {
        @compileError(std.fmt.comptimePrint(
            "{s}.deinit must have signature fn (*@This(), std.mem.Allocator) void",
            .{@typeName(T)},
        ));
    }
}

fn decodeField(comptime T: type, allocator: std.mem.Allocator, value: *const KustoValue) !T {
    return switch (@typeInfo(T)) {
        .optional => |item| if (value.isNull())
            null
        else
            try decodeNonOptional(item.child, allocator, value),
        else => blk: {
            if (value.isNull()) return error.RequiredKustoValueIsNull;
            break :blk try decodeNonOptional(T, allocator, value);
        },
    };
}

fn decodeNonOptional(comptime T: type, allocator: std.mem.Allocator, value: *const KustoValue) !T {
    if (comptime hasCustomDecode(T))
        return T.kustoDecode(allocator, value);
    if (T == bool) return value.asBool() orelse error.IncompatibleKustoValue;
    if (T == i32) return value.asI32() orelse error.IncompatibleKustoValue;
    if (T == i64) return value.asI64() orelse error.IncompatibleKustoValue;
    if (T == f64) return typedReal(value.*) orelse error.IncompatibleKustoValue;
    if (T == []u8 or T == []const u8) {
        const text = value.asString() orelse return error.IncompatibleKustoValue;
        return try allocator.dupe(u8, text);
    }
    if (T == KustoValue) return try value.clone(allocator);
    if (T == KustoDateTime) {
        const text = value.asDateTime() orelse return error.IncompatibleKustoValue;
        return .{ .value = try allocator.dupe(u8, text) };
    }
    if (T == KustoTimespan) {
        const text = value.asTimespan() orelse return error.IncompatibleKustoValue;
        return .{ .value = try allocator.dupe(u8, text) };
    }
    if (T == KustoDecimal) {
        const text = value.asDecimal() orelse return error.IncompatibleKustoValue;
        return .{ .value = try allocator.dupe(u8, text) };
    }
    if (T == KustoGuid) {
        const text = value.asGuid() orelse return error.IncompatibleKustoValue;
        return .{ .value = try allocator.dupe(u8, text) };
    }
    if (T == KustoDynamic) {
        const raw = value.asDynamic() orelse return error.IncompatibleKustoValue;
        return .{ .raw_json = try allocator.dupe(u8, raw) };
    }
    unreachable;
}

fn typedReal(value: KustoValue) ?f64 {
    return switch (value) {
        .real => |number| number,
        .real_raw => |raw| {
            if (std.mem.eql(u8, raw, "\"NaN\"")) return std.math.nan(f64);
            if (std.mem.eql(u8, raw, "\"Infinity\"") or
                std.mem.eql(u8, raw, "\"+Infinity\""))
                return std.math.inf(f64);
            if (std.mem.eql(u8, raw, "\"-Infinity\""))
                return -std.math.inf(f64);
            return null;
        },
        else => null,
    };
}

fn deinitDecodedRow(comptime T: type, value: *T, allocator: std.mem.Allocator) void {
    inline for (std.meta.fields(T)) |meta_field| {
        deinitDecodedField(meta_field.type, &@field(value.*, meta_field.name), allocator);
    }
}

fn deinitDecodedField(comptime T: type, value: *T, allocator: std.mem.Allocator) void {
    switch (@typeInfo(T)) {
        .optional => {
            if (value.*) |*child| deinitDecodedField(@typeInfo(T).optional.child, child, allocator);
            return;
        },
        else => {},
    }
    if (T == []u8 or T == []const u8) {
        allocator.free(value.*);
        return;
    }
    if (T == KustoValue) {
        value.deinit(allocator);
        return;
    }
    if (T == KustoDateTime or T == KustoTimespan or T == KustoDecimal or
        T == KustoGuid or T == KustoDynamic)
    {
        value.deinit(allocator);
        return;
    }
    if (comptime hasCustomDeinit(T)) value.deinit(allocator);
}

/// The raw JSON and ordinal for a buffered response frame. `raw_json` borrows
/// the containing dataset's `raw_response`; it is not a second response copy.
pub const KustoFramePayload = struct {
    index: usize,
    raw_json: []const u8,
};

/// An unrecognized V2 frame. Its decoded `frame_type` is owned by the
/// dataset, while `raw_json` borrows the dataset's raw response.
pub const KustoUnknownFrame = struct {
    index: usize,
    frame_type: []u8,
    raw_json: []const u8,
};

/// A buffered Kusto response frame.
///
/// Known V2 frame kinds and a V1 response root are explicit union tags. Every
/// variant exposes its exact JSON through `rawJson`, and an unknown frame also
/// retains its exact decoded `FrameType` text.
pub const KustoFrame = union(enum) {
    v1_root: KustoFramePayload,
    data_set_header: KustoFramePayload,
    data_set_completion: KustoFramePayload,
    data_table: KustoFramePayload,
    table_header: KustoFramePayload,
    table_fragment: KustoFramePayload,
    table_progress: KustoFramePayload,
    table_completion: KustoFramePayload,
    unknown: KustoUnknownFrame,

    pub fn deinit(self: *KustoFrame, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .unknown => |frame| allocator.free(frame.frame_type),
            else => {},
        }
        self.* = undefined;
    }

    pub fn index(self: KustoFrame) usize {
        return switch (self) {
            inline else => |frame| frame.index,
        };
    }

    pub fn rawJson(self: KustoFrame) []const u8 {
        return switch (self) {
            inline else => |frame| frame.raw_json,
        };
    }

    pub fn frameType(self: KustoFrame) []const u8 {
        return switch (self) {
            .v1_root => "V1",
            .data_set_header => "DataSetHeader",
            .data_set_completion => "DataSetCompletion",
            .data_table => "DataTable",
            .table_header => "TableHeader",
            .table_fragment => "TableFragment",
            .table_progress => "TableProgress",
            .table_completion => "TableCompletion",
            .unknown => |frame| frame.frame_type,
        };
    }
};

pub const FrameIterator = struct {
    frames: []const KustoFrame,
    index: usize = 0,

    pub fn next(self: *FrameIterator) ?*const KustoFrame {
        if (self.index >= self.frames.len) return null;
        defer self.index += 1;
        return &self.frames[self.index];
    }
};

pub const TableIterator = struct {
    tables: []const KustoResultTable,
    index: usize = 0,

    pub fn next(self: *TableIterator) ?*const KustoResultTable {
        if (self.index >= self.tables.len) return null;
        defer self.index += 1;
        return &self.tables[self.index];
    }
};

pub const KustoResponseDataSet = struct {
    protocol: KustoResponseProtocol,
    tables: []KustoResultTable,
    raw_response: []u8,
    frames: []KustoFrame,
    v1_exceptions: [][]u8,
    version: ?[]u8 = null,
    is_progressive: bool = false,
    is_fragmented: ?bool = null,
    error_reporting_placement: ?[]u8 = null,
    completed: bool = false,
    has_errors: ?bool = null,
    cancelled: bool = false,
    client_request_id: ?[]u8 = null,
    activity_id: ?[]u8 = null,

    pub fn deinit(self: *KustoResponseDataSet, allocator: std.mem.Allocator) void {
        for (self.tables) |*table| table.deinit(allocator);
        allocator.free(self.tables);
        for (self.frames) |*frame| frame.deinit(allocator);
        allocator.free(self.frames);
        for (self.v1_exceptions) |value| allocator.free(value);
        allocator.free(self.v1_exceptions);
        allocator.free(self.raw_response);
        if (self.version) |value| allocator.free(value);
        if (self.error_reporting_placement) |value| allocator.free(value);
        if (self.client_request_id) |value| allocator.free(value);
        if (self.activity_id) |value| allocator.free(value);
        self.* = undefined;
    }

    pub fn tableIterator(self: *const KustoResponseDataSet) TableIterator {
        return .{ .tables = self.tables };
    }

    pub fn frameIterator(self: *const KustoResponseDataSet) FrameIterator {
        return .{ .frames = self.frames };
    }

    pub fn tableById(self: *const KustoResponseDataSet, id: i64) ?*const KustoResultTable {
        for (self.tables) |*table| {
            if (table.id != null and table.id.? == id) return table;
        }
        return null;
    }

    pub fn tableByKind(self: *const KustoResponseDataSet, kind: []const u8) ?*const KustoResultTable {
        for (self.tables) |*table| {
            if (table.kind) |table_kind| {
                if (std.ascii.eqlIgnoreCase(table_kind, kind)) return table;
            }
            if (table.known_kind != .unknown and
                std.ascii.eqlIgnoreCase(tableKindName(table.known_kind), kind))
                return table;
        }
        return null;
    }

    pub fn queryProperties(self: *const KustoResponseDataSet) ?*const KustoResultTable {
        for (self.tables) |*table| {
            if (table.known_kind == .query_properties) return table;
        }
        return null;
    }

    pub fn queryStatus(self: *const KustoResponseDataSet) ?*const KustoResultTable {
        for (self.tables) |*table| {
            if (table.known_kind == .query_status or table.known_kind == .query_completion_information)
                return table;
        }
        return null;
    }

    /// Prefers explicit primary/query-result metadata. The V1 fallback exists
    /// for management responses that consist of one ordinary result table.
    pub fn primaryTable(self: *const KustoResponseDataSet) ?*const KustoResultTable {
        for (self.tables) |*table| {
            if (table.known_kind == .primary_result or table.known_kind == .query_result)
                return table;
        }
        for (self.tables) |*table| {
            if (std.ascii.eqlIgnoreCase(table.name, "PrimaryResult") or
                (table.toc_name != null and std.ascii.eqlIgnoreCase(table.toc_name.?, "PrimaryResult")))
                return table;
        }
        if (self.protocol == .v1 and self.tables.len == 1)
            return &self.tables[0];
        return null;
    }
};

/// How a progressive table batch changes its table's current rows. Consumers
/// must treat `replace` as a reset, including when the batch has zero rows.
pub const ProgressiveTableAction = enum {
    append,
    replace,
};

/// Allocator-owned V2 data-set metadata emitted by a progressive stream.
pub const ProgressiveDataSetHeader = struct {
    version: []u8,
    is_progressive: bool,
    is_fragmented: ?bool = null,
    error_reporting_placement: ?[]u8 = null,

    pub fn deinit(self: *ProgressiveDataSetHeader, allocator: std.mem.Allocator) void {
        allocator.free(self.version);
        if (self.error_reporting_placement) |value| allocator.free(value);
        self.* = undefined;
    }
};

/// An owned table-shaped progressive batch. A `data_table` event is always a
/// replacement, while a table fragment preserves the server's explicit action.
pub const ProgressiveTableBatch = struct {
    action: ProgressiveTableAction,
    table: KustoResultTable,
    failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *ProgressiveTableBatch, allocator: std.mem.Allocator) void {
        self.table.deinit(allocator);
        if (self.failure) |*failure| failure.deinit();
        self.* = undefined;
    }
};

pub const ProgressiveTableProgress = struct {
    table_id: i64,
    progress: f64,
};

pub const ProgressiveTableCompletion = struct {
    table_id: i64,
    row_count: i64,
    has_errors: bool,
    cancelled: bool,
    failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *ProgressiveTableCompletion) void {
        if (self.failure) |*failure| failure.deinit();
        self.* = undefined;
    }
};

pub const ProgressiveDataSetCompletion = struct {
    has_errors: bool,
    cancelled: bool,
    failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *ProgressiveDataSetCompletion) void {
        if (self.failure) |*failure| failure.deinit();
        self.* = undefined;
    }
};

pub const ProgressiveUnknownFrame = struct {
    frame_type: []u8,

    pub fn deinit(self: *ProgressiveUnknownFrame, allocator: std.mem.Allocator) void {
        allocator.free(self.frame_type);
        self.* = undefined;
    }
};

/// One owned V2 response event. `raw_json` is the exact complete JSON object
/// received from the wire and remains valid until `deinit`.
pub const ProgressiveFrame = struct {
    index: usize,
    raw_json: []u8,
    payload: Payload,

    pub const Payload = union(enum) {
        data_set_header: ProgressiveDataSetHeader,
        data_table: ProgressiveTableBatch,
        table_header: KustoResultTable,
        table_fragment: ProgressiveTableBatch,
        table_progress: ProgressiveTableProgress,
        table_completion: ProgressiveTableCompletion,
        data_set_completion: ProgressiveDataSetCompletion,
        unknown: ProgressiveUnknownFrame,
    };

    pub fn deinit(self: *ProgressiveFrame, allocator: std.mem.Allocator) void {
        switch (self.payload) {
            .data_set_header => |*header| header.deinit(allocator),
            .data_table, .table_fragment => |*batch| batch.deinit(allocator),
            .table_header => |*table| table.deinit(allocator),
            .table_completion => |*completion| completion.deinit(),
            .data_set_completion => |*completion| completion.deinit(),
            .unknown => |*unknown| unknown.deinit(allocator),
            .table_progress => {},
        }
        allocator.free(self.raw_json);
        self.* = undefined;
    }

    pub fn frameType(self: *const ProgressiveFrame) []const u8 {
        return switch (self.payload) {
            .data_set_header => "DataSetHeader",
            .data_table => "DataTable",
            .table_header => "TableHeader",
            .table_fragment => "TableFragment",
            .table_progress => "TableProgress",
            .table_completion => "TableCompletion",
            .data_set_completion => "DataSetCompletion",
            .unknown => |unknown| unknown.frame_type,
        };
    }
};

const ProgressiveTableState = struct {
    table: ?KustoResultTable,
    row_count: i64,
    completed: bool,

    fn deinit(self: *ProgressiveTableState, allocator: std.mem.Allocator) void {
        if (self.table) |*table| table.deinit(allocator);
        self.* = undefined;
    }
};

/// Incrementally validates V2 frames while retaining only schemas, row counts,
/// and table state. Every input slice passed to `decodeOwnedFrame` transfers
/// ownership, whether decoding succeeds or fails.
pub const ProgressiveDecoder = struct {
    allocator: std.mem.Allocator,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    tables: std.ArrayList(ProgressiveTableState) = .empty,
    table_indexes: std.AutoHashMap(i64, usize),
    saw_header: bool = false,
    saw_completion: bool = false,
    is_progressive: bool = false,
    is_fragmented: bool = false,
    next_index: usize = 0,
    max_table_count: usize = 1024,

    pub fn init(
        allocator: std.mem.Allocator,
        options: DecodeOptions,
        operation: kusto_common.KustoOperation,
    ) ProgressiveDecoder {
        return .{
            .allocator = allocator,
            .options = options,
            .operation = operation,
            .table_indexes = std.AutoHashMap(i64, usize).init(allocator),
        };
    }

    pub fn deinit(self: *ProgressiveDecoder) void {
        for (self.tables.items) |*table| table.deinit(self.allocator);
        self.tables.deinit(self.allocator);
        self.table_indexes.deinit();
        self.* = undefined;
    }

    /// Decodes one complete JSON object and transfers ownership of `raw_json`
    /// to the returned event. The decoder never accumulates event rows.
    pub fn decodeOwnedFrame(self: *ProgressiveDecoder, raw_json: []u8) !ProgressiveFrame {
        errdefer self.allocator.free(raw_json);
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const fields = try parseObjectFields(arena.allocator(), raw_json);
        const frame_type_raw = requiredField(fields, "FrameType") orelse return error.MalformedKustoResponse;
        const frame_type = try decodeStringTemp(arena.allocator(), frame_type_raw);
        if (self.saw_completion) return error.MalformedKustoResponse;
        if (!self.saw_header and !std.mem.eql(u8, frame_type, "DataSetHeader"))
            return error.MalformedKustoResponse;

        var payload: ProgressiveFrame.Payload = undefined;
        if (std.mem.eql(u8, frame_type, "DataSetHeader")) {
            if (self.saw_header) return error.MalformedKustoResponse;
            payload = .{ .data_set_header = try self.decodeHeader(fields) };
        } else if (std.mem.eql(u8, frame_type, "DataTable")) {
            payload = .{ .data_table = try self.decodeDataTable(fields) };
        } else if (std.mem.eql(u8, frame_type, "TableHeader")) {
            payload = .{ .table_header = try self.decodeTableHeader(fields) };
        } else if (std.mem.eql(u8, frame_type, "TableFragment")) {
            payload = .{ .table_fragment = try self.decodeTableFragment(fields) };
        } else if (std.mem.eql(u8, frame_type, "TableProgress")) {
            payload = .{ .table_progress = try self.decodeTableProgress(fields) };
        } else if (std.mem.eql(u8, frame_type, "TableCompletion")) {
            payload = .{ .table_completion = try self.decodeTableCompletion(fields) };
        } else if (std.mem.eql(u8, frame_type, "DataSetCompletion")) {
            payload = .{ .data_set_completion = try self.decodeDataSetCompletion(fields) };
        } else {
            payload = .{ .unknown = .{
                .frame_type = try self.allocator.dupe(u8, frame_type),
            } };
        }
        const frame = ProgressiveFrame{
            .index = self.next_index,
            .raw_json = raw_json,
            .payload = payload,
        };
        self.next_index += 1;
        return frame;
    }

    /// Verifies that the top-level array ended after a header and completion.
    pub fn finish(self: *const ProgressiveDecoder) !void {
        if (!self.saw_header or !self.saw_completion)
            return error.MalformedKustoResponse;
    }

    fn decodeHeader(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveDataSetHeader {
        const version_raw = requiredField(fields, "Version") orelse return error.MalformedKustoResponse;
        const progressive_raw = requiredField(fields, "IsProgressive") orelse return error.MalformedKustoResponse;
        const version = try decodeStringOwned(self.allocator, version_raw);
        errdefer self.allocator.free(version);
        var header = ProgressiveDataSetHeader{
            .version = version,
            .is_progressive = try decodeBool(progressive_raw),
        };
        errdefer header.deinit(self.allocator);
        if (field(fields, "IsFragmented")) |raw|
            header.is_fragmented = try decodeBool(raw);
        if (field(fields, "ErrorReportingPlacement")) |raw|
            header.error_reporting_placement = try decodeStringOwned(self.allocator, raw);
        self.saw_header = true;
        self.is_progressive = header.is_progressive;
        self.is_fragmented = header.is_fragmented orelse false;
        return header;
    }

    fn decodeDataTable(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveTableBatch {
        const id = try parseRequiredId(fields, "TableId");
        if (self.table_indexes.contains(id)) return error.MalformedKustoResponse;
        var failure: ?kusto_common.KustoError = null;
        errdefer if (failure) |*value| value.deinit();
        var builder = try parseDataTable(
            self.allocator,
            fields,
            id,
            self.options,
            self.operation,
            &failure,
        );
        errdefer builder.deinit(self.allocator);
        var table = try builder.take(self.allocator);
        errdefer table.deinit(self.allocator);
        try self.addTableState(&table, @intCast(table.rows.len), true);
        const owned_failure = failure;
        failure = null;
        return .{ .action = .replace, .table = table, .failure = owned_failure };
    }

    fn decodeTableHeader(self: *ProgressiveDecoder, fields: []const Field) !KustoResultTable {
        if (!self.allowsTableFrames()) return error.MalformedKustoResponse;
        const id = try parseRequiredId(fields, "TableId");
        if (self.table_indexes.contains(id)) return error.MalformedKustoResponse;
        var builder = try parseTableHeader(self.allocator, fields, id);
        errdefer builder.deinit(self.allocator);
        var table = try builder.take(self.allocator);
        errdefer table.deinit(self.allocator);
        try self.addTableState(&table, 0, false);
        return table;
    }

    fn decodeTableFragment(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveTableBatch {
        if (!self.allowsTableFrames()) return error.MalformedKustoResponse;
        const id = try parseRequiredId(fields, "TableId");
        const table_index = self.table_indexes.get(id) orelse return error.MalformedKustoResponse;
        const state = &self.tables.items[table_index];
        if (state.completed) return error.MalformedKustoResponse;
        const state_table = if (state.table) |*table| table else return error.MalformedKustoResponse;
        if (field(fields, "FieldCount")) |raw| {
            const field_count = try decodeNonNegativeI64(raw);
            if (field_count != state_table.columns.len) return error.MalformedKustoResponse;
        }
        const type_raw = requiredField(fields, "TableFragmentType") orelse return error.MalformedKustoResponse;
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const type_name = try decodeStringTemp(arena.allocator(), type_raw);
        const action: ProgressiveTableAction = if (std.mem.eql(u8, type_name, "DataAppend"))
            .append
        else if (std.mem.eql(u8, type_name, "DataReplace"))
            .replace
        else
            return error.UnsupportedTableFragmentType;
        const rows_raw = requiredField(fields, "Rows") orelse return error.MalformedKustoResponse;
        var batch_table = try cloneTableMetadata(self.allocator, state_table, false);
        errdefer batch_table.deinit(self.allocator);
        var failure: ?kusto_common.KustoError = null;
        errdefer if (failure) |*value| value.deinit();
        const rows = try parseRows(
            self.allocator,
            rows_raw,
            batch_table.columns,
            self.options,
            self.operation,
            &failure,
        );
        batch_table.rows = rows;
        batch_table.reported_row_count = @intCast(rows.len);
        const batch_count: i64 = @intCast(rows.len);
        state.row_count = switch (action) {
            .append => std.math.add(i64, state.row_count, batch_count) catch return error.MalformedKustoResponse,
            .replace => batch_count,
        };
        const owned_failure = failure;
        failure = null;
        return .{ .action = action, .table = batch_table, .failure = owned_failure };
    }

    fn decodeTableProgress(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveTableProgress {
        if (!self.allowsTableFrames()) return error.MalformedKustoResponse;
        const id = try parseRequiredId(fields, "TableId");
        const table_index = self.table_indexes.get(id) orelse return error.MalformedKustoResponse;
        const state = &self.tables.items[table_index];
        if (state.completed) return error.MalformedKustoResponse;
        const progress_raw = requiredField(fields, "TableProgress") orelse return error.MalformedKustoResponse;
        const progress = try decodeFiniteNumber(progress_raw);
        if (progress < 0 or progress > 100) return error.MalformedKustoResponse;
        const table = if (state.table) |*value| value else return error.MalformedKustoResponse;
        table.progress = progress;
        return .{ .table_id = id, .progress = progress };
    }

    fn decodeTableCompletion(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveTableCompletion {
        const id = try parseRequiredId(fields, "TableId");
        const table_index = self.table_indexes.get(id) orelse return error.MalformedKustoResponse;
        const state = &self.tables.items[table_index];
        if (state.completed) return error.MalformedKustoResponse;
        const row_count_raw = requiredField(fields, "RowCount") orelse return error.MalformedKustoResponse;
        const row_count = try decodeNonNegativeI64(row_count_raw);
        if (row_count != state.row_count) return error.MalformedKustoResponse;
        const has_errors = if (field(fields, "HasErrors")) |raw| try decodeBool(raw) else false;
        const cancelled = if (field(fields, "Cancelled")) |raw| try decodeBool(raw) else false;
        const failure = try completionFailure(
            self.allocator,
            self.operation,
            .table_completion,
            field(fields, "OneApiErrors"),
            has_errors,
            cancelled,
        );
        state.completed = true;
        if (state.table) |*table| {
            table.deinit(self.allocator);
            state.table = null;
        }
        return .{
            .table_id = id,
            .row_count = row_count,
            .has_errors = has_errors,
            .cancelled = cancelled,
            .failure = failure,
        };
    }

    fn decodeDataSetCompletion(self: *ProgressiveDecoder, fields: []const Field) !ProgressiveDataSetCompletion {
        for (self.tables.items) |state| {
            if (!state.completed) return error.MalformedKustoResponse;
        }
        const has_errors_raw = requiredField(fields, "HasErrors") orelse return error.MalformedKustoResponse;
        const cancelled_raw = requiredField(fields, "Cancelled") orelse return error.MalformedKustoResponse;
        const has_errors = try decodeBool(has_errors_raw);
        const cancelled = try decodeBool(cancelled_raw);
        const failure = try completionFailure(
            self.allocator,
            self.operation,
            .dataset_completion,
            field(fields, "OneApiErrors"),
            has_errors,
            cancelled,
        );
        self.saw_completion = true;
        return .{
            .has_errors = has_errors,
            .cancelled = cancelled,
            .failure = failure,
        };
    }

    fn addTableState(
        self: *ProgressiveDecoder,
        source: *const KustoResultTable,
        row_count: i64,
        completed: bool,
    ) !void {
        const id = source.id orelse return error.MalformedKustoResponse;
        if (self.tables.items.len >= self.max_table_count)
            return error.KustoProgressiveTableLimitExceeded;
        var table: ?KustoResultTable = if (completed)
            null
        else
            try cloneTableMetadata(self.allocator, source, false);
        errdefer if (table) |*value| value.deinit(self.allocator);
        if (table) |*value| {
            value.completed = false;
            value.reported_row_count = row_count;
        }
        try self.table_indexes.put(id, self.tables.items.len);
        errdefer {
            _ = self.table_indexes.remove(id);
        }
        try self.tables.append(self.allocator, .{
            .table = table,
            .row_count = row_count,
            .completed = completed,
        });
        table = null;
    }

    fn allowsTableFrames(self: *const ProgressiveDecoder) bool {
        return self.is_progressive or self.is_fragmented;
    }
};

pub const DecodeOutcome = struct {
    dataset: KustoResponseDataSet,
    failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *DecodeOutcome, allocator: std.mem.Allocator) void {
        self.dataset.deinit(allocator);
        if (self.failure) |*failure| failure.deinit();
        self.* = undefined;
    }
};

const Field = struct {
    name: []const u8,
    value: []const u8,
};

const JsonTokenKind = enum {
    object_begin,
    object_end,
    array_begin,
    array_end,
    string,
    number,
    true_lit,
    false_lit,
    null_lit,
};

const TableBuilder = struct {
    table: KustoResultTable,
    rows: std.ArrayList(KustoResultRow) = .empty,
    active: bool = true,

    fn deinit(self: *TableBuilder, allocator: std.mem.Allocator) void {
        if (!self.active) return;
        deinitRows(self.rows.items, allocator);
        self.rows.deinit(allocator);
        deinitTableMetadata(&self.table, allocator);
        self.active = false;
    }

    fn take(self: *TableBuilder, allocator: std.mem.Allocator) !KustoResultTable {
        self.table.rows = try self.rows.toOwnedSlice(allocator);
        self.rows = .empty;
        self.active = false;
        return self.table;
    }
};

pub fn decode(
    allocator: std.mem.Allocator,
    body: []const u8,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
) !DecodeOutcome {
    var dataset = KustoResponseDataSet{
        .protocol = .v1,
        .tables = &.{},
        .raw_response = try allocator.dupe(u8, body),
        .frames = &.{},
        .v1_exceptions = &.{},
    };
    errdefer dataset.deinit(allocator);
    var failure: ?kusto_common.KustoError = null;
    errdefer if (failure) |*value| value.deinit();
    if (!try std.json.validate(allocator, dataset.raw_response))
        return error.MalformedKustoResponse;

    var deserializer = serde.json.Deserializer.init(dataset.raw_response);
    const root_token = deserializer.scanner.next() catch return error.MalformedKustoResponse;
    switch (root_token) {
        .object_begin => try parseV1(allocator, &dataset, options, operation, &failure),
        .array_begin => try parseV2(allocator, &dataset, options, operation, &failure),
        else => return error.MalformedKustoResponse,
    }

    if (failure == null) {
        if (try queryStatusFailure(allocator, &dataset, operation)) |status_failure|
            failure = status_failure;
    }

    return .{ .dataset = dataset, .failure = failure };
}

fn parseV1(
    allocator: std.mem.Allocator,
    dataset: *KustoResponseDataSet,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const fields = try parseObjectFields(arena.allocator(), dataset.raw_response);
    const tables_raw = requiredField(fields, "Tables") orelse return error.MalformedKustoResponse;

    var exceptions = std.ArrayList([]u8).empty;
    errdefer {
        for (exceptions.items) |value| allocator.free(value);
        exceptions.deinit(allocator);
    }
    if (field(fields, "Exceptions")) |raw|
        try collectExceptions(allocator, raw, &exceptions);

    dataset.tables = try parseV1Tables(allocator, tables_raw, options, &exceptions);
    dataset.v1_exceptions = try exceptions.toOwnedSlice(allocator);
    exceptions = .empty;
    dataset.frames = try allocator.alloc(KustoFrame, 1);
    dataset.frames[0] = .{ .v1_root = .{
        .index = 0,
        .raw_json = dataset.raw_response,
    } };
    dataset.protocol = .v1;
    dataset.completed = true;

    const has_table_of_contents = try applyV1TableOfContents(allocator, dataset);
    if (!has_table_of_contents)
        applyShortV1TableKinds(dataset);
    if (dataset.v1_exceptions.len > 0) {
        var in_band = kusto_common.errors.inBandFailure(
            allocator,
            operation,
            .v1_exception,
            false,
        );
        errdefer in_band.deinit();
        in_band.detail.message = try allocator.dupe(u8, dataset.v1_exceptions[0]);
        rememberFailure(failure, in_band);
    }
}

fn parseV1Tables(
    allocator: std.mem.Allocator,
    raw: []const u8,
    options: DecodeOptions,
    exceptions: *std.ArrayList([]u8),
) ![]KustoResultTable {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var tables = std.ArrayList(KustoResultTable).empty;
    errdefer {
        for (tables.items) |*table| table.deinit(allocator);
        tables.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const table_raw = try captureValue(scanner, raw);
            var table = try parseV1Table(allocator, table_raw, options, exceptions);
            errdefer table.deinit(allocator);
            table.ordinal = @intCast(tables.items.len);
            try tables.append(allocator, table);
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    return tables.toOwnedSlice(allocator);
}

fn parseV1Table(
    allocator: std.mem.Allocator,
    raw: []const u8,
    options: DecodeOptions,
    exceptions: *std.ArrayList([]u8),
) !KustoResultTable {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const fields = try parseObjectFields(arena.allocator(), raw);
    const name_raw = requiredField(fields, "TableName") orelse return error.MalformedKustoResponse;
    const columns_raw = requiredField(fields, "Columns") orelse return error.MalformedKustoResponse;
    const rows_raw = requiredField(fields, "Rows") orelse return error.MalformedKustoResponse;

    const name = try decodeStringOwned(allocator, name_raw);
    errdefer allocator.free(name);
    const kind = if (field(fields, "TableKind")) |kind_raw|
        try decodeStringOwned(allocator, kind_raw)
    else
        null;
    errdefer if (kind) |value| allocator.free(value);
    const columns = try parseColumns(allocator, columns_raw);
    errdefer {
        for (columns) |*column| column.deinit(allocator);
        allocator.free(columns);
    }
    const rows = try parseV1Rows(allocator, rows_raw, columns, options, exceptions);
    return .{
        .name = name,
        .kind = kind,
        .known_kind = normalizeTableKind(kind orelse name),
        .columns = columns,
        .rows = rows,
        .completed = true,
    };
}

fn parseV1Rows(
    allocator: std.mem.Allocator,
    raw: []const u8,
    columns: []const KustoResultColumn,
    options: DecodeOptions,
    exceptions: *std.ArrayList([]u8),
) ![]KustoResultRow {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var rows = std.ArrayList(KustoResultRow).empty;
    errdefer {
        deinitRows(rows.items, allocator);
        rows.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const row_raw = try captureValue(scanner, raw);
            const token = try singleToken(row_raw);
            switch (token) {
                .array_begin => {
                    var row = try parseRow(allocator, row_raw, columns, options);
                    errdefer row.deinit(allocator);
                    try rows.append(allocator, row);
                },
                .object_begin => try collectV1RowExceptions(allocator, row_raw, exceptions),
                else => return error.MalformedKustoResponse,
            }
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    return rows.toOwnedSlice(allocator);
}

fn collectV1RowExceptions(
    allocator: std.mem.Allocator,
    raw: []const u8,
    exceptions: *std.ArrayList([]u8),
) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const fields = try parseObjectFields(arena.allocator(), raw);
    const errors_raw = requiredField(fields, "Exceptions") orelse return error.MalformedKustoResponse;
    try collectExceptions(allocator, errors_raw, exceptions);
}

fn collectExceptions(
    allocator: std.mem.Allocator,
    raw: []const u8,
    exceptions: *std.ArrayList([]u8),
) !void {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const item_raw = try captureValue(scanner, raw);
            const item = try decodeStringOwned(allocator, item_raw);
            errdefer allocator.free(item);
            try exceptions.append(allocator, item);
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
}

fn applyV1TableOfContents(
    allocator: std.mem.Allocator,
    dataset: *KustoResponseDataSet,
) !bool {
    var found = false;
    for (dataset.tables, 0..) |*toc, toc_index| {
        if (!isV1TableOfContents(dataset.tables, toc_index))
            continue;
        found = true;
        toc.known_kind = .table_of_contents;
        for (toc.rows) |*row| {
            const ordinal_value = row.getByName("Ordinal") orelse continue;
            const ordinal = valueAsI64(ordinal_value.*) orelse continue;
            if (ordinal < 0) continue;
            const target_index = std.math.cast(usize, ordinal) orelse continue;
            if (target_index >= toc_index) continue;
            const target = &dataset.tables[target_index];
            target.ordinal = ordinal;

            if (row.getByName("Kind")) |value| {
                if (value.lexical()) |kind| {
                    try replaceOptionalString(allocator, &target.kind, kind);
                    target.known_kind = normalizeTableKind(kind);
                }
            }
            if (row.getByName("Name")) |value| {
                if (value.lexical()) |name|
                    try replaceOptionalString(allocator, &target.toc_name, name);
            }
            if (row.getByName("PrettyName")) |value| {
                if (value.lexical()) |pretty_name|
                    try replaceOptionalString(allocator, &target.pretty_name, pretty_name);
            }
            if (row.getByName("Id")) |value| {
                if (try valueTextOwned(allocator, value.*)) |id_text| {
                    if (target.toc_id) |old| allocator.free(old);
                    target.toc_id = id_text;
                }
                if (valueAsI64(value.*)) |id| target.id = id;
            }
        }
    }
    return found;
}

fn applyShortV1TableKinds(dataset: *KustoResponseDataSet) void {
    if (dataset.tables.len == 0 or dataset.tables.len > 2) return;
    if (dataset.tables[0].known_kind == .unknown)
        dataset.tables[0].known_kind = .primary_result;
    if (dataset.tables[0].id == null)
        dataset.tables[0].id = 0;
    if (dataset.tables.len == 2) {
        if (dataset.tables[1].known_kind == .unknown)
            dataset.tables[1].known_kind = .query_properties;
        if (dataset.tables[1].id == null)
            dataset.tables[1].id = 1;
    }
}

fn isV1TableOfContents(tables: []const KustoResultTable, index: usize) bool {
    const table = &tables[index];
    if (table.known_kind == .table_of_contents or
        std.ascii.eqlIgnoreCase(table.name, "TableOfContents"))
        return true;
    if (index != tables.len - 1 or table.columns.len < v1_toc_column_names.len)
        return false;
    for (v1_toc_column_names) |expected| {
        var found = false;
        for (table.columns) |column| {
            if (std.ascii.eqlIgnoreCase(column.name, expected)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

const v1_toc_column_names = [_][]const u8{
    "Ordinal",
    "Kind",
    "Name",
    "Id",
    "PrettyName",
};

fn parseV2(
    allocator: std.mem.Allocator,
    dataset: *KustoResponseDataSet,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !void {
    var deserializer = serde.json.Deserializer.init(dataset.raw_response);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var builders = std.ArrayList(TableBuilder).empty;
    errdefer deinitBuilders(&builders, allocator);
    var frames = std.ArrayList(KustoFrame).empty;
    errdefer deinitFrames(&frames, allocator);
    var table_indexes = std.AutoHashMap(i64, usize).init(allocator);
    defer table_indexes.deinit();

    var saw_header = false;
    var saw_completion = false;
    var frame_index: usize = 0;
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse)
        return error.MalformedKustoResponse;

    while (true) {
        const frame_raw = try captureValue(scanner, dataset.raw_response);
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const fields = try parseObjectFields(arena.allocator(), frame_raw);
        const frame_type_raw = requiredField(fields, "FrameType") orelse return error.MalformedKustoResponse;
        const frame_type = try decodeStringTemp(arena.allocator(), frame_type_raw);

        var frame = try makeFrame(allocator, frame_index, frame_type, frame_raw);
        frames.append(allocator, frame) catch |err| {
            frame.deinit(allocator);
            return err;
        };

        if (saw_completion) return error.MalformedKustoResponse;
        if (!saw_header and !std.mem.eql(u8, frame_type, "DataSetHeader"))
            return error.MalformedKustoResponse;

        if (std.mem.eql(u8, frame_type, "DataSetHeader")) {
            if (saw_header) return error.MalformedKustoResponse;
            try parseDataSetHeader(allocator, dataset, fields);
            saw_header = true;
        } else if (std.mem.eql(u8, frame_type, "DataTable")) {
            const id = try parseRequiredId(fields, "TableId");
            if (table_indexes.get(id) != null) return error.MalformedKustoResponse;
            var builder = try parseDataTable(allocator, fields, id, options, operation, failure);
            errdefer builder.deinit(allocator);
            builder.table.ordinal = @intCast(builders.items.len);
            try table_indexes.put(id, builders.items.len);
            try builders.append(allocator, builder);
        } else if (std.mem.eql(u8, frame_type, "TableHeader")) {
            if (!allowsTableFrames(dataset)) return error.MalformedKustoResponse;
            const id = try parseRequiredId(fields, "TableId");
            if (table_indexes.get(id) != null) return error.MalformedKustoResponse;
            var builder = try parseTableHeader(allocator, fields, id);
            errdefer builder.deinit(allocator);
            builder.table.ordinal = @intCast(builders.items.len);
            try table_indexes.put(id, builders.items.len);
            try builders.append(allocator, builder);
        } else if (std.mem.eql(u8, frame_type, "TableFragment")) {
            if (!allowsTableFrames(dataset)) return error.MalformedKustoResponse;
            const id = try parseRequiredId(fields, "TableId");
            const index = table_indexes.get(id) orelse return error.MalformedKustoResponse;
            try applyTableFragment(
                allocator,
                &builders.items[index],
                fields,
                options,
                operation,
                failure,
            );
        } else if (std.mem.eql(u8, frame_type, "TableProgress")) {
            if (!allowsTableFrames(dataset)) return error.MalformedKustoResponse;
            const id = try parseRequiredId(fields, "TableId");
            const index = table_indexes.get(id) orelse return error.MalformedKustoResponse;
            try applyTableProgress(&builders.items[index], fields);
        } else if (std.mem.eql(u8, frame_type, "TableCompletion")) {
            const id = try parseRequiredId(fields, "TableId");
            const index = table_indexes.get(id) orelse return error.MalformedKustoResponse;
            try applyTableCompletion(allocator, &builders.items[index], fields, operation, failure);
        } else if (std.mem.eql(u8, frame_type, "DataSetCompletion")) {
            if (saw_completion) return error.MalformedKustoResponse;
            try applyDataSetCompletion(allocator, dataset, builders.items, fields, operation, failure);
            saw_completion = true;
        }

        switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
            .end => break,
            .more => frame_index += 1,
        }
    }
    try ensureScannerComplete(scanner, dataset.raw_response);
    if (!saw_header or !saw_completion) return error.MalformedKustoResponse;

    dataset.tables = try finishBuilders(allocator, &builders);
    dataset.frames = try frames.toOwnedSlice(allocator);
    frames = .empty;
    dataset.v1_exceptions = try allocator.alloc([]u8, 0);
    dataset.protocol = .v2;
}

fn allowsTableFrames(dataset: *const KustoResponseDataSet) bool {
    return dataset.is_progressive or dataset.is_fragmented == true;
}

fn makeFrame(
    allocator: std.mem.Allocator,
    index: usize,
    frame_type: []const u8,
    raw_json: []const u8,
) !KustoFrame {
    const payload = KustoFramePayload{ .index = index, .raw_json = raw_json };
    if (std.mem.eql(u8, frame_type, "DataSetHeader"))
        return .{ .data_set_header = payload };
    if (std.mem.eql(u8, frame_type, "DataSetCompletion"))
        return .{ .data_set_completion = payload };
    if (std.mem.eql(u8, frame_type, "DataTable"))
        return .{ .data_table = payload };
    if (std.mem.eql(u8, frame_type, "TableHeader"))
        return .{ .table_header = payload };
    if (std.mem.eql(u8, frame_type, "TableFragment"))
        return .{ .table_fragment = payload };
    if (std.mem.eql(u8, frame_type, "TableProgress"))
        return .{ .table_progress = payload };
    if (std.mem.eql(u8, frame_type, "TableCompletion"))
        return .{ .table_completion = payload };
    return .{ .unknown = .{
        .index = index,
        .frame_type = try allocator.dupe(u8, frame_type),
        .raw_json = raw_json,
    } };
}

fn parseDataSetHeader(
    allocator: std.mem.Allocator,
    dataset: *KustoResponseDataSet,
    fields: []const Field,
) !void {
    const version_raw = requiredField(fields, "Version") orelse return error.MalformedKustoResponse;
    const progressive_raw = requiredField(fields, "IsProgressive") orelse return error.MalformedKustoResponse;
    dataset.version = try decodeStringOwned(allocator, version_raw);
    dataset.is_progressive = try decodeBool(progressive_raw);
    if (field(fields, "IsFragmented")) |raw|
        dataset.is_fragmented = try decodeBool(raw);
    if (field(fields, "ErrorReportingPlacement")) |raw|
        dataset.error_reporting_placement = try decodeStringOwned(allocator, raw);
}

fn parseDataTable(
    allocator: std.mem.Allocator,
    fields: []const Field,
    id: i64,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !TableBuilder {
    var builder = TableBuilder{ .table = try parseTableMetadata(allocator, fields, id, true) };
    errdefer builder.deinit(allocator);
    const rows_raw = requiredField(fields, "Rows") orelse return error.MalformedKustoResponse;
    const rows = try parseRows(
        allocator,
        rows_raw,
        builder.table.columns,
        options,
        operation,
        failure,
    );
    try appendOwnedRows(allocator, &builder.rows, rows);
    builder.table.reported_row_count = @intCast(builder.rows.items.len);
    return builder;
}

fn parseTableHeader(
    allocator: std.mem.Allocator,
    fields: []const Field,
    id: i64,
) !TableBuilder {
    return .{ .table = try parseTableMetadata(allocator, fields, id, false) };
}

fn parseTableMetadata(
    allocator: std.mem.Allocator,
    fields: []const Field,
    id: i64,
    completed: bool,
) !KustoResultTable {
    const name_raw = requiredField(fields, "TableName") orelse return error.MalformedKustoResponse;
    const kind_raw = requiredField(fields, "TableKind") orelse return error.MalformedKustoResponse;
    const columns_raw = requiredField(fields, "Columns") orelse return error.MalformedKustoResponse;
    const name = try decodeStringOwned(allocator, name_raw);
    errdefer allocator.free(name);
    const kind = try decodeStringOwned(allocator, kind_raw);
    errdefer allocator.free(kind);
    const columns = try parseColumns(allocator, columns_raw);
    return .{
        .id = id,
        .name = name,
        .kind = kind,
        .known_kind = normalizeTableKind(kind),
        .columns = columns,
        .rows = &.{},
        .completed = completed,
    };
}

fn applyTableFragment(
    allocator: std.mem.Allocator,
    builder: *TableBuilder,
    fields: []const Field,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !void {
    if (builder.table.completed) return error.MalformedKustoResponse;
    if (field(fields, "FieldCount")) |raw| {
        const field_count = try decodeNonNegativeI64(raw);
        if (field_count != builder.table.columns.len) return error.MalformedKustoResponse;
    }
    const type_raw = requiredField(fields, "TableFragmentType") orelse return error.MalformedKustoResponse;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const fragment_type = try decodeStringTemp(arena.allocator(), type_raw);
    const is_append = std.mem.eql(u8, fragment_type, "DataAppend");
    const is_replace = std.mem.eql(u8, fragment_type, "DataReplace");
    if (!is_append and !is_replace) return error.UnsupportedTableFragmentType;
    const rows_raw = requiredField(fields, "Rows") orelse return error.MalformedKustoResponse;
    const rows = try parseRows(
        allocator,
        rows_raw,
        builder.table.columns,
        options,
        operation,
        failure,
    );
    if (is_append) {
        try appendOwnedRows(allocator, &builder.rows, rows);
    } else {
        deinitRows(builder.rows.items, allocator);
        builder.rows.clearRetainingCapacity();
        try appendOwnedRows(allocator, &builder.rows, rows);
    }
}

fn applyTableProgress(builder: *TableBuilder, fields: []const Field) !void {
    if (builder.table.completed) return error.MalformedKustoResponse;
    const progress_raw = requiredField(fields, "TableProgress") orelse return error.MalformedKustoResponse;
    const progress = try decodeFiniteNumber(progress_raw);
    if (progress < 0 or progress > 100) return error.MalformedKustoResponse;
    builder.table.progress = progress;
}

fn applyTableCompletion(
    allocator: std.mem.Allocator,
    builder: *TableBuilder,
    fields: []const Field,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !void {
    if (builder.table.completed) return error.MalformedKustoResponse;
    const row_count_raw = requiredField(fields, "RowCount") orelse return error.MalformedKustoResponse;
    const row_count = try decodeNonNegativeI64(row_count_raw);
    if (row_count != builder.rows.items.len) return error.MalformedKustoResponse;
    builder.table.reported_row_count = row_count;
    builder.table.completed = true;

    const has_errors = if (field(fields, "HasErrors")) |raw| try decodeBool(raw) else false;
    const cancelled = if (field(fields, "Cancelled")) |raw| try decodeBool(raw) else false;
    if (try completionFailure(
        allocator,
        operation,
        .table_completion,
        field(fields, "OneApiErrors"),
        has_errors,
        cancelled,
    )) |in_band|
        rememberFailure(failure, in_band);
}

fn applyDataSetCompletion(
    allocator: std.mem.Allocator,
    dataset: *KustoResponseDataSet,
    builders: []const TableBuilder,
    fields: []const Field,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) !void {
    for (builders) |builder| {
        if (!builder.table.completed) return error.MalformedKustoResponse;
    }
    const has_errors_raw = requiredField(fields, "HasErrors") orelse return error.MalformedKustoResponse;
    const cancelled_raw = requiredField(fields, "Cancelled") orelse return error.MalformedKustoResponse;
    const has_errors = try decodeBool(has_errors_raw);
    const cancelled = try decodeBool(cancelled_raw);
    dataset.completed = true;
    dataset.has_errors = has_errors;
    dataset.cancelled = cancelled;
    if (try completionFailure(
        allocator,
        operation,
        .dataset_completion,
        field(fields, "OneApiErrors"),
        has_errors,
        cancelled,
    )) |in_band|
        rememberFailure(failure, in_band);
}

fn completionFailure(
    allocator: std.mem.Allocator,
    operation: kusto_common.KustoOperation,
    source: kusto_common.KustoErrorSource,
    errors_raw: ?[]const u8,
    has_errors: bool,
    cancelled: bool,
) !?kusto_common.KustoError {
    if (errors_raw) |raw| {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const errors = serde.json.fromSlice(
            []kusto_common.errors.OneApiEnvelope,
            arena.allocator(),
            raw,
        ) catch |err| {
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return error.MalformedKustoResponse;
        };
        if (errors.len > 0)
            return try kusto_common.errors.fromOneApiEnvelope(
                allocator,
                operation,
                source,
                errors[0],
                cancelled,
            );
    }
    if (has_errors or cancelled)
        return kusto_common.errors.inBandFailure(allocator, operation, source, cancelled);
    return null;
}

fn parseColumns(allocator: std.mem.Allocator, raw: []const u8) ![]KustoResultColumn {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var columns = std.ArrayList(KustoResultColumn).empty;
    errdefer {
        for (columns.items) |*column| column.deinit(allocator);
        columns.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const column_raw = try captureValue(scanner, raw);
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const fields = try parseObjectFields(arena.allocator(), column_raw);
            const name_raw = requiredField(fields, "ColumnName") orelse return error.MalformedKustoResponse;
            const column_type_raw = field(fields, "ColumnType");
            const type_raw = column_type_raw orelse field(fields, "DataType");
            // V1 DataType is advisory: service status payloads can contain a
            // structured value even when DataType says String.
            const has_declared_type = column_type_raw != null;
            const name = try decodeStringOwned(allocator, name_raw);
            const column_type = (if (type_raw) |value|
                decodeStringOwned(allocator, value)
            else
                allocator.dupe(u8, "string")) catch |err| {
                allocator.free(name);
                return err;
            };
            var column = KustoResultColumn{
                .name = name,
                .column_type = column_type,
                .scalar_kind = normalizeScalarKind(column_type),
                .has_declared_type = has_declared_type,
            };
            columns.append(allocator, column) catch |err| {
                column.deinit(allocator);
                return err;
            };
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    return columns.toOwnedSlice(allocator);
}

fn parseRows(
    allocator: std.mem.Allocator,
    raw: []const u8,
    columns: []const KustoResultColumn,
    options: DecodeOptions,
    operation: kusto_common.KustoOperation,
    failure: *?kusto_common.KustoError,
) ![]KustoResultRow {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var rows = std.ArrayList(KustoResultRow).empty;
    errdefer {
        deinitRows(rows.items, allocator);
        rows.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const row_raw = try captureValue(scanner, raw);
            switch (try singleToken(row_raw)) {
                .array_begin => {
                    var row = try parseRow(allocator, row_raw, columns, options);
                    errdefer row.deinit(allocator);
                    try rows.append(allocator, row);
                },
                .object_begin => {
                    const in_band = try rowEmbeddedOneApiFailure(
                        allocator,
                        operation,
                        row_raw,
                    );
                    rememberFailure(failure, in_band);
                },
                else => return error.MalformedKustoResponse,
            }
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    return rows.toOwnedSlice(allocator);
}

fn rowEmbeddedOneApiFailure(
    allocator: std.mem.Allocator,
    operation: kusto_common.KustoOperation,
    raw: []const u8,
) !kusto_common.KustoError {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const fields = try parseObjectFields(arena.allocator(), raw);
    if (fields.len != 1) return error.MalformedKustoResponse;
    const errors_raw = requiredField(fields, "OneApiErrors") orelse return error.MalformedKustoResponse;
    const errors = serde.json.fromSlice(
        []kusto_common.errors.OneApiEnvelope,
        arena.allocator(),
        errors_raw,
    ) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.MalformedKustoResponse;
    };
    if (errors.len == 0 or errors[0].@"error" == null)
        return error.MalformedKustoResponse;
    return kusto_common.errors.fromOneApiEnvelope(
        allocator,
        operation,
        .data_table,
        errors[0],
        false,
    );
}

fn parseRow(
    allocator: std.mem.Allocator,
    raw: []const u8,
    columns: []const KustoResultColumn,
    options: DecodeOptions,
) !KustoResultRow {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .array_begin)
        return error.MalformedKustoResponse;

    var values = std.ArrayList(KustoValue).empty;
    errdefer {
        for (values.items) |*value| value.deinit(allocator);
        values.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const cell_raw = try captureValue(scanner, raw);
            const column = if (values.items.len < columns.len)
                &columns[values.items.len]
            else
                null;
            const scalar_kind = if (column) |item| item.scalar_kind else .unknown;
            const allow_untyped_fallback = if (column) |item| !item.has_declared_type else false;
            var value = try decodeValue(allocator, scalar_kind, cell_raw, allow_untyped_fallback);
            errdefer value.deinit(allocator);
            try values.append(allocator, value);
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    if (!options.allow_varying_row_widths and values.items.len != columns.len)
        return error.MalformedKustoResponse;
    return .{
        .values = try values.toOwnedSlice(allocator),
        .columns = columns,
    };
}

fn decodeValue(
    allocator: std.mem.Allocator,
    scalar_kind: KustoScalarKind,
    raw: []const u8,
    allow_untyped_fallback: bool,
) !KustoValue {
    const token = try singleToken(raw);
    if (token == .null_lit) return .null;
    return switch (scalar_kind) {
        .string => switch (token) {
            .string => .{ .string = try decodeStringOwned(allocator, raw) },
            else => if (allow_untyped_fallback)
                .{ .unknown = try allocator.dupe(u8, raw) }
            else
                error.MalformedKustoResponse,
        },
        .bool => .{ .bool = try decodeKustoBool(raw) },
        .int => .{ .int = try decodeInteger(i32, raw) },
        .long => .{ .long = try decodeInteger(i64, raw) },
        .real => switch (token) {
            .number => {
                const value = std.fmt.parseFloat(f64, raw) catch return .{
                    .real_raw = try allocator.dupe(u8, raw),
                };
                if (std.math.isFinite(value)) return .{ .real = value };
                return .{ .real_raw = try allocator.dupe(u8, raw) };
            },
            .string => .{ .real_raw = try allocator.dupe(u8, raw) },
            else => error.MalformedKustoResponse,
        },
        .decimal => switch (token) {
            .string => .{ .decimal = try decodeStringOwned(allocator, raw) },
            .number => .{ .decimal = try allocator.dupe(u8, raw) },
            else => error.MalformedKustoResponse,
        },
        .datetime => .{ .datetime = try decodeStringOwned(allocator, raw) },
        .timespan => .{ .timespan = try decodeStringOwned(allocator, raw) },
        .guid => .{ .guid = try decodeStringOwned(allocator, raw) },
        .dynamic => .{ .dynamic = try allocator.dupe(u8, raw) },
        .unknown => .{ .unknown = try allocator.dupe(u8, raw) },
    };
}

fn appendOwnedRows(
    allocator: std.mem.Allocator,
    destination: *std.ArrayList(KustoResultRow),
    rows: []KustoResultRow,
) !void {
    errdefer {
        deinitRows(rows, allocator);
        allocator.free(rows);
    }
    try destination.appendSlice(allocator, rows);
    allocator.free(rows);
}

fn finishBuilders(
    allocator: std.mem.Allocator,
    builders: *std.ArrayList(TableBuilder),
) ![]KustoResultTable {
    var tables = std.ArrayList(KustoResultTable).empty;
    errdefer {
        for (tables.items) |*table| table.deinit(allocator);
        tables.deinit(allocator);
    }
    for (builders.items) |*builder| {
        var table = try builder.take(allocator);
        tables.append(allocator, table) catch |err| {
            table.deinit(allocator);
            return err;
        };
    }
    builders.deinit(allocator);
    builders.* = .empty;
    return tables.toOwnedSlice(allocator);
}

fn deinitBuilders(builders: *std.ArrayList(TableBuilder), allocator: std.mem.Allocator) void {
    for (builders.items) |*builder| builder.deinit(allocator);
    builders.deinit(allocator);
    builders.* = .empty;
}

fn deinitFrames(frames: *std.ArrayList(KustoFrame), allocator: std.mem.Allocator) void {
    for (frames.items) |*frame| frame.deinit(allocator);
    frames.deinit(allocator);
    frames.* = .empty;
}

fn deinitRows(rows: []KustoResultRow, allocator: std.mem.Allocator) void {
    for (rows) |*row| row.deinit(allocator);
}

fn deinitTableMetadata(table: *KustoResultTable, allocator: std.mem.Allocator) void {
    for (table.columns) |*column| column.deinit(allocator);
    allocator.free(table.columns);
    allocator.free(table.name);
    if (table.kind) |value| allocator.free(value);
    if (table.toc_name) |value| allocator.free(value);
    if (table.toc_id) |value| allocator.free(value);
    if (table.pretty_name) |value| allocator.free(value);
}

fn cloneTableMetadata(
    allocator: std.mem.Allocator,
    source: *const KustoResultTable,
    completed: bool,
) !KustoResultTable {
    const name = try allocator.dupe(u8, source.name);
    errdefer allocator.free(name);
    const kind = if (source.kind) |value| try allocator.dupe(u8, value) else null;
    errdefer if (kind) |value| allocator.free(value);
    const toc_name = if (source.toc_name) |value| try allocator.dupe(u8, value) else null;
    errdefer if (toc_name) |value| allocator.free(value);
    const toc_id = if (source.toc_id) |value| try allocator.dupe(u8, value) else null;
    errdefer if (toc_id) |value| allocator.free(value);
    const pretty_name = if (source.pretty_name) |value| try allocator.dupe(u8, value) else null;
    errdefer if (pretty_name) |value| allocator.free(value);
    const columns = try cloneColumns(allocator, source.columns);
    errdefer {
        for (columns) |*column| column.deinit(allocator);
        allocator.free(columns);
    }
    return .{
        .id = source.id,
        .ordinal = source.ordinal,
        .name = name,
        .kind = kind,
        .known_kind = source.known_kind,
        .toc_name = toc_name,
        .toc_id = toc_id,
        .pretty_name = pretty_name,
        .columns = columns,
        .rows = &.{},
        .progress = source.progress,
        .reported_row_count = source.reported_row_count,
        .completed = completed,
    };
}

fn cloneColumns(
    allocator: std.mem.Allocator,
    source: []const KustoResultColumn,
) ![]KustoResultColumn {
    var columns = try allocator.alloc(KustoResultColumn, source.len);
    var initialized: usize = 0;
    errdefer {
        for (columns[0..initialized]) |*column| column.deinit(allocator);
        allocator.free(columns);
    }
    for (source, 0..) |column, index| {
        columns[index] = .{
            .name = try allocator.dupe(u8, column.name),
            .column_type = undefined,
            .scalar_kind = column.scalar_kind,
            .has_declared_type = column.has_declared_type,
        };
        errdefer allocator.free(columns[index].name);
        columns[index].column_type = try allocator.dupe(u8, column.column_type);
        initialized += 1;
    }
    return columns;
}

fn parseObjectFields(allocator: std.mem.Allocator, raw: []const u8) ![]Field {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    if ((scanner.next() catch return error.MalformedKustoResponse) != .object_begin)
        return error.MalformedKustoResponse;

    var fields = std.ArrayList(Field).empty;
    if (scanner.isContainerEmpty('}') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            scanner.skipWhitespace();
            const key_start = scanner.pos;
            const key_token = scanner.next() catch return error.MalformedKustoResponse;
            if (key_token != .string) return error.MalformedKustoResponse;
            const key_raw = raw[key_start..scanner.pos];
            const key = try decodeStringTemp(allocator, key_raw);
            for (fields.items) |existing| {
                if (std.mem.eql(u8, existing.name, key))
                    return error.MalformedKustoResponse;
            }
            scanner.expectColon() catch return error.MalformedKustoResponse;
            const value = try captureValue(scanner, raw);
            try fields.append(allocator, .{ .name = key, .value = value });
            switch (scanner.finishContainer('}') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    try ensureScannerComplete(scanner, raw);
    return fields.toOwnedSlice(allocator);
}

fn field(fields: []const Field, name: []const u8) ?[]const u8 {
    for (fields) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.value;
    }
    return null;
}

fn requiredField(fields: []const Field, name: []const u8) ?[]const u8 {
    return field(fields, name);
}

fn captureValue(scanner: anytype, input: []const u8) ![]const u8 {
    scanner.skipWhitespace();
    const start = scanner.pos;
    scanner.skipValue() catch return error.MalformedKustoResponse;
    return input[start..scanner.pos];
}

fn ensureScannerComplete(scanner: anytype, input: []const u8) !void {
    scanner.skipWhitespace();
    if (scanner.pos != input.len) return error.MalformedKustoResponse;
}

fn singleToken(raw: []const u8) !JsonTokenKind {
    var deserializer = serde.json.Deserializer.init(raw);
    const scanner = &deserializer.scanner;
    const token = scanner.next() catch return error.MalformedKustoResponse;
    return switch (token) {
        .object_begin => .object_begin,
        .object_end => .object_end,
        .array_begin => .array_begin,
        .array_end => .array_end,
        .string => .string,
        .number => .number,
        .true_lit => .true_lit,
        .false_lit => .false_lit,
        .null_lit => .null_lit,
    };
}

fn decodeStringOwned(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    const value = serde.json.fromSlice([]const u8, allocator, raw) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.MalformedKustoResponse;
    };
    return @constCast(value);
}

fn decodeStringTemp(allocator: std.mem.Allocator, raw: []const u8) ![]const u8 {
    return serde.json.fromSlice([]const u8, allocator, raw) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.MalformedKustoResponse;
    };
}

fn decodeBool(raw: []const u8) !bool {
    return switch (try singleToken(raw)) {
        .true_lit => true,
        .false_lit => false,
        else => error.MalformedKustoResponse,
    };
}

fn decodeKustoBool(raw: []const u8) !bool {
    return switch (try singleToken(raw)) {
        .true_lit => true,
        .false_lit => false,
        .number => switch (try decodeInteger(i64, raw)) {
            0 => false,
            1 => true,
            else => error.MalformedKustoResponse,
        },
        else => error.MalformedKustoResponse,
    };
}

fn decodeInteger(comptime T: type, raw: []const u8) !T {
    switch (try singleToken(raw)) {
        .number => {},
        else => return error.MalformedKustoResponse,
    }
    return std.fmt.parseInt(T, raw, 10) catch error.MalformedKustoResponse;
}

fn decodeFiniteNumber(raw: []const u8) !f64 {
    switch (try singleToken(raw)) {
        .number => {},
        else => return error.MalformedKustoResponse,
    }
    const value = std.fmt.parseFloat(f64, raw) catch return error.MalformedKustoResponse;
    if (!std.math.isFinite(value)) return error.MalformedKustoResponse;
    return value;
}

fn decodeNonNegativeI64(raw: []const u8) !i64 {
    const value = try decodeInteger(i64, raw);
    if (value < 0) return error.MalformedKustoResponse;
    return value;
}

fn parseRequiredId(fields: []const Field, name: []const u8) !i64 {
    const raw = requiredField(fields, name) orelse return error.MalformedKustoResponse;
    return decodeInteger(i64, raw);
}

fn replaceOptionalString(
    allocator: std.mem.Allocator,
    destination: *?[]u8,
    source: []const u8,
) !void {
    const owned = try allocator.dupe(u8, source);
    if (destination.*) |old| allocator.free(old);
    destination.* = owned;
}

fn valueAsI64(value: KustoValue) ?i64 {
    return switch (value) {
        .int => |item| item,
        .long => |item| item,
        .string, .decimal => |item| std.fmt.parseInt(i64, item, 10) catch null,
        .unknown => |item| rawAsI64(item),
        else => null,
    };
}

fn rawAsI64(raw: []const u8) ?i64 {
    if ((singleToken(raw) catch return null) != .number) return null;
    return std.fmt.parseInt(i64, raw, 10) catch null;
}

fn valueTextOwned(allocator: std.mem.Allocator, value: KustoValue) !?[]u8 {
    if (value.lexical()) |item| return @as(?[]u8, try allocator.dupe(u8, item));
    return switch (value) {
        .int => |item| try std.fmt.allocPrint(allocator, "{d}", .{item}),
        .long => |item| try std.fmt.allocPrint(allocator, "{d}", .{item}),
        .bool => |item| try allocator.dupe(u8, if (item) "true" else "false"),
        .unknown => |item| blk: {
            switch (try singleToken(item)) {
                .string => break :blk @as(?[]u8, try decodeStringOwned(allocator, item)),
                .number, .true_lit, .false_lit => break :blk @as(?[]u8, try allocator.dupe(u8, item)),
                else => break :blk null,
            }
        },
        else => null,
    };
}

fn rememberFailure(
    destination: *?kusto_common.KustoError,
    incoming: kusto_common.KustoError,
) void {
    if (destination.*) |_| {
        var discarded = incoming;
        discarded.deinit();
    } else {
        destination.* = incoming;
    }
}

fn queryStatusFailure(
    allocator: std.mem.Allocator,
    dataset: *const KustoResponseDataSet,
    operation: kusto_common.KustoOperation,
) !?kusto_common.KustoError {
    return switch (dataset.protocol) {
        .v1 => queryStatusFailureV1(allocator, dataset, operation),
        .v2 => queryCompletionInformationFailure(allocator, dataset, operation),
    };
}

fn queryStatusFailureV1(
    allocator: std.mem.Allocator,
    dataset: *const KustoResponseDataSet,
    operation: kusto_common.KustoOperation,
) !?kusto_common.KustoError {
    for (dataset.tables) |*table| {
        if (table.known_kind != .query_status and
            !std.ascii.eqlIgnoreCase(table.name, "QueryStatus"))
            continue;
        for (table.rows) |*row| {
            const severity_value = row.getByName("Severity") orelse continue;
            const severity = valueAsI64(severity_value.*) orelse continue;
            if (severity > 2) continue;

            var result = kusto_common.errors.inBandFailure(
                allocator,
                operation,
                .query_status,
                false,
            );
            errdefer result.deinit();
            if (row.getByName("StatusCode")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.detail.code = text;
            }
            if (row.getByName("StatusDescription")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.detail.message = text;
            }
            if (row.getByName("ClientActivityId") orelse row.getByName("RequestId")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.client_request_id = text;
            }
            if (row.getByName("ActivityId")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.activity_id = text;
            }
            return result;
        }
    }
    return null;
}

fn queryCompletionInformationFailure(
    allocator: std.mem.Allocator,
    dataset: *const KustoResponseDataSet,
    operation: kusto_common.KustoOperation,
) !?kusto_common.KustoError {
    for (dataset.tables) |*table| {
        if (table.known_kind != .query_completion_information)
            continue;
        for (table.rows) |*row| {
            const level_value = row.getByName("Level") orelse continue;
            const level = valueAsI64(level_value.*) orelse continue;
            if (level > 2) continue;

            var result = kusto_common.errors.inBandFailure(
                allocator,
                operation,
                .query_status,
                false,
            );
            errdefer result.deinit();
            if (row.getByName("StatusCodeName")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.detail.code = text;
            }
            if (result.detail.code == null) {
                if (row.getByName("StatusCode")) |value| {
                    if (try valueTextOwned(allocator, value.*)) |text|
                        result.detail.code = text;
                }
            }
            if (row.getByName("Payload")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.detail.message = text;
            }
            if (row.getByName("ClientRequestId")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.client_request_id = text;
            }
            if (row.getByName("ActivityId")) |value| {
                if (try valueTextOwned(allocator, value.*)) |text|
                    result.activity_id = text;
            }
            return result;
        }
    }
    return null;
}

fn normalizeScalarKind(column_type: []const u8) KustoScalarKind {
    if (std.ascii.eqlIgnoreCase(column_type, "string") or
        std.ascii.eqlIgnoreCase(column_type, "System.String"))
        return .string;
    if (std.ascii.eqlIgnoreCase(column_type, "bool") or
        std.ascii.eqlIgnoreCase(column_type, "boolean") or
        std.ascii.eqlIgnoreCase(column_type, "sbyte") or
        std.ascii.eqlIgnoreCase(column_type, "System.SByte") or
        std.ascii.eqlIgnoreCase(column_type, "System.Boolean"))
        return .bool;
    if (std.ascii.eqlIgnoreCase(column_type, "int") or
        std.ascii.eqlIgnoreCase(column_type, "int32") or
        std.ascii.eqlIgnoreCase(column_type, "System.Int32"))
        return .int;
    if (std.ascii.eqlIgnoreCase(column_type, "long") or
        std.ascii.eqlIgnoreCase(column_type, "int64") or
        std.ascii.eqlIgnoreCase(column_type, "System.Int64"))
        return .long;
    if (std.ascii.eqlIgnoreCase(column_type, "real") or
        std.ascii.eqlIgnoreCase(column_type, "float") or
        std.ascii.eqlIgnoreCase(column_type, "double") or
        std.ascii.eqlIgnoreCase(column_type, "System.Single") or
        std.ascii.eqlIgnoreCase(column_type, "System.Double"))
        return .real;
    if (std.ascii.eqlIgnoreCase(column_type, "decimal") or
        std.ascii.eqlIgnoreCase(column_type, "System.Decimal"))
        return .decimal;
    if (std.ascii.eqlIgnoreCase(column_type, "datetime") or
        std.ascii.eqlIgnoreCase(column_type, "date") or
        std.ascii.eqlIgnoreCase(column_type, "System.DateTime"))
        return .datetime;
    if (std.ascii.eqlIgnoreCase(column_type, "timespan") or
        std.ascii.eqlIgnoreCase(column_type, "time") or
        std.ascii.eqlIgnoreCase(column_type, "System.TimeSpan"))
        return .timespan;
    if (std.ascii.eqlIgnoreCase(column_type, "guid") or
        std.ascii.eqlIgnoreCase(column_type, "uuid") or
        std.ascii.eqlIgnoreCase(column_type, "uniqueid") or
        std.ascii.eqlIgnoreCase(column_type, "System.Guid"))
        return .guid;
    if (std.ascii.eqlIgnoreCase(column_type, "dynamic") or
        std.ascii.eqlIgnoreCase(column_type, "object") or
        std.ascii.eqlIgnoreCase(column_type, "System.Object"))
        return .dynamic;
    return .unknown;
}

fn normalizeTableKind(kind: []const u8) KustoTableKind {
    if (std.ascii.eqlIgnoreCase(kind, "PrimaryResult")) return .primary_result;
    if (std.ascii.eqlIgnoreCase(kind, "QueryResult")) return .query_result;
    if (std.ascii.eqlIgnoreCase(kind, "QueryProperties")) return .query_properties;
    if (std.ascii.eqlIgnoreCase(kind, "QueryStatus")) return .query_status;
    if (std.ascii.eqlIgnoreCase(kind, "QueryCompletionInformation")) return .query_completion_information;
    if (std.ascii.eqlIgnoreCase(kind, "QueryTraceLog")) return .query_trace_log;
    if (std.ascii.eqlIgnoreCase(kind, "QueryPerfLog")) return .query_perf_log;
    if (std.ascii.eqlIgnoreCase(kind, "QueryPlan")) return .query_plan;
    if (std.ascii.eqlIgnoreCase(kind, "TableOfContents")) return .table_of_contents;
    return .unknown;
}

fn tableKindName(kind: KustoTableKind) []const u8 {
    return switch (kind) {
        .primary_result => "PrimaryResult",
        .query_result => "QueryResult",
        .query_properties => "QueryProperties",
        .query_status => "QueryStatus",
        .query_completion_information => "QueryCompletionInformation",
        .query_trace_log => "QueryTraceLog",
        .query_perf_log => "QueryPerfLog",
        .query_plan => "QueryPlan",
        .table_of_contents => "TableOfContents",
        .unknown => "",
    };
}

fn expectString(value: *const KustoValue, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, value.asString() orelse return error.TestUnexpectedResult);
}

test "V1 management response owns typed values" {
    const body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"Name","DataType":"string"},{"ColumnName":"Count","ColumnType":"long"},{"ColumnName":"Enabled","ColumnType":"bool"}],"Rows":[["db",9223372036854775807,true]]}]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .management);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expect(decoded.failure == null);
    try std.testing.expectEqual(KustoResponseProtocol.v1, decoded.dataset.protocol);
    try std.testing.expectEqual(@as(usize, 1), decoded.dataset.frames.len);
    switch (decoded.dataset.frames[0]) {
        .v1_root => |frame| try std.testing.expectEqualStrings(body, frame.raw_json),
        else => return error.TestUnexpectedResult,
    }
    const table = decoded.dataset.primaryTable().?;
    try std.testing.expectEqualStrings("Table_0", table.name);
    try expectString(table.rows[0].get(0).?, "db");
    try std.testing.expectEqual(@as(?i64, std.math.maxInt(i64)), table.rows[0].get(1).?.asI64());
    try std.testing.expectEqual(@as(?bool, true), table.rows[0].get(2).?.asBool());
}

test "V1 DataType aliases decode typed values without ColumnType" {
    const body =
        \\{"Tables":[{"TableName":"Aliases","Columns":[
        \\ {"ColumnName":"Long","DataType":"Int64"},{"ColumnName":"Dynamic","DataType":"Object"},{"ColumnName":"Date","DataType":"Date"},{"ColumnName":"Guid","DataType":"UUID"},{"ColumnName":"Time","DataType":"Time"},{"ColumnName":"Byte","DataType":"SByte"}
        \\],"Rows":[[42,{"nested":"escaped \"value\""},"2026-01-02","123e4567-e89b-12d3-a456-426614174000","00:00:01",true]]}]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .management);
    defer decoded.deinit(std.testing.allocator);

    const values = decoded.dataset.tables[0].rows[0].values;
    try std.testing.expectEqual(@as(?i64, 42), values[0].asI64());
    try std.testing.expectEqualStrings(
        "{\"nested\":\"escaped \\\"value\\\"\"}",
        values[1].rawJson().?,
    );
    try std.testing.expectEqualStrings("2026-01-02", values[2].asDateTime().?);
    try std.testing.expectEqualStrings(
        "123e4567-e89b-12d3-a456-426614174000",
        values[3].asGuid().?,
    );
    try std.testing.expectEqualStrings("00:00:01", values[4].asTimespan().?);
    try std.testing.expectEqual(@as(?bool, true), values[5].asBool());
}

test "V1 DataType-only string columns preserve structured values" {
    const body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"StatusDescription","DataType":"String"}],"Rows":[[{"ExecutionTime":0,"resource_usage":{"cpu":null}}]]}]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(KustoTableKind.primary_result, decoded.dataset.tables[0].known_kind);
    try std.testing.expectEqualStrings(
        "{\"ExecutionTime\":0,\"resource_usage\":{\"cpu\":null}}",
        decoded.dataset.tables[0].rows[0].get(0).?.rawJson().?,
    );
}

test "Kusto booleans accept numeric zero and one only" {
    const body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"False","ColumnType":"bool"},{"ColumnName":"True","ColumnType":"boolean"}],"Rows":[[0,1]]}]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);
    const values = decoded.dataset.tables[0].rows[0].values;
    try std.testing.expectEqual(@as(?bool, false), values[0].asBool());
    try std.testing.expectEqual(@as(?bool, true), values[1].asBool());

    const invalid =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"Value","ColumnType":"bool"}],"Rows":[[2]]}]}
    ;
    try std.testing.expectError(
        error.MalformedKustoResponse,
        decode(std.testing.allocator, invalid, .{}, .query),
    );
}

test "short V1 datasets classify primary and query properties tables" {
    const body =
        \\{"Tables":[
        \\ {"TableName":"Table_0","Columns":[{"ColumnName":"Value","DataType":"Int64"}],"Rows":[[42]]},
        \\ {"TableName":"Table_1","Columns":[{"ColumnName":"Key","DataType":"String"}],"Rows":[["Visualization"]]}
        \\]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(KustoTableKind.primary_result, decoded.dataset.tables[0].known_kind);
    try std.testing.expectEqual(KustoTableKind.query_properties, decoded.dataset.tables[1].known_kind);
    try std.testing.expectEqual(@as(?i64, 0), decoded.dataset.tables[0].id);
    try std.testing.expectEqual(@as(?i64, 1), decoded.dataset.tables[1].id);
    try std.testing.expect(decoded.dataset.primaryTable() == &decoded.dataset.tables[0]);
    try std.testing.expect(decoded.dataset.queryProperties() == &decoded.dataset.tables[1]);
}

test "V1 final generic TOC selects multiple query result tables" {
    const body =
        \\{"Tables":[
        \\ {"TableName":"Table_0","Columns":[{"ColumnName":"a","DataType":"Int32","ColumnType":"int"}],"Rows":[[1],[2],[3]]},
        \\ {"TableName":"Table_1","Columns":[{"ColumnName":"a","DataType":"String","ColumnType":"string"},{"ColumnName":"b","DataType":"Int32","ColumnType":"int"}],"Rows":[["a",1],["b",2],["c",3]]},
        \\ {"TableName":"Table_2","Columns":[{"ColumnName":"Value","DataType":"String","ColumnType":"string"}],"Rows":[["{\"Visualization\":null}"],["{\"Visualization\":null}"]]},
        \\ {"TableName":"Table_3","Columns":[{"ColumnName":"Severity","DataType":"Int32","ColumnType":"int"},{"ColumnName":"StatusCode","DataType":"Int32","ColumnType":"int"},{"ColumnName":"StatusDescription","DataType":"String","ColumnType":"string"},{"ColumnName":"ClientActivityId","DataType":"String","ColumnType":"string"}],"Rows":[[4,0,"Query completed successfully","blab6"],[6,0,"statistics","blab6"]]},
        \\ {"TableName":"Table_4","Columns":[
        \\   {"ColumnName":"Ordinal","DataType":"Int64","ColumnType":"long"},{"ColumnName":"Kind","DataType":"String","ColumnType":"string"},{"ColumnName":"Name","DataType":"String","ColumnType":"string"},{"ColumnName":"Id","DataType":"String","ColumnType":"string"},{"ColumnName":"PrettyName","DataType":"String","ColumnType":"string"}
        \\ ],"Rows":[[0,"QueryResult","PrimaryResult","e43f725a-26fd-4219-8869-30c21e1b139c",""],[1,"QueryResult","PrimaryResult","0f66e92a-8d0e-43da-8a66-ddb6bf84c49d",""],[2,"QueryProperties","@ExtendedProperties","d52bc55b-fc74-4a63-adb9-b72ff939e4c2",""],[3,"QueryStatus","QueryStatus","00000000-0000-0000-0000-000000000000",""]]}
        \\]}
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expect(decoded.failure == null);
    try std.testing.expectEqual(KustoTableKind.query_result, decoded.dataset.tables[0].known_kind);
    try std.testing.expectEqual(KustoTableKind.query_result, decoded.dataset.tables[1].known_kind);
    try std.testing.expectEqual(KustoTableKind.table_of_contents, decoded.dataset.tables[4].known_kind);
    try std.testing.expectEqualStrings("PrimaryResult", decoded.dataset.tables[0].toc_name.?);
    try std.testing.expect(decoded.dataset.queryProperties() != null);
    try std.testing.expect(decoded.dataset.queryStatus() != null);
    try std.testing.expectEqual(@as(?i64, 1), decoded.dataset.primaryTable().?.rows[0].get(0).?.asI64());
}

test "V2 normal tables expose tagged frames and iterators" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false,"IsFragmented":false,"ErrorReportingPlacement":"EndOfDataSet"},
        \\ {"FrameType":"DataTable","TableId":7,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"A","ColumnType":"string"}],"Rows":[["one"],["two"]]},
        \\ {"FrameType":"DataTable","TableId":8,"TableKind":"QueryProperties","TableName":"QueryProperties","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    const dataset = &decoded.dataset;
    try std.testing.expectEqual(KustoResponseProtocol.v2, dataset.protocol);
    try std.testing.expectEqual(@as(usize, 4), dataset.frames.len);
    try std.testing.expectEqualStrings("DataTable", dataset.frames[1].frameType());
    switch (dataset.frames[1]) {
        .data_table => {},
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(std.mem.indexOf(u8, dataset.frames[1].rawJson(), "\"DataTable\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dataset.raw_response, "\"PrimaryResult\"") != null);
    try std.testing.expect(dataset.tableById(7) != null);
    try std.testing.expect(dataset.tableByKind("QueryProperties") != null);
    try std.testing.expect(dataset.queryProperties() != null);
    var tables = dataset.tableIterator();
    try std.testing.expect(tables.next() != null);
    const primary = dataset.primaryTable().?;
    var rows = primary.rowIterator();
    try expectString(rows.next().?.getByName("A").?, "one");
    try expectString(rows.next().?.get(0).?, "two");
    try std.testing.expect(rows.next() == null);
    var frames = dataset.frameIterator();
    try std.testing.expect(frames.next() != null);
    try std.testing.expectEqualStrings("DataTable", frames.next().?.frameType());
}

test "V2 normal and progressive tables decode equivalently" {
    const normal =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":4,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"V","ColumnType":"long"}],"Rows":[[1],[2]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    const progressive =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":4,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"V","ColumnType":"long"}]},
        \\ {"FrameType":"TableFragment","TableId":4,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[[1],[2]]},
        \\ {"FrameType":"TableCompletion","TableId":4,"RowCount":2},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var normal_decoded = try decode(std.testing.allocator, normal, .{}, .query);
    defer normal_decoded.deinit(std.testing.allocator);
    var progressive_decoded = try decode(std.testing.allocator, progressive, .{}, .query);
    defer progressive_decoded.deinit(std.testing.allocator);
    const normal_rows = normal_decoded.dataset.primaryTable().?.rows;
    const progressive_rows = progressive_decoded.dataset.primaryTable().?.rows;
    try std.testing.expectEqual(normal_rows.len, progressive_rows.len);
    for (normal_rows, progressive_rows) |left, right|
        try std.testing.expectEqual(left.get(0).?.asI64(), right.get(0).?.asI64());
}

test "progressive datasets accept normal metadata DataTable frames" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"DataTable","TableId":10,"TableKind":"QueryProperties","TableName":"QueryProperties","Columns":[{"ColumnName":"Name","ColumnType":"String"}],"Rows":[["metadata"]]},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"V","ColumnType":"long"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"TableFragmentType":"DataAppend","Rows":[[42]]},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":1},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), decoded.dataset.tables.len);
    try std.testing.expectEqualStrings(
        "metadata",
        decoded.dataset.queryProperties().?.rows[0].get(0).?.asString().?,
    );
    try std.testing.expectEqual(
        @as(?i64, 42),
        decoded.dataset.primaryTable().?.rows[0].get(0).?.asI64(),
    );
}

test "fragmented datasets accept mixed normal and table frames" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false,"IsFragmented":true,"ErrorReportingPlacement":"EndOfTable"},
        \\ {"FrameType":"DataTable","TableId":10,"TableKind":"QueryProperties","TableName":"QueryProperties","Columns":[{"ColumnName":"Name","ColumnType":"string"}],"Rows":[["metadata"]]},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"V","ColumnType":"long"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[[42]]},
        \\ {"FrameType":"TableProgress","TableId":1,"TableProgress":100},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":1},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    const dataset = &decoded.dataset;
    try std.testing.expectEqual(@as(?bool, true), dataset.is_fragmented);
    try std.testing.expectEqualStrings("EndOfTable", dataset.error_reporting_placement.?);
    try expectString(dataset.queryProperties().?.rows[0].get(0).?, "metadata");
    const primary = dataset.primaryTable().?;
    try std.testing.expectEqual(@as(?f64, 100), primary.progress);
    try std.testing.expectEqual(@as(?i64, 1), primary.reported_row_count);
    try std.testing.expectEqual(@as(?i64, 42), primary.rows[0].get(0).?.asI64());
}

test "V2 progressive append replace and interleaved IDs reconstruct rows" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"First","Columns":[{"ColumnName":"V","ColumnType":"string"}]},
        \\ {"FrameType":"TableHeader","TableId":2,"TableKind":"SecondaryResult","TableName":"Second","Columns":[{"ColumnName":"V","ColumnType":"string"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[["A"]]},
        \\ {"FrameType":"TableFragment","TableId":2,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[["B"]]},
        \\ {"FrameType":"TableProgress","TableId":1,"TableProgress":50},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":1,"TableFragmentType":"DataReplace","Rows":[["C"]]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[["D"]]},
        \\ {"FrameType":"TableCompletion","TableId":2,"RowCount":1},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":2},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    const first = decoded.dataset.tableById(1).?;
    const second = decoded.dataset.tableById(2).?;
    try std.testing.expectEqual(@as(?f64, 50), first.progress);
    try std.testing.expectEqual(@as(usize, 2), first.rows.len);
    try expectString(first.rows[0].get(0).?, "C");
    try expectString(first.rows[1].get(0).?, "D");
    try expectString(second.rows[0].get(0).?, "B");
    const tags = [_]std.meta.Tag(KustoFrame){
        .data_set_header,
        .table_header,
        .table_header,
        .table_fragment,
        .table_fragment,
        .table_progress,
        .table_fragment,
        .table_fragment,
        .table_completion,
        .table_completion,
        .data_set_completion,
    };
    for (decoded.dataset.frames, tags) |frame, tag|
        try std.testing.expectEqual(tag, std.meta.activeTag(frame));
}

test "V2 completion errors keep reconstructed tables" {
    const table_error =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"V","ColumnType":"string"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"TableFragmentType":"DataAppend","Rows":[["before"]]},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":1,"OneApiErrors":[{"error":{"code":"TableFailure","message":"bad table"}}]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var table_decoded = try decode(std.testing.allocator, table_error, .{}, .query);
    defer table_decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(KustoErrorSource.table_completion, table_decoded.failure.?.source);
    try expectString(table_decoded.dataset.primaryTable().?.rows[0].get(0).?, "before");

    const dataset_error =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"V","ColumnType":"string"}],"Rows":[["before"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":true,"Cancelled":false,"OneApiErrors":[{"error":{"code":"DataSetFailure","message":"bad dataset"}}]}
        \\]
    ;
    var dataset_decoded = try decode(std.testing.allocator, dataset_error, .{}, .query);
    defer dataset_decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(KustoErrorSource.dataset_completion, dataset_decoded.failure.?.source);
    try std.testing.expectEqualStrings("DataSetFailure", dataset_decoded.failure.?.detail.code.?);
}

test "V2 row-embedded OneApiErrors retain DataTable and fragment rows" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"QueryProperties","TableName":"@ExtendedProperties","Columns":[{"ColumnName":"TableId","ColumnType":"int"},{"ColumnName":"Key","ColumnType":"string"},{"ColumnName":"Value","ColumnType":"dynamic"}],"Rows":[[1,"Visualization","{\"Visualization\":null}"]]},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"x","ColumnType":"long"}],"Rows":[[1],[2],[3],[4],[5],{"OneApiErrors":[{"error":{"code":"LimitsExceeded","message":"Request is invalid and cannot be executed.","@type":"Kusto.Data.Exceptions.KustoServicePartialQueryFailureLimitsExceededException","@message":"Query execution has exceeded the allowed limits (80DA0003): .","@context":{"clientRequestId":"KPC.execute;d3a43e37-0d7f-47a9-b6cd-a889b2aee3d3","activityId":"a57ec272-8846-49e6-b458-460b841ed47d"},"@permanent":false}}]}]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":true,"Cancelled":false,"OneApiErrors":[{"error":{"code":"LimitsExceeded","message":"Request is invalid and cannot be executed."}}]}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(KustoErrorSource.data_table, decoded.failure.?.source);
    try std.testing.expectEqualStrings("LimitsExceeded", decoded.failure.?.detail.code.?);
    try std.testing.expectEqualStrings(
        "Request is invalid and cannot be executed.",
        decoded.failure.?.detail.message.?,
    );
    try std.testing.expectEqualStrings(
        "Kusto.Data.Exceptions.KustoServicePartialQueryFailureLimitsExceededException",
        decoded.failure.?.detail.error_type.?,
    );
    try std.testing.expectEqualStrings(
        "Query execution has exceeded the allowed limits (80DA0003): .",
        decoded.failure.?.detail.description.?,
    );
    try std.testing.expectEqual(@as(?bool, false), decoded.failure.?.permanent);
    try std.testing.expectEqualStrings(
        "KPC.execute;d3a43e37-0d7f-47a9-b6cd-a889b2aee3d3",
        decoded.failure.?.client_request_id.?,
    );
    try std.testing.expectEqualStrings(
        "a57ec272-8846-49e6-b458-460b841ed47d",
        decoded.failure.?.activity_id.?,
    );
    try std.testing.expectEqual(@as(usize, 1), decoded.dataset.queryProperties().?.rows.len);
    try std.testing.expectEqual(@as(?i64, 5), decoded.dataset.primaryTable().?.rows[4].get(0).?.asI64());
    try std.testing.expectEqual(@as(usize, 5), decoded.dataset.primaryTable().?.rows.len);

    const fragment_only =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"V","ColumnType":"long"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":1,"TableFragmentType":"DataAppend","Rows":[[42],{"OneApiErrors":[{"error":{"code":"FragmentFailure","message":"partial fragment"}}]}]},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":1},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var fragment_decoded = try decode(std.testing.allocator, fragment_only, .{}, .query);
    defer fragment_decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(KustoErrorSource.data_table, fragment_decoded.failure.?.source);
    try std.testing.expectEqualStrings("FragmentFailure", fragment_decoded.failure.?.detail.code.?);
    try std.testing.expectEqual(@as(usize, 1), fragment_decoded.dataset.primaryTable().?.rows.len);
}

test "V2 row objects must be OneApiErrors" {
    const malformed = [_][]const u8{
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[],"Rows":[{"unexpected":true}]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[],"Rows":[{"OneApiErrors":[]}]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
    };
    for (malformed) |body| {
        try std.testing.expectError(
            error.MalformedKustoResponse,
            decode(std.testing.allocator, body, .{}, .query),
        );
    }
}

test "V2 QueryCompletionInformation failures produce a partial failure" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"QueryCompletionInformation","TableName":"QueryCompletionInformation","Columns":[
        \\   {"ColumnName":"Timestamp","ColumnType":"datetime"},{"ColumnName":"ClientRequestId","ColumnType":"string"},{"ColumnName":"ActivityId","ColumnType":"guid"},{"ColumnName":"SubActivityId","ColumnType":"guid"},{"ColumnName":"ParentActivityId","ColumnType":"guid"},{"ColumnName":"Level","ColumnType":"int"},{"ColumnName":"LevelName","ColumnType":"string"},{"ColumnName":"StatusCode","ColumnType":"int"},{"ColumnName":"StatusCodeName","ColumnType":"string"},{"ColumnName":"EventType","ColumnType":"int"},{"ColumnName":"EventTypeName","ColumnType":"string"},{"ColumnName":"Payload","ColumnType":"string"}
        \\ ],"Rows":[["2024-01-01T00:00:00Z","row-request","123e4567-e89b-12d3-a456-426614174000","123e4567-e89b-12d3-a456-426614174001","123e4567-e89b-12d3-a456-426614174002",2,"Error",429,"LimitsExceeded",0,"QueryError","truncated"],["2024-01-01T00:00:01Z","stats-request","123e4567-e89b-12d3-a456-426614174003","123e4567-e89b-12d3-a456-426614174004","123e4567-e89b-12d3-a456-426614174005",6,"Stats",200,"Succeeded",0,"QueryResourceConsumption","statistics"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(KustoErrorSource.query_status, decoded.failure.?.source);
    try std.testing.expectEqualStrings("LimitsExceeded", decoded.failure.?.detail.code.?);
    try std.testing.expectEqualStrings("truncated", decoded.failure.?.detail.message.?);
    try std.testing.expectEqualStrings("row-request", decoded.failure.?.client_request_id.?);
    try std.testing.expectEqualStrings(
        "123e4567-e89b-12d3-a456-426614174000",
        decoded.failure.?.activity_id.?,
    );

    const normal =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"QueryCompletionInformation","TableName":"QueryCompletionInformation","Columns":[{"ColumnName":"Level","ColumnType":"int"},{"ColumnName":"Payload","ColumnType":"string"}],"Rows":[[4,"warning"],[6,"statistics"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var normal_decoded = try decode(std.testing.allocator, normal, .{}, .query);
    defer normal_decoded.deinit(std.testing.allocator);
    try std.testing.expect(normal_decoded.failure == null);
}

test "scalar aliases preserve lexical and raw JSON values" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"T","Columns":[
        \\   {"ColumnName":"S","ColumnType":"string"},{"ColumnName":"B","ColumnType":"boolean"},{"ColumnName":"I","ColumnType":"int32"},{"ColumnName":"L","ColumnType":"int64"},{"ColumnName":"R","ColumnType":"double"},{"ColumnName":"D","ColumnType":"decimal"},{"ColumnName":"Date","ColumnType":"date"},{"ColumnName":"Time","ColumnType":"time"},{"ColumnName":"Id","ColumnType":"uniqueid"},{"ColumnName":"Dyn","ColumnType":"dynamic"},{"ColumnName":"Unknown","ColumnType":"custom"}
        \\ ],"Rows":[["escaped\n\"value\"",true,-12,9223372036854775807,-12.5e+2,"12.340","2026-01-02","00:00:01","123e4567-e89b-12d3-a456-426614174000",{"a":[1,{"b":null}]},"raw"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    const values = decoded.dataset.primaryTable().?.rows[0].values;
    try expectString(&values[0], "escaped\n\"value\"");
    try std.testing.expectEqual(@as(?bool, true), values[1].asBool());
    try std.testing.expectEqual(@as(?i32, -12), values[2].asI32());
    try std.testing.expectEqual(@as(?i64, std.math.maxInt(i64)), values[3].asI64());
    try std.testing.expectApproxEqAbs(@as(f64, -1250), values[4].asF64().?, 0.001);
    try std.testing.expectEqualStrings("12.340", values[5].lexical().?);
    try std.testing.expectEqualStrings("2026-01-02", values[6].lexical().?);
    try std.testing.expectEqualStrings("00:00:01", values[7].lexical().?);
    try std.testing.expectEqualStrings("123e4567-e89b-12d3-a456-426614174000", values[8].lexical().?);
    try std.testing.expectEqualStrings("{\"a\":[1,{\"b\":null}]}", values[9].rawJson().?);
    try std.testing.expectEqualStrings("\"raw\"", values[10].rawJson().?);
}

test "real values reject incompatible JSON while preserving special strings" {
    const special =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"R","ColumnType":"Real"}],"Rows":[["NaN"],[1e999]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, special, .{}, .query);
    defer decoded.deinit(std.testing.allocator);
    const rows = decoded.dataset.primaryTable().?.rows;
    try std.testing.expectEqualStrings("\"NaN\"", rows[0].get(0).?.rawJson().?);
    try std.testing.expectEqualStrings("1e999", rows[1].get(0).?.rawJson().?);

    const incompatible = [_][]const u8{
        "true",
        "[]",
        "{}",
    };
    for (incompatible) |value| {
        const body = try std.fmt.allocPrint(
            std.testing.allocator,
            \\[
            \\ {{"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false}},
            \\ {{"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"T","Columns":[{{"ColumnName":"R","ColumnType":"real"}}],"Rows":[[{s}]]}},
            \\ {{"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}}
            \\]
        ,
            .{value},
        );
        defer std.testing.allocator.free(body);
        try std.testing.expectError(
            error.MalformedKustoResponse,
            decode(std.testing.allocator, body, .{}, .query),
        );
    }
}

test "documented table kinds normalize and retain canonical names" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"QueryTraceLog","TableName":"Trace","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataTable","TableId":2,"TableKind":"queryperflog","TableName":"Perf","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataTable","TableId":3,"TableKind":"QueryPlan","TableName":"Plan","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(KustoTableKind.query_trace_log, decoded.dataset.tables[0].known_kind);
    try std.testing.expectEqual(KustoTableKind.query_perf_log, decoded.dataset.tables[1].known_kind);
    try std.testing.expectEqual(KustoTableKind.query_plan, decoded.dataset.tables[2].known_kind);
    try std.testing.expect(decoded.dataset.tableByKind("QueryTraceLog") != null);
    try std.testing.expect(decoded.dataset.tableByKind("QueryPerfLog") != null);
    try std.testing.expect(decoded.dataset.tableByKind("QueryPlan") != null);
    try std.testing.expectEqualStrings("QueryTraceLog", tableKindName(.query_trace_log));
    try std.testing.expectEqualStrings("QueryPerfLog", tableKindName(.query_perf_log));
    try std.testing.expectEqualStrings("QueryPlan", tableKindName(.query_plan));
}

test "unknown tagged frames and table kinds are retained without state changes" {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"FutureFrame","Nested":{"a":[1,2]}},
        \\ {"FrameType":"DataTable","TableId":3,"TableKind":"FutureKind","TableName":"T","Columns":[{"ColumnName":"X","ColumnType":"future"}],"Rows":[[{"opaque":true}]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var decoded = try decode(std.testing.allocator, body, .{}, .query);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), decoded.dataset.frames.len);
    switch (decoded.dataset.frames[1]) {
        .unknown => |frame| {
            try std.testing.expectEqualStrings("FutureFrame", frame.frame_type);
            try std.testing.expectEqualStrings(
                "{\"FrameType\":\"FutureFrame\",\"Nested\":{\"a\":[1,2]}}",
                frame.raw_json,
            );
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(KustoTableKind.unknown, decoded.dataset.tables[0].known_kind);
    try std.testing.expectEqualStrings("{\"opaque\":true}", decoded.dataset.tables[0].rows[0].get(0).?.rawJson().?);
}

test "ordering and row-width violations are rejected while varying widths are safe" {
    const missing_header =
        \\[{"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}]
    ;
    try std.testing.expectError(
        error.MalformedKustoResponse,
        decode(std.testing.allocator, missing_header, .{}, .query),
    );
    const unknown_fragment_type =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[]},
        \\ {"FrameType":"TableFragment","TableId":1,"TableFragmentType":"Future","Rows":[]},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":0},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    try std.testing.expectError(
        error.UnsupportedTableFragmentType,
        decode(std.testing.allocator, unknown_fragment_type, .{}, .query),
    );
    const invalid_dynamic =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"D","ColumnType":"dynamic"}],"Rows":[[{"invalid":"\uZZZZ"}]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    try std.testing.expectError(
        error.MalformedKustoResponse,
        decode(std.testing.allocator, invalid_dynamic, .{}, .query),
    );

    const varying =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"A","ColumnType":"string"},{"ColumnName":"B","ColumnType":"long"}],"Rows":[["one"],["two",2,{"extra":true}]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    try std.testing.expectError(
        error.MalformedKustoResponse,
        decode(std.testing.allocator, varying, .{}, .query),
    );
    var decoded = try decode(
        std.testing.allocator,
        varying,
        .{ .allow_varying_row_widths = true },
        .query,
    );
    defer decoded.deinit(std.testing.allocator);
    const rows = decoded.dataset.primaryTable().?.rows;
    try std.testing.expectEqual(@as(usize, 1), rows[0].values.len);
    try std.testing.expectEqual(@as(usize, 3), rows[1].values.len);
    try std.testing.expectEqualStrings("{\"extra\":true}", rows[1].values[2].rawJson().?);
}

test "V2 frame state rejects invalid IDs ordering and metadata" {
    const malformed = [_][]const u8{
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"A","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"B","Columns":[],"Rows":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false,"IsFragmented":false},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableFragment","TableId":9,"TableFragmentType":"DataAppend","Rows":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"A","ColumnType":"string"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":2,"TableFragmentType":"DataAppend","Rows":[]},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":0},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[]},
        \\ {"FrameType":"TableProgress","TableId":1,"TableProgress":101},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":0},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
        ,
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false},
        \\ {"FrameType":"FutureFrame"}
        \\]
        ,
    };
    for (malformed) |body| {
        try std.testing.expectError(
            error.MalformedKustoResponse,
            decode(std.testing.allocator, body, .{}, .query),
        );
    }
}

fn parseAllocationFixture(allocator: std.mem.Allocator) !void {
    const body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},
        \\ {"FrameType":"DataTable","TableId":10,"TableKind":"QueryProperties","TableName":"QueryProperties","Columns":[{"ColumnName":"Name","ColumnType":"string"}],"Rows":[["metadata"],{"OneApiErrors":[{"error":{"code":"DataTableFailure","message":"partial data table"}}]}]},
        \\ {"FrameType":"TableHeader","TableId":1,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"S","ColumnType":"string"},{"ColumnName":"D","ColumnType":"dynamic"}]},
        \\ {"FrameType":"TableFragment","TableId":1,"FieldCount":2,"TableFragmentType":"DataAppend","Rows":[["escaped\nvalue",{"nested":[1,2]}],{"OneApiErrors":[{"error":{"code":"FragmentFailure","message":"partial fragment"}}]}]},
        \\ {"FrameType":"FutureFrame","nested":{"a":[1,2]}},
        \\ {"FrameType":"TableCompletion","TableId":1,"RowCount":1},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false,"OneApiErrors":[{"error":{"code":"DuplicateFailure","message":"reported later"}}]}
        \\]
    ;
    var decoded = try decode(allocator, body, .{}, .query);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), decoded.dataset.tables.len);
    try std.testing.expectEqual(KustoErrorSource.data_table, decoded.failure.?.source);
}

test "complex result parsing releases all allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parseAllocationFixture,
        .{},
    );
}

test "progressive decoder does not retain completed DataTable schemas" {
    const allocator = std.testing.allocator;
    var decoder = ProgressiveDecoder.init(allocator, .{}, .query);
    defer decoder.deinit();

    var header = try decoder.decodeOwnedFrame(try allocator.dupe(u8,
        \\{"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false}
    ));
    defer header.deinit(allocator);
    var table = try decoder.decodeOwnedFrame(try allocator.dupe(u8,
        \\{"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"T","Columns":[{"ColumnName":"Value","ColumnType":"long"}],"Rows":[[1]]}
    ));
    defer table.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), decoder.tables.items.len);
    try std.testing.expect(decoder.tables.items[0].table == null);
}

const TypedHook = struct {
    text: []u8,

    pub fn kustoDecode(allocator: std.mem.Allocator, value: *const KustoValue) !@This() {
        const text = value.asString() orelse return error.TypedHookExpectedString;
        return .{ .text = try allocator.dupe(u8, text) };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.text);
        self.* = undefined;
    }
};

const FailingTypedHook = struct {
    pub fn kustoDecode(_: std.mem.Allocator, _: *const KustoValue) !@This() {
        return error.TypedHookRejected;
    }
};

fn decodeTypedFixture(allocator: std.mem.Allocator) !DecodeOutcome {
    return decode(
        allocator,
        \\{"Tables":[{"TableName":"Rows","Columns":[
        \\ {"ColumnName":"Name","ColumnType":"string"},{"ColumnName":"Count","ColumnType":"long"},{"ColumnName":"Flag","ColumnType":"bool"},{"ColumnName":"Small","ColumnType":"int"},{"ColumnName":"Rate","ColumnType":"real"},{"ColumnName":"When","ColumnType":"datetime"},{"ColumnName":"Span","ColumnType":"timespan"},{"ColumnName":"Amount","ColumnType":"decimal"},{"ColumnName":"Id","ColumnType":"guid"},{"ColumnName":"Payload","ColumnType":"dynamic"},{"ColumnName":"NullName","ColumnType":"string"}
        \\],"Rows":[["Ada",42,true,7,1.25,"2026-01-02T03:04:05Z","01:02:03","12.340","123e4567-e89b-12d3-a456-426614174000",{"nested":[1,2]},null],["Grace",43,false,8,2.5,"2026-01-03T03:04:05Z","02:03:04","13.340","123e4567-e89b-12d3-a456-426614174001",{"nested":[3]},null]]}]}
    ,
        .{},
        .query,
    );
}

test "typed rows map reordered and renamed columns into owned values" {
    const Row = struct {
        count: i64,
        name: []u8,
        enabled: bool,
        optional_name: ?[]const u8,

        pub const kusto_columns = .{
            .count = "Count",
            .name = "Name",
            .enabled = "Flag",
            .optional_name = "NullName",
        };
    };
    const Decoder = KustoRowDecoder(Row);
    var decoded = try decodeTypedFixture(std.testing.allocator);
    defer decoded.deinit(std.testing.allocator);
    const table = &decoded.dataset.tables[0];
    const decoder = try table.rowDecoder(Row);
    var row = try decoder.rowAs(&table.rows[0], std.testing.allocator);
    defer Decoder.deinitRow(&row, std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 42), row.count);
    try std.testing.expectEqualStrings("Ada", row.name);
    try std.testing.expect(row.enabled);
    try std.testing.expect(row.optional_name == null);

    const IntRow = struct { Small: i32 };
    const int_decoder = try table.rowDecoder(IntRow);
    var int_row = try int_decoder.rowAs(&table.rows[0], std.testing.allocator);
    defer KustoRowDecoder(IntRow).deinitRow(&int_row, std.testing.allocator);
    try std.testing.expectEqual(@as(i32, 7), int_row.Small);
}

test "typed rows support scalars semantic values and KustoValue cloning" {
    const Row = struct {
        Name: KustoValue,
        Small: i64,
        Rate: f64,
        When: KustoDateTime,
        Span: KustoTimespan,
        Amount: KustoDecimal,
        Id: KustoGuid,
        Payload: KustoDynamic,
    };
    const Decoder = KustoRowDecoder(Row);
    var decoded = try decodeTypedFixture(std.testing.allocator);
    const table = &decoded.dataset.tables[0];
    const decoder = try table.rowDecoder(Row);
    var row = try decoder.rowAs(&table.rows[0], std.testing.allocator);
    decoded.deinit(std.testing.allocator);
    defer Decoder.deinitRow(&row, std.testing.allocator);
    try std.testing.expectEqualStrings("Ada", row.Name.asString().?);
    try std.testing.expectEqual(@as(i64, 7), row.Small);
    try std.testing.expectApproxEqAbs(@as(f64, 1.25), row.Rate, 0.001);
    try std.testing.expectEqualStrings("2026-01-02T03:04:05Z", row.When.value);
    try std.testing.expectEqualStrings("01:02:03", row.Span.value);
    try std.testing.expectEqualStrings("12.340", row.Amount.value);
    try std.testing.expectEqualStrings("123e4567-e89b-12d3-a456-426614174000", row.Id.value);
    try std.testing.expectEqualStrings("{\"nested\":[1,2]}", row.Payload.raw_json);
}

test "typed rows decode documented non-finite real values" {
    const Row = struct { Value: f64 };
    const Decoder = KustoRowDecoder(Row);
    var decoded = try decode(
        std.testing.allocator,
        \\{"Tables":[{"TableName":"Reals","Columns":[{"ColumnName":"Value","ColumnType":"real"}],"Rows":[["NaN"],["Infinity"],["-Infinity"],[1e999]]}]}
    ,
        .{},
        .query,
    );
    defer decoded.deinit(std.testing.allocator);
    const table = &decoded.dataset.tables[0];
    const decoder = try table.rowDecoder(Row);

    var nan_row = try decoder.rowAs(&table.rows[0], std.testing.allocator);
    defer Decoder.deinitRow(&nan_row, std.testing.allocator);
    try std.testing.expect(std.math.isNan(nan_row.Value));

    var positive_row = try decoder.rowAs(&table.rows[1], std.testing.allocator);
    defer Decoder.deinitRow(&positive_row, std.testing.allocator);
    try std.testing.expect(std.math.isPositiveInf(positive_row.Value));

    var negative_row = try decoder.rowAs(&table.rows[2], std.testing.allocator);
    defer Decoder.deinitRow(&negative_row, std.testing.allocator);
    try std.testing.expect(std.math.isNegativeInf(negative_row.Value));

    try std.testing.expectError(
        error.IncompatibleKustoValue,
        decoder.rowAs(&table.rows[3], std.testing.allocator),
    );
}

test "typed rows reject missing duplicate null and incompatible cells" {
    const Missing = struct { Absent: []u8 };
    var decoded = try decodeTypedFixture(std.testing.allocator);
    defer decoded.deinit(std.testing.allocator);
    const table = &decoded.dataset.tables[0];
    try std.testing.expectError(error.MissingKustoColumn, table.rowDecoder(Missing));

    const RequiredNull = struct { NullName: []u8 };
    const null_decoder = try table.rowDecoder(RequiredNull);
    try std.testing.expectError(
        error.RequiredKustoValueIsNull,
        null_decoder.rowAs(&table.rows[0], std.testing.allocator),
    );

    const Incompatible = struct { Count: bool };
    const incompatible_decoder = try table.rowDecoder(Incompatible);
    try std.testing.expectError(
        error.IncompatibleKustoValue,
        incompatible_decoder.rowAs(&table.rows[0], std.testing.allocator),
    );

    const NotDynamic = struct { Name: KustoDynamic };
    const not_dynamic_decoder = try table.rowDecoder(NotDynamic);
    try std.testing.expectError(
        error.IncompatibleKustoValue,
        not_dynamic_decoder.rowAs(&table.rows[0], std.testing.allocator),
    );

    const LaterFailure = struct {
        Name: []u8,
        Count: bool,
    };
    const later_failure_decoder = try table.rowDecoder(LaterFailure);
    try std.testing.expectError(
        error.IncompatibleKustoValue,
        later_failure_decoder.rowAs(&table.rows[0], std.testing.allocator),
    );

    var duplicate = try decode(
        std.testing.allocator,
        \\{"Tables":[{"TableName":"Duplicate","Columns":[{"ColumnName":"Name","ColumnType":"string"},{"ColumnName":"Name","ColumnType":"string"}],"Rows":[["one","two"]]}]}
    ,
        .{},
        .query,
    );
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expectError(
        error.DuplicateKustoColumn,
        duplicate.dataset.tables[0].rowDecoder(struct { Name: []u8 }),
    );
}

test "typed rows reject missing varying-width cells and schema mismatches" {
    const Row = struct { B: i64 };
    var varying = try decode(
        std.testing.allocator,
        \\{"Tables":[{"TableName":"Rows","Columns":[{"ColumnName":"A","ColumnType":"string"},{"ColumnName":"B","ColumnType":"long"}],"Rows":[["only-a"]]}]}
    ,
        .{ .allow_varying_row_widths = true },
        .query,
    );
    defer varying.deinit(std.testing.allocator);
    const decoder = try varying.dataset.tables[0].rowDecoder(Row);
    try std.testing.expectError(
        error.MissingKustoCell,
        decoder.rowAs(&varying.dataset.tables[0].rows[0], std.testing.allocator),
    );

    var another = try decodeTypedFixture(std.testing.allocator);
    defer another.deinit(std.testing.allocator);
    const name_decoder = try varying.dataset.tables[0].rowDecoder(struct { A: []u8 });
    try std.testing.expectError(
        error.KustoRowSchemaMismatch,
        name_decoder.rowAs(&another.dataset.tables[0].rows[0], std.testing.allocator),
    );
}

test "typed rows support custom conversion hooks and typed iteration" {
    const Row = struct { Name: TypedHook };
    const Decoder = KustoRowDecoder(Row);
    var decoded = try decodeTypedFixture(std.testing.allocator);
    defer decoded.deinit(std.testing.allocator);
    const table = &decoded.dataset.tables[0];
    const decoder = try table.rowDecoder(Row);
    var row = try decoder.rowAs(&table.rows[0], std.testing.allocator);
    defer Decoder.deinitRow(&row, std.testing.allocator);
    try std.testing.expectEqualStrings("Ada", row.Name.text);

    const Failing = struct { Name: FailingTypedHook };
    const failing_decoder = try table.rowDecoder(Failing);
    try std.testing.expectError(
        error.TypedHookRejected,
        failing_decoder.rowAs(&table.rows[0], std.testing.allocator),
    );

    const IteratorRow = struct { Count: i64 };
    const Iterator = KustoTypedRowIterator(IteratorRow);
    var rows = try table.typedRows(IteratorRow, std.testing.allocator);
    var first = (try rows.next()).?;
    defer Iterator.deinitRow(&first, std.testing.allocator);
    var second = (try rows.next()).?;
    defer Iterator.deinitRow(&second, std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 42), first.Count);
    try std.testing.expectEqual(@as(i64, 43), second.Count);
    try std.testing.expect((try rows.next()) == null);
}

fn typedRowAllocationFixture(allocator: std.mem.Allocator) !void {
    const Row = struct {
        Name: []u8,
        Payload: KustoDynamic,
    };
    const Decoder = KustoRowDecoder(Row);
    var decoded = try decodeTypedFixture(allocator);
    defer decoded.deinit(allocator);
    const decoder = try decoded.dataset.tables[0].rowDecoder(Row);
    var row = try decoder.rowAs(&decoded.dataset.tables[0].rows[0], allocator);
    defer Decoder.deinitRow(&row, allocator);
}

test "typed row conversion releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        typedRowAllocationFixture,
        .{},
    );
}

test "ProgressiveDecoder retains only state and preserves append replace completion errors" {
    const allocator = std.testing.allocator;
    var decoder = ProgressiveDecoder.init(allocator, .{}, .query);
    defer decoder.deinit();

    var header = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"DataSetHeader\",\"Version\":\"v2.0\",\"IsProgressive\":true}",
    ));
    defer header.deinit(allocator);
    try std.testing.expectEqualStrings("DataSetHeader", header.frameType());

    var table_header = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"TableHeader\",\"TableId\":7,\"TableKind\":\"PrimaryResult\",\"TableName\":\"T\",\"Columns\":[{\"ColumnName\":\"n\",\"ColumnType\":\"long\"}]}",
    ));
    defer table_header.deinit(allocator);

    var append = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"TableFragment\",\"TableId\":7,\"FieldCount\":1,\"TableFragmentType\":\"DataAppend\",\"Rows\":[[1]]}",
    ));
    defer append.deinit(allocator);
    switch (append.payload) {
        .table_fragment => |batch| {
            try std.testing.expectEqual(ProgressiveTableAction.append, batch.action);
            try std.testing.expectEqual(@as(?i64, 1), batch.table.rows[0].get(0).?.asI64());
        },
        else => return error.TestUnexpectedFrame,
    }

    var replace = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"TableFragment\",\"TableId\":7,\"FieldCount\":1,\"TableFragmentType\":\"DataReplace\",\"Rows\":[]}",
    ));
    defer replace.deinit(allocator);
    switch (replace.payload) {
        .table_fragment => |batch| {
            try std.testing.expectEqual(ProgressiveTableAction.replace, batch.action);
            try std.testing.expectEqual(@as(usize, 0), batch.table.rows.len);
        },
        else => return error.TestUnexpectedFrame,
    }

    var completion = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"TableCompletion\",\"TableId\":7,\"RowCount\":0,\"HasErrors\":true,\"Cancelled\":false,\"OneApiErrors\":[{\"error\":{\"code\":\"Partial\",\"message\":\"partial table\"}}]}",
    ));
    defer completion.deinit(allocator);
    switch (completion.payload) {
        .table_completion => |item| {
            try std.testing.expect(item.failure != null);
            try std.testing.expectEqual(KustoErrorSource.table_completion, item.failure.?.source);
        },
        else => return error.TestUnexpectedFrame,
    }

    var dataset_completion = try decoder.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"DataSetCompletion\",\"HasErrors\":false,\"Cancelled\":false}",
    ));
    defer dataset_completion.deinit(allocator);
    try decoder.finish();
}

test "ProgressiveDecoder rejects out of order and invalid row counts" {
    const allocator = std.testing.allocator;
    var decoder = ProgressiveDecoder.init(allocator, .{}, .query);
    defer decoder.deinit();
    try std.testing.expectError(
        error.MalformedKustoResponse,
        decoder.decodeOwnedFrame(try allocator.dupe(
            u8,
            "{\"FrameType\":\"TableProgress\",\"TableId\":1,\"TableProgress\":50}",
        )),
    );

    var second = ProgressiveDecoder.init(allocator, .{}, .query);
    defer second.deinit();
    var header = try second.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"DataSetHeader\",\"Version\":\"v2.0\",\"IsProgressive\":true}",
    ));
    defer header.deinit(allocator);
    var table = try second.decodeOwnedFrame(try allocator.dupe(
        u8,
        "{\"FrameType\":\"TableHeader\",\"TableId\":1,\"TableKind\":\"PrimaryResult\",\"TableName\":\"T\",\"Columns\":[]}",
    ));
    defer table.deinit(allocator);
    try std.testing.expectError(
        error.MalformedKustoResponse,
        second.decodeOwnedFrame(try allocator.dupe(
            u8,
            "{\"FrameType\":\"TableCompletion\",\"TableId\":1,\"RowCount\":1}",
        )),
    );
}
