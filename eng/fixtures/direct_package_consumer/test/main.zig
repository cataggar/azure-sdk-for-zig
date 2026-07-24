const std = @import("std");
const core = @import("azure_sdk_core");

test "direct package consumer compiles" {
    try std.testing.expect(@sizeOf(core.http.Request) > 0);
}
