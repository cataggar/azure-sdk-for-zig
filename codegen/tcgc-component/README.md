# tcgc-component

JavaScript wrapper around [TypeSpec](https://typespec.io) +
[TCGC](https://github.com/Azure/typespec-azure/tree/main/packages/typespec-client-generator-core),
compiled into a [WebAssembly Component](https://component-model.bytecodealliance.org/)
via [`jco`](https://github.com/bytecodealliance/jco). The Zig code
generator at `../cli` loads the resulting `tcgc.wasm` to obtain a
TCGC code model from `.tsp` files.

## WIT world

See [`wit/component.wit`](wit/component.wit). Exports one function:

```wit
compile: func(project-path: string, emitter-options: string)
         -> result<string, string>;
```

## Build

```bash
# Install JS deps.
npm install

# Componentize.
npm run build          # produces tcgc.wasm

# Optional: dev-run on plain Node for fast iteration.
node src/index.js ../../../../azure-rest-api-specs/specification/keyvault/data-plane/Secrets/tspconfig.yaml

# Regenerate the checked-in Container Registry wire-contract fixture.
# AZURE_REST_API_SPECS may point at a non-default specs checkout.
npm run fixture:container-registry

# Run focused adapter tests.
npm test
```

## Inspect the resulting component

[`wabt`](https://github.com/cataggar/wabt) at
`/home/azureuser/wabt` (a Zig-packaged WABT) provides `wasm2wat` for
manual inspection:

```bash
wasm2wat tcgc.wasm | head
```
