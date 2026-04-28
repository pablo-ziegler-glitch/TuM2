#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const EXPECTED_ALLOWLIST = [
  "farmacia",
  "kiosco",
  "almacen",
  "veterinaria",
  "comida_al_paso",
  "casa_de_comidas",
  "gomeria",
  "panaderia",
  "confiteria",
];

const BLOCKED_LEGACY = new Set([
  "cafeteria",
  "cafe",
  "supermarket",
  "supermercado",
  "other",
  "otro",
  "prepared_food",
  "food_on_the_go",
  "fast_food",
  "grocery",
  "kiosk",
  "pharmacy",
  "veterinary",
]);

function parseQuotedStrings(source, declarationName) {
  const escapedName = declarationName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const regex = new RegExp(
    `${escapedName}\\s*=\\s*\\[(.*?)\\]\\s*as const`,
    "s"
  );
  const match = source.match(regex);
  if (!match) {
    throw new Error(`No se encontró declaración '${declarationName}'.`);
  }
  const body = match[1];
  const values = [];
  const valueRegex = /["']([^"']+)["']/g;
  let valueMatch = valueRegex.exec(body);
  while (valueMatch != null) {
    values.push(valueMatch[1].trim());
    valueMatch = valueRegex.exec(body);
  }
  return values;
}

function parseDartSet(source, declarationName) {
  const escapedName = declarationName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const regex = new RegExp(`${escapedName}\\s*=\\s*<String>\\{(.*?)\\};`, "s");
  const match = source.match(regex);
  if (!match) {
    throw new Error(`No se encontró declaración '${declarationName}'.`);
  }
  const body = match[1];
  const values = [];
  const valueRegex = /'([^']+)'/g;
  let valueMatch = valueRegex.exec(body);
  while (valueMatch != null) {
    values.push(valueMatch[1].trim());
    valueMatch = valueRegex.exec(body);
  }
  return values;
}

function normalize(values) {
  return [...new Set(values.map((value) => value.trim().toLowerCase()))].sort();
}

function assertSetEquals(label, actualValues, expectedValues) {
  const actual = normalize(actualValues);
  const expected = normalize(expectedValues);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${label} inválido.\nactual=${JSON.stringify(actual)}\nexpected=${JSON.stringify(expected)}`
    );
  }
}

function assertNoLegacy(label, values) {
  const normalized = normalize(values);
  const found = normalized.filter((value) => BLOCKED_LEGACY.has(value));
  if (found.length > 0) {
    throw new Error(
      `${label} contiene categorías legacy bloqueadas: ${found.join(", ")}`
    );
  }
}

function main() {
  const functionsRoot = path.resolve(__dirname, "..");
  const backendPolicyPath = path.join(
    functionsRoot,
    "src",
    "lib",
    "merchantClaimEvidencePolicy.ts"
  );
  const mobilePolicyPath = path.join(
    functionsRoot,
    "..",
    "mobile",
    "lib",
    "modules",
    "merchant_claim",
    "models",
    "merchant_claim_evidence_policy.dart"
  );

  const backendSource = fs.readFileSync(backendPolicyPath, "utf8");
  const mobileSource = fs.readFileSync(mobilePolicyPath, "utf8");

  const backendAllowlist = parseQuotedStrings(
    backendSource,
    "CLAIM_ALLOWED_CATEGORY_IDS"
  );
  const mobileAllowlist = parseDartSet(mobileSource, "kClaimAllowedCategoryIds");

  assertSetEquals("backend CLAIM_ALLOWED_CATEGORY_IDS", backendAllowlist, EXPECTED_ALLOWLIST);
  assertSetEquals("mobile kClaimAllowedCategoryIds", mobileAllowlist, EXPECTED_ALLOWLIST);
  assertNoLegacy("backend CLAIM_ALLOWED_CATEGORY_IDS", backendAllowlist);
  assertNoLegacy("mobile kClaimAllowedCategoryIds", mobileAllowlist);

  console.log(
    JSON.stringify({
      check: "claim_categories_allowlist_guard",
      status: "ok",
      categories: normalize(EXPECTED_ALLOWLIST),
    })
  );
}

try {
  main();
} catch (error) {
  console.error("[claim_categories_allowlist_guard] failed");
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
