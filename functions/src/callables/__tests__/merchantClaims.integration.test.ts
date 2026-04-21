import assert from "node:assert/strict";
import test, { before, beforeEach } from "node:test";
import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

let upsertDraftRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let submitClaimRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let evaluateClaimRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let resolveClaimRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let revealSensitiveRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let getReviewDetailRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let listReviewQueueRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;
let listMyClaimsRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;

function buildRequest(params: {
  uid: string;
  email: string;
  data: Record<string, unknown>;
  role?: "customer" | "admin" | "super_admin";
  tokenExtras?: Record<string, unknown>;
}): Record<string, unknown> {
  return {
    data: params.data,
    auth: {
      uid: params.uid,
      token: {
        role: params.role ?? "customer",
        email: params.email,
        ...(params.tokenExtras ?? {}),
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
    evaluateClaimRun = (
      callables.evaluateMerchantClaim as unknown as {
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
    getReviewDetailRun = (
      callables.getMerchantClaimReviewDetail as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
    listReviewQueueRun = (
      callables.listMerchantClaimsForReview as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
    listMyClaimsRun = (
      callables.listMyMerchantClaims as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
  });

  beforeEach(async () => {
    await Promise.all([
      deleteCollection("merchant_claims"),
      deleteCollection("merchant_claim_private"),
      deleteCollection("merchants"),
      deleteCollection("zones"),
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
      {
        id: "regulatory_1",
        kind: "regulatory_document",
        storagePath: `merchant-claims/${uid}/${claimId}/regulatory_document/reg.pdf`,
        contentType: "application/pdf",
        sizeBytes: 4096,
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
    assert.deepEqual(submittedData.autoValidationReasons ?? [], [
      "sensitive_category_requires_manual_review",
    ]);
    const merchantPublicDoc = await firestore.doc(`merchant_public/${merchantId}`).get();
    assert.equal(merchantPublicDoc.exists, false);

    const userDoc = await firestore.doc(`users/${uid}`).get();
    assert.equal(userDoc.get("ownerPending"), true);
    assert.equal(userDoc.get("role"), "customer");
  });

  test("submit de claim sin evidencia mínima deriva a needs_more_info", async () => {
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

    const submitResponse = (await submitClaimRun!(
      buildRequest({
        uid: "user-1",
        email: "owner@example.com",
        data: { claimId: "claim-abcdefghij" },
      })
    )) as Record<string, unknown>;

    assert.equal(submitResponse.claimStatus, "needs_more_info");
    const updated = await firestore
      .collection("merchant_claims")
      .doc("claim-abcdefghij")
      .get();
    assert.equal(updated.get("missingEvidence"), true);
    assert.deepEqual(updated.get("missingEvidenceTypes"), [
      "storefront_photo",
      "ownership_document",
    ]);
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
      categoryId: "kiosk",
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

  test("rerun admin no duplica decisión ni escribe no-op", async () => {
    assert.ok(upsertDraftRun && submitClaimRun && evaluateClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-rerun-1";
    const uid = "user-rerun";

    await firestore.collection("merchants").doc(merchantId).set({
      name: "Kiosco Centro",
      categoryId: "kiosk",
      zoneId: "zone-5",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "rerun@example.com",
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
              sizeBytes: 1024,
            },
            {
              id: "document_1",
              kind: "ownership_document",
              storagePath: `merchant-claims/${uid}/${claimId}/ownership_document/doc.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 2048,
            },
          ],
        },
      })
    );

    await submitClaimRun!(
      buildRequest({
        uid,
        email: "rerun@example.com",
        data: { claimId },
      })
    );

    const before = await firestore.doc(`merchant_claims/${claimId}`).get();
    const beforeUpdatedAt = (before.get("updatedAt") as Timestamp).toMillis();
    const firstHash = before.get("lastAutoValidationHash");

    await evaluateClaimRun!(
      buildRequest({
        uid: "admin-rerun-1",
        email: "admin-rerun@example.com",
        role: "admin",
        data: { claimId },
      })
    );
    const after = await firestore.doc(`merchant_claims/${claimId}`).get();
    const afterUpdatedAt = (after.get("updatedAt") as Timestamp).toMillis();
    const secondHash = after.get("lastAutoValidationHash");

    assert.equal(before.get("claimStatus"), "under_review");
    assert.equal(after.get("claimStatus"), "under_review");
    assert.equal(firstHash, secondHash);
    assert.equal(beforeUpdatedAt, afterUpdatedAt);
  });

  test("reveal sensible devuelve datos y registra auditoría append-only", async () => {
    assert.ok(upsertDraftRun && revealSensitiveRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-reveal12";
    const uid = "user-4";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Heladeria Sur",
      categoryId: "fast_food",
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
          reasonCode: "verify_identity",
          fields: ["phone", "fullName"],
        },
      })
    )) as Record<string, unknown>;

    assert.equal(revealResponse.claimId, claimId);
    const revealed = (revealResponse.revealed ?? {}) as Record<string, unknown>;
    assert.equal(typeof revealed.phone, "string");
    assert.equal(typeof revealed.fullName, "string");
    assert.equal(revealed.claimNote, undefined);

    const auditSnap = await firestore
      .collection("merchant_claim_sensitive_reveals")
      .where("claimId", "==", claimId)
      .limit(1)
      .get();
    assert.equal(auditSnap.empty, false);
    const audit = auditSnap.docs[0].data();
    assert.equal(audit.reasonCode, "verify_identity");
  });

  test("cola admin de claims filtra por zone/status y pagina por cursor", async () => {
    assert.ok(listReviewQueueRun);
    const firestore = getFirestore();
    const zoneId = "zone-review-1";
    await firestore.collection("zones").doc(zoneId).set({
      provinceName: "Buenos Aires",
      departmentName: "Ezeiza",
      localityName: "Ezeiza",
    });

    const baseMillis = 1_710_000_000_000;
    const claims = [
      {
        claimId: "claim-review-001",
        zoneId,
        status: "under_review",
        createdAt: Timestamp.fromMillis(baseMillis + 3000),
      },
      {
        claimId: "claim-review-002",
        zoneId,
        status: "needs_more_info",
        createdAt: Timestamp.fromMillis(baseMillis + 2000),
      },
      {
        claimId: "claim-review-003",
        zoneId,
        status: "conflict_detected",
        createdAt: Timestamp.fromMillis(baseMillis + 1000),
      },
      {
        claimId: "claim-review-other-zone",
        zoneId: "zone-review-2",
        status: "under_review",
        createdAt: Timestamp.fromMillis(baseMillis + 4000),
      },
      {
        claimId: "claim-review-closed",
        zoneId,
        status: "approved",
        createdAt: Timestamp.fromMillis(baseMillis + 5000),
      },
    ];

    await Promise.all(
      claims.map((item, index) =>
        firestore.collection("merchant_claims").doc(item.claimId).set({
          claimId: item.claimId,
          merchantId: `merchant-review-${index}`,
          userId: `user-review-${index}`,
          zoneId: item.zoneId,
          provinceName: item.zoneId === zoneId ? "Buenos Aires" : "Buenos Aires",
          provinceKey: "buenos aires",
          departmentName: item.zoneId === zoneId ? "Ezeiza" : "Cañuelas",
          departmentKey: item.zoneId === zoneId ? "ezeiza" : "canuelas",
          categoryId: "pharmacy",
          declaredRole: "owner",
          claimStatus: item.status,
          userVisibleStatus: item.status,
          merchantName: `Merchant ${index}`,
          createdAt: item.createdAt,
          updatedAt: item.createdAt,
          submittedAt: item.createdAt,
        })
      )
    );

    const firstPage = (await listReviewQueueRun!(
      buildRequest({
        uid: "admin-review",
        email: "admin-review@example.com",
        role: "admin",
        data: {
          provinceName: "Buenos Aires",
          departmentName: "Ezeiza",
          zoneId,
          limit: 2,
          statuses: ["under_review", "needs_more_info", "conflict_detected"],
        },
      })
    )) as {
      claims: Array<{ claimId: string }>;
      nextCursor: { createdAtMillis: number; claimId: string } | null;
    };

    assert.equal(firstPage.claims.length, 2);
    assert.deepEqual(
      firstPage.claims.map((item) => item.claimId),
      ["claim-review-001", "claim-review-002"]
    );
    assert.ok(firstPage.nextCursor);

    const secondPage = (await listReviewQueueRun!(
      buildRequest({
        uid: "admin-review",
        email: "admin-review@example.com",
        role: "admin",
        data: {
          provinceName: "Buenos Aires",
          departmentName: "Ezeiza",
          zoneId,
          limit: 2,
          statuses: ["under_review", "needs_more_info", "conflict_detected"],
          cursorCreatedAtMillis: firstPage.nextCursor!.createdAtMillis,
          cursorClaimId: firstPage.nextCursor!.claimId,
        },
      })
    )) as {
      claims: Array<{ claimId: string }>;
      nextCursor: { createdAtMillis: number; claimId: string } | null;
    };

    assert.equal(secondPage.claims.length, 1);
    assert.deepEqual(secondPage.claims.map((item) => item.claimId), [
      "claim-review-003",
    ]);
    assert.equal(secondPage.nextCursor, null);
  });

  test("historial de mis claims pagina por updatedAt desc sin listeners", async () => {
    assert.ok(listMyClaimsRun);
    const firestore = getFirestore();
    const uid = "user-history-1";
    const baseMillis = 1_710_100_000_000;

    await Promise.all([
      firestore.collection("merchant_claims").doc("claim-history-001").set({
        claimId: "claim-history-001",
        merchantId: "merchant-h-1",
        userId: uid,
        zoneId: "zone-h",
        categoryId: "pharmacy",
        claimStatus: "under_review",
        userVisibleStatus: "under_review",
        updatedAt: Timestamp.fromMillis(baseMillis + 3000),
        createdAt: Timestamp.fromMillis(baseMillis + 1000),
      }),
      firestore.collection("merchant_claims").doc("claim-history-002").set({
        claimId: "claim-history-002",
        merchantId: "merchant-h-2",
        userId: uid,
        zoneId: "zone-h",
        categoryId: "pharmacy",
        claimStatus: "needs_more_info",
        userVisibleStatus: "needs_more_info",
        updatedAt: Timestamp.fromMillis(baseMillis + 2000),
        createdAt: Timestamp.fromMillis(baseMillis + 1000),
      }),
      firestore.collection("merchant_claims").doc("claim-history-003").set({
        claimId: "claim-history-003",
        merchantId: "merchant-h-3",
        userId: uid,
        zoneId: "zone-h",
        categoryId: "pharmacy",
        claimStatus: "approved",
        userVisibleStatus: "approved",
        updatedAt: Timestamp.fromMillis(baseMillis + 1000),
        createdAt: Timestamp.fromMillis(baseMillis + 1000),
      }),
      firestore.collection("merchant_claims").doc("claim-history-other-user").set({
        claimId: "claim-history-other-user",
        merchantId: "merchant-h-x",
        userId: "another-user",
        zoneId: "zone-h",
        categoryId: "pharmacy",
        claimStatus: "under_review",
        userVisibleStatus: "under_review",
        updatedAt: Timestamp.fromMillis(baseMillis + 5000),
        createdAt: Timestamp.fromMillis(baseMillis + 1000),
      }),
    ]);

    const firstPage = (await listMyClaimsRun!(
      buildRequest({
        uid,
        email: "history@example.com",
        data: { limit: 2 },
      })
    )) as {
      claims: Array<{ claimId: string }>;
      nextCursor: { updatedAtMillis: number; claimId: string } | null;
    };

    assert.equal(firstPage.claims.length, 2);
    assert.deepEqual(
      firstPage.claims.map((item) => item.claimId),
      ["claim-history-001", "claim-history-002"]
    );
    assert.ok(firstPage.nextCursor);

    const secondPage = (await listMyClaimsRun!(
      buildRequest({
        uid,
        email: "history@example.com",
        data: {
          limit: 2,
          cursorUpdatedAtMillis: firstPage.nextCursor!.updatedAtMillis,
          cursorClaimId: firstPage.nextCursor!.claimId,
        },
      })
    )) as {
      claims: Array<{ claimId: string }>;
      nextCursor: { updatedAtMillis: number; claimId: string } | null;
    };

    assert.equal(secondPage.claims.length, 1);
    assert.deepEqual(secondPage.claims.map((item) => item.claimId), [
      "claim-history-003",
    ]);
    assert.equal(secondPage.nextCursor, null);
  });

  test("cola admin de claims rechaza usuarios no admin", async () => {
    assert.ok(listReviewQueueRun);
    await assert.rejects(
      async () =>
        listReviewQueueRun!(
          buildRequest({
            uid: "user-no-admin",
            email: "user@example.com",
            role: "customer",
            data: {
              provinceName: "Buenos Aires",
              departmentName: "Ezeiza",
              zoneId: "zone-review-1",
              limit: 5,
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "permission-denied");
        return true;
      }
    );
  });

  test("detalle admin entrega masking, timeline y capabilities", async () => {
    assert.ok(getReviewDetailRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-detail-01";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Farmacia Centro",
      categoryId: "pharmacy",
      zoneId: "zone-detail-1",
      address: "Av. Principal 123",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "claimed",
      ownerUserId: "owner-existing-01",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("merchant_claims").doc(claimId).set({
      claimId,
      merchantId,
      merchantName: "Farmacia Centro",
      userId: "user-detail-1",
      zoneId: "zone-detail-1",
      categoryId: "pharmacy",
      claimStatus: "under_review",
      userVisibleStatus: "under_review",
      internalWorkflowStatus: "auto_validation_passed",
      authenticatedEmail: "owner.detail@example.com",
      phoneMasked: "+5***78",
      claimantDisplayNameMasked: "J***z",
      claimantNoteMasked: "D***o",
      autoValidationReasons: ["sensitive_category_requires_manual_review"],
      hasConflict: false,
      hasDuplicate: false,
      requiresManualReview: true,
      evidenceFiles: [
        {
          id: "storefront_1",
          kind: "storefront_photo",
          contentType: "image/jpeg",
          sizeBytes: 1024,
          uploadedAt: Timestamp.fromMillis(1_710_000_000_000),
          originalFileName: "fachada.jpg",
        },
      ],
      createdAt: Timestamp.fromMillis(1_710_000_000_000),
      submittedAt: Timestamp.fromMillis(1_710_000_100_000),
      autoValidationCompletedAt: Timestamp.fromMillis(1_710_000_200_000),
      updatedAt: Timestamp.fromMillis(1_710_000_300_000),
      lastStatusAt: Timestamp.fromMillis(1_710_000_300_000),
    });

    const response = (await getReviewDetailRun!(
      buildRequest({
        uid: "admin-detail",
        email: "admin@example.com",
        role: "admin",
        data: { claimId },
      })
    )) as {
      claim: { authenticatedEmailMasked: string; userIdMasked: string };
      capabilities: { canRevealSensitive: boolean; canResolveCritical: boolean };
      timeline: Array<{ code: string }>;
    };

    assert.equal(response.claim.authenticatedEmailMasked, "o***l@example.com");
    assert.equal(response.claim.userIdMasked, "****il-1");
    assert.equal(response.capabilities.canRevealSensitive, true);
    assert.equal(response.capabilities.canResolveCritical, true);
    assert.deepEqual(
      response.timeline.map((entry) => entry.code),
      ["created", "submitted", "auto_validation_completed", "status_change"]
    );
  });

  test("resolve rechaza stale decision token", async () => {
    assert.ok(resolveClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-stale-01";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Kiosco Token",
      categoryId: "kiosk",
      zoneId: "zone-stale-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("merchant_claims").doc(claimId).set({
      claimId,
      merchantId,
      merchantName: "Kiosco Token",
      userId: "user-stale-1",
      zoneId: "zone-stale-1",
      categoryId: "kiosk",
      claimStatus: "under_review",
      userVisibleStatus: "under_review",
      updatedAt: Timestamp.fromMillis(1_710_000_300_000),
      createdAt: Timestamp.fromMillis(1_710_000_100_000),
    });

    await assert.rejects(
      async () =>
        resolveClaimRun!(
          buildRequest({
            uid: "admin-stale",
            email: "admin@example.com",
            role: "admin",
            data: {
              claimId,
              userVisibleStatus: "rejected",
              expectedUpdatedAtMillis: 1_710_000_200_000,
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: { code?: string } };
        assert.equal(err.code, "failed-precondition");
        assert.equal(err.details?.code, "stale_claim");
        return true;
      }
    );
  });

  test("reviewer no puede aprobar claims", async () => {
    assert.ok(resolveClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-reviewer-approve-01";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Comercio Reviewer",
      categoryId: "kiosk",
      zoneId: "zone-reviewer-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("merchant_claims").doc(claimId).set({
      claimId,
      merchantId,
      userId: "user-reviewer-approve",
      zoneId: "zone-reviewer-1",
      categoryId: "kiosk",
      claimStatus: "under_review",
      userVisibleStatus: "under_review",
      updatedAt: Timestamp.fromMillis(1_710_000_300_000),
      createdAt: Timestamp.fromMillis(1_710_000_100_000),
    });

    await assert.rejects(
      async () =>
        resolveClaimRun!(
          buildRequest({
            uid: "admin-reviewer-approve",
            email: "reviewer-approve@example.com",
            role: "admin",
            tokenExtras: { claimsReviewLevel: "reviewer" },
            data: {
              claimId,
              userVisibleStatus: "approved",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "permission-denied");
        return true;
      }
    );
  });

  test("senior reviewer no puede aprobar claims conflictivos", async () => {
    assert.ok(resolveClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-senior-conflict-01";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Comercio Senior",
      categoryId: "kiosk",
      zoneId: "zone-senior-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "claimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("merchant_claims").doc(claimId).set({
      claimId,
      merchantId,
      userId: "user-senior-approve",
      zoneId: "zone-senior-1",
      categoryId: "kiosk",
      claimStatus: "conflict_detected",
      userVisibleStatus: "conflict_detected",
      hasConflict: true,
      updatedAt: Timestamp.fromMillis(1_710_000_300_000),
      createdAt: Timestamp.fromMillis(1_710_000_100_000),
    });

    await assert.rejects(
      async () =>
        resolveClaimRun!(
          buildRequest({
            uid: "admin-senior-approve",
            email: "senior-approve@example.com",
            role: "admin",
            tokenExtras: { claimsReviewLevel: "senior_reviewer" },
            data: {
              claimId,
              userVisibleStatus: "approved",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "permission-denied");
        return true;
      }
    );
  });

  test("senior reviewer puede aprobar caso simple sin riesgo alto", async () => {
    assert.ok(resolveClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-senior-simple-01";
    const ownerUid = "user-senior-simple";
    await firestore.collection("merchants").doc(merchantId).set({
      name: "Comercio Simple Senior",
      categoryId: "kiosk",
      zoneId: "zone-senior-2",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("merchant_claims").doc(claimId).set({
      claimId,
      merchantId,
      userId: ownerUid,
      zoneId: "zone-senior-2",
      categoryId: "kiosk",
      claimStatus: "under_review",
      userVisibleStatus: "under_review",
      hasConflict: false,
      hasDuplicate: false,
      riskPriority: "medium",
      updatedAt: Timestamp.fromMillis(1_710_000_300_000),
      createdAt: Timestamp.fromMillis(1_710_000_100_000),
    });

    const response = (await resolveClaimRun!(
      buildRequest({
        uid: "admin-senior-simple",
        email: "senior-simple@example.com",
        role: "admin",
        tokenExtras: { claimsReviewLevel: "senior_reviewer" },
        data: {
          claimId,
          userVisibleStatus: "approved",
          reviewReasonCode: "manual_ok",
        },
      })
    )) as { claimStatus?: string };
    assert.equal(response.claimStatus, "approved");
  });

  test("reveal sensible exige capability senior cuando viene explicitada", async () => {
    assert.ok(upsertDraftRun && revealSensitiveRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-reveal-cap-01";
    const uid = "user-reveal-cap-1";

    await firestore.collection("merchants").doc(merchantId).set({
      name: "Veterinaria Cap",
      categoryId: "veterinary",
      zoneId: "zone-cap-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "cap@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          phone: "+54 9 11 1111 1111",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [],
        },
      })
    );

    await assert.rejects(
      async () =>
        revealSensitiveRun!(
          buildRequest({
            uid: "admin-reviewer",
            email: "reviewer@example.com",
            role: "admin",
            tokenExtras: {
              claimsReviewLevel: "reviewer",
              capabilities: ["claims.review", "claims.resolve_standard"],
            },
            data: {
              claimId,
              reasonCode: "verify_identity",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "permission-denied");
        return true;
      }
    );
  });

  test("upsert draft rechaza categoría fuera de allowlist MVP", async () => {
    assert.ok(upsertDraftRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;

    await firestore.collection("merchants").doc(merchantId).set({
      name: "Panadería Legacy",
      categoryId: "panaderia",
      zoneId: "zone-legacy-1",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await assert.rejects(
      async () =>
        upsertDraftRun!(
          buildRequest({
            uid: "user-legacy-1",
            email: "legacy@example.com",
            data: {
              claimId: "claim-legacy-cat-01",
              merchantId,
              declaredRole: "owner",
              hasAcceptedDataProcessingConsent: true,
              hasAcceptedLegitimacyDeclaration: true,
              evidenceFiles: [],
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: { code?: string } };
        assert.equal(err.code, "failed-precondition");
        assert.equal(err.details?.code, "claim_category_not_allowed");
        return true;
      }
    );
  });

  test("submit rechaza stale token cuando otro dispositivo actualizó el draft", async () => {
    assert.ok(upsertDraftRun && submitClaimRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-stale-submit-01";
    const uid = "user-stale-submit";

    await firestore.collection("merchants").doc(merchantId).set({
      name: "Kiosco Stale",
      categoryId: "kiosk",
      zoneId: "zone-stale-submit",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const firstDraft = (await upsertDraftRun!(
      buildRequest({
        uid,
        email: "stale@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [
            {
              id: "store_1",
              kind: "storefront_photo",
              storagePath:
                `merchant-claims/${uid}/${claimId}/storefront_photo/front.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 1024,
            },
          ],
        },
      })
    )) as { updatedAtMillis?: number | null };

    const tokenA = firstDraft.updatedAtMillis ?? null;
    assert.ok(tokenA != null);

    await upsertDraftRun!(
      buildRequest({
        uid,
        email: "stale@example.com",
        data: {
          claimId,
          expectedUpdatedAtMillis: tokenA,
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [
            {
              id: "store_1",
              kind: "storefront_photo",
              storagePath:
                `merchant-claims/${uid}/${claimId}/storefront_photo/front.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 1024,
            },
            {
              id: "doc_1",
              kind: "ownership_document",
              storagePath:
                `merchant-claims/${uid}/${claimId}/ownership_document/doc.jpg`,
              contentType: "image/jpeg",
              sizeBytes: 1024,
            },
          ],
        },
      })
    );

    await assert.rejects(
      async () =>
        submitClaimRun!(
          buildRequest({
            uid,
            email: "stale@example.com",
            data: { claimId, expectedUpdatedAtMillis: tokenA },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: { code?: string } };
        assert.equal(err.code, "failed-precondition");
        assert.equal(err.details?.code, "stale_claim");
        return true;
      }
    );
  });

  test("upsert draft rechaza stale token en edición concurrente multi-dispositivo", async () => {
    assert.ok(upsertDraftRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const claimId = "claim-stale-upsert-01";
    const uid = "user-stale-upsert";

    await firestore.collection("merchants").doc(merchantId).set({
      name: "Almacén Concurrencia",
      categoryId: "almacen",
      zoneId: "zone-stale-upsert",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const draftA = (await upsertDraftRun!(
      buildRequest({
        uid,
        email: "stale-upsert@example.com",
        data: {
          claimId,
          merchantId,
          declaredRole: "owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [],
        },
      })
    )) as { updatedAtMillis?: number | null };
    const tokenA = draftA.updatedAtMillis ?? null;
    assert.ok(tokenA != null);

    const draftB = (await upsertDraftRun!(
      buildRequest({
        uid,
        email: "stale-upsert@example.com",
        data: {
          claimId,
          expectedUpdatedAtMillis: tokenA,
          merchantId,
          declaredRole: "co_owner",
          hasAcceptedDataProcessingConsent: true,
          hasAcceptedLegitimacyDeclaration: true,
          evidenceFiles: [],
        },
      })
    )) as { updatedAtMillis?: number | null };

    const tokenB = draftB.updatedAtMillis ?? null;
    assert.ok(tokenB != null);
    assert.notEqual(tokenB, tokenA);

    await assert.rejects(
      async () =>
        upsertDraftRun!(
          buildRequest({
            uid,
            email: "stale-upsert@example.com",
            data: {
              claimId,
              expectedUpdatedAtMillis: tokenA,
              merchantId,
              declaredRole: "owner",
              hasAcceptedDataProcessingConsent: true,
              hasAcceptedLegitimacyDeclaration: true,
              evidenceFiles: [],
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: { code?: string } };
        assert.equal(err.code, "failed-precondition");
        assert.equal(err.details?.code, "stale_claim");
        return true;
      }
    );
  });
}
