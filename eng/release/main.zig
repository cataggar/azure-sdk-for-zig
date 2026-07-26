//! Command-line entry point for the package release engine.
//! Port of the release.py CLI.

const std = @import("std");
const engine = @import("engine.zig");
const self_test = @import("self_test.zig");

pub fn main(init: std.process.Init) !u8 {
    const gpa = init.arena.allocator();
    const io = init.io;
    const env = init.environ_map;
    const args = try init.minimal.args.toSlice(gpa);

    if (args.len < 2) {
        usage();
        return 2;
    }
    const command = args[1];

    const root = engine.gitOut(gpa, io, ".", &.{ "rev-parse", "--show-toplevel" }) catch {
        printErr(io, "package-release: not inside a Git repository\n", .{});
        return 1;
    };

    if (std.mem.eql(u8, command, "self-test")) {
        self_test.runSelfTest(gpa, io, env, root) catch |err| {
            printErr(io, "package-release: self-test failed: {s}\n", .{@errorName(err)});
            return 1;
        };
        return 0;
    }

    if (!std.mem.eql(u8, command, "verify") and
        !std.mem.eql(u8, command, "prepare") and
        !std.mem.eql(u8, command, "publish"))
    {
        usage();
        return 2;
    }
    if (args.len < 3) {
        usage();
        return 2;
    }
    const package_name = args[2];

    var remote: []const u8 = env.get("PACKAGE_RELEASE_REMOTE") orelse "origin";
    var dry_run = false;
    if (std.mem.eql(u8, command, "publish")) {
        remote = "origin";
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, arg, "--dry-run")) {
                dry_run = true;
            } else if (std.mem.eql(u8, arg, "--remote")) {
                i += 1;
                if (i >= args.len) {
                    usage();
                    return 2;
                }
                remote = args[i];
            } else if (std.mem.startsWith(u8, arg, "--remote=")) {
                remote = arg["--remote=".len..];
            } else {
                usage();
                return 2;
            }
        }
    }

    const release_root: ?[]const u8 = env.get("PACKAGE_RELEASE_ROOT");

    var eng = engine.Engine.init(gpa, io, root, remote, release_root, env) catch |err| {
        printErr(io, "package-release: {s}\n", .{@errorName(err)});
        return 1;
    };

    const result = dispatch(&eng, command, package_name, dry_run);
    eng.cleanup();
    if (result) |_| {
        return 0;
    } else |err| {
        const message = eng.message orelse @errorName(err);
        printErr(io, "package-release: {s}\n", .{message});
        return 1;
    }
}

fn dispatch(eng: *engine.Engine, command: []const u8, package_name: []const u8, dry_run: bool) !void {
    if (std.mem.eql(u8, command, "verify")) {
        try eng.verify(package_name, true);
    } else if (std.mem.eql(u8, command, "prepare")) {
        try eng.prepare(package_name, true);
    } else {
        _ = try eng.publish(package_name, dry_run);
    }
}

fn usage() void {
    std.debug.print(
        "usage: package-release <verify|prepare|publish|self-test> [package] [--dry-run] [--remote REMOTE]\n",
        .{},
    );
}

fn printErr(io: std.Io, comptime fmt: []const u8, args: anytype) void {
    var buffer: [4096]u8 = undefined;
    var file = std.Io.File.stderr();
    var writer = file.writer(io, &buffer);
    writer.interface.print(fmt, args) catch return;
    writer.interface.flush() catch return;
}
