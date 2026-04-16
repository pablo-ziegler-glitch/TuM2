import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "./projection";
import { MerchantDoc, OperationalSignals } from "./types";

const db = () => getFirestore();

const VOLATILE_PUBLIC_FIELDS = new Set([
  "syncedAt",
  "updatedAt",
  "createdAt",
  "lastDataRefreshAt",
  "operationalSignalUpdatedAt",
  "metadata",
  "syncMetadata",
]);

type ComparablePublicState = Record<string, unknown>;

export interface SyncMerchantPublicProjectionInput {
  merchantId: string;
  merchant?: MerchantDoc;
  // `undefined` => no se resolvió aún; `null` => resuelto y ausente.
  signals?: OperationalSignals | null;
}

export interface SyncMerchantPublicProjectionResult {
  publicWritePerformed: boolean;
  projectionWriteSkipped: boolean;
  reason:
    | "projection_updated"
    | "merchant_missing"
    | "merchant_suppressed"
    | "no_changes";
  projectionSignalType: "none" | "vacation" | "temporary_closure" | "delay";
  projectionOverrideMode: "none" | "force_closed" | "informational";
}

interface SyncMerchantPublicProjectionDeps {
  firestore?: FirebaseFirestore.Firestore;
  computeProjection?: typeof computeMerchantPublicProjection;
  serverTimestamp?: () => unknown;
  logger?: Pick<Console, "log">;
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

function normalizeComparableValue(value: unknown): unknown {
  if (
    value &&
    typeof value === "object" &&
    "toMillis" in (value as Record<string, unknown>) &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  if (Array.isArray(value)) {
    return value.map((item) => normalizeComparableValue(item));
  }

  if (value && typeof value === "object") {
    const input = value as Record<string, unknown>;
    const normalizedEntries = Object.entries(input)
      .filter(([key]) => !VOLATILE_PUBLIC_FIELDS.has(key))
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, nested]) => [key, normalizeComparableValue(nested)]);

    return Object.fromEntries(normalizedEntries);
  }

  return value ?? null;
}

function buildComparablePublicState(source: unknown): ComparablePublicState {
  if (!source || typeof source !== "object") return {};
  return normalizeComparableValue(source) as ComparablePublicState;
}

export function areComparablePublicStatesEqual(
  current: unknown,
  next: unknown
): boolean {
  const currentComparable = buildComparablePublicState(current);
  const nextComparable = buildComparablePublicState(next);
  return JSON.stringify(currentComparable) === JSON.stringify(nextComparable);
}

function diffComparableTopLevelFields(current: unknown, next: unknown): string[] {
  const currentComparable = buildComparablePublicState(current);
  const nextComparable = buildComparablePublicState(next);
  const keys = new Set([
    ...Object.keys(currentComparable),
    ...Object.keys(nextComparable),
  ]);
  const changed: string[] = [];
  for (const key of keys) {
    if (JSON.stringify(currentComparable[key]) !== JSON.stringify(nextComparable[key])) {
      changed.push(key);
    }
  }
  return changed.sort();
}

export async function syncMerchantPublicProjection(
  input: SyncMerchantPublicProjectionInput,
  deps: SyncMerchantPublicProjectionDeps = {}
): Promise<SyncMerchantPublicProjectionResult> {
  const merchantId = input.merchantId;
  const firestore = deps.firestore ?? db();
  const computeProjection = deps.computeProjection ?? computeMerchantPublicProjection;
  const logger = deps.logger ?? console;
  let merchant = input.merchant;

  if (!merchant) {
    const merchantSnap = await firestore.doc(`merchants/${merchantId}`).get();
    if (!merchantSnap.exists) {
      await firestore.doc(`merchant_public/${merchantId}`).delete().catch(() => undefined);
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

  const publicDocRef = firestore.doc(`merchant_public/${merchantId}`);
  const currentPublicSnap = await publicDocRef.get();
  const isInitialCreate = !currentPublicSnap.exists;
  const currentPublic = currentPublicSnap.exists ? currentPublicSnap.data() : null;

  if (merchant.visibilityStatus === "suppressed") {
    const nextSuppressedProjection = {
      visibilityStatus: "suppressed",
      merchantId,
    };
    if (areComparablePublicStatesEqual(currentPublic, nextSuppressedProjection)) {
      logger.log(
        `[Sync] No-op: No hay cambios detectados para el comercio ${merchantId}`,
        JSON.stringify({
          merchantId,
          reason: "merchant_suppressed",
          sourceTrigger: "syncMerchantPublicProjection",
          writePerformed: false,
          isInitialCreate,
        })
      );
      return {
        publicWritePerformed: false,
        projectionWriteSkipped: true,
        reason: "no_changes",
        projectionSignalType: "none",
        projectionOverrideMode: "none",
      };
    }

    await publicDocRef.set(nextSuppressedProjection, { merge: false });
    logger.log(
      `[Sync] merchant_public actualizado para ${merchantId}`,
      JSON.stringify({
        merchantId,
        reason: "merchant_suppressed",
        sourceTrigger: "syncMerchantPublicProjection",
        writePerformed: true,
        isInitialCreate,
      })
    );
    return {
      publicWritePerformed: true,
      projectionWriteSkipped: false,
      reason: "merchant_suppressed",
      projectionSignalType: "none",
      projectionOverrideMode: "none",
    };
  }

  let signals = input.signals;
  if (signals === undefined) {
    const signalsSnap = await firestore.doc(`merchant_operational_signals/${merchantId}`).get();
    signals = signalsSnap.exists ? (signalsSnap.data() as OperationalSignals) : null;
  }

  const projection = computeProjection(merchant, signals ?? undefined);
  const publicComparableChanged = !areComparablePublicStatesEqual(currentPublic, projection);
  if (!publicComparableChanged) {
    logger.log(
      `[Sync] No-op: No hay cambios detectados para el comercio ${merchantId}`,
      JSON.stringify({
        merchantId,
        reason: "projection_updated",
        sourceTrigger: "syncMerchantPublicProjection",
        writePerformed: false,
        isInitialCreate,
      })
    );
    return {
      publicWritePerformed: false,
      projectionWriteSkipped: true,
      reason: "no_changes",
      projectionSignalType: normalizeSignalType(projection.operationalSignalType),
      projectionOverrideMode: normalizeOverrideMode(projection.manualOverrideMode),
    };
  }

  await publicDocRef.set(
    {
      ...projection,
      syncedAt: deps.serverTimestamp ? deps.serverTimestamp() : FieldValue.serverTimestamp(),
    },
    { merge: false }
  );
  logger.log(
    `[Sync] merchant_public actualizado para ${merchantId}`,
    JSON.stringify({
      merchantId,
      reason: "projection_updated",
      sourceTrigger: "syncMerchantPublicProjection",
      writePerformed: true,
      isInitialCreate,
      changedFields: diffComparableTopLevelFields(currentPublic, projection),
    })
  );

  return {
    publicWritePerformed: true,
    projectionWriteSkipped: false,
    reason: "projection_updated",
    projectionSignalType: normalizeSignalType(projection.operationalSignalType),
    projectionOverrideMode: normalizeOverrideMode(projection.manualOverrideMode),
  };
}
