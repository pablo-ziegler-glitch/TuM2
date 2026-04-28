const CATEGORY_TOKEN_REGEX = /^[a-z0-9]+(?:_[a-z0-9]+)*$/;

export function canonicalCategoryToken(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isCanonicalCategoryToken(value: string): boolean {
  return CATEGORY_TOKEN_REGEX.test(value);
}

export function uniqueCategoryTokens(tokens: readonly string[]): string[] {
  return Array.from(new Set(tokens));
}
