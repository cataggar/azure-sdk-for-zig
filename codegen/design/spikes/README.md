# QuickJS feasibility spikes

Throwaway reproduction harnesses backing the spike results in
[`../replace-jco-with-quickjs.md`](../replace-jco-with-quickjs.md). They run
the real `tcgc-component` bundle under `quickjs-zig`'s `qjs` — **not** part
of the build; kept only as evidence / a starting point for the Zig host.

- `host_polyfills.js` — the missing-global shims (`TextEncoder`/
  `TextDecoder`, `queueMicrotask`, `structuredClone`,
  `crypto.subtle.digest("SHA-256")`). These become the production Zig host
  shims (backed by `std.crypto` / `std.unicode`).
- `demo_harness.mjs` — drives `compile()` against a small inline service.
- `avs_harness.mjs` — drives `compile()` against the large `Microsoft.AVS`
  ARM spec.

## Reproduce

From `codegen/tcgc-component/` (after `npm install --legacy-peer-deps` and
building `dist/bundled.js` via the bundle step of
`scripts/build-component.mjs`):

```bash
# 1. Bake the TypeSpec stdlib .tsp/package.json into a path->content map.
node -e '
const fs=require("fs"),path=require("path");
const lines=fs.readFileSync("dist/stdlib-preopens.txt","utf8").trim().split("\n");const out={};
function walk(h,v){for(const e of fs.readdirSync(h,{withFileTypes:true})){const hp=path.join(h,e.name),vp=v+"/"+e.name;if(e.isDirectory())walk(hp,vp);else if(e.name.endsWith(".tsp")||e.name==="package.json")out[vp]=fs.readFileSync(hp,"utf8");}}
for(const l of lines){const[h,v]=l.split("=");walk(h,v);}fs.writeFileSync("/tmp/stdlib.json",JSON.stringify(out));'

# 2. (AVS only) bake the spec .tsp files into /tmp/avs_spec.json keyed at /spec/.
node -e '
const fs=require("fs"),path=require("path");
const dir=process.env.HOME+"/azure-rest-api-specs/specification/vmware/resource-manager/Microsoft.AVS/AVS";
const out={};for(const e of fs.readdirSync(dir)){if(e.endsWith(".tsp"))out["/spec/"+e]=fs.readFileSync(path.join(dir,e),"utf8");}
fs.writeFileSync("/tmp/avs_spec.json",JSON.stringify(out));'

# 3. Run a harness. Large stack is required (QuickJS recurses on the C stack).
cp ../docs/spikes/host_polyfills.js ./_polyfills.js
cp ../docs/spikes/demo_harness.mjs ./_harness.mjs   # or avs_harness.mjs
( ulimit -s 524288; \
  /path/to/quickjs-zig/zig-out/bin/qjs --std --stack-size 400000000 \
    -I ./_polyfills.js -m ./_harness.mjs )
```
