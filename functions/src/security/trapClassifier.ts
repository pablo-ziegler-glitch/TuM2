export type TrapCategory =
  | "scanner_generic"
  | "tum2_admin_probe"
  | "tum2_internal_probe"
  | "claim_probe"
  | "secret_probe"
  | "unknown_trap";

export type TrapSeverity = "info" | "warning" | "high" | "critical";

export interface TrapClassification {
  trapCategory: TrapCategory;
  severity: TrapSeverity;
  riskScore: number;
}

const SECRET_PROBE_PATTERNS = [
  "/.env",
  "/.env.prod",
  "/.env.production",
  "/firebase-service-account.json",
  "/service-account.json",
  "/google-services.json",
  "/firebase.json.bak",
  "/functions/.env",
  "/functions/service-account.json",
];

const CLAIM_PROBE_PATTERNS = [
  "/api/claims/export",
  "/api/claims/reveal-all",
  "/api/claims/evidence-dump",
  "/api/claims/approve-all",
  "/api/claims/owner-transition",
  "/api/merchant-claims/export",
  "/api/merchant-claims/reveal-sensitive",
];

const INTERNAL_PROBE_PATTERNS = [
  "/api/internal/merchant-dump",
  "/api/internal/merchant-public-dump",
  "/api/internal/pharmacy-duties/export",
  "/api/internal/zones/export",
  "/api/internal/search-index-dump",
  "/api/private/merchant_public_dump",
  "/api/private/app-config",
  "/api/private/firebase-config",
];

const ADMIN_PROBE_PATTERNS = [
  "/admin/export-users",
  "/admin/export-claims",
  "/admin/users.csv",
  "/admin/claims.csv",
  "/api/admin/users",
  "/api/admin/export-users",
  "/api/admin/export-claims",
  "/api/admin/reveal-sensitive",
  "/api/admin/merchant-claims-dump",
];

const SCANNER_GENERIC_PATTERNS = [
  "/wp-login.php",
  "/wp-admin",
  "/wp-admin/**",
  "/xmlrpc.php",
  "/phpmyadmin",
  "/phpmyadmin/**",
  "/adminer.php",
  "/.git/config",
  "/.git/**",
  "/backup.zip",
  "/database.sql",
  "/config.json",
  "/server-status",
];

function removeTrailingSlash(path: string): string {
  if (path === "/") return path;
  return path.endsWith("/") ? path.slice(0, -1) : path;
}

export function normalizeTrapPath(rawPath: string | undefined | null): string {
  if (typeof rawPath !== "string" || rawPath.trim().length === 0) return "/";
  const noQuery = rawPath.split("?")[0].split("#")[0].trim();
  const withLeadingSlash = noQuery.startsWith("/") ? noQuery : `/${noQuery}`;
  let decoded = withLeadingSlash;
  try {
    decoded = decodeURIComponent(withLeadingSlash);
  } catch {
    decoded = withLeadingSlash;
  }
  const collapsed = decoded.replace(/\/{2,}/g, "/").toLowerCase();
  return removeTrailingSlash(collapsed || "/");
}

function matchesPathPattern(path: string, pattern: string): boolean {
  if (pattern.endsWith("/**")) {
    const base = pattern.slice(0, -3);
    return path === base || path.startsWith(`${base}/`);
  }
  return path === pattern;
}

function matchesAny(path: string, patterns: string[]): boolean {
  return patterns.some((pattern) => matchesPathPattern(path, pattern));
}

export function severityByCategory(category: TrapCategory): TrapSeverity {
  if (category === "secret_probe") return "critical";
  if (
    category === "tum2_admin_probe" ||
    category === "tum2_internal_probe" ||
    category === "claim_probe"
  ) {
    return "high";
  }
  if (category === "scanner_generic" || category === "unknown_trap") {
    return "warning";
  }
  return "info";
}

export function riskScoreByCategory(category: TrapCategory): number {
  if (category === "secret_probe") return 90;
  if (category === "claim_probe") return 80;
  if (category === "tum2_internal_probe") return 75;
  if (category === "tum2_admin_probe") return 70;
  if (category === "unknown_trap") return 40;
  if (category === "scanner_generic") return 35;
  return 0;
}

export function classifyTrapPath(rawPath: string | undefined | null): TrapClassification {
  const normalizedPath = normalizeTrapPath(rawPath);
  let trapCategory: TrapCategory = "unknown_trap";

  if (matchesAny(normalizedPath, SECRET_PROBE_PATTERNS)) {
    trapCategory = "secret_probe";
  } else if (matchesAny(normalizedPath, CLAIM_PROBE_PATTERNS)) {
    trapCategory = "claim_probe";
  } else if (matchesAny(normalizedPath, INTERNAL_PROBE_PATTERNS)) {
    trapCategory = "tum2_internal_probe";
  } else if (matchesAny(normalizedPath, ADMIN_PROBE_PATTERNS)) {
    trapCategory = "tum2_admin_probe";
  } else if (matchesAny(normalizedPath, SCANNER_GENERIC_PATTERNS)) {
    trapCategory = "scanner_generic";
  }

  return {
    trapCategory,
    severity: severityByCategory(trapCategory),
    riskScore: riskScoreByCategory(trapCategory),
  };
}
