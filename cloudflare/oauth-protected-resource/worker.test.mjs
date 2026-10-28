import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "./worker.mjs";

const env = {
  RESOURCE: "https://sleeppuzzle.com",
  ACCESS_ISSUER: "https://access.example.com/application"
};
const endpoint = `${env.RESOURCE}/.well-known/oauth-protected-resource`;

test("anonymous discovery returns JSON with the configured resource and exact issuer", async () => {
  for (const accept of ["application/json", "text/html", "text/markdown", "*/*"]) {
    const response = await worker.fetch(new Request(endpoint, {
      headers: { Accept: accept }
    }), env);

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("Content-Type"), "application/json; charset=utf-8");
    assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
    assert.deepEqual(await response.json(), {
      resource: env.RESOURCE,
      authorization_servers: [env.ACCESS_ISSUER]
    });
  }
});

test("HEAD returns the metadata headers with an empty body", async () => {
  const response = await worker.fetch(new Request(endpoint, { method: "HEAD" }), env);
  assert.equal(response.status, 200);
  assert.match(response.headers.get("Content-Type"), /^application\/json/);
  assert.equal(await response.text(), "");
});

test("discovery permits browser preflight", async () => {
  const response = await worker.fetch(new Request(endpoint, { method: "OPTIONS" }), env);
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Methods"), "GET, HEAD, OPTIONS");
});

test("unsupported methods cannot mutate anything", async () => {
  const response = await worker.fetch(new Request(endpoint, { method: "POST" }), env);
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("Allow"), "GET, HEAD, OPTIONS");
});

test("query strings work but unrelated paths and wildcard suffixes return 404", async () => {
  assert.equal((await worker.fetch(new Request(`${endpoint}?discovery=1`), env)).status, 200);
  for (const path of ["/", "/users/sign_in", "/.well-known/oauth-protected-resource/other",
    "/.well-known/oauth-protected-resource.json"]) {
    assert.equal((await worker.fetch(new Request(`${env.RESOURCE}${path}`), env)).status, 404);
  }
});

test("missing or invalid configuration never publishes misleading metadata", async () => {
  const invalidIssuers = [undefined, "", "http://access.example.com", "not a URL",
    "https://access.example.com/#fragment", "https://access.example.com/?query=1",
    "https://user:secret@access.example.com", " https://access.example.com"];
  const invalidResources = [undefined, "http://sleeppuzzle.com", "https://sleeppuzzle.com/path",
    "https://sleeppuzzle.com/", "https://sleeppuzzle.com?query=1"];
  for (const config of [
    ...invalidIssuers.map(ACCESS_ISSUER => ({ ...env, ACCESS_ISSUER })),
    ...invalidResources.map(RESOURCE => ({ ...env, RESOURCE }))
  ]) {
    const response = await worker.fetch(new Request(endpoint), config);
    assert.equal(response.status, 503);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    assert.equal(await response.text(), "");
  }
});
