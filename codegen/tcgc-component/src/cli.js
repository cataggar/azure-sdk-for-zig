// SPDX-License-Identifier: MIT
//
// CLI entrypoint for the TypeSpec → JSON code-model emitter. Drives
// the TypeSpec compiler in-process with our package registered as
// `--emit`, then writes the resulting code model to stdout.
//
// Lives in its own file (separate from `src/index.js`) because
// `node:fs` / `node:path` / `node:url` aren't available inside the
// wasm bundle that `tcgc-component/scripts/build-component.mjs`
// produces. The wasm path uses `src/wasi-host.js` instead, which
// surfaces the spec files through WASI preopens.
//
// Usage:
//
//   node src/cli.js <project-path> [emitter-options-json]

import {
  compile as tspCompile,
  NodeHost,
  resolvePath,
} from "@typespec/compiler";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

import { LIB_NAME, __slot } from "./index.js";

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

function packageRoot() {
  // src/cli.js → ../
  const here = fileURLToPath(import.meta.url);
  return resolvePath(path.dirname(path.dirname(here)));
}

function joinTmp() {
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
 */
function stageSpec(inputPath) {
  const root = packageRoot();
  const stagingRoot = path.join(root, ".tsp-staging");
  fs.rmSync(stagingRoot, { recursive: true, force: true });
  fs.mkdirSync(stagingRoot, { recursive: true });

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

/* ───────────────────────── CLI ───────────────────────────────────── */

if (
  typeof process !== "undefined" &&
  typeof process.argv?.[1] === "string" &&
  process.argv[1].endsWith("cli.js")
) {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error(
      "Usage: node src/cli.js <project-path> [emitter-options-json]",
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
