import { readFileSync } from "node:fs";
import path from "node:path";
import { after, before, test } from "node:test";
import {
  RulesTestEnvironment,
  assertFails,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { ref, getBytes, listAll } from "firebase/storage";
import { Timestamp, doc, setDoc } from "firebase/firestore";

let testEnv: RulesTestEnvironment;

before(async () => {
  const storageRulesPath = path.resolve(process.cwd(), "../storage.rules");
  testEnv = await initializeTestEnvironment({
    projectId: `tum2-storage-claims-${Date.now()}`,
    storage: {
      rules: readFileSync(storageRulesPath, "utf8"),
    },
    firestore: { rules: readFileSync(path.resolve(process.cwd(), "../firestore.rules"), "utf8") },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "merchant_claims/claim-storage-1"), {
      claimId: "claim-storage-1",
      merchantId: "merchant-1",
      userId: "owner-1",
      claimStatus: "under_review",
      zoneId: "zone-1",
      categoryId: "pharmacy",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("cliente no puede leer binario de attachment por storage directo", async () => {
  const owner = testEnv.authenticatedContext("owner-1", { role: "owner" });
  const ownerStorage = owner.storage();
  const fileRef = ref(
    ownerStorage,
    "merchant-claims/owner-1/claim-storage-1/storefront_photo/front.jpg"
  );
  await assertFails(getBytes(fileRef));
});

test("cliente no puede listar paths sensibles de attachments", async () => {
  const admin = testEnv.authenticatedContext("admin-1", { role: "admin" });
  const storage = admin.storage();
  const folderRef = ref(storage, "merchant-claims/owner-1/claim-storage-1");
  await assertFails(listAll(folderRef));
});
