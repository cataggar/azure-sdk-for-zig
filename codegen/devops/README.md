# Azure DevOps code generation

Azure DevOps is the only service whose contract does not live in
`Azure/azure-rest-api-specs`. Microsoft publishes it as Swagger 2.0 in
[`microsoft/vsts-rest-api-specs`](https://github.com/microsoft/vsts-rest-api-specs),
so the pipeline has one extra stage in front: a fork converts those
definitions to TypeSpec, and everything downstream is the ordinary
TypeSpec toolchain.

```
microsoft/vsts-rest-api-specs  specification/<area>/7.2/<name>.json   (Swagger 2.0)
  └─ cataggar/vsts-rest-api-specs, branch `typespec`
       swagger2openapi --patch → tools/patcher.mjs → tsp-openapi3
       → post-processing → tsp compile --no-emit  (gate)
       └─ typespec/specs/<area>/<name>/main.tsp
            └─ build-devops-models.mjs   → JSON code models, one per area
                 └─ generate_devops_package.zig → the `azure_rest_devops` package
```

## Why one package and not 44

Azure DevOps splits its REST API into 44 areas (`git`, `build`, `wit`,
…). They share a host family, an auth scheme and a release cadence, and
callers routinely use several at once, so they ship as a single package
with a Zig namespace per area rather than 44 separately versioned
packages. This mirrors `azure-devops-rust-api`.

Areas are independent below that: each gets its own
`src/<area>/{root,clients,models,enums}.zig` and its own root client
carrying that area's default endpoint. `src/root.zig` re-exports them.

## Only the latest version

Only API version **7.2** is generated. The upstream repository carries
4.1 through 7.2, but the SDK tracks the current contract only; the
`typespec` branch pins the selection in `typespec/config.json`.

## Running it

Build the code models (~10 minutes; runs TCGC once per spec):

```bash
node codegen/devops/build-devops-models.mjs \
  ../vsts-rest-api-specs/typespec/specs .devops-models
```

Pass area names after the output directory to build a subset:

```bash
node codegen/devops/build-devops-models.mjs \
  ../vsts-rest-api-specs/typespec/specs .devops-models git build
```

Then generate the package:

```bash
cd codegen/cli
zig build generate-devops-package \
  -Ddevops-models=../../.devops-models \
  -Ddevops-output=../../.release/devops/generated-rest \
  -Dazure-sdk-core-commit=<commit> \
  -Dazure-sdk-core-hash=<hash>
```

`-Ddevops-generator-commit` and `-Ddevops-spec-commit` record provenance
in the generated `.azure-sdk-generator`; supply both when producing
output destined for the `rest/devops` branch.

Verify the result the same way the branch CI does:

```bash
cd .release/devops/generated-rest && zig build test --summary all
```

## Multi-spec areas

Five areas ship more than one spec file (`artifacts`,
`artifactsPackageTypes`, `advancedSecurity`, `approvalsAndChecks`,
`distributedTask`). `mergeArea` folds them into one namespace: sub-clients
are concatenated under a single root client named after the area, and
models, enums and unions are deduplicated by name.
