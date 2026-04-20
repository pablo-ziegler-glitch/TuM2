import assert from "node:assert/strict";
import test, { before, beforeEach } from "node:test";
import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import {
  runMerchantClaimAutoValidation,
  shouldRunAutoValidationFromTransition,
} from "../merchantClaimAutoValidationService";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

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
  test("merchant claim auto-validation integration requires FIRESTORE_EMULATOR_HOST", { skip: true }, () => {
    assert.ok(true);
  });
} else {
  before(async () => {
    process.env.GCLOUD_PROJECT ??= "tum2-dev-6283d";
    if (getApps().length === 0) {
      initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    }
  });

  beforeEach(async () => {
    await Promise.all([
      deleteCollection("merchant_claims"),
      deleteCollection("merchant_claim_private"),
      deleteCollection("merchant_public"),
      deleteCollection("merchants"),
      deleteCollection("users"),
    ]);
  });

  test("transición real a submitted + reintento idempotente sin writes redundantes", async () => {
    const firestore = getFirestore();
    const claimId = `claim-${randomUUID()}`;
    const merchantId = `merchant-${randomUUID()}`;
    const userId = `user-${randomUUID()}`;

    await firestore.doc(`users/${userId}`).set({
      role: "customer",
      status: "active",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.doc(`merchants/${merchantId}`).set({
      name: "Kiosco Mitre",
      categoryId: "kiosk",
      zoneId: "zone-z",
      status: "active",
      visibilityStatus: "visible",
      ownershipStatus: "unclaimed",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await firestore.doc(`merchant_claims/${claimId}`).set({
      claimId,
      userId,
      merchantId,
      categoryId: "kiosk",
      zoneId: "zone-z",
      authenticatedEmail: "owner@example.com",
      declaredRole: "owner",
      hasAcceptedDataProcessingConsent: true,
      hasAcceptedLegitimacyDeclaration: true,
      claimStatus: "draft",
      userVisibleStatus: "draft",
      evidenceFiles: [
        { id: "store", kind: "storefront_photo" },
        { id: "doc", kind: "ownership_document" },
      ],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    await firestore.doc(`merchant_claim_private/${claimId}`).set({
      claimId,
      userId,
      merchantId,
      fingerprintPrimary: "fp-001",
      sensitiveVault: {
        keyVersion: "v1",
        fingerprintPrimary: "fp-001",
      },
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    const beforeTransition = shouldRunAutoValidationFromTransition({
      beforeStatus: "draft",
      afterStatus: "submitted",
    });
    assert.equal(beforeTransition, true);

    await firestore.doc(`merchant_claims/${claimId}`).set(
      {
        claimStatus: "submitted",
        userVisibleStatus: "submitted",
        internalWorkflowStatus: "auto_validation_running",
        updatedAt: FieldValue.serverTimestamp(),
        submittedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const firstRun = await runMerchantClaimAutoValidation({
      claimId,
      origin: "submitted_trigger",
    });
    assert.ok(firstRun);
    assert.equal(firstRun?.didChange, true);
    assert.equal(firstRun?.nextStatus, "under_review");

    const firstDoc = await firestore.doc(`merchant_claims/${claimId}`).get();
    const updatedAtFirst = (firstDoc.get("updatedAt") as Timestamp).toMillis();
    const hashFirst = firstDoc.get("lastAutoValidationHash");
    assert.equal(firstDoc.get("claimStatus"), "under_review");
    assert.equal(firstDoc.get("processedBySystem"), true);

    const secondRun = await runMerchantClaimAutoValidation({
      claimId,
      origin: "submitted_trigger",
      force: true,
    });
    assert.ok(secondRun);
    assert.equal(secondRun?.didChange, false);
    assert.equal(secondRun?.noOp, true);

    const secondDoc = await firestore.doc(`merchant_claims/${claimId}`).get();
    const updatedAtSecond = (secondDoc.get("updatedAt") as Timestamp).toMillis();
    const hashSecond = secondDoc.get("lastAutoValidationHash");
    assert.equal(updatedAtFirst, updatedAtSecond);
    assert.equal(hashFirst, hashSecond);

    const merchantPublic = await firestore.doc(`merchant_public/${merchantId}`).get();
    assert.equal(merchantPublic.exists, false);
    const userDoc = await firestore.doc(`users/${userId}`).get();
    assert.notEqual(userDoc.get("role"), "owner");
  });
}
