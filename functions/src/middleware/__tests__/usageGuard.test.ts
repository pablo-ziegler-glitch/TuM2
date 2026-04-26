import assert from "node:assert/strict";
import test, { afterEach } from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import {
  __resetUsageGuardDependenciesForTest,
  __setUsageGuardDependenciesForTest,
  withUsageGuard,
} from "../usageGuard";

afterEach(() => {
  __resetUsageGuardDependenciesForTest();
});

test("withUsageGuard bloquea requests en SHUTDOWN", async () => {
  let handlerCalled = false;
  __setUsageGuardDependenciesForTest({
    getCurrentAlertLevel: async () => "SHUTDOWN",
    trackUsage: async () => undefined,
  });

  const wrapped = withUsageGuard(async () => {
    handlerCalled = true;
    return { ok: true };
  });

  await assert.rejects(
    async () => wrapped({ data: {}, auth: null } as never),
    (error) =>
      error instanceof HttpsError &&
      error.code === "unavailable" &&
      error.message.includes("temporalmente")
  );
  assert.equal(handlerCalled, false);
});
