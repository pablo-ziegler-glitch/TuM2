import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ReportDoc } from "../lib/types";

const db = () => getFirestore();

const DEFAULT_SUPPRESSION_THRESHOLD = 3;
const CONFIG_DOC = "config/moderation";

async function getSuppressionThreshold(): Promise<number> {
  const configSnap = await db().doc(CONFIG_DOC).get();
  if (!configSnap.exists) return DEFAULT_SUPPRESSION_THRESHOLD;
  const data = configSnap.data();
  return typeof data?.suppressionThreshold === "number"
    ? data.suppressionThreshold
    : DEFAULT_SUPPRESSION_THRESHOLD;
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

    // Count open reports for this merchant
    const openReportsSnap = await db()
      .collection("reports")
      .where("targetId", "==", targetId)
      .where("targetType", "==", "merchant")
      .where("status", "==", "open")
      .get();

    const openCount = openReportsSnap.size;
    const threshold = await getSuppressionThreshold();

    if (openCount >= threshold) {
      await db()
        .doc(`merchants/${targetId}`)
        .set(
          {
            visibilityStatus: "suppressed",
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      console.log(
        `[onReportThresholdSuppressMerchant] Suppressed merchant ${targetId} (${openCount} open reports >= threshold ${threshold})`
      );
    }
  }
);
