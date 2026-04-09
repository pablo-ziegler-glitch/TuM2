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
 * merchant_operational_signals/{merchantId}.hasPharmacyDutyToday.
 * merchant_public se sincroniza desde onSignalsWriteSyncPublic.
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

    const beforeDuty = beforeSnap?.exists
      ? (beforeSnap.data() as PharmacyDutyDoc)
      : undefined;
    const afterDuty = afterSnap?.exists
      ? (afterSnap.data() as PharmacyDutyDoc)
      : undefined;
    const isSameEffectiveState =
      beforeDuty &&
      afterDuty &&
      beforeDuty.merchantId === afterDuty.merchantId &&
      beforeDuty.date === afterDuty.date &&
      beforeDuty.status === afterDuty.status;
    if (isSameEffectiveState) return;

    const today = todayDateString();
    const touchesToday = beforeDate === today || afterDate === today;
    if (!touchesToday) return;

    const affectedMerchantIds = new Set<string>();
    if (beforeDuty?.merchantId?.trim()) affectedMerchantIds.add(beforeDuty.merchantId.trim());
    if (afterDuty?.merchantId?.trim()) affectedMerchantIds.add(afterDuty.merchantId.trim());
    if (affectedMerchantIds.size === 0) return;

    await Promise.all(
      [...affectedMerchantIds].map(async (affectedMerchantId) => {
        const signalRef = db().doc(`merchant_operational_signals/${affectedMerchantId}`);
        const [publishedTodaySnap, signalSnap] = await Promise.all([
          db()
            .collection("pharmacy_duties")
            .where("merchantId", "==", affectedMerchantId)
            .where("date", "==", today)
            .where("status", "==", "published")
            .limit(1)
            .get(),
          signalRef.get(),
        ]);
        const hasDutyToday = !publishedTodaySnap.empty;
        const currentHasDutyToday = signalSnap.exists
          && signalSnap.data()?.["hasPharmacyDutyToday"] === true;
        if (currentHasDutyToday === hasDutyToday) {
          return;
        }

        await signalRef.set(
          {
            hasPharmacyDutyToday: hasDutyToday,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        console.log(
          `[onPharmacyDutyWriteSyncMerchant] ${affectedMerchantId} hasPharmacyDutyToday=${hasDutyToday}`
        );
      })
    );
  }
);
