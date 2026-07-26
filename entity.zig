const std = @import("std");

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
