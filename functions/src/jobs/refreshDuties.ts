import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, FieldValue, WriteBatch } from "firebase-admin/firestore";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();
const BATCH_SIZE = 500;

interface PharmacyDutyDoc {
  merchantId: string;
  date: string;
  status: "draft" | "published" | "cancelled";
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
    const today = todayDateString();
    console.log(`[nightlyRefreshPharmacyDutyFlags] Starting for date=${today}`);

    // Get all visible pharmacies and reset their flags first
    const pharmaciesSnap = await db()
      .collection("merchant_public")
      .where("isPharmacy", "==", true)
      .where("visibilityStatus", "==", "visible")
      .get();

    const batches: WriteBatch[] = [];
    let currentBatch = db().batch();
    let batchOps = 0;

    // Reset all pharmacy duty flags
    for (const doc of pharmaciesSnap.docs) {
      currentBatch.set(
        doc.ref,
        {
          hasPharmacyDutyToday: false,
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps++;

      if (batchOps >= BATCH_SIZE) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        batchOps = 0;
      }
    }

    // Get today's published duties
    const dutiesSnap = await db()
      .collection("pharmacy_duties")
      .where("date", "==", today)
      .where("status", "==", "published")
      .get();

    const todayMerchantIds = new Set<string>();

    for (const dutyDoc of dutiesSnap.docs) {
      const duty = dutyDoc.data() as PharmacyDutyDoc;
      if (duty.merchantId) {
        todayMerchantIds.add(duty.merchantId);
      }
    }

    // Set duty flag for today's merchants
    for (const merchantId of todayMerchantIds) {
      const publicRef = db().doc(`merchant_public/${merchantId}`);
      const signalRef = db().doc(`merchant_operational_signals/${merchantId}`);

      currentBatch.set(
        publicRef,
        {
          hasPharmacyDutyToday: true,
          syncedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      currentBatch.set(
        signalRef,
        {
          hasPharmacyDutyToday: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps += 2;

      if (batchOps >= BATCH_SIZE - 1) {
        batches.push(currentBatch);
        currentBatch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) batches.push(currentBatch);

    await Promise.all(batches.map((b) => b.commit()));

    console.log(
      `[nightlyRefreshPharmacyDutyFlags] Done. Reset ${pharmaciesSnap.size} pharmacies, set ${todayMerchantIds.size} on-duty.`
    );
  }
);
