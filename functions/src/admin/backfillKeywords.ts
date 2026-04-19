import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldPath, getFirestore } from "firebase-admin/firestore";
import { buildSearchKeywords } from "../lib/projection";
import { MerchantDoc } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 400;
const DEFAULT_PAGE_SIZE = 300;
const MAX_PAGE_SIZE = 1000;
const DEFAULT_MAX_PAGES = 10;
const MAX_PAGES = 100;

export interface BackfillSearchKeywordsSummary {
  scanned: number;
  updated: number;
  skipped: number;
  failed: number;
  missingBefore: number;
  pageSize: number;
  pagesProcessed: number;
  hasMore: boolean;
  nextCursor: string | null;
  durationMs: number;
}

export interface BackfillSearchKeywordsOptions {
  pageSize?: number;
  startAfterId?: string;
  maxPages?: number;
}

function normalizeBackfillOptions(
  options?: BackfillSearchKeywordsOptions
): Required<BackfillSearchKeywordsOptions> {
  const pageSizeRaw = Number(options?.pageSize ?? DEFAULT_PAGE_SIZE);
  const maxPagesRaw = Number(options?.maxPages ?? DEFAULT_MAX_PAGES);
  return {
    pageSize: Math.max(1, Math.min(MAX_PAGE_SIZE, Number.isFinite(pageSizeRaw) ? pageSizeRaw : DEFAULT_PAGE_SIZE)),
    startAfterId: (options?.startAfterId ?? "").trim(),
    maxPages: Math.max(1, Math.min(MAX_PAGES, Number.isFinite(maxPagesRaw) ? maxPagesRaw : DEFAULT_MAX_PAGES)),
  };
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

export async function runBackfillSearchKeywords(
  options?: BackfillSearchKeywordsOptions
): Promise<BackfillSearchKeywordsSummary> {
  const startedAtMs = Date.now();
  const normalizedOptions = normalizeBackfillOptions(options);

  let scanned = 0;
  let updated = 0;
  let skipped = 0;
  let failed = 0;
  let missingBefore = 0;
  let pagesProcessed = 0;
  let hasMore = false;
  let nextCursor: string | null = normalizedOptions.startAfterId || null;

  let batchOps = 0;
  let batch = db().batch();
  const commits: Array<Promise<FirebaseFirestore.WriteResult[]>> = [];

  for (let page = 0; page < normalizedOptions.maxPages; page++) {
    let query = db()
      .collection("merchant_public")
      .orderBy(FieldPath.documentId())
      .limit(normalizedOptions.pageSize);
    if (nextCursor) {
      query = query.startAfter(nextCursor);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      hasMore = false;
      nextCursor = null;
      break;
    }
    pagesProcessed += 1;

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

    const lastDocId = snapshot.docs[snapshot.docs.length - 1]?.id ?? null;
    if (!lastDocId) {
      hasMore = false;
      nextCursor = null;
      break;
    }
    if (snapshot.size < normalizedOptions.pageSize) {
      hasMore = false;
      nextCursor = null;
      break;
    }
    nextCursor = lastDocId;
    hasMore = true;
  }

  if (batchOps > 0) {
    commits.push(batch.commit());
  }

  await Promise.all(commits);

  const durationMs = Date.now() - startedAtMs;
  const summary = {
    scanned,
    updated,
    skipped,
    failed,
    missingBefore,
    pageSize: normalizedOptions.pageSize,
    pagesProcessed,
    hasMore,
    nextCursor: hasMore ? nextCursor : null,
    durationMs,
  };
  console.log(
    JSON.stringify({
      job: "backfillSearchKeywords",
      readDocs: scanned,
      writeDocs: updated,
      skippedDocs: skipped,
      failedDocs: failed,
      missingBefore,
      pageSize: normalizedOptions.pageSize,
      pagesProcessed,
      hasMore,
      nextCursor: hasMore ? nextCursor : null,
      durationMs,
    })
  );
  return summary;
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

    const payload = (request.data ?? {}) as Record<string, unknown>;
    const summary = await runBackfillSearchKeywords({
      pageSize: typeof payload["pageSize"] === "number" ? payload["pageSize"] : undefined,
      startAfterId: typeof payload["startAfterId"] === "string" ? payload["startAfterId"] : undefined,
      maxPages: typeof payload["maxPages"] === "number" ? payload["maxPages"] : undefined,
    });
    console.log("[backfillSearchKeywords] Summary", summary);
    return summary;
  }
);
