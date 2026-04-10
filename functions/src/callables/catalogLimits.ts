import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  CatalogLimitSource,
  MerchantCatalogSnapshot,
  isAllowedCatalogCategoryId,
  normalizeCatalogLimitsConfig,
  normalizeProductLimitInput,
  resolveActiveProductCount,
  resolveEffectiveCatalogLimit,
  sanitizeCategoryId,
} from "../lib/catalogLimits";

const db = () => getFirestore();
const CATALOG_LIMITS_CONFIG_PATH = "admin_configs/catalog_limits";

type Role = "owner" | "admin" | "super_admin" | "customer" | "unknown";
type ProductStockStatus = "available" | "out_of_stock";
type ProductVisibilityStatus = "visible" | "hidden";
type ProductStatus = "active" | "inactive";
type ProductImageUploadStatus = "pending" | "ready" | "failed";

interface SetGlobalCatalogProductLimitRequest {
  defaultProductLimit?: number;
}

interface SetCategoryCatalogProductLimitRequest {
  categoryId?: string;
  productLimit?: number;
}

interface ClearCategoryCatalogProductLimitRequest {
  categoryId?: string;
}

interface SetMerchantCatalogLimitOverrideRequest {
  merchantId?: string;
  productLimitOverride?: number;
}

interface ClearMerchantCatalogLimitOverrideRequest {
  merchantId?: string;
}

interface CatalogLimitMutationResponse {
  success: true;
}

interface SearchCatalogLimitMerchantsRequest {
  query?: string;
  limit?: number;
}

interface SearchCatalogLimitMerchantRow {
  merchantId: string;
  name: string;
  legalName: string;
  fantasyName: string;
  categoryId: string;
  zoneId: string;
  activeProductCount: number;
  overrideLimit: number | null;
  effectiveLimit: number;
  limitSource: CatalogLimitSource;
  usageRatio: number;
  usagePercent: number;
  status: string;
  visibilityStatus: string;
}

interface SearchCatalogLimitMerchantsResponse {
  query: string;
  merchants: SearchCatalogLimitMerchantRow[];
}

interface CreateMerchantProductRequest {
  merchantId?: string;
  productId?: string;
  name?: string;
  priceLabel?: string;
  stockStatus?: ProductStockStatus;
  visibilityStatus?: ProductVisibilityStatus;
  status?: ProductStatus;
  imageUrl?: string | null;
  imagePath?: string | null;
  imageUploadStatus?: ProductImageUploadStatus | null;
}

interface CreateMerchantProductResponse {
  merchantId: string;
  productId: string;
  activeProductCount: number;
  effectiveLimit: number;
  limitSource: CatalogLimitSource;
  usageRatio: number;
}

interface DeactivateMerchantProductRequest {
  merchantId?: string;
  productId?: string;
}

interface DeactivateMerchantProductResponse {
  merchantId: string;
  productId: string;
  activeProductCount: number;
}

function normalizeRole(raw: unknown): Role {
  if (typeof raw !== "string") return "unknown";
  const normalized = raw.trim().toLowerCase();
  if (normalized === "owner") return "owner";
  if (normalized === "admin") return "admin";
  if (normalized === "super_admin") return "super_admin";
  if (normalized === "customer") return "customer";
  return "unknown";
}

function assertAuthenticated(
  auth: { uid: string; token: Record<string, unknown> } | null | undefined
): { uid: string; token: Record<string, unknown> } {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Autenticación requerida.");
  }
  return auth;
}

function assertAdminRole(role: Role): void {
  if (role === "admin" || role === "super_admin") return;
  throw new HttpsError(
    "permission-denied",
    "Solo ADMIN o SUPER_ADMIN pueden modificar límites de catálogo."
  );
}

function assertOwnerOrAdminRole(role: Role): void {
  if (role === "owner" || role === "admin" || role === "super_admin") return;
  throw new HttpsError(
    "permission-denied",
    "No tenés permisos para gestionar productos."
  );
}

