import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { MerchantClaimDoc } from "../lib/types";

const db = () => getFirestore();
const OWNER_PENDING_STATUSES = new Set([
  "submitted",
  "under_review",
  "needs_more_info",
  "duplicate_claim",
  "conflict_detected",
]);
const ACTIVE_STATUSES = [...OWNER_PENDING_STATUSES, "draft"];

async function syncOwnerPendingClaim(userId: string, expected: boolean): Promise<void> {
  try {
    const auth = getAuth();
    const userRecord = await auth.getUser(userId);
    const currentClaims = userRecord.customClaims ?? {};
    const roleRaw = currentClaims["role"];
    const role = typeof roleRaw === "string" ? roleRaw.trim().toLowerCase() : "";
    const currentPending = currentClaims["owner_pending"] === true;

    // OWNER final no usa owner_pending.
    if (role === "owner" && expected) return;
    if (currentPending === expected) return;

    await auth.setCustomUserClaims(userId, {
      ...currentClaims,
      owner_pending: expected,
    });
  } catch (error) {
    console.warn(
      `[onClaimApprovedPromoteMerchant] owner_pending sync skipped user=${userId}`,
      error
    );
  }
}

async function clearOwnerPendingIfNoActiveClaims(userId: string): Promise<void> {
  const active = await db()
    .collection("merchant_claims")
    .where("userId", "==", userId)
    .where("claimStatus", "in", ACTIVE_STATUSES)
    .limit(1)
    .get();
  if (active.empty) {
    await syncOwnerPendingClaim(userId, false);
  }
}

/**
 * onClaimApprovedPromoteMerchant
 *
 * Triggered when a merchant_claims/{claimId} doc is updated.
 * If claimStatus transitions to "approved":
 * - Assigns ownerUserId to the merchant
 * - Upgrades verificationStatus to "claimed"
 * - merchant_public will be updated via the merchants trigger cascade
 */
export const onClaimApprovedPromoteMerchant = onDocumentUpdated(
  "merchant_claims/{claimId}",
  async (event) => {
    const before = event.data?.before.data() as MerchantClaimDoc;
    const after = event.data?.after.data() as MerchantClaimDoc;
    const beforeStatus = before?.claimStatus ?? null;
    const afterStatus = after?.claimStatus ?? null;

    if (!afterStatus || beforeStatus === afterStatus) return;

    // CLAIM workflow v2 maneja side-effects en callables para evitar duplicación.
    // Este trigger queda como fallback para flujos legacy/escrituras administrativas directas.
    if (after?.workflowManagedBy === "callable_v2") return;

    // Transición de owner_pending durante estados en revisión.
    if (OWNER_PENDING_STATUSES.has(afterStatus)) {
      await syncOwnerPendingClaim(after.userId, true);
    }

    // Si el claim cierra en negativo y no hay otros activos, limpiamos owner_pending.
    if (
      afterStatus === "rejected" ||
      afterStatus === "duplicate_claim" ||
      afterStatus === "conflict_detected"
    ) {
      await clearOwnerPendingIfNoActiveClaims(after.userId);
    }

    // Solo promoción OWNER cuando pasa a approved.
    if (afterStatus !== "approved") return;

    const { merchantId, userId } = after;
    if (!merchantId || !userId) {
      console.warn(`[onClaimApprovedPromoteMerchant] Missing merchantId or userId in claim ${event.params.claimId}`);
      return;
    }

    await db()
      .doc(`merchants/${merchantId}`)
      .set(
        {
          ownerUserId: userId,
          verificationStatus: "claimed",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    const auth = getAuth();
    const userRecord = await auth.getUser(userId);
    const currentClaims = userRecord.customClaims ?? {};
    const claimMerchantId =
      typeof currentClaims["merchantId"] === "string" &&
      currentClaims["merchantId"].trim().length > 0
        ? currentClaims["merchantId"].trim()
        : null;
    const claimMerchantIds = Array.isArray(currentClaims["merchantIds"])
      ? currentClaims["merchantIds"]
          .filter((value): value is string => typeof value === "string")
          .map((value) => value.trim())
          .filter((value) => value.length > 0)
      : [];
    const mergedMerchantIds = [...new Set([merchantId, ...claimMerchantIds])];

    await auth.setCustomUserClaims(userId, {
      ...currentClaims,
      role: "owner",
      merchantId: claimMerchantId ?? merchantId,
      merchantIds: mergedMerchantIds,
      onboardingComplete: true,
      owner_pending: false,
    });

    console.log(
      `[onClaimApprovedPromoteMerchant] Merchant ${merchantId} promoted to claimed, owner=${userId}, claimsSynced=true`
    );
  }
);
