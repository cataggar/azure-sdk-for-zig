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
  createTypeSpecLibrary,
  paramMessage,
  resolvePath,
} from "@typespec/compiler";
import { createSdkContext } from "@azure-tools/typespec-client-generator-core";
import { virtualFsSources, jsImports } from "../dist/wasi-entry.generated.js";

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

// ── TypeSpec library registration ──────────────────────────────────

const LIB_NAME = "@azure-tools/typespec-zig";

export const $lib = createTypeSpecLibrary({
  name: LIB_NAME,
  diagnostics: {
    "internal-error": {
      severity: "error",
      messages: {
        default: paramMessage`typespec-zig encountered an internal error: ${"message"}`,
      },
    },
  },
  emitter: {
    options: {
      type: "object",
      additionalProperties: true,
      properties: {},
      required: [],
    },
  },
});

/* eslint-disable-next-line @typescript-eslint/unbound-method */
export const { reportDiagnostic } = $lib;

// ── WasiHost CompilerHost implementation ───────────────────────────

// Captured by $onEmit, returned by compile(). One per `compile()` call.
const __slot = { json: null, error: null };

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

// ── TypeSpec emitter — captures the SdkPackage as JSON ─────────────

export async function $onEmit(context) {
  try {
    const sdkContext = await createSdkContext(context, LIB_NAME, {
      disableUsageAccessPropagationToBase: true,
    });
    context.program.reportDiagnostics(sdkContext.diagnostics);
    const errors = sdkContext.diagnostics.filter((d) => d.severity === "error");
    if (errors.length > 0) {
      throw new Error(
        "TCGC reported errors:\n" +
          errors.map((d) => `  ${d.code}: ${d.message}`).join("\n"),
      );
    }
    const opts = context.options ?? {};
    const codeModel = {
      package_name: opts["package-name"] || "azure_generated",
      package_version: opts["package-version"] || "0.1.0",
      target_kind: opts["target-kind"] || "client",
      service_kind: detectServiceKind(sdkContext),
      clients: sdkContext.sdkPackage.clients.map(adaptClient),
      models: sdkContext.sdkPackage.models.map(adaptModel),
      enums: sdkContext.sdkPackage.enums.map(adaptEnum),
      unions: [],
    };
    __slot.json = JSON.stringify(codeModel);
  } catch (err) {
    __slot.error = err instanceof Error ? err : new Error(String(err));
  }
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

// ── Adapters — keep in sync with src/index.js (Node-bridge version) ─

function detectServiceKind(sdkContext) {
  if (sdkContext.arm === true) return "azure-arm";
  for (const c of sdkContext.sdkPackage.clients) {
    for (const p of c.clientInitialization?.parameters ?? []) {
      if (p.name === "subscriptionId") return "azure-arm";
    }
  }
  return "azure-dataplane";
}

function adaptClient(client) {
  return {
    name: client.name,
    namespace: client.namespace ?? null,
    doc: client.doc ?? null,
    parameters: adaptClientParams(client.clientInitialization),
    endpoint: adaptClientEndpoint(client.clientInitialization),
    methods: (client.methods ?? [])
      .filter((m) => m.kind !== "clientaccessor")
      .map(adaptMethod),
    sub_clients: (client.children ?? []).map((child) => ({
      name: toSnakeCase(child.name),
      accessor_name: `get${child.name}`,
      client_name: child.name,
    })),
    credential_scopes: defaultCredentialScopes(client),
  };
}

function adaptClientEndpoint(init) {
  const ep = init?.parameters?.find((p) => p.kind === "endpoint");
  if (!ep) return { name: "endpoint", default_value: null };
  return {
    name: toSnakeCase(ep.name),
    default_value:
      ep.type?.templateArguments?.[0]?.defaultValue ??
      ep.clientDefaultValue ??
      null,
  };
}

function adaptClientParams(init) {
  const params = [];
  for (const p of init?.parameters ?? []) {
    if (p.kind === "credential" || p.kind === "endpoint") continue;
    if (p.isApiVersionParam) continue;
    params.push({
      name: toSnakeCase(p.name),
      doc: p.doc ?? null,
      param_type: adaptType(p.type),
      optional: !!p.optional,
    });
  }
  return params;
}

function defaultCredentialScopes(client) {
  const isArm = (client.clientInitialization?.parameters ?? []).some(
    (p) => p.name === "subscriptionId",
  );
  return isArm
    ? ["https://management.azure.com/.default"]
    : ["{endpoint}/.default"];
}

function adaptMethod(method) {
  const op = method.operation ?? {};
  return {
    name: toSnakeCase(method.name),
    doc: method.doc ?? null,
    http_method: (op.verb ?? "get").toLowerCase(),
    path: op.path ?? "",
    parameters: (method.parameters ?? []).map(adaptMethodParameter),
    response: { response_type: method.response?.type ? adaptType(method.response.type) : null, status_codes: [] },
    paging: null,
    long_running: null,
    kind: method.kind ?? "basic",
  };
}

function adaptMethodParameter(p) {
  return {
    name: toSnakeCase(p.name),
    serialized_name: p.serializedName ?? p.name,
    location: paramLocation(p),
    doc: p.doc ?? null,
    param_type: adaptType(p.type),
    optional: !!p.optional,
  };
}

function paramLocation(p) {
  switch (p.kind) {
    case "path": return "path";
    case "query": return "query";
    case "header": return "header";
    case "cookie": return "cookie";
    case "body": return "body";
    case "endpoint": return "endpoint";
    case "credential": return "credential";
    default: return "method";
  }
}

function adaptModel(model) {
  return {
    name: model.name,
    namespace: model.namespace ?? null,
    doc: model.doc ?? null,
    fields: (model.properties ?? []).map((p) => ({
      name: toSnakeCase(p.name),
      serialized_name: p.serializedName ?? p.name,
      doc: p.doc ?? null,
      field_type: adaptType(p.type),
      optional: !!p.optional,
      read_only: !!p.readOnly,
      flatten: !!p.flatten,
    })),
    parents: model.baseModel ? [model.baseModel.name] : [],
    discriminator: model.discriminatorProperty?.name ?? null,
    is_input: !!(model.usage & 1),
    is_output: !!(model.usage & 2),
  };
}

function adaptEnum(en) {
  return {
    name: en.name,
    namespace: en.namespace ?? null,
    doc: en.doc ?? null,
    values: (en.values ?? []).map((v) => ({
      name: v.name,
      value: v.value,
      doc: v.doc ?? null,
    })),
    value_type: en.valueType?.kind ?? "string",
    extensible: en.isFixed === false,
  };
}

function adaptType(type) {
  if (!type) return { kind: "Scalar", value: "unknown" };
  switch (type.kind) {
    case "string": return { kind: "Scalar", value: "string" };
    case "boolean": return { kind: "Scalar", value: "bool" };
    case "bytes": return { kind: "Scalar", value: "bytes" };
    case "url": return { kind: "Scalar", value: "url" };
    case "utcDateTime":
    case "offsetDateTime":
      return { kind: "Scalar", value: "datetime" };
    case "duration": return { kind: "Scalar", value: "duration" };
    case "model": return { kind: "Model", value: type.name };
    case "enum": return { kind: "Enum", value: type.name };
    case "union": return { kind: "Union", value: type.name ?? "anonymous" };
    case "array": return { kind: "Array", value: adaptType(type.valueType) };
    case "dict": return { kind: "Map", value: adaptType(type.valueType) };
    case "nullable": return { kind: "Option", value: adaptType(type.type) };
    case "constant": return { kind: "Constant", value: String(type.value) };
    default: return { kind: "Scalar", value: type.kind ?? "unknown" };
  }
}

function toSnakeCase(str) {
  return String(str)
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
    .replace(/([a-z\d])([A-Z])/g, "$1_$2")
    .toLowerCase()
    .replace(/^_/, "");
}

// Top-level shim so `compile` is also reachable as a named export of
// the bundle root (jco's "extract exports" stage looks for it).
export const compile = tcgc.compile;
