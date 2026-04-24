import { readFileSync } from "node:fs";
import path from "node:path";
import { after, before, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from "firebase/firestore";

let testEnv: RulesTestEnvironment;

before(async () => {
  const rulesPath = path.resolve(process.cwd(), "../firestore.rules");
  testEnv = await initializeTestEnvironment({
    projectId: `tum2-rules-claims-matrix-${Date.now()}`,
    firestore: { rules: readFileSync(rulesPath, "utf8") },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/owner-1"), {
      role: "owner",
      ownerPending: false,
      accessVersion: 3,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "users/customer-1"), {
      role: "customer",
      ownerPending: false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    await setDoc(doc(db, "merchants/m-owner"), {
      ownerUserId: "owner-1",
      status: "active",
      visibilityStatus: "visible",
      verificationStatus: "claimed",
      sourceType: "owner_created",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "merchants/m-other"), {
      ownerUserId: "owner-2",
      status: "active",
      visibilityStatus: "visible",
      verificationStatus: "claimed",
      sourceType: "owner_created",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "merchant_public/m-owner"), {
      merchantId: "m-owner",
      status: "active",
      visibilityStatus: "visible",
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "merchant_schedules/m-owner"), {
      merchantId: "m-owner",
      timezone: "America/Argentina/Buenos_Aires",
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "merchant_operational_signals/m-owner"), {
      merchantId: "m-owner",
      ownerUserId: "owner-1",
      signalType: "none",
      isActive: false,
      message: null,
      forceClosed: false,
      updatedAt: Timestamp.now(),
      updatedByUid: "owner-1",
      createdAt: Timestamp.now(),
      schemaVersion: 1,
    });
    await setDoc(doc(db, "merchant_products/p-1"), {
      id: "p-1",
      merchantId: "m-owner",
      ownerUserId: "owner-1",
      name: "Ibuprofeno",
      normalizedName: "ibuprofeno",
      priceLabel: "$1000",
      stockStatus: "available",
      visibilityStatus: "visible",
      status: "active",
      sourceType: "owner_created",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      createdBy: "owner-1",
      updatedBy: "owner-1",
    });
    await setDoc(doc(db, "merchant_claims/claim-1"), {
      claimId: "claim-1",
      userId: "owner-1",
      merchantId: "m-owner",
      claimStatus: "under_review",
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "reports/report-1"), {
      reportedBy: "customer-1",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "admin_configs/pharmacy_duty_rules"), {
      maxCandidatesPerRound: 5,
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "pharmacy_duties/d-1"), {
      merchantId: "m-owner",
      status: "scheduled",
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "external_places/e-1"), {
      placeId: "e-1",
      zoneId: "z-1",
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "import_batches/b-1"), {
      zoneId: "z-1",
      createdAt: Timestamp.now(),
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("anónimo y customer no escalan permisos administrativos", async () => {
  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anonDb, "merchant_public/m-owner")));
  await assertFails(getDoc(doc(anonDb, "users/owner-1")));
  await assertFails(getDoc(doc(anonDb, "admin_configs/pharmacy_duty_rules")));
  await assertFails(getDoc(doc(anonDb, "external_places/e-1")));
  await assertFails(setDoc(doc(anonDb, "reports/r-anon"), {
    reportedBy: "anon",
    createdAt: Timestamp.now(),
  }));

  const customerDb = testEnv.authenticatedContext("customer-1", {
    role: "customer",
    owner_pending: false,
  }).firestore();
  await assertFails(getDoc(doc(customerDb, "admin_configs/pharmacy_duty_rules")));
  await assertFails(getDoc(doc(customerDb, "merchant_claims/claim-1")));
  await assertFails(setDoc(doc(customerDb, "merchant_schedules/m-owner"), {
    merchantId: "m-owner",
    updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(setDoc(doc(customerDb, "reports/r-ok"), {
    reportedBy: "customer-1",
    createdAt: Timestamp.now(),
  }));
  await assertFails(setDoc(doc(customerDb, "reports/r-bad"), {
    reportedBy: "other-user",
    createdAt: Timestamp.now(),
  }));
});

test("owner_pending no obtiene acceso owner pleno", async () => {
  const pendingDb = testEnv.authenticatedContext("owner-1", {
    role: "customer",
    owner_pending: true,
  }).firestore();

  await assertFails(setDoc(doc(pendingDb, "merchant_schedules/m-owner"), {
    merchantId: "m-owner",
    updatedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(pendingDb, "merchant_operational_signals/m-owner"), {
    signalType: "delay",
    isActive: true,
    forceClosed: false,
    updatedAt: Timestamp.now(),
    updatedByUid: "owner-1",
  }));
});

test("owner opera sólo recursos de su comercio", async () => {
  const ownerDb = testEnv.authenticatedContext("owner-1", {
    role: "owner",
    owner_pending: false,
  }).firestore();

  await assertSucceeds(setDoc(doc(ownerDb, "merchant_schedules/m-owner"), {
    merchantId: "m-owner",
    updatedAt: Timestamp.now(),
    timezone: "America/Argentina/Buenos_Aires",
  }));
  await assertFails(setDoc(doc(ownerDb, "merchant_schedules/m-other"), {
    merchantId: "m-other",
    updatedAt: Timestamp.now(),
  }));
  await assertFails(setDoc(doc(ownerDb, "merchant_public/m-owner"), {
    merchantId: "m-owner",
    visibilityStatus: "visible",
  }));
  await assertSucceeds(getDoc(doc(ownerDb, "pharmacy_duties/d-1")));
});

test("admin y super_admin tienen lectura admin-only; sólo super_admin escribe admin_configs", async () => {
  const adminDb = testEnv.authenticatedContext("admin-1", {
    role: "admin",
    admin: true,
  }).firestore();
  await assertSucceeds(getDoc(doc(adminDb, "merchant_claims/claim-1")));
  await assertSucceeds(getDoc(doc(adminDb, "admin_configs/pharmacy_duty_rules")));
  await assertSucceeds(getDoc(doc(adminDb, "external_places/e-1")));
  await assertSucceeds(getDoc(doc(adminDb, "import_batches/b-1")));
  await assertFails(updateDoc(doc(adminDb, "admin_configs/pharmacy_duty_rules"), {
    maxCandidatesPerRound: 7,
  }));

  const superAdminDb = testEnv.authenticatedContext("super-1", {
    role: "super_admin",
    admin: true,
    super_admin: true,
  }).firestore();
  await assertSucceeds(updateDoc(doc(superAdminDb, "admin_configs/pharmacy_duty_rules"), {
    maxCandidatesPerRound: 9,
  }));
});
