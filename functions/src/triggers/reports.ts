import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ReportDoc } from "../lib/types";
import { logFinOpsEvent } from "../lib/finops";

const db = () => getFirestore();

const DEFAULT_SUPPRESSION_THRESHOLD = 3;
const CONFIG_DOC = "admin_configs/moderation";
const CONFIG_CACHE_TTL_MS = 5 * 60 * 1000;
let cachedThreshold: number | null = null;
let cachedThresholdExpiresAtMs = 0;

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
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) return;

    const report = afterSnap.data() as ReportDoc;
    if (report.targetType !== "merchant") return;

    const targetId = report.targetId;
    if (!targetId) return;

    // Count open reports with aggregate query to avoid reading all report docs.
    const openReportsAgg = await db()
      .collection("reports")
      .where("targetId", "==", targetId)
      .where("targetType", "==", "merchant")
      .where("status", "==", "open")
      .count()
      .get();

    const openCount = Number(openReportsAgg.data().count ?? 0);
    const threshold = await getSuppressionThreshold();
    logFinOpsEvent({
      event: "trigger_reports_threshold_eval",
      module: "triggers.reports",
      payload: {
        merchantId: targetId,
        openCount,
        threshold,
      },
    });

    if (openCount >= threshold) {
      const merchantRef = db().doc(`merchants/${targetId}`);
      const merchantSnap = await merchantRef.get();
      if (merchantSnap.exists && merchantSnap.data()?.["visibilityStatus"] === "suppressed") {
        logFinOpsEvent({
          event: "trigger_reports_suppress_skipped",
          module: "triggers.reports",
          payload: {
            merchantId: targetId,
            reason: "already_suppressed",
            openCount,
            threshold,
          },
        });
        return;
      }

      await merchantRef.set(
          {
            visibilityStatus: "suppressed",
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      console.log(
        `[onReportThresholdSuppressMerchant] Suppressed merchant ${targetId} (${openCount} open reports >= threshold ${threshold})`
      );
      logFinOpsEvent({
        event: "trigger_reports_suppressed",
        level: "warning",
        module: "triggers.reports",
        payload: {
          merchantId: targetId,
          openCount,
          threshold,
        },
      });
    }
  }
);
