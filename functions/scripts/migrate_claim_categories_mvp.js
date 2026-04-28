#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

const DEFAULT_PAGE_SIZE = 400;
const BATCH_LIMIT = 450;
const CLAIM_ALLOWED_CATEGORY_IDS = new Set([
  "farmacia",
  "kiosco",
  "almacen",
  "veterinaria",
  "comida_al_paso",
  "casa_de_comidas",
  "gomeria",
  "panaderia",
  "confiteria",
]);

const CATEGORY_ALIASES = {
  farmacia: "farmacia",
  pharmacy: "farmacia",
  drugstore: "farmacia",
  kiosco: "kiosco",
  kiosk: "kiosco",
  grocery: "almacen",
  grocery_stores: "almacen",
  store: "almacen",
  veterinary: "veterinaria",
  veterinaria: "veterinaria",
  vet: "veterinaria",
  comida_al_paso: "comida_al_paso",
  fast_food: "comida_al_paso",
  food_on_the_go: "comida_al_paso",
  comida_rapida: "comida_al_paso",
  prepared_food: "casa_de_comidas",
  rotiseria: "casa_de_comidas",
  tire_shop: "gomeria",
  bakery: "panaderia",
  "panadería": "panaderia",
  confitería: "confiteria",
};

function parseArgs(argv) {
  const args = {
    project: process.env.GCLOUD_PROJECT || "",
    apply: false,
    pageSize: DEFAULT_PAGE_SIZE,
  };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--apply") {
      args.apply = true;
      continue;
    }
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Missing value for --${key}`);
    }
    i += 1;
    if (key === "project") args.project = value.trim();
    if (key === "page-size") {
      const parsed = Number(value);
      if (!Number.isFinite(parsed) || parsed < 1) {
        throw new Error("--page-size debe ser un entero positivo.");
      }
      args.pageSize = Math.min(1000, Math.floor(parsed));
    }
  }
  return args;
}

function normalizeClaimCategoryId(raw) {
  const normalized = String(raw || "").trim().toLowerCase();
  return CATEGORY_ALIASES[normalized] || normalized;
}

async function migrateMerchantClaims({ db, apply, pageSize }) {
  let cursor = null;
  let scanned = 0;
  let changed = 0;
  let unsupported = 0;
  let written = 0;
  let batch = db.batch();
  let batchOps = 0;

  while (true) {
    let query = db
      .collection("merchant_claims")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const current = String(data.categoryId || "").trim();
      const normalized = normalizeClaimCategoryId(current);
      const needsChange = normalized && normalized !== current;
      const isUnsupported = normalized && !CLAIM_ALLOWED_CATEGORY_IDS.has(normalized);
      if (isUnsupported) unsupported += 1;
      if (!needsChange) continue;
      changed += 1;
      if (!apply) continue;
      batch.set(
        doc.ref,
        {
          categoryId: normalized,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      batchOps += 1;
      written += 1;
      if (batchOps >= BATCH_LIMIT) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    }
    if (snap.size < pageSize) break;
    cursor = snap.docs[snap.docs.length - 1];
  }

  if (apply && batchOps > 0) {
    await batch.commit();
  }

  return { scanned, changed, unsupported, written };
}

async function main() {
  const args = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }
  const db = admin.firestore();
  const startedAt = Date.now();
  const summary = await migrateMerchantClaims({
    db,
    apply: args.apply,
    pageSize: args.pageSize,
  });
  console.log(
    JSON.stringify({
      migration: "claim_categories_mvp",
      mode: args.apply ? "apply" : "dry_run",
      ...summary,
      durationMs: Date.now() - startedAt,
    })
  );
  if (summary.unsupported > 0) {
    console.warn(
      `WARN: ${summary.unsupported} claims quedan fuera del allowlist MVP y requieren decisión manual.`
    );
  }
}

main().catch((error) => {
  console.error("[migrate_claim_categories_mvp] Failed:", error);
  process.exit(1);
});
