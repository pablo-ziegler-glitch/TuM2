import { getAuth } from "firebase-admin/auth";

export type AccessRole = "customer" | "owner" | "admin" | "super_admin";

const ACCESS_CLAIMS_VERSION = 1;

const MANAGED_KEYS = new Set([
  "role",
  "owner_pending",
  "admin",
  "super_admin",
  "access_version",
  "claims_version",
  "claims_updated_at",
]);

const LEGACY_KEYS_TO_REMOVE = new Set([
  "merchantId",
  "merchantIds",
  "onboardingComplete",
  "ownerPending",
]);

type MutableClaims = Record<string, unknown>;

type ClaimsSummary = {
  role: AccessRole;
  ownerPending: boolean;
  admin: boolean;
  superAdmin: boolean;
  accessVersion: number | null;
  claimsVersion: number;
};

export type ApplyUserAccessClaimsParams = {
  uid: string;
  role: AccessRole;
  ownerPending: boolean;
  accessVersion?: number | null;
  reason: string;
  actorType?: "system" | "user" | "admin" | "super_admin";
  actorUid?: string | null;
};

export type ApplyUserAccessClaimsResult = {
  updated: boolean;
  previous: ClaimsSummary;
  next: ClaimsSummary;
};

function normalizeRole(value: unknown): AccessRole {
  if (typeof value !== "string") return "customer";
  const normalized = value.trim().toLowerCase();
  if (
    normalized === "customer" ||
    normalized === "owner" ||
    normalized === "admin" ||
    normalized === "super_admin"
  ) {
    return normalized;
  }
  return "customer";
}

function normalizeNonNegativeInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed) && parsed >= 0) return parsed;
  }
  return null;
}

function normalizeOwnerPending(value: unknown): boolean {
  if (value === true) return true;
  if (typeof value === "string") return value.trim().toLowerCase() === "true";
  return false;
}

function claimsSummaryFromRecord(record: MutableClaims): ClaimsSummary {
  const role = normalizeRole(record.role);
  const ownerPending = normalizeOwnerPending(record.owner_pending);
  const admin = record.admin === true || role === "admin" || role === "super_admin";
  const superAdmin = record.super_admin === true || role === "super_admin";
  return {
    role,
    ownerPending,
    admin,
    superAdmin,
    accessVersion: normalizeNonNegativeInt(record.access_version),
    claimsVersion:
      normalizeNonNegativeInt(record.claims_version) ?? ACCESS_CLAIMS_VERSION,
  };
}

function normalizeClaimObjectForComparison(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => normalizeClaimObjectForComparison(item));
  }
  if (value != null && typeof value === "object") {
    const source = value as Record<string, unknown>;
    const sortedKeys = Object.keys(source).sort((a, b) => a.localeCompare(b));
    const normalized: Record<string, unknown> = {};
    for (const key of sortedKeys) {
      normalized[key] = normalizeClaimObjectForComparison(source[key]);
    }
    return normalized;
  }
  return value;
}

function stableStringify(value: unknown): string {
  return JSON.stringify(normalizeClaimObjectForComparison(value));
}

function buildNextClaims(params: {
  currentClaims: MutableClaims;
  role: AccessRole;
  ownerPending: boolean;
  accessVersion: number | null;
  includeUpdatedAt: boolean;
  claimsUpdatedAtSeconds: number;
}): MutableClaims {
  const nextClaims: MutableClaims = {};
  for (const [key, value] of Object.entries(params.currentClaims)) {
    if (MANAGED_KEYS.has(key) || LEGACY_KEYS_TO_REMOVE.has(key)) continue;
    nextClaims[key] = value;
  }

  const role = normalizeRole(params.role);
  const superAdmin = role === "super_admin";
  const admin = role === "admin" || superAdmin;

  nextClaims.role = role;
  nextClaims.owner_pending = params.ownerPending;
  nextClaims.admin = admin;
  nextClaims.super_admin = superAdmin;
  nextClaims.claims_version = ACCESS_CLAIMS_VERSION;
  if (params.accessVersion != null) {
    nextClaims.access_version = params.accessVersion;
  } else if ("access_version" in params.currentClaims) {
    const normalizedCurrent = normalizeNonNegativeInt(params.currentClaims.access_version);
    if (normalizedCurrent != null) {
      nextClaims.access_version = normalizedCurrent;
    }
  }
  if (params.includeUpdatedAt) {
    nextClaims.claims_updated_at = params.claimsUpdatedAtSeconds;
  }
  return nextClaims;
}

