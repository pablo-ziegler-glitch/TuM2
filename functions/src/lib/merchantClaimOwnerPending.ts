import {
  FieldValue,
  Query,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { applyUserAccessClaims } from "./accessClaims";

const db = () => getFirestore();

const OWNER_PENDING_STATUSES = [
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
] as const;

const OWNER_RESTRICTION_STATES = [
  "none",
  "cooldown",
  "manual_review_only",
  "blocked",
] as const;

const OWNER_ACCESS_SUMMARY_VERSION = 1;
const MAX_PENDING_CLAIMS_SCAN = 20;
const MAX_APPROVED_MERCHANTS_SCAN = 10;

type OwnerRestrictionState = (typeof OWNER_RESTRICTION_STATES)[number];

type OwnerRestrictionPatch = {
  state: OwnerRestrictionState;
  reasonCode: string | null;
  blockedUntilMillis: number | null;
};

type OwnerRestrictionContext = {
  state: OwnerRestrictionState;
  reasonCode: string | null;
  blockedUntilMillis: number | null;
};

type OwnerAccessSummary = {
  summaryVersion: number;
  defaultMerchantId: string | null;
  approvedMerchantIdsCount: number;
  pendingClaimMerchantIdsCount: number;
  hasConcurrentPendingClaims: boolean;
  primaryContextMode:
    | "customer"
    | "owner_single"
    | "owner_multi"
    | "owner_with_pending"
    | "owner_pending_only"
    | "restricted";
  restrictionState: OwnerRestrictionState;
  restrictionReasonCode: string | null;
  blockedUntil: Timestamp | null;
  updatedAt: unknown;
};

function readTrimmedString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function readMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return null;
}

function normalizeRestrictionState(value: unknown): OwnerRestrictionState {
  const normalized = readTrimmedString(value)?.toLowerCase();
  if (
    normalized === "none" ||
    normalized === "cooldown" ||
    normalized === "manual_review_only" ||
    normalized === "blocked"
  ) {
    return normalized;
  }
  return "none";
}

function severityForRestriction(state: OwnerRestrictionState): number {
  if (state === "blocked") return 3;
  if (state === "manual_review_only") return 2;
  if (state === "cooldown") return 1;
  return 0;
}

function isAdminRole(role: string | null): boolean {
  return role === "admin" || role === "super_admin";
}

async function safeCount(query: Query, fallbackLimit: number): Promise<number> {
  try {
    const aggregate = await query.count().get();
    return aggregate.data().count;
  } catch {
    const snap = await query.limit(fallbackLimit).get();
    return snap.size;
  }
}

async function readApprovedMerchants(userId: string): Promise<{
  defaultMerchantId: string | null;
  approvedMerchantIdsCount: number;
}> {
  const merchantsQuery = db().collection("merchants").where("ownerUserId", "==", userId);
  const [count, sampleSnap] = await Promise.all([
    safeCount(merchantsQuery, MAX_APPROVED_MERCHANTS_SCAN),
    merchantsQuery.limit(MAX_APPROVED_MERCHANTS_SCAN).get(),
  ]);

  const merchants = sampleSnap.docs
    .map((doc) => {
      const data = doc.data() ?? {};
      const updatedAtMillis = readMillis(data.updatedAt) ?? 0;
      const createdAtMillis = readMillis(data.createdAt) ?? 0;
      return {
        merchantId: doc.id,
        updatedAtMillis,
        createdAtMillis,
      };
    })
    .sort((left, right) => {
      if (left.updatedAtMillis != right.updatedAtMillis) {
        return right.updatedAtMillis - left.updatedAtMillis;
      }
      if (left.createdAtMillis != right.createdAtMillis) {
        return right.createdAtMillis - left.createdAtMillis;
      }
      return left.merchantId.localeCompare(right.merchantId);
    });

  return {
    defaultMerchantId: merchants.length > 0 ? merchants[0].merchantId : null,
    approvedMerchantIdsCount: count,
  };
}

