import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { isOpenNow, todayScheduleLabel } from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";

const db = () => getFirestore();

/**
 * onScheduleWriteRecalculateOpenNow
 *
 * Triggered on any write to merchant_schedules/{merchantId}.
 * Recalculates isOpenNow and todayScheduleLabel and propagates to:
 * - merchant_operational_signals/{merchantId}
 * - merchant_public/{merchantId}
 */
export const onScheduleWriteRecalculateOpenNow = onDocumentWritten(
  "merchant_schedules/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const afterSnap = event.data?.after;

    if (!afterSnap?.exists) return;

    const scheduleDoc = afterSnap.data() as MerchantScheduleDoc;

    const openNow = isOpenNow(scheduleDoc);
    const scheduleLabel = todayScheduleLabel(scheduleDoc);

    const signalUpdate = {
      isOpenNow: openNow,
      todayScheduleLabel: scheduleLabel,
      updatedAt: FieldValue.serverTimestamp(),
    };

    await Promise.all([
      db()
        .doc(`merchant_operational_signals/${merchantId}`)
        .set(signalUpdate, { merge: true }),
      db()
        .doc(`merchant_public/${merchantId}`)
        .set(
          {
            isOpenNow: openNow,
            todayScheduleLabel: scheduleLabel,
            syncedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
    ]);

    console.log(
      `[onScheduleWriteRecalculateOpenNow] ${merchantId} isOpenNow=${openNow}`
    );
  }
);
