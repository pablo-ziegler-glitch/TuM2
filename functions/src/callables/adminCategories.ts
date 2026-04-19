import {
  FieldPath,
  FieldValue,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  canonicalCategoryToken,
  isCanonicalCategoryToken,
  uniqueCategoryTokens,
} from "../lib/adminCategories";

const db = () => getFirestore();
const MAX_PAGE_SIZE = 50;
const DEFAULT_PAGE_SIZE = 20;
const CATALOG_LIMITS_CONFIG_PATH = "admin_configs/catalog_limits";

type Role = "owner" | "admin" | "super_admin" | "customer" | "unknown";

interface CategoryListItem {
  categoryId: string;
  label: string;
  iconName: string;
  aliases: string[];
  isActive: boolean;
  productLimit: number | null;
  updatedAtMillis: number | null;
}

interface ListAdminCategoriesRequest {
  limit?: unknown;
  cursor?: unknown;
  includeInactive?: unknown;
}

interface ListAdminCategoriesResponse {
  categories: CategoryListItem[];
  nextCursor: string | null;
}

interface UpsertAdminCategoryRequest {
  categoryId?: unknown;
  label?: unknown;
  iconName?: unknown;
  aliases?: unknown;
  isActive?: unknown;
}

interface UpsertAdminCategoryResponse {
  category: CategoryListItem;
}

interface ToggleAdminCategoryActiveRequest {
  categoryId?: unknown;
  isActive?: unknown;
}

interface ToggleAdminCategoryActiveResponse {
  success: true;
  categoryId: string;
  isActive: boolean;
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
    "Solo ADMIN o SUPER_ADMIN pueden administrar categorías."
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

function normalizeCategoryToken(value: unknown, field: string): string {
  const canonical = canonicalCategoryToken(normalizeRequiredString(value, field));
  if (!isCanonicalCategoryToken(canonical)) {
    throw new HttpsError(
      "invalid-argument",
      `${field} debe usar formato canónico: minúsculas, números y '_' (sin espacios).`
    );
  }
  if (canonical.length > 50) {
    throw new HttpsError("invalid-argument", `${field} no puede superar 50 caracteres.`);
  }
  return canonical;
}

function normalizeLabel(value: unknown): string {
  const normalized = normalizeRequiredString(value, "label").replace(/\s+/g, " ");
  if (normalized.length < 2 || normalized.length > 80) {
    throw new HttpsError("invalid-argument", "label debe tener entre 2 y 80 caracteres.");
  }
  return normalized;
}

function normalizeIconName(value: unknown): string {
  if (value == null) return "store";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "iconName debe ser un string.");
  }
  const normalized = value.trim();
  if (!normalized) return "store";
  if (!/^[a-z0-9_]{2,40}$/.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "iconName debe contener solo minúsculas, números y '_'."
    );
  }
  return normalized;
}

function normalizeAliases(value: unknown): string[] {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "aliases debe ser un arreglo.");
  }
  const aliases = new Set<string>();
  for (const entry of value) {
    const alias = normalizeCategoryToken(entry, "alias");
    aliases.add(alias);
  }
  return Array.from(aliases).sort();
}

