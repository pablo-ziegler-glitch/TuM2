#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_INPUT_DIR = path.resolve(
  __dirname,
  "../../docs/ops/generated"
);

function parseArgs(argv) {
  const parsed = {
    inputDir: DEFAULT_INPUT_DIR,
    out: "",
    markdown: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    if (key === "markdown") {
      parsed.markdown = true;
      continue;
    }
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Falta valor para --${key}`);
    }
    i += 1;
    if (key === "input-dir") {
      parsed.inputDir = path.resolve(process.cwd(), value);
      continue;
    }
    if (key === "out") {
      parsed.out = path.resolve(process.cwd(), value);
      continue;
    }
    throw new Error(`Argumento no soportado: --${key}`);
  }

  return parsed;
}

function loadReports(inputDir) {
  if (!fs.existsSync(inputDir)) {
    throw new Error(`No existe directorio de entrada: ${inputDir}`);
  }

  const files = fs
    .readdirSync(inputDir)
    .filter((name) => /^cost-guard-.*\.json$/i.test(name))
    .sort();
  if (files.length === 0) {
    throw new Error(`No se encontraron reportes cost-guard en ${inputDir}`);
  }

  return files.map((fileName) => {
    const fullPath = path.join(inputDir, fileName);
    const raw = fs.readFileSync(fullPath, "utf8");
    const parsed = JSON.parse(raw);
    return {
      fileName,
      fullPath,
      ...parsed,
    };
  });
}

function summarizeReport(report) {
  const statusRank = { ok: 0, warn: 1, critical: 2 };
  let worstStatus = "ok";
  let warnCount = 0;
  let criticalCount = 0;
  for (const row of report.results || []) {
    const status = String(row.status || "ok");
    if (status === "warn") warnCount += 1;
    if (status === "critical") criticalCount += 1;
    if ((statusRank[status] || 0) > statusRank[worstStatus]) {
      worstStatus = status;
    }
  }

  return {
    fileName: report.fileName,
    project: report.project,
    env: report.env,
    windowHours: report.windowHours,
    generatedAt: report.generatedAt,
    worstStatus,
    warnCount,
    criticalCount,
    metrics: report.results || [],
  };
}

function buildMarkdown(summaryRows) {
  const lines = [];
  lines.push("# FinOps Summary");
  lines.push("");
  lines.push(
    "| env | project | window(h) | worst | warnings | critical | generatedAt |"
  );
  lines.push("|---|---|---:|---|---:|---:|---|");
  for (const row of summaryRows) {
    lines.push(
      `| ${row.env} | ${row.project} | ${row.windowHours} | ${row.worstStatus.toUpperCase()} | ${row.warnCount} | ${row.criticalCount} | ${row.generatedAt} |`
    );
  }
  lines.push("");
  return `${lines.join("\n")}\n`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const reports = loadReports(args.inputDir);
  const summaryRows = reports.map(summarizeReport);

  const payload = {
    generatedAt: new Date().toISOString(),
    reports: summaryRows,
  };

  if (args.out) {
    fs.mkdirSync(path.dirname(args.out), { recursive: true });
    if (args.markdown) {
      fs.writeFileSync(args.out, buildMarkdown(summaryRows), "utf8");
    } else {
      fs.writeFileSync(args.out, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    }
    console.log(`Resumen guardado en: ${args.out}`);
  }

  console.log("");
  console.log("=== FinOps Summary ===");
  for (const row of summaryRows) {
    console.log(
      `${row.env} (${row.project}) worst=${row.worstStatus} warn=${row.warnCount} critical=${row.criticalCount}`
    );
  }
  console.log("");
}

main();
