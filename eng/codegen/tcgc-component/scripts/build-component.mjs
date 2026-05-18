// SPDX-License-Identifier: MIT
//
// build-component.mjs — assemble a self-contained WASI component from
// @typespec/compiler + TCGC + friends.
//
// Why this exists:
//
//   componentize-js (StarlingMonkey) snapshots all JS at component-build
//   time. There is no runtime ESM `import()` of external paths. TypeSpec
//   normally loads decorator and emitter modules dynamically via
//   `host.getJsImport(absolutePath)` — that doesn't work inside a wasm
//   component.
//
//   This script generates a single entry file that:
//     1. Statically imports every TypeSpec package we want to support
//        (so esbuild captures their JS into the bundle).
//     2. Inlines every `.tsp` stdlib file as a string literal (so the
//        compiler's source loader can read them from an in-memory
//        virtualFs without WASI fs access).
//     3. Builds a `getJsImport(path) → module` map keyed by the same
//        absolute paths the TypeSpec module resolver computes.
//     4. Re-exports a `WasiHost` that combines the virtualFs +
//        jsImports map + WASI fs preopens for the user's spec.
//
// Then it runs esbuild (with a stub for @babel/code-frame to avoid
// SpiderMonkey-incompatible Unicode-property regexes from js-tokens)
// and jco componentize to produce tcgc.wasm.

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import * as esbuild from "esbuild";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const dist = path.join(root, "dist");

// ── Packages to vendor into the component ──────────────────────────

const packages = [
  "@typespec/compiler",
  "@typespec/http",
  "@typespec/rest",
  "@typespec/versioning",
  "@typespec/openapi",
  "@azure-tools/typespec-azure-core",
  "@azure-tools/typespec-azure-resource-manager",
  "@azure-tools/typespec-client-generator-core",
];

function readPackageJson(spec) {
  const pjPath = path.join(root, "node_modules", spec, "package.json");
  return JSON.parse(fs.readFileSync(pjPath, "utf-8"));
}

/** Recursively walk a dir and return absolute file paths. */
function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.isFile()) out.push(p);
  }
  return out;
}

// ── Discover .tsp + package.json files to inline ────────────────────

const virtualFsEntries = []; // { virtualPath, sourcePath }
const jsImportEntries = []; // { virtualPath, importSpec, identKey }

for (const spec of packages) {
  const pj = readPackageJson(spec);
  const pkgRoot = path.join(root, "node_modules", spec);
  const virtPkgRoot = `/node_modules/${spec}`;

  // package.json — always needed for module resolution.
  virtualFsEntries.push({
    virtualPath: `${virtPkgRoot}/package.json`,
    sourcePath: path.join(pkgRoot, "package.json"),
  });

  // All .tsp files under lib/ — TypeSpec stdlib source.
  const libDir = path.join(pkgRoot, "lib");
  for (const f of walk(libDir)) {
    if (f.endsWith(".tsp")) {
      const rel = path.relative(pkgRoot, f);
      virtualFsEntries.push({
        virtualPath: `${virtPkgRoot}/${rel}`,
        sourcePath: f,
      });
    }
  }

  // Main JS module — used by the compiler/emitter for `$lib`,
  // `$linter`, `$onEmit`. Registered in jsImports map, NOT inlined as
  // text (esbuild bundles the module body via the import).
  const mainRel = pj.main ?? "dist/src/index.js";
  jsImportEntries.push({
    virtualPath: `${virtPkgRoot}/${stripDotSlash(mainRel)}`,
    importSpec: spec,
    identKey: spec,
  });

  // tsp-side JS imports — every .tsp file in the package may `import`
  // a .js file from its sibling `dist/` tree, e.g.
  // `import "../dist/src/tsp-index.js"` (containing `$decorators`)
  // or `import "../dist/src/decorators.js"` (containing individual
  // `$xxx` decorator impls). Scan every .tsp file and resolve each
  // .js import against the package root. Each unique target becomes
  // a `jsImports` entry imported by absolute filesystem path
  // (package `exports` rarely declares these deep subpaths).
  const tspJsImports = new Set();
  for (const tspFile of walk(path.join(pkgRoot, "lib"))) {
    if (!tspFile.endsWith(".tsp")) continue;
    const src = fs.readFileSync(tspFile, "utf-8");
    for (const m of src.matchAll(/^\s*import\s+"([^"]+\.js)"/gm)) {
      const importPath = m[1];
      // Skip package-relative imports like `@typespec/foo` — they're
      // handled by the package being registered separately.
      if (!importPath.startsWith(".")) continue;
      const absImport = path.resolve(path.dirname(tspFile), importPath);
      // Only register imports that land inside the package root.
      if (!absImport.startsWith(pkgRoot + path.sep)) continue;
      tspJsImports.add(absImport);
    }
  }
  for (const absImport of tspJsImports) {
    const rel = path.relative(pkgRoot, absImport);
    jsImportEntries.push({
      virtualPath: `${virtPkgRoot}/${rel}`,
      importSpec: absImport,
      identKey: `tsp-js:${spec}:${rel}`,
    });
  }
}

