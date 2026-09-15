const std = @import("std");
const production = @import("build.zig");

pub fn build(b: *std.Build) void {
    production.build(b);
    const receipt_step = b.step("static-core-receipt", "Record the existing Core test artifact without executing it");
    const test_step = b.top_level_steps.get("test-compile") orelse {
        receipt_step.dependOn(&b.addFail("Core receipt requires the production native test configuration").step);
        return;
    };
    if (test_step.step.dependencies.items.len != 1)
        @panic("production test-compile graph changed");
    const core = test_step.step.dependencies.items[0].cast(std.Build.Step.Compile) orelse
        @panic("production test-compile does not identify one compile artifact");
    const source = core.root_module.root_source_file orelse @panic("Core test source missing");
    if (!core.kind.isTest() or !std.mem.eql(u8, source.getPath(b), b.pathFromRoot("root.zig")))
        @panic("receipt does not identify the production Core test");

    // Resolve the compiler-reported generated file even on a cache hit; never scan caches.
    const receipt = b.addSystemCommand(&.{
        "python3", "-B", ".github/scripts/static_core_terminal.py", "receipt",
    });
    receipt.addFileArg(core.getEmittedBin());
    receipt.has_side_effects = true;
    receipt_step.dependOn(&receipt.step);
}
