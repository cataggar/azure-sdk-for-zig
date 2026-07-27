const codec = @import("entity_codec.zig");

const InvalidEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    timestamp: []const u8,
};

comptime {
    _ = codec.EntityCodec(InvalidEntity);
}
