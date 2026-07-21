// SPDX-License-Identifier: MIT

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

import { compile } from "../src/cli.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.dirname(here);
const specsRoot = process.env.AZURE_REST_API_SPECS ?? [
  path.resolve(packageRoot, "../../../azure-rest-api-specs"),
  path.resolve(packageRoot, "../../../../azure-rest-api-specs"),
].find((candidate) => fs.existsSync(candidate));
if (!specsRoot && !process.argv[2]) {
  throw new Error(
    "azure-rest-api-specs not found; set AZURE_REST_API_SPECS or pass the Registry path",
  );
}
const spec =
  process.argv[2] ??
  path.join(
    specsRoot,
    "specification/containerregistry/data-plane/Registry",
  );
const output =
  process.argv[3] ??
  path.resolve(packageRoot, "../fixtures/container_registry.json");

const json = await compile(
  spec,
  JSON.stringify({
    "package-name": "container_registry",
    "package-version": "0.1.0",
    "target-kind": "client",
  }),
);

fs.writeFileSync(output, json + "\n");
console.error(`wrote ${output}`);
