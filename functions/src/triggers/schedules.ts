import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  computeNextScheduleTransition,
  isOpenNow,
  todayScheduleLabel,
} from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";

const db = () => getFirestore();

function scheduleComparableShape(doc: MerchantScheduleDoc | undefined): string {
  if (!doc) return "{}";
  return JSON.stringify({
    schedule: doc.schedule ?? null,
    timezone: doc.timezone ?? null,
  });
}

/**
 * onScheduleWriteRecalculateOpenNow
 *
 * Triggered on any write to merchant_schedules/{merchantId}.
 * Recalculates isOpenNow and todayScheduleLabel and propagates to
 * merchant_operational_signals/{merchantId}.
 * merchant_public se sincroniza desde onSignalsWriteSyncPublic.
 */
export const onScheduleWriteRecalculateOpenNow = onDocumentWritten(
  "merchant_schedules/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    if (!afterSnap?.exists) return;

    const scheduleDoc = afterSnap.data() as MerchantScheduleDoc;
    const openNow = isOpenNow(scheduleDoc);
    const scheduleLabel = todayScheduleLabel(scheduleDoc);
    const transitions = computeNextScheduleTransition(scheduleDoc);

    if (beforeSnap?.exists) {
      const beforeDoc = beforeSnap.data() as MerchantScheduleDoc;
      if (scheduleComparableShape(beforeDoc) === scheduleComparableShape(scheduleDoc)) {
        return;
      }
      const beforeOpenNow = isOpenNow(beforeDoc);
      const beforeScheduleLabel = todayScheduleLabel(beforeDoc);
      if (beforeOpenNow === openNow && beforeScheduleLabel === scheduleLabel) {
        return;
      }
    }

    const signalUpdate = {
      isOpenNow: openNow,
      isOpenNowSnapshot: openNow,
      snapshotComputedAt: FieldValue.serverTimestamp(),
      todayScheduleLabel: scheduleLabel,
      scheduleSummary: transitions.scheduleSummary,
      nextOpenAt: transitions.nextOpenAt,
      nextCloseAt: transitions.nextCloseAt,
      nextTransitionAt: transitions.nextTransitionAt,
      hasScheduleConfigured: transitions.scheduleSummary.hasSchedule,
      updatedAt: FieldValue.serverTimestamp(),
    };

    await db()
      .doc(`merchant_operational_signals/${merchantId}`)
      .set(signalUpdate, { merge: true });

    console.log(
      `[onScheduleWriteRecalculateOpenNow] ${merchantId} isOpenNow=${openNow}`
    );
  }
);
