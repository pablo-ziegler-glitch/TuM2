#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require("node:fs");
const path = require("node:path");

function parseList(value) {
  if (typeof value !== "string" || value.trim().length === 0) return [];
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function parseArgs(argv) {
  const parsed = {
    summary: "",
    onlyEnvs: [],
    failOnWarnEnvs: ["prod"],
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Falta valor para --${key}`);
    }
    i += 1;
    if (key === "summary") {
      parsed.summary = path.resolve(process.cwd(), value);
      continue;
    }
    if (key === "only-envs") {
      parsed.onlyEnvs = parseList(value);
      continue;
    }
    if (key === "fail-on-warn-envs") {
      parsed.failOnWarnEnvs = parseList(value);
      continue;
    }
    throw new Error(`Argumento no soportado: --${key}`);
  }

  if (!parsed.summary) {
    throw new Error("Argumento requerido: --summary <finops-summary.json>");
  }
  return parsed;
}

function loadSummary(summaryPath) {
  if (!fs.existsSync(summaryPath)) {
    throw new Error(`No existe summary file: ${summaryPath}`);
  }
  const raw = fs.readFileSync(summaryPath, "utf8");
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed.reports)) {
    throw new Error("Formato inválido: falta array reports");
  }
  return parsed.reports;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const reports = loadSummary(args.summary)
    .filter((report) => {
      if (args.onlyEnvs.length === 0) return true;
      return args.onlyEnvs.includes(String(report.env || ""));
    });

  if (reports.length === 0) {
    console.log("No hay reportes para evaluar en los ambientes seleccionados.");
    process.exitCode = 0;
    return;
  }

  let hasCritical = false;
  let hasWarnFailure = false;

  console.log("");
  console.log("=== FinOps Gate ===");
  for (const report of reports) {
    const env = String(report.env || "unknown");
    const project = String(report.project || "unknown");
    const worst = String(report.worstStatus || "ok").toLowerCase();
    const warnCount = Number(report.warnCount || 0);
    const criticalCount = Number(report.criticalCount || 0);
    console.log(
      `${env} (${project}) worst=${worst} warn=${warnCount} critical=${criticalCount}`
    );

    if (worst === "critical" || criticalCount > 0) {
      hasCritical = true;
      continue;
    }
    if (
      (worst === "warn" || warnCount > 0) &&
      args.failOnWarnEnvs.includes(env)
    ) {
      hasWarnFailure = true;
    }
  }
  console.log("");

  if (hasCritical) {
    console.error("FinOps Gate CRITICAL: se detectaron ambientes en critical.");
    process.exitCode = 2;
    return;
  }
  if (hasWarnFailure) {
    console.error(
      `FinOps Gate WARN: se detectaron warnings en ambientes con fail-on-warn (${args.failOnWarnEnvs.join(",")}).`
    );
    process.exitCode = 3;
    return;
  }

  process.exitCode = 0;
}

main();
