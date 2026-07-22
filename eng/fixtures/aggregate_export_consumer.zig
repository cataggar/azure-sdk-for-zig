const fixture = @import("fixture_module");

test "dependency module can be exported without a facade" {
    try @import("std").testing.expectEqual(@as(u32, 0xa2_5d_16), fixture.marker);
}
