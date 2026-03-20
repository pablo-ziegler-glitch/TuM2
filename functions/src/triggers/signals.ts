import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { OperationalSignals } from "../lib/types";

const db = () => getFirestore();

/**
 * Merges operational signals with the following priority:
 *   temporaryClosed > manual overrides > schedule-derived values
 */
function mergeSignals(signals: OperationalSignals): Partial<OperationalSignals> {
  const merged: Partial<OperationalSignals> = { ...signals };

  if (signals.temporaryClosed === true) {
    // Override everything: merchant is temporarily closed
    merged.isOpenNow = false;
    merged.todayScheduleLabel = signals.temporaryClosedNote
      ? `Cerrado temporalmente: ${signals.temporaryClosedNote}`
      : "Cerrado temporalmente";
  }

  return merged;
}

/**
 * onSignalsWriteSyncPublic
 *
 * Triggered on any write to merchant_operational_signals/{merchantId}.
 * Merges signals (respecting priority) and propagates to merchant_public.
 */
export const onSignalsWriteSyncPublic = onDocumentWritten(
  "merchant_operational_signals/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const afterSnap = event.data?.after;

    if (!afterSnap?.exists) return;

    const signals = afterSnap.data() as OperationalSignals;
    const merged = mergeSignals(signals);

    await db()
      .doc(`merchant_public/${merchantId}`)
      .set(
        {
          operationalSignals: merged,
          isOpenNow: merged.isOpenNow ?? false,
          todayScheduleLabel: merged.todayScheduleLabel ?? "",
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    console.log(`[onSignalsWriteSyncPublic] Synced signals for ${merchantId}`);
  }
);
