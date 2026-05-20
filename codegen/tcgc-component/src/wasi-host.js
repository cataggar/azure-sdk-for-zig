// SPDX-License-Identifier: MIT
//
// WasiHost — a TypeSpec CompilerHost that runs inside a wasm component.
//
// The host services TypeSpec's file / module / JS-import requests from
// three sources in priority order:
//
//   1. `virtualFsSources` (generated): TypeSpec stdlib .tsp files +
//      every TypeSpec/TCGC package.json, baked into the component at
//      build time.
//
//   2. `jsImports` (generated): static map from a TypeSpec library's
//      absolute JS path (the one the resolver computes) to the
//      already-imported module object. Replaces `import(path)`.
//
//   3. WASI filesystem at `/spec`: user-supplied `.tsp` files for the
//      service being generated, surfaced as a preopen by the Zig host
//      (see `eng/codegen/codegen/src/host.zig`).
//
// `compile()` is the WIT-exported entrypoint. It runs the TypeSpec
// compiler with this host registered, drives our typespec-zig emitter
// via `$onEmit`, and returns the resulting JSON code model.

import {
  compile as tspCompile,
  resolvePath,
} from "@typespec/compiler";
import { virtualFsSources, jsImports } from "../dist/wasi-entry.generated.js";
import { $lib, $onEmit, LIB_NAME, __slot } from "./index.js";

// ─────────────────────────────────────────────────────────────────
//
// At bundle time the script `scripts/build-component.mjs` generates
// `dist/wasi-entry.generated.js`, which:
//
//   * statically imports every TypeSpec package (so esbuild captures
//     the JS),
//   * builds `virtualFsSources` (a Map<path, string> with every TspMain
//     `.tsp` file and every package.json),
//   * builds `jsImports` (a Map<path, module> mapping the resolver's
//     canonical paths to the bundled module objects), and
//   * re-exports `compile` / `tcgc` from this file.
//
// The order of evaluation matters: the generated entry file runs
// FIRST (populating both maps), THEN this file runs (consuming them).
// To make that work the entry file uses static imports rather than
// re-imports through the package main.
//
// All TypeSpec→JSON adaptation logic — `$lib`, `$onEmit`, every
// `adapt*` helper — lives in `./index.js`. This file is purely the
// WASI host that registers `index.js` as the emitter and surfaces
// the resulting JSON model. Keep adaptation OUT of this file so the
// CLI shim (`node src/index.js …`) and the in-component path stay
// byte-for-byte identical.

export { $lib };

// ── WasiHost CompilerHost implementation ───────────────────────────

