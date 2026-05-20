// SPDX-License-Identifier: MIT
//
// TCGC adapter — TypeSpec emitter that produces a JSON code model for
// the Azure SDK for Zig code generator.
//
// At runtime the package serves two roles:
//
//   1. A standard TypeSpec emitter library. The TypeSpec compiler loads
//      this file via `tspMain` (see package.json) and calls `$onEmit`
//      when invoked with `--emit @azure-tools/typespec-zig`.
//
//   2. A WIT-style export: `compile(projectPath, emitterOptions)` runs
//      the TypeSpec compiler programmatically with this package as the
//      sole emitter, captures the code model produced by `$onEmit`,
//      and returns it as a JSON string. This is the entry point the
//      Zig host (and `jco componentize`) call into.
//
// CLI usage (development):
//
//   node src/index.js <project-path> [emitter-options-json]
//
// TCGC API targeted: @azure-tools/typespec-client-generator-core 0.68.0
// (matches @typespec/compiler 1.12.0).

import {
  compile as tspCompile,
  NodeHost,
  resolvePath,
  createTypeSpecLibrary,
  paramMessage,
} from "@typespec/compiler";
import { createSdkContext } from "@azure-tools/typespec-client-generator-core";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

/* ───────────────────────── Library registration ──────────────────── */

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
      properties: {
        "package-name": { type: "string", nullable: true },
        "package-version": { type: "string", nullable: true },
        "target-kind": { type: "string", nullable: true },
      },
      required: [],
    },
  },
});

/* eslint-disable-next-line @typescript-eslint/unbound-method */
export const { reportDiagnostic } = $lib;

/**
 * Stashes the most recent code model so `compile()` can pick it up after
 * driving the TypeSpec compiler. Single-threaded by construction.
 *
 * @type {{ json: string | null, error: Error | null }}
 */
const __slot = { json: null, error: null };

/* ───────────────────────── TypeSpec `$onEmit` ────────────────────── */

/**
 * Entry point the TypeSpec compiler calls when this package is listed
 * in `--emit`. Builds the TCGC SdkContext and serializes a JSON code
 * model into `__slot`.
 *
 * @param {import('@typespec/compiler').EmitContext} context
 */
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
    __slot.json = JSON.stringify(codeModel, null, 2);
  } catch (err) {
    __slot.error = err instanceof Error ? err : new Error(String(err));
  }
}

/* ───────────────────────── WIT export: compile() ─────────────────── */

/**
 * Drives the TypeSpec compiler with this package registered as the
 * sole emitter and returns the JSON code model.
 *
 * @param {string} projectPath path to a directory containing
 *                             `tspconfig.yaml`, `client.tsp`, or
 *                             `main.tsp`, or to a `.tsp` file.
 * @param {string} emitterOptions JSON-encoded options blob.
 * @returns {Promise<string>} JSON code model.
 */
export async function compile(projectPath, emitterOptions) {
  const options = JSON.parse(emitterOptions || "{}");
  const staged = stageSpec(projectPath);
  const mainFile = resolveMainFile(staged);

  __slot.json = null;
  __slot.error = null;

  const program = await tspCompile(NodeHost, mainFile, {
    emit: [packageRoot()],
    options: {
      [LIB_NAME]: {
        "package-name": options["package-name"],
        "package-version": options["package-version"],
        "target-kind": options["target-kind"] ?? "client",
        "emitter-output-dir": joinTmp(),
      },
    },
    noEmit: false,
    warningAsError: false,
  });

  const compileErrors = program.diagnostics.filter(
    (d) => d.severity === "error",
  );
  if (compileErrors.length > 0) {
    throw new Error(
      "TypeSpec compilation failed:\n" +
        compileErrors.map((d) => `  ${d.code}: ${d.message}`).join("\n"),
    );
  }
  if (__slot.error) throw __slot.error;
  if (!__slot.json) throw new Error("typespec-zig emitter produced no output");
  return __slot.json;
}

/* ───────────────────────── Helpers ───────────────────────────────── */

function packageRoot() {
  // src/index.js → ../
  const here = fileURLToPath(import.meta.url);
  return resolvePath(path.dirname(path.dirname(here)));
}

function joinTmp() {
  // The TypeSpec compiler insists on an emitter-output-dir even when we
  // don't write any files. Use the package's own tmp area; we'll clean
  // it up implicitly on next invocation.
  return resolvePath(path.join(packageRoot(), ".typespec-output"));
}

function resolveMainFile(projectPath) {
  const abs = path.resolve(projectPath);
  const stat = fs.statSync(abs);
  if (stat.isFile()) return resolvePath(abs);
  for (const candidate of ["client.tsp", "main.tsp"]) {
    const p = path.join(abs, candidate);
    if (fs.existsSync(p)) return resolvePath(p);
  }
  return resolvePath(abs);
}

