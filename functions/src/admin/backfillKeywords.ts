import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { buildSearchKeywords } from "../lib/projection";
import { MerchantDoc } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 400;

export interface BackfillSearchKeywordsSummary {
  scanned: number;
  updated: number;
  skipped: number;
  failed: number;
  missingBefore: number;
}

export function assertAdminCallableAccess(
  auth: { token?: Record<string, unknown> } | null | undefined
): void {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (auth.token?.["admin"] !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
}

function asKeywordSource(
  merchantPublicData: FirebaseFirestore.DocumentData
): MerchantDoc {
  return {
    merchantId: (merchantPublicData["merchantId"] as string) ?? "",
    name: (merchantPublicData["name"] as string) ?? "",
    category:
      (merchantPublicData["categoryId"] as string) ??
      (merchantPublicData["category"] as string) ??
      "",
    zone:
      (merchantPublicData["zoneId"] as string) ??
      (merchantPublicData["zone"] as string) ??
      "",
    address: merchantPublicData["address"] as string | undefined,
    verificationStatus:
      (merchantPublicData["verificationStatus"] as MerchantDoc["verificationStatus"]) ??
      "unverified",
    visibilityStatus:
      (merchantPublicData["visibilityStatus"] as MerchantDoc["visibilityStatus"]) ??
      "visible",
    sourceType: "community",
  };
}

export function shouldUpdateKeywords(
  currentKeywords: unknown,
  nextKeywords: string[]
): boolean {
  if (!Array.isArray(currentKeywords)) return true;
  const normalizedCurrent = currentKeywords.map((value) => String(value));
  if (normalizedCurrent.length !== nextKeywords.length) return true;
  return normalizedCurrent.some((value, index) => value !== nextKeywords[index]);
}

export async function runBackfillSearchKeywords(): Promise<BackfillSearchKeywordsSummary> {
  const snapshot = await db().collection("merchant_public").get();

  if (snapshot.empty) {
    return { scanned: 0, updated: 0, skipped: 0, failed: 0, missingBefore: 0 };
  }

  let scanned = 0;
  let updated = 0;
  let skipped = 0;
  let failed = 0;
  let missingBefore = 0;

  let batchOps = 0;
  let batch = db().batch();
  const commits: Array<Promise<FirebaseFirestore.WriteResult[]>> = [];

  for (const doc of snapshot.docs) {
    scanned++;
    try {
      const data = doc.data();
      const currentKeywords = data["searchKeywords"];
      if (!Array.isArray(currentKeywords) || currentKeywords.length === 0) {
        missingBefore++;
      }

      const source = asKeywordSource(data);
      const nextKeywords = buildSearchKeywords(source);

      if (!shouldUpdateKeywords(currentKeywords, nextKeywords)) {
        skipped++;
        continue;
      }

      batch.set(doc.ref, { searchKeywords: nextKeywords }, { merge: true });
      updated++;
      batchOps++;

      if (batchOps >= BATCH_SIZE) {
        commits.push(batch.commit());
        batch = db().batch();
        batchOps = 0;
      }
    } catch (error) {
      failed++;
      console.error("[backfillSearchKeywords] Failed doc", {
        merchantId: doc.id,
        error,
      });
    }
  }

  if (batchOps > 0) {
    commits.push(batch.commit());
  }

  await Promise.all(commits);
  return { scanned, updated, skipped, failed, missingBefore };
}

/**
 * backfillSearchKeywords
 *
 * Admin-only callable. Rebuilds searchKeywords for merchant_public documents
 * using source data from merchants.
 */
export const backfillSearchKeywords = onCall(
  { timeoutSeconds: 540, memory: "1GiB", enforceAppCheck: true },
  async (request) => {
    assertAdminCallableAccess(request.auth);

    const summary = await runBackfillSearchKeywords();
    console.log("[backfillSearchKeywords] Summary", summary);
    return summary;
  }
);