function normalizeRequiredString(value: unknown, field: string): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new HttpsError("invalid-argument", `${field} es requerido.`);
  }
  return normalized;
}

function normalizeProductId(value: unknown): string {
  const normalized = normalizeRequiredString(value, "productId");
  if (!/^[A-Za-z0-9_-]{10,40}$/.test(normalized)) {
    throw new HttpsError("invalid-argument", "productId inválido.");
  }
  return normalized;
}

function normalizeLimitInput(value: unknown, field: string): number {
  const normalized = normalizeProductLimitInput(value);
  if (normalized == null) {
    throw new HttpsError(
      "invalid-argument",
      `${field} debe ser un entero positivo entre 1 y 100000.`
    );
  }
  return normalized;
}

function normalizeProductName(value: unknown): string {
  const normalized = normalizeRequiredString(value, "name");
  if (normalized.length < 2 || normalized.length > 80) {
    throw new HttpsError(
      "invalid-argument",
      "name debe tener entre 2 y 80 caracteres."
    );
  }
  return normalized.replace(/\s+/g, " ");
}

function normalizePriceLabel(value: unknown): string {
  const normalized = normalizeRequiredString(value, "priceLabel");
  if (normalized.length > 60) {
    throw new HttpsError(
      "invalid-argument",
      "priceLabel no puede superar 60 caracteres."
    );
  }
  return normalized.replace(/\s+/g, " ");
}

function normalizeNormalizedName(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function buildProductSearchKeywords(name: string): string[] {
  const normalizedName = normalizeNormalizedName(name);
  if (!normalizedName) return [];
  const tokens = normalizedName
    .split(" ")
    .map((token) => token.trim())
    .filter((token) => token.length > 0);
  const keywords = new Set<string>([normalizedName]);
  for (const token of tokens) {
    const minPrefixLength = token.length >= 2 ? 2 : 1;
    for (let size = minPrefixLength; size <= token.length; size++) {
      keywords.add(token.substring(0, size));
    }
  }
  return [...keywords].slice(0, 40);
}

function normalizeStockStatus(value: unknown): ProductStockStatus {
  if (value == null) return "available";
  if (value === "available" || value === "out_of_stock") return value;
  throw new HttpsError("invalid-argument", "stockStatus inválido.");
}

function normalizeVisibilityStatus(value: unknown): ProductVisibilityStatus {
  if (value == null) return "visible";
  if (value === "visible" || value === "hidden") return value;
  throw new HttpsError("invalid-argument", "visibilityStatus inválido.");
}

function normalizeProductStatus(value: unknown): ProductStatus {
  if (value == null) return "active";
  if (value === "active" || value === "inactive") return value;
  throw new HttpsError("invalid-argument", "status inválido.");
}

function normalizeOptionalImageUrl(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "imageUrl inválido.");
  }
  const normalized = value.trim();
  if (!normalized) return null;
  if (normalized.length > 1500) {
    throw new HttpsError("invalid-argument", "imageUrl excede 1500 caracteres.");
  }
  return normalized;
}

function normalizeOptionalImagePath(
  value: unknown,
  merchantId: string,
  productId: string
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "imagePath inválido.");
  }
  const normalized = value.trim();
  if (!normalized) return null;
  const expected = `merchant-products/${merchantId}/${productId}/cover.jpg`;
  if (normalized !== expected) {
    throw new HttpsError(
      "invalid-argument",
      "imagePath debe respetar el path canónico del producto."
    );
  }
  return normalized;
}

function normalizeOptionalImageUploadStatus(
  value: unknown
): ProductImageUploadStatus | null {
  if (value == null) return null;
  if (value === "pending" || value === "ready" || value === "failed") {
    return value;
  }
  throw new HttpsError("invalid-argument", "imageUploadStatus inválido.");
}

function merchantOwnerUserId(merchantData: Record<string, unknown>): string {
  const owner = merchantData["ownerUserId"];
  return typeof owner === "string" ? owner.trim() : "";
}

