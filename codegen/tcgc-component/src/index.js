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
  createTypeSpecLibrary,
  paramMessage,
} from "@typespec/compiler";
import { createSdkContext } from "@azure-tools/typespec-client-generator-core";

/* ───────────────────────── Library registration ──────────────────── */

export const LIB_NAME = "@azure-tools/typespec-zig";

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
export const __slot = { json: null, error: null };

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
    // Flatten the SdkClient tree (TCGC keeps children nested under
    // `client.children`). The Zig emitter renders one struct per
    // entry; the first entry of each contiguous family is the root
    // (`is_root: true`) and owns init / auth / deinit. Sub-clients
    // borrow the parent's pipeline + init params and only carry
    // method bodies.
    const flatClients = [];
    for (const top of sdkContext.sdkPackage.clients) {
      flattenClients(top, /*parent=*/null, flatClients);
    }
    const codeModel = {
      package_name: opts["package-name"] || "azure_generated",
      package_version: opts["package-version"] || "0.1.0",
      target_kind: opts["target-kind"] || "client",
      service_kind: detectServiceKind(sdkContext),
      clients: flatClients,
      models: sdkContext.sdkPackage.models.map(adaptModel),
      enums: sdkContext.sdkPackage.enums.map(adaptEnum),
      unions: sdkContext.sdkPackage.unions.map(adaptUnion),
    };
    __slot.json = JSON.stringify(codeModel, null, 2);
  } catch (err) {
    __slot.error = err instanceof Error ? err : new Error(String(err));
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

/** Recursively walk a TCGC client tree and adapt each node. */
function flattenClients(client, parent, out) {
  out.push(adaptClient(client, parent));
  for (const child of client.children ?? []) {
    flattenClients(child, client, out);
  }
}

function adaptClient(client, parent) {
  const isRoot = !parent;
  const initParams = adaptInitParameters(client.clientInitialization);
  return {
    name: client.name,
    namespace: client.namespace ?? null,
    doc: client.doc ?? null,
    is_root: isRoot,
    parent_name: parent ? parent.name : null,
    /** Propagated client-level state stored on every (root + sub-)
     *  client struct (e.g. `subscription_id`). */
    init_parameters: initParams.propagated,
    /** Default api-version string (`@@clientInitialization apiVersion`
     *  default). Used to populate `InitOptions.api_version`. */
    api_version_default: initParams.api_version_default,
    endpoint: initParams.endpoint,
    methods: (client.methods ?? [])
      .filter((m) => m.kind !== "clientaccessor")
      .map((m) => adaptMethod(m, initParams.client_param_names)),
    sub_clients: (client.children ?? []).map((child) => ({
      /** camelCase accessor: `Microsoft.AVS.PrivateClouds` →
       *  `privateClouds`. The previous shape (`getPrivateClouds`) was
       *  wrong for the Zig emitter. */
      accessor_camel: toCamelCase(child.name),
      /** snake_case fallback if a future emitter needs it. */
      accessor_snake: toSnakeCase(child.name),
      client_name: child.name,
    })),
    credential_scopes: defaultCredentialScopes(client),
  };
}

/**
 * Walk a `SdkClientInitializationType.parameters` array and partition
 * it into:
 *   - `endpoint`         : the endpoint param (always present)
 *   - `api_version_default` : default value if a method-typed
 *                          `apiVersion` parameter is present
 *   - `propagated`       : typed init knobs (e.g. `subscription_id`)
 *                          that we surface as required fields on the
 *                          root `InitOptions` and store on every
 *                          sub-client struct
 *   - `client_param_names`: a set of snake_cased names of all
 *                          client-level params (`subscription_id`,
 *                          `endpoint`, `api_version`). The method
 *                          adapter uses this set to decide whether a
 *                          path/query parameter is sourced from
 *                          `self.<name>` instead of a user argument.
 */
function adaptInitParameters(init) {
  const params = init?.parameters ?? [];
  const propagated = [];
  let endpointParam = null;
  let apiVersionDefault = null;
  const clientParamNames = new Set();
  for (const p of params) {
    if (p.kind === "endpoint") {
      endpointParam = p;
      clientParamNames.add("endpoint");
      continue;
    }
    if (p.kind === "credential") continue;
    if (p.isApiVersionParam) {
      if (typeof p.clientDefaultValue === "string") apiVersionDefault = p.clientDefaultValue;
      clientParamNames.add("api_version");
      continue;
    }
    // Remaining: typed init knobs (kind === "method"). For ARM, that's
    // `subscriptionId`. Surface as a required required field unless
    // marked optional.
    const snake = toSnakeCase(p.name);
    clientParamNames.add(snake);
    propagated.push({
      name: snake,
      serialized_name: p.serializedName ?? p.name,
      doc: p.doc ?? null,
      param_type: adaptType(p.type),
      optional: !!p.optional,
    });
  }
  return {
    endpoint: adaptEndpointFromParam(endpointParam),
    api_version_default: apiVersionDefault,
    propagated,
    client_param_names: clientParamNames,
  };
}

function adaptEndpointFromParam(ep) {
  if (!ep) return { name: "endpoint", default_value: null };
  return {
    name: toSnakeCase(ep.name),
    default_value:
      ep.type?.templateArguments?.[0]?.clientDefaultValue ??
      ep.clientDefaultValue ??
      null,
  };
}

function defaultCredentialScopes(client) {
  // Look up the credential param on this client (or any ancestor) and
  // pick the first scope value the OAuth2 flow declares.
  let cur = client;
  while (cur) {
    for (const p of cur.clientInitialization?.parameters ?? []) {
      if (p.kind !== "credential") continue;
      const flows = p.type?.scheme?.flows ?? [];
      const scopes = [];
      for (const f of flows) {
        for (const s of f.scopes ?? []) {
          if (s.value) scopes.push(s.value);
        }
      }
      if (scopes.length > 0) return Array.from(new Set(scopes));
    }
    cur = cur.parent;
  }
  // Fallback: ARM scope if a `subscriptionId` parameter is present,
  // else the data-plane wildcard.
  const hasSub = (client.clientInitialization?.parameters ?? []).some(
    (p) => p.name === "subscriptionId",
  );
  return hasSub
    ? ["https://management.azure.com/.default"]
    : ["{endpoint}/.default"];
}

export function adaptMethod(method, clientParamNames) {
  const op = method.operation ?? {};
  const user = adaptUserParameters(method.parameters ?? [], clientParamNames);
  const wire = adaptWireParameters(op, clientParamNames, user.byMethodName);
  return {
    name: toSnakeCase(method.name),
    name_camel: toCamelCase(method.name),
    doc: method.doc ?? null,
    http_method: (op.verb ?? "get").toLowerCase(),
    path: op.path ?? "",
    uri_template: op.uriTemplate ?? op.path ?? "",
    /** User-facing args. Snake-cased name + type; the emitter renders
     *  these as method parameters in order. */
    user_parameters: user.list,
    /** Resolved path placeholders: `{ wire_name, source: {kind, name} }`. */
    path_parameters: wire.path,
    /** Query string keys: `{ wire_name, source, optional }`. */
    query_parameters: wire.query,
    /** Static + sourced headers. The emitter always sets the ones with
     *  `source.kind === "constant"`. */
    header_parameters: wire.header,
    /** Body to serialize; null for no-body operations. */
    body_parameter: wire.body,
    response: adaptMethodResponse(method.response, op.responses),
    responses: (op.responses ?? []).map(adaptResponseVariant),
    exceptions: (op.exceptions ?? []).map(adaptResponseVariant),
    paging: adaptPaging(method),
    long_running: adaptLro(method),
    kind: method.kind ?? "basic",
  };
}

/**
 * Extract the user-facing parameter list from a method. Filter out:
 *   - `accept` / `contentType` (constants emitted by the wire layer)
 *   - client-level parameters (`subscriptionId`, `apiVersion`,
 *     `endpoint`) — those are stored on the client struct
 *
 * Returns `{ list, byMethodName }`. `list` keeps spec declaration
 * order so the generated function signature matches the spec.
 * `byMethodName` is a `Map<string, UserParam>` keyed by the *raw*
 * TCGC name (camelCase) used by `methodParameterSegments` lookups.
 */
function adaptUserParameters(params, clientParamNames) {
  const list = [];
  const byMethodName = new Map();
  for (const p of params) {
    const snake = toSnakeCase(p.name);
    if (clientParamNames.has(snake)) continue;
    if (p.isApiVersionParam) continue;
    if (p.type?.kind === "constant") continue;
    // Anything else is a real user-facing arg.
    const out = {
      name: snake,
      method_name: p.name,
      doc: p.doc ?? null,
      param_type: adaptType(p.type),
      optional: !!p.optional,
    };
    list.push(out);
    byMethodName.set(p.name, out);
  }
  return { list, byMethodName };
}

/**
 * Walk `operation.parameters` + `operation.bodyParam` and tag each
 * HTTP-layer parameter with how to source its value at runtime:
 *
 *   - `{ kind: "client", name: "subscription_id" }`
 *   - `{ kind: "user",   name: "resource_group_name" }`
 *   - `{ kind: "constant", value: "application/json" }`
 *
 * Returns `{ path, query, header, body }`.
 */
function adaptWireParameters(op, clientParamNames, userByMethodName) {
  const path = [];
  const query = [];
  const header = [];
  let body = null;

  function sourceFor(p) {
    // 1. Sourced from the client struct? (subscription_id, etc.)
    if (p.onClient) {
      const snake = toSnakeCase(p.name);
      if (p.isApiVersionParam) {
        return { kind: "client", name: "api_version" };
      }
      if (clientParamNames.has(snake)) {
        return { kind: "client", name: snake };
      }
    }
    // 2. Constant from a TypeSpec literal (e.g. `Accept: "application/json"`).
    if (p.type?.kind === "constant") {
      return { kind: "constant", value: String(p.type.value ?? "") };
    }
    // 3. Sourced from a user-facing method parameter via the
    //    correspondence chain. Prefer `methodParameterSegments` over
    //    the deprecated `correspondingMethodParams`.
    const segs = p.methodParameterSegments?.[0] ?? p.correspondingMethodParams ?? [];
    for (const seg of segs) {
      const user = userByMethodName.get(seg.name);
      if (user) return { kind: "user", name: user.name };
    }
    // 4. Last-resort fallback to a constant value if the param has a
    //    `clientDefaultValue` (e.g. `accept` is sometimes modeled as a
    //    method param with a constant type that we already filtered).
    if (typeof p.clientDefaultValue !== "undefined") {
      return { kind: "constant", value: String(p.clientDefaultValue) };
    }
    return { kind: "user", name: toSnakeCase(p.name) };
  }

  for (const p of op.parameters ?? []) {
    const src = sourceFor(p);
    const entry = {
      wire_name: p.serializedName ?? p.name,
      source: src,
      optional: !!p.optional,
      style: p.kind === "path" ? (p.style ?? null) : null,
      explode:
        p.kind === "path" || p.kind === "query" ? !!p.explode : null,
      allow_reserved: p.kind === "path" ? !!p.allowReserved : null,
    };
    switch (p.kind) {
      case "path":
        path.push(entry);
        break;
      case "query":
        query.push(entry);
        break;
      case "header":
        header.push(entry);
        break;
      // We intentionally drop "cookie" — no Azure API uses it.
    }
  }

  if (op.bodyParam) {
    const bp = op.bodyParam;
    const segs = bp.methodParameterSegments?.[0] ?? bp.correspondingMethodParams ?? [];
    let userName = null;
    for (const seg of segs) {
      const user = userByMethodName.get(seg.name);
      if (user) {
        userName = user.name;
        break;
      }
    }
    body = {
      user_param_name: userName ?? toSnakeCase(bp.name),
      content_type:
        bp.defaultContentType ??
        (bp.contentTypes && bp.contentTypes[0]) ??
        "application/json",
      content_types: bp.contentTypes ?? [],
      body_type: adaptType(bp.type),
      serialization_kind: serializationKind(
        bp.serializationOptions,
        bp.contentTypes,
      ),
    };
  }

  return { path, query, header, body };
}

function adaptMethodResponse(resp, responses) {
  return {
    response_type: resp?.type ? adaptType(resp.type) : null,
    status_codes: (responses ?? []).flatMap((r) => normalizeStatusCodes(r.statusCodes)),
  };
}

function adaptResponseVariant(resp) {
  return {
    status_codes: normalizeStatusCodes(resp.statusCodes),
    response_type: resp.type ? adaptType(resp.type) : null,
    headers: (resp.headers ?? []).map((h) => ({
      name: toSnakeCase(h.name),
      wire_name: h.serializedName ?? h.name,
      header_type: adaptType(h.type),
      optional: !!h.optional,
    })),
    content_types: resp.contentTypes ?? [],
    body_kind: resp.type
      ? serializationKind(resp.serializationOptions, resp.contentTypes)
      : "none",
  };
}

function normalizeStatusCodes(statusCodes) {
  return typeof statusCodes === "undefined" ? [] : [statusCodes];
}

function serializationKind(options, contentTypes) {
  if (
    options?.multipart ||
    (contentTypes ?? []).some((c) =>
      c.toLowerCase().startsWith("multipart/"),
    )
  ) {
    return "multipart";
  }
  if (
    options?.json ||
    (contentTypes ?? []).some((c) =>
      c.toLowerCase().includes("json"),
    )
  ) {
    return "json";
  }
  return "raw";
}

function adaptPaging(method) {
  if (method.kind !== "paging" && method.kind !== "lropaging") return null;
  const meta = method.pagingMetadata ?? {};
  const items = meta.pageItemsSegments ?? [];
  // For the standard `{ "value": [T, ...], "nextLink": "..." }` ARM
  // envelope, surface the *item* type (T) so the Zig emitter can hand
  // it to `core.pager.listPageParser(T)` directly.
  let item_type = null;
  if (items.length === 1) {
    const leaf = items[0];
    if (leaf.type?.kind === "array" && leaf.type.valueType) {
      item_type = adaptType(leaf.type.valueType);
    }
  }
  return {
    items_segments: items.map((s) => s.name ?? null),
    next_link_segments: (meta.nextLinkSegments ?? []).map((s) => s.name ?? null),
    next_link_verb: meta.nextLinkVerb ?? null,
    next_link_operation: meta.nextLinkOperation?.name ?? null,
    /** Standard ARM-style page envelope marker. The emitter falls back
     *  to a hand-rolled parse if this isn't set. */
    envelope:
      items.length === 1 &&
      items[0].name === "value" &&
      (meta.nextLinkSegments ?? []).length === 1 &&
      meta.nextLinkSegments[0].name === "nextLink"
        ? "value_next_link"
        : null,
    item_type,
  };
}

function adaptLro(method) {
  if (method.kind !== "lro" && method.kind !== "lropaging") return null;
  const meta = method.lroMetadata ?? {};
  // For the typed final result we prefer the operation's own response
  // model (e.g. `PrivateCloud` for `privateClouds.update`) over the
  // polling envelope (`ArmOperationStatusResourceProvisioningState`
  // and similar). TCGC sets `method.response.type` to
  // `lroMetadata.finalResponse.result` — the user-visible final
  // result — or leaves it `undefined` when the LRO has no final body
  // (`lroMetadata.finalResponse === undefined`). That covers:
  //
  //   * ARM DELETE LROs (e.g. `privateClouds.delete`)
  //   * "Fire-and-forget" POST LROs (e.g. `rotateVcenterPassword`,
  //     `checkAvailability`, `restrictMovement`)
  //
  // Leaving `final_response_type` null in those cases makes the Zig
  // emitter fall back to `core.lro.TypedPoller(void)`, which skips
  // the final deserialize (see `sdk/core/lro.zig`:
  // `if (T == void) return;`).
  //
  // We deliberately do not fall back to `lroMetadata.envelopeResult`
  // when `method.response.type` is undefined: that field is the
  // polling-protocol envelope, not a user-visible payload, and
  // surfacing it would re-introduce
  // `TypedPoller(ArmOperationStatus...)` for void LROs.
  let result_type = null;
  if (method.response?.type) {
    result_type = adaptType(method.response.type);
  }
  return {
    final_state_via: meta.finalStateVia ?? null,
    final_response_type: result_type,
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

export function adaptModel(model) {
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
      multipart: adaptMultipartField(p.serializationOptions?.multipart),
    })),
    parents: model.baseModel ? [model.baseModel.name] : [],
    discriminator: model.discriminatorProperty?.name ?? null,
    is_input: !!(model.usage & 1),
    is_output: !!(model.usage & 2),
    arm_resource_kind: detectArmResourceKind(model),
    additional_properties: model.additionalProperties
      ? adaptType(model.additionalProperties)
      : null,
  };
}

function adaptMultipartField(multipart) {
  if (!multipart) return null;
  return {
    name: multipart.name,
    is_file: !!multipart.isFilePart,
    is_multi: !!multipart.isMulti,
    content_types: multipart.defaultContentTypes ?? [],
  };
}

export function adaptEnum(en) {
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
    is_union: !!en.isUnionAsEnum,
  };
}

export function adaptUnion(union) {
  if (union.kind === "nullable") {
    return {
      name: union.name,
      namespace: union.namespace ?? null,
      doc: union.doc ?? null,
      variants: [adaptType(union.type)],
      nullable: true,
    };
  }
  return {
    name: union.name,
    namespace: union.namespace ?? null,
    doc: union.doc ?? null,
    variants: (union.variantTypes ?? []).map(adaptType),
    nullable: false,
  };
}

export function adaptType(type) {
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
    case "tuple":
      return { kind: "Tuple", value: (type.valueTypes ?? []).map(adaptType) };
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

/** Lower-camel-case: keeps existing camelCase as-is, lowercases the
 *  first character. `PrivateClouds` → `privateClouds`. */
function toCamelCase(str) {
  const s = String(str);
  if (!s) return s;
  return s.charAt(0).toLowerCase() + s.slice(1);
}
