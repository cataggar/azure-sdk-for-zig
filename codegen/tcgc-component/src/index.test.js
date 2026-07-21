// SPDX-License-Identifier: MIT

import assert from "node:assert/strict";
import test from "node:test";

import {
  adaptEnum,
  adaptMethod,
  adaptModel,
  adaptUnion,
} from "./index.js";

const stringType = { kind: "string" };
const bytesType = { kind: "bytes" };

test("method adapter preserves protocol wire alternatives", () => {
  const nextLink = {
    kind: "method",
    name: "nextBlobUuidLink",
    type: stringType,
    optional: false,
  };
  const range = {
    kind: "method",
    name: "range",
    type: stringType,
    optional: false,
  };
  const value = {
    kind: "method",
    name: "value",
    type: bytesType,
    optional: false,
  };
  const method = adaptMethod(
    {
      name: "uploadChunk",
      kind: "basic",
      parameters: [nextLink, range, value],
      operation: {
        verb: "PATCH",
        path: "/{nextBlobUuidLink}",
        uriTemplate: "/{+nextBlobUuidLink}",
        parameters: [
          {
            ...nextLink,
            kind: "path",
            serializedName: "nextBlobUuidLink",
            style: "simple",
            explode: false,
            allowReserved: true,
            methodParameterSegments: [[nextLink]],
          },
          {
            ...range,
            kind: "header",
            serializedName: "Range",
            methodParameterSegments: [[range]],
          },
        ],
        bodyParam: {
          name: "value",
          type: bytesType,
          contentTypes: ["application/octet-stream"],
          defaultContentType: "application/octet-stream",
          serializationOptions: {},
          methodParameterSegments: [[value]],
        },
        responses: [{
          statusCodes: 202,
          headers: [{
            name: "dockerUploadUuid",
            serializedName: "Docker-Upload-UUID",
            type: stringType,
          }],
          serializationOptions: {},
        }],
        exceptions: [{
          statusCodes: "*",
          type: { kind: "model", name: "AcrErrors" },
          headers: [],
          contentTypes: ["application/json"],
          serializationOptions: { json: { name: "" } },
        }],
      },
      response: {},
    },
    new Set(),
  );

  assert.equal(method.uri_template, "/{+nextBlobUuidLink}");
  assert.equal(method.path_parameters[0].allow_reserved, true);
  assert.equal(method.header_parameters[0].source.kind, "user");
  assert.equal(method.body_parameter.serialization_kind, "raw");
  assert.deepEqual(method.response.status_codes, [202]);
  assert.equal(method.responses[0].headers[0].wire_name, "Docker-Upload-UUID");
  assert.equal(method.exceptions[0].status_codes[0], "*");
  assert.equal(method.exceptions[0].body_kind, "json");
});

test("model adapter preserves multipart fields and open records", () => {
  const multipart = adaptModel({
    name: "MultipartBodyParameter",
    namespace: "ContainerRegistry",
    properties: [{
      name: "grantType",
      serializedName: "grantType",
      type: stringType,
      serializationOptions: {
        multipart: {
          name: "grantType",
          isFilePart: false,
          isMulti: false,
          defaultContentTypes: ["text/plain"],
        },
      },
    }],
    usage: 2,
  });
  assert.equal(multipart.is_input, true);
  assert.equal(multipart.is_output, false);
  assert.deepEqual(multipart.fields[0].multipart, {
    name: "grantType",
    is_file: false,
    is_multi: false,
    content_types: ["text/plain"],
  });

  const open = adaptModel({
    name: "Annotations",
    properties: [],
    additionalProperties: {
      kind: "dict",
      valueType: { kind: "unknown" },
    },
    usage: 4,
  });
  assert.equal(open.is_input, false);
  assert.equal(open.is_output, true);
  assert.deepEqual(open.additional_properties, {
    kind: "Map",
    value: { kind: "Scalar", value: "unknown" },
  });
});

test("union metadata is not collapsed away", () => {
  const unionEnum = adaptEnum({
    name: "ArtifactArchitecture",
    values: [],
    valueType: stringType,
    isFixed: false,
    isUnionAsEnum: true,
  });
  assert.equal(unionEnum.is_union, true);

  const union = adaptUnion({
    kind: "union",
    name: "Payload",
    namespace: "ContainerRegistry",
    variantTypes: [stringType, bytesType],
  });
  assert.deepEqual(union.variants, [
    { kind: "Scalar", value: "string" },
    { kind: "Scalar", value: "bytes" },
  ]);
});