function makeHost() {
  // In-memory layer combining baked-in stdlib (`virtualFsSources`)
  // and the per-invocation spec-files map planted by `compileInner`
  // BEFORE `tspCompile` runs. The wasm component has no JS-visible
  // filesystem (StarlingMonkey doesn't shim `node:fs`), so user
  // spec files are passed inline by the Zig CLI host.
  const fsReadFile = async (p) => {
    if (virtualFsSources.has(p)) {
      return makeSourceFile(virtualFsSources.get(p), p);
    }
    throw makeFsError(p, "ENOENT");
  };

  const fsStat = async (p) => {
    if (virtualFsSources.has(p)) {
      return { isFile: () => true, isDirectory: () => false };
    }
    // TypeSpec's resolver calls `stat` on the `.js` file pointed to by
    // a package.json's `main`/`tspMain` field before calling
    // `getJsImport(p)`. We don't keep that file's source in
    // `virtualFsSources` (it's bundled, not interpreted), but it IS
    // resolvable via `jsImports` — treat that as proof-of-existence.
    if (jsImports.has(p)) {
      return { isFile: () => true, isDirectory: () => false };
    }
    for (const key of virtualFsSources.keys()) {
      if (key.startsWith(p + "/")) {
        return { isFile: () => false, isDirectory: () => true };
      }
    }
    throw makeFsError(p, "ENOENT");
  };

  const fsReadDir = async (p) => {
    const out = new Set();
    for (const key of virtualFsSources.keys()) {
      if (key.startsWith(p + "/")) {
        const rest = key.slice(p.length + 1);
        const idx = rest.indexOf("/");
        out.add(idx === -1 ? rest : rest.slice(0, idx));
      }
    }
    return [...out];
  };

  const fsRealpath = async (p) => p;

  return {
    async readUrl() {
      throw new Error("readUrl: not supported inside the wasm component");
    },
    readFile: fsReadFile,
    async writeFile() {
      // The emitter we register only stashes JSON in __slot — it never
      // writes files. Anything else hitting writeFile is a bug.
      throw new Error("writeFile: not supported inside the wasm component");
    },
    readDir: fsReadDir,
    async rm() {
      // No-op; we never delete files.
    },
    mkdirp: async () => undefined,
    stat: fsStat,
    realpath: fsRealpath,
    getExecutionRoot: () => "/node_modules/@typespec/compiler",
    getLibDirs: () => ["/node_modules/@typespec/compiler/lib/std"],
    async getJsImport(p) {
      const norm = normalize(p);
      const mod = jsImports.get(norm);
      if (mod === undefined) {
        throw new Error(`getJsImport: ${p} not in bundled jsImports map`);
      }
      return mod;
    },
    getSourceFileKind: (p) => {
      if (p.endsWith(".tsp")) return "typespec";
      if (p.endsWith(".js")) return "js";
      return undefined;
    },
    fileURLToPath: (url) => url.replace(/^file:\/\//, ""),
    pathToFileURL: (p) => `file://${p}`,
    logSink: { log() {} },
  };
}

function normalize(p) {
  // Strip any leading `file://`.
  const noScheme = p.replace(/^file:\/\//, "");
  // Collapse `//` and `/./`.
  return noScheme.replace(/\/+/g, "/").replace(/\/\.\//g, "/");
}

function makeSourceFile(text, p) {
  return {
    text,
    path: p,
    kind: p.endsWith(".tsp") ? "typespec" : "js",
  };
}

function makeFsError(p, code) {
  const err = new Error(`${code}: ${p}`);
  err.code = code;
  return err;
}

// ── WIT export: tcgc.compile ───────────────────────────────────────

export const tcgc = {
  async compile(projectPath, emitterOptions) {
    try {
      return await compileInner(projectPath, emitterOptions);
    } catch (err) {
      // Componentize-js's generated wrapper calls `getErrorPayload(e)`,
      // which re-throws if `e instanceof Error` (turning the failure
      // into an unhandled rejection and a runtime trap). To surface
      // the message back as the `err` branch of `result<string,
      // string>`, throw a plain object with a `payload` string — that
      // path returns the string directly to `utf8Encode`.
      const message =
        err && err.stack
          ? `${err.message ?? String(err)}\n${err.stack}`
          : String(err && err.message ? err.message : err);
      throw { payload: message };
    }
  },
};

async function compileInner(projectPath, emitterOptions) {
  registerTypespecZig();
  const options = JSON.parse(emitterOptions || "{}");

  // The Zig CLI host walks /spec via WASI filesystem and passes every
  // file it finds inline under `__spec_files`. We merge those into the
  // baked-in stdlib map before running TypeSpec — TypeSpec's resolver
  // then sees `/spec/client.tsp` etc. as plain virtualFsSources hits.
  const specFiles = options.__spec_files || {};
  delete options.__spec_files;
  for (const [path, content] of Object.entries(specFiles)) {
    virtualFsSources.set(path, content);
  }

  const host = makeHost();

  // Resolve `projectPath` (a WASI preopen path like `/spec`) into a
  // `main.tsp` / `client.tsp` to feed the compiler.
  const mainFile = await resolveMainFile(host, projectPath);

  __slot.json = null;
  __slot.error = null;

  const program = await tspCompile(host, mainFile, {
    emit: ["/node_modules/" + LIB_NAME],
    options: { [LIB_NAME]: options },
    noEmit: false,
    warningAsError: false,
  });

  const errs = program.diagnostics.filter((d) => d.severity === "error");
  if (errs.length > 0) {
    throw new Error(
      "TypeSpec compilation failed:\n" +
        errs.map((d) => `  ${d.code}: ${d.message}`).join("\n"),
    );
  }
  if (__slot.error) throw __slot.error;
  if (!__slot.json) throw new Error("typespec-zig emitter produced no output");
  return __slot.json;
}

// Register this module as `@azure-tools/typespec-zig`'s emitter target.
// Called from the generated entry AFTER virtualFsSources / jsImports
// have been populated. Idempotent.
let __registered = false;
export function registerTypespecZig() {
  if (__registered) return;
  __registered = true;
  jsImports.set(
    "/node_modules/" + LIB_NAME + "/package.json",
    { $lib, $onEmit, tspMain: "src/index.js" },
  );
  jsImports.set(
    "/node_modules/" + LIB_NAME + "/src/index.js",
    { $lib, $onEmit },
  );
  virtualFsSources.set(
    "/node_modules/" + LIB_NAME + "/package.json",
    JSON.stringify({
      name: LIB_NAME,
      version: "0.1.0",
      type: "module",
      main: "src/index.js",
      tspMain: "src/index.js",
    }),
  );
}

async function resolveMainFile(host, projectPath) {
  const candidates = ["client.tsp", "main.tsp"];
  for (const c of candidates) {
    const p = resolvePath(projectPath, c);
    try {
      const s = await host.stat(p);
      if (s.isFile()) return p;
    } catch {}
  }
  return resolvePath(projectPath);
}


// Top-level shim so `compile` is also reachable as a named export of
// the bundle root (jco's "extract exports" stage looks for it).
export const compile = tcgc.compile;