export function computeUserAccessClaimsUpdate(params: {
  currentClaims: Record<string, unknown>;
  role: AccessRole;
  ownerPending: boolean;
  accessVersion?: number | null;
}): {
  updated: boolean;
  previous: ClaimsSummary;
  next: ClaimsSummary;
  nextClaimsWithoutTimestamp: Record<string, unknown>;
} {
  const nextWithoutTimestamp = buildNextClaims({
    currentClaims: params.currentClaims,
    role: params.role,
    ownerPending: params.ownerPending,
    accessVersion: normalizeNonNegativeInt(params.accessVersion),
    includeUpdatedAt: false,
    claimsUpdatedAtSeconds: 0,
  });
  const currentWithoutTimestamp = { ...params.currentClaims };
  delete currentWithoutTimestamp.claims_updated_at;
  for (const key of LEGACY_KEYS_TO_REMOVE) {
    delete currentWithoutTimestamp[key];
  }

  const updated =
    stableStringify(nextWithoutTimestamp) !==
    stableStringify(currentWithoutTimestamp);

  return {
    updated,
    previous: claimsSummaryFromRecord(params.currentClaims as MutableClaims),
    next: claimsSummaryFromRecord(nextWithoutTimestamp as MutableClaims),
    nextClaimsWithoutTimestamp: nextWithoutTimestamp,
  };
}

export async function applyUserAccessClaims(
  params: ApplyUserAccessClaimsParams
): Promise<ApplyUserAccessClaimsResult> {
  const uid = params.uid.trim();
  if (uid.length === 0) {
    throw new Error("applyUserAccessClaims requiere uid.");
  }

  const role = normalizeRole(params.role);
  const ownerPending = params.ownerPending === true;
  const normalizedAccessVersion = normalizeNonNegativeInt(params.accessVersion);
  const actorType = params.actorType ?? "system";
  const reason = params.reason.trim();
  if (reason.length === 0) {
    throw new Error("applyUserAccessClaims requiere reason.");
  }

  const auth = getAuth();
  const user = await auth.getUser(uid);
  const currentClaims = (user.customClaims ?? {}) as MutableClaims;
  const claimsUpdatedAtSeconds = Math.trunc(Date.now() / 1000);

  const computed = computeUserAccessClaimsUpdate({
    currentClaims,
    role,
    ownerPending,
    accessVersion: normalizedAccessVersion,
  });
  const updated = computed.updated;
  const previousSummary = computed.previous;
  const nextSummary = computed.next;

  if (!updated) {
    console.log(
      JSON.stringify({
        event: "access_claims.noop",
        uid,
        reason,
        actorType,
        actorUid: params.actorUid ?? null,
        previous: previousSummary,
      })
    );
    return {
      updated: false,
      previous: previousSummary,
      next: nextSummary,
    };
  }

  const nextClaims = buildNextClaims({
    currentClaims,
    role,
    ownerPending,
    accessVersion: normalizedAccessVersion,
    includeUpdatedAt: true,
    claimsUpdatedAtSeconds,
  });
  await auth.setCustomUserClaims(uid, nextClaims);

  console.log(
    JSON.stringify({
      event: "access_claims.updated",
      uid,
      reason,
      actorType,
      actorUid: params.actorUid ?? null,
      previous: previousSummary,
      next: claimsSummaryFromRecord(nextClaims),
    })
  );

  return {
    updated: true,
    previous: previousSummary,
    next: claimsSummaryFromRecord(nextClaims),
  };
}
