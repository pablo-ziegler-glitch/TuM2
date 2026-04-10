import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  getFirestore,
  FieldPath,
  FieldValue,
  WriteBatch,
} from "firebase-admin/firestore";
import { isOpenNow, todayScheduleLabel } from "../lib/schedules";
import { MerchantScheduleDoc } from "../lib/types";
import { shouldRunAutomaticFirestoreJob } from "../lib/automaticJobsGuard";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const READ_CHUNK_SIZE = 30;
const MAX_SCAN_PER_RUN = 2000;
const CURSOR_DOC = "system_jobs/nightlyRefreshOpenStatuses";

interface OpenStatusCursorDoc {
  lastDocId?: string;
}

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
    if (!shouldRunAutomaticFirestoreJob("nightlyRefreshOpenStatuses")) {
      return;
    }
    console.log("[nightlyRefreshOpenStatuses] Starting...");

    const cursorRef = db().doc(CURSOR_DOC);
    const cursorSnap = await cursorRef.get();
    const cursorRaw = cursorSnap.exists
      ? (cursorSnap.data() as OpenStatusCursorDoc)
      : undefined;
    const cursorDocId =
      typeof cursorRaw?.lastDocId === "string" && cursorRaw.lastDocId.trim().length > 0
        ? cursorRaw.lastDocId.trim()
        : null;

    let scanQuery = db()
      .collection("merchant_public")
      .where("visibilityStatus", "==", "visible")
      .orderBy(FieldPath.documentId())
      .limit(MAX_SCAN_PER_RUN);
    if (cursorDocId) {
      scanQuery = scanQuery.startAfter(cursorDocId);
    }
    let merchantsSnap = await scanQuery.get();
    let restartedFromBeginning = false;
    if (merchantsSnap.empty && cursorDocId != null) {
      await cursorRef.set(
        {
          lastDocId: "",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      merchantsSnap = await db()
        .collection("merchant_public")
        .where("visibilityStatus", "==", "visible")
        .orderBy(FieldPath.documentId())
        .limit(MAX_SCAN_PER_RUN)
        .get();
      restartedFromBeginning = true;
    }

    if (merchantsSnap.empty) {
      console.log("[nightlyRefreshOpenStatuses] No merchants in current scan window.");
      return;
    }

    const merchantIds = merchantsSnap.docs.map((d) => d.id);
    const lastScannedDocId = merchantsSnap.docs[merchantsSnap.docs.length - 1]?.id ?? "";
    const hasMore = merchantsSnap.size >= MAX_SCAN_PER_RUN;
    await cursorRef.set(
      {
        lastDocId: hasMore ? lastScannedDocId : "",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

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
        scanned: merchantsSnap.size,
        visibleScanned: merchantIds.length,
        merchantScheduleReads: scheduleReads,
        signalWrites: updated,
        skippedUnchanged,
        hasMore,
        restartedFromBeginning,
        lastScannedDocId,
      })
    );
    logFinOpsEvent({
      event: "job_refresh_open_statuses_window",
      level: hasMore ? "warning" : "info",
      module: "jobs.refreshOpenStatuses",
      payload: {
        scanned: merchantsSnap.size,
        visibleScanned: merchantIds.length,
        merchantScheduleReads: scheduleReads,
        signalWrites: updated,
        skippedUnchanged,
        hasMore,
        restartedFromBeginning,
        lastScannedDocId,
      },
    });
  }
);
