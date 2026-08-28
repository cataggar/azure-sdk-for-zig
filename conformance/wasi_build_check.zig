const core = @import("azure_sdk_core");

comptime {
    _ = core.http.wasi.WasiHttpTransport;
}

export fn azureSdkCoreWasiBuildCheck() void {}
