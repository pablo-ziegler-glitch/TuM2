import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  normalizeOperationalPublicStateForDiff,
  resolveOperationalPublicState,
} from "../lib/operationalSignals";
import { OperationalSignals } from "../lib/types";

const db = () => getFirestore();

function stableStringify(value: unknown): string {
  return JSON.stringify(value);
}

/**
 * onSignalsWriteSyncPublic
 *
 * Triggered on any write to merchant_operational_signals/{merchantId}.
 * Resuelve precedencia manual override > cálculo automático y sincroniza
 * merchant_public con no-op write avoidance.
 */
export const onSignalsWriteSyncPublic = onDocumentWritten(
  "merchant_operational_signals/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    const beforeSignals = beforeSnap?.exists
      ? (beforeSnap.data() as OperationalSignals)
      : undefined;
    const afterSignals = afterSnap?.exists
      ? (afterSnap.data() as OperationalSignals)
      : undefined;

    const resolvedBefore = resolveOperationalPublicState(beforeSignals);
    const resolvedAfter = resolveOperationalPublicState(afterSignals);
    const diffBefore = normalizeOperationalPublicStateForDiff(resolvedBefore);
    const diffAfter = normalizeOperationalPublicStateForDiff(resolvedAfter);

    const skipWrite = stableStringify(diffBefore) === stableStringify(diffAfter);
    if (skipWrite) {
      console.log(
        JSON.stringify({
          trigger: "onSignalsWriteSyncPublic",
          merchantId,
          signalType: resolvedAfter.operationalSignalType,
          overrideMode: resolvedAfter.manualOverrideMode,
          forceClosed: resolvedAfter.manualOverrideMode === "force_closed",
          projectionWriteSkipped: true,
          reason: "no_diff",
        })
      );
      return;
    }

    const updatedAt = afterSnap?.exists
      ? (afterSnap.data()?.["updatedAt"] ?? null)
      : null;

    await db()
      .doc(`merchant_public/${merchantId}`)
      .set(
        {
          hasOperationalSignal: resolvedAfter.hasOperationalSignal,
          operationalSignalType: resolvedAfter.operationalSignalType,
          operationalSignalMessage: resolvedAfter.operationalSignalMessage,
          operationalSignalUpdatedAt: updatedAt,
          manualOverrideMode: resolvedAfter.manualOverrideMode,
          operationalStatusLabel: resolvedAfter.operationalStatusLabel,
          isOpenNow: resolvedAfter.isOpenNow,
          todayScheduleLabel: resolvedAfter.todayScheduleLabel,
          hasPharmacyDutyToday: resolvedAfter.hasPharmacyDutyToday,
          operationalSignals: resolvedAfter.operationalSignals,
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    console.log(
      JSON.stringify({
        trigger: "onSignalsWriteSyncPublic",
        merchantId,
        signalType: resolvedAfter.operationalSignalType,
        overrideMode: resolvedAfter.manualOverrideMode,
        forceClosed: resolvedAfter.manualOverrideMode === "force_closed",
        projectionWriteSkipped: false,
        reason: "projection_updated",
      })
    );
  }
);

