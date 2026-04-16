import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();
const MAX_BATCH_SIZE = 400;

interface SanitizeMerchantClaimsRequest {
  cursor?: unknown;
  batchSize?: unknown;
  dryRun?: unknown;
}

interface SanitizeMerchantClaimsResponse {
  scanned: number;
  sanitized: number;
  dryRun: boolean;
  nextCursor: string | null;
}

function assertAdminAccess(
  auth: { token?: Record<string, unknown> } | null | undefined
): void {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const token = auth.token ?? {};
  const role = typeof token["role"] === "string" ? token["role"] : "";
  if (
    token["admin"] !== true &&
    role !== "admin" &&
    role !== "super_admin"
  ) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
}

function normalizeBatchSize(raw: unknown): number {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return 200;
  return Math.max(1, Math.min(MAX_BATCH_SIZE, Math.trunc(raw)));
}

function normalizeCursor(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  return value.length > 0 ? value : null;
}

function normalizeDryRun(raw: unknown): boolean {
  return raw === true;
}

function needsSanitization(data: FirebaseFirestore.DocumentData): boolean {
  return (
    data["sensitiveVault"] != null ||
    data["fingerprintPrimary"] != null ||
    data["phone"] != null ||
    data["claimantDisplayName"] != null ||
    data["claimantNote"] != null
  );
}

function buildSanitizePayload(): Record<string, unknown> {
  return {
    sensitiveVault: FieldValue.delete(),
    fingerprintPrimary: FieldValue.delete(),
    phone: FieldValue.delete(),
    claimantDisplayName: FieldValue.delete(),
    claimantNote: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * adminSanitizeMerchantClaimsSensitive
 *
 * Admin-only callable para limpiar campos sensibles legacy de merchant_claims.
 * Se ejecuta paginado por cursor para controlar costo y timeout.
 */
export const adminSanitizeMerchantClaimsSensitive = onCall<
  SanitizeMerchantClaimsRequest,
  Promise<SanitizeMerchantClaimsResponse>
>(
  { timeoutSeconds: 540, memory: "1GiB", enforceAppCheck: true },
  async (request) => {
    assertAdminAccess(request.auth);

    const batchSize = normalizeBatchSize(request.data.batchSize);
    const cursor = normalizeCursor(request.data.cursor);
    const dryRun = normalizeDryRun(request.data.dryRun);

    let query = db()
      .collection("merchant_claims")
      .orderBy("__name__")
      .limit(batchSize);
    if (cursor != null) {
      query = query.startAfter(cursor);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      return { scanned: 0, sanitized: 0, dryRun, nextCursor: null };
    }

    let sanitized = 0;
    const batch = db().batch();
    let writes = 0;

    for (const doc of snapshot.docs) {
      if (!needsSanitization(doc.data())) continue;
      sanitized++;
      if (dryRun) continue;
      batch.set(doc.ref, buildSanitizePayload(), { merge: true });
      writes++;
    }

    if (!dryRun && writes > 0) {
      await batch.commit();
    }

    const lastDoc = snapshot.docs[snapshot.docs.length - 1];
    return {
      scanned: snapshot.size,
      sanitized,
      dryRun,
      nextCursor: lastDoc?.id ?? null,
    };
  }
);
