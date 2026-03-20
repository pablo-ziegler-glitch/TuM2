import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, WriteBatch } from "firebase-admin/firestore";
import { isOpenNow, todayScheduleLabel } from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 500;

/**
 * nightlyRefreshOpenStatuses
 *
 * Runs every day at 00:05 Argentina time (03:05 UTC).
 * Recalculates isOpenNow for all visible merchants to correct
 * any drift caused by missed trigger events.
 */
export const nightlyRefreshOpenStatuses = onSchedule(
  {
    schedule: "5 3 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    console.log("[nightlyRefreshOpenStatuses] Starting...");

    const merchantsSnap = await db()
      .collection("merchant_public")
      .where("visibilityStatus", "==", "visible")
      .get();

    if (merchantsSnap.empty) {
      console.log("[nightlyRefreshOpenStatuses] No visible merchants found.");
      return;
    }

    const merchantIds = merchantsSnap.docs.map((d) => d.id);
    console.log(`[nightlyRefreshOpenStatuses] Processing ${merchantIds.length} merchants`);

    let updated = 0;
    const batches: WriteBatch[] = [];
    let currentBatch = db().batch();
    let batchOps = 0;

    for (const merchantId of merchantIds) {
      const scheduleSnap = await db()
        .doc(`merchant_schedules/${merchantId}`)
        .get();

      if (!scheduleSnap.exists) continue;

      const scheduleDoc = scheduleSnap.data() as MerchantScheduleDoc;
      const openNow = isOpenNow(scheduleDoc);
      const label = todayScheduleLabel(scheduleDoc);

      const publicRef = db().doc(`merchant_public/${merchantId}`);
      const signalRef = db().doc(`merchant_operational_signals/${merchantId}`);

      currentBatch.set(
        publicRef,
        {
          isOpenNow: openNow,
          todayScheduleLabel: label,
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      currentBatch.set(
        signalRef,
        {
          isOpenNow: openNow,
          todayScheduleLabel: label,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps += 2;
      updated++;

      if (batchOps >= BATCH_SIZE - 1) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) batches.push(currentBatch);

    await Promise.all(batches.map((b) => b.commit()));
    console.log(`[nightlyRefreshOpenStatuses] Done. Updated ${updated} merchants.`);
  }
);
