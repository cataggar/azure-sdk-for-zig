const codec = @import("entity_codec.zig");

const InvalidEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    first: bool,
    second: i32,

    pub const table = .{
        .rename = .{
            .first = "Same",
            .second = "Same",
        },
    };
};

comptime {
    _ = codec.EntityCodec(InvalidEntity);
}