async function readPendingClaimMerchants(userId: string): Promise<{
  pendingClaimMerchantIdsCount: number;
  hasConcurrentPendingClaims: boolean;
}> {
  const pendingSnap = await db()
    .collection("merchant_claims")
    .where("userId", "==", userId)
    .where("claimStatus", "in", [...OWNER_PENDING_STATUSES])
    .limit(MAX_PENDING_CLAIMS_SCAN)
    .get();

  const uniqueMerchantIds = new Set<string>();
  for (const doc of pendingSnap.docs) {
    const merchantId = readTrimmedString(doc.data()?.merchantId);
    if (merchantId != null) uniqueMerchantIds.add(merchantId);
    if (uniqueMerchantIds.size > 1) {
      return {
        pendingClaimMerchantIdsCount: uniqueMerchantIds.size,
        hasConcurrentPendingClaims: true,
      };
    }
  }

  return {
    pendingClaimMerchantIdsCount: uniqueMerchantIds.size,
    hasConcurrentPendingClaims: false,
  };
}

function readCurrentRestriction(userData: Record<string, unknown>): OwnerRestrictionContext {
  const restrictionMap =
    userData.ownerRestriction != null && typeof userData.ownerRestriction === "object"
      ? (userData.ownerRestriction as Record<string, unknown>)
      : {};
  const summaryMap =
    userData.ownerAccessSummary != null && typeof userData.ownerAccessSummary === "object"
      ? (userData.ownerAccessSummary as Record<string, unknown>)
      : {};

  const state = normalizeRestrictionState(
    restrictionMap.state ?? summaryMap.restrictionState
  );
  const reasonCode = readTrimmedString(
    restrictionMap.reasonCode ?? summaryMap.restrictionReasonCode
  );
  const blockedUntilMillis = readMillis(
    restrictionMap.blockedUntil ?? summaryMap.blockedUntil
  );
  const nowMillis = Date.now();

  if (state === "cooldown" && blockedUntilMillis != null && blockedUntilMillis <= nowMillis) {
    return {
      state: "none",
      reasonCode: null,
      blockedUntilMillis: null,
    };
  }

  if (state === "blocked" && blockedUntilMillis != null && blockedUntilMillis <= nowMillis) {
    return {
      state: "none",
      reasonCode: null,
      blockedUntilMillis: null,
    };
  }

  return {
    state,
    reasonCode,
    blockedUntilMillis,
  };
}

function resolvePrimaryContextMode(params: {
  approvedMerchantIdsCount: number;
  ownerPending: boolean;
  restrictionState: OwnerRestrictionState;
}): OwnerAccessSummary["primaryContextMode"] {
  if (params.restrictionState !== "none") return "restricted";
  if (params.approvedMerchantIdsCount > 1 && params.ownerPending) {
    return "owner_with_pending";
  }
  if (params.approvedMerchantIdsCount > 1) return "owner_multi";
  if (params.approvedMerchantIdsCount === 1 && params.ownerPending) {
    return "owner_with_pending";
  }
  if (params.approvedMerchantIdsCount === 1) return "owner_single";
  if (params.ownerPending) return "owner_pending_only";
  return "customer";
}

function normalizeClaimStatus(value: string): string {
  return value.trim().toLowerCase();
}

function normalizeReasonCode(value: string | null | undefined): string | null {
  if (value == null) return null;
  const normalized = value.trim().toLowerCase();
  return normalized.length > 0 ? normalized : null;
}

function chooseStricterRestriction(
  current: OwnerRestrictionContext,
  next: OwnerRestrictionPatch
): OwnerRestrictionPatch {
  const currentSeverity = severityForRestriction(current.state);
  const nextSeverity = severityForRestriction(next.state);
  if (nextSeverity > currentSeverity) {
    return next;
  }
  if (nextSeverity < currentSeverity) {
    return {
      state: current.state,
      reasonCode: current.reasonCode,
      blockedUntilMillis: current.blockedUntilMillis,
    };
  }

  if (next.state === "cooldown" || next.state === "manual_review_only") {
    const currentUntil = current.blockedUntilMillis ?? 0;
    const nextUntil = next.blockedUntilMillis ?? 0;
    if (nextUntil > currentUntil) return next;
    return {
      state: current.state,
      reasonCode: current.reasonCode,
      blockedUntilMillis: current.blockedUntilMillis,
    };
  }

  return next;
}

function patchEquals(
  left: OwnerRestrictionPatch,
  right: OwnerRestrictionContext
): boolean {
  return (
    left.state === right.state &&
    left.reasonCode === right.reasonCode &&
    left.blockedUntilMillis === right.blockedUntilMillis
  );
}

