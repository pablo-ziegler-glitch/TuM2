import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();

const OWNER_PENDING_STATUSES = new Set([
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
]);

const CLOSED_NEGATIVE_STATUSES = new Set(["rejected"]);

async function hasOtherPendingClaims(
  userId: string,
  excludeClaimId: string
): Promise<boolean> {
  const snap = await db()
    .collection("merchant_claims")
    .where("userId", "==", userId)
    .where("claimStatus", "in", [...OWNER_PENDING_STATUSES])
    .limit(5)
    .get();
  return snap.docs.some((doc) => doc.id !== excludeClaimId);
}

export async function syncOwnerPendingAccess(params: {
  userId: string;
  claimId: string;
  claimStatus: string;
  merchantId: string;
}): Promise<void> {
  const auth = getAuth();
  let currentClaims: Record<string, unknown> = {};
  let isOwner = false;

  try {
    const userRecord = await auth.getUser(params.userId);
    currentClaims = (userRecord.customClaims ?? {}) as Record<string, unknown>;
    isOwner = currentClaims["role"] === "owner";
  } catch (error) {
    console.warn(
      JSON.stringify({
        source: "merchant_claims",
        action: "owner_pending_get_user_failed",
        userId: params.userId,
        claimId: params.claimId,
        error: error instanceof Error ? error.message : String(error),
      })
    );
  }

  let ownerPending = OWNER_PENDING_STATUSES.has(params.claimStatus);
  if (!ownerPending && !isOwner && CLOSED_NEGATIVE_STATUSES.has(params.claimStatus)) {
    ownerPending = await hasOtherPendingClaims(params.userId, params.claimId);
  }

  const nextClaims: Record<string, unknown> = { ...currentClaims };
  nextClaims["owner_pending"] = ownerPending;

  if (params.claimStatus === "approved") {
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
    nextClaims["role"] = "owner";
    nextClaims["merchantId"] = claimMerchantId ?? params.merchantId;
    nextClaims["merchantIds"] = [...new Set([params.merchantId, ...claimMerchantIds])];
    nextClaims["onboardingComplete"] = true;
    nextClaims["owner_pending"] = false;
  } else if (!isOwner) {
    nextClaims["role"] = "customer";
    nextClaims["onboardingComplete"] = false;
  }

  if (JSON.stringify(currentClaims) !== JSON.stringify(nextClaims)) {
    try {
      await auth.setCustomUserClaims(params.userId, nextClaims);
    } catch (error) {
      console.warn(
        JSON.stringify({
          source: "merchant_claims",
          action: "owner_pending_set_claims_failed",
          userId: params.userId,
          claimId: params.claimId,
          error: error instanceof Error ? error.message : String(error),
        })
      );
    }
  }

  const userRef = db().doc(`users/${params.userId}`);
  const nextUserRole =
    params.claimStatus === "approved" ? "owner" : isOwner ? "owner" : "customer";
  const nextUserMerchantId =
    params.claimStatus === "approved" ? (nextClaims["merchantId"] as string) : null;
  const nextUserOwnerPending = nextClaims["owner_pending"] === true;
  const nextUserOnboarding = nextClaims["onboardingComplete"] === true;

  const userSnap = await userRef.get();
  const userData = userSnap.data() ?? {};
  const currentUserRole = typeof userData.role === "string" ? userData.role : null;
  const currentUserMerchantId =
    typeof userData.merchantId === "string" ? userData.merchantId : null;
  const currentUserOwnerPending = userData.ownerPending === true;
  const currentUserOnboarding = userData.onboardingComplete === true;

  const changed =
    currentUserRole !== nextUserRole ||
    currentUserMerchantId !== nextUserMerchantId ||
    currentUserOwnerPending !== nextUserOwnerPending ||
    currentUserOnboarding !== nextUserOnboarding;

  if (changed) {
    await userRef.set(
      {
        role: nextUserRole,
        merchantId: nextUserMerchantId,
        ownerPending: nextUserOwnerPending,
        onboardingComplete: nextUserOnboarding,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}
