//! Typed query parameters and safe KQL construction.
//!
//! Parameter wrapper values borrow their lexical input during `bind`; the
//! returned `ClientRequestProperties` owns its copied wire values. Query text
//! is never assembled from runtime parameter values.
const std = @import("std");
const serde = @import("serde");
const kusto_common = @import("kusto_common_internal");

pub const ClientRequestProperties = kusto_common.ClientRequestProperties;

/// A borrowed datetime lexical value for a typed query parameter.
pub const DateTime = struct { value: []const u8 };
/// A borrowed timespan lexical value for a typed query parameter.
pub const Timespan = struct { value: []const u8 };
/// A borrowed decimal lexical value for a typed query parameter.
pub const Decimal = struct { value: []const u8 };
/// A borrowed GUID lexical value for a typed query parameter.
pub const Guid = struct { value: []const u8 };

/// Wrap a value which will be JSON-serialized and sent as `dynamic(...)`.
/// This deliberately accepts structured Zig values rather than raw KQL.
pub fn Dynamic(comptime T: type) type {
    return struct {
        value: T,

        pub const __kusto_dynamic_wrapper = true;
    };
}

pub fn dynamic(value: anytype) Dynamic(@TypeOf(value)) {
    return .{ .value = value };
}

const ParameterKind = enum {
    string,
    bool,
    int,
    long,
    real,
    datetime,
    timespan,
    decimal,
    guid,
    dynamic,

    fn declarationType(self: ParameterKind) []const u8 {
        return switch (self) {
            .string => "string",
            .bool => "bool",
            .int => "int",
            .long => "long",
            .real => "real",
            .datetime => "datetime",
            .timespan => "timespan",
            .decimal => "decimal",
            .guid => "guid",
            .dynamic => "dynamic",
        };
    }
};

/// Creates a typed parameter binder for a non-tuple struct.
///
/// The generated `Name` enum is the only accepted runtime parameter-reference
/// type for `Builder.parameter`.
pub fn QueryParameters(comptime T: type) type {
    validateParameterStruct(T);
    const declaration_text = makeDeclaration(T);

    return struct {
        pub const Value = T;
        pub const Name = std.meta.FieldEnum(T);
        pub const declaration = declaration_text;
        pub const __kusto_query_parameters = true;

        /// Copies encoded values into an owned request-property bag.
        pub fn bind(allocator: std.mem.Allocator, values: T) !ClientRequestProperties {
            var properties = ClientRequestProperties{};
            errdefer properties.deinit(allocator);
            inline for (std.meta.fields(T)) |field| {
                try bindField(
                    allocator,
                    &properties,
                    field.name,
                    classifyParameterType(field.name, field.type),
                    @field(values, field.name),
                );
            }
            return properties;
        }

        /// Prepends this binding's deterministic declaration to raw trusted KQL.
        pub fn prepend(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
            return concatenateDeclaration(allocator, declaration_text, query);
        }

        pub fn prependDeclaration(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
            return prepend(allocator, query);
        }
    };
}

/// Appends a deterministic query-parameter declaration to a query allocation.
fn concatenateDeclaration(
    allocator: std.mem.Allocator,
    declaration: []const u8,
    query: []const u8,
) ![]u8 {
    const length = std.math.add(usize, declaration.len, query.len) catch return error.OutOfMemory;
    const result = try allocator.alloc(u8, length);
    @memcpy(result[0..declaration.len], declaration);
    @memcpy(result[declaration.len..], query);
    return result;
}