function stripDotSlash(s) {
  return s.startsWith("./") ? s.slice(2) : s;
}

// ── Generate dist/wasi-entry.generated.js ──────────────────────────

fs.mkdirSync(dist, { recursive: true });

// Build a stable list of unique import specifiers so each one is
// imported exactly once into a numbered __pkgN binding.
const importSpecs = [];
const importIdx = new Map();
for (const e of jsImportEntries) {
  if (!importIdx.has(e.identKey)) {
    importIdx.set(e.identKey, importSpecs.length);
    importSpecs.push(e.importSpec);
  }
}

let entry = `// Generated by scripts/build-component.mjs — do not edit by hand.\n\n`;

// Static imports of each TypeSpec package so esbuild bundles the JS.
for (let i = 0; i < importSpecs.length; i++) {
  entry += `import * as __pkg${i} from ${JSON.stringify(importSpecs[i])};\n`;
}
entry += `\n`;

// Inlined .tsp + package.json sources as a virtualFs map.
entry += `export const virtualFsSources = new Map();\n`;
for (const e of virtualFsEntries) {
  const content = fs.readFileSync(e.sourcePath, "utf-8");
  entry += `virtualFsSources.set(${JSON.stringify(e.virtualPath)}, ${JSON.stringify(content)});\n`;
}
entry += `\n`;

// jsImports map keyed by absolute virtual paths.
entry += `export const jsImports = new Map();\n`;
for (const e of jsImportEntries) {
  const pkgIdx = importIdx.get(e.identKey);
  entry += `jsImports.set(${JSON.stringify(e.virtualPath)}, __pkg${pkgIdx});\n`;
}
entry += `\n`;

// Re-export the WasiHost-using compile entry-point from src/wasi-host.js.
entry += `export { compile, tcgc } from "../src/wasi-host.js";\n`;

const entryPath = path.join(dist, "wasi-entry.generated.js");
fs.writeFileSync(entryPath, entry);
console.log(`wrote ${entryPath} (${entry.length} bytes)`);

// ── Inject minimal globals SpiderMonkey-in-StarlingMonkey lacks ────
//
// StarlingMonkey omits Intl (no internationalization), which
// `temporal-polyfill` and a few other libs probe for at module-init
// time. Define just enough surface that capability detection sees
// "supported = false" and the library falls back to a no-op path.

const globalsPlugin = {
  name: "wasi-globals",
  setup(build) {
    build.onResolve({ filter: /^@wasi-globals$/ }, () => ({
      path: path.join(stubsDir, "globals.js"),
    }));
  },
};

// Prepend a hidden import of the globals shim to the entry file.
fs.writeFileSync(
  entryPath,
  `import "@wasi-globals";\n` + fs.readFileSync(entryPath, "utf-8"),
);

const stubsDir = path.join(root, "src", "stubs");
const stubFor = {
  "@babel/code-frame": path.join(stubsDir, "babel-code-frame.js"),
  "change-case": path.join(stubsDir, "change-case.js"),
  "is-unicode-supported": path.join(stubsDir, "is-unicode-supported.js"),
  "vscode-languageserver": path.join(stubsDir, "vscode-languageserver.js"),
  "vscode-languageserver-textdocument": path.join(stubsDir, "vscode-languageserver.js"),
};

