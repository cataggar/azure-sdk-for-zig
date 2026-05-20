//! Naming-convention helpers used by the emitter.
//!
//! Conventions (per AGENTS.md):
//!  * Types / structs : PascalCase
//!  * Functions       : camelCase
//!  * File names      : snake_case
//!  * Zig identifiers : snake_case for fields and locals

const std = @import("std");

/// Convert `snake_case` → `PascalCase`. Input is consumed as-is for
/// already-PascalCase inputs (e.g. `WidgetSuite` stays `WidgetSuite`).
pub fn toPascalCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    var upper_next = true;
    for (input) |c| {
        if (c == '_' or c == '-' or c == ' ') {
            upper_next = true;
            continue;
        }
        if (upper_next) {
            try buf.append(allocator, std.ascii.toUpper(c));
            upper_next = false;
        } else {
            try buf.append(allocator, c);
        }
    }
    return try buf.toOwnedSlice(allocator);
}

/// Convert any input to `camelCase`.
pub fn toCamelCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const pascal = try toPascalCase(allocator, input);
    if (pascal.len == 0) return pascal;
    pascal[0] = std.ascii.toLower(pascal[0]);
    return pascal;
}

/// Convert anything to `snake_case`. Already-snake input is unchanged.
pub fn toSnakeCase(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);
    var prev_lower = false;
    var prev_upper = false;
    for (input, 0..) |c, i| {
        if (c == '-' or c == ' ') {
            try buf.append(allocator, '_');
            prev_lower = false;
            prev_upper = false;
            continue;
        }
        if (std.ascii.isUpper(c)) {
            const needs_underscore = (prev_lower) or
                (prev_upper and i + 1 < input.len and std.ascii.isLower(input[i + 1]));
            if (needs_underscore and buf.items.len > 0 and
                buf.items[buf.items.len - 1] != '_')
                try buf.append(allocator, '_');
            try buf.append(allocator, std.ascii.toLower(c));
            prev_upper = true;
            prev_lower = false;
        } else {
            try buf.append(allocator, c);
            prev_lower = std.ascii.isLower(c);
            prev_upper = false;
        }
    }
    return try buf.toOwnedSlice(allocator);
}

test "toSnakeCase" {
    const a = std.testing.allocator;
    {
        const s = try toSnakeCase(a, "WidgetSuite");
        defer a.free(s);
        try std.testing.expectEqualStrings("widget_suite", s);
    }
    {
        const s = try toSnakeCase(a, "KeyVaultClient");
        defer a.free(s);
        try std.testing.expectEqualStrings("key_vault_client", s);
    }
    {
        const s = try toSnakeCase(a, "already_snake");
        defer a.free(s);
        try std.testing.expectEqualStrings("already_snake", s);
    }
}

test "toPascalCase" {
    const a = std.testing.allocator;
    {
        const s = try toPascalCase(a, "azure_security_keyvault_secrets");
        defer a.free(s);
        try std.testing.expectEqualStrings("AzureSecurityKeyvaultSecrets", s);
    }
}

test "toCamelCase" {
    const a = std.testing.allocator;
    {
        const s = try toCamelCase(a, "get_secret");
        defer a.free(s);
        try std.testing.expectEqualStrings("getSecret", s);
    }
}
