//! Explicit opt-in Kusto Data and Ingest live tests.

test {
    _ = @import("data/live_test.zig");
    _ = @import("ingest/live_test.zig");
}
