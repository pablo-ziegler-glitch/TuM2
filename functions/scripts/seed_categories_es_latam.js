#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = {
    project: process.env.GCLOUD_PROJECT || "",
    apply: false,
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
  }
  return args;
}

const CATEGORY_SEED = [
  {
    id: "farmacia",
    label: "Farmacia",
    iconName: "local_pharmacy",
    aliases: ["pharmacy", "farmacia", "drugstore"],
  },
  {
    id: "kiosco",
    label: "Kiosco",
    iconName: "storefront",
    aliases: ["kiosk", "kiosco", "convenience_store"],
  },
  {
    id: "almacen",
    label: "Almacen",
    iconName: "shopping_basket",
    aliases: ["grocery", "almacen", "store"],
  },
  {
    id: "supermercado",
    label: "Supermercado",
    iconName: "shopping_cart",
    aliases: ["supermarket", "supermercado", "hipermercado"],
  },
  {
    id: "veterinaria",
    label: "Veterinaria",
    iconName: "pets",
    aliases: ["veterinary", "veterinaria", "vet"],
  },
  {
    id: "casa_de_comidas",
    label: "Casa de comidas",
    iconName: "restaurant",
    aliases: ["prepared_food", "rotiseria", "cocina_preparada"],
  },
  {
    id: "comida_al_paso",
    label: "Comida al paso",
    iconName: "lunch_dining",
    aliases: ["fast_food", "comida_rapida", "comida_al_paso"],
  },
  {
    id: "gomeria",
    label: "Gomeria",
    iconName: "tire_repair",
    aliases: ["tire_shop", "gomeria"],
  },
  {
    id: "cafeteria",
    label: "Cafeteria",
    iconName: "local_cafe",
    aliases: ["cafeteria", "cafe", "coffee_shop"],
  },
  {
    id: "panaderia",
    label: "Panaderia",
    iconName: "bakery_dining",
    aliases: ["panaderia", "bakery"],
  },
  {
    id: "otro",
    label: "Otro",
    iconName: "store",
    aliases: ["other", "otro"],
  },
];

const LEGACY_IDS = [
  "pharmacy",
  "kiosk",
  "grocery",
  "supermarket",
  "veterinary",
  "prepared_food",
  "fast_food",
  "tire_shop",
  "other",
  "bakery",
  "vet",
];

async function main() {
  const args = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  console.log("---- seed_categories_es_latam ----");
  console.log(`Project: ${args.project || "(default credentials project)"}`);
  console.log(`Mode: ${args.apply ? "APPLY" : "DRY-RUN"}`);

  if (!args.apply) {
    console.log("Categorías a upsert:");
    for (const row of CATEGORY_SEED) {
      console.log(`- ${row.id} (${row.label}) aliases=${row.aliases.join(",")}`);
    }
    console.log(`Legacy IDs a eliminar: ${LEGACY_IDS.join(", ")}`);
    return;
  }

  const batch = db.batch();
  for (const row of CATEGORY_SEED) {
    batch.set(
      db.doc(`categories/${row.id}`),
      {
        categoryId: row.id,
        label: row.label,
        iconName: row.iconName,
        aliases: Array.from(
          new Set(row.aliases.map((value) => String(value).trim().toLowerCase()))
        ).sort(),
        isActive: true,
        createdAt: now,
        createdBy: "seed_categories_es_latam",
        updatedAt: now,
        updatedBy: "seed_categories_es_latam",
      },
      { merge: true }
    );
  }

  for (const legacyId of LEGACY_IDS) {
    batch.delete(db.doc(`categories/${legacyId}`));
  }
  await batch.commit();

  const snapshot = await db
    .collection("categories")
    .orderBy(admin.firestore.FieldPath.documentId())
    .get();
  console.log(`Done. categories count=${snapshot.size}`);
}

main().catch((error) => {
  console.error("[seed_categories_es_latam] Failed:", error);
  process.exit(1);
});
