#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

const DEFAULT_PAGE_SIZE = 400;
const SAMPLE_LIMIT = 40;

const CLAIM_ALLOWED_CATEGORY_IDS = new Set([
  "pharmacy",
  "kiosk",
  "almacen",
  "veterinary",
  "fast_food",
  "casa_de_comidas",
  "gomeria",
]);

const CATEGORY_ALIASES = {
  farmacia: "pharmacy",
  drugstore: "pharmacy",
  kiosco: "kiosk",
  grocery: "almacen",
  store: "almacen",
  veterinary: "veterinary",
  veterinaria: "veterinary",
  vet: "veterinary",
  comida_al_paso: "fast_food",
  comida_rapida: "fast_food",
  prepared_food: "casa_de_comidas",
  rotiseria: "casa_de_comidas",
  house_food: "casa_de_comidas",
  tire_shop: "gomeria",
  supermarket: "unsupported_non_mvp",
  supermercado: "unsupported_non_mvp",
  cafeteria: "unsupported_non_mvp",
  cafe: "unsupported_non_mvp",
  bakery: "unsupported_non_mvp",
  panaderia: "unsupported_non_mvp",
  "panadería": "unsupported_non_mvp",
  confiteria: "unsupported_non_mvp",
  "confitería": "unsupported_non_mvp",
  other: "unsupported_non_mvp",
  otro: "unsupported_non_mvp",
};

function parseArgs(argv) {
  const args = {
    project: process.env.GCLOUD_PROJECT || "",
    pageSize: DEFAULT_PAGE_SIZE,
  };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
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

function normalizeCategoryId(raw) {
  const normalized = String(raw || "").trim().toLowerCase();
  return CATEGORY_ALIASES[normalized] || normalized;
}

function readCategory(data) {
  const categoryId = typeof data.categoryId === "string" ? data.categoryId.trim() : "";
  if (categoryId) return categoryId;
  const category = typeof data.category === "string" ? data.category.trim() : "";
  return category;
}

function inc(map, key) {
  map[key] = (map[key] || 0) + 1;
}

async function auditCollection({ db, collectionName, pageSize }) {
  let cursor = null;
  let scanned = 0;
  let empty = 0;
  let normalizedChanges = 0;
  let unsupported = 0;
  const rawCounts = {};
  const normalizedCounts = {};
  const unsupportedSamples = [];

  while (true) {
    let query = db
      .collection(collectionName)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const rawCategory = readCategory(data);
      const rawNormalized = rawCategory.trim().toLowerCase();
      if (!rawNormalized) {
        empty += 1;
        continue;
      }
      const normalizedCategory = normalizeCategoryId(rawNormalized);
      if (normalizedCategory !== rawNormalized) normalizedChanges += 1;
      const isUnsupported =
        normalizedCategory === "unsupported_non_mvp" ||
        !CLAIM_ALLOWED_CATEGORY_IDS.has(normalizedCategory);
      if (isUnsupported) {
        unsupported += 1;
        if (unsupportedSamples.length < SAMPLE_LIMIT) {
          unsupportedSamples.push({
            docId: doc.id,
            rawCategory: rawNormalized,
            normalizedCategory,
          });
        }
      }
      inc(rawCounts, rawNormalized);
      inc(normalizedCounts, normalizedCategory);
    }

    if (snap.size < pageSize) break;
    cursor = snap.docs[snap.docs.length - 1];
  }

  return {
    collectionName,
    scanned,
    empty,
    normalizedChanges,
    unsupported,
    rawCounts,
    normalizedCounts,
    unsupportedSamples,
  };
}

async function main() {
  const args = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }

  const db = admin.firestore();
  const startedAt = Date.now();
  const [claims, merchants, merchantPublic] = await Promise.all([
    auditCollection({
      db,
      collectionName: "merchant_claims",
      pageSize: args.pageSize,
    }),
    auditCollection({
      db,
      collectionName: "merchants",
      pageSize: args.pageSize,
    }),
    auditCollection({
      db,
      collectionName: "merchant_public",
      pageSize: args.pageSize,
    }),
  ]);

  const summary = {
    audit: "claim_categories_mvp",
    project: args.project || "(default credentials project)",
    pageSize: args.pageSize,
    durationMs: Date.now() - startedAt,
    collections: [claims, merchants, merchantPublic],
  };
  console.log(JSON.stringify(summary));
}

main().catch((error) => {
  console.error("[audit_claim_categories_mvp] Failed:", error);
  process.exit(1);
});
