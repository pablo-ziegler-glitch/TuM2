import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { todayDateString } from "../lib/schedules";
import {
  DutyConfidenceLevel,
  DutyPublicStatusLabel,
  DutyStatus,
  normalizeDutyStatus,
} from "../lib/pharmacyDutyMitigation";

const db = () => getFirestore();
const MAX_DUTY_DOCS_PER_EVENT = 10;
const NON_CANCELLED_DUTY_STATUSES = [
  "draft",
  "published",
  "scheduled",
  "active",
  "incident_reported",
  "replacement_pending",
  "reassigned",
] as const;

interface PharmacyDutyDoc {
  merchantId: string;
  date: string; // "YYYY-MM-DD"
  status: DutyStatus | string;
  confirmationStatus?: string;
  incidentOpen?: boolean;
  confidenceLevel?: DutyConfidenceLevel;
  publicStatusLabel?: DutyPublicStatusLabel;
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
    const beforeStatus = beforeDuty?.status
      ? normalizeDutyStatus(beforeDuty.status)
      : undefined;
    const afterStatus = afterDuty?.status
      ? normalizeDutyStatus(afterDuty.status)
      : undefined;
    const isSameEffectiveState =
      beforeDuty &&
      afterDuty &&
      beforeDuty.merchantId === afterDuty.merchantId &&
      beforeDuty.date === afterDuty.date &&
      beforeStatus === afterStatus &&
      beforeDuty.confirmationStatus === afterDuty.confirmationStatus &&
      beforeDuty.incidentOpen === afterDuty.incidentOpen &&
      beforeDuty.confidenceLevel === afterDuty.confidenceLevel &&
      beforeDuty.publicStatusLabel === afterDuty.publicStatusLabel;
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
        const publicRef = db().doc(`merchant_public/${affectedMerchantId}`);
        const [todayDutiesSnap, signalSnap] = await Promise.all([
          db()
            .collection("pharmacy_duties")
            .where("merchantId", "==", affectedMerchantId)
            .where("date", "==", today)
            // Acotamos lecturas por evento: solo estados no cancelados y límite duro.
            .where("status", "in", [...NON_CANCELLED_DUTY_STATUSES])
            .limit(MAX_DUTY_DOCS_PER_EVENT)
            .get(),
          signalRef.get(),
        ]);
        const relevantTodayDuties = todayDutiesSnap.docs
          .map((doc) => doc.data() as PharmacyDutyDoc);
        const hasDutyToday = relevantTodayDuties.length > 0;
        const bestDuty = relevantTodayDuties
          .slice()
          .sort((a, b) => {
            const priority = (duty: PharmacyDutyDoc): number => {
              if (duty.incidentOpen === true) return 0;
              const status = normalizeDutyStatus(duty.status);
              if (status === "replacement_pending" || status === "incident_reported") return 1;
              if (status === "reassigned" || status === "active") return 3;
              if (duty.confirmationStatus === "confirmed" || duty.confirmationStatus === "replaced") return 4;
              return 2;
            };
            return priority(b) - priority(a);
          })[0];

        const currentHasDutyToday = signalSnap.exists
          && signalSnap.data()?.["hasPharmacyDutyToday"] === true;
        const signalNeedsUpdate = currentHasDutyToday !== hasDutyToday;

        const nextConfidence = bestDuty?.confidenceLevel ?? null;
        const nextPublicStatus = bestDuty?.publicStatusLabel ?? null;
        const publicSnap = await publicRef.get();
        const currentConfidence = publicSnap.data()?.["confidenceLevel"] ?? null;
        const currentPublicStatus = publicSnap.data()?.["publicStatusLabel"] ?? null;
        const currentPublicDutyToday = publicSnap.data()?.["isOnDutyToday"] === true;
        const publicNeedsUpdate =
          currentPublicDutyToday !== hasDutyToday ||
          currentConfidence !== nextConfidence ||
          currentPublicStatus !== nextPublicStatus;

        if (!signalNeedsUpdate && !publicNeedsUpdate) return;

        const writes: Array<Promise<unknown>> = [];
        if (signalNeedsUpdate) {
          writes.push(
            signalRef.set(
              {
                hasPharmacyDutyToday: hasDutyToday,
                updatedAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            )
          );
        }
        if (publicNeedsUpdate) {
          writes.push(
            publicRef.set(
              {
                hasPharmacyDutyToday: hasDutyToday,
                isOnDutyToday: hasDutyToday,
                confidenceLevel: nextConfidence,
                publicStatusLabel: nextPublicStatus,
                lastDataRefreshAt: FieldValue.serverTimestamp(),
              },
              { merge: true }
            )
          );
        }
        await Promise.all(writes);

        console.log(
          `[onPharmacyDutyWriteSyncMerchant] ${affectedMerchantId} hasPharmacyDutyToday=${hasDutyToday}`
        );
      })
    );
  }
);
