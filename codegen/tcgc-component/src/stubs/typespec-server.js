// Stub for @typespec/compiler/dist/src/server/* (the language server
// subtree). Never used during `tsp compile` but eagerly initialised by
// the compiler's top-level `await init_server()`.

function notSupported() {
  throw new Error("typespec language server is not available inside the wasm component");
}

// Symbols the compiler's index.js re-exports from `./server/`.
export const createServer = notSupported;
export const TypeSpecLanguageConfiguration = {};
export default { createServer, TypeSpecLanguageConfiguration };
