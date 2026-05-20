//! ARM (Azure Resource Manager) resource concept.
//!
//! Zig has no struct inheritance, so generated ARM models use the
//! "copy-down" strategy: every leaf resource struct redeclares the
//! fields it inherits from `Resource` / `TrackedResource` /
//! `ExtensionResource`. To still allow generic helpers like "get the id
//! of any resource" or "set tags on any tracked resource", each
//! generated resource struct declares
//!
//!     pub const arm_resource_kind: core.arm.ResourceKind = .tracked;
//!
//! and the helpers in this file dispatch on that marker plus comptime
//! `@hasField` checks. The pattern is the same flavor of comptime
//! parametricity used by `core.pager.Pager(T)`, but without runtime fn
//! pointers — accessors are monomorphized per concrete `T` and compile
//! down to plain field loads.

const std = @import("std");

/// Which ARM base type a generated resource derives from.
///
/// The set mirrors the base types in `Azure.ResourceManager`:
///
/// * `proxy`     — `ProxyResource` (id/name/type/systemData only)
/// * `tracked`   — `TrackedResource` (proxy + location/tags)
/// * `extension` — `ExtensionResource` (proxy + extends parent scope)
///
/// Resources that don't fit (rare; usually pre-ARM data-plane shapes)
/// simply omit the `arm_resource_kind` decl.
pub const ResourceKind = enum { proxy, tracked, extension };

fn requireFields(comptime T: type, comptime fields: []const []const u8) void {
    comptime {
        for (fields) |f| {
            if (!@hasField(T, f))
                @compileError(@typeName(T) ++ " is not an ARM resource: missing field '" ++ f ++ "'");
        }
    }
}

/// Comptime contract check: `T` carries the four ARM identity fields
/// (`id`, `name`, `type`, `system_data`).
///
/// Note: `type` is not a reserved Zig keyword, so the emitter uses it
/// as a bare field name (matching what TCGC produces from its
/// `serializedName`).
pub fn assertResource(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "arm_resource_kind"))
            @compileError(@typeName(T) ++ " is not an ARM resource (no arm_resource_kind decl)");
        requireFields(T, &.{ "id", "name", "type", "system_data" });
    }
}

/// Comptime contract check: `T` is a TrackedResource — Resource plus
/// `location` and `tags`.
pub fn assertTrackedResource(comptime T: type) void {
    comptime {
        assertResource(T);
        if (T.arm_resource_kind != .tracked)
            @compileError(@typeName(T) ++ " is not a TrackedResource (arm_resource_kind != .tracked)");
        requireFields(T, &.{ "location", "tags" });
    }
}

/// Get the ARM resource id of any resource.
pub fn id(res: anytype) ?[]const u8 {
    assertResource(@TypeOf(res.*));
    return res.id;
}

/// Get the ARM resource name of any resource.
pub fn name(res: anytype) ?[]const u8 {
    assertResource(@TypeOf(res.*));
    return res.name;
}

/// Get the ARM resource type (e.g. `Microsoft.AVS/privateClouds`).
pub fn typeName(res: anytype) ?[]const u8 {
    assertResource(@TypeOf(res.*));
    return res.type;
}

/// Get the ARM region of any TrackedResource.
pub fn location(res: anytype) ?[]const u8 {
    assertTrackedResource(@TypeOf(res.*));
    return res.location;
}

/// Replace the tags map on any TrackedResource.
pub fn setTags(res: anytype, tags: anytype) void {
    assertTrackedResource(@TypeOf(res.*));
    res.tags = tags;
}

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;

const FakeTracked = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    type: ?[]const u8 = null,
    system_data: ?u8 = null,
    location: ?[]const u8 = null,
    tags: ?u8 = null,
    extra: u32 = 0,

    pub const arm_resource_kind: ResourceKind = .tracked;
};

const FakeProxy = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    type: ?[]const u8 = null,
    system_data: ?u8 = null,

    pub const arm_resource_kind: ResourceKind = .proxy;
};

test "Resource accessors compile and read the marked fields" {
    var r = FakeTracked{
        .id = "/subscriptions/s/resources/r",
        .name = "r",
        .type = "Microsoft.AVS/privateClouds",
        .location = "westus",
    };
    try testing.expectEqualStrings("/subscriptions/s/resources/r", id(&r).?);
    try testing.expectEqualStrings("r", name(&r).?);
    try testing.expectEqualStrings("Microsoft.AVS/privateClouds", typeName(&r).?);
    try testing.expectEqualStrings("westus", location(&r).?);

    setTags(&r, @as(?u8, 42));
    try testing.expectEqual(@as(?u8, 42), r.tags);
}

test "Resource accessors work on a proxy resource (no location)" {
    var r = FakeProxy{ .id = "/p/q", .name = "q" };
    try testing.expectEqualStrings("/p/q", id(&r).?);
    try testing.expectEqualStrings("q", name(&r).?);
    // location(&r) would be a compile error: FakeProxy is not a TrackedResource.
}

test "assertResource/assertTrackedResource accept the matching kinds" {
    assertResource(FakeProxy);
    assertResource(FakeTracked);
    assertTrackedResource(FakeTracked);
    // assertTrackedResource(FakeProxy) would be a compile error.
}
