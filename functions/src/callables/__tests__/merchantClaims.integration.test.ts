import assert from "node:assert/strict";
import test, { before, beforeEach } from "node:test";
import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

let upsertDraftRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let submitClaimRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;

function buildRequest(params: {
  uid: string;
  email: string;
  data: Record<string, unknown>;
}): Record<string, unknown> {
  return {
    data: params.data,
    auth: {
      uid: params.uid,
      token: {
        role: "customer",
        email: params.email,
      },
    },
    rawRequest: { headers: {} },
  };
}

async function deleteCollection(collectionName: string): Promise<void> {
  const firestore = getFirestore();
  let hasMore = true;
  while (hasMore) {
    const snapshot = await firestore.collection(collectionName).limit(200).get();
    if (snapshot.empty) {
      hasMore = false;
      continue;
    }
    const batch = firestore.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

if (!emulatorHost) {
  test("merchant claims integration requires FIRESTORE_EMULATOR_HOST", { skip: true }, () => {
    assert.ok(true);
  });
} else {
  before(async () => {
    process.env.GCLOUD_PROJECT ??= "tum2-dev-6283d";
    if (getApps().length === 0) {
      initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    }

    const callables = await import("../merchantClaims");
    upsertDraftRun = (
      callables.upsertMerchantClaimDraft as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
    submitClaimRun = (
      callables.submitMerchantClaim as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
  });

  beforeEach(async () => {
    await Promise.all([deleteCollection("merchant_claims"), deleteCollection("merchants")]);
  });

  test("upsert draft crea claim y submit pasa a auto_validating", async () => {
    assert.ok(upsertDraftRun && submitClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Farmacia Central",
      categoryId: "pharmacy",
      zoneId: "zone-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const evidence = [
      {
        id: "storefront_1",
        kind: "storefront_photo",
        storagePath: `merchant-claims/user-1/claim-1234567890/storefront_photo/front.jpg`,
        contentType: "image/jpeg",
        sizeBytes: 1024,
      },
      {
        id: "document_1",
        kind: "ownership_document",
        storagePath: `merchant-claims/user-1/claim-1234567890/ownership_document/doc.jpg`,
        contentType: "image/jpeg",
        sizeBytes: 2048,
      },
    ];

    const draftResponse = (await upsertDraftRun!(
      buildRequest({
        uid: "user-1",
        email: "owner@example.com",
        data: {
          claimId: "claim-1234567890",
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: evidence,
        },
      })
    )) as Record<string, unknown>;

    assert.equal(draftResponse.claimStatus, "draft");

    const submitResponse = (await submitClaimRun!(
      buildRequest({
        uid: "user-1",
        email: "owner@example.com",
        data: {
          claimId: "claim-1234567890",
        },
      })
    )) as Record<string, unknown>;

    assert.equal(submitResponse.claimStatus, "auto_validating");
  });

  test("submit de claim sin evidencia mínima falla", async () => {
    assert.ok(upsertDraftRun && submitClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Kiosco 24h",
      categoryId: "kiosk",
      zoneId: "zone-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid: "user-1",
        email: "owner@example.com",
        data: {
          claimId: "claim-abcdefghij",
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [],
        },
      })
    );

    await assert.rejects(
      async () =>
        submitClaimRun!(
          buildRequest({
            uid: "user-1",
            email: "owner@example.com",
            data: {
              claimId: "claim-abcdefghij",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "failed-precondition");
        return true;
      }
    );
  });

  test("upsert draft bloquea duplicado activo por userId+merchantId", async () => {
    assert.ok(upsertDraftRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Veterinaria Norte",
      categoryId: "veterinary",
      zoneId: "zone-2",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid: "user-1",
        email: "owner@example.com",
        data: {
          claimId: "claim-dup-11111",
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: false,
          hasAcceptedLegitimacyDeclaration: false,
          evidenceFiles: [],
        },
      })
    );

    await assert.rejects(
      async () =>
        upsertDraftRun!(
          buildRequest({
            uid: "user-1",
            email: "owner@example.com",
            data: {
              claimId: "claim-dup-22222",
              merchantId,
              declaredRole: "owner",
              hasAcceptedDataProcessingConsent: false,
              hasAcceptedLegitimacyDeclaration: false,
              evidenceFiles: [],
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: Record<string, unknown> };
        assert.equal(err.code, "already-exists");
        assert.equal(err.details?.code, "active_claim_exists");
        return true;
      }
    );
  });
}