function deriveRestrictionPatchFromResolution(params: {
  claimStatus: string;
  reviewReasonCode: string | null;
  nowMillis: number;
}): OwnerRestrictionPatch {
  const status = normalizeClaimStatus(params.claimStatus);
  const reason = normalizeReasonCode(params.reviewReasonCode);
  const value = reason ?? "";
  const severeFraud =
    value.includes("fraud") ||
    value.includes("falso") ||
    value.includes("forg") ||
    value.includes("suplant") ||
    value.includes("identity_theft");
  if (severeFraud) {
    return {
      state: "blocked",
      reasonCode: reason ?? "fraud_confirmed",
      blockedUntilMillis: null,
    };
  }

  const abuse =
    value.includes("abuso") ||
    value.includes("reincid") ||
    value.includes("spam") ||
    value.includes("malicious");
  if (abuse) {
    return {
      state: "manual_review_only",
      reasonCode: reason ?? "abuse_recurrent",
      blockedUntilMillis: params.nowMillis + 7 * 24 * 60 * 60 * 1000,
    };
  }

  const missingInfo =
    value.includes("missing") ||
    value.includes("insufficient") ||
    value.includes("incomplet") ||
    value.includes("evidence") ||
    value.includes("info");

  if (status === "needs_more_info" || (status === "rejected" && missingInfo)) {
    return {
      state: "cooldown",
      reasonCode: reason ?? "insufficient_evidence_cooldown",
      blockedUntilMillis: params.nowMillis + 24 * 60 * 60 * 1000,
    };
  }

  return {
    state: "none",
    reasonCode: null,
    blockedUntilMillis: null,
  };
}

function compareSummaryShape(
  currentRaw: unknown,
  nextComparable: {
    defaultMerchantId: string | null;
    approvedMerchantIdsCount: number;
    pendingClaimMerchantIdsCount: number;
    hasConcurrentPendingClaims: boolean;
    primaryContextMode: string;
    restrictionState: OwnerRestrictionState;
    restrictionReasonCode: string | null;
    blockedUntilMillis: number | null;
    summaryVersion: number;
  }
): boolean {
  if (currentRaw == null || typeof currentRaw !== "object") return false;
  const current = currentRaw as Record<string, unknown>;
  const currentBlockedUntilMillis = readMillis(current.blockedUntil);
  return (
    readTrimmedString(current.defaultMerchantId) === nextComparable.defaultMerchantId &&
    Number(current.approvedMerchantIdsCount ?? -1) ===
      nextComparable.approvedMerchantIdsCount &&
    Number(current.pendingClaimMerchantIdsCount ?? -1) ===
      nextComparable.pendingClaimMerchantIdsCount &&
    current.hasConcurrentPendingClaims === nextComparable.hasConcurrentPendingClaims &&
    readTrimmedString(current.primaryContextMode) === nextComparable.primaryContextMode &&
    normalizeRestrictionState(current.restrictionState) ===
      nextComparable.restrictionState &&
    readTrimmedString(current.restrictionReasonCode) ===
      nextComparable.restrictionReasonCode &&
    currentBlockedUntilMillis === nextComparable.blockedUntilMillis &&
    Number(current.summaryVersion ?? -1) === nextComparable.summaryVersion
  );
}

