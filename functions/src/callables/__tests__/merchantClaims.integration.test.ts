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
let resolveClaimRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let revealSensitiveRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;

function buildRequest(params: {
  uid: string;
  email: string;
  data: Record<string, unknown>;
  role?: "customer" | "admin" | "super_admin";
}): Record<string, unknown> {
  return {
    data: params.data,
    auth: {
      uid: params.uid,
      token: {
        role: params.role ?? "customer",
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
    resolveClaimRun = (
      callables.resolveMerchantClaim as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
    revealSensitiveRun = (
      callables.revealMerchantClaimSensitiveData as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
  });

  beforeEach(async () => {
    await Promise.all([
      deleteCollection("merchant_claims"),
      deleteCollection("merchant_claim_private"),
      deleteCollection("merchants"),
      deleteCollection("users"),
      deleteCollection("merchant_claim_sensitive_reveals"),
    ]);
  });

  test("draft+submit usa estados canónicos y activa owner_pending", async () => {
    assert.ok(upsertDraftRun && submitClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-1234567890";
    const uid = "user-1";

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
        storagePath: `merchant-claims/${uid}/${claimId}/storefront_photo/front.jpg`,
        contentType: "image/jpeg",
        sizeBytes: 1024,
      },
      {
        id: "document_1",
        kind: "ownership_document",
        storagePath: `merchant-claims/${uid}/${claimId}/ownership_document/doc.jpg`,
        contentType: "image/jpeg",
        sizeBytes: 2048,
      },
    ];

    const draftResponse = (await upsertDraftRun!(
      buildRequest({
        uid,
        email: "owner@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          phone: "+54 9 11 1234 5678",
          claimantDisplayName: "Juan Perez",
          claimantNote: "Solicitud inicial",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: evidence,
        },
      })
    )) as Record<string, unknown>;
    assert.equal(draftResponse.claimStatus, "draft");

    const draftSnap = await firestore.collection("merchant_claims").doc(claimId).get();
    const draftData = draftSnap.data() ?? {};
    assert.equal(draftData.claimStatus, "draft");
    assert.equal(draftData.userVisibleStatus, "draft");
    assert.equal(draftData.internalWorkflowStatus, "draft_editing");
    assert.equal(draftData.authenticatedEmail, "owner@example.com");
    assert.equal(typeof draftData.phoneMasked, "string");
    assert.equal(draftData.sensitiveVault, undefined);
    assert.equal(draftData.phone, undefined);

    const privateSnap = await firestore
      .collection("merchant_claim_private")
      .doc(claimId)
      .get();
    const privateData = privateSnap.data() ?? {};
    assert.equal(typeof privateData.sensitiveVault, "object");

    const submitResponse = (await submitClaimRun!(
      buildRequest({
        uid,
        email: "owner@example.com",
        data: { claimId },
      })
    )) as Record<string, unknown>;
    assert.equal(submitResponse.claimStatus, "under_review");

    const submittedSnap = await firestore.collection("merchant_claims").doc(claimId).get();
    const submittedData = submittedSnap.data() ?? {};
    assert.equal(submittedData.userVisibleStatus, "under_review");
    assert.equal(submittedData.internalWorkflowStatus, "auto_validation_passed");

    const userDoc = await firestore.doc(`users/${uid}`).get();
    assert.equal(userDoc.get("ownerPending"), true);
    assert.equal(userDoc.get("role"), "customer");
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
            data: { claimId: "claim-abcdefghij" },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "failed-precondition");
        return true;
      }
    );
  });

  test("submit conflictivo marca conflict_detected y mantiene owner_pending", async () => {
    assert.ok(upsertDraftRun && submitClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-conflict1";
    const uid = "user-2";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Veterinaria Norte",
      categoryId: "veterinary",
      zoneId: "zone-2",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "claimed",
      ownerUserId: "existing-owner",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "owner2@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [
            {
              id: "storefront_1",
              kind: "storefront_photo",
              storagePath: `merchant-claims/${uid}/${claimId}/storefront_photo/front.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 1111,
            },
            {
              id: "document_1",
              kind: "ownership_document",
              storagePath: `merchant-claims/${uid}/${claimId}/ownership_document/doc.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 2222,
            },
          ],
        },
      })
    );

    const submitResponse = (await submitClaimRun!(
      buildRequest({
        uid,
        email: "owner2@example.com",
        data: { claimId },
      })
    )) as Record<string, unknown>;
    assert.equal(submitResponse.claimStatus, "conflict_detected");

    const userDoc = await firestore.doc(`users/${uid}`).get();
    assert.equal(userDoc.get("ownerPending"), true);
    assert.equal(userDoc.get("role"), "customer");
  });

  test("resolve approved promueve a owner y limpia owner_pending", async () => {
    assert.ok(upsertDraftRun && submitClaimRun && resolveClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-approve1";
    const uid = "user-3";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Panaderia Sol",
      categoryId: "bakery",
      zoneId: "zone-3",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "owner3@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [
            {
              id: "storefront_1",
              kind: "storefront_photo",
              storagePath: `merchant-claims/${uid}/${claimId}/storefront_photo/front.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 1111,
            },
            {
              id: "document_1",
              kind: "ownership_document",
              storagePath: `merchant-claims/${uid}/${claimId}/ownership_document/doc.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 2222,
            },
          ],
        },
      })
    );
    await submitClaimRun!(
      buildRequest({
        uid,
        email: "owner3@example.com",
        data: { claimId },
      })
    );

    const resolveResponse = (await resolveClaimRun!(
      buildRequest({
        uid: "admin-1",
        email: "admin@example.com",
        role: "admin",
        data: {
          claimId,
          userVisibleStatus: "approved",
          reviewReasonCode: "manual_ok",
        },
      })
    )) as Record<string, unknown>;
    assert.equal(resolveResponse.claimStatus, "approved");

    const userDoc = await firestore.doc(`users/${uid}`).get();
    assert.equal(userDoc.get("ownerPending"), false);
    assert.equal(userDoc.get("role"), "owner");

    const merchantDoc = await firestore.doc(`merchants/${merchantId}`).get();
    assert.equal(merchantDoc.get("ownerUserId"), uid);
    assert.equal(merchantDoc.get("ownershipStatus"), "claimed");
  });

  test("reveal sensible devuelve datos y registra auditoría append-only", async () => {
    assert.ok(upsertDraftRun && revealSensitiveRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-reveal12";
    const uid = "user-4";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Heladeria Sur",
      categoryId: "icecream",
      zoneId: "zone-4",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "owner4@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          phone: "+54 9 11 5678 1234",
          claimantDisplayName: "Maria Gomez",
          claimantNote: "Documento firmado",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [],
        },
      })
    );

    const revealResponse = (await revealSensitiveRun!(
      buildRequest({
        uid: "admin-2",
        email: "admin@example.com",
        role: "admin",
        data: {
          claimId,
          reasonCode: "manual_review",
          fields: ["phone", "claimantDisplayName"],
        },
      })
    )) as Record<string, unknown>;

    assert.equal(revealResponse.claimId, claimId);
    const revealed = (revealResponse.revealed ?? {}) as Record<string, unknown>;
    assert.equal(typeof revealed.phone, "string");
    assert.equal(typeof revealed.claimantDisplayName, "string");
    assert.equal(revealed.claimantNote, undefined);

    const auditSnap = await firestore
      .collection("merchant_claim_sensitive_reveals")
      .where("claimId", "==", claimId)
      .limit(1)
      .get();
    assert.equal(auditSnap.empty, false);
    const audit = auditSnap.docs[0].data();
    assert.equal(audit.reasonCode, "manual_review");
  });
}