function resolveMerchantCategoryId(merchantData: Record<string, unknown>): string {
  const categoryId = merchantData["categoryId"];
  if (typeof categoryId === "string" && categoryId.trim().length > 0) {
    return categoryId.trim().toLowerCase();
  }
  const category = merchantData["category"];
  if (typeof category === "string" && category.trim().length > 0) {
    return category.trim().toLowerCase();
  }
  return "";
}

function resolveMerchantZoneId(merchantData: Record<string, unknown>): string {
  const zoneId = merchantData["zoneId"];
  if (typeof zoneId === "string" && zoneId.trim().length > 0) {
    return zoneId.trim().toLowerCase();
  }
  const zone = merchantData["zone"];
  if (typeof zone === "string" && zone.trim().length > 0) {
    return zone.trim().toLowerCase();
  }
  return "";
}

function usageRatio(count: number, limit: number): number {
  if (limit <= 0) return 0;
  return Number((count / limit).toFixed(4));
}

function usagePercent(count: number, limit: number): number {
  if (limit <= 0) return 0;
  return Math.round((count / limit) * 100);
}

export const setGlobalCatalogProductLimit = onCall<
  SetGlobalCatalogProductLimitRequest,
  Promise<CatalogLimitMutationResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const defaultProductLimit = normalizeLimitInput(
    request.data.defaultProductLimit,
    "defaultProductLimit"
  );

  await db().doc(CATALOG_LIMITS_CONFIG_PATH).set(
    {
      defaultProductLimit,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: auth.uid,
    },
    { merge: true }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "set_global_limit",
      actorUid: auth.uid,
      defaultProductLimit,
    })
  );

  return { success: true };
});

export const setCategoryCatalogProductLimit = onCall<
  SetCategoryCatalogProductLimitRequest,
  Promise<CatalogLimitMutationResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const categoryId = sanitizeCategoryId(
    normalizeRequiredString(request.data.categoryId, "categoryId")
  );
  if (!isAllowedCatalogCategoryId(categoryId)) {
    throw new HttpsError("invalid-argument", "categoryId inválido para el MVP.");
  }
  const productLimit = normalizeLimitInput(request.data.productLimit, "productLimit");

  await db().doc(CATALOG_LIMITS_CONFIG_PATH).set(
    {
      categoryLimits: {
        [categoryId]: productLimit,
      },
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: auth.uid,
    },
    { merge: true }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "set_category_limit",
      actorUid: auth.uid,
      categoryId,
      productLimit,
    })
  );

  return { success: true };
});

export const clearCategoryCatalogProductLimit = onCall<
  ClearCategoryCatalogProductLimitRequest,
  Promise<CatalogLimitMutationResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const categoryId = sanitizeCategoryId(
    normalizeRequiredString(request.data.categoryId, "categoryId")
  );
  if (!isAllowedCatalogCategoryId(categoryId)) {
    throw new HttpsError("invalid-argument", "categoryId inválido para el MVP.");
  }

  await db().doc(CATALOG_LIMITS_CONFIG_PATH).set(
    {
      categoryLimits: {
        [categoryId]: FieldValue.delete(),
      },
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: auth.uid,
    },
    { merge: true }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "clear_category_limit",
      actorUid: auth.uid,
      categoryId,
    })
  );

  return { success: true };
});

export const setMerchantCatalogLimitOverride = onCall<
  SetMerchantCatalogLimitOverrideRequest,
  Promise<CatalogLimitMutationResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const merchantId = normalizeRequiredString(request.data.merchantId, "merchantId");
  const productLimitOverride = normalizeLimitInput(
    request.data.productLimitOverride,
    "productLimitOverride"
  );

  const merchantRef = db().doc(`merchants/${merchantId}`);
  const merchantSnap = await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", "Comercio no encontrado.");
  }

  await merchantRef.set(
    {
      catalogLimits: {
        productLimitOverride,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "set_merchant_override",
      actorUid: auth.uid,
      merchantId,
      productLimitOverride,
    })
  );

  return { success: true };
});

