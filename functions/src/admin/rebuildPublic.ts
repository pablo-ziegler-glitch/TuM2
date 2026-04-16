import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldPath, FieldValue } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "../lib/projection";
import { MerchantDoc, OperationalSignals } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 400;
const PAGE_SIZE = 400;
const SIGNALS_READ_CHUNK = 200;

interface RebuildRequest {
  merchantId?: string;
}

/**
 * adminRebuildMerchantPublic
 *
 * Admin-only HTTPS callable. Rebuilds merchant_public projection for:
 * - a single merchant (if merchantId is provided), or
 * - all visible merchants (if merchantId is omitted).
 *
 * Useful for debugging, data migrations, and feature rollouts.
 */
export const adminRebuildMerchantPublic = onCall(
  { enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    if (!request.auth.token.admin) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { merchantId } = request.data as RebuildRequest;

    if (merchantId) {
      const count = await rebuildSingle(merchantId);
      return { rebuilt: count, merchantId };
    } else {
      const count = await rebuildAll();
      return { rebuilt: count };
    }
  }
);

async function rebuildSingle(merchantId: string): Promise<number> {
  const merchantSnap = await db().doc(`merchants/${merchantId}`).get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", `Merchant ${merchantId} not found.`);
  }

  const merchant = merchantSnap.data() as MerchantDoc;
  const signalsSnap = await db()
    .doc(`merchant_operational_signals/${merchantId}`)
    .get();

  const signals = signalsSnap.exists
    ? (signalsSnap.data() as OperationalSignals)
    : undefined;

  const projection = computeMerchantPublicProjection(merchant, signals);
  await db()
    .doc(`merchant_public/${merchantId}`)
    .set({ ...projection, syncedAt: FieldValue.serverTimestamp() }, { merge: false });

  console.log(`[adminRebuildMerchantPublic] Rebuilt ${merchantId}`);
  return 1;
}

async function rebuildAll(): Promise<number> {
  let rebuilt = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let hasMore = true;

  while (hasMore) {
    let query = db()
      .collection("merchants")
      .where("visibilityStatus", "in", ["visible", "review_pending"])
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const merchantsSnap = await query.get();
    if (merchantsSnap.empty) {
      hasMore = false;
      continue;
    }

    const merchantIds = merchantsSnap.docs.map((doc) => doc.id);
    const signalsByMerchantId = new Map<string, OperationalSignals>();
    for (const idsChunk of chunk(merchantIds, SIGNALS_READ_CHUNK)) {
      const refs = idsChunk.map((merchantId) =>
        db().doc(`merchant_operational_signals/${merchantId}`)
      );
      const signalSnaps = await db().getAll(...refs);
      for (const signalSnap of signalSnaps) {
        if (!signalSnap.exists) continue;
        signalsByMerchantId.set(signalSnap.id, signalSnap.data() as OperationalSignals);
      }
    }

    let batch = db().batch();
    let batchOps = 0;
    const commits: Array<Promise<FirebaseFirestore.WriteResult[]>> = [];

    for (const doc of merchantsSnap.docs) {
      const merchantId = doc.id;
      const merchant = doc.data() as MerchantDoc;
      const signals = signalsByMerchantId.get(merchantId);
      const projection = computeMerchantPublicProjection(merchant, signals);

      batch.set(
        db().doc(`merchant_public/${merchantId}`),
        { ...projection, syncedAt: FieldValue.serverTimestamp() },
        { merge: false }
      );
      batchOps++;
      rebuilt++;

      if (batchOps >= BATCH_SIZE) {
        commits.push(batch.commit());
        batch = db().batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) commits.push(batch.commit());
    if (commits.length > 0) {
      await Promise.all(commits);
    }

    lastDoc = merchantsSnap.docs[merchantsSnap.docs.length - 1] ?? null;
    hasMore = merchantsSnap.size === PAGE_SIZE && lastDoc != null;
  }

  console.log(`[adminRebuildMerchantPublic] Rebuilt ${rebuilt} merchants.`);
  return rebuilt;
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}
