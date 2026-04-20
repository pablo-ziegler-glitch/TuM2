#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

const BATCH_LIMIT = 450;
const DEFAULT_PAGE_SIZE = 400;

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
    if (token === "--help" || token === "-h") {
      args.help = true;
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

function canonicalCategoryId(raw) {
  const normalized = String(raw || "").trim().toLowerCase();
  if (normalized === "vet") return "veterinary";
  return normalized;
}

function readPath(source, path) {
  const segments = path.split(".");
  let cursor = source;
  for (const segment of segments) {
    if (cursor == null || typeof cursor !== "object") return undefined;
    cursor = cursor[segment];
  }
  return cursor;
}

async function migrateCategoryFields({
  db,
  apply,
  pageSize,
  collectionName,
  fieldPaths,
}) {
  let cursor = null;
  let scanned = 0;
  let changed = 0;
  let written = 0;
  let page = 0;
  let batch = db.batch();
  let batchOps = 0;

  while (true) {
    let query = db
      .collection(collectionName)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const snap = await query.get();
    if (snap.empty) break;
    page += 1;

    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const patch = {};

      for (const path of fieldPaths) {
        const raw = readPath(data, path);
        if (typeof raw !== "string") continue;
        const next = canonicalCategoryId(raw);
        if (!next || next === raw) continue;
        patch[path] = next;
      }

      const patchKeys = Object.keys(patch);
      if (!patchKeys.length) continue;
      changed += 1;

      if (!apply) continue;
      batch.set(
        doc.ref,
        {
          ...patch,
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

  return { collectionName, pages: page, scanned, changed, written };
}

async function migrateCatalogLimitsConfig({ db, apply }) {
  const ref = db.doc("admin_configs/catalog_limits");
  const snap = await ref.get();
  if (!snap.exists) {
    return { scanned: 0, changed: 0, written: 0 };
  }
  const data = snap.data() || {};
  const categoryLimits = data.categoryLimits;
  if (categoryLimits == null || typeof categoryLimits !== "object") {
    return { scanned: 1, changed: 0, written: 0 };
  }

  const legacy = categoryLimits.vet;
  if (legacy == null) {
    return { scanned: 1, changed: 0, written: 0 };
  }

  if (apply) {
    const patch = {
      "categoryLimits.veterinary":
        categoryLimits.veterinary != null ? categoryLimits.veterinary : legacy,
      "categoryLimits.vet": admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await ref.set(patch, { merge: true });
  }

  return { scanned: 1, changed: 1, written: apply ? 1 : 0 };
}

async function migrateCategoriesCollection({ db, apply }) {
  const legacyRef = db.doc("categories/vet");
  const canonicalRef = db.doc("categories/veterinary");
  const [legacySnap, canonicalSnap] = await Promise.all([
    legacyRef.get(),
    canonicalRef.get(),
  ]);

  if (!legacySnap.exists) {
    return { scanned: 1, changed: 0, written: 0 };
  }

  if (apply) {
    const legacyData = legacySnap.data() || {};
    if (!canonicalSnap.exists) {
      await canonicalRef.set(
        {
          ...legacyData,
          categoryId: "veterinary",
          aliases: admin.firestore.FieldValue.arrayUnion("vet"),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } else {
      await canonicalRef.set(
        {
          aliases: admin.firestore.FieldValue.arrayUnion("vet"),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    await legacyRef.delete();
  }

  return { scanned: 1, changed: 1, written: apply ? 2 : 0 };
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    console.log(
      [
        "Uso:",
        "  node scripts/migrate_categories_canonical.js [--project <id>] [--page-size <n>] [--apply]",
        "",
        "Por defecto ejecuta dry-run (no escribe).",
        "Colecciones incluidas:",
        "  - categories (doc id vet -> veterinary)",
        "  - admin_configs/catalog_limits (categoryLimits.vet -> veterinary)",
        "  - merchants (category/categoryId)",
        "  - merchant_public (category/categoryId)",
        "  - merchant_claims (categoryId)",
        "  - users (onboardingOwnerProgress.step1.categoryId)",
      ].join("\n")
    );
    return;
  }

  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }
  const db = admin.firestore();

  const startedAt = Date.now();
  console.log("---- migrate_categories_canonical ----");
  console.log(`Project: ${args.project || "(default credentials project)"}`);
  console.log(`Mode: ${args.apply ? "APPLY" : "DRY-RUN"}`);
  console.log(`Page size: ${args.pageSize}`);

  const summaries = [];
  summaries.push(
    await migrateCategoriesCollection({ db, apply: args.apply })
  );
  summaries.push(
    await migrateCatalogLimitsConfig({ db, apply: args.apply })
  );
  summaries.push(
    await migrateCategoryFields({
      db,
      apply: args.apply,
      pageSize: args.pageSize,
      collectionName: "merchants",
      fieldPaths: ["category", "categoryId"],
    })
  );
  summaries.push(
    await migrateCategoryFields({
      db,
      apply: args.apply,
      pageSize: args.pageSize,
      collectionName: "merchant_public",
      fieldPaths: ["category", "categoryId"],
    })
  );
  summaries.push(
    await migrateCategoryFields({
      db,
      apply: args.apply,
      pageSize: args.pageSize,
      collectionName: "merchant_claims",
      fieldPaths: ["categoryId"],
    })
  );
  summaries.push(
    await migrateCategoryFields({
      db,
      apply: args.apply,
      pageSize: args.pageSize,
      collectionName: "users",
      fieldPaths: ["onboardingOwnerProgress.step1.categoryId"],
    })
  );

  let totalScanned = 0;
  let totalChanged = 0;
  let totalWritten = 0;
  for (const summary of summaries) {
    totalScanned += summary.scanned || 0;
    totalChanged += summary.changed || 0;
    totalWritten += summary.written || 0;
    console.log(
      JSON.stringify({
        migration: "categories_canonical",
        scope: summary.collectionName || "singleton_doc",
        ...summary,
      })
    );
  }

  console.log(
    JSON.stringify({
      migration: "categories_canonical",
      mode: args.apply ? "apply" : "dry_run",
      totalScanned,
      totalChanged,
      totalWritten,
      durationMs: Date.now() - startedAt,
    })
  );
}

main().catch((error) => {
  console.error("[migrate_categories_canonical] Failed:", error);
  process.exit(1);
});

