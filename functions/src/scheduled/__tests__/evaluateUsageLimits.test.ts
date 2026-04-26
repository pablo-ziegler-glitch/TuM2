import assert from "node:assert/strict";
import test from "node:test";
import { runEvaluateUsageLimits } from "../evaluateUsageLimits";

test("reseteo automático diario desactiva mantenimiento cuando shutdown previo fue diario", async () => {
  let deactivateCalls = 0;
  let activateCalls = 0;

  const result = await runEvaluateUsageLimits({
    now: () => new Date("2026-04-24T03:05:00.000Z"), // 00:05 ARG
    ensureUsageCounterDocs: async () => undefined,
    getUsageSummary: async () => ({
      firestore_reads: 100,
      firestore_writes: 20,
      firestore_deletes: 0,
      functions_invocations: 1000,
      storage_downloads: 10,
      storage_uploads: 1,
      hosting_bandwidth_mb: 1,
      alert_level: "NORMAL",
      last_updated: new Date(),
    }),
    updateRemoteConfig: async () => undefined,
    sendSlackAlert: async () => undefined,
    activateShutdown: async () => {
      activateCalls += 1;
    },
    deactivateShutdown: async () => {
      deactivateCalls += 1;
    },
    getRemoteCurrentAlertLevel: async () => "SHUTDOWN",
    markCycleAsProcessed: async () => true,
    loadState: async () => ({
      alert_level: "SHUTDOWN",
      shutdown_reason: "firestore_reads_98pct_daily",
    }),
    saveState: async () => undefined,
    saveDailyAlert: async () => undefined,
    appendHistory: async () => undefined,
    registerShutdown: async () => undefined,
  });

  assert.equal(result.skipped, false);
  assert.equal(result.alertLevel, "NORMAL");
  assert.equal(activateCalls, 0);
  assert.equal(deactivateCalls, 1);
});