/// A KQL builder which makes runtime values safe by default.
///
/// `literal` is comptime-only trusted KQL. `unsafeRaw` is intentionally the
/// only runtime method which inserts unescaped query syntax.
pub fn Builder(comptime Binding: type) type {
    validateBinding(Binding);

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        buffer: std.ArrayList(u8) = .empty,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var self = Self{ .allocator = allocator };
            errdefer self.deinit();
            try self.buffer.appendSlice(allocator, Binding.declaration);
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
            self.buffer = .empty;
        }

        /// Appends a comptime-trusted KQL fragment.
        pub fn literal(self: *Self, comptime text: []const u8) !void {
            try self.buffer.appendSlice(self.allocator, text);
        }

        /// Appends a validated bracketed KQL string-name.
        pub fn identifier(self: *Self, value: []const u8) !void {
            if (value.len == 0 or !std.unicode.utf8ValidateSlice(value))
                return error.InvalidKustoIdentifier;
            try self.buffer.appendSlice(self.allocator, "['");
            try self.appendEscaped(value);
            try self.buffer.appendSlice(self.allocator, "']");
        }

        /// Appends a validated single-quoted KQL string literal.
        pub fn string(self: *Self, value: []const u8) !void {
            if (!std.unicode.utf8ValidateSlice(value))
                return error.InvalidKustoString;
            try self.buffer.append(self.allocator, '\'');
            try self.appendEscaped(value);
            try self.buffer.append(self.allocator, '\'');
        }

        /// Appends a declaration-bound parameter reference.
        pub fn parameter(self: *Self, name: Binding.Name) !void {
            try self.buffer.appendSlice(self.allocator, "['");
            try self.buffer.appendSlice(self.allocator, @tagName(name));
            try self.buffer.appendSlice(self.allocator, "']");
        }

        /// Appends runtime KQL without escaping. Prefer every other method.
        pub fn unsafeRaw(self: *Self, value: []const u8) !void {
            try self.buffer.appendSlice(self.allocator, value);
        }

        /// Borrows the completed query bytes until `deinit` or `takeBytes`.
        pub fn bytes(self: *const Self) []const u8 {
            return self.buffer.items;
        }

        /// Transfers the completed query allocation to the caller.
        pub fn takeBytes(self: *Self) ![]u8 {
            const result = try self.buffer.toOwnedSlice(self.allocator);
            self.buffer = .empty;
            return result;
        }

        fn appendEscaped(self: *Self, value: []const u8) !void {
            for (value) |byte| {
                switch (byte) {
                    '\'' => try self.buffer.appendSlice(self.allocator, "\\'"),
                    '\\' => try self.buffer.appendSlice(self.allocator, "\\\\"),
                    '\n' => try self.buffer.appendSlice(self.allocator, "\\n"),
                    '\r' => try self.buffer.appendSlice(self.allocator, "\\r"),
                    '\t' => try self.buffer.appendSlice(self.allocator, "\\t"),
                    0x08 => try self.buffer.appendSlice(self.allocator, "\\b"),
                    0x0c => try self.buffer.appendSlice(self.allocator, "\\f"),
                    else => {
                        if (byte < 0x20 or byte == 0x7f) {
                            const digits = "01234567";
                            const escaped = [_]u8{
                                '\\',
                                digits[(byte >> 6) & 0x07],
                                digits[(byte >> 3) & 0x07],
                                digits[byte & 0x07],
                            };
                            try self.buffer.appendSlice(self.allocator, &escaped);
                        } else {
                            try self.buffer.append(self.allocator, byte);
                        }
                    },
                }
            }
        }
    };
}

fn validateBinding(comptime Binding: type) void {
    if (!@hasDecl(Binding, "__kusto_query_parameters") or
        !@hasDecl(Binding, "Name") or
        !@hasDecl(Binding, "declaration"))
    {
        @compileError("kql.Builder requires a type returned by kql.QueryParameters");
    }
}

fn validateParameterStruct(comptime T: type) void {
    const info = switch (@typeInfo(T)) {
        .@"struct" => |item| item,
        else => @compileError("kql.QueryParameters requires a non-tuple struct"),
    };
    if (info.is_tuple)
        @compileError("kql.QueryParameters requires a non-tuple struct");
    inline for (std.meta.fields(T)) |field| {
        validateParameterName(field.name);
        _ = classifyParameterType(field.name, field.type);
    }
}

