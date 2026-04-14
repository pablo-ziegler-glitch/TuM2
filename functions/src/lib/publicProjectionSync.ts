import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "./projection";
import { MerchantDoc, OperationalSignals } from "./types";

const db = () => getFirestore();

export interface SyncMerchantPublicProjectionInput {
  merchantId: string;
  merchant?: MerchantDoc;
  signals?: OperationalSignals;
}

export interface SyncMerchantPublicProjectionResult {
  publicWritePerformed: boolean;
  projectionWriteSkipped: boolean;
  reason: "projection_updated" | "merchant_missing" | "merchant_suppressed";
  projectionSignalType: "none" | "vacation" | "temporary_closure" | "delay";
  projectionOverrideMode: "none" | "force_closed" | "informational";
}

function normalizeSignalType(value: unknown): SyncMerchantPublicProjectionResult["projectionSignalType"] {
  if (
    value === "vacation" ||
    value === "temporary_closure" ||
    value === "delay" ||
    value === "none"
  ) {
    return value;
  }
  return "none";
}

function normalizeOverrideMode(
  value: unknown
): SyncMerchantPublicProjectionResult["projectionOverrideMode"] {
  if (value === "force_closed" || value === "informational" || value === "none") {
    return value;
  }
  return "none";
}

export async function syncMerchantPublicProjection(
  input: SyncMerchantPublicProjectionInput
): Promise<SyncMerchantPublicProjectionResult> {
  const merchantId = input.merchantId;
  let merchant = input.merchant;

  if (!merchant) {
    const merchantSnap = await db().doc(`merchants/${merchantId}`).get();
    if (!merchantSnap.exists) {
      await db().doc(`merchant_public/${merchantId}`).delete().catch(() => undefined);
      return {
        publicWritePerformed: false,
        projectionWriteSkipped: true,
        reason: "merchant_missing",
        projectionSignalType: "none",
        projectionOverrideMode: "none",
      };
    }
    merchant = merchantSnap.data() as MerchantDoc;
  }

  if (merchant.visibilityStatus === "suppressed") {
    await db()
      .doc(`merchant_public/${merchantId}`)
      .set({ visibilityStatus: "suppressed", merchantId }, { merge: true });
    return {
      publicWritePerformed: true,
      projectionWriteSkipped: false,
      reason: "merchant_suppressed",
      projectionSignalType: "none",
      projectionOverrideMode: "none",
    };
  }

  let signals = input.signals;
  if (!signals) {
    const signalsSnap = await db().doc(`merchant_operational_signals/${merchantId}`).get();
    signals = signalsSnap.exists ? (signalsSnap.data() as OperationalSignals) : undefined;
  }

  const projection = computeMerchantPublicProjection(merchant, signals);
  await db()
    .doc(`merchant_public/${merchantId}`)
    .set(
      {
        ...projection,
        syncedAt: FieldValue.serverTimestamp(),
      },
      { merge: false }
    );

  return {
    publicWritePerformed: true,
    projectionWriteSkipped: false,
    reason: "projection_updated",
    projectionSignalType: normalizeSignalType(projection.operationalSignalType),
    projectionOverrideMode: normalizeOverrideMode(projection.manualOverrideMode),
  };
}
