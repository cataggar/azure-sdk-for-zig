const codec = @import("entity_codec.zig");

const InvalidEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    value: bool,

    pub const table = .{
        .rename = .{ .value = "PartitionKey" },
    };
};

comptime {
    _ = codec.EntityCodec(InvalidEntity);
}
