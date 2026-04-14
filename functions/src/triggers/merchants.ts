import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "../lib/projection";
import { MerchantDoc, OperationalSignals } from "../lib/types";
import { syncMerchantPublicProjection } from "../lib/publicProjectionSync";

const db = () => getFirestore();

const RELEVANT_PROJECTION_FIELDS: Array<keyof MerchantDoc> = [
  "merchantId",
  "name",
  "category",
  "zone",
  "zoneId",
  "address",
  "isPharmacy",
  "verificationStatus",
  "visibilityStatus",
  "completenessScore",
  "lastActivityAt",
];

function toComparableValue(value: unknown): unknown {
  if (
    value &&
    typeof value === "object" &&
    "toMillis" in (value as Record<string, unknown>) &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  return value;
}

function hasProjectionRelevantChanges(before: MerchantDoc, after: MerchantDoc): boolean {
  return RELEVANT_PROJECTION_FIELDS.some((field) => {
    const beforeValue = toComparableValue(before[field]);
    const afterValue = toComparableValue(after[field]);
    return JSON.stringify(beforeValue) !== JSON.stringify(afterValue);
  });
}

function projectionSignature(value: unknown): string {
  return JSON.stringify(
    value,
    (_key, currentValue) => toComparableValue(currentValue)
  );
}

/**
 * onMerchantWriteSyncPublic
 *
 * Triggered on any write to merchants/{merchantId}.
 * Creates or updates merchant_public/{merchantId} with a computed projection.
 * Suppressed merchants are hidden from public view.
 */
export const onMerchantWriteSyncPublic = onDocumentWritten(
  "merchants/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    // Document was deleted
    if (!afterSnap?.exists) {
      await db()
        .doc(`merchant_public/${merchantId}`)
        .delete();
      return;
    }

    const merchant = afterSnap.data() as MerchantDoc;
    let beforeMerchant: MerchantDoc | undefined;
    if (beforeSnap?.exists) {
      beforeMerchant = beforeSnap.data() as MerchantDoc;
      if (!hasProjectionRelevantChanges(beforeMerchant, merchant)) {
        return;
      }
    }

    // Fetch current signals (best-effort)
    const [signalsSnap] = await Promise.all([
      db().doc(`merchant_operational_signals/${merchantId}`).get(),
    ]);

    const signals = signalsSnap.exists
      ? (signalsSnap.data() as OperationalSignals)
      : undefined;

    const projection = computeMerchantPublicProjection(merchant, signals);
    if (beforeMerchant) {
      const beforeProjection = computeMerchantPublicProjection(beforeMerchant, signals);
      if (projectionSignature(beforeProjection) === projectionSignature(projection)) {
        return;
      }
    }

    await syncMerchantPublicProjection({
      merchantId,
      merchant,
      signals,
    });

    console.log(`[onMerchantWriteSyncPublic] Synced ${merchantId}`);
  }
);
