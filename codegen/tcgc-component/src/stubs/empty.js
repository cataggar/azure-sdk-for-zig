// Empty stub for modules we don't use at runtime.
//
// `formatter/` etc. only runs for `tsp format`, not `tsp compile`.
// Anything imported from these stubs should never actually be called.
// Use a Proxy so ANY named import resolves to a no-op throw.

const noopHandler = {
  get(_target, prop) {
    if (prop === Symbol.toPrimitive) return () => "";
    if (prop === "__esModule") return true;
    if (prop === "default") return noopProxy;
    return noopProxy;
  },
};

const noopProxy = new Proxy(function () {
  throw new Error("stub: called a stubbed-out module function");
}, noopHandler);

export default noopProxy;
export const builders = noopProxy;
export const check = noopProxy;
export const format = noopProxy;
export const Parser = undefined;
export const SupportLanguage = undefined;
export const AstPath = undefined;
export const Doc = undefined;
export const Printer = undefined;
