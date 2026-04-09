import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { todayDateString } from "../lib/schedules";

const db = () => getFirestore();

interface PharmacyDutyDoc {
  merchantId: string;
  date: string; // "YYYY-MM-DD"
  status: "draft" | "published" | "cancelled";
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
    const { merchantId } = duty;
    const beforeDate = beforeSnap?.exists
      ? ((beforeSnap.data() as PharmacyDutyDoc).date ?? "")
      : "";
    const afterDate = afterSnap?.exists
      ? ((afterSnap.data() as PharmacyDutyDoc).date ?? "")
      : "";

    if (!merchantId) return;

    const today = todayDateString();
    const touchesToday = beforeDate === today || afterDate === today;
    if (!touchesToday) return;

    const publishedTodaySnap = await db()
      .collection("pharmacy_duties")
      .where("merchantId", "==", merchantId)
      .where("date", "==", today)
      .where("status", "==", "published")
      .limit(1)
      .get();
    const hasDutyToday = !publishedTodaySnap.empty;

    await Promise.all([
      db()
        .doc(`merchant_public/${merchantId}`)
        .set(
          {
            hasPharmacyDutyToday: hasDutyToday,
            syncedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
      db()
        .doc(`merchant_operational_signals/${merchantId}`)
        .set(
          {
            hasPharmacyDutyToday: hasDutyToday,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
    ]);

    console.log(
      `[onPharmacyDutyWriteSyncMerchant] ${merchantId} hasPharmacyDutyToday=${hasDutyToday}`
    );
  }
);
