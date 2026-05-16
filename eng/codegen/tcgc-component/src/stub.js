// Stub TCGC component for wiring the wamr host. Returns a tiny canned
// JSON code model regardless of inputs.

export const tcgc = {
  compile(projectPath, emitterOptions) {
    const options = JSON.parse(emitterOptions || "{}");
    const out = {
      package_name: options["package-name"] || "azure_codegen_stub",
      package_version: options["package-version"] || "0.0.0",
      target_kind: "client",
      service_kind: "azure-dataplane",
      clients: [
        {
          name: "StubClient",
          namespace: "Stub",
          doc: "Component-stub client used to verify host wiring.",
          parameters: [],
          endpoint: { name: "endpoint", default_value: null },
          methods: [],
          sub_clients: [],
          credential_scopes: ["{endpoint}/.default"],
        },
      ],
      models: [],
      enums: [],
      unions: [],
    };
    return JSON.stringify(out);
  },
};
