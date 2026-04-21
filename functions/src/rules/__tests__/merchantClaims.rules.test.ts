import { readFileSync } from "node:fs";
import path from "node:path";
import { after, before, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { Timestamp, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

let testEnv: RulesTestEnvironment;

before(async () => {
  const rulesPath = path.resolve(process.cwd(), "../firestore.rules");
  testEnv = await initializeTestEnvironment({
    projectId: `tum2-rules-claims-${Date.now()}`,
    firestore: { rules: readFileSync(rulesPath, "utf8") },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchant_claims/claim-owner-1"), {
      claimId: "claim-owner-1",
      merchantId: "merchant-1",
      userId: "owner-1",
      claimStatus: "under_review",
      categoryId: "pharmacy",
      zoneId: "zone-1",
      authenticatedEmail: "owner1@example.com",
      declaredRole: "owner",
      hasAcceptedDataProcessingConsent: true,
      hasAcceptedLegitimacyDeclaration: true,
      storefrontPhotoUploaded: true,
      ownershipDocumentUploaded: true,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("usuario autenticado no puede leer claims por acceso directo", async () => {
  const ctx = testEnv.authenticatedContext("owner-1", { role: "customer" });
  const db = ctx.firestore();

  await assertFails(getDoc(doc(db, "merchant_claims/claim-owner-1")));
});

test("usuario autenticado no puede leer claims ajenos", async () => {
  const ctx = testEnv.authenticatedContext("owner-2", { role: "customer" });
  const db = ctx.firestore();

  await assertFails(getDoc(doc(db, "merchant_claims/claim-owner-1")));
});

test("usuario autenticado no puede crear ni actualizar claims por cliente", async () => {
  const ctx = testEnv.authenticatedContext("owner-1", { role: "customer" });
  const db = ctx.firestore();

  await assertFails(
    setDoc(doc(db, "merchant_claims/claim-owner-2"), {
      claimId: "claim-owner-2",
      userId: "owner-1",
      merchantId: "merchant-2",
      claimStatus: "approved",
      updatedAt: Timestamp.now(),
    })
  );

  await assertFails(
    updateDoc(doc(db, "merchant_claims/claim-owner-1"), {
      claimStatus: "approved",
    })
  );
});

test("admin puede leer claims pero no escribirlos por cliente", async () => {
  const ctx = testEnv.authenticatedContext("admin-1", { role: "admin" });
  const db = ctx.firestore();

  const ref = doc(db, "merchant_claims/claim-owner-1");
  await assertSucceeds(getDoc(ref));
  await assertFails(
    updateDoc(ref, {
      claimStatus: "needs_more_info",
      reviewNotes: "Falta evidencia legible",
    })
  );
});

test("ningún cliente (incluyendo admin) puede leer claim private", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchant_claim_private/claim-owner-1"), {
      claimId: "claim-owner-1",
      userId: "owner-1",
      merchantId: "merchant-1",
      sensitiveVault: {
        keyVersion: "v1",
        phoneCiphertext: "x.y.z",
        phoneFingerprint: "abc",
      },
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });

  const ownerCtx = testEnv.authenticatedContext("owner-1", { role: "customer" });
  await assertFails(
    getDoc(doc(ownerCtx.firestore(), "merchant_claim_private/claim-owner-1"))
  );

  const adminCtx = testEnv.authenticatedContext("admin-1", { role: "admin" });
  await assertFails(
    getDoc(doc(adminCtx.firestore(), "merchant_claim_private/claim-owner-1"))
  );
});

test("auditorías sensibles quedan cerradas para lectura/escritura cliente", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchant_claim_sensitive_reveals/reveal-1"), {
      claimId: "claim-owner-1",
      actorUid: "admin-1",
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "merchant_claim_attachment_access_logs/log-1"), {
      claimId: "claim-owner-1",
      attachmentId: "evidence-1",
      actorUid: "admin-1",
      createdAt: Timestamp.now(),
    });
  });

  const adminCtx = testEnv.authenticatedContext("admin-1", { role: "admin" });
  await assertFails(
    getDoc(
      doc(adminCtx.firestore(), "merchant_claim_sensitive_reveals/reveal-1")
    )
  );
  await assertFails(
    getDoc(
      doc(adminCtx.firestore(), "merchant_claim_attachment_access_logs/log-1")
    )
  );
  await assertFails(
    setDoc(doc(adminCtx.firestore(), "merchant_claim_sensitive_reveals/reveal-2"), {
      claimId: "claim-owner-1",
      actorUid: "admin-1",
      createdAt: Timestamp.now(),
    })
  );
});
