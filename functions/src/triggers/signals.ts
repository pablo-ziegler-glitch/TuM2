import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import {
  normalizeOperationalPublicStateForDiff,
  resolveOperationalPublicState,
} from "../lib/operationalSignals";
import { OperationalSignals } from "../lib/types";
import { syncMerchantPublicProjection } from "../lib/publicProjectionSync";
import { logFinOpsEvent } from "../lib/finops";
import { apply24hClosePolicy } from "../lib/twentyFourHourPolicy";

function stableStringify(value: unknown): string {
  return JSON.stringify(value);
}

function toMillis(value: unknown): number | null {
  if (
    value &&
    typeof value === "object" &&
    "toMillis" in (value as Record<string, unknown>) &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

/**
 * onSignalsWriteSyncPublic
 *
 * Triggered on any write to merchant_operational_signals/{merchantId}.
 * Resuelve precedencia manual override > cálculo automático y sincroniza
 * merchant_public con no-op write avoidance.
 */
export const onSignalsWriteSyncPublic = onDocumentWritten(
  "merchant_operational_signals/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    const beforeSignals = beforeSnap?.exists
      ? (beforeSnap.data() as OperationalSignals)
      : undefined;
    const afterSignals = afterSnap?.exists
      ? (afterSnap.data() as OperationalSignals)
      : undefined;

    const resolvedBefore = resolveOperationalPublicState(beforeSignals);
    const resolvedAfter = resolveOperationalPublicState(afterSignals);
    const diffBefore = normalizeOperationalPublicStateForDiff(resolvedBefore);
    const diffAfter = normalizeOperationalPublicStateForDiff(resolvedAfter);
    const nowMs = Date.now();
    let effectiveAfterSignals = afterSignals;

    if (afterSignals) {
      const rawAfter = afterSignals as Record<string, unknown>;
      const strikeCount =
        typeof rawAfter["twentyFourHourStrikeCount"] === "number"
          ? (rawAfter["twentyFourHourStrikeCount"] as number)
          : 0;
      const policy = apply24hClosePolicy({
        previousIsOpenNow: resolvedBefore.isOpenNow,
        nextIsOpenNow: resolvedAfter.isOpenNow,
        nowMs,
        state: {
          is24hEnabled: rawAfter["is24h"] === true,
          strikeCount,
          cooldownUntilMs: toMillis(rawAfter["twentyFourHourCooldownUntil"]),
        },
      });

      if (policy.removedBecauseClosed) {
        const cooldownUntil = policy.next.cooldownUntilMs != null
          ? Timestamp.fromMillis(policy.next.cooldownUntilMs)
          : null;
        const patch: Record<string, unknown> = {
          is24h: false,
          twentyFourHourStrikeCount: policy.next.strikeCount,
          twentyFourHourCooldownUntil: cooldownUntil,
          twentyFourHourBadgeRemovedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        await getFirestore()
          .doc(`merchant_operational_signals/${merchantId}`)
          .set(patch, { merge: true });
        effectiveAfterSignals = {
          ...afterSignals,
          is24h: false,
          twentyFourHourStrikeCount: policy.next.strikeCount,
          twentyFourHourCooldownUntil: cooldownUntil,
        };
      }
    }

    const skipWrite = stableStringify(diffBefore) === stableStringify(diffAfter);
    if (skipWrite) {
      const logPayload = {
        trigger: "onSignalsWriteSyncPublic",
        merchantId,
        signalType: resolvedAfter.operationalSignalType,
        overrideMode: resolvedAfter.manualOverrideMode,
        forceClosed: resolvedAfter.manualOverrideMode === "force_closed",
        projectionWriteSkipped: true,
        reason: "no_diff",
      };
      console.log(
        JSON.stringify(logPayload)
      );
      logFinOpsEvent({
        event: "trigger_signals_projection",
        module: "triggers.signals",
        payload: {
          merchantId,
          signalType: resolvedAfter.operationalSignalType,
          overrideMode: resolvedAfter.manualOverrideMode,
          duplicateEvent: true,
          duplicateEventWriteRateSample: 1,
          publicWritePerformed: false,
          projectionWriteSkipped: true,
          reason: "no_diff",
        },
      });
      return;
    }

    const syncResult = await syncMerchantPublicProjection({
      merchantId,
      signals: effectiveAfterSignals,
    });

    const logPayload = {
      trigger: "onSignalsWriteSyncPublic",
      merchantId,
      signalType: syncResult.projectionSignalType,
      overrideMode: syncResult.projectionOverrideMode,
      forceClosed: syncResult.projectionOverrideMode === "force_closed",
      projectionWriteSkipped: syncResult.projectionWriteSkipped,
      reason: syncResult.reason,
    };
    console.log(
      JSON.stringify(logPayload)
    );
    logFinOpsEvent({
      event: "trigger_signals_projection",
      module: "triggers.signals",
      payload: {
        merchantId,
        signalType: syncResult.projectionSignalType,
        overrideMode: syncResult.projectionOverrideMode,
        duplicateEvent: false,
        duplicateEventWriteRateSample: 0,
        publicWritePerformed: syncResult.publicWritePerformed,
        projectionWriteSkipped: syncResult.projectionWriteSkipped,
        reason: syncResult.reason,
      },
    });
  }
);
