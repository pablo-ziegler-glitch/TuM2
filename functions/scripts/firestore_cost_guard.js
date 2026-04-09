#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Guardrail de costo Firestore.
 *
 * Objetivo:
 * - Consultar métricas de Cloud Monitoring para Firestore.
 * - Compararlas contra umbrales por ambiente.
 * - Fallar (exit code != 0) ante regresión crítica de consumo.
 *
 * Uso:
 *   node scripts/firestore_cost_guard.js \
 *     --project tum2-staging-45c83 \
 *     --env staging \
 *     --window-hours 24 \
 *     --fail-on-warn
 */

const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const https = require("node:https");
const path = require("node:path");

const DEFAULT_THRESHOLDS_PATH = path.resolve(
  __dirname,
  "../../docs/ops/firestore_cost_thresholds.json"
);

const METRICS = [
  {
    key: "readOps",
    label: "Firestore read ops",
    metricType: "firestore.googleapis.com/document/read_ops_count",
    aggregation: "sum",
    unit: "ops",
  },
  {
    key: "writeOps",
    label: "Firestore write ops",
    metricType: "firestore.googleapis.com/document/write_ops_count",
    aggregation: "sum",
    unit: "ops",
  },
  {
    key: "deleteOps",
    label: "Firestore delete ops",
    metricType: "firestore.googleapis.com/document/delete_ops_count",
    aggregation: "sum",
    unit: "ops",
  },
  {
    key: "snapshotListeners",
    label: "Snapshot listeners (max)",
    metricType: "firestore.googleapis.com/network/snapshot_listeners",
    aggregation: "max_sum_by_timestamp",
    unit: "listeners",
  },
  {
    key: "rulesEvaluations",
    label: "Rules evaluations",
    metricType: "firestore.googleapis.com/rules/evaluation_count",
    aggregation: "sum",
    unit: "evals",
  },
];

