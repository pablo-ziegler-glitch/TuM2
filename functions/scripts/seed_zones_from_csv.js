#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = {
    csv: "",
    project: process.env.GCLOUD_PROJECT || "",
    collection: "zones",
    apply: false,
    merge: true,
  };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--apply") {
      args.apply = true;
      continue;
    }
    if (token === "--no-merge") {
      args.merge = false;
      continue;
    }
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Missing value for --${key}`);
    }
    i++;
    if (key === "csv") args.csv = value;
    else if (key === "project") args.project = value;
    else if (key === "collection") args.collection = value;
  }
  if (!args.csv) {
    throw new Error("Missing required --csv <path>");
  }
  return args;
}

function parseCsvLine(line) {
  const out = [];
  let cur = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch === "," && !inQuotes) {
      out.push(cur);
      cur = "";
      continue;
    }
    cur += ch;
  }
  out.push(cur);
  return out.map((v) => v.trim());
}

function readCsv(csvPath) {
  const raw = fs.readFileSync(csvPath, "utf8").replace(/^\uFEFF/, "");
  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.length > 0);
  if (lines.length < 2) {
    throw new Error("CSV has no data rows");
  }
  const header = parseCsvLine(lines[0]);
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    if (cols.length !== header.length) {
      console.warn(
        `[warn] line ${i + 1}: expected ${header.length} cols, got ${cols.length}. Skipped.`
      );
      continue;
    }
    const row = {};
    for (let j = 0; j < header.length; j++) {
      row[header[j]] = cols[j];
    }
    rows.push(row);
  }
  return rows;
}

function slugify(input) {
  return String(input || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function toZoneDocs(rows) {
  const map = new Map();
  for (const row of rows) {
    const localidadId = String(row.localidad_id || "").trim();
    if (!localidadId) continue;

    const localidadNombre = String(row.localidad_nombre || "").trim();
    const provinciaId = String(row.provincia_id || "").trim();
    const provinciaNombre = String(row.provincia_nombre || "").trim();
    const departamentoId = String(row.departamento_id || "").trim();
    const departamentoNombre = String(row.departamento_nombre || "").trim();
    const codloc = String(row.codloc || "").trim();
    const codent = String(row.codent || "").trim();
    const cp = String(row.cp || "").trim();

    const zoneId = localidadId;
    if (map.has(zoneId)) continue;

    map.set(zoneId, {
      id: zoneId,
      name: localidadNombre || zoneId,
      slug: `${slugify(localidadNombre || zoneId)}-${zoneId}`.slice(0, 120),
      provinceId: provinciaId,
      provinceName: provinciaNombre,
      cityId: localidadId,
      cityName: localidadNombre || zoneId,
      countryId: "AR",
      countryName: "Argentina",
      status: "public_enabled",
      priorityLevel: 1000,
      launchPhase: "mvp",
      // No centroid in this CSV version. Keeping explicit metadata helps
      // detect and backfill coordinates later.
      centroidMissing: true,
      source: {
        dataset: "datos.salud.gob.ar farmacias",
        snapshot: "2026-01",
        rowType: "unique_no_duplicates",
      },
      references: {
        departamentoId,
        departamentoNombre,
        codloc,
        codent,
        cp,
      },
    });
  }
  return [...map.values()];
}

async function writeZones(db, collection, docs, merge) {
  const chunkSize = 450;
  let written = 0;
  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const zone of chunk) {
      const ref = db.collection(collection).doc(zone.id);
      batch.set(
        ref,
        {
          ...zone,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge }
      );
    }
    await batch.commit();
    written += chunk.length;
    console.log(`Committed ${written}/${docs.length}`);
  }
}

async function main() {
  const args = parseArgs(process.argv);
  const csvPath = path.resolve(process.cwd(), args.csv);
  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV not found: ${csvPath}`);
  }

  if (!admin.apps.length) {
    admin.initializeApp(
      args.project ? { projectId: args.project } : undefined
    );
  }

  const rows = readCsv(csvPath);
  const zones = toZoneDocs(rows);
  console.log(`Rows read: ${rows.length}`);
  console.log(`Unique zones prepared: ${zones.length}`);
  console.log(`Target collection: ${args.collection}`);
  console.log(`Project: ${args.project || "(from credentials/default)"}`);

  if (!args.apply) {
    console.log(
      "\nDry-run only. Re-run with --apply to write documents to Firestore."
    );
    return;
  }

  const db = admin.firestore();
  await writeZones(db, args.collection, zones, args.merge);
  console.log(`Done. ${zones.length} zones upserted.`);
}

main().catch((err) => {
  console.error("[seed_zones_from_csv] Failed:", err.message);
  process.exit(1);
});

