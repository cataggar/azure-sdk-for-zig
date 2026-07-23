const std = @import("std");
const ingest = @import("azure_sdk_kusto_ingest");

test "direct package consumer compiles" {
    try std.testing.expect(@sizeOf(ingest.StreamingIngestTarget) > 0);
}