/**
 * The TypeSpec compiler walks up from the spec file's directory looking
 * for `node_modules`. Azure specs in `azure-rest-api-specs/` don't have
 * one, so we stage the spec under our package directory where our
 * `node_modules` is reachable.
 *
 * For specs that pull in sibling directories via tspconfig
 * `additionalDirectories`, this layout is extended later. For
 * self-contained specs (e.g. keyvault data-plane), copying the spec
 * directory itself is enough.
 *
 * @param {string} inputPath
 * @returns {string} path to the staged equivalent of `inputPath`.
 */
function stageSpec(inputPath) {
  const root = packageRoot();
  const stagingRoot = path.join(root, ".tsp-staging");
  fs.rmSync(stagingRoot, { recursive: true, force: true });
  fs.mkdirSync(stagingRoot, { recursive: true });

  // For initial bring-up: stage the spec's parent directory so sibling
  // dirs referenced by `tspconfig.additionalDirectories` or relative
  // imports (`../Foo.Shared`) are reachable. Specs that reach further
  // (ARM `../../common-types/...`) still need an extended staging
  // strategy — tracked as a follow-up.
  const absInput = path.resolve(inputPath);
  const inputDir = fs.statSync(absInput).isFile()
    ? path.dirname(absInput)
    : absInput;
  const parentDir = path.dirname(inputDir);

  const stagedParent = path.join(stagingRoot, path.basename(parentDir));
  fs.mkdirSync(stagedParent, { recursive: true });
  copyDir(parentDir, stagedParent);

  const rel = path.relative(parentDir, absInput);
  return rel === "" ? stagedParent : path.join(stagedParent, rel);
}

function copyDir(src, dst) {
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    if (entry.name === "node_modules" || entry.name === ".git") continue;
    const s = path.join(src, entry.name);
    const d = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      fs.mkdirSync(d, { recursive: true });
      copyDir(s, d);
    } else if (entry.isFile()) {
      fs.copyFileSync(s, d);
    }
  }
}

/* ───────────────────────── ARM vs data-plane detection ───────────── */

function detectServiceKind(sdkContext) {
  if (sdkContext.arm === true) return "azure-arm";
  for (const c of sdkContext.sdkPackage.clients) {
    for (const p of c.clientInitialization?.parameters ?? []) {
      if (p.name === "subscriptionId") return "azure-arm";
    }
  }
  return "azure-dataplane";
}

/* ───────────────────────── Client / method adapters ──────────────── */

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
    response: adaptMethodResponse(method.response),
    paging: adaptPaging(method),
    long_running: adaptLro(method),
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
    case "path":
      return "path";
    case "query":
      return "query";
    case "header":
      return "header";
    case "cookie":
      return "cookie";
    case "body":
      return "body";
    case "endpoint":
      return "endpoint";
    case "credential":
      return "credential";
    default:
      return "method";
  }
}

function adaptMethodResponse(resp) {
  if (!resp) return { response_type: null, status_codes: [] };
  return {
    response_type: resp.type ? adaptType(resp.type) : null,
    status_codes: [],
  };
}

function adaptPaging(method) {
  if (method.kind !== "paging" && method.kind !== "lropaging") return null;
  const meta = method.pagingMetadata ?? {};
  return {
    items_segments: (meta.pageItemsSegments ?? []).map((s) => s.name ?? null),
    next_link_segments: (meta.nextLinkSegments ?? []).map((s) => s.name ?? null),
    next_link_verb: meta.nextLinkVerb ?? null,
    next_link_operation: meta.nextLinkOperation?.name ?? null,
  };
}

function adaptLro(method) {
  if (method.kind !== "lro" && method.kind !== "lropaging") return null;
  const meta = method.lroMetadata ?? {};
  return {
    final_state_via: meta.finalStateVia ?? null,
    final_response_type: meta.finalResponse?.envelopeResult
      ? adaptType(meta.finalResponse.envelopeResult)
      : null,
  };
}

/* ───────────────────────── Model / enum / type adapters ──────────── */

// Cross-language-definition-id of each ARM base type. TCGC stamps these
// onto `SdkModelType.crossLanguageDefinitionId` regardless of how the
// spec aliases the type, so matching here is robust against namespace
// re-imports.
const ARM_RESOURCE_KIND_BY_XLDID = {
  "Azure.ResourceManager.CommonTypes.ProxyResource": "proxy",
  "Azure.ResourceManager.CommonTypes.Resource": "proxy",
  "Azure.ResourceManager.CommonTypes.TrackedResource": "tracked",
  "Azure.ResourceManager.CommonTypes.ExtensionResource": "extension",
  // Older / alternate aliases used by some TCGC versions.
  "Azure.ResourceManager.ProxyResource": "proxy",
  "Azure.ResourceManager.Resource": "proxy",
  "Azure.ResourceManager.TrackedResource": "tracked",
  "Azure.ResourceManager.ExtensionResource": "extension",
};

