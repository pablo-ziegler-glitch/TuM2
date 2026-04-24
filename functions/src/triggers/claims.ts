import { onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { MerchantClaimDoc } from "../lib/types";
import {
  readClaimStatusFromSnapshotData,
  runMerchantClaimAutoValidation,
  shouldRunAutoValidationFromTransition,
} from "../lib/merchantClaimAutoValidationService";
import { syncOwnerPendingAccess } from "../lib/merchantClaimOwnerPending";

const db = () => getFirestore();

export const onClaimSubmittedRunAutoValidation = onDocumentWritten(
  "merchant_claims/{claimId}",
  async (event) => {
    const beforeData = event.data?.before.data() as Record<string, unknown> | undefined;
    const afterData = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!afterData) return;

    const beforeStatus = readClaimStatusFromSnapshotData(beforeData);
    const afterStatus = readClaimStatusFromSnapshotData(afterData);
    if (!shouldRunAutoValidationFromTransition({ beforeStatus, afterStatus })) {
      return;
    }

    await runMerchantClaimAutoValidation({
      claimId: event.params.claimId,
      origin: "submitted_trigger",
    });
  }
);

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

    // Solo promoción OWNER cuando pasa a approved.
    const { merchantId, userId } = after;
    if (!merchantId || !userId) {
      console.warn(`[onClaimApprovedPromoteMerchant] Missing merchantId or userId in claim ${event.params.claimId}`);
      return;
    }

    if (afterStatus === "approved") {
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
    }

    await syncOwnerPendingAccess({
      userId,
      claimId: event.params.claimId,
      claimStatus: afterStatus,
      merchantId,
      forceAccessVersionBump: true,
      reasonCode: (() => {
        const afterMap = after as unknown as Record<string, unknown>;
        const raw = afterMap["reviewReasonCode"];
        return typeof raw === "string" ? raw : null;
      })(),
    });

    console.log(
      `[onClaimApprovedPromoteMerchant] Fallback sync completed claim=${event.params.claimId} status=${afterStatus} user=${userId}`
    );
  }
);
