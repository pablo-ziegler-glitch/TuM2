import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { MerchantClaimDoc } from "../lib/types";

const db = () => getFirestore();

/**
 * onClaimApprovedPromoteMerchant
 *
 * Triggered when a merchant_claims/{claimId} doc is updated.
 * If the status transitions to "approved":
 * - Assigns ownerUserId to the merchant
 * - Upgrades verificationStatus to "claimed"
 * - merchant_public will be updated via the merchants trigger cascade
 */
export const onClaimApprovedPromoteMerchant = onDocumentUpdated(
  "merchant_claims/{claimId}",
  async (event) => {
    const before = event.data?.before.data() as MerchantClaimDoc;
    const after = event.data?.after.data() as MerchantClaimDoc;

    // Only act on status change to "approved"
    if (before.status === "approved" || after.status !== "approved") return;

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

    console.log(
      `[onClaimApprovedPromoteMerchant] Merchant ${merchantId} promoted to claimed, owner=${userId}`
    );
  }
);
