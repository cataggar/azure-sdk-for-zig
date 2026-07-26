const std = @import("std");
const emitter = @import("emit");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.skip();
    const output_path = args.next() orelse return error.MissingOutputPath;

    var parsed = try std.json.parseFromSlice(
        emitter.CodeModel,
        allocator,
        @embedFile("data_tables.json"),
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const parent_path = std.fs.path.dirname(output_path) orelse ".";
    const directory_name = std.fs.path.basename(output_path);
    var parent = if (std.fs.path.isAbsolute(output_path))
        try std.Io.Dir.openDirAbsolute(io, parent_path, .{})
    else
        try std.Io.Dir.cwd().createDirPathOpen(io, parent_path, .{});
    defer parent.close(io);
    if (std.mem.eql(u8, directory_name, ".") or
        std.mem.eql(u8, directory_name, ".."))
    {
        return error.InvalidOutputPath;
    }
    try parent.deleteTree(io, directory_name);
    var output = try parent.createDirPathOpen(io, directory_name, .{});
    defer output.close(io);

    try emitter.emit(allocator, io, output, parsed.value, .{
        .package_name = "azure_rest_data_tables",
        .display_name = "data-tables",
        .azure_sdk_core_path = "../../sdk/core",
    });
    try output.writeFile(io, .{
        .sub_path = "src/clients_test.zig",
        .data =
        \\const std = @import("std");
        \\const clients = @import("clients.zig");
        \\const models = @import("models.zig");
        \\
        \\test "generated Tables declarations compile" {
        \\    try std.testing.expect(@hasDecl(clients, "Table"));
        \\    try std.testing.expect(@hasDecl(models, "TableServiceProperties"));
        \\}
        \\
        ,
    });
}
