//! Mock-only service-client tracing. No Azure credentials, network, or collector.
//! Run: zig build tracing-mock
const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");

const parent_header = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &buffer);
    _ = try run(init.gpa, init.io, &stdout.interface);
    try stdout.interface.flush();
}

/// Returns owned wire IDs so the test can correlate the emitted OTLP spans.
pub fn run(allocator: std.mem.Allocator, io: std.Io, writer: *std.Io.Writer) ![2]core.tracing.TraceContext {
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(io);
    const runtime = core.http.HttpRuntime.init(transport.asTransport(), crypto.asProvider());
    var scratch: [16 * 1024]u8 = undefined;
    var exporter = core.tracing.OtlpJsonWriterExporter.init(writer, &scratch);
    var provider = try core.tracing.ExportingTracerProvider.init(
        allocator,
        io,
        runtime.crypto,
        exporter.asExporter(),
        .{
            .service_name = "blob-tracing-example",
            .max_spans = 2,
            .max_queued_spans = 2,
            .max_scopes = 1,
            .max_batch_size = 1,
        },
    );
    defer provider.deinit() catch unreachable;
    var wire: [2]core.tracing.TraceContext = undefined;
    {
        // User-agent policy is caller-owned and independent of span creation.
        var telemetry = core.http.TelemetryPolicy.init(blobs.user_agent_prefix);
        var policies = [_]*core.http.HttpPolicy{telemetry.asPolicy()};
        var pipeline = core.http.HttpPipeline.init(runtime, &policies);
        pipeline.setInstrumentation(.{
            .provider = provider.asProvider(),
            .scope_name = "azure_sdk_storage_blobs",
            .scope_version = blobs.version,
            .namespace = "Microsoft.Storage",
            .parent_context = core.tracing.TraceContext.extract(parent_header, "demo=mock").?,
        });
        var container = blobs.BlobContainerClient.init(pipeline, .{
            .endpoint = "https://mock.blob.core.windows.net",
            .container_name = "private-container",
        });
        try container.create(allocator);
        wire[0] = try wireContext(&transport);
        var blob = container.getBlobClient("private-blob");
        try blob.upload(allocator, "private-payload", "text/plain");
        wire[1] = try wireContext(&transport);
    }
    // All SDK requests, responses, clients and the copied pipeline are gone.
    // These cooperative budgets do not promise to interrupt arbitrary writers.
    try provider.forceFlush(1000);
    try provider.shutdown(1000);
    if (provider.stats().exported != 2 or transport.call_count != 2)
        return error.UnexpectedSpanOrDispatchCount;
    return wire;
}

fn wireContext(transport: *core.http.MockTransport) !core.tracing.TraceContext {
    const value = transport.last_headers.get("traceparent") orelse return error.MissingTraceparent;
    const context = core.tracing.TraceContext.parseTraceparent(value) orelse return error.InvalidTraceparent;
    if (!std.mem.eql(u8, &context.trace_id, parent_header[3..35]))
        return error.UnexpectedTrace;
    return context;
}

test "mock Blob service operations emit versioned OTLP spans matching W3C wire IDs" {
    var output: [16 * 1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    const wire = try run(std.testing.allocator, std.testing.io, &writer);
    try std.testing.expect(!std.mem.eql(u8, &wire[0].span_id, &wire[1].span_id));
    try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "private-") == null);
    var lines = std.mem.tokenizeScalar(u8, writer.buffered(), '\n');
    for (wire) |context| {
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, lines.next().?, .{});
        defer parsed.deinit();
        const resource = parsed.value.object.get("resourceSpans").?.array.items[0];
        const scoped = resource.object.get("scopeSpans").?.array.items[0];
        const scope = scoped.object.get("scope").?.object;
        try std.testing.expectEqualStrings("azure_sdk_storage_blobs", scope.get("name").?.string);
        try std.testing.expectEqualStrings(blobs.version, scope.get("version").?.string);
        const span = scoped.object.get("spans").?.array.items[0].object;
        try std.testing.expectEqualStrings(&context.trace_id, span.get("traceId").?.string);
        try std.testing.expectEqualStrings(&context.span_id, span.get("spanId").?.string);
        try std.testing.expectEqualStrings(parent_header[36..52], span.get("parentSpanId").?.string);
        try std.testing.expectEqualStrings("demo=mock", span.get("traceState").?.string);
    }
    try std.testing.expect(lines.next() == null);
}
