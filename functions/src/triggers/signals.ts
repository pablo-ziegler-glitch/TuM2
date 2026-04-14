import { onDocumentWritten } from "firebase-functions/v2/firestore";
import {
  normalizeOperationalPublicStateForDiff,
  resolveOperationalPublicState,
} from "../lib/operationalSignals";
import { OperationalSignals } from "../lib/types";
import { syncMerchantPublicProjection } from "../lib/publicProjectionSync";
import { logFinOpsEvent } from "../lib/finops";

function stableStringify(value: unknown): string {
  return JSON.stringify(value);
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
      signals: afterSignals,
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