export async function syncOwnerPendingAccess(params: {
  userId: string;
  claimId: string;
  claimStatus: string;
  merchantId: string;
  forceAccessVersionBump?: boolean;
  reasonCode?: string | null;
}): Promise<{
  role: "customer" | "owner" | "admin" | "super_admin";
  ownerPending: boolean;
  accessVersion: number;
  summaryChanged: boolean;
  claimsUpdated: boolean;
}> {
  const userRef = db().doc(`users/${params.userId}`);
  const [userSnap, approvedInfo, pendingInfo] = await Promise.all([
    userRef.get(),
    readApprovedMerchants(params.userId),
    readPendingClaimMerchants(params.userId),
  ]);

  const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
  const currentRestriction = readCurrentRestriction(userData);
  const ownerPending = pendingInfo.pendingClaimMerchantIdsCount > 0;
  const primaryContextMode = resolvePrimaryContextMode({
    approvedMerchantIdsCount: approvedInfo.approvedMerchantIdsCount,
    ownerPending,
    restrictionState: currentRestriction.state,
  });

  const nextRole: "customer" | "owner" =
    approvedInfo.approvedMerchantIdsCount > 0 ? "owner" : "customer";
  const currentRole = readTrimmedString(userData.role)?.toLowerCase();
  const currentOwnerPending = userData.ownerPending === true;
  const currentAccessVersionRaw = userData.accessVersion;
  const currentAccessVersion =
    typeof currentAccessVersionRaw === "number" && Number.isFinite(currentAccessVersionRaw)
      ? Math.max(0, Math.trunc(currentAccessVersionRaw))
      : 0;

  const nextSummaryComparable = {
    defaultMerchantId: approvedInfo.defaultMerchantId,
    approvedMerchantIdsCount: approvedInfo.approvedMerchantIdsCount,
    pendingClaimMerchantIdsCount: pendingInfo.pendingClaimMerchantIdsCount,
    hasConcurrentPendingClaims: pendingInfo.hasConcurrentPendingClaims,
    primaryContextMode,
    restrictionState: currentRestriction.state,
    restrictionReasonCode: currentRestriction.reasonCode,
    blockedUntilMillis: currentRestriction.blockedUntilMillis,
    summaryVersion: OWNER_ACCESS_SUMMARY_VERSION,
  };

  const summaryChanged = !compareSummaryShape(
    userData.ownerAccessSummary,
    nextSummaryComparable
  );
  const roleChanged = currentRole !== nextRole;
  const pendingChanged = currentOwnerPending !== ownerPending;
  const forceBump = params.forceAccessVersionBump === true;
  const shouldBumpVersion = forceBump || summaryChanged || roleChanged || pendingChanged;
  const nextAccessVersion = shouldBumpVersion
    ? currentAccessVersion + 1
    : currentAccessVersion;

  if (shouldBumpVersion) {
    const nextSummary: OwnerAccessSummary = {
      summaryVersion: OWNER_ACCESS_SUMMARY_VERSION,
      defaultMerchantId: approvedInfo.defaultMerchantId,
      approvedMerchantIdsCount: approvedInfo.approvedMerchantIdsCount,
      pendingClaimMerchantIdsCount: pendingInfo.pendingClaimMerchantIdsCount,
      hasConcurrentPendingClaims: pendingInfo.hasConcurrentPendingClaims,
      primaryContextMode,
      restrictionState: currentRestriction.state,
      restrictionReasonCode: currentRestriction.reasonCode,
      blockedUntil:
        currentRestriction.blockedUntilMillis != null
          ? Timestamp.fromMillis(currentRestriction.blockedUntilMillis)
          : null,
      updatedAt: FieldValue.serverTimestamp(),
    };
    await userRef.set(
      {
        role: nextRole,
        ownerPending,
        merchantId: approvedInfo.defaultMerchantId,
        onboardingComplete: nextRole === "owner",
        accessVersion: nextAccessVersion,
        ownerAccessSummary: nextSummary,
        ownerRestriction: {
          state: currentRestriction.state,
          reasonCode: currentRestriction.reasonCode,
          blockedUntil:
            currentRestriction.blockedUntilMillis != null
              ? Timestamp.fromMillis(currentRestriction.blockedUntilMillis)
              : null,
        },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  let claimsUpdated = false;
  try {
    const currentClaimRole = currentRole;
    const stableRole: "customer" | "owner" | "admin" | "super_admin" =
      currentClaimRole != null && isAdminRole(currentClaimRole)
        ? (currentClaimRole as "admin" | "super_admin")
        : nextRole;
    const claimsResult = await applyUserAccessClaims({
      uid: params.userId,
      role: stableRole,
      ownerPending,
      accessVersion: nextAccessVersion,
      reason: "sync_owner_pending_access",
      actorType: "system",
    });
    claimsUpdated = claimsResult.updated;
    return {
      role: stableRole,
      ownerPending,
      accessVersion: nextAccessVersion,
      summaryChanged,
      claimsUpdated,
    };
  } catch (error) {
    console.warn(
      JSON.stringify({
        source: "merchant_claims",
        action: "sync_owner_access_claims_failed",
        userId: params.userId,
        claimId: params.claimId,
        claimStatus: params.claimStatus,
        merchantId: params.merchantId,
        reasonCode: params.reasonCode ?? null,
        error: error instanceof Error ? error.message : String(error),
      })
    );
    return {
      role: nextRole,
      ownerPending,
      accessVersion: nextAccessVersion,
      summaryChanged,
      claimsUpdated: false,
    };
  }
}

export async function applyRestrictionFromClaimResolution(params: {
  userId: string;
  claimId: string;
  merchantId: string;
  claimStatus: string;
  reviewReasonCode: string | null;
  actorUid: string;
  actorRole: string;
}): Promise<{
  applied: boolean;
  state: OwnerRestrictionState;
  reasonCode: string | null;
  blockedUntilMillis: number | null;
}> {
  const nowMillis = Date.now();
  const userRef = db().doc(`users/${params.userId}`);
  const userSnap = await userRef.get();
  const userData = (userSnap.data() ?? {}) as Record<string, unknown>;
  const current = readCurrentRestriction(userData);
  const requested = deriveRestrictionPatchFromResolution({
    claimStatus: params.claimStatus,
    reviewReasonCode: params.reviewReasonCode,
    nowMillis,
  });
  const next = chooseStricterRestriction(current, requested);
  if (patchEquals(next, current)) {
    return {
      applied: false,
      state: current.state,
      reasonCode: current.reasonCode,
      blockedUntilMillis: current.blockedUntilMillis,
    };
  }

  await userRef.set(
    {
      ownerRestriction: {
        state: next.state,
        reasonCode: next.reasonCode,
        blockedUntil:
          next.blockedUntilMillis != null
            ? Timestamp.fromMillis(next.blockedUntilMillis)
            : null,
        source: "claim_resolution",
        updatedByUid: params.actorUid,
        updatedByRole: params.actorRole,
        updatedAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db().collection("merchant_claim_owner_access_actions").add({
    claimId: params.claimId,
    merchantId: params.merchantId,
    userId: params.userId,
    actorUid: params.actorUid,
    actorRole: params.actorRole,
    actionType: "restriction_applied",
    claimStatus: normalizeClaimStatus(params.claimStatus),
    reviewReasonCode: normalizeReasonCode(params.reviewReasonCode),
    restrictionState: next.state,
    restrictionReasonCode: next.reasonCode,
    blockedUntil:
      next.blockedUntilMillis != null
        ? Timestamp.fromMillis(next.blockedUntilMillis)
        : null,
    createdAt: FieldValue.serverTimestamp(),
    schemaVersion: 1,
  });

  return {
    applied: true,
    state: next.state,
    reasonCode: next.reasonCode,
    blockedUntilMillis: next.blockedUntilMillis,
  };
}

export async function setOwnerAccessRestriction(params: {
  userId: string;
  actorUid: string;
  actorRole: string;
  reasonCode: string | null;
  state: OwnerRestrictionState;
  blockedUntilMillis?: number | null;
  claimId?: string | null;
  merchantId?: string | null;
}): Promise<{
  state: OwnerRestrictionState;
  reasonCode: string | null;
  blockedUntilMillis: number | null;
}> {
  const normalizedReason = normalizeReasonCode(params.reasonCode);
  const blockedUntilMillis =
    params.blockedUntilMillis != null ? Math.trunc(params.blockedUntilMillis) : null;
  const userRef = db().doc(`users/${params.userId}`);
  await userRef.set(
    {
      ownerRestriction: {
        state: params.state,
        reasonCode: normalizedReason,
        blockedUntil:
          blockedUntilMillis != null ? Timestamp.fromMillis(blockedUntilMillis) : null,
        source: "admin_manual",
        updatedByUid: params.actorUid,
        updatedByRole: params.actorRole,
        updatedAt: FieldValue.serverTimestamp(),
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db().collection("merchant_claim_owner_access_actions").add({
    claimId: params.claimId ?? null,
    merchantId: params.merchantId ?? null,
    userId: params.userId,
    actorUid: params.actorUid,
    actorRole: params.actorRole,
    actionType: "restriction_rehabilitated",
    reviewReasonCode: null,
    restrictionState: params.state,
    restrictionReasonCode: normalizedReason,
    blockedUntil:
      blockedUntilMillis != null ? Timestamp.fromMillis(blockedUntilMillis) : null,
    createdAt: FieldValue.serverTimestamp(),
    schemaVersion: 1,
  });

  return {
    state: params.state,
    reasonCode: normalizedReason,
    blockedUntilMillis,
  };
}

export function normalizeOwnerRestrictionState(value: unknown): OwnerRestrictionState {
  return normalizeRestrictionState(value);
}
