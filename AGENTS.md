# AGENTS.md — AI Agent Guidelines

This document provides guidance for AI agents (Copilot, etc.) working on this repository.

## Build & Test Commands

```bash
zig build                     # compile SDK + example
zig build test --summary all  # run all tests (must pass before committing)
zig fmt sdk/ examples/ build.zig        # format code (CI enforces this)
zig fmt --check sdk/ examples/ build.zig # check formatting without modifying
```

## Repository Structure

- `sdk/core/` — Core framework (HTTP pipeline, credentials, pager, LRO, utilities)
- `sdk/identity/` — Credential implementations (CLI, client secret, managed identity, etc.)
- `sdk/storage/` — Azure Storage clients (blobs, queues, files)
- `sdk/keyvault/` — Azure Key Vault clients (secrets, keys, certificates)
- `sdk/data/` — Data services (Tables, App Configuration)
- `sdk/messaging/` — Messaging services (Event Hubs)
- `sdk/attestation/` — Azure Attestation
- `build.zig` — Build configuration (modules, tests, dependencies)
- `build.zig.zon` — Package dependencies

## Naming Conventions

- **Types/structs**: `PascalCase` (e.g., `SecretClient`, `BlobProperties`)
- **Functions/methods**: `camelCase` (e.g., `getSecret`, `listBlobs`)
- **Constants**: `snake_case` (e.g., `azure_public`, `user_agent_prefix`)
- **Files**: `snake_case.zig` (e.g., `client_secret.zig`, `azure_cli.zig`)
- **Modules in build.zig**: `snake_case` with `azure_` prefix (e.g., `azure_core`, `azure_identity`)

## Key Patterns

### Interface Pattern
Use function-pointer structs with `@fieldParentPtr` for runtime polymorphism.
See: `TokenCredential`, `HttpTransport`, `HttpPolicy`, `Pager`.

### Service Client Pattern
Each service client:
1. Stores `pipeline: core.pipeline.HttpPipeline` by value
2. Takes `credential` and `transport` in `init()`
3. Builds URLs with `buildUrl()` or `std.fmt.allocPrint()`
4. Uses `pipeline.send(&req)` for HTTP calls
5. Returns parsed domain objects (not raw responses)

### Pagination Pattern
List operations return `PipelinePager(T)` with a service-specific parse function.
See: `SecretClient.listSecrets()`, `KeyClient.listKeys()`.

### Error Handling
- Return `anyerror` from interface fn pointers
- Return specific errors from service operations (e.g., `error.SecretNotFound`)
- Use `core.errors.errorFromResponse(resp)` for Azure error JSON parsing

## What NOT to Do

- Do not add C dependencies — the SDK must remain pure Zig
- Do not modify test infrastructure without running the full test suite
- Do not hardcode credentials or secrets in source files
- Do not break existing public API signatures without justification
- Do not skip `zig fmt` — CI will reject unformatted code

## Dependencies

Only two external Zig packages (keep it minimal):

| Package | Purpose |
|---------|---------|
| [serde.zig](https://github.com/cataggar/serde.zig) | Typed JSON + XML (de)serialization |
| [azure-uamqp-zig](https://github.com/cataggar/azure-uamqp-zig) | AMQP 1.0 for Event Hubs |

Everything else comes from `std` (HTTP, TLS, crypto, base64).
