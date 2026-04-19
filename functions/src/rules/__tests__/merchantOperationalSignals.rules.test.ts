import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { after, before, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { Timestamp, doc, getDoc, setDoc } from "firebase/firestore";

let testEnv: RulesTestEnvironment;

const ownerSignalPayload = {
  merchantId: "m1",
  ownerUserId: "owner-1",
  signalType: "vacation",
  isActive: true,
  message: "Cerrado por vacaciones",
  forceClosed: true,
  updatedAt: Timestamp.now(),
  updatedByUid: "owner-1",
  schemaVersion: 1,
};

before(async () => {
  const rulesPath = path.resolve(process.cwd(), "../firestore.rules");
  testEnv = await initializeTestEnvironment({
    projectId: `tum2-rules-${Date.now()}`,
    firestore: {
      rules: readFileSync(rulesPath, "utf8"),
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchants/m1"), {
      ownerUserId: "owner-1",
      status: "active",
      visibilityStatus: "visible",
      verificationStatus: "unverified",
      sourceType: "owner_created",
    });
    await setDoc(doc(db, "merchants/m2"), {
      ownerUserId: "owner-2",
      status: "active",
      visibilityStatus: "visible",
      verificationStatus: "unverified",
      sourceType: "owner_created",
    });
    await setDoc(doc(db, "merchant_public/m1"), {
      merchantId: "m1",
      name: "Farmacia Central",
      visibilityStatus: "visible",
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("owner real puede crear y leer su señal operativa", async () => {
  const ctx = testEnv.authenticatedContext("owner-1", {
    role: "owner",
    merchantId: "m1",
  });
  const db = ctx.firestore();
  const signalRef = doc(db, "merchant_operational_signals/m1");

  await assertSucceeds(setDoc(signalRef, ownerSignalPayload));
  const snapshot = await assertSucceeds(getDoc(signalRef));
  assert.equal(snapshot.exists(), true);
});

test("owner de otro comercio no puede escribir señal ajena", async () => {
  const ctx = testEnv.authenticatedContext("owner-1", {
    role: "owner",
    merchantId: "m1",
  });
  const db = ctx.firestore();
  const signalRef = doc(db, "merchant_operational_signals/m2");

  await assertFails(
    setDoc(signalRef, {
      ...ownerSignalPayload,
      merchantId: "m2",
    })
  );
});

test("customer autenticado no puede leer ni escribir señales", async () => {
  const ctx = testEnv.authenticatedContext("customer-1", {
    role: "customer",
  });
  const db = ctx.firestore();
  const signalRef = doc(db, "merchant_operational_signals/m1");

  await assertFails(getDoc(signalRef));
  await assertFails(
    setDoc(signalRef, {
      ...ownerSignalPayload,
      updatedByUid: "customer-1",
      ownerUserId: "customer-1",
    })
  );
});

test("anónimo no puede leer ni escribir señales", async () => {
  const ctx = testEnv.unauthenticatedContext();
  const db = ctx.firestore();
  const signalRef = doc(db, "merchant_operational_signals/m1");

  await assertFails(getDoc(signalRef));
  await assertFails(setDoc(signalRef, ownerSignalPayload));
});

test("ningún cliente puede escribir merchant_public", async () => {
  const ctx = testEnv.authenticatedContext("owner-1", {
    role: "owner",
    merchantId: "m1",
  });
  const db = ctx.firestore();
  const publicRef = doc(db, "merchant_public/m1");

  await assertFails(
    setDoc(publicRef, {
      merchantId: "m1",
      visibilityStatus: "visible",
      isOpenNow: true,
    })
  );
});

