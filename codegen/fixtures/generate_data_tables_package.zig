const std = @import("std");
const emitter = @import("emit");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var args: std.process.Args.Iterator = try .initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.skip();
    const output_path = args.next() orelse return error.MissingOutputPath;
    var azure_sdk_core_commit: ?[]const u8 = null;
    var azure_sdk_core_hash: ?[]const u8 = null;
    var azure_sdk_core_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--azure-sdk-core-commit")) {
            azure_sdk_core_commit = args.next() orelse return error.MissingAzureSdkCoreCommit;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-hash")) {
            azure_sdk_core_hash = args.next() orelse return error.MissingAzureSdkCoreHash;
        } else if (std.mem.eql(u8, arg, "--azure-sdk-core-path")) {
            azure_sdk_core_path = args.next() orelse return error.MissingAzureSdkCorePath;
        } else {
            return error.UnexpectedArgument;
        }
    }
    if ((azure_sdk_core_commit == null) != (azure_sdk_core_hash == null)) {
        return error.IncompleteAzureSdkCorePin;
    }
    if (azure_sdk_core_commit != null and azure_sdk_core_path != null) {
        return error.ConflictingAzureSdkCoreDependency;
    }

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
        .azure_sdk_core_commit = azure_sdk_core_commit,
        .azure_sdk_core_hash = azure_sdk_core_hash,
        .azure_sdk_core_path = azure_sdk_core_path orelse "../../sdk/core",
    });
    const zon = try output.readFileAlloc(
        io,
        "build.zig.zon",
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(zon);
    const zon_with_license = try addLicensePath(allocator, zon);
    defer allocator.free(zon_with_license);
    try output.writeFile(io, .{
        .sub_path = "build.zig.zon",
        .data = zon_with_license,
    });
    const license = try std.Io.Dir.readFileAlloc(
        .cwd(),
        io,
        "../../LICENSE.txt",
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(license);
    try output.writeFile(io, .{
        .sub_path = "LICENSE.txt",
        .data = license,
    });
    try output.writeFile(io, .{
        .sub_path = "src/clients_test.zig",
        .data = generated_tests,
    });
    try output.writeFile(io, .{
        .sub_path = "README.md",
        .data = generated_readme,
    });
}

fn addLicensePath(allocator: std.mem.Allocator, zon: []const u8) ![]u8 {
    const marker = "        \"README.md\",\n";
    const index = std.mem.indexOf(u8, zon, marker) orelse
        return error.MissingReadmePath;
    const insertion = marker ++ "        \"LICENSE.txt\",\n";
    const result = try allocator.alloc(
        u8,
        zon.len - marker.len + insertion.len,
    );
    @memcpy(result[0..index], zon[0..index]);
    @memcpy(result[index .. index + insertion.len], insertion);
    @memcpy(
        result[index + insertion.len ..],
        zon[index + marker.len ..],
    );
    return result;
}

const generated_readme =
    \\# Azure Tables REST for Zig
    \\
    \\`azure_rest_data_tables` is the generated Azure Tables protocol package for
    \\the stable **2019-02-02** TypeSpec contract. It is entirely
    \\generator-owned; update the fixture or emitter and regenerate instead of
    \\editing package files by hand.
    \\
    \\## Protocol surface
    \\
    \\The package exposes `TablesClient`, `Table`, and `Service`, covering all
    \\14 canonical operations, JSON and XML wire models, enum values, response
    \\headers, exact alternate statuses, and continuation headers. It preserves
    \\the TypeSpec's OData entity records and literal-query routes.
    \\
    \\The source contract is
    \\[`specification/cosmos-db/data-plane/Tables/tspconfig.yaml`](https://github.com/Azure/azure-rest-api-specs/tree/0744f52a86919d243ba2225e55bdb9c87bf521a5/specification/cosmos-db/data-plane/Tables).
    \\The directory is historical; this package has no Cosmos-specific runtime
    \\behavior. The selected TypeSpec has no `$batch` operation.
    \\
    \\## Build and regeneration
    \\
    \\```bash
    \\zig build test --summary all
    \\```
    \\
    \\The manifest pins `azure_sdk_core` by immutable release commit and Zig
    \\package hash. The `.azure-sdk-generator` provenance file records the
    \\generator revision and reproducible generation command.
    \\
;

const generated_tests =
    \\const std = @import("std");
    \\const clients = @import("clients.zig");
    \\const models = @import("models.zig");
    \\
    \\test "all fourteen stable Tables operations are directly accessible" {
    \\    try expectPublicMethods(clients.TablesClient, &.{ "table", "service" });
    \\    try expectPublicMethods(clients.Table, &.{
    \\        "query",
    \\        "create",
    \\        "delete",
    \\        "queryEntities",
    \\        "queryEntityWithPartitionAndRowKey",
    \\        "updateEntity",
    \\        "mergeEntity",
    \\        "deleteEntity",
    \\        "insertEntity",
    \\        "getAccessPolicy",
    \\        "setAccessPolicy",
    \\    });
    \\    try expectPublicMethods(clients.Service, &.{
    \\        "setProperties",
    \\        "getProperties",
    \\        "getStatistics",
    \\    });
    \\    try std.testing.expect(@hasDecl(models, "TableServiceProperties"));
    \\    try std.testing.expect(@hasDecl(models, "TableServiceStats"));
    \\}
    \\
    \\fn expectPublicMethods(comptime Client: type, comptime methods: []const []const u8) !void {
    \\    inline for (methods) |method| {
    \\        try std.testing.expect(@hasDecl(Client, method));
    \\    }
    \\}
    \\
;
