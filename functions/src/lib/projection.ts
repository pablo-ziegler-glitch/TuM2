import { FieldValue, Timestamp } from "firebase-admin/firestore";
import {
  MerchantDoc,
  MerchantPublicDoc,
  OperationalSignals,
  ScheduleSummary,
  TrustBadgeId,
  VerificationStatus,
} from "./types";
import { resolveOperationalPublicState } from "./operationalSignals";

const VERIFICATION_BOOST: Record<VerificationStatus, number> = {
  unverified: 30,
  community_submitted: 50,
  referential: 70,
  claimed: 85,
  validated: 90,
  verified: 100,
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
export function computeSortBoost(
  merchant: MerchantDoc,
  badges: TrustBadgeId[] = [],
  {
    pharmacyContext = false,
  }: {
    pharmacyContext?: boolean;
  } = {}
): number {
  let total = VERIFICATION_BOOST[merchant.verificationStatus] ?? 30;
  const badgeSet = new Set(badges);

  if (badgeSet.has("schedule_verified")) total += 10;
  if (badgeSet.has("schedule_updated")) total += 5;
  if (pharmacyContext && badgeSet.has("duty_loaded")) total += 15;

  return Math.min(total, 120);
}

const PRIMARY_TRUST_BADGE_PRIORITY: TrustBadgeId[] = [
  "duty_loaded",
  "schedule_verified",
  "verified_merchant",
  "claimed_by_owner",
  "validated_info",
  "schedule_updated",
  "community_info",
  "visible_in_tum2",
];

function toTimestamp(value: unknown): Timestamp | null {
  if (
    value &&
    typeof value === "object" &&
    "toMillis" in (value as Record<string, unknown>) &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return Timestamp.fromMillis((value as { toMillis: () => number }).toMillis());
  }
  if (value instanceof Date) return Timestamp.fromDate(value);
  if (typeof value === "number" && Number.isFinite(value)) {
    return Timestamp.fromMillis(value);
  }
  return null;
}

function ageDays(value: unknown): number | null {
  const ts = toTimestamp(value);
  if (!ts) return null;
  return (Date.now() - ts.toMillis()) / (1000 * 60 * 60 * 24);
}

function safeScheduleSummary(signals?: OperationalSignals): ScheduleSummary | null {
  const raw = (signals as Record<string, unknown> | undefined)?.["scheduleSummary"];
  if (!raw || typeof raw !== "object") return null;
  const data = raw as Record<string, unknown>;
  const windowsRaw = Array.isArray(data["todayWindows"]) ? data["todayWindows"] : [];
  const todayWindows = windowsRaw
    .map((window) => {
      if (!window || typeof window !== "object") return null;
      const windowData = window as Record<string, unknown>;
      const opens = windowData["opensAtLocalMinutes"];
      const closes = windowData["closesAtLocalMinutes"];
      if (typeof opens !== "number" || typeof closes !== "number") return null;
      return {
        opensAtLocalMinutes: Math.max(0, Math.min(1439, Math.round(opens))),
        closesAtLocalMinutes: Math.max(0, Math.min(1439, Math.round(closes))),
      };
    })
    .filter((window): window is { opensAtLocalMinutes: number; closesAtLocalMinutes: number } => window != null);

  const output: ScheduleSummary = {
    timezone:
      typeof data["timezone"] === "string" && data["timezone"].trim().length > 0
        ? (data["timezone"] as string).trim()
        : "America/Argentina/Buenos_Aires",
    todayWindows,
    hasSchedule: data["hasSchedule"] === true,
  };
  const scheduleLastUpdatedAt = toTimestamp(data["scheduleLastUpdatedAt"]);
  if (scheduleLastUpdatedAt) output.scheduleLastUpdatedAt = scheduleLastUpdatedAt;
  const lastVerifiedAt = toTimestamp(data["lastVerifiedAt"]);
  if (lastVerifiedAt) output.lastVerifiedAt = lastVerifiedAt;
  return output;
}

export function computeTrustBadges(
  merchant: MerchantDoc,
  signals?: OperationalSignals
): TrustBadgeId[] {
  const badges: TrustBadgeId[] = [];
  const categoryId = resolveCategoryId(merchant).toLowerCase();
  const scheduleSummary = safeScheduleSummary(signals);
  const scheduleLastUpdatedDays = ageDays(scheduleSummary?.scheduleLastUpdatedAt);
  const lastVerifiedAt = scheduleSummary?.lastVerifiedAt ?? merchant.lastVerifiedAt;
  const lastVerifiedAgeDays = ageDays(lastVerifiedAt);
  const verification = merchant.verificationStatus;
  const sourceType = merchant.sourceType;
  const signalMap = (signals ?? {}) as Record<string, unknown>;
  const isOnDutyToday =
    signalMap["hasPharmacyDutyToday"] === true || signalMap["isOnDutyToday"] === true;
  const pharmacyDutyStatus =
    typeof signalMap["pharmacyDutyStatus"] === "string"
      ? String(signalMap["pharmacyDutyStatus"]).trim().toLowerCase()
      : "";

  const lifecycleStatus = (merchant.status ?? "active").trim().toLowerCase();
  if (lifecycleStatus === "active" && merchant.visibilityStatus === "visible") {
    badges.push("visible_in_tum2");
  }
  if (scheduleLastUpdatedDays != null && scheduleLastUpdatedDays <= 30) {
    badges.push("schedule_updated");
  }
  if (
    (verification === "claimed" || verification === "validated" || verification === "verified") &&
    scheduleSummary?.hasSchedule === true &&
    lastVerifiedAgeDays != null &&
    lastVerifiedAgeDays <= 45
  ) {
    badges.push("schedule_verified");
  }
  if (
    categoryId === "pharmacy" &&
    isOnDutyToday &&
    pharmacyDutyStatus === "published"
  ) {
    badges.push("duty_loaded");
  }
  if (sourceType === "community_suggested" || verification === "community_submitted") {
    badges.push("community_info");
  }
  if (verification === "claimed" && merchant.ownerUserId) {
    badges.push("claimed_by_owner");
  }
  if (verification === "validated") {
    badges.push("validated_info");
  }
  if (verification === "verified" && lastVerifiedAt) {
    badges.push("verified_merchant");
  }

  return badges;
}

export function computePrimaryTrustBadge(
  badges: TrustBadgeId[]
): TrustBadgeId | undefined {
  const set = new Set(badges);
  for (const candidate of PRIMARY_TRUST_BADGE_PRIORITY) {
    if (set.has(candidate)) return candidate;
  }
  return undefined;
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

function resolveCategoryId(merchant: MerchantDoc): string {
  return (merchant.categoryId ?? merchant.category ?? "").trim();
}

function resolveZoneId(merchant: MerchantDoc): string {
  return (merchant.zoneId ?? merchant.zone ?? "").trim();
}

function toMillis(value: unknown): number | null {
  if (
    value &&
    typeof value === "object" &&
    "toMillis" in (value as Record<string, unknown>) &&
    typeof (value as { toMillis?: unknown }).toMillis === "function"
  ) {
    return (value as { toMillis: () => number }).toMillis();
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

function resolve24hForProjection(
  merchant: MerchantDoc,
  signals: OperationalSignals | undefined,
  isOpenNow: boolean
): { is24h: boolean; cooldownUntilMs: number | null; strikeCount: number } {
  const signalMap = (signals ?? {}) as Record<string, unknown>;
  const manual24h = signalMap["is24h"] === true || merchant.is24h === true;
  const cooldownUntilMs = toMillis(signalMap["twentyFourHourCooldownUntil"]);
  const strikeCountRaw = signalMap["twentyFourHourStrikeCount"];
  const strikeCount = typeof strikeCountRaw === "number" ? Math.max(0, strikeCountRaw) : 0;
  const inCooldown = cooldownUntilMs != null && cooldownUntilMs > Date.now();
  const visible24h = manual24h && !inCooldown && isOpenNow;
  return {
    is24h: visible24h,
    cooldownUntilMs,
    strikeCount,
  };
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
  const categoryId = resolveCategoryId(merchant);
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
  const categoryId = resolveCategoryId(merchant);
  const zoneId = resolveZoneId(merchant);
  const trustBadges = computeTrustBadges(merchant, signals);
  const primaryTrustBadge = computePrimaryTrustBadge(trustBadges);
  const sortBoost = computeSortBoost(merchant, trustBadges, {
    pharmacyContext: categoryId.toLowerCase() === "pharmacy",
  });
  const signalMap = (signals ?? {}) as Record<string, unknown>;
  const scheduleSummary = safeScheduleSummary(signals);
  const nextOpenAt = toTimestamp(signalMap["nextOpenAt"]);
  const nextCloseAt = toTimestamp(signalMap["nextCloseAt"]);
  const nextTransitionAt = toTimestamp(signalMap["nextTransitionAt"]);
  const snapshotComputedAt = toTimestamp(signalMap["snapshotComputedAt"]);
  const isOpenNowSnapshot = signalMap["isOpenNowSnapshot"] === true;

  const projection: Omit<MerchantPublicDoc, "syncedAt"> = {
    merchantId: merchant.merchantId,
    name: merchant.name,
    category: categoryId,
    categoryId: categoryId,
    zone: zoneId,
    zoneId: zoneId,
    verificationStatus: merchant.verificationStatus,
    visibilityStatus: merchant.visibilityStatus,
    badges: trustBadges,
    primaryTrustBadge,
    sortBoost,
    searchKeywords: buildSearchKeywords(merchant),
  };

  if (merchant.address) projection.address = merchant.address;
  if (merchant.isPharmacy) projection.isPharmacy = merchant.isPharmacy;

  const resolvedOperational = resolveOperationalPublicState(signals);
  projection.isOpenNow = resolvedOperational.isOpenNow;
  projection.isOpenNowSnapshot = isOpenNowSnapshot;
  if (snapshotComputedAt) projection.snapshotComputedAt = snapshotComputedAt;
  projection.todayScheduleLabel = resolvedOperational.todayScheduleLabel;
  if (scheduleSummary) projection.scheduleSummary = scheduleSummary;
  if (nextOpenAt) projection.nextOpenAt = nextOpenAt;
  if (nextCloseAt) projection.nextCloseAt = nextCloseAt;
  if (nextTransitionAt) projection.nextTransitionAt = nextTransitionAt;
  projection.hasPharmacyDutyToday = resolvedOperational.hasPharmacyDutyToday;
  projection.isOnDutyToday = resolvedOperational.hasPharmacyDutyToday;
  projection.hasOperationalSignal = resolvedOperational.hasOperationalSignal;
  projection.operationalSignalType = resolvedOperational.operationalSignalType;
  projection.operationalSignalMessage = resolvedOperational.operationalSignalMessage;
  projection.manualOverrideMode = resolvedOperational.manualOverrideMode;
  projection.operationalStatusLabel = resolvedOperational.operationalStatusLabel;
  projection.operationalSignals = resolvedOperational.operationalSignals;
  const h24 = resolve24hForProjection(merchant, signals, resolvedOperational.isOpenNow);
  projection.is24h = h24.is24h;
  projection.twentyFourHourStrikeCount = h24.strikeCount;
  projection.twentyFourHourCooldownUntil = h24.cooldownUntilMs != null
    ? Timestamp.fromMillis(h24.cooldownUntilMs)
    : null;

  return projection;
}

// Re-export FieldValue for use in triggers
export { FieldValue };
