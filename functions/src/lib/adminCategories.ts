const CATEGORY_TOKEN_REGEX = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;

const LEGACY_CATEGORY_MAP: Record<string, string> = {
  vet: "veterinaria",
  veterinary: "veterinaria",
  pharmacy: "farmacia",
  kiosk: "kiosco",
  grocery: "almacen",
  supermarket: "supermercado",
  prepared_food: "casa_de_comidas",
  fast_food: "comida_al_paso",
  tire_shop: "gomeria",
  other: "otro",
};

export function canonicalCategoryToken(raw: string): string {
  const normalized = raw.trim().toLowerCase();
  return LEGACY_CATEGORY_MAP[normalized] ?? normalized;
}

export function isCanonicalCategoryToken(value: string): boolean {
  return CATEGORY_TOKEN_REGEX.test(value);
}

export function uniqueCategoryTokens(tokens: readonly string[]): string[] {
  return Array.from(new Set(tokens));
}
