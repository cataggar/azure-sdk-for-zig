# azure_sdk aggregate

`azure_sdk` is the convenience aggregate over all independently versioned
Azure SDK for Zig packages.

The aggregate is released from `sdk/aggregate`, starts at `0.1.0`, and exposes
only canonical module names such as `azure_sdk_core` and
`azure_sdk_storage_blobs`. It does not expose old module aliases.

Consumers should choose either:

- direct package dependencies for the smallest dependency graph; or
- this aggregate for one dependency containing every canonical module.

Do not mix direct and aggregate instances of the same package in one build.
The aggregate package-local build is introduced after all implementation
packages have been extracted.
