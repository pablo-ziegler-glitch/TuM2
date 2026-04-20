import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  getFirestore,
  FieldPath,
  FieldValue,
  QueryDocumentSnapshot,
  WriteBatch,
} from "firebase-admin/firestore";
import { todayDateString } from "../lib/schedules";
import { DutyStatus, normalizeDutyStatus } from "../lib/pharmacyDutyMitigation";
import { shouldRunAutomaticFirestoreJob } from "../lib/automaticJobsGuard";

const db = () => getFirestore();
const BATCH_SIZE = 500;
const DUTY_SCAN_PAGE_SIZE = 800;

interface PharmacyDutyDoc {
  merchantId: string;
  date: string;
  status: DutyStatus | string;
}

async function readTodayDutyMerchantIds(today: string): Promise<{
  merchantIds: Set<string>;
  reads: number;
}> {
  const merchantIds = new Set<string>();
  let reads = 0;
  let cursor: QueryDocumentSnapshot | null = null;
  let keepPaging = true;

  while (keepPaging) {
    let query = db()
      .collection("pharmacy_duties")
      .where("date", "==", today)
      .orderBy(FieldPath.documentId())
      .limit(DUTY_SCAN_PAGE_SIZE);

    if (cursor) {
      query = query.startAfter(cursor);
    }

    const pageSnap = await query.get();
    if (pageSnap.empty) {
      keepPaging = false;
      continue;
    }
    reads += pageSnap.size;

    for (const dutyDoc of pageSnap.docs) {
      const duty = dutyDoc.data() as PharmacyDutyDoc;
      const status = normalizeDutyStatus(duty.status);
      if (duty.merchantId && status !== "cancelled") {
        merchantIds.add(duty.merchantId);
      }
    }

    if (pageSnap.size < DUTY_SCAN_PAGE_SIZE) {
      keepPaging = false;
    } else {
      cursor = pageSnap.docs[pageSnap.docs.length - 1];
    }
  }

  return { merchantIds, reads };
}

/**
 * nightlyRefreshPharmacyDutyFlags
 *
 * Runs every day at 00:10 Argentina time (03:10 UTC).
 * Rebuilds hasPharmacyDutyToday for all visible pharmacy merchants.
 * Clears yesterday's flags and sets today's flags.
 */
export const nightlyRefreshPharmacyDutyFlags = onSchedule(
  {
    schedule: "10 3 * * *",
    timeZone: "America/Argentina/Buenos_Aires",
  },
  async () => {
    if (!shouldRunAutomaticFirestoreJob("nightlyRefreshPharmacyDutyFlags")) {
      return;
    }
    const today = todayDateString();
    console.log(`[nightlyRefreshPharmacyDutyFlags] Starting for date=${today}`);

    // Leer solo señales actualmente en true (más barato que barrer merchant_public completo).
    const currentSignalsSnap = await db()
      .collection("merchant_operational_signals")
      .where("hasPharmacyDutyToday", "==", true)
      .get();
    const currentFlagByMerchantId = new Map<string, boolean>();
    for (const doc of currentSignalsSnap.docs) {
      currentFlagByMerchantId.set(doc.id, true);
    }

    // Get today's duties (filtrado de estado se hace en memoria para evitar índices extra).
    const { merchantIds: todayMerchantIds, reads: dutyReads } = await readTodayDutyMerchantIds(today);

    const desiredFlagByMerchantId = new Map<string, boolean>();
    for (const merchantId of currentFlagByMerchantId.keys()) {
      if (!todayMerchantIds.has(merchantId)) {
        desiredFlagByMerchantId.set(merchantId, false);
      }
    }
    for (const merchantId of todayMerchantIds) {
      if (!currentFlagByMerchantId.has(merchantId)) {
        desiredFlagByMerchantId.set(merchantId, true);
      }
    }

    if (desiredFlagByMerchantId.size === 0) {
      console.log(
        `[nightlyRefreshPharmacyDutyFlags] Done. No changes needed. currentlyFlagged=${currentSignalsSnap.size} dutiesToday=${todayMerchantIds.size}.`
      );
      return;
    }

    const batches: WriteBatch[] = [];
    let currentBatch = db().batch();
    let batchOps = 0;

    // Write only changed flags
    for (const [merchantId, hasDutyToday] of desiredFlagByMerchantId.entries()) {
      const signalRef = db().doc(`merchant_operational_signals/${merchantId}`);

      currentBatch.set(
        signalRef,
        {
          hasPharmacyDutyToday: hasDutyToday,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps += 1;

      if (batchOps >= BATCH_SIZE - 1) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) batches.push(currentBatch);

    await Promise.all(batches.map((b) => b.commit()));

    console.log(
      `[nightlyRefreshPharmacyDutyFlags] Done. updated=${desiredFlagByMerchantId.size} currentlyFlagged=${currentSignalsSnap.size} dutiesToday=${todayMerchantIds.size}.`
    );
    console.log(
      JSON.stringify({
        job: "nightlyRefreshPharmacyDutyFlags",
        signalReads: currentSignalsSnap.size,
        dutyReads,
        signalWrites: desiredFlagByMerchantId.size,
      })
    );
  }
);
