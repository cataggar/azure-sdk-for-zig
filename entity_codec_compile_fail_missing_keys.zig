const codec = @import("entity_codec.zig");

const InvalidEntity = struct {
    name: []const u8,
};

comptime {
    _ = codec.EntityCodec(InvalidEntity);
}
