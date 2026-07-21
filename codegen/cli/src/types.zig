//! Maps TCGC `TypeRef` values to Zig source-level type expressions.

const std = @import("std");
const cm = @import("codemodel");

pub const Scope = enum {
    /// `clients.zig` — model refs go through `models.`, enum refs go
    /// through `enums.`.
    clients,
    /// `models.zig` — model refs stay bare, enum refs go through
    /// `enums.`.
    models,
    /// `enums.zig` — no cross-references expected.
    enums,
};

pub fn renderType(
    allocator: std.mem.Allocator,
    t: cm.TypeRef,
    scope: Scope,
) std.mem.Allocator.Error![]u8 {
    if (t.isOption()) {
        const inner = try renderTypeFromValue(allocator, t.value, scope);
        defer allocator.free(inner);
        return std.fmt.allocPrint(allocator, "?{s}", .{inner});
    }
    if (t.isArray()) {
        const inner = try renderTypeFromValue(allocator, t.value, scope);
        defer allocator.free(inner);
        return std.fmt.allocPrint(allocator, "[]const {s}", .{inner});
    }
    if (t.isMap()) {
        const inner = try renderTypeFromValue(allocator, t.value, scope);
        defer allocator.free(inner);
        return std.fmt.allocPrint(allocator, "std.json.ArrayHashMap({s})", .{inner});
    }
    if (t.isModel()) {
        if (t.namedTypeName()) |n| {
            return switch (scope) {
                .clients => std.fmt.allocPrint(allocator, "models.{s}", .{n}),
                .models, .enums => allocator.dupe(u8, n),
            };
        }
        return allocator.dupe(u8, "std.json.Value");
    }
    if (t.isEnum()) {
        if (t.namedTypeName()) |n| {
            return switch (scope) {
                .clients, .models => std.fmt.allocPrint(allocator, "enums.{s}", .{n}),
                .enums => allocator.dupe(u8, n),
            };
        }
        return allocator.dupe(u8, "std.json.Value");
    }
    if (std.mem.eql(u8, t.kind, "Union")) {
        if (t.namedTypeName()) |n| return allocator.dupe(u8, n);
        return allocator.dupe(u8, "std.json.Value");
    }
    if (t.isScalar()) {
        return try renderScalar(allocator, t.scalarName() orelse "unknown", scope);
    }
    return allocator.dupe(u8, "std.json.Value");
}

fn renderTypeFromValue(
    allocator: std.mem.Allocator,
    v: std.json.Value,
    scope: Scope,
) std.mem.Allocator.Error![]u8 {
    // Nested TypeRef arrives as an object {kind, value}.
    switch (v) {
        .object => |o| {
            const kind = o.get("kind") orelse return allocator.dupe(u8, "std.json.Value");
            const value = o.get("value") orelse return allocator.dupe(u8, "std.json.Value");
            const nested = cm.TypeRef{
                .kind = switch (kind) {
                    .string => |s| s,
                    else => "Scalar",
                },
                .value = value,
            };
            return try renderType(allocator, nested, scope);
        },
        else => return try allocator.dupe(u8, "std.json.Value"),
    }
}

fn renderScalar(
    allocator: std.mem.Allocator,
    name: []const u8,
    scope: Scope,
) ![]u8 {
    if (std.mem.eql(u8, name, "unknown")) {
        return try allocator.dupe(u8, switch (scope) {
            .clients => "models.JsonValue",
            .models, .enums => "JsonValue",
        });
    }
    const mapping = [_]struct { []const u8, []const u8 }{
        .{ "string", "[]const u8" },
        .{ "bool", "bool" },
        .{ "bytes", "[]const u8" },
        .{ "url", "[]const u8" },
        .{ "datetime", "[]const u8" },
        .{ "duration", "[]const u8" },
        .{ "decimal", "[]const u8" },
        .{ "endpoint", "[]const u8" },
        .{ "credential", "[]const u8" },
        .{ "int8", "i8" },
        .{ "int16", "i16" },
        .{ "int32", "i32" },
        .{ "int64", "i64" },
        .{ "uint8", "u8" },
        .{ "uint16", "u16" },
        .{ "uint32", "u32" },
        .{ "uint64", "u64" },
        .{ "float32", "f32" },
        .{ "float64", "f64" },
        .{ "safeint", "i64" },
        .{ "integer", "i64" },
        .{ "numeric", "f64" },
        .{ "float", "f64" },
    };
    for (mapping) |m| {
        if (std.mem.eql(u8, name, m[0])) {
            return try allocator.dupe(u8, m[1]);
        }
    }
    return try allocator.dupe(u8, "[]const u8");
}