function parseArgs(argv) {
  const parsed = {
    project: "",
    env: "",
    windowHours: 24,
    thresholdsPath: DEFAULT_THRESHOLDS_PATH,
    out: "",
    failOnWarn: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    if (key === "fail-on-warn") {
      parsed.failOnWarn = true;
      continue;
    }
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Falta valor para --${key}`);
    }
    i += 1;

    switch (key) {
      case "project":
        parsed.project = value.trim();
        break;
      case "env":
        parsed.env = value.trim();
        break;
      case "window-hours":
        parsed.windowHours = Number.parseInt(value, 10);
        break;
      case "thresholds":
        parsed.thresholdsPath = path.resolve(process.cwd(), value);
        break;
      case "out":
        parsed.out = path.resolve(process.cwd(), value);
        break;
      default:
        throw new Error(`Argumento no soportado: --${key}`);
    }
  }

  if (!parsed.project) {
    throw new Error("Argumento requerido: --project <firebase-project-id>");
  }
  if (!Number.isFinite(parsed.windowHours) || parsed.windowHours <= 0) {
    throw new Error("window-hours inválido. Debe ser un entero > 0.");
  }

  if (!parsed.env) {
    parsed.env = inferEnvFromProject(parsed.project);
  }

  return parsed;
}

function inferEnvFromProject(projectId) {
  const normalized = projectId.toLowerCase();
  if (normalized.includes("prod")) return "prod";
  if (normalized.includes("staging")) return "staging";
  return "dev";
}

function loadThresholds(thresholdsPath, env) {
  if (!fs.existsSync(thresholdsPath)) {
    throw new Error(`No existe archivo de umbrales: ${thresholdsPath}`);
  }
  const raw = fs.readFileSync(thresholdsPath, "utf8");
  const parsed = JSON.parse(raw);
  const envConfig = parsed?.environments?.[env];
  if (!envConfig) {
    throw new Error(
      `No hay umbrales para env='${env}' en ${thresholdsPath}`
    );
  }
  return envConfig;
}

function gcloudAccessToken() {
  try {
    const output = execFileSync(
      "gcloud",
      ["auth", "print-access-token"],
      { encoding: "utf8" }
    );
    const token = output.trim();
    if (!token) {
      throw new Error("Token vacío");
    }
    return token;
  } catch (error) {
    throw new Error(
      "No se pudo obtener access token con gcloud. " +
        "Revisá autenticación: gcloud auth application-default login o account impersonation.\n" +
        String(error?.message || error)
    );
  }
}

function fetchAllTimeSeries({
  project,
  metricType,
  startIso,
  endIso,
  accessToken,
}) {
  const allSeries = [];
  let pageToken = "";

  return new Promise((resolve, reject) => {
    const nextPage = () => {
      const filter = `metric.type="${metricType}"`;
      const params = new URLSearchParams({
        filter,
        "interval.startTime": startIso,
        "interval.endTime": endIso,
        view: "FULL",
        pageSize: "1000",
      });
      if (pageToken) {
        params.set("pageToken", pageToken);
      }
      const requestPath = `/v3/projects/${encodeURIComponent(
        project
      )}/timeSeries?${params.toString()}`;

      const req = https.request(
        {
          hostname: "monitoring.googleapis.com",
          method: "GET",
          path: requestPath,
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Accept: "application/json",
          },
        },
        (res) => {
          let body = "";
          res.on("data", (chunk) => {
            body += chunk;
          });
          res.on("end", () => {
            if (res.statusCode == null || res.statusCode >= 400) {
              reject(
                new Error(
                  `Monitoring API error ${res.statusCode}: ${body.slice(0, 600)}`
                )
              );
              return;
            }

            let parsed;
            try {
              parsed = JSON.parse(body);
            } catch (error) {
              reject(
                new Error(
                  `Respuesta JSON inválida de Monitoring API (${metricType}): ${String(
                    error?.message || error
                  )}`
                )
              );
              return;
            }

            const series = Array.isArray(parsed.timeSeries)
              ? parsed.timeSeries
              : [];
            allSeries.push(...series);
            pageToken = parsed.nextPageToken || "";

            if (pageToken) {
              nextPage();
              return;
            }

            resolve(allSeries);
          });
        }
      );

      req.on("error", (error) => {
        reject(
          new Error(
            `Error consultando Monitoring API (${metricType}): ${String(
              error?.message || error
            )}`
          )
        );
      });
      req.end();
    };

    nextPage();
  });
}

function pointNumericValue(point) {
  const value = point?.value;
  if (!value || typeof value !== "object") return 0;
  if (typeof value.int64Value === "string") {
    const num = Number(value.int64Value);
    return Number.isFinite(num) ? num : 0;
  }
  if (typeof value.doubleValue === "number") return value.doubleValue;
  if (typeof value.boolValue === "boolean") return value.boolValue ? 1 : 0;
  return 0;
}

function aggregateSeries(seriesList, aggregation) {
  if (!Array.isArray(seriesList) || seriesList.length === 0) return 0;

  if (aggregation === "sum") {
    let total = 0;
    for (const series of seriesList) {
      const points = Array.isArray(series.points) ? series.points : [];
      for (const point of points) {
        total += pointNumericValue(point);
      }
    }
    return total;
  }

  if (aggregation === "max_sum_by_timestamp") {
    const sumsByTimestamp = new Map();
    for (const series of seriesList) {
      const points = Array.isArray(series.points) ? series.points : [];
      for (const point of points) {
        const timestamp =
          point?.interval?.endTime || point?.interval?.startTime || "unknown";
        const current = sumsByTimestamp.get(timestamp) || 0;
        sumsByTimestamp.set(timestamp, current + pointNumericValue(point));
      }
    }
    let max = 0;
    for (const value of sumsByTimestamp.values()) {
      if (value > max) max = value;
    }
    return max;
  }

  throw new Error(`Agregación no soportada: ${aggregation}`);
}

function classifyStatus(value, threshold) {
  if (!threshold) return "ok";
  if (typeof threshold.critical === "number" && value >= threshold.critical) {
    return "critical";
  }
  if (typeof threshold.warn === "number" && value >= threshold.warn) {
    return "warn";
  }
  return "ok";
}

function formatNumber(value) {
  return new Intl.NumberFormat("es-AR").format(Math.round(value));
}

function printSummary({
  project,
  env,
  windowHours,
  results,
  startedAtIso,
  endedAtIso,
}) {
  console.log("");
  console.log("=== Firestore Cost Guard ===");
  console.log(`Proyecto: ${project}`);
  console.log(`Ambiente: ${env}`);
  console.log(`Ventana: ${windowHours}h`);
  console.log(`Intervalo: ${startedAtIso} -> ${endedAtIso}`);
  console.log("");

  const header =
    "| Métrica | Valor | Warn | Critical | Estado |\n" +
    "|---|---:|---:|---:|---|";
  console.log(header);
  for (const row of results) {
    const warn = row.threshold?.warn ?? "-";
    const critical = row.threshold?.critical ?? "-";
    const statusEmoji =
      row.status === "critical"
        ? "CRITICAL"
        : row.status === "warn"
          ? "WARN"
          : "OK";
    console.log(
      `| ${row.label} | ${formatNumber(row.value)} ${row.unit} | ${warn} | ${critical} | ${statusEmoji} |`
    );
  }
  console.log("");
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const thresholds = loadThresholds(args.thresholdsPath, args.env);

  const endTime = new Date();
  const startTime = new Date(
    endTime.getTime() - args.windowHours * 60 * 60 * 1000
  );
  const startedAtIso = startTime.toISOString();
  const endedAtIso = endTime.toISOString();

  const accessToken = gcloudAccessToken();
  const results = [];

  for (const metric of METRICS) {
    const series = await fetchAllTimeSeries({
      project: args.project,
      metricType: metric.metricType,
      startIso: startedAtIso,
      endIso: endedAtIso,
      accessToken,
    });
    const value = aggregateSeries(series, metric.aggregation);
    const threshold = thresholds?.[metric.key] || null;
    const status = classifyStatus(value, threshold);

    results.push({
      key: metric.key,
      label: metric.label,
      metricType: metric.metricType,
      value,
      unit: metric.unit,
      threshold,
      status,
      seriesCount: series.length,
    });
  }

  printSummary({
    project: args.project,
    env: args.env,
    windowHours: args.windowHours,
    results,
    startedAtIso,
    endedAtIso,
  });

  const payload = {
    project: args.project,
    env: args.env,
    windowHours: args.windowHours,
    startedAtIso,
    endedAtIso,
    generatedAt: new Date().toISOString(),
    results,
  };

  if (args.out) {
    fs.mkdirSync(path.dirname(args.out), { recursive: true });
    fs.writeFileSync(args.out, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    console.log(`Resultado guardado en: ${args.out}`);
  }

  const hasCritical = results.some((row) => row.status === "critical");
  const hasWarn = results.some((row) => row.status === "warn");

  if (hasCritical) {
    console.error("Guardrail CRITICO: se excedieron umbrales críticos.");
    process.exitCode = 2;
    return;
  }
  if (hasWarn && args.failOnWarn) {
    console.error("Guardrail WARN: se excedieron umbrales de advertencia.");
    process.exitCode = 3;
    return;
  }
  process.exitCode = 0;
}

main().catch((error) => {
  console.error("Error ejecutando firestore_cost_guard:", error);
  process.exit(1);
});
