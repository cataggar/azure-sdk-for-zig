//! Upload a file through a complete, service-issued Blob SAS URL.
//!
//! Usage:
//!   zig build complete-sas-upload -- <blob-sas-url> <file>

const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const sas_url = args.next() orelse return error.MissingBlobSasUrl;
    const file_path = args.next() orelse return error.MissingFilePath;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var client = try blobs.SasBlobClient.init(
        allocator,
        sas_url,
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.uploadFile(file_path, .{});
    var buffer: [512]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &buffer);
    defer stdout.interface.flush() catch {};
    try stdout.interface.print("{f}\n", .{outcome});
}
