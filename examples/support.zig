const std = @import("std");
const tables = @import("azure_sdk_data_tables");

pub const ExampleEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    name: []const u8,
    count: i32,
    timestamp: ?tables.EdmDateTime = null,
};

comptime {
    _ = tables.EntityCodec(ExampleEntity);
}

pub fn required(
    env: *const std.process.Environ.Map,
    name: []const u8,
) ![]const u8 {
    const value = env.get(name) orelse return error.ExampleEnvironmentRequired;
    if (value.len == 0) return error.ExampleEnvironmentRequired;
    return value;
}

pub fn enabled(env: *const std.process.Environ.Map, name: []const u8) bool {
    return if (env.get(name)) |value| std.mem.eql(u8, value, "1") else false;
}
