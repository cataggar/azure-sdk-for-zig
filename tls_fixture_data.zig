//! Build-only generation of public deterministic test material. No HTTPX TLS
//! module or provider ABI is compiled into this std-only helper executable.
const std = @import("std");
const fixtures = @import("httpx_test_certificates");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedFixtureOutputDirectory;
    var directory = try std.Io.Dir.cwd().createDirPathOpen(init.io, args[1], .{});
    defer directory.close(init.io);
    var chain = try fixtures.Chain.init(init.gpa, .ecdsa_p256);
    defer chain.deinit();
    const other_key = try fixtures.Key.init(.ecdsa_p256, 9);
    var other_options = fixtures.rootOptions();
    other_options.subject = "Unrelated Fixture Root";
    other_options.issuer = "Unrelated Fixture Root";
    const other_root = try fixtures.certificate(init.gpa, other_key, other_key, other_options);
    defer init.gpa.free(other_root);
    try directory.writeFile(init.io, .{ .sub_path = "other.der", .data = other_root });
    try directory.writeFile(init.io, .{ .sub_path = "root.der", .data = chain.root });
    try directory.writeFile(init.io, .{ .sub_path = "intermediate.der", .data = chain.intermediate });
    try directory.writeFile(init.io, .{ .sub_path = "leaf.der", .data = chain.leaf });
    try directory.writeFile(init.io, .{ .sub_path = "leaf.raw", .data = &chain.leaf_key.ecdsa_p256.secret_key.toBytes() });
    try directory.writeFile(init.io, .{
        .sub_path = "fixtures.zig",
        .data =
        \\//! Public deterministic test certificates and test-only key, not credentials.
        \\pub const root = @embedFile("root.der");
        \\pub const intermediate = @embedFile("intermediate.der");
        \\pub const leaf = @embedFile("leaf.der");
        \\pub const leaf_key = @embedFile("leaf.raw");
        \\pub const other_root = @embedFile("other.der");
        \\
        ,
    });
}
