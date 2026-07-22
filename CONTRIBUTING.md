# Contributing to Azure SDK for Zig

## Prerequisites

- [Zig 0.15.2](https://ziglang.org/download/) or later

## Building and Testing

```bash
zig build                     # compile SDK + example
zig build test --summary all  # run all tests
zig build run                 # run the example app
```

## Code Style

- Run `zig fmt sdk/ build.zig` before committing — CI enforces this
- Follow Zig naming conventions: `camelCase` for functions/variables, `PascalCase` for types
- Add `///` doc comments to all public declarations
- Keep files focused: one client or module per file

## Module Structure

```
sdk/
├── core/               # Foundation: HTTP, pipeline, credentials, utilities
│   ├── http/           # Transport, pipeline, policies, decompression
│   ├── credentials/    # TokenCredential interface, caching
│   ├── cloud.zig       # Sovereign cloud configurations
│   ├── pager.zig       # Generic pagination (Pager, PipelinePager)
│   ├── lro.zig         # Long-running operation poller
│   ├── testing/        # Test framework (recording/playback)
│   └── ...             # URL, UUID, DateTime, Base64, XML, errors
├── identity/           # Credential implementations
├── storage/            # Blob, Queue, Files, DataLake, Common
├── keyvault/           # Secrets, Keys, Certificates, Administration
├── data/               # Tables, App Configuration
├── messaging/          # Event Hubs
├── attestation/        # Attestation
└── examples/           # Example applications
```

## Adding a New Service SDK

1. Create `sdk/<service>/<subservice>/root.zig`
2. Import `azure_sdk_core` for HTTP pipeline, credentials, errors
3. Define models (request/response structs)
4. Implement the client struct with CRUD operations
5. Add tests using `MockTransport` or `SequenceMockTransport`
6. Register the module in `build.zig` (add `b.addModule(...)` and test step)
7. For paginated list operations, use `PipelinePager(T)` from `azure_sdk_core.pager`

## Interface Pattern

The SDK uses function-pointer structs for interfaces (like `std.mem.Allocator`):

```zig
pub const MyInterface = struct {
    doWorkFn: *const fn (self: *MyInterface, ...) anyerror!Result,

    pub fn doWork(self: *MyInterface, ...) !Result {
        return self.doWorkFn(self, ...);
    }
};

pub const MyImpl = struct {
    interface: MyInterface,
    // ... fields ...

    pub fn init(...) MyImpl {
        return .{ .interface = .{ .doWorkFn = &doWorkImpl }, ... };
    }

    pub fn asInterface(self: *MyImpl) *MyInterface {
        return &self.interface;
    }

    fn doWorkImpl(iface: *MyInterface, ...) anyerror!Result {
        const self: *MyImpl = @fieldParentPtr("interface", iface);
        // ... implementation ...
    }
};
```

## Testing

- All tests use `std.testing.allocator` to detect memory leaks
- Use `MockTransport` for single-response tests
- Use `SequenceMockTransport` for multi-step flows (retry, pagination)
- Use `PlaybackTransport` for recorded HTTP exchange replay
- Use `RecordingTransport` to capture live HTTP exchanges

## Pull Request Process

1. Fork and create a feature branch
2. Make changes, add tests
3. Run `zig fmt sdk/ build.zig`
4. Run `zig build test --summary all` — all tests must pass
5. Submit PR against the `zig` branch
