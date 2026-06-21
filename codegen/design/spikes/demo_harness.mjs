import * as std from "std";
import { compile } from "./dist/bundled.js";

const stdlib = JSON.parse(std.loadFile("/tmp/stdlib.json"));

const main = `
import "@typespec/http";
import "@typespec/rest";

using Http;

@service(#{ title: "Widget Service" })
namespace DemoService;

model Widget {
  @key id: string;
  weight: int32;
}

@route("/widgets")
interface Widgets {
  @get list(): Widget[];
  @get read(@path id: string): Widget;
}
`;

const specFiles = Object.assign({}, stdlib, { "/spec/main.tsp": main });
const options = { "package-name": "demo", __spec_files: specFiles };

try {
  const json = await compile("/spec", JSON.stringify(options));
  console.log("COMPILE OK, json length =", json.length);
  console.log(json.slice(0, 400));
} catch (e) {
  const msg = (e && (e.payload || e.message)) || String(e);
  console.log("COMPILE ERROR:", msg);
}
