import assert from "node:assert/strict";
import test from "node:test";

import { hashIp, hashUserAgent } from "../hash";

test("misma IP y mismo secret produce mismo hash", () => {
  const first = hashIp("203.0.113.10", "secret-a");
  const second = hashIp("203.0.113.10", "secret-a");
  assert.equal(first, second);
});

test("misma IP y distinto secret produce distinto hash", () => {
  const first = hashIp("203.0.113.10", "secret-a");
  const second = hashIp("203.0.113.10", "secret-b");
  assert.notEqual(first, second);
});

test("IP vacía usa valor controlado unknown", () => {
  const empty = hashIp("", "secret-a");
  const unknown = hashIp(undefined, "secret-a");
  assert.equal(empty, unknown);
});

test("hashes no exponen el valor original", () => {
  const rawIp = "203.0.113.10";
  const rawUa = "curl/8.4.0";
  const ipHash = hashIp(rawIp, "secret-a");
  const uaHash = hashUserAgent(rawUa, "secret-a");
  assert.equal(ipHash.includes(rawIp), false);
  assert.equal(uaHash.includes(rawUa), false);
});
