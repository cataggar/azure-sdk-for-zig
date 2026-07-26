const std = @import("std");
const codec = @import("entity_codec.zig");
const edm = @import("edm.zig");

fn boundaryEntity(comptime custom_count: usize) type {
    const field_count = 3 + custom_count;
    var names: [field_count][:0]const u8 = undefined;
    var types: [field_count]type = undefined;
    const attributes: [field_count]std.builtin.Type.StructField.Attributes = @splat(.{});
    names[0] = "partition_key";
    types[0] = []const u8;
    names[1] = "row_key";
    types[1] = []const u8;
    inline for (0..custom_count) |index| {
        names[2 + index] = std.fmt.comptimePrint("optional_property_{d}", .{index});
        types[2 + index] = ?bool;
    }
    names[field_count - 1] = "timestamp";
    types[field_count - 1] = ?edm.EdmDateTime;
    return @Struct(.auto, null, &names, &types, &attributes);
}

comptime {
    @setEvalBranchQuota(2_000_000);
    _ = codec.EntityCodec(boundaryEntity(253));
}
