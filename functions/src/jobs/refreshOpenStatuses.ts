import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  getFirestore,
  FieldPath,
  FieldValue,
  WriteBatch,
} from "firebase-admin/firestore";
import { isOpenNow, todayScheduleLabel } from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const READ_CHUNK_SIZE = 30;

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

/**
 * nightlyRefreshOpenStatuses
 *
 * Runs every day at 03:05 Argentina time.
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
    const merchantPublicById = new Map<string, FirebaseFirestore.DocumentData>();
    let scheduleReads = 0;
    for (const doc of merchantsSnap.docs) {
      merchantPublicById.set(doc.id, doc.data());
    }
    console.log(`[nightlyRefreshOpenStatuses] Processing ${merchantIds.length} merchants`);

    const scheduleMap = new Map<string, MerchantScheduleDoc>();
    for (const idsChunk of chunk(merchantIds, READ_CHUNK_SIZE)) {
      const schedulesSnap = await db()
        .collection("merchant_schedules")
        .where(FieldPath.documentId(), "in", idsChunk)
        .get();
      scheduleReads += schedulesSnap.size;

      for (const scheduleDoc of schedulesSnap.docs) {
        scheduleMap.set(scheduleDoc.id, scheduleDoc.data() as MerchantScheduleDoc);
      }
    }

    let updated = 0;
    let skippedUnchanged = 0;
    const batches: WriteBatch[] = [];
    let currentBatch = db().batch();
    let batchOps = 0;

    for (const merchantId of merchantIds) {
      const scheduleDoc = scheduleMap.get(merchantId);
      if (!scheduleDoc) continue;
      const openNow = isOpenNow(scheduleDoc);
      const label = todayScheduleLabel(scheduleDoc);
      const currentPublic = merchantPublicById.get(merchantId) ?? {};
      const currentOpenNow = currentPublic["isOpenNow"] === true;
      const currentLabel = typeof currentPublic["todayScheduleLabel"] === "string"
        ? (currentPublic["todayScheduleLabel"] as string)
        : "";
      if (currentOpenNow === openNow && currentLabel === label) {
        skippedUnchanged++;
        continue;
      }

      const signalRef = db().doc(`merchant_operational_signals/${merchantId}`);

      currentBatch.set(
        signalRef,
        {
          isOpenNow: openNow,
          todayScheduleLabel: label,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps += 1;
      updated++;

      if (batchOps >= BATCH_SIZE - 1) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) batches.push(currentBatch);

    if (batches.length > 0) {
      await Promise.all(batches.map((b) => b.commit()));
    }
    console.log(
      `[nightlyRefreshOpenStatuses] Done. Updated ${updated} merchants, skippedUnchanged=${skippedUnchanged}.`
    );
    console.log(
      JSON.stringify({
        job: "nightlyRefreshOpenStatuses",
        merchantPublicReads: merchantsSnap.size,
        merchantScheduleReads: scheduleReads,
        signalWrites: updated,
        skippedUnchanged,
      })
    );
  }
);
