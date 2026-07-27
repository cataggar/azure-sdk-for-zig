#!/bin/sh
# Verify that the pinned Azure Tables TypeSpec remains the current stable
# contract. This intentionally does not substitute a generic Storage version.
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_repository=https://github.com/Azure/azure-rest-api-specs.git
source_commit=0744f52a86919d243ba2225e55bdb9c87bf521a5
source_path=specification/cosmos-db/data-plane/Tables
expected_version=2019-02-02

latest_commit=$(git ls-remote "$source_repository" refs/heads/main | awk '{print $1}')
if [ "$latest_commit" != "$source_commit" ]; then
    echo "Azure Tables TypeSpec changed: pinned $source_commit, upstream $latest_commit" >&2
    exit 1
fi

config=$(curl --fail --silent --show-error --location \
    "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/$source_commit/$source_path/tspconfig.yaml")
main=$(curl --fail --silent --show-error --location \
    "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/$source_commit/$source_path/main.tsp")
routes=$(curl --fail --silent --show-error --location \
    "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/$source_commit/$source_path/routes.tsp")

printf '%s\n' "$config" | grep -Fq 'service-dir'
versions=$(printf '%s\n' "$main" |
    awk -F'"' '/^[[:space:]]*v[0-9][0-9][0-9][0-9]_[0-9][0-9]_[0-9][0-9]:/ { print $2 }' |
    sort -u)
if [ "$versions" != "$expected_version" ]; then
    echo "expected only stable Tables version $expected_version; found: $versions" >&2
    exit 1
fi
if printf '%s\n' "$routes" | grep -Fq '$batch'; then
    echo "canonical TypeSpec now models \$batch; move it out of the hand-written SDK layer" >&2
    exit 1
fi
grep -Fq "pub const latest_api_version = \"$expected_version\";" \
    "$repository_root/options.zig"
grep -Fq "#67d001426e73385a944a1bacde8d482b81dbf5ae" \
    "$repository_root/build.zig.zon"

printf '%s\n' "Azure Tables TypeSpec is current at $source_commit ($expected_version; \$batch absent)."
