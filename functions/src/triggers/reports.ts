import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ReportDoc } from "../lib/types";
import { logFinOpsEvent } from "../lib/finops";

const db = () => getFirestore();

const DEFAULT_SUPPRESSION_THRESHOLD = 3;
const CONFIG_DOC = "admin_configs/moderation";
const COUNTERS_COLLECTION = "report_counters";
const CONFIG_CACHE_TTL_MS = 5 * 60 * 1000;
let cachedThreshold: number | null = null;
let cachedThresholdExpiresAtMs = 0;

interface ReportCounterDoc {
  openCount?: number;
  suppressionTriggered?: boolean;
}

async function getSuppressionThreshold(): Promise<number> {
  const nowMs = Date.now();
  if (cachedThreshold != null && nowMs < cachedThresholdExpiresAtMs) {
    return cachedThreshold;
  }

  const configSnap = await db().doc(CONFIG_DOC).get();
  if (!configSnap.exists) {
    cachedThreshold = DEFAULT_SUPPRESSION_THRESHOLD;
    cachedThresholdExpiresAtMs = nowMs + CONFIG_CACHE_TTL_MS;
    return DEFAULT_SUPPRESSION_THRESHOLD;
  }

  const data = configSnap.data();
  const resolved = typeof data?.suppressionThreshold === "number"
    ? data.suppressionThreshold
    : DEFAULT_SUPPRESSION_THRESHOLD;
  cachedThreshold = resolved;
  cachedThresholdExpiresAtMs = nowMs + CONFIG_CACHE_TTL_MS;
  return resolved;
}

function merchantIdFromReport(report: ReportDoc | undefined): string | null {
  if (!report || report.targetType !== "merchant") return null;
  const targetId = report.targetId?.trim();
  return targetId && targetId.length > 0 ? targetId : null;
}

function isOpenReport(report: ReportDoc | undefined): boolean {
  return report?.status === "open";
}

/**
 * onReportThresholdSuppressMerchant
 *
 * Triggered on create/update of reports/{reportId}.
 * Counts open reports for the target merchant.
 * If count >= threshold, sets merchant visibilityStatus to "suppressed".
 */
export const onReportThresholdSuppressMerchant = onDocumentWritten(
  "reports/{reportId}",
  async (event) => {
    const threshold = await getSuppressionThreshold();
    const beforeReport = event.data?.before.exists
      ? (event.data.before.data() as ReportDoc)
      : undefined;
    const afterReport = event.data?.after.exists
      ? (event.data.after.data() as ReportDoc)
      : undefined;
    const beforeMerchantId = merchantIdFromReport(beforeReport);
    const afterMerchantId = merchantIdFromReport(afterReport);

    const affectedMerchantIds = new Set<string>();
    if (beforeMerchantId) affectedMerchantIds.add(beforeMerchantId);
    if (afterMerchantId) affectedMerchantIds.add(afterMerchantId);
    if (affectedMerchantIds.size === 0) return;

    const operations = [...affectedMerchantIds].map(async (merchantId) => {
      const beforeWasOpen = beforeMerchantId === merchantId && isOpenReport(beforeReport);
      const afterIsOpen = afterMerchantId === merchantId && isOpenReport(afterReport);
      const delta = (afterIsOpen ? 1 : 0) - (beforeWasOpen ? 1 : 0);
      if (delta === 0) return;

      const counterRef = db().collection(COUNTERS_COLLECTION).doc(merchantId);
      const merchantRef = db().doc(`merchants/${merchantId}`);

      let nextOpenCount = 0;
      let crossedThreshold = false;
      await db().runTransaction(async (tx) => {
        const counterSnap = await tx.get(counterRef);
        const currentCounter = (counterSnap.data() ?? {}) as ReportCounterDoc;
        const previousOpenCount = Math.max(
          0,
          Number(currentCounter.openCount ?? 0)
        );
        nextOpenCount = Math.max(0, previousOpenCount + delta);
        const suppressionTriggered = currentCounter.suppressionTriggered === true;
        crossedThreshold =
          !suppressionTriggered &&
          previousOpenCount < threshold &&
          nextOpenCount >= threshold;

        tx.set(
          counterRef,
          {
            merchantId,
            openCount: nextOpenCount,
            suppressionTriggered: suppressionTriggered || crossedThreshold,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        if (crossedThreshold) {
          tx.set(
            merchantRef,
            {
              visibilityStatus: "suppressed",
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      });

      logFinOpsEvent({
        event: "trigger_reports_threshold_eval",
        module: "triggers.reports",
        payload: {
          merchantId,
          openCount: nextOpenCount,
          threshold,
          delta,
        },
      });

      if (!crossedThreshold) {
        logFinOpsEvent({
          event: "trigger_reports_suppress_skipped",
          module: "triggers.reports",
          payload: {
            merchantId,
            reason: "threshold_not_crossed",
            openCount: nextOpenCount,
            threshold,
          },
        });
        return;
      }

      console.log(
        `[onReportThresholdSuppressMerchant] Suppressed merchant ${merchantId} (${nextOpenCount} open reports >= threshold ${threshold})`
      );
      logFinOpsEvent({
        event: "trigger_reports_suppressed",
        level: "warning",
        module: "triggers.reports",
        payload: {
          merchantId,
          openCount: nextOpenCount,
          threshold,
        },
      });
    });

    await Promise.all(operations);
  }
);
