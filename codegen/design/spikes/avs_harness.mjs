import * as std from "std";
import { compile } from "./dist/bundled.js";

const stdlib = JSON.parse(std.loadFile("/tmp/stdlib.json"));
const avs = JSON.parse(std.loadFile("/tmp/avs_spec.json"));

const specFiles = Object.assign({}, stdlib, avs);
const options = {
  "package-name": "vmware_avs",
  "target-kind": "arm",
  __spec_files: specFiles,
};

const t0 = Date.now();
try {
  const json = await compile("/spec", JSON.stringify(options));
  const ms = Date.now() - t0;
  let clients = 0, models = 0;
  try { const o = JSON.parse(json); clients = (o.clients||[]).length; models = (o.models||o.types||[]).length; } catch {}
  console.log("AVS COMPILE OK in", ms, "ms; json length =", json.length, "clients =", clients);
} catch (e) {
  const msg = (e && (e.payload || e.message)) || String(e);
  console.log("AVS COMPILE ERROR:", String(msg).split("\n").slice(0,4).join("\n"));
}
