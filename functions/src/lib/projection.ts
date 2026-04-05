import { FieldValue } from "firebase-admin/firestore";
import {
  MerchantDoc,
  MerchantPublicDoc,
  OperationalSignals,
  VerificationStatus,
} from "./types";

const VERIFICATION_BOOST: Record<VerificationStatus, number> = {
  verified: 40,
  validated: 35,
  claimed: 25,
  community_submitted: 8,
  referential: 5,
  unverified: 0,
};

const TOKEN_STOPWORDS = new Set([
  "de",
  "del",
  "la",
  "las",
  "el",
  "los",
  "y",
  "en",
  "al",
  "para",
  "por",
  "con",
]);

const ADDRESS_STOPWORDS = new Set([
  "calle",
  "nro",
  "numero",
  "num",
  ...TOKEN_STOPWORDS,
]);

const CATEGORY_ALIASES: Record<string, string[]> = {
  pharmacy: ["farmacia"],
  veterinary: ["veterinaria"],
  "veterinary clinic": ["veterinaria"],
  kiosk: ["kiosco"],
  "convenience store": ["kiosco"],
  grocery: ["almacen"],
  supermarket: ["supermercado"],
  "hardware store": ["ferreteria"],
  bakery: ["panaderia"],
};

const HONORIFIC_EQUIVALENTS: Record<string, string[]> = {
  dr: ["doctor", "doctora"],
  dra: ["doctora", "doctor"],
  prof: ["profesor", "profesora"],
  profesor: ["prof"],
  profesora: ["prof"],
  doctor: ["dr", "dra"],
  doctora: ["dr", "dra"],
};

/**
 * Computes the sortBoost score for a merchant.
 * Higher = appears earlier in zone listings.
 */
export function computeSortBoost(merchant: MerchantDoc): number {
  let boost = 0;

  // Verification tier
  boost += VERIFICATION_BOOST[merchant.verificationStatus] ?? 0;

  // Completeness
  boost += (merchant.completenessScore ?? 0) * 0.3;

  // Recent activity bonus (within last 30 days)
  if (merchant.lastActivityAt) {
    const msAgo =
      Date.now() - merchant.lastActivityAt.toMillis();
    const daysAgo = msAgo / (1000 * 60 * 60 * 24);
    if (daysAgo < 30) {
      boost += Math.max(0, 10 - daysAgo / 3);
    }
  }

  return Math.round(boost * 10) / 10;
}

function normalizeText(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function tokenize(
  value: string | undefined,
  {
    minLen = 3,
    stopwords = TOKEN_STOPWORDS,
    keepNumbers = false,
  }: {
    minLen?: number;
    stopwords?: Set<string>;
    keepNumbers?: boolean;
  } = {}
): string[] {
  if (!value) return [];
  const normalized = normalizeText(value);
  if (!normalized) return [];

  return normalized
    .split(" ")
    .filter((token) => token.length >= minLen)
    .filter((token) => !stopwords.has(token))
    .filter((token) => keepNumbers || !/^\d+$/.test(token));
}

function buildBigrams(tokens: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < tokens.length - 1; i++) {
    out.push(`${tokens[i]} ${tokens[i + 1]}`);
  }
  return out;
}

function resolveCategoryTokens(category: string | undefined): string[] {
  if (!category) return [];
  const normalizedCategory = normalizeText(category);
  if (!normalizedCategory) return [];

  const categoryTokens = tokenize(normalizedCategory, { minLen: 2 });
  const aliases = CATEGORY_ALIASES[normalizedCategory] ?? [];
  const aliasTokens = aliases.flatMap((alias) => tokenize(alias, { minLen: 2 }));
  return [
    normalizedCategory,
    ...categoryTokens,
    ...buildBigrams(categoryTokens),
    ...aliases,
    ...aliasTokens,
  ];
}

function expandHonorifics(tokens: string[]): string[] {
  const expansions = tokens.flatMap((token) => HONORIFIC_EQUIVALENTS[token] ?? []);
  return [...tokens, ...expansions];
}

function buildAddressTokens(address: string | undefined): string[] {
  if (!address) return [];
  const tokens = tokenize(address, {
    minLen: 2,
    stopwords: ADDRESS_STOPWORDS,
  });
  const normalized = normalizeText(address);
  if (!normalized) return tokens;

  const noNumbers = normalized.replace(/\d+/g, " ").replace(/\s+/g, " ").trim();
  const tokensNoNumbers = tokenize(noNumbers, {
    minLen: 2,
    stopwords: ADDRESS_STOPWORDS,
  });
  return [...tokens, ...tokensNoNumbers, ...buildBigrams(tokensNoNumbers)];
}

/**
 * Builds a normalized keyword corpus for client-side search on merchant_public.
 */
export function buildSearchKeywords(merchant: MerchantDoc): string[] {
  const categoryId = merchant.category;
  const nameTokens = expandHonorifics(tokenize(merchant.name, { minLen: 2 }));
  const categoryTokens = resolveCategoryTokens(categoryId);
  const addressTokens = buildAddressTokens(merchant.address);

  const keywords = [
    ...nameTokens,
    ...buildBigrams(nameTokens),
    ...categoryTokens,
    ...addressTokens,
  ];

  const unique = Array.from(new Set(keywords)).filter((token) => token.length > 0);
  return unique.slice(0, 30);
}

/**
 * Builds the full merchant_public projection from source docs.
 */
export function computeMerchantPublicProjection(
  merchant: MerchantDoc,
  signals?: OperationalSignals
): Omit<MerchantPublicDoc, "syncedAt"> {
  const sortBoost = computeSortBoost(merchant);

  const projection: Omit<MerchantPublicDoc, "syncedAt"> = {
    merchantId: merchant.merchantId,
    name: merchant.name,
    category: merchant.category,
    categoryId: merchant.category,
    zone: merchant.zone,
    zoneId: merchant.zoneId ?? merchant.zone,
    verificationStatus: merchant.verificationStatus,
    visibilityStatus: merchant.visibilityStatus,
    sortBoost,
    searchKeywords: buildSearchKeywords(merchant),
  };

  if (merchant.address) projection.address = merchant.address;
  if (merchant.isPharmacy) projection.isPharmacy = merchant.isPharmacy;

  if (signals) {
    projection.isOpenNow = signals.isOpenNow ?? false;
    projection.todayScheduleLabel = signals.todayScheduleLabel ?? "";
    projection.hasPharmacyDutyToday = signals.hasPharmacyDutyToday ?? false;
    projection.operationalSignals = signals;
  }

  return projection;
}

// Re-export FieldValue for use in triggers
export { FieldValue };
