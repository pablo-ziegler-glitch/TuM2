#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

function parseArgs(argv) {
  const out = {
    project: process.env.GCLOUD_PROJECT || "",
    apply: false,
    limit: 0,
  };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--apply") {
      out.apply = true;
      continue;
    }
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Missing value for --${key}`);
    }
    i++;
    if (key === "project") out.project = value;
    if (key === "limit") out.limit = Number(value) || 0;
  }
  return out;
}

function normalizeToken(raw) {
  return String(raw || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function inferCategory(place) {
  const rawPayload = place.rawPayload || {};
  const candidates = [
    place.rawCategory,
    rawPayload.tipologia_sigla,
    rawPayload.tipologia_id,
    rawPayload.category,
    rawPayload.rubro,
    rawPayload.tipo,
  ]
    .map((v) => normalizeToken(v))
    .filter((v) => v.length > 0);

  for (const token of candidates) {
    if (
      token === "farmacia" ||
      token === "farmacias" ||
      token === "pharmacy" ||
      token === "drugstore" ||
      token === "70"
    ) {
      return "farmacia";
    }
  }
  return null;
}

async function main() {
  const args = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }
  const db = admin.firestore();

  const merchantsSnap = await db
    .collection("merchants")
    .where("category", "==", "comercio_general")
    .get();

  let candidates = merchantsSnap.docs.filter((doc) => {
    const data = doc.data() || {};
    return data.sourceType === "external_seed" && !!data.externalPlaceId;
  });

  if (args.limit > 0) {
    candidates = candidates.slice(0, args.limit);
  }

  const byRawCategory = new Map();
  const toFix = [];
  const chunkSize = 300;
  for (let i = 0; i < candidates.length; i += chunkSize) {
    const chunk = candidates.slice(i, i + chunkSize);
    const refs = chunk.map((doc) =>
      db.collection("external_places").doc(String(doc.data().externalPlaceId))
    );
    const placeDocs = await db.getAll(...refs);

    for (let j = 0; j < chunk.length; j++) {
      const merchantDoc = chunk[j];
      const placeDoc = placeDocs[j];
      if (!placeDoc.exists) continue;
      const place = placeDoc.data() || {};
      const raw = String(place.rawCategory || "").trim();
      byRawCategory.set(raw, (byRawCategory.get(raw) || 0) + 1);

      const normalized = inferCategory(place);
      if (normalized === "farmacia") {
        toFix.push({
          merchantRef: merchantDoc.ref,
          merchantId: merchantDoc.id,
          externalPlaceId: placeDoc.id,
        });
      }
    }
  }

  const topRaw = [...byRawCategory.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15);

  console.log("---- Audit resumen ----");
  console.log(`project: ${args.project || "(default credentials project)"}`);
  console.log(`merchants comercio_general: ${merchantsSnap.size}`);
  console.log(`candidatos external_seed+externalPlaceId: ${candidates.length}`);
  console.log(`detectados como farmacia para corregir: ${toFix.length}`);
  console.log("top rawCategory:", topRaw);

  if (!args.apply) {
    console.log(
      "\nDry-run. Ejecutar con --apply para actualizar category=farmacia en merchants."
    );
    return;
  }

  let updated = 0;
  for (let i = 0; i < toFix.length; i += 450) {
    const batch = db.batch();
    const slice = toFix.slice(i, i + 450);
    for (const item of slice) {
      batch.set(
        item.merchantRef,
        {
          category: "farmacia",
          isPharmacy: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    await batch.commit();
    updated += slice.length;
    console.log(`updated ${updated}/${toFix.length}`);
  }

  console.log("Done.");
}

main().catch((err) => {
  console.error("[audit_fix_farmacias_category] Failed:", err.message);
  process.exit(1);
});