fn validateParameterName(comptime name: []const u8) void {
    if (name.len == 0 or !isIdentifierStart(name[0])) {
        @compileError(std.fmt.comptimePrint(
            "Kusto parameter field '{s}' is not a safe Kusto parameter identifier",
            .{name},
        ));
    }
    for (name[1..]) |byte| {
        if (!isIdentifierContinue(byte)) {
            @compileError(std.fmt.comptimePrint(
                "Kusto parameter field '{s}' is not a safe Kusto parameter identifier",
                .{name},
            ));
        }
    }
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
}

fn classifyParameterType(comptime field_name: []const u8, comptime T: type) ParameterKind {
    if (T == DateTime) return .datetime;
    if (T == Timespan) return .timespan;
    if (T == Decimal) return .decimal;
    if (T == Guid) return .guid;
    if (isDynamicWrapper(T)) return .dynamic;
    if (isByteString(T)) return .string;
    if (T == bool) return .bool;
    if (T == i64 or T == u32) return .long;
    if (T == i8 or T == i16 or T == i32 or T == u8 or T == u16) return .int;
    if (T == f32 or T == f64) return .real;
    @compileError(std.fmt.comptimePrint(
        "Kusto parameter field '{s}' has unsupported type {s}; supported types are byte strings, bool, i8/i16/i32/i64, u8/u16/u32, f32/f64, kql.DateTime, kql.Timespan, kql.Decimal, kql.Guid, and kql.dynamic(...)",
        .{ field_name, @typeName(T) },
    ));
}

fn isDynamicWrapper(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "__kusto_dynamic_wrapper");
}

fn isByteString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .array => |array| array.child == u8,
        .pointer => |pointer| switch (pointer.size) {
            .slice => pointer.child == u8,
            .one => switch (@typeInfo(pointer.child)) {
                .array => |array| array.child == u8,
                else => false,
            },
            else => false,
        },
        else => false,
    };
}

fn makeDeclaration(comptime T: type) []const u8 {
    if (std.meta.fields(T).len == 0) return "";
    comptime var result: []const u8 = "declare query_parameters (";
    inline for (std.meta.fields(T), 0..) |field, index| {
        if (index != 0) result = result ++ ", ";
        result = result ++ "['" ++ field.name ++ "']:" ++ classifyParameterType(field.name, field.type).declarationType();
    }
    return result ++ ");\n";
}

fn bindField(
    allocator: std.mem.Allocator,
    properties: *ClientRequestProperties,
    comptime name: []const u8,
    comptime kind: ParameterKind,
    value: anytype,
) !void {
    switch (kind) {
        .string => {
            const text: []const u8 = switch (@typeInfo(@TypeOf(value))) {
                .array => value[0..],
                .pointer => |pointer| switch (pointer.size) {
                    .slice => value,
                    .one => value[0..],
                    else => unreachable,
                },
                else => unreachable,
            };
            if (!std.unicode.utf8ValidateSlice(text))
                return error.InvalidKustoStringParameter;
            const wire = try serializeDynamic(allocator, text);
            defer allocator.free(wire);
            try properties.setParameter(allocator, name, wire);
        },
        .long => {
            const wire = try std.fmt.allocPrint(allocator, "long({d})", .{value});
            defer allocator.free(wire);
            try properties.setParameter(allocator, name, wire);
        },
        .bool => try properties.setParameter(
            allocator,
            name,
            if (value) "bool(true)" else "bool(false)",
        ),
        .int => {
            const wire = try std.fmt.allocPrint(allocator, "int({d})", .{value});
            defer allocator.free(wire);
            try properties.setParameter(allocator, name, wire);
        },
        .real => {
            const wire = try realWireValue(allocator, value);
            defer allocator.free(wire);
            try properties.setParameter(allocator, name, wire);
        },
        .datetime => try bindLexical(allocator, properties, name, "datetime", value.value),
        .timespan => try bindLexical(allocator, properties, name, "timespan", value.value),
        .decimal => try bindLexical(allocator, properties, name, "decimal", value.value),
        .guid => try bindLexical(allocator, properties, name, "guid", value.value),
        .dynamic => {
            const json = try serializeDynamic(allocator, value.value);
            defer allocator.free(json);
            const wire = try std.fmt.allocPrint(allocator, "dynamic({s})", .{json});
            defer allocator.free(wire);
            try properties.setParameter(allocator, name, wire);
        },
    }
}

