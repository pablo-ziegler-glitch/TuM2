import assert from "node:assert/strict";
import test from "node:test";

import { redactRequestMetadata } from "../redaction";

test("headers sensibles se detectan sin exponer valores", () => {
  const metadata = redactRequestMetadata(
    {
      method: "post",
      path: "/api/internal/merchant-dump",
      ip: "203.0.113.10",
      headers: {
        authorization: "Bearer secret-token",
        cookie: "sessionid=private-cookie",
        "x-firebase-appcheck": "app-check-secret",
        "user-agent": "curl/8.4.0",
      },
      query: {
        token: "abc",
      },
      body: "sensitive-body",
    },
    "test-secret"
  );

  assert.equal(metadata.hasAuthHeader, true);
  assert.equal(metadata.hasCookieHeader, true);
  assert.equal(metadata.hasAppCheckHeader, true);
  assert.equal(metadata.userAgentFamily, "curl");
  assert.equal(metadata.bodyCaptured, false);
  assert.equal(metadata.queryKeys.includes("token"), true);

  const serialized = JSON.stringify(metadata);
  assert.equal(serialized.includes("secret-token"), false);
  assert.equal(serialized.includes("private-cookie"), false);
  assert.equal(serialized.includes("app-check-secret"), false);
  assert.equal(serialized.includes("abc"), false);
  assert.equal(serialized.includes("sensitive-body"), false);
});

test("bodySizeBytes registra tamaño y bodyCaptured siempre false", () => {
  const payload = { note: "hola", token: "sensitive" };
  const metadata = redactRequestMetadata(
    {
      method: "POST",
      path: "/api/claims/evidence-dump",
      headers: {
        "user-agent": "Mozilla/5.0",
      },
      query: {
        q: "x",
        page: "1",
      },
      body: payload,
    },
    "test-secret"
  );

  assert.equal(metadata.bodyCaptured, false);
  assert.equal(metadata.bodySizeBytes > 0, true);
  assert.equal(metadata.queryKeyCount, 2);
});

test("bodySizeBytes es 0 cuando no hay body", () => {
  const metadata = redactRequestMetadata(
    {
      method: "GET",
      path: "/wp-login.php",
      headers: {
        "user-agent": "unknown-agent",
      },
      query: {},
    },
    "test-secret"
  );
  assert.equal(metadata.bodySizeBytes, 0);
  assert.equal(metadata.bodyCaptured, false);
});
