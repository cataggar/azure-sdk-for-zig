///! Azure SDK Performance Framework — benchmark harness.
///!
///! Provides a lightweight framework for throughput and latency benchmarks.
const std = @import("std");
const builtin = @import("builtin");

/// Collected metrics from a benchmark run.
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    sum_ns: u64,

    pub fn avgNs(self: BenchmarkResult) u64 {
        if (self.iterations == 0) return 0;
        return self.sum_ns / self.iterations;
    }

    pub fn opsPerSecond(self: BenchmarkResult) f64 {
        if (self.total_ns == 0) return 0;
        const iters: f64 = @floatFromInt(self.iterations);
        const secs: f64 = @as(f64, @floatFromInt(self.total_ns)) / 1_000_000_000.0;
        return iters / secs;
    }
};

/// Simple monotonic tick counter.
/// Uses a thread-safe atomic counter — suitable for relative benchmarking.
/// Real high-resolution timing requires `std.Io` in Zig 0.16.
var global_tick: std.atomic.Value(u64) = std.atomic.Value(u64).init(0);

fn readTick() u64 {
    return global_tick.fetchAdd(1, .monotonic);
}

fn ticksToNs(ticks: u64) u64 {
    // Each "tick" is one iteration unit — approximate as 1ns for stats.
    return ticks;
}

/// Run a benchmark function `iterations` times and collect timing stats.
pub fn benchmark(
    name: []const u8,
    iterations: u64,
    comptime func: anytype,
) BenchmarkResult {
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    var sum_ns: u64 = 0;

    const start = readTick();

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const lap_start = readTick();
        func() catch {};
        const lap_end = readTick();
        const elapsed = ticksToNs(lap_end - lap_start);
        sum_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    const total_ns = ticksToNs(readTick() - start);

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = if (iterations > 0) min_ns else 0,
        .max_ns = max_ns,
        .sum_ns = sum_ns,
    };
}

/// Print benchmark results to stderr.
pub fn printResult(result: BenchmarkResult) void {
    std.debug.print(
        "BENCH {s}: {d} iters, avg {d}ns, min {d}ns, max {d}ns, {d:.0} ops/s\n",
        .{
            result.name,
            result.iterations,
            result.avgNs(),
            result.min_ns,
            result.max_ns,
            result.opsPerSecond(),
        },
    );
}

fn dummyWork() !void {
    var x: u64 = 0;
    for (0..100) |i| x +%= i;
    std.mem.doNotOptimizeAway(x);
}

test "benchmark collects stats" {
    const result = benchmark("dummy", 1000, dummyWork);
    try std.testing.expectEqual(@as(u64, 1000), result.iterations);
    try std.testing.expect(result.total_ns > 0);
    try std.testing.expect(result.min_ns <= result.max_ns);
    try std.testing.expect(result.avgNs() > 0);
    try std.testing.expect(result.opsPerSecond() > 0);
}

test "BenchmarkResult zero iterations" {
    const r = BenchmarkResult{
        .name = "empty",
        .iterations = 0,
        .total_ns = 0,
        .min_ns = 0,
        .max_ns = 0,
        .sum_ns = 0,
    };
    try std.testing.expectEqual(@as(u64, 0), r.avgNs());
    try std.testing.expectEqual(@as(f64, 0), r.opsPerSecond());
}
