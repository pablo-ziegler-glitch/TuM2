import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { OperationalSignals } from "../lib/types";

const db = () => getFirestore();

type SignalDocRaw = Record<string, unknown>;

function toBool(value: unknown): boolean | undefined {
  if (typeof value === "boolean") return value;
  return undefined;
}

function toStringOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asMap(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object") return {};
  return value as Record<string, unknown>;
}

function readOwnerSignals(raw: SignalDocRaw): {
  temporaryClosed?: boolean;
  temporaryClosedNote?: string;
  hasDelivery?: boolean;
  acceptsWhatsappOrders?: boolean;
  openNowManualOverride?: boolean;
} {
  const nested = asMap(raw.signals);
  const source = Object.keys(nested).length > 0 ? nested : raw;
  return {
    temporaryClosed: toBool(source.temporaryClosed),
    temporaryClosedNote: toStringOrNull(source.temporaryClosedNote) ?? undefined,
    hasDelivery: toBool(source.hasDelivery),
    acceptsWhatsappOrders: toBool(source.acceptsWhatsappOrders),
    openNowManualOverride: toBool(source.openNowManualOverride),
  };
}

function readDerivedSignals(raw: SignalDocRaw): {
  isOpenNow?: boolean;
  todayScheduleLabel?: string;
  hasPharmacyDutyToday?: boolean;
  hasScheduleConfigured?: boolean;
  closesAt?: string | null;
  opensNextAt?: string | null;
} {
  return {
    isOpenNow: toBool(raw.isOpenNow),
    todayScheduleLabel: toStringOrNull(raw.todayScheduleLabel) ?? undefined,
    hasPharmacyDutyToday: toBool(raw.hasPharmacyDutyToday),
    hasScheduleConfigured: toBool(raw.hasScheduleConfigured),
    closesAt: toStringOrNull(raw.closesAt),
    opensNextAt: toStringOrNull(raw.opensNextAt),
  };
}

/**
 * Merges operational signals with the following priority:
 *   temporaryClosed > manual overrides > schedule-derived values
 */
function mergeSignals(signals: OperationalSignals): Partial<OperationalSignals> {
  const raw = signals as SignalDocRaw;
  const owner = readOwnerSignals(raw);
  const derived = readDerivedSignals(raw);
  const merged: Partial<OperationalSignals> = {
    ...owner,
    ...derived,
  };

  if (owner.temporaryClosed === true) {
    // Override everything: merchant is temporarily closed
    merged.isOpenNow = false;
    merged.todayScheduleLabel = owner.temporaryClosedNote
      ? `Cerrado temporalmente: ${owner.temporaryClosedNote}`
      : "Cerrado temporalmente";
  } else if (owner.openNowManualOverride === true) {
    merged.isOpenNow = true;
  }

  return merged;
}

function normalizeForComparison(
  value: Partial<OperationalSignals> | undefined
): Record<string, unknown> {
  if (!value) return {};
  const unsafe = value as Record<string, unknown>;
  return {
    isOpenNow: value.isOpenNow === true,
    todayScheduleLabel: value.todayScheduleLabel ?? "",
    temporaryClosed: value.temporaryClosed === true,
    temporaryClosedNote: value.temporaryClosedNote ?? null,
    hasDelivery: value.hasDelivery === true,
    acceptsWhatsappOrders: value.acceptsWhatsappOrders === true,
    openNowManualOverride: value.openNowManualOverride === true,
    hasPharmacyDutyToday: value.hasPharmacyDutyToday === true,
    hasScheduleConfigured:
      typeof unsafe.hasScheduleConfigured === "boolean"
        ? unsafe.hasScheduleConfigured
        : null,
    closesAt: unsafe.closesAt ?? null,
    opensNextAt: unsafe.opensNextAt ?? null,
  };
}

/**
 * onSignalsWriteSyncPublic
 *
 * Triggered on any write to merchant_operational_signals/{merchantId}.
 * Merges signals (respecting priority) and propagates to merchant_public.
 */
export const onSignalsWriteSyncPublic = onDocumentWritten(
  "merchant_operational_signals/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    if (!afterSnap?.exists) return;

    const signals = afterSnap.data() as OperationalSignals;
    const mergedAfter = mergeSignals(signals);
    const mergedBefore = beforeSnap?.exists
      ? mergeSignals(beforeSnap.data() as OperationalSignals)
      : undefined;
    if (
      JSON.stringify(normalizeForComparison(mergedBefore)) ===
      JSON.stringify(normalizeForComparison(mergedAfter))
    ) {
      return;
    }

    const mergedUnsafe = mergedAfter as Record<string, unknown>;
    const publicPayload: Record<string, unknown> = {
      operationalSignals: mergedAfter,
      isOpenNow: mergedAfter.isOpenNow ?? false,
      todayScheduleLabel: mergedAfter.todayScheduleLabel ?? "",
      hasPharmacyDutyToday: mergedAfter.hasPharmacyDutyToday ?? false,
      syncedAt: FieldValue.serverTimestamp(),
    };
    if ("hasScheduleConfigured" in mergedUnsafe) {
      publicPayload.hasScheduleConfigured = mergedUnsafe.hasScheduleConfigured;
    }
    if ("closesAt" in mergedUnsafe) {
      publicPayload.closesAt = mergedUnsafe.closesAt ?? null;
    }
    if ("opensNextAt" in mergedUnsafe) {
      publicPayload.opensNextAt = mergedUnsafe.opensNextAt ?? null;
    }

    await db()
      .doc(`merchant_public/${merchantId}`)
      .set(publicPayload, { merge: true });

    console.log(`[onSignalsWriteSyncPublic] Synced signals for ${merchantId}`);
  }
);