export const clearMerchantCatalogLimitOverride = onCall<
  ClearMerchantCatalogLimitOverrideRequest,
  Promise<CatalogLimitMutationResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const merchantId = normalizeRequiredString(request.data.merchantId, "merchantId");
  const merchantRef = db().doc(`merchants/${merchantId}`);
  const merchantSnap = await merchantRef.get();
  if (!merchantSnap.exists) {
    throw new HttpsError("not-found", "Comercio no encontrado.");
  }

  await merchantRef.set(
    {
      catalogLimits: {
        productLimitOverride: null,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "clear_merchant_override",
      actorUid: auth.uid,
      merchantId,
    })
  );

  return { success: true };
});

export const searchCatalogLimitMerchants = onCall<
  SearchCatalogLimitMerchantsRequest,
  Promise<SearchCatalogLimitMerchantsResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const normalizedQuery = normalizeNormalizedName(request.data.query ?? "");
  if (normalizedQuery.length < 2) {
    return { query: normalizedQuery, merchants: [] };
  }

  const safeLimit = Math.min(
    Math.max(
      normalizeProductLimitInput(request.data.limit ?? 20) ?? 20,
      1
    ),
    30
  );

  const [configSnap, merchantsSnap] = await Promise.all([
    db().doc(CATALOG_LIMITS_CONFIG_PATH).get(),
    db()
      .collection("merchants")
      .orderBy("normalizedName")
      .startAt(normalizedQuery)
      .endAt(`${normalizedQuery}\uf8ff`)
      .limit(safeLimit)
      .get(),
  ]);

  const catalogConfig = normalizeCatalogLimitsConfig(
    configSnap.data() as Record<string, unknown> | undefined
  );

  const merchants = merchantsSnap.docs
    .map((doc) => {
      const data = doc.data() as Record<string, unknown>;
      const snapshot: MerchantCatalogSnapshot = {
        categoryId: resolveMerchantCategoryId(data),
        catalogLimits: {
          productLimitOverride:
            (data["catalogLimits"] as { productLimitOverride?: unknown } | undefined)
              ?.productLimitOverride as number | null | undefined,
        },
        catalogStats: {
          activeProductCount:
            (data["catalogStats"] as { activeProductCount?: unknown } | undefined)
              ?.activeProductCount as number | undefined,
        },
      };
      const resolved = resolveEffectiveCatalogLimit({
        merchant: snapshot,
        catalogConfig,
      });
      const activeProductCount = resolveActiveProductCount(snapshot);

      return {
        merchantId: doc.id,
        name: (data["name"] as string | undefined)?.trim() ?? "",
        legalName: (data["razonSocial"] as string | undefined)?.trim() ?? "",
        fantasyName:
          (data["nombreFantasia"] as string | undefined)?.trim() ?? "",
        categoryId: resolveMerchantCategoryId(data),
        zoneId: resolveMerchantZoneId(data),
        activeProductCount,
        overrideLimit:
          snapshot.catalogLimits?.productLimitOverride == null
            ? null
            : normalizeProductLimitInput(
                snapshot.catalogLimits?.productLimitOverride
              ),
        effectiveLimit: resolved.effectiveLimit,
        limitSource: resolved.limitSource,
        usageRatio: usageRatio(activeProductCount, resolved.effectiveLimit),
        usagePercent: usagePercent(activeProductCount, resolved.effectiveLimit),
        status: (data["status"] as string | undefined)?.trim() ?? "",
        visibilityStatus:
          (data["visibilityStatus"] as string | undefined)?.trim() ?? "",
      } satisfies SearchCatalogLimitMerchantRow;
    })
    .filter((row) => {
      const haystack = normalizeNormalizedName(
        `${row.name} ${row.legalName} ${row.fantasyName}`
      );
      return haystack.includes(normalizedQuery);
    });

  return {
    query: normalizedQuery,
    merchants,
  };
});

