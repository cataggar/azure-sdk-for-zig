# Azure SDK for Zig

Idiomatic Azure client libraries for Zig 0.16.0 and later.

## SDK Packages

This repository uses mixed source ownership:

- Every SDK and REST package is developed and owned on its package branch;
  `main` carries only shared tooling (`eng/`, `codegen/`, `doc/`, `scripts/`).
- Package consumers use immutable package tags such as
  `azure_sdk_core/v0.1.2`.

See the [package catalog](doc/package-catalog.md) for ownership, branches,
dependencies, and validation commands.

## Documentation

- [Development](doc/development.md)
- [Examples](doc/examples.md)
- [Package branch model](doc/package-branch-model.md)
- [Releasing packages](doc/releasing-packages.md)
- [Package reset record](doc/package-reset-2026-07-24.md)
- [Code generation](codegen/README.md)
- [Contributing](CONTRIBUTING.md)

## License

Licensed under the [MIT License](LICENSE.txt).
