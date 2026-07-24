# Azure SDK for Zig

Idiomatic Azure client libraries for Zig 0.16.0 and later.

## SDK Packages

This repository uses mixed source ownership:

- `main` owns the five Core-family packages under `sdk/core`.
- Every other SDK and REST package is developed on its package branch.
- Package consumers use immutable package tags such as
  `azure_sdk_core/v0.1.0`.

See the [package catalog](doc/package-catalog.md) for ownership, branches,
dependencies, and validation commands.

## Documentation

- [Development](doc/development.md)
- [Package branch model](doc/package-branch-model.md)
- [Releasing packages](doc/releasing-packages.md)
- [Package reset record](doc/package-reset-2026-07-24.md)
- [Code generation](codegen/README.md)
- [Contributing](CONTRIBUTING.md)

## License

Licensed under the [MIT License](LICENSE.txt).
