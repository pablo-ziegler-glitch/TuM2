import assert from "node:assert/strict";
import test, { afterEach } from "node:test";

import { handleSecurityTrapRequest } from "../securityTrap";

interface MockResponseState {
  headers: Record<string, string>;
  statusCode: number | null;
  body: unknown;
}

function createResponseMock(): {
  state: MockResponseState;
  response: {
    set: (name: string, value: string) => void;
    status: (code: number) => { json: (body: unknown) => void };
  };
} {
  const state: MockResponseState = {
    headers: {},
    statusCode: null,
    body: null,
  };

  return {
    state,
    response: {
      set(name: string, value: string) {
        state.headers[name] = value;
      },
      status(code: number) {
        state.statusCode = code;
        return {
          json(body: unknown) {
            state.body = body;
          },
        };
      },
    },
  };
}

const originalTrapEnabled = process.env.SECURITY_TRAP_ENABLED;
const originalHashSecret = process.env.SECURITY_HASH_SECRET;
const originalEmulator = process.env.FUNCTIONS_EMULATOR;
const originalProject = process.env.GCLOUD_PROJECT;
const originalConsoleLog = console.log;

afterEach(() => {
  process.env.SECURITY_TRAP_ENABLED = originalTrapEnabled;
  process.env.SECURITY_HASH_SECRET = originalHashSecret;
  process.env.FUNCTIONS_EMULATOR = originalEmulator;
  process.env.GCLOUD_PROJECT = originalProject;
  console.log = originalConsoleLog;
});

test("cuando está deshabilitado, responde 404 sin log", async () => {
  process.env.SECURITY_TRAP_ENABLED = "false";
  process.env.SECURITY_HASH_SECRET = "test-secret";

  let logCalls = 0;
  console.log = (...args: unknown[]) => {
    void args;
    logCalls += 1;
  };

  const { state, response } = createResponseMock();
  await handleSecurityTrapRequest(
    {
      method: "GET",
      path: "/wp-login.php",
      headers: { "user-agent": "curl/8.4.0" },
      query: {},
    },
    response
  );

  assert.equal(logCalls, 0);
  assert.equal(state.statusCode, 404);
  assert.equal(state.headers["Cache-Control"], "no-store");
  assert.deepEqual(state.body, { error: "not_found" });
});

test("cuando detecta honeytoken, loguea critical y responde 404", async () => {
  process.env.SECURITY_TRAP_ENABLED = "true";
  process.env.SECURITY_HASH_SECRET = "test-secret";
  process.env.GCLOUD_PROJECT = "tum2-dev-6283d";

  let rawLog = "";
  console.log = (...args: unknown[]) => {
    rawLog = args.map((item) => String(item)).join(" ");
  };

  const { state, response } = createResponseMock();
  await handleSecurityTrapRequest(
    {
      method: "POST",
      path: "/api/admin/export-users",
      ip: "203.0.113.12",
      headers: {
        "user-agent": "python-requests/2.0",
        authorization: "Bearer tum2_honey_key_001",
      },
      query: {
        token: "tum2_honey_key_001",
      },
      body: {
        value: "tum2_honey_key_001",
      },
    },
    response
  );

  assert.equal(state.statusCode, 404);
  assert.deepEqual(state.body, { error: "not_found" });
  assert.ok(rawLog.length > 0);

  const payload = JSON.parse(rawLog) as Record<string, unknown>;
  assert.equal(payload.eventType, "security_honeypot_hit");
  assert.equal(payload.environment, "dev");
  assert.equal(payload.severity, "critical");
  assert.equal(payload.riskScore, 100);
  assert.equal(payload.honeytokenDetected, true);
  assert.equal(payload.responseStatus, 404);
  assert.equal(payload.trapCategory, "tum2_admin_probe");
});
