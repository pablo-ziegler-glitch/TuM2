import assert from "node:assert/strict";
import test, { before, beforeEach } from "node:test";
import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

let upsertPharmacyDutyRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;

function buildOwnerRequest(params: {
  uid: string;
  merchantId: string;
  data: Record<string, unknown>;
}): Record<string, unknown> {
  return {
    data: params.data,
    auth: {
      uid: params.uid,
      token: {
        role: "owner",
        merchantId: params.merchantId,
      },
    },
    rawRequest: {
      headers: {},
    },
  };
}

async function deleteCollection(collectionName: string): Promise<void> {
  const firestore = getFirestore();
  while (true) {
    const snapshot = await firestore.collection(collectionName).limit(200).get();
    if (snapshot.empty) return;
    const batch = firestore.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

if (!emulatorHost) {
  test("pharmacy duties integration requires FIRESTORE_EMULATOR_HOST", { skip: true }, () => {
    assert.ok(true);
  });
} else {
  before(async () => {
    process.env.GCLOUD_PROJECT ??= "tum2-dev-6283d";
    process.env.PHARMACY_DUTY_MUTATION_RATE_LIMIT_WINDOW_MS = "60000";
    process.env.PHARMACY_DUTY_MUTATION_RATE_LIMIT_MAX = "2";
    if (getApps().length === 0) {
      initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    }

    const callables = await import("../pharmacyDuties");
    upsertPharmacyDutyRun = (
      callables.upsertPharmacyDuty as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
  });

  beforeEach(async () => {
    await Promise.all([
      deleteCollection("pharmacy_duties"),
      deleteCollection("merchants"),
      deleteCollection("pharmacy_duty_mutation_rate_limits"),
    ]);
  });

  test("upsertPharmacyDuty rechaza owner que no controla el comercio", async () => {
    assert.ok(upsertPharmacyDutyRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      ownerUserId: "owner-real",
      categoryId: "pharmacy",
      zoneId: "zone-1",
      status: "active",
      name: "Farmacia Test",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await assert.rejects(
      async () =>
        upsertPharmacyDutyRun!(
          buildOwnerRequest({
            uid: "owner-other",
            merchantId,
            data: {
              merchantId,
              date: "2099-01-15",
              startsAt: "2099-01-15T08:00:00.000Z",
              endsAt: "2099-01-15T12:00:00.000Z",
              status: "scheduled",
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

  test("upsertPharmacyDuty detecta conflicto de horario", async () => {
    assert.ok(upsertPharmacyDutyRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const ownerUid = `owner-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      ownerUserId: ownerUid,
      categoryId: "pharmacy",
      zoneId: "zone-1",
      status: "active",
      name: "Farmacia Conflicto",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await firestore.collection("pharmacy_duties").doc(`seed-${randomUUID()}`).set({
      merchantId,
      zoneId: "zone-1",
      date: "2099-01-15",
      startsAt: "2099-01-15T08:00:00.000Z",
      endsAt: "2099-01-15T12:00:00.000Z",
      status: "scheduled",
      sourceType: "owner_created",
      createdBy: ownerUid,
      updatedBy: ownerUid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await assert.rejects(
      async () =>
        upsertPharmacyDutyRun!(
          buildOwnerRequest({
            uid: ownerUid,
            merchantId,
            data: {
              merchantId,
              date: "2099-01-15",
              startsAt: "2099-01-15T10:00:00.000Z",
              endsAt: "2099-01-15T14:00:00.000Z",
              status: "scheduled",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: Record<string, unknown> };
        assert.equal(err.code, "already-exists");
        assert.equal(err.details?.code, "duty_conflict");
        return true;
      }
    );
  });

  test("upsertPharmacyDuty aplica rate limit por uid+merchantId", async () => {
    assert.ok(upsertPharmacyDutyRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    const ownerUid = `owner-${randomUUID()}`;
    await firestore.collection("merchants").doc(merchantId).set({
      ownerUserId: ownerUid,
      categoryId: "pharmacy",
      zoneId: "zone-1",
      status: "active",
      name: "Farmacia Rate Limit",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await upsertPharmacyDutyRun!(
      buildOwnerRequest({
        uid: ownerUid,
        merchantId,
        data: {
          merchantId,
          date: "2099-01-16",
          startsAt: "2099-01-16T08:00:00.000Z",
          endsAt: "2099-01-16T10:00:00.000Z",
          status: "scheduled",
        },
      })
    );
    await upsertPharmacyDutyRun!(
      buildOwnerRequest({
        uid: ownerUid,
        merchantId,
        data: {
          merchantId,
          date: "2099-01-16",
          startsAt: "2099-01-16T10:30:00.000Z",
          endsAt: "2099-01-16T12:00:00.000Z",
          status: "scheduled",
        },
      })
    );

    await assert.rejects(
      async () =>
        upsertPharmacyDutyRun!(
          buildOwnerRequest({
            uid: ownerUid,
            merchantId,
            data: {
              merchantId,
              date: "2099-01-16",
              startsAt: "2099-01-16T12:30:00.000Z",
              endsAt: "2099-01-16T14:00:00.000Z",
              status: "scheduled",
            },
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: Record<string, unknown> };
        assert.equal(err.code, "resource-exhausted");
        assert.equal(err.details?.code, "rate_limited");
        return true;
      }
    );
  });
}