fn serializeDynamic(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var output: serde.compat.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    serde.json.toWriter(&output.writer, value) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => return err,
    };
    return output.toOwnedSlice() catch error.OutOfMemory;
}

fn bindLexical(
    allocator: std.mem.Allocator,
    properties: *ClientRequestProperties,
    comptime name: []const u8,
    comptime type_name: []const u8,
    value: []const u8,
) !void {
    const wire = try std.fmt.allocPrint(allocator, "{s}({s})", .{ type_name, value });
    defer allocator.free(wire);
    try properties.setParameter(allocator, name, wire);
}

fn realWireValue(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    if (std.math.isNan(value))
        return allocator.dupe(u8, "real(nan)");
    if (std.math.isInf(value))
        return allocator.dupe(u8, if (value < 0) "real(-inf)" else "real(+inf)");
    return std.fmt.allocPrint(allocator, "real({d})", .{value});
}

test "typed query parameters have deterministic declaration and wire values" {
    const Payload = struct { nested: []const u8, values: [2]i32 };
    const Params = struct {
        text: []const u8,
        literal: @TypeOf("literal"),
        bytes: [3]u8,
        signed: i32,
        small_unsigned: u16,
        count: i64,
        wide_unsigned: u32,
        enabled: bool,
        ratio: f64,
        ratio32: f32,
        when: DateTime,
        span: Timespan,
        amount: Decimal,
        id: Guid,
        payload: Dynamic(Payload),
    };
    const Binding = QueryParameters(Params);
    try std.testing.expectEqualStrings(
        "declare query_parameters (['text']:string, ['literal']:string, ['bytes']:string, ['signed']:int, ['small_unsigned']:int, ['count']:long, ['wide_unsigned']:long, ['enabled']:bool, ['ratio']:real, ['ratio32']:real, ['when']:datetime, ['span']:timespan, ['amount']:decimal, ['id']:guid, ['payload']:dynamic);\n",
        Binding.declaration,
    );

    var properties = try Binding.bind(std.testing.allocator, .{
        .text = "a\"b",
        .literal = "literal",
        .bytes = .{ 'x', 'y', 'z' },
        .signed = -2,
        .small_unsigned = 3,
        .count = 4,
        .wide_unsigned = 5,
        .enabled = true,
        .ratio = 1.5,
        .ratio32 = 2.5,
        .when = .{ .value = "2026-01-02T03:04:05Z" },
        .span = .{ .value = "01:02:03" },
        .amount = .{ .value = "12.340" },
        .id = .{ .value = "123e4567-e89b-12d3-a456-426614174000" },
        .payload = dynamic(Payload{ .nested = "a\"b", .values = .{ 1, 2 } }),
    });
    defer properties.deinit(std.testing.allocator);
    const json = try properties.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings(
        "{\"Options\":{},\"Parameters\":{\"text\":\"\\\"a\\\\\\\"b\\\"\",\"literal\":\"\\\"literal\\\"\",\"bytes\":\"\\\"xyz\\\"\",\"signed\":\"int(-2)\",\"small_unsigned\":\"int(3)\",\"count\":\"long(4)\",\"wide_unsigned\":\"long(5)\",\"enabled\":\"bool(true)\",\"ratio\":\"real(1.5)\",\"ratio32\":\"real(2.5)\",\"when\":\"datetime(2026-01-02T03:04:05Z)\",\"span\":\"timespan(01:02:03)\",\"amount\":\"decimal(12.340)\",\"id\":\"guid(123e4567-e89b-12d3-a456-426614174000)\",\"payload\":\"dynamic({\\\"nested\\\":\\\"a\\\\\\\"b\\\",\\\"values\\\":[1,2]})\"}}",
        json,
    );
    const query = try Binding.prepend(std.testing.allocator, "print ['count']");
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings(Binding.declaration ++ "print ['count']", query);
}

