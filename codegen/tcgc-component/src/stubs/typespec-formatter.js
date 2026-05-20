// SPDX-License-Identifier: MIT
//
// Stub for @typespec/compiler/dist/src/{core/formatter.js,
// formatter/...,ast/index.js's printTypeSpecNode}.
//
// These run only for `tsp format` — never during `tsp compile`. We
// export every name TypeSpec re-exports from them so that the bundler
// is satisfied at JS-build time; the runtime stubs throw if anyone
// actually calls them inside the wasm component.

function notSupported() {
  throw new Error("typespec formatter is not available inside the wasm component");
}

export const checkFormatTypeSpec = notSupported;
export const formatTypeSpec = notSupported;
export const printTypeSpecNode = notSupported;
export default { checkFormatTypeSpec, formatTypeSpec, printTypeSpecNode };
