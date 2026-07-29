//! Azure SDK Performance Framework — benchmark harness.
//!
//! Measures wall-clock nanoseconds and, optionally, allocation counts.
//!
//! Timing reads `std.Io.Timestamp` on the `.awake` monotonic clock, so every
//! caller must supply a `std.Io`. Use `std.testing.io` in tests.
const std = @import("std");

/// Collected metrics from a benchmark run.
///
/// Two different clocks are recorded. `sum_ns` adds up the per-iteration laps
/// and is what `avgNs` and `opsPerSecond` report, so those two agree with each
/// other. `total_ns` is wall-clock for the whole run and additionally includes
/// the harness's own per-iteration timer reads, so it is always the larger of
/// the two; compare it against `sum_ns` to see how much overhead the harness
/// itself contributed.
///
/// Each lap costs two clock reads (tens of nanoseconds on a typical host), so
/// `min_ns` has a floor of roughly one clock read and measurements of
/// operations that fast should not be trusted in absolute terms. Increase the
/// work per iteration until `sum_ns` dominates that floor.
///
/// `allocations` and `bytes_allocated` are zero unless the benchmark ran
/// through `benchmarkAllocating`.
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    sum_ns: u64,
    allocations: u64 = 0,
    bytes_allocated: u64 = 0,
    /// Iterations whose closure returned an error. A benchmark that fails
    /// early looks deceptively fast, so callers should check this is zero
    /// before trusting the timings.
    errors: u64 = 0,

    pub fn avgNs(self: BenchmarkResult) u64 {
        if (self.iterations == 0) return 0;
        return self.sum_ns / self.iterations;
    }

    /// Throughput implied by the measured work, excluding harness overhead.
    /// This is the reciprocal of `avgNs`; use `total_ns` for elapsed time.
    pub fn opsPerSecond(self: BenchmarkResult) f64 {
        if (self.sum_ns == 0) return 0;
        const iters: f64 = @floatFromInt(self.iterations);
        const secs: f64 = @as(f64, @floatFromInt(self.sum_ns)) / 1_000_000_000.0;
        return iters / secs;
    }

    pub fn allocationsPerOp(self: BenchmarkResult) f64 {
        if (self.iterations == 0) return 0;
        return @as(f64, @floatFromInt(self.allocations)) /
            @as(f64, @floatFromInt(self.iterations));
    }

    pub fn bytesPerOp(self: BenchmarkResult) f64 {
        if (self.iterations == 0) return 0;
        return @as(f64, @floatFromInt(self.bytes_allocated)) /
            @as(f64, @floatFromInt(self.iterations));
    }
};

/// Wraps an allocator and counts the allocations made through it.
///
/// Counting is deliberately restricted to events that obtain *new* memory:
///
/// - `alloc` counts only when the parent returns a pointer. A failed
///   allocation obtained nothing.
/// - `resize` never counts. It grows or shrinks an existing allocation in
///   place and issues no new one.
/// - `remap` counts only when it succeeds *and* moves the allocation. A remap
///   that succeeds in place is a resize; a remap that returns `null` obtained
///   nothing, and `std.mem.Allocator` then falls back to `alloc` + copy +
///   `free`, which `alloc` counts. Counting the failure too would report the
///   same event twice.
pub const CountingAllocator = struct {
    parent: std.mem.Allocator,
    count: u64 = 0,
    bytes: u64 = 0,

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    pub fn init(parent: std.mem.Allocator) CountingAllocator {
        return .{ .parent = parent };
    }

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    /// Clears the counters without disturbing the parent allocator, so a
    /// warm-up pass can be excluded from a measurement.
    pub fn reset(self: *CountingAllocator) void {
        self.count = 0;
        self.bytes = 0;
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, alignment, ret_addr);
        if (result != null) {
            self.count += 1;
            self.bytes += len;
        }
        return result;
    }

    fn resize(
        ctx: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(
        ctx: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawRemap(memory, alignment, new_len, ret_addr);
        if (result) |ptr| {
            if (ptr != memory.ptr) {
                self.count += 1;
                self.bytes += new_len;
            }
        }
        return result;
    }

    fn free(
        ctx: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(memory, alignment, ret_addr);
    }
};

/// Reads the monotonic clock that keeps running while the process sleeps.
pub fn nowNs(io: std.Io) i96 {
    return std.Io.Timestamp.now(io, .awake).nanoseconds;
}

fn elapsedSince(io: std.Io, start: i96) u64 {
    const delta = nowNs(io) - start;
    if (delta <= 0) return 0;
    return @intCast(delta);
}

