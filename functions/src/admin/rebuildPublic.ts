import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "../lib/projection";
import { MerchantDoc, OperationalSignals } from "../lib/types";

const db = () => getFirestore();
const BATCH_SIZE = 400;

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
  { enforceAppCheck: false },
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
  const merchantsSnap = await db()
    .collection("merchants")
    .where("visibilityStatus", "in", ["visible", "review_pending"])
    .get();

  if (merchantsSnap.empty) return 0;

  let rebuilt = 0;
  let batch = db().batch();
  let batchOps = 0;
  const batches: FirebaseFirestore.WriteBatch[] = [];

  for (const doc of merchantsSnap.docs) {
    const merchantId = doc.id;
    const merchant = doc.data() as MerchantDoc;

    const signalsSnap = await db()
      .doc(`merchant_operational_signals/${merchantId}`)
      .get();

    const signals = signalsSnap.exists
      ? (signalsSnap.data() as OperationalSignals)
      : undefined;

    const projection = computeMerchantPublicProjection(merchant, signals);
    batch.set(
      db().doc(`merchant_public/${merchantId}`),
      { ...projection, syncedAt: FieldValue.serverTimestamp() },
      { merge: false }
    );
    batchOps++;
    rebuilt++;

    if (batchOps >= BATCH_SIZE) {
      batches.push(batch);
      batch = db().batch();
      batchOps = 0;
    }
  }

  if (batchOps > 0) batches.push(batch);
  await Promise.all(batches.map((b) => b.commit()));

  console.log(`[adminRebuildMerchantPublic] Rebuilt ${rebuilt} merchants.`);
  return rebuilt;
}
