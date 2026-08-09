// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
//
// build-devops-models.mjs — run the TCGC front-end over every converted
// Azure DevOps TypeSpec spec and write one JSON code model per API area.
//
// Areas that publish more than one spec (artifacts, distributedTask,
// advancedSecurity, …) are merged into a single code model so the Zig
// package gets one namespace per area, matching how Azure DevOps
// documents its REST surface.
//
// Usage:
//
//   node codegen/devops/build-devops-models.mjs <specs-dir> <out-dir> [area…]

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const here = path.dirname(fileURLToPath(import.meta.url));
const cli = path.resolve(here, "..", "tcgc-component", "src", "cli.js");

/** `workItemTracking` → `work_item_tracking`; `advancedSecurity.Reporting` → `advanced_security_reporting`. */
export function toSnakeCase(name) {
  return name
    .replace(/[.\s-]+/g, "_")
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/_+/g, "_")
    .toLowerCase();
}

/** `workItemTracking` → `WorkItemTrackingClient`. */
export function toRootClientName(area) {
  const pascal = toSnakeCase(area)
    .split("_")
    .map((segment) => segment[0].toUpperCase() + segment.slice(1))
    .join("");
  return `${pascal}Client`;
}

/**
 * Merge the code models of an area's specs into one.
 *
 * Azure DevOps repeats shared models (`ReferenceLinks`, `IdentityRef`)
 * across the specs of an area, so a later definition of an already-seen
 * name is dropped rather than duplicated. The per-spec root clients are
 * folded into a single root so the area has one entry point.
 */
export function mergeArea(models, area) {
  const rootName = toRootClientName(area);
  const clients = [];
  const seenClients = new Set();
  const mergedModels = [];
  const seenModels = new Set();
  const mergedEnums = [];
  const seenEnums = new Set();
  const mergedUnions = [];
  const seenUnions = new Set();
  let root = null;

  for (const model of models) {
    for (const client of model.clients) {
      if (client.is_root) {
        if (root === null) {
          root = {
            ...client,
            name: rootName,
            methods: [...client.methods],
            sub_clients: [...(client.sub_clients ?? [])],
          };
        } else {
          root.sub_clients.push(...(client.sub_clients ?? []));
          root.methods.push(...client.methods);
        }
        continue;
      }
      if (seenClients.has(client.name)) continue;
      seenClients.add(client.name);
      clients.push({ ...client, parent_name: rootName });
    }
    for (const m of model.models) {
      if (seenModels.has(m.name)) continue;
      seenModels.add(m.name);
      mergedModels.push(m);
    }
    for (const e of model.enums) {
      if (seenEnums.has(e.name)) continue;
      seenEnums.add(e.name);
      mergedEnums.push(e);
    }
    for (const u of model.unions ?? []) {
      if (seenUnions.has(u.name)) continue;
      seenUnions.add(u.name);
      mergedUnions.push(u);
    }
  }

  if (root !== null) {
    const seenSubClients = new Set();
    root.sub_clients = root.sub_clients.filter((sub) => {
      const key = sub.name ?? sub;
      if (seenSubClients.has(key)) return false;
      seenSubClients.add(key);
      return true;
    });
  }

  return {
    package_name: models[0].package_name,
    package_version: models[0].package_version,
    target_kind: models[0].target_kind,
    service_kind: models[0].service_kind,
    clients: root === null ? clients : [root, ...clients],
    models: mergedModels,
    enums: mergedEnums,
    unions: mergedUnions,
  };
}

function main() {
  const [specsDir, outDir, ...selected] = process.argv.slice(2);
  if (!specsDir || !outDir) {
    console.error("usage: build-devops-models.mjs <specs-dir> <out-dir> [area…]");
    process.exit(1);
  }

  const specsRoot = path.resolve(specsDir);
  const manifest = JSON.parse(fs.readFileSync(path.join(specsRoot, "manifest.json"), "utf8"));
  const entries = Array.isArray(manifest) ? manifest : manifest.specs;

  const byArea = new Map();
  for (const entry of entries) {
    if (selected.length && !selected.includes(entry.area)) continue;
    if (!byArea.has(entry.area)) byArea.set(entry.area, []);
    byArea.get(entry.area).push(entry);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const summary = [];
  const failures = [];

  for (const [area, specs] of [...byArea.entries()].sort()) {
    const models = [];
    let failed = false;
    for (const spec of specs) {
      const dir = path.join(specsRoot, area, spec.name);
      try {
        const stdout = execFileSync(
          process.execPath,
          [cli, dir, JSON.stringify({ package_name: "azure_rest_devops" })],
          { encoding: "utf8", maxBuffer: 512 * 1024 * 1024 },
        );
        models.push(JSON.parse(stdout));
      } catch (error) {
        failures.push({ area, spec: spec.name, error: String(error.stderr || error.message).slice(0, 400) });
        failed = true;
        break;
      }
    }
    if (failed) continue;

    const merged = models.length === 1 ? models[0] : mergeArea(models, area);
    const namespace = toSnakeCase(area);
    fs.writeFileSync(path.join(outDir, `${namespace}.json`), JSON.stringify(merged));
    const methods = merged.clients.reduce((total, c) => total + c.methods.length, 0);
    summary.push({
      area,
      namespace,
      display_name: area,
      specs: specs.length,
      clients: merged.clients.length,
      methods,
      endpoint: merged.clients.find((c) => c.is_root)?.endpoint?.default_value ?? null,
    });
    console.log(`ok   ${area} → ${namespace}.json (${merged.clients.length} clients, ${methods} operations)`);
  }

  fs.writeFileSync(path.join(outDir, "areas.json"), `${JSON.stringify(summary, null, 2)}\n`);
  console.log(`\n${summary.length}/${byArea.size} areas built`);
  for (const failure of failures) console.error(`FAIL ${failure.area}/${failure.spec}: ${failure.error}`);
  process.exit(failures.length === 0 ? 0 : 1);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main();
