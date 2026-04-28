export type CatalogLimitSource =
  | "merchant_override"
  | "category_override"
  | "global_default";

export interface CatalogLimitsConfigDoc {
  defaultProductLimit: number;
  categoryLimits: Record<string, number>;
}

export interface MerchantCatalogLimitsSnapshot {
  productLimitOverride?: number | null;
}

export interface MerchantCatalogStatsSnapshot {
  activeProductCount?: number;
}

export interface MerchantCatalogSnapshot {
  categoryId?: string;
  category?: string;
  catalogLimits?: MerchantCatalogLimitsSnapshot;
  catalogStats?: MerchantCatalogStatsSnapshot;
  ownerUserId?: string | null;
}

export interface ResolvedCatalogLimit {
  effectiveLimit: number;
  limitSource: CatalogLimitSource;
}

const DEFAULT_PRODUCT_LIMIT = 100;
const MIN_PRODUCT_LIMIT = 1;
const MAX_PRODUCT_LIMIT = 100000;

const FORBIDDEN_CATEGORY_IDS = new Set<string>(["bakery_confiteria"]);

function toSafeInt(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  if (!Number.isInteger(value)) return null;
  return value;
}

function isValidProductLimit(value: unknown): value is number {
  const parsed = toSafeInt(value);
  if (parsed == null) return false;
  return parsed >= MIN_PRODUCT_LIMIT && parsed <= MAX_PRODUCT_LIMIT;
}

export function sanitizeCategoryId(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().toLowerCase();
}

export function isAllowedCatalogCategoryId(categoryId: string): boolean {
  const normalized = sanitizeCategoryId(categoryId);
  if (!normalized) return false;
  if (FORBIDDEN_CATEGORY_IDS.has(normalized)) return false;
  return /^[a-z0-9_]+$/.test(normalized);
}

export function resolveMerchantCategoryId(merchant: MerchantCatalogSnapshot): string {
  const normalizedCategoryId = sanitizeCategoryId(merchant.categoryId);
  if (normalizedCategoryId.length > 0) return normalizedCategoryId;
  return sanitizeCategoryId(merchant.category);
}

export function normalizeCatalogLimitsConfig(
  raw: Record<string, unknown> | undefined
): CatalogLimitsConfigDoc {
  const defaultLimitRaw = raw?.["defaultProductLimit"];
  const defaultProductLimit = isValidProductLimit(defaultLimitRaw)
    ? defaultLimitRaw
    : DEFAULT_PRODUCT_LIMIT;

  const normalizedCategoryLimits: Record<string, number> = {};
  const categoryLimitsRaw = raw?.["categoryLimits"];
  if (
    categoryLimitsRaw &&
    typeof categoryLimitsRaw === "object" &&
    !Array.isArray(categoryLimitsRaw)
  ) {
    for (const [key, value] of Object.entries(
      categoryLimitsRaw as Record<string, unknown>
    )) {
      const categoryId = sanitizeCategoryId(key);
      if (!categoryId) continue;
      if (!isAllowedCatalogCategoryId(categoryId)) continue;
      if (!isValidProductLimit(value)) continue;
      normalizedCategoryLimits[categoryId] = value;
    }
  }

  return {
    defaultProductLimit,
    categoryLimits: normalizedCategoryLimits,
  };
}

export function resolveEffectiveCatalogLimit(params: {
  merchant: MerchantCatalogSnapshot;
  catalogConfig: CatalogLimitsConfigDoc;
}): ResolvedCatalogLimit {
  const { merchant, catalogConfig } = params;

  const merchantOverride = merchant.catalogLimits?.productLimitOverride;
  if (isValidProductLimit(merchantOverride)) {
    return {
      effectiveLimit: merchantOverride,
      limitSource: "merchant_override",
    };
  }

  const categoryId = resolveMerchantCategoryId(merchant);
  const categoryLimit = catalogConfig.categoryLimits[categoryId];
  if (isValidProductLimit(categoryLimit)) {
    return {
      effectiveLimit: categoryLimit,
      limitSource: "category_override",
    };
  }

  return {
    effectiveLimit: catalogConfig.defaultProductLimit,
    limitSource: "global_default",
  };
}

export function resolveActiveProductCount(merchant: MerchantCatalogSnapshot): number {
  const count = toSafeInt(merchant.catalogStats?.activeProductCount);
  if (count == null || count < 0) return 0;
  return count;
}

export function normalizeProductLimitInput(value: unknown): number | null {
  const parsed = toSafeInt(value);
  if (parsed == null) return null;
  if (parsed < MIN_PRODUCT_LIMIT || parsed > MAX_PRODUCT_LIMIT) return null;
  return parsed;
}