export const createMerchantProduct = onCall<
  CreateMerchantProductRequest,
  Promise<CreateMerchantProductResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertOwnerOrAdminRole(role);

  const merchantId = normalizeRequiredString(request.data.merchantId, "merchantId");
  const productId = request.data.productId?.trim().length
    ? normalizeProductId(request.data.productId)
    : db().collection("merchant_products").doc().id;
  const name = normalizeProductName(request.data.name);
  const priceLabel = normalizePriceLabel(request.data.priceLabel);
  const stockStatus = normalizeStockStatus(request.data.stockStatus);
  const visibilityStatus = normalizeVisibilityStatus(request.data.visibilityStatus);
  const status = normalizeProductStatus(request.data.status);
  const imageUrl = normalizeOptionalImageUrl(request.data.imageUrl);
  const imagePath = normalizeOptionalImagePath(
    request.data.imagePath,
    merchantId,
    productId
  );
  const imageUploadStatus = normalizeOptionalImageUploadStatus(
    request.data.imageUploadStatus
  );

  if ((imageUrl == null) != (imagePath == null)) {
    throw new HttpsError(
      "invalid-argument",
      "imageUrl e imagePath deben enviarse juntos."
    );
  }

  if (imagePath != null && imageUploadStatus !== "ready") {
    throw new HttpsError(
      "invalid-argument",
      "imageUploadStatus debe ser 'ready' cuando se envía imagen."
    );
  }

  const merchantRef = db().doc(`merchants/${merchantId}`);
  const productRef = db().doc(`merchant_products/${productId}`);
  const configRef = db().doc(CATALOG_LIMITS_CONFIG_PATH);
  const response = await db().runTransaction<CreateMerchantProductResponse>(
    async (tx) => {
      const [merchantSnap, configSnap, productSnap] = await Promise.all([
        tx.get(merchantRef),
        tx.get(configRef),
        tx.get(productRef),
      ]);

    if (!merchantSnap.exists) {
      throw new HttpsError("not-found", "Comercio no encontrado.");
    }
    if (productSnap.exists) {
      throw new HttpsError("already-exists", "productId ya existe.");
    }

    const merchantData = merchantSnap.data() as Record<string, unknown>;
    const ownerUserId = merchantOwnerUserId(merchantData);
    if (!ownerUserId) {
      throw new HttpsError(
        "failed-precondition",
        "El comercio no tiene owner asignado."
      );
    }
    if (role === "owner" && ownerUserId !== auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "No podés crear productos para otro comercio."
      );
    }

    const catalogConfig = normalizeCatalogLimitsConfig(
      configSnap.data() as Record<string, unknown> | undefined
    );
    const resolved = resolveEffectiveCatalogLimit({
      merchant: {
        categoryId: resolveMerchantCategoryId(merchantData),
        catalogLimits:
          (merchantData["catalogLimits"] as { productLimitOverride?: number | null } | undefined) ??
          undefined,
        catalogStats:
          (merchantData["catalogStats"] as { activeProductCount?: number } | undefined) ??
          undefined,
      },
      catalogConfig,
    });
    const currentCount = resolveActiveProductCount({
      catalogStats:
        (merchantData["catalogStats"] as { activeProductCount?: number } | undefined) ??
        undefined,
    });

    const willConsumeQuota = status === "active";
    if (willConsumeQuota && currentCount >= resolved.effectiveLimit) {
      throw new HttpsError(
        "failed-precondition",
        "Límite de catálogo alcanzado.",
        {
          code: "catalog_limit_reached",
          activeProductCount: currentCount,
          effectiveLimit: resolved.effectiveLimit,
          limitSource: resolved.limitSource,
        }
      );
    }

    const normalizedName = normalizeNormalizedName(name);
    tx.set(productRef, {
      id: productId,
      merchantId,
      ownerUserId,
      name,
      normalizedName,
      searchKeywords: buildProductSearchKeywords(name),
      priceLabel,
      stockStatus,
      visibilityStatus,
      status,
      sourceType: "owner_created",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: auth.uid,
      updatedBy: auth.uid,
      ...(imageUrl ? { imageUrl } : {}),
      ...(imagePath ? { imagePath } : {}),
      ...(imageUploadStatus ? { imageUploadStatus } : {}),
    });

    const nextCount = willConsumeQuota ? currentCount + 1 : currentCount;
    if (willConsumeQuota) {
      tx.set(
        merchantRef,
        {
          catalogStats: {
            activeProductCount: nextCount,
            updatedAt: FieldValue.serverTimestamp(),
          },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    return {
      merchantId,
      productId,
      activeProductCount: nextCount,
      effectiveLimit: resolved.effectiveLimit,
      limitSource: resolved.limitSource,
      usageRatio: usageRatio(nextCount, resolved.effectiveLimit),
    };
    }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "create_merchant_product",
      actorUid: auth.uid,
      merchantId: response.merchantId,
      productId: response.productId,
      activeProductCount: response.activeProductCount,
      effectiveLimit: response.effectiveLimit,
      limitSource: response.limitSource,
    })
  );

  return response;
});

