# Package reset: 2026-07-24

Reset `package-reset-2026-07-24-global-r3` moved all 18 non-Core packages
from `main` to protected package branches while preserving reviewed file
history. The five Core-family packages remain Main-owned. Exact machine-readable
ref targets and artifact digests are in
[`eng/package_provenance/package-reset-2026-07-24.json`](../eng/package_provenance/package-reset-2026-07-24.json).

## Sealed input and tooling

- Sealed Main commit: `2f34b8ce949a23245187664a04765b0029d87d9b`
- `git-filter-repo`: 2.47.0, reported version `a40bce548d2c`
- Sealed migration manifest SHA-256:
  `189c7a07b8292b3de5293316315bb7086404ab0676d23efb1cc52cddeb3c0a03`
- Candidate artifact index SHA-256:
  `d38bbc8ea9fad7920d103da6c26eaf1713d4a8cfecf86591a6a4ee3c0dcd9408`
- Reviewed history-map SHA-256:
  `d2c2721ebef923799e56529fab860d5087212c43993fee0fe8c74fc1efb51991`

## Production package refs

Each package branch and its `v0.1.0` tag point to the same commit.

| Package | Branch | Commit |
| --- | --- | --- |
| `azure_rest_arm_avs` | `rest/arm_avs` | `fe7662a3416f599794c10d038854262bf22a664a` |
| `azure_rest_keyvault_secrets` | `rest/keyvault_secrets` | `7716ae63671f26a39bf8338dde48c7e4c3bb6304` |
| `azure_rest_container_registry` | `rest/container_registry` | `70cf5bf1e8155fc9a5ae23206a6b092c2182d21b` |
| `azure_sdk_container_registry` | `sdk/container_registry` | `c99143953fb06be5aada15ccae807162d0fc3524` |
| `azure_sdk_storage_common` | `sdk/storage_common` | `93be9fdd48cefa1f30023c5b852f89193671988c` |
| `azure_sdk_storage_blobs` | `sdk/storage_blobs` | `4f1e3c0e3ed14df68956af442cd401ac2974b362` |
| `azure_sdk_storage_queues` | `sdk/storage_queues` | `fa33ee1b6a02f6dc3f6064e3563d292fd3320f2d` |
| `azure_sdk_storage_files_shares` | `sdk/storage_files_shares` | `c3873e2ada83f4d61c3beb61baf0653f38dfecb8` |
| `azure_sdk_storage_files_datalake` | `sdk/storage_files_datalake` | `3c7af8ad76756227d91baf9d695d9a605b8f5a0b` |
| `azure_sdk_keyvault` | `sdk/keyvault` | `7a7f2023ec2bff3d13918bbb37f082d9b3420b3f` |
| `azure_sdk_data_tables` | `sdk/data_tables` | `915370a472a46baf718978e27b550dde935dece9` |
| `azure_sdk_data_cosmos` | `sdk/data_cosmos` | `f38a480fddf1728edb4f70e792ed3e9ff227f046` |
| `azure_sdk_data_appconfiguration` | `sdk/data_appconfiguration` | `c17bc6759d51847ab603459b1103a731ed0d17a2` |
| `azure_sdk_attestation` | `sdk/attestation` | `e8ca692a96e6583da08ed810aaf41ec3f3c7355b` |
| `azure_sdk_messaging_common` | `sdk/messaging_common` | `51c5ec8e181abd59a0f8180fc4c37b9ddc8a2bcb` |
| `azure_sdk_eventhubs` | `sdk/eventhubs` | `0bbe991cdbadbd4c63347ca49408877620817c46` |
| `azure_sdk_servicebus` | `sdk/servicebus` | `d19aff0729464de3fbcad15d4ea2ca4d23611530` |
| `azure_sdk_kusto` | `sdk/kusto` | `d9aab9910e295bf70057e163368767abff65fb39` |

Kusto now exposes `common`, `data`, and `ingest` namespaces from one
`azure_sdk_kusto` package. The former Common, Data, and Ingest package refs
were archived and retired.

## Standalone examples

| Branch | Commit | Cutover |
| --- | --- | --- |
| `example/arm_avs` | `661796509350f6bb3271d47822a3144428e77eef` | Fast-forward |
| `example/arm_avs_wasi` | `75d331df357a32d73a6fba968c9de78fc9bbc632` | Fast-forward |
| `example/kusto` | `85952066382c4344fa24897e9f3ad582a3315b71` | Created |

## Recovery and rollback

All 44 pre-cutover branch and tag targets remain under:

```text
refs/heads/archive/package-reset-2026-07-24-global-r3/
```

The external recovery bundle has SHA-256
`c8fd86e017f008342e46a09e65900ccc9b021e9d946b205ce9b0dd1ae049a647`;
its recovery artifact commit is
`2de1d7ab17217a79b3aa1a07af5df8f17bef4800`.

Before using the bundle, verify its checksum, then inspect it with
`git bundle verify`. Restore production refs only with the exact old and
current object IDs from the provenance JSON. The recorded rollback rehearsal
successfully restored and reapplied all 47 production ref operations.

After the approved observation period, all 21
`migration/package-reset-2026-07-24-global-r3/...` refs were deleted in one
atomic exact-lease push. All 44 archive refs and the external recovery bundle
remain.

Permanent rulesets protect the five Core release branches, branch-owned
packages, package version tags, and standalone examples. Package and example
branches require pull requests, conversation resolution, and the Ubuntu,
Windows, and macOS `package-test` checks.

## Final verification

Phase 5 completed the production and recovery proof:

- all 18 branch-owned packages passed remote branch/tag validation, immutable
  dependency hash checks, and 463 package tests;
- all three standalone examples passed clean-clone formatting, build, test,
  and live-test-safe validation;
- temporary PRs
  [#115](https://github.com/cataggar/azure-sdk-for-zig/pull/115),
  [#116](https://github.com/cataggar/azure-sdk-for-zig/pull/116), and
  [#119](https://github.com/cataggar/azure-sdk-for-zig/pull/119) proved the
  example, SDK, and generated REST branch workflows and all three required
  check contexts;
- 357 candidate artifact digests, 21 candidate repositories, all nonzero
  commit-map objects, 27 mapping histories, and 13 representative Kusto
  history records were revalidated;
- a fresh bundle restore and disposable bare-remote rehearsal restored 120
  rollback refs, then reapplied all 47 production operations to 115 exact
  post-reset refs.

The final Main workflow run was
[`30116230119`](https://github.com/cataggar/azure-sdk-for-zig/actions/runs/30116230119).
The generated-package proof used run
[`30116248154`](https://github.com/cataggar/azure-sdk-for-zig/actions/runs/30116248154)
and trusted package checks run
[`30116321507`](https://github.com/cataggar/azure-sdk-for-zig/actions/runs/30116321507).
