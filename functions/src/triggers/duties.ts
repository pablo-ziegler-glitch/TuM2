import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();

interface PharmacyDutyDoc {
  dutyId: string;
  merchantId: string;
  date: string; // "YYYY-MM-DD"
  isActive?: boolean;
}

/**
 * onPharmacyDutyWriteSyncMerchant
 *
 * Triggered on any write to pharmacy_duties/{dutyId}.
 * If the duty applies to today (Argentina TZ), updates
 * merchant_public/{merchantId}.hasPharmacyDutyToday.
 */
export const onPharmacyDutyWriteSyncMerchant = onDocumentWritten(
  "pharmacy_duties/{dutyId}",
  async (event) => {
    const afterSnap = event.data?.after;
    const beforeSnap = event.data?.before;

    // Determine which doc to use (after for create/update, before for delete)
    const snap = afterSnap?.exists ? afterSnap : beforeSnap;
    if (!snap?.exists) return;

    const duty = snap.data() as PharmacyDutyDoc;
    const { merchantId, date } = duty;

    if (!merchantId || !date) return;

    const today = todayDateString();
    const isToday = date === today;
    const isActiveToday = isToday && (duty.isActive !== false) && afterSnap?.exists;

    await Promise.all([
      db()
        .doc(`merchant_public/${merchantId}`)
        .set(
          {
            hasPharmacyDutyToday: isActiveToday,
            syncedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
      db()
        .doc(`merchant_operational_signals/${merchantId}`)
        .set(
          {
            hasPharmacyDutyToday: isActiveToday,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
    ]);

    console.log(
      `[onPharmacyDutyWriteSyncMerchant] ${merchantId} hasPharmacyDutyToday=${isActiveToday}`
    );
  }
);