/// Runs `func` `iterations` times and collects wall-clock timing stats.
pub fn benchmark(
    io: std.Io,
    name: []const u8,
    iterations: u64,
    comptime func: anytype,
) BenchmarkResult {
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    var sum_ns: u64 = 0;
    var errors: u64 = 0;

    const start = nowNs(io);

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const lap_start = nowNs(io);
        func() catch {
            errors += 1;
        };
        const elapsed = elapsedSince(io, lap_start);
        sum_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = elapsedSince(io, start),
        .min_ns = if (iterations > 0) min_ns else 0,
        .max_ns = max_ns,
        .sum_ns = sum_ns,
        .errors = errors,
    };
}

/// Runs `func(allocator)` `iterations` times, collecting timing stats and
/// counting the allocations `func` makes.
///
/// `func` receives a counting wrapper around `parent`; it must free whatever
/// it allocates, since the wrapper only observes.
pub fn benchmarkAllocating(
    io: std.Io,
    name: []const u8,
    iterations: u64,
    parent: std.mem.Allocator,
    comptime func: anytype,
) BenchmarkResult {
    var counting = CountingAllocator.init(parent);
    const allocator = counting.allocator();

    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;
    var sum_ns: u64 = 0;
    var errors: u64 = 0;

    const start = nowNs(io);

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const lap_start = nowNs(io);
        func(allocator) catch {
            errors += 1;
        };
        const elapsed = elapsedSince(io, lap_start);
        sum_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = elapsedSince(io, start),
        .min_ns = if (iterations > 0) min_ns else 0,
        .max_ns = max_ns,
        .sum_ns = sum_ns,
        .allocations = counting.count,
        .bytes_allocated = counting.bytes,
        .errors = errors,
    };
}

/// Prints a benchmark result to stderr.
pub fn printResult(result: BenchmarkResult) void {
    std.debug.print(
        "BENCH {s}: {d} iters, avg {d}ns, min {d}ns, max {d}ns, {d:.0} ops/s, {d:.2} allocs/op, {d:.0} B/op{s}\n",
        .{
            result.name,
            result.iterations,
            result.avgNs(),
            result.min_ns,
            result.max_ns,
            result.opsPerSecond(),
            result.allocationsPerOp(),
            result.bytesPerOp(),
            if (result.errors > 0) " [ERRORS]" else "",
        },
    );
    if (result.errors > 0) {
        std.debug.print(
            "  WARNING: {d} of {d} iterations returned an error; timings are not meaningful\n",
            .{ result.errors, result.iterations },
        );
    }
}

fn dummyWork() !void {
    var x: u64 = 0;
    for (0..100) |i| x +%= i;
    std.mem.doNotOptimizeAway(x);
}

fn allocatingWork(allocator: std.mem.Allocator) !void {
    const buf = try allocator.alloc(u8, 64);
    defer allocator.free(buf);
    @memset(buf, 7);
    std.mem.doNotOptimizeAway(buf.ptr);
}

test "benchmark measures wall-clock time" {
    const result = benchmark(std.testing.io, "dummy", 1000, dummyWork);
    try std.testing.expectEqual(@as(u64, 1000), result.iterations);
    try std.testing.expect(result.total_ns > 0);
    try std.testing.expect(result.min_ns <= result.max_ns);
    try std.testing.expect(result.opsPerSecond() > 0);
    try std.testing.expectEqual(@as(u64, 0), result.allocations);
}

test "benchmark elapsed time grows with work" {
    const Work = struct {
        fn spin(comptime rounds: usize) fn () anyerror!void {
            return struct {
                fn run() anyerror!void {
                    var x: u64 = 0;
                    for (0..rounds) |i| x +%= i *% 2654435761;
                    std.mem.doNotOptimizeAway(x);
                }
            }.run;
        }
    };
    const small = benchmark(std.testing.io, "small", 200, Work.spin(64));
    const large = benchmark(std.testing.io, "large", 200, Work.spin(64 * 512));
    try std.testing.expect(large.total_ns > small.total_ns);
}

test "benchmarkAllocating counts allocations" {
    const result = benchmarkAllocating(
        std.testing.io,
        "alloc",
        100,
        std.testing.allocator,
        allocatingWork,
    );
    try std.testing.expectEqual(@as(u64, 100), result.iterations);
    try std.testing.expectEqual(@as(u64, 100), result.allocations);
    try std.testing.expectEqual(@as(u64, 6400), result.bytes_allocated);
    try std.testing.expectEqual(@as(f64, 1), result.allocationsPerOp());
    try std.testing.expectEqual(@as(f64, 64), result.bytesPerOp());
}

