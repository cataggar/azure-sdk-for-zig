#!/usr/bin/env bash
# Patch the fetched azure_sdk for wasm32 support.
#
# azure_core's `BearerTokenAuthPolicy` reconstructs itself from its embedded
# `HttpPolicy` vtable via `@fieldParentPtr`. On 64-bit targets everything is
# 8-aligned so this is fine, but on wasm32 the function-pointer vtable is
# 4-aligned while the struct needs 8-alignment (it has an `i64` field), so the
# compiler rejects `@fieldParentPtr` with "increases pointer alignment".
#
# The fix is a one-line `@alignCast` (the struct is always heap/stack-allocated
# at its natural alignment, so the assertion is sound). This belongs UPSTREAM in
# cataggar/azure-sdk-for-zig (sdk/core/http/pipeline.zig); until then we patch
# the fetched copy. Idempotent — safe to run repeatedly.
set -euo pipefail
cd "$(dirname "$0")"

shopt -s nullglob
found=0
for f in zig-pkg/azure_sdk-*/sdk/core/http/pipeline.zig; do
    found=1
    if grep -q '@alignCast(@fieldParentPtr("policy", policy))' "$f"; then
        echo "already patched: $f"
        continue
    fi
    sed -i \
        's|@fieldParentPtr("policy", policy)|@alignCast(@fieldParentPtr("policy", policy))|g' \
        "$f"
    echo "patched: $f"
done

if [[ "$found" -eq 0 ]]; then
    echo "note: azure_sdk not fetched yet; run 'zig build --fetch' first" >&2
fi