function normalizeBoolean(value: unknown, field: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} debe ser boolean.`);
  }
  return value;
}

function toMillis(value: unknown): number | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as { toMillis?: () => number };
  if (typeof candidate.toMillis !== "function") return null;
  return candidate.toMillis();
}

function normalizeProductLimit(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isInteger(value)) return null;
  if (value < 1 || value > 100000) return null;
  return value;
}

function parsePageSize(value: unknown): number {
  if (typeof value !== "number" || !Number.isInteger(value)) return DEFAULT_PAGE_SIZE;
  return Math.max(1, Math.min(value, MAX_PAGE_SIZE));
}

function normalizeCursor(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "cursor inválido.");
  }
  const normalized = value.trim().toLowerCase();
  if (!normalized) return null;
  if (!isCanonicalCategoryToken(normalized)) {
    throw new HttpsError("invalid-argument", "cursor inválido.");
  }
  return normalized;
}

function toCategoryListItem(params: {
  categoryId: string;
  data: Record<string, unknown>;
  productLimit: number | null;
}): CategoryListItem {
  const { categoryId, data, productLimit } = params;
  const rawAliases = Array.isArray(data["aliases"]) ? data["aliases"] : [];
  const aliases = rawAliases
    .map((value) => (typeof value === "string" ? value.trim().toLowerCase() : ""))
    .filter((value) => value.length > 0)
    .filter((value) => isCanonicalCategoryToken(value));
  aliases.sort();

  return {
    categoryId,
    label:
      (typeof data["label"] === "string" && data["label"].trim().length > 0
        ? data["label"].trim()
        : categoryId),
    iconName:
      (typeof data["iconName"] === "string" && data["iconName"].trim().length > 0
        ? data["iconName"].trim()
        : "store"),
    aliases,
    isActive: data["isActive"] !== false,
    productLimit,
    updatedAtMillis: toMillis(data["updatedAt"]),
  };
}

function assertNoSelfAliasCollision(params: {
  categoryId: string;
  aliases: string[];
}): void {
  const { categoryId, aliases } = params;
  if (aliases.includes(categoryId)) {
    throw new HttpsError(
      "already-exists",
      "Una categoría no puede incluir su propio categoryId como alias."
    );
  }
}

async function assertNoTokenCollisionsInTx(
  tx: Transaction,
  params: {
  categoryId: string;
  aliases: string[];
  }
): Promise<void> {
  const { categoryId, aliases } = params;
  const categories = db().collection("categories");
  const tokens = uniqueCategoryTokens([categoryId, ...aliases]);

  for (const token of tokens) {
    const categoryByIdSnap = await tx.get(categories.doc(token));
    if (categoryByIdSnap.exists && categoryByIdSnap.id !== categoryId) {
      throw new HttpsError(
        "already-exists",
        `Colisión detectada: '${token}' ya existe como categoryId.`
      );
    }

    const aliasSnap = await tx.get(
      categories.where("aliases", "array-contains", token).limit(5)
    );
    for (const row of aliasSnap.docs) {
      if (row.id !== categoryId) {
        throw new HttpsError(
          "already-exists",
          `Colisión detectada: '${token}' ya pertenece a '${row.id}'.`
        );
      }
    }
  }
}

export const listAdminCategories = onCall<
  ListAdminCategoriesRequest,
  Promise<ListAdminCategoriesResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const pageSize = parsePageSize(request.data.limit);
  const cursor = normalizeCursor(request.data.cursor);
  const includeInactive = request.data.includeInactive === true;

  let query = db()
    .collection("categories")
    .orderBy(FieldPath.documentId())
    .limit(pageSize);
  if (cursor != null) {
    query = query.startAfter(cursor);
  }

  const [configSnap, categoriesSnap] = await Promise.all([
    db().doc(CATALOG_LIMITS_CONFIG_PATH).get(),
    query.get(),
  ]);
  const configData = (configSnap.data() as Record<string, unknown> | undefined) ?? {};
  const categoryLimitsRaw = configData["categoryLimits"];
  const categoryLimits =
    categoryLimitsRaw && typeof categoryLimitsRaw === "object" && !Array.isArray(categoryLimitsRaw)
      ? (categoryLimitsRaw as Record<string, unknown>)
      : {};

  const categories = categoriesSnap.docs
    .map((doc) => {
      const categoryId = doc.id.trim().toLowerCase();
      const data = doc.data() as Record<string, unknown>;
      const productLimit = normalizeProductLimit(categoryLimits[categoryId]);
      return toCategoryListItem({ categoryId, data, productLimit });
    })
    .filter((row) => includeInactive || row.isActive);

  const nextCursor =
    categoriesSnap.docs.length < pageSize ? null : categoriesSnap.docs[categoriesSnap.docs.length - 1].id;

  return { categories, nextCursor };
});

export const upsertAdminCategory = onCall<
  UpsertAdminCategoryRequest,
  Promise<UpsertAdminCategoryResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const categoryId = normalizeCategoryToken(request.data.categoryId, "categoryId");
  const label = normalizeLabel(request.data.label);
  const iconName = normalizeIconName(request.data.iconName);
  const aliases = normalizeAliases(request.data.aliases);
  assertNoSelfAliasCollision({ categoryId, aliases });
  const categoryRef = db().doc(`categories/${categoryId}`);
  const persisted = await db().runTransaction(async (tx) => {
    await assertNoTokenCollisionsInTx(tx, { categoryId, aliases });
    const currentSnap = await tx.get(categoryRef);
    const currentData = (currentSnap.data() as Record<string, unknown> | undefined) ?? {};
    const isActive =
      request.data.isActive == null
        ? currentData["isActive"] !== false
        : normalizeBoolean(request.data.isActive, "isActive");
    tx.set(
      categoryRef,
      {
        categoryId,
        label,
        iconName,
        aliases,
        isActive,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
        createdAt: currentSnap.exists
          ? currentData["createdAt"] ?? FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
        createdBy: currentSnap.exists
          ? currentData["createdBy"] ?? auth.uid
          : auth.uid,
      },
      { merge: true }
    );
    return { currentData, isActive };
  });

  const configSnap = await db().doc(CATALOG_LIMITS_CONFIG_PATH).get();
  const categoryLimitsRaw = (configSnap.data()?.["categoryLimits"] ??
    {}) as Record<string, unknown>;
  const category = toCategoryListItem({
    categoryId,
    data: {
      ...persisted.currentData,
      categoryId,
      label,
      iconName,
      aliases,
      isActive: persisted.isActive,
    },
    productLimit: normalizeProductLimit(categoryLimitsRaw[categoryId]),
  });

  return { category };
});

export const toggleAdminCategoryActive = onCall<
  ToggleAdminCategoryActiveRequest,
  Promise<ToggleAdminCategoryActiveResponse>
>({ enforceAppCheck: true }, async (request) => {
  const auth = assertAuthenticated(request.auth);
  const role = normalizeRole(auth.token.role);
  assertAdminRole(role);

  const categoryId = normalizeCategoryToken(request.data.categoryId, "categoryId");
  const isActive = normalizeBoolean(request.data.isActive, "isActive");
  const categoryRef = db().doc(`categories/${categoryId}`);
  const categorySnap = await categoryRef.get();
  if (!categorySnap.exists) {
    throw new HttpsError("not-found", "Categoría no encontrada.");
  }

  await categoryRef.set(
    {
      isActive,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: auth.uid,
    },
    { merge: true }
  );

  return { success: true, categoryId, isActive };
});
