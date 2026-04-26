import assert from "node:assert/strict";
import test from "node:test";
import { DAILY_LIMITS, calculateAlertLevel } from "../usageTracker";

test("calculateAlertLevel: 0 uso -> NORMAL", () => {
  const level = calculateAlertLevel({
    firestore_reads: 0,
    firestore_writes: 0,
    firestore_deletes: 0,
    storage_downloads: 0,
    storage_uploads: 0,
    functions_invocations: 0,
    hosting_bandwidth_mb: 0,
  });
  assert.equal(level, "NORMAL");
});

test("calculateAlertLevel: 25000 reads (50%) -> WARNING", () => {
  const level = calculateAlertLevel({
    firestore_reads: Math.floor(DAILY_LIMITS.firestore_reads * 0.5),
  });
  assert.equal(level, "WARNING");
});

test("calculateAlertLevel: 37500 reads (75%) -> DANGER", () => {
  const level = calculateAlertLevel({
    firestore_reads: Math.floor(DAILY_LIMITS.firestore_reads * 0.75),
  });
  assert.equal(level, "DANGER");
});

test("calculateAlertLevel: 47500 reads (95%) -> SHUTDOWN", () => {
  const level = calculateAlertLevel({
    firestore_reads: Math.floor(DAILY_LIMITS.firestore_reads * 0.95),
  });
  assert.equal(level, "SHUTDOWN");
});

test("calculateAlertLevel: una métrica WARNING y otra DANGER -> DANGER", () => {
  const level = calculateAlertLevel({
    firestore_reads: Math.floor(DAILY_LIMITS.firestore_reads * 0.5),
    firestore_writes: Math.floor(DAILY_LIMITS.firestore_writes * 0.75),
  });
  assert.equal(level, "DANGER");
});
