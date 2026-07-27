const std = @import("std");
const edm = @import("edm.zig");

/// Azure Tables permits 255 properties total. PartitionKey, RowKey, and the
/// service Timestamp reserve three slots for every entity.
pub const max_custom_properties = 252;

/// A runtime-typed Table property. Dynamic entities own all values placed in
/// their property map and release them through `DynamicEntity.deinit`.
pub const EdmValue = union(enum) {
    null,
    boolean: bool,
    int32: i32,
    float64: f64,
    string: []const u8,
    binary: edm.EdmBinary,
    datetime: edm.EdmDateTime,
    guid: edm.EdmGuid,
    int64: edm.EdmInt64,

    pub fn clone(self: EdmValue, allocator: std.mem.Allocator) !EdmValue {
        return switch (self) {
            .null, .boolean, .int32, .float64, .int64 => self,
            .string => |value| .{ .string = try allocator.dupe(u8, value) },
            .binary => |value| .{ .binary = .{ .bytes = try allocator.dupe(u8, value.bytes) } },
            .datetime => |value| blk: {
                _ = try edm.EdmDateTime.init(value.value);
                break :blk .{ .datetime = .{ .value = try allocator.dupe(u8, value.value) } };
            },
            .guid => |value| blk: {
                _ = try edm.EdmGuid.init(value.value);
                break :blk .{ .guid = .{ .value = try allocator.dupe(u8, value.value) } };
            },
        };
    }

    pub fn deinit(self: *EdmValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |value| allocator.free(value),
            .binary => |value| allocator.free(value.bytes),
            .datetime => |value| allocator.free(value.value),
            .guid => |value| allocator.free(value.value),
            else => {},
        }
        self.* = .null;
    }
};

/// A runtime-schema entity. This is the dynamic escape hatch for callers whose
/// property schema is not known at compile time.
pub const DynamicEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    timestamp: ?edm.EdmDateTime = null,
    properties: std.StringHashMap(EdmValue),
    allocator: std.mem.Allocator,

    /// Copies both keys. Values later supplied to `put` are copied as well.
    pub fn init(allocator: std.mem.Allocator, partition_key: []const u8, row_key: []const u8) !DynamicEntity {
        const copied_partition_key = try allocator.dupe(u8, partition_key);
        errdefer allocator.free(copied_partition_key);
        return .{
            .partition_key = copied_partition_key,
            .row_key = try allocator.dupe(u8, row_key),
            .properties = std.StringHashMap(EdmValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn put(self: *DynamicEntity, key: []const u8, value: EdmValue) !void {
        try validatePropertyName(key);
        const copied_value = try value.clone(self.allocator);
        errdefer {
            var value_to_free = copied_value;
            value_to_free.deinit(self.allocator);
        }

        if (self.properties.getPtr(key)) |existing| {
            existing.deinit(self.allocator);
            existing.* = copied_value;
            return;
        }

        const copied_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(copied_key);
        try self.properties.put(copied_key, copied_value);
    }

    pub fn setTimestamp(self: *DynamicEntity, value: ?edm.EdmDateTime) !void {
        if (value) |datetime| _ = try edm.EdmDateTime.init(datetime.value);
        const copied = if (value) |datetime| try self.allocator.dupe(u8, datetime.value) else null;
        if (self.timestamp) |old| self.allocator.free(old.value);
        self.timestamp = if (copied) |datetime| .{ .value = datetime } else null;
    }

    pub fn deinit(self: *DynamicEntity) void {
        var it = self.properties.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.properties.deinit();
        self.allocator.free(self.partition_key);
        self.allocator.free(self.row_key);
        if (self.timestamp) |datetime| self.allocator.free(datetime.value);
    }
};

pub fn validatePropertyName(name: []const u8) !void {
    if (name.len == 0 or name.len > 255) return error.InvalidPropertyName;
    if (!isIdentifierStart(name[0])) return error.InvalidPropertyName;
    for (name[1..]) |c| {
        if (!isIdentifierContinue(c)) return error.InvalidPropertyName;
    }
    if (std.mem.eql(u8, name, "PartitionKey") or
        std.mem.eql(u8, name, "RowKey") or
        std.mem.eql(u8, name, "Timestamp"))
    {
        return error.ReservedPropertyName;
    }
}

fn isIdentifierStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isIdentifierContinue(c: u8) bool {
    return isIdentifierStart(c) or std.ascii.isDigit(c);
}

/// A string-only table entity retained for 0.1.0 compatibility.
///
/// The map allocates its bookkeeping with `allocator`, but all keys and values
/// are borrowed. They must outlive the entity or be removed before their
/// backing storage is released. Call `deinit` to release the map allocation.
pub const TableEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    properties: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, partition_key: []const u8, row_key: []const u8) TableEntity {
        return .{
            .partition_key = partition_key,
            .row_key = row_key,
            .properties = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Adds borrowed key and value slices.
    pub fn put(self: *TableEntity, key: []const u8, value: []const u8) !void {
        try self.properties.put(key, value);
    }

    pub fn deinit(self: *TableEntity) void {
        self.properties.deinit();
    }
};

test "TableEntity init and put" {
    const allocator = std.testing.allocator;
    var table_entity = TableEntity.init(allocator, "pk1", "rk1");
    defer table_entity.deinit();
    try table_entity.put("Name", "Alice");
    try std.testing.expectEqualStrings("Alice", table_entity.properties.get("Name").?);
}

test "DynamicEntity owns copied property values" {
    const allocator = std.testing.allocator;
    var entity = try DynamicEntity.init(allocator, "pk1", "rk1");
    defer entity.deinit();
    try entity.put("Count", .{ .int64 = .{ .value = 42 } });
    try entity.put("Name", .{ .string = "Alice" });
    try std.testing.expectEqual(@as(i64, 42), entity.properties.get("Count").?.int64.value);
    try std.testing.expectEqualStrings("Alice", entity.properties.get("Name").?.string);
}

fn testDynamicEntityAllocationFailures(allocator: std.mem.Allocator) !void {
    var value = try DynamicEntity.init(allocator, "partition", "row");
    defer value.deinit();
    try value.put("Name", .{ .string = "example" });
    try value.put("Payload", .{ .binary = .{ .bytes = "bytes" } });
    try value.setTimestamp(try edm.EdmDateTime.init("2026-07-27T00:00:00Z"));
}

test "DynamicEntity allocation failures are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testDynamicEntityAllocationFailures,
        .{},
    );
}