test "CountingAllocator counts allocations but not resizes" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    const buf = try allocator.alloc(u8, 32);
    defer allocator.free(buf);
    try std.testing.expectEqual(@as(u64, 1), counting.count);
    try std.testing.expectEqual(@as(u64, 32), counting.bytes);

    _ = allocator.resize(buf, 16);
    try std.testing.expectEqual(@as(u64, 1), counting.count);

    counting.reset();
    try std.testing.expectEqual(@as(u64, 0), counting.count);
    try std.testing.expectEqual(@as(u64, 0), counting.bytes);
}

test "CountingAllocator forwards to the parent allocator" {
    var counting = CountingAllocator.init(std.testing.allocator);
    const allocator = counting.allocator();

    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(allocator);
    for (0..256) |i| try list.append(allocator, @intCast(i));

    try std.testing.expectEqual(@as(usize, 256), list.items.len);
    try std.testing.expectEqual(@as(u32, 255), list.items[255]);
    try std.testing.expect(counting.count > 0);
}

test "CountingAllocator ignores a failed remap" {
    var buf: [512]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var counting = CountingAllocator.init(fba.allocator());
    const allocator = counting.allocator();

    const first = try allocator.alloc(u8, 16);
    const second = try allocator.alloc(u8, 16);
    try std.testing.expectEqual(@as(u64, 2), counting.count);

    // `first` is not the last allocation, so the fixed buffer cannot grow it
    // and cannot move it either. Nothing was obtained, so nothing is counted;
    // std falls back to alloc+copy+free, and that alloc is what counts.
    try std.testing.expect(allocator.remap(first, 32) == null);
    try std.testing.expectEqual(@as(u64, 2), counting.count);
    try std.testing.expectEqual(@as(u64, 32), counting.bytes);

    // `second` is the last allocation, so this remap succeeds in place. An
    // in-place remap is a resize, not a new allocation.
    const grown = allocator.remap(second, 24);
    try std.testing.expect(grown != null);
    try std.testing.expectEqual(second.ptr, grown.?.ptr);
    try std.testing.expectEqual(@as(u64, 2), counting.count);
    try std.testing.expectEqual(@as(u64, 32), counting.bytes);
}

test "CountingAllocator ignores a failed allocation" {
    var buf: [64]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var counting = CountingAllocator.init(fba.allocator());
    const allocator = counting.allocator();

    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 4096));
    try std.testing.expectEqual(@as(u64, 0), counting.count);
    try std.testing.expectEqual(@as(u64, 0), counting.bytes);
}

test "CountingAllocator matches ground truth through ArrayList growth" {
    var truth = TruthAllocator{ .parent = std.testing.allocator };
    var counting = CountingAllocator.init(truth.allocator());
    const allocator = counting.allocator();

    var list: std.ArrayList(u64) = .empty;
    defer list.deinit(allocator);
    for (0..2000) |i| try list.append(allocator, @intCast(i));

    try std.testing.expectEqual(@as(usize, 2000), list.items.len);
    try std.testing.expectEqual(truth.real_allocations, counting.count);
}

/// Records only the allocation events that actually obtained new memory,
/// observed below `CountingAllocator` so the two can be compared.
const TruthAllocator = struct {
    parent: std.mem.Allocator,
    real_allocations: u64 = 0,

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = talloc,
        .resize = tresize,
        .remap = tremap,
        .free = tfree,
    };

    fn allocator(self: *TruthAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn talloc(ctx: *anyopaque, len: usize, a: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *TruthAllocator = @ptrCast(@alignCast(ctx));
        const r = self.parent.rawAlloc(len, a, ra);
        if (r != null) self.real_allocations += 1;
        return r;
    }

    fn tresize(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) bool {
        const self: *TruthAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(m, a, n, ra);
    }

    fn tremap(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, n: usize, ra: usize) ?[*]u8 {
        const self: *TruthAllocator = @ptrCast(@alignCast(ctx));
        const r = self.parent.rawRemap(m, a, n, ra);
        if (r) |p| {
            if (p != m.ptr) self.real_allocations += 1;
        }
        return r;
    }

    fn tfree(ctx: *anyopaque, m: []u8, a: std.mem.Alignment, ra: usize) void {
        const self: *TruthAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(m, a, ra);
    }
};

test "benchmark records failing iterations" {
    const Failing = struct {
        fn run() !void {
            return error.Boom;
        }
    };
    const result = benchmark(std.testing.io, "failing", 10, Failing.run);
    try std.testing.expectEqual(@as(u64, 10), result.errors);
    try std.testing.expectEqual(@as(u64, 10), result.iterations);
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
    try std.testing.expectEqual(@as(f64, 0), r.allocationsPerOp());
    try std.testing.expectEqual(@as(f64, 0), r.bytesPerOp());
}
