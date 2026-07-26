// SPDX-License-Identifier: MIT

import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "../src/cli.js";

const sourcePath =
  "specification/cosmos-db/data-plane/Tables";
const here = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.dirname(here);
const specsRoot = process.env.AZURE_REST_API_SPECS ?? [
  path.resolve(packageRoot, "../../../azure-rest-api-specs"),
  path.resolve(packageRoot, "../../../../azure-rest-api-specs"),
].find((candidate) => fs.existsSync(candidate));
if (!specsRoot && !process.argv[2]) {
  throw new Error(
    "azure-rest-api-specs not found; set AZURE_REST_API_SPECS or pass the Tables path",
  );
}
const spec = process.argv[2] ?? path.join(specsRoot, sourcePath);
const output =
  process.argv[3] ??
  path.resolve(packageRoot, "../fixtures/data_tables.json");
const mainTsp = fs.readFileSync(path.join(spec, "main.tsp"), "utf8");
const versions = readStableVersions(mainTsp);
if (versions.length === 0) {
  throw new Error("Data.Tables.Versions contains no stable API version");
}
const selectedVersion = versions.at(-1);

const model = JSON.parse(
  await compile(
    spec,
    JSON.stringify({
      "package-name": "data_tables",
      "package-version": "0.1.0",
      "target-kind": "client",
    }),
  ),
);
for (const client of model.clients) {
  if (client.api_version_default !== selectedVersion) {
    throw new Error(
      `${client.name} selected ${client.api_version_default}; expected newest stable ${selectedVersion}`,
    );
  }
}

model.provenance = {
  source_repository: "https://github.com/Azure/azure-rest-api-specs",
  source_path: `${sourcePath}/tspconfig.yaml`,
  source_commit: resolveSourceCommit(spec),
  stable_api_versions: versions,
  selected_api_version: selectedVersion,
  batch_operation: model.clients
    .flatMap((client) => client.methods)
    .some(
      (method) =>
        method.name.toLowerCase().includes("batch") ||
        method.path.toLowerCase().includes("$batch"),
    )
    ? "present"
    : "absent",
};

fs.writeFileSync(output, JSON.stringify(model, null, 2) + "\n");
console.error(
  `wrote ${output} from ${model.provenance.source_commit} (${selectedVersion})`,
);

function readStableVersions(source) {
  const marker = source.indexOf("enum Versions");
  if (marker < 0) throw new Error("Data.Tables.Versions enum not found");
  const open = source.indexOf("{", marker);
  let depth = 0;
  let close = -1;
  for (let i = open; i < source.length; i += 1) {
    if (source[i] === "{") depth += 1;
    if (source[i] === "}") depth -= 1;
    if (depth === 0) {
      close = i;
      break;
    }
  }
  if (open < 0 || close < 0) throw new Error("invalid Versions enum");
  return [...source.slice(open + 1, close).matchAll(/:\s*"([^"]+)"/g)]
    .map((match) => match[1])
    .filter((version) => /^\d{4}-\d{2}-\d{2}$/.test(version))
    .sort();
}

function resolveSourceCommit(specPath) {
  if (process.env.AZURE_REST_API_SPECS_COMMIT) {
    return process.env.AZURE_REST_API_SPECS_COMMIT;
  }
  return execFileSync("git", ["-C", specPath, "rev-parse", "HEAD"], {
    encoding: "utf8",
  }).trim();
}
