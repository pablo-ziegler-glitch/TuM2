import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  getFirestore,
  FieldPath,
  FieldValue,
  WriteBatch,
} from "firebase-admin/firestore";
import { logFinOpsEvent } from "../lib/finops";
import { isOpenNow, todayScheduleLabel } from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";
import { shouldRunAutomaticFirestoreJob } from "../lib/automaticJobsGuard";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const READ_CHUNK_SIZE = 30;
const MAX_SCAN_PER_RUN = 300;

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
 * Recalcula estados operativos solo para documentos con transición vencida,
 * evitando escanear todo merchant_public en cada corrida.
 */
export const nightlyRefreshOpenStatuses = onSchedule(
  {
    schedule: "5 3 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    if (!shouldRunAutomaticFirestoreJob("nightlyRefreshOpenStatuses")) {
      return;
    }
    console.log("[nightlyRefreshOpenStatuses] Starting...");
    const now = FieldValue.serverTimestamp();
    const nowDate = new Date();
    const merchantsSnap = await db()
      .collection("merchant_public")
      .where("visibilityStatus", "==", "visible")
      .where("nextTransitionAt", "<=", nowDate)
      .orderBy("nextTransitionAt")
      .limit(MAX_SCAN_PER_RUN)
      .get();

    if (merchantsSnap.empty) {
      console.log("[nightlyRefreshOpenStatuses] No merchants due for transition.");
      return;
    }

    const merchantIds = merchantsSnap.docs.map((d) => d.id);
    const hasMore = merchantsSnap.size >= MAX_SCAN_PER_RUN;

    const merchantPublicById = new Map<string, FirebaseFirestore.DocumentData>();
    let scheduleReads = 0;
    for (const doc of merchantsSnap.docs) {
      merchantPublicById.set(doc.id, doc.data());
    }
    console.log(
      `[nightlyRefreshOpenStatuses] Visible window scanned=${merchantsSnap.size}`
    );

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
          isOpenNowSnapshot: openNow,
          snapshotComputedAt: now,
          todayScheduleLabel: label,
          updatedAt: now,
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
        scanned: merchantsSnap.size,
        dueByTransition: merchantIds.length,
        merchantScheduleReads: scheduleReads,
        signalWrites: updated,
        skippedUnchanged,
        hasMore,
      })
    );
    logFinOpsEvent({
      event: "job_refresh_open_statuses_window",
      level: hasMore ? "warning" : "info",
      module: "jobs.refreshOpenStatuses",
      payload: {
        scanned: merchantsSnap.size,
        dueByTransition: merchantIds.length,
        merchantScheduleReads: scheduleReads,
        signalWrites: updated,
        skippedUnchanged,
        hasMore,
      },
    });
  }
);