const stubPlugin = {
  name: "wasi-stubs",
  setup(build) {
    for (const [pkg, stubPath] of Object.entries(stubFor)) {
      const filter = new RegExp(`^${pkg.replace(/[.+?^${}()|[\]\\]/g, "\\$&")}$`);
      build.onResolve({ filter }, (args) => {
        console.log(`  [stub] ${args.path} → ${stubPath}`);
        return { path: stubPath };
      });
    }
    // Anything importing prettier (formatter only, never used by us)
    // can resolve to an empty module.
    build.onResolve({ filter: /^prettier($|\/)/ }, (args) => {
      console.log(`  [stub] ${args.path} → empty prettier shim`);
      return { path: path.join(stubsDir, "empty.js") };
    });
    // TypeSpec's `dist/src/core/formatter.js` and the entire
    // `formatter/` subtree are only used by `tsp format`, but they're
    // eagerly initialised at top-level of the compiler entry, which
    // drags `prettier` into the bundle. Redirect to a named-fallback
    // stub whenever the importer is inside @typespec/compiler and the
    // import touches the formatter subtree.
    build.onResolve({ filter: /formatter|printTypeSpec/ }, (args) => {
      if (!args.importer.includes("@typespec/compiler")) return null;
      if (!/formatter|printTypeSpec/.test(args.path)) return null;
      return { path: path.join(stubsDir, "typespec-formatter.js") };
    });
    // Same trick for the language-server subtree: top-level
    // `await init_server()` in compiler/index.js drags
    // vscode-languageserver-protocol and a chain of `await` calls
    // that StarlingMonkey can't satisfy. We don't use any server APIs
    // from the compile path.
    build.onResolve({ filter: /server/ }, (args) => {
      if (!args.importer.includes("@typespec/compiler")) return null;
      if (!/\.\/server|\/server\//.test(args.path)) return null;
      return { path: path.join(stubsDir, "typespec-server.js") };
    });
  },
};

// ── Bundle ─────────────────────────────────────────────────────────

const bundlePath = path.join(dist, "bundled.js");
await esbuild.build({
  entryPoints: [entryPath],
  bundle: true,
  format: "esm",
  // Browser platform picks up the "browser" field in TypeSpec's
  // package.json, which already aliases the Node-specific compiler
  // files (`node-host.js`, `console-sink.js`) to wasm-friendly stubs.
  platform: "browser",
  conditions: ["browser", "import", "default"],
  mainFields: ["browser", "module", "main"],
  target: "es2022",
  outfile: bundlePath,
  external: [],
  plugins: [globalsPlugin, stubPlugin],
  // Treat `process`, `fs`, etc. as global stubs (esbuild's
  // browser-platform default behaviour but with explicit error
  // surfacing on unhandled cases).
  logLevel: "warning",
});
console.log(`bundled ${bundlePath} (${fs.statSync(bundlePath).size} bytes)`);

// ── Componentize ───────────────────────────────────────────────────

const wasmPath = path.join(root, "tcgc.wasm");
const wasmNohttpPath = path.join(root, "tcgc-nohttp.wasm");
const jcoBin = path.join(root, "node_modules", ".bin", "jco");
const witPath = path.join(root, "wit", "component.wit");

execFileSync(jcoBin, [
  "componentize",
  bundlePath,
  "--wit", witPath,
  "--world-name", "codegen",
  "--out", wasmPath,
], { stdio: "inherit" });

console.log(`wrote ${wasmPath} (${fs.statSync(wasmPath).size} bytes)`);

// Also build a no-http variant — the codegen-cli pipeline uses this
// one to avoid dragging wasi:http/outgoing-handler@0.2.10 (which
// wasmtime can't satisfy at 0.2.10) into the composed component.
execFileSync(jcoBin, [
  "componentize",
  bundlePath,
  "--wit", witPath,
  "--world-name", "codegen",
  "--disable", "http",
  "--out", wasmNohttpPath,
], { stdio: "inherit" });

console.log(`wrote ${wasmNohttpPath} (${fs.statSync(wasmNohttpPath).size} bytes)`);
