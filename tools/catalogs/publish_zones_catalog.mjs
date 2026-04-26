#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");

const VALID_ENVS = new Set(["dev", "staging", "prod"]);

function parseArgs(argv) {
  const args = {
    env: "",
    version: 0,
    csv: "data/comercios_unicos_2026-04-03.csv",
    sourceJson: "data/catalogs/zones/editorial/zones_editorial_seed.json",
    rollback: false,
    rollbackTo: 0,
    updateSeed: false,
    allowNonProdSeed: false,
    dryRun: false,
  };

  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--rollback") {
      args.rollback = true;
      continue;
    }
    if (token === "--dry-run") {
      args.dryRun = true;
      continue;
    }
    if (token === "--no-update-seed") {
      args.updateSeed = false;
      continue;
    }
    if (token === "--update-seed") {
      args.updateSeed = true;
      continue;
    }
    if (token === "--allow-non-prod-seed") {
      args.allowNonProdSeed = true;
      continue;
    }
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Falta valor para --${key}`);
    }
    i++;
    if (key === "env") args.env = value.trim().toLowerCase();
    else if (key === "version") args.version = Number.parseInt(value, 10);
    else if (key === "csv") args.csv = value;
    else if (key === "source-json") args.sourceJson = value;
    else if (key === "rollback-to") args.rollbackTo = Number.parseInt(value, 10);
  }

  if (!VALID_ENVS.has(args.env)) {
    throw new Error("--env debe ser dev | staging | prod");
  }
  if (args.rollback) {
    if (!Number.isInteger(args.rollbackTo) || args.rollbackTo <= 0) {
      throw new Error("--rollback requiere --rollback-to <version>");
    }
  } else if (!Number.isInteger(args.version) || args.version <= 0) {
    throw new Error("--version debe ser entero positivo");
  }
  if (args.updateSeed && args.env !== "prod" && !args.allowNonProdSeed) {
    throw new Error(
      "--update-seed fuera de prod requiere --allow-non-prod-seed explícito"
    );
  }
  return args;
}

function normalize(input) {
  return String(input || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
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
  const absPath = path.resolve(ROOT, csvPath);
  if (!fs.existsSync(absPath)) {
    throw new Error(`CSV no encontrado: ${absPath}`);
  }
  const raw = fs.readFileSync(absPath, "utf8").replace(/^\uFEFF/, "");
  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.length > 0);
  if (lines.length < 2) {
    throw new Error("CSV sin filas de datos");
  }
  const header = parseCsvLine(lines[0]);
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const cols = parseCsvLine(lines[i]);
    if (cols.length !== header.length) continue;
    const row = {};
    for (let j = 0; j < header.length; j++) {
      row[header[j]] = cols[j];
    }
    rows.push(row);
  }
  return rows;
}

function readEditorialJson(sourceJsonPath) {
  const absPath = path.resolve(ROOT, sourceJsonPath);
  if (!fs.existsSync(absPath)) {
    return [];
  }
  const raw = JSON.parse(fs.readFileSync(absPath, "utf8"));
  if (!Array.isArray(raw)) {
    throw new Error(`El JSON editorial debe ser un array: ${absPath}`);
  }
  return raw;
}

function compareText(a, b) {
  return normalize(a).localeCompare(normalize(b));
}

function toCatalogZones(rows) {
  const map = new Map();
  for (const row of rows) {
    const zoneId = String(row.localidad_id || "").trim();
    if (!zoneId || map.has(zoneId)) continue;

    const localityName = String(row.localidad_nombre || "").trim() || zoneId;
    const provinceName = String(row.provincia_nombre || "").trim();
    const provinceId = String(row.provincia_id || "").trim();
    const departmentName = String(row.departamento_nombre || "").trim();
    const departmentId = String(row.departamento_id || "").trim();
    const codloc = String(row.codloc || "").trim();
    const codent = String(row.codent || "").trim();
    const cp = String(row.cp || "").trim();

    map.set(zoneId, {
      id: zoneId,
      zoneId,
      name: localityName,
      normalizedName: normalize(localityName),
      provinceId,
      provinceName,
      provinceNormalizedName: normalize(provinceName),
      departmentId,
      departmentName,
      departmentNormalizedName: normalize(departmentName),
      localityId: zoneId,
      localityName,
      localityNormalizedName: normalize(localityName),
      cityId: zoneId,
      cityName: localityName,
      countryId: "AR",
      countryName: "Argentina",
      status: "public_enabled",
      priorityLevel: 1000,
      references: {
        codloc,
        codent,
        cp,
      },
    });
  }

  const zones = [...map.values()];
  zones.sort((a, b) => {
    const p = compareText(a.provinceName, b.provinceName);
    if (p !== 0) return p;
    const d = compareText(a.departmentName, b.departmentName);
    if (d !== 0) return d;
    const l = compareText(a.localityName, b.localityName);
    if (l !== 0) return l;
    return a.id.localeCompare(b.id);
  });
  return zones;
}

function toCatalogZonesFromEditorial(rows) {
  const map = new Map();
  for (const row of rows) {
    const zoneId = String(row.id || row.zoneId || "").trim();
    if (!zoneId || map.has(zoneId)) continue;
    const localityName = String(
      row.localityName || row.name || row.locality || zoneId
    ).trim();
    const provinceName = String(row.provinceName || "").trim();
    const provinceId = String(row.provinceId || "").trim();
    const departmentName = String(row.departmentName || "").trim();
    const departmentId = String(row.departmentId || "").trim();
    const priorityLevel = Number.isFinite(Number(row.priorityLevel))
      ? Number(row.priorityLevel)
      : 1000;

    map.set(zoneId, {
      id: zoneId,
      zoneId,
      name: localityName,
      normalizedName: normalize(localityName),
      provinceId,
      provinceName,
      provinceNormalizedName: normalize(provinceName),
      departmentId,
      departmentName,
      departmentNormalizedName: normalize(departmentName),
      localityId: zoneId,
      localityName,
      localityNormalizedName: normalize(localityName),
      cityId: zoneId,
      cityName: localityName,
      countryId: "AR",
      countryName: "Argentina",
      status: "public_enabled",
      priorityLevel,
      references: {
        codloc: String(row.codloc || "").trim(),
        codent: String(row.codent || "").trim(),
        cp: String(row.cp || "").trim(),
      },
    });
  }
  const zones = [...map.values()];
  zones.sort((a, b) => {
    const p = compareText(a.provinceName, b.provinceName);
    if (p !== 0) return p;
    const d = compareText(a.departmentName, b.departmentName);
    if (d !== 0) return d;
    const l = compareText(a.localityName, b.localityName);
    if (l !== 0) return l;
    return a.id.localeCompare(b.id);
  });
  return zones;
}

function sha256Base64(content) {
  const digest = crypto.createHash("sha256").update(content).digest("base64");
  return `sha256-${digest}`;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function writeJson(filePath, value) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function loadJsonIfExists(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function createManifest({ env, version, checksum, entries }) {
  const now = new Date().toISOString();
  return {
    catalog: "zones",
    environment: env,
    version,
    publishedAt: now,
    file: `/catalogs/zones/${env}/versions/zones-v${version}.json`,
    checksum,
    schemaVersion: 1,
    entries,
  };
}

function mirrorPublishedArtifacts({ env, version, manifest, catalogContent }) {
  const targets = [
    path.resolve(ROOT, `mobile/web/catalogs/zones/${env}`),
    path.resolve(ROOT, `web/web/catalogs/zones/${env}`),
  ];
  for (const target of targets) {
    ensureDir(path.join(target, "versions"));
    fs.writeFileSync(path.join(target, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
    fs.writeFileSync(
      path.join(target, `versions/zones-v${version}.json`),
      `${catalogContent}\n`,
      "utf8"
    );
  }
}

function updateSeedAssets(catalogJson) {
  const seedTargets = [
    path.resolve(ROOT, "mobile/assets/catalogs/zones/seed/zones-seed.json"),
    path.resolve(ROOT, "web/assets/catalogs/zones/seed/zones-seed.json"),
  ];
  for (const target of seedTargets) {
    ensureDir(path.dirname(target));
    fs.writeFileSync(target, `${catalogJson}\n`, "utf8");
  }
}

function publish(args) {
  const editorialRows = readEditorialJson(args.sourceJson);
  const csvRows = editorialRows.length > 0 ? [] : readCsv(args.csv);
  const zones = editorialRows.length > 0
    ? toCatalogZonesFromEditorial(editorialRows)
    : toCatalogZones(csvRows);
  const catalog = {
    catalog: "zones",
    schemaVersion: 1,
    version: args.version,
    generatedAt: new Date().toISOString(),
    source: {
      type: editorialRows.length > 0 ? "editorial_json" : "csv",
      file: editorialRows.length > 0 ? args.sourceJson : args.csv,
    },
    entries: zones.length,
    zones,
  };
  const catalogJson = JSON.stringify(catalog, null, 2);
  const checksum = sha256Base64(catalogJson);
  const manifest = createManifest({
    env: args.env,
    version: args.version,
    checksum,
    entries: zones.length,
  });

  const envRoot = path.resolve(ROOT, `data/catalogs/zones/${args.env}`);
  const manifestPath = path.join(envRoot, "manifest.json");
  const rollbackPath = path.join(envRoot, "rollback.json");
  const versionPath = path.join(envRoot, `versions/zones-v${args.version}.json`);
  const existingManifest = loadJsonIfExists(manifestPath);
  if (existingManifest != null && Number(existingManifest.version) >= args.version) {
    throw new Error(
      `La nueva versión (${args.version}) debe ser mayor que la publicada (${existingManifest.version}).`
    );
  }

  if (args.dryRun) {
    console.log(
      JSON.stringify(
        {
          mode: "dry-run",
          env: args.env,
          version: args.version,
          entries: zones.length,
          checksum,
          manifestPath,
          versionPath,
          updateSeed: args.updateSeed,
        },
        null,
        2
      )
    );
    return;
  }

  writeJson(versionPath, catalog);
  writeJson(manifestPath, manifest);
  if (existingManifest != null) {
    writeJson(rollbackPath, {
      catalog: "zones",
      environment: args.env,
      previousVersion: Number(existingManifest.version),
      previousFile: String(existingManifest.file || ""),
      rolledForwardTo: args.version,
      at: new Date().toISOString(),
    });
  }
  mirrorPublishedArtifacts({
    env: args.env,
    version: args.version,
    manifest,
    catalogContent: catalogJson,
  });
  if (args.updateSeed) {
    updateSeedAssets(catalogJson);
  }

  console.log(
    JSON.stringify(
      {
        mode: "publish",
        env: args.env,
        version: args.version,
        entries: zones.length,
        checksum,
        updateSeed: args.updateSeed,
      },
      null,
      2
    )
  );
}

function rollback(args) {
  const envRoot = path.resolve(ROOT, `data/catalogs/zones/${args.env}`);
  const versionPath = path.join(envRoot, `versions/zones-v${args.rollbackTo}.json`);
  if (!fs.existsSync(versionPath)) {
    throw new Error(`No existe versión para rollback: ${versionPath}`);
  }

  const catalogJson = fs.readFileSync(versionPath, "utf8").trimEnd();
  const catalog = JSON.parse(catalogJson);
  const checksum = sha256Base64(catalogJson);
  const manifest = createManifest({
    env: args.env,
    version: args.rollbackTo,
    checksum,
    entries: Number(catalog.entries || 0),
  });

  const manifestPath = path.join(envRoot, "manifest.json");
  if (args.dryRun) {
    console.log(
      JSON.stringify(
        {
          mode: "dry-run-rollback",
          env: args.env,
          rollbackTo: args.rollbackTo,
          manifestPath,
        },
        null,
        2
      )
    );
    return;
  }

  writeJson(manifestPath, manifest);
  mirrorPublishedArtifacts({
    env: args.env,
    version: args.rollbackTo,
    manifest,
    catalogContent: catalogJson,
  });

  console.log(
    JSON.stringify(
      {
        mode: "rollback",
        env: args.env,
        rollbackTo: args.rollbackTo,
      },
      null,
      2
    )
  );
}

function main() {
  const args = parseArgs(process.argv);
  if (args.rollback) {
    rollback(args);
    return;
  }
  publish(args);
}

main();