export const deactivateMerchantProduct = onCall<
  DeactivateMerchantProductRequest,
  Promise<DeactivateMerchantProductResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertOwnerOrAdminRole(role);

  const merchantId = normalizeRequiredString(request.data.merchantId, "merchantId");
  const productId = normalizeRequiredString(request.data.productId, "productId");

  const merchantRef = db().doc(`merchants/${merchantId}`);
  const productRef = db().doc(`merchant_products/${productId}`);
  const response = await db().runTransaction<DeactivateMerchantProductResponse>(
    async (tx) => {
      const [merchantSnap, productSnap] = await Promise.all([
        tx.get(merchantRef),
        tx.get(productRef),
      ]);

    if (!merchantSnap.exists) {
      throw new HttpsError("not-found", "Comercio no encontrado.");
    }
    if (!productSnap.exists) {
      throw new HttpsError("not-found", "Producto no encontrado.");
    }

    const merchantData = merchantSnap.data() as Record<string, unknown>;
    const ownerUserId = merchantOwnerUserId(merchantData);
    if (!ownerUserId) {
      throw new HttpsError(
        "failed-precondition",
        "El comercio no tiene owner asignado."
      );
    }
    if (role === "owner" && ownerUserId !== auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "No podés modificar productos de otro comercio."
      );
    }

    const productData = productSnap.data() as Record<string, unknown>;
    const productMerchantId =
      typeof productData["merchantId"] === "string"
        ? productData["merchantId"].trim()
        : "";
    if (!productMerchantId || productMerchantId !== merchantId) {
      throw new HttpsError(
        "failed-precondition",
        "El producto no pertenece al comercio indicado."
      );
    }

    const productOwnerUserId =
      typeof productData["ownerUserId"] === "string"
        ? productData["ownerUserId"].trim()
        : "";
    if (role === "owner" && productOwnerUserId !== auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "No podés modificar productos de otro comercio."
      );
    }

    const currentStatus =
      typeof productData["status"] === "string"
        ? (productData["status"] as ProductStatus)
        : "inactive";
    if (currentStatus !== "active" && currentStatus !== "inactive") {
      throw new HttpsError("failed-precondition", "Estado de producto inválido.");
    }

    const currentCount = resolveActiveProductCount({
      catalogStats:
        (merchantData["catalogStats"] as { activeProductCount?: number } | undefined) ??
        undefined,
    });

    if (currentStatus === "active") {
      const nextCount = Math.max(0, currentCount - 1);
      tx.update(productRef, {
        status: "inactive",
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
      });
      tx.set(
        merchantRef,
        {
          catalogStats: {
            activeProductCount: nextCount,
            updatedAt: FieldValue.serverTimestamp(),
          },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        merchantId,
        productId,
        activeProductCount: nextCount,
      };
    }

    tx.update(productRef, {
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: auth.uid,
    });
    return {
      merchantId,
      productId,
      activeProductCount: currentCount,
    };
    }
  );

  console.log(
    JSON.stringify({
      source: "catalog_limits",
      action: "deactivate_merchant_product",
      actorUid: auth.uid,
      merchantId: response.merchantId,
      productId: response.productId,
      activeProductCount: response.activeProductCount,
    })
  );

  return response;
});
