import assert from "node:assert/strict";
import test, { afterEach } from "node:test";
import {
  __resetCircuitBreakerDependenciesForTest,
  __setCircuitBreakerDependenciesForTest,
  deactivateShutdown,
} from "../circuitBreaker";

afterEach(() => {
  __resetCircuitBreakerDependenciesForTest();
});

test("deactivateShutdown no reactiva si métricas siguen altas (85%)", async () => {
  let publishCalls = 0;

  __setCircuitBreakerDependenciesForTest({
    getUsageSummary: async () => ({
      firestore_reads: 42_500,
      firestore_writes: 0,
      firestore_deletes: 0,
      functions_invocations: 0,
      storage_downloads: 0,
      storage_uploads: 0,
      hosting_bandwidth_mb: 0,
      alert_level: "CRITICAL",
      last_updated: new Date(),
    }),
    publishRemoteConfig: async () => {
      publishCalls += 1;
    },
  });

  await deactivateShutdown();
  assert.equal(publishCalls, 0);
});
