const codec = @import("entity_codec.zig");

const InvalidEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    count: u64,
};

comptime {
    _ = codec.EntityCodec(InvalidEntity);
}