test "real parameter special values use valid Kusto literals" {
    const Binding = QueryParameters(struct { value: f64 });
    const values = [_]struct { input: f64, expected: []const u8 }{
        .{ .input = std.math.nan(f64), .expected = "real(nan)" },
        .{ .input = std.math.inf(f64), .expected = "real(+inf)" },
        .{ .input = -std.math.inf(f64), .expected = "real(-inf)" },
    };
    for (values) |item| {
        var properties = try Binding.bind(std.testing.allocator, .{ .value = item.input });
        defer properties.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(item.expected, switch (properties.parameters.items[0].value) {
            .string => |wire| wire,
            else => return error.TestUnexpectedResult,
        });
    }
}

test "string parameter values reject invalid UTF-8" {
    const Binding = QueryParameters(struct { value: []const u8 });
    try std.testing.expectError(
        error.InvalidKustoStringParameter,
        Binding.bind(std.testing.allocator, .{ .value = &[_]u8{0xff} }),
    );
}

test "safe KQL builder escapes runtime values and transfers ownership" {
    const Binding = QueryParameters(struct { value: i64 });
    var builder = try Builder(Binding).init(std.testing.allocator);
    defer builder.deinit();
    try builder.literal("T | where ");
    try builder.identifier("x'] | take 1 //\\\n");
    try builder.literal(" == ");
    try builder.string("a'\\\n\t\x01é");
    try builder.literal(" and x == ");
    try builder.parameter(.value);
    try builder.unsafeRaw(" | take 1");
    try builder.literal(" | project ");
    try builder.identifier("表");
    try std.testing.expectEqualStrings(
        "declare query_parameters (['value']:long);\nT | where ['x\\'] | take 1 //\\\\\\n'] == 'a\\'\\\\\\n\\t\\001é' and x == ['value'] | take 1 | project ['表']",
        builder.bytes(),
    );
    const owned = try builder.takeBytes();
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualStrings(
        "declare query_parameters (['value']:long);\nT | where ['x\\'] | take 1 //\\\\\\n'] == 'a\\'\\\\\\n\\t\\001é' and x == ['value'] | take 1 | project ['表']",
        owned,
    );
    try std.testing.expectEqual(@as(usize, 0), builder.bytes().len);
    try std.testing.expectError(error.InvalidKustoIdentifier, builder.identifier(""));
    try std.testing.expectError(error.InvalidKustoIdentifier, builder.identifier(&[_]u8{0xff}));
    try std.testing.expectError(error.InvalidKustoString, builder.string(&[_]u8{0xff}));
}

test "empty parameter bindings omit the declaration" {
    const Binding = QueryParameters(struct {});
    try std.testing.expectEqualStrings("", Binding.declaration);
    var properties = try Binding.bind(std.testing.allocator, .{});
    defer properties.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), properties.parameters.items.len);

    var builder = try Builder(Binding).init(std.testing.allocator);
    defer builder.deinit();
    try builder.literal("print 1");
    try std.testing.expectEqualStrings("print 1", builder.bytes());
}

fn bindAllocationFixture(allocator: std.mem.Allocator) !void {
    const Payload = struct { values: [2]i32 };
    const Binding = QueryParameters(struct {
        text: []const u8,
        payload: Dynamic(Payload),
    });
    var properties = try Binding.bind(allocator, .{
        .text = "value",
        .payload = dynamic(Payload{ .values = .{ 1, 2 } }),
    });
    defer properties.deinit(allocator);
    const query = try Binding.prepend(allocator, "print text");
    defer allocator.free(query);
}

test "query binding releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        bindAllocationFixture,
        .{},
    );
}

fn builderAllocationFixture(allocator: std.mem.Allocator) !void {
    const Binding = QueryParameters(struct { value: i64 });
    var builder = try Builder(Binding).init(allocator);
    defer builder.deinit();
    try builder.identifier("quotes' slash\\ and newline\n");
    try builder.string("text\x01");
}

test "KQL builder releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        builderAllocationFixture,
        .{},
    );
}
