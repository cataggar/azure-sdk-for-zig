#!/bin/sh
# Regenerate into a disposable directory under the supplied pinned codegen
# worktree, then compare its exact output with the REST package worktree.
set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <codegen-worktree> <rest-package-worktree>" >&2
    exit 64
fi

codegen_worktree=$1
rest_worktree=$2
generator_commit=c83a1cbef5f728d7530fdec4a724cc453233cfa4
core_commit=bc77bcacbb64af935ca53d60bf8a351c9592bc41
core_hash=azure_sdk_core-0.3.0-eFY0Ev0-CACjsFaYPL6jS7CpeVNvsqYqTrXRfgQKiRFV
output="$codegen_worktree/.release/data_tables-regeneration-check"

if [ "$(git -C "$codegen_worktree" rev-parse HEAD)" != "$generator_commit" ]; then
    echo "codegen worktree must be pinned at $generator_commit" >&2
    exit 1
fi
if ! grep -Fq "generator_commit=$generator_commit" \
    "$rest_worktree/.azure-sdk-generator"; then
    echo "REST package provenance does not match the pinned generator" >&2
    exit 1
fi
if ! grep -Fq "source_commit=0744f52a86919d243ba2225e55bdb9c87bf521a5" \
    "$rest_worktree/.azure-sdk-generator"; then
    echo "REST package provenance does not match the verified TypeSpec" >&2
    exit 1
fi

mkdir -p "$(dirname "$output")"
rm -rf "$output"
trap 'rm -rf "$output"' EXIT HUP INT TERM
(
    cd "$codegen_worktree/codegen/cli"
    zig build \
        -Ddata-tables-output="$output" \
        -Dazure-sdk-core-commit="$core_commit" \
        -Dazure-sdk-core-hash="$core_hash" \
        generate-data-tables-package
)
for path in .gitignore build.zig build.zig.zon LICENSE.txt README.md src; do
    diff -ru "$rest_worktree/$path" "$output/$path"
done
printf '%s\n' "Azure Tables REST regeneration is deterministic."
