export type AdminRole = "reviewer" | "senior_reviewer" | "admin" | "super_admin";

export type ClaimResolutionAction =
  | "approve"
  | "reject"
  | "needs_more_info"
  | "conflict_detected"
  | "duplicate_claim"
  | "escalate";

export interface ClaimResolutionContext {
  claimStatus: string;
  hasConflict: boolean;
  hasDuplicate: boolean;
  isSensitiveCategory: boolean;
  riskLevel: string | null;
}

const HIGH_RISK_LEVELS = new Set(["high", "critical"]);

function readString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => readString(item))
    .filter((item): item is string => item != null);
}

function parseLegacyRole(token: Record<string, unknown>): AdminRole | null {
  const role = readString(token.role);
  if (role === "super_admin") return "super_admin";
  if (role !== "admin") return null;

  const levelRaw =
    readString(token.claimsReviewLevel) ??
    readString(token.claims_review_level) ??
    (token.claimsSeniorReviewer === true ? "senior_reviewer" : null) ??
    (token.claimsReviewer === true ? "reviewer" : null);

  if (levelRaw === "reviewer") return "reviewer";
  if (levelRaw === "senior" || levelRaw === "senior_reviewer") {
    return "senior_reviewer";
  }
  return "admin";
}

export function getAdminRoleFromClaims(
  decodedToken: Record<string, unknown>
): AdminRole | null {
  const explicit =
    readString(decodedToken.adminRole) ??
    readString(decodedToken.admin_role) ??
    readString(decodedToken.claimsReviewRole) ??
    readString(decodedToken.claims_review_role);
  if (
    explicit === "reviewer" ||
    explicit === "senior_reviewer" ||
    explicit === "admin" ||
    explicit === "super_admin"
  ) {
    return explicit;
  }

  const byLegacyRole = parseLegacyRole(decodedToken);
  if (byLegacyRole != null) return byLegacyRole;

  const capabilities = new Set(readStringArray(decodedToken.capabilities));
  if (capabilities.has("claims.resolve_all") || capabilities.has("claims.admin")) {
    return "admin";
  }
  if (
    capabilities.has("claims.resolve_critical") ||
    capabilities.has("claims.reveal_sensitive")
  ) {
    return "senior_reviewer";
  }
  if (capabilities.has("claims.review") || capabilities.has("claims.resolve_standard")) {
    return "reviewer";
  }

  return null;
}

export function canEvaluate(role: AdminRole | null): boolean {
  return role != null;
}

export function canRevealSensitive(role: AdminRole | null): boolean {
  return role === "senior_reviewer" || role === "admin" || role === "super_admin";
}

export function canDownloadSensitiveAttachment(role: AdminRole | null): boolean {
  return role === "admin" || role === "super_admin";
}

function canSeniorApprove(context: ClaimResolutionContext): boolean {
  const risk = (context.riskLevel ?? "").trim().toLowerCase();
  if (context.hasConflict) return false;
  if (context.hasDuplicate) return false;
  if (context.isSensitiveCategory) return false;
  if (HIGH_RISK_LEVELS.has(risk)) return false;
  return true;
}

export function canResolve(
  role: AdminRole | null,
  action: ClaimResolutionAction,
  context: ClaimResolutionContext
): boolean {
  if (role == null) return false;
  if (role === "super_admin" || role === "admin") {
    return true;
  }

  if (role === "reviewer") {
    return action === "needs_more_info" || action === "escalate";
  }

  if (role === "senior_reviewer") {
    if (action === "approve") return canSeniorApprove(context);
    if (action === "reject") return true;
    if (action === "needs_more_info") return true;
    if (action === "conflict_detected") return true;
    if (action === "duplicate_claim") return true;
    if (action === "escalate") return true;
  }

  return false;
}