// Fallback table keyed on the topmost base model's `name`, used when
// `crossLanguageDefinitionId` is unset or unrecognized.
const ARM_RESOURCE_KIND_BY_NAME = {
  ProxyResource: "proxy",
  Resource: "proxy",
  TrackedResource: "tracked",
  ExtensionResource: "extension",
};

/**
 * Walk the `baseModel` chain root-to-leaf and return the concatenated
 * list of (own + inherited) properties. Inherited properties come
 * first; the leaf's own properties last. Within that order we de-dup
 * by `serializedName` so a property re-declared on the leaf wins (its
 * doc / optionality / type override the inherited one).
 */
function collectInheritedProperties(model) {
  const chain = [];
  for (let cur = model; cur; cur = cur.baseModel) chain.unshift(cur);

  const byKey = new Map();
  for (const m of chain) {
    for (const p of m.properties ?? []) {
      const key = p.serializedName ?? p.name;
      byKey.set(key, p); // later (more-derived) entries replace earlier ones
    }
  }
  return Array.from(byKey.values());
}

/**
 * Detect which ARM base type (if any) sits at the root of `model`'s
 * `baseModel` chain. Returns `"proxy"` / `"tracked"` / `"extension"`,
 * or `null` for non-ARM types.
 */
function detectArmResourceKind(model) {
  let topmost = model;
  for (let cur = model; cur; cur = cur.baseModel) {
    const xldid = cur.crossLanguageDefinitionId;
    if (xldid && Object.prototype.hasOwnProperty.call(ARM_RESOURCE_KIND_BY_XLDID, xldid)) {
      return ARM_RESOURCE_KIND_BY_XLDID[xldid];
    }
    topmost = cur;
  }
  // Fallback: classify by the topmost base model's name when xldid is
  // unrecognized. Guard with a namespace prefix to avoid catching
  // unrelated "Resource" / "TrackedResource" types in non-ARM specs.
  const ns = topmost?.namespace ?? topmost?.clientNamespace ?? "";
  if (
    Object.prototype.hasOwnProperty.call(ARM_RESOURCE_KIND_BY_NAME, topmost?.name) &&
    typeof ns === "string" &&
    ns.startsWith("Azure.ResourceManager")
  ) {
    return ARM_RESOURCE_KIND_BY_NAME[topmost.name];
  }
  return null;
}

function adaptModel(model) {
  const props = collectInheritedProperties(model);
  return {
    name: model.name,
    namespace: model.namespace ?? null,
    doc: model.doc ?? null,
    fields: props.map((p) => ({
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
    arm_resource_kind: detectArmResourceKind(model),
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
    case "string":
      return { kind: "Scalar", value: "string" };
    case "boolean":
      return { kind: "Scalar", value: "bool" };
    case "bytes":
      return { kind: "Scalar", value: "bytes" };
    case "url":
      return { kind: "Scalar", value: "url" };
    case "utcDateTime":
    case "offsetDateTime":
      return { kind: "Scalar", value: "datetime" };
    case "duration":
      return { kind: "Scalar", value: "duration" };
    case "decimal":
    case "decimal128":
      return { kind: "Scalar", value: "decimal" };
    case "int8":
    case "int16":
    case "int32":
    case "int64":
    case "uint8":
    case "uint16":
    case "uint32":
    case "uint64":
    case "float32":
    case "float64":
    case "numeric":
    case "integer":
    case "float":
    case "safeint":
      return { kind: "Scalar", value: type.kind };
    case "model":
      return { kind: "Model", value: type.name };
    case "enum":
      return { kind: "Enum", value: type.name };
    case "union":
      return { kind: "Union", value: type.name ?? "anonymous" };
    case "array":
      return { kind: "Array", value: adaptType(type.valueType) };
    case "dict":
      return { kind: "Map", value: adaptType(type.valueType) };
    case "nullable":
      return { kind: "Option", value: adaptType(type.type) };
    case "constant":
      return { kind: "Constant", value: String(type.value) };
    case "endpoint":
      return { kind: "Scalar", value: "endpoint" };
    case "credential":
      return { kind: "Scalar", value: "credential" };
    default:
      return { kind: "Scalar", value: type.kind ?? "unknown" };
  }
}

function toSnakeCase(str) {
  return String(str)
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
    .replace(/([a-z\d])([A-Z])/g, "$1_$2")
    .toLowerCase()
    .replace(/^_/, "");
}

/* ───────────────────────── CLI shim ──────────────────────────────── */

if (
  typeof process !== "undefined" &&
  typeof process.argv?.[1] === "string" &&
  process.argv[1].endsWith("index.js")
) {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error(
      "Usage: node src/index.js <project-path> [emitter-options-json]",
    );
    process.exit(1);
  }
  compile(args[0], args[1] || "{}").then(
    (json) => process.stdout.write(json + "\n"),
    (err) => {
      console.error(err?.stack || err);
      process.exit(1);
    },
  );
}
