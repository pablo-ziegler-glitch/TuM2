import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import {
  CLAIM_AUTO_VALIDATION_SYSTEM,
  CLAIM_AUTO_VALIDATION_VERSION,
  ClaimAutoValidationStatus,
  buildAutoValidationInputHash,
  evaluateMerchantClaimAutoValidation,
} from "./merchantClaimAutoValidation";
import { syncOwnerPendingAccess } from "./merchantClaimOwnerPending";

const db = () => getFirestore();

const ACTIVE_STATUSES = [
  "draft",
  "submitted",
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
] as const;

function toLowerTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function toTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function toBoolean(value: unknown): boolean {
  return value === true;
}

function safeTimestampMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  return null;
}

function mapInternalWorkflowStatus(status: ClaimAutoValidationStatus): string {
  if (status === "under_review") return "auto_validation_passed";
  if (status === "needs_more_info") return "auto_validation_needs_more_info";
  if (status === "duplicate_claim") return "auto_validation_blocked_duplicate";
  if (status === "conflict_detected") return "auto_validation_blocked_conflict";
  return "auto_validation_blocked_rejected";
}

function pickAutoValidationState(data: Record<string, unknown>): Record<string, unknown> {
  return {
    claimStatus: data.claimStatus ?? null,
    userVisibleStatus: data.userVisibleStatus ?? null,
    internalWorkflowStatus: data.internalWorkflowStatus ?? null,
    autoValidationStatus: data.autoValidationStatus ?? null,
    autoValidationResult: data.autoValidationResult ?? null,
    autoValidationReasons: Array.isArray(data.autoValidationReasons)
      ? data.autoValidationReasons
      : [],
    autoValidationVersion: data.autoValidationVersion ?? null,
    hasConflict: data.hasConflict === true,
    hasDuplicate: data.hasDuplicate === true,
    requiresManualReview: data.requiresManualReview === true,
    missingEvidence: data.missingEvidence === true,
    missingEvidenceTypes: Array.isArray(data.missingEvidenceTypes)
      ? data.missingEvidenceTypes
      : [],
    riskFlags: Array.isArray(data.riskFlags) ? data.riskFlags : [],
    riskPriority: data.riskPriority ?? "low",
    reviewQueuePriority: data.reviewQueuePriority ?? 0,
    lastAutoValidationHash:
      typeof data.lastAutoValidationHash === "string" ? data.lastAutoValidationHash : null,
  };
}

function logStructured(event: string, payload: Record<string, unknown>): void {
  console.log(JSON.stringify({ event, ...payload }));
}

export interface RunMerchantClaimAutoValidationParams {
  claimId: string;
  origin: "submit_callable" | "submitted_trigger" | "admin_rerun";
  force?: boolean;
}

export interface RunMerchantClaimAutoValidationResult {
  claimId: string;
  merchantId: string;
  userId: string;
  previousStatus: string;
  nextStatus: string;
  didChange: boolean;
  noOp: boolean;
  reasonCodes: string[];
}

export async function runMerchantClaimAutoValidation(
  params: RunMerchantClaimAutoValidationParams
): Promise<RunMerchantClaimAutoValidationResult | null> {
  const startedAt = Date.now();
  const claimRef = db().collection("merchant_claims").doc(params.claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) return null;
  const claimData = claimSnap.data() ?? {};
  const claimStatus = toLowerTrimmedString(
    claimData.userVisibleStatus ?? claimData.claimStatus
  );
  if (!params.force && claimStatus !== "submitted") {
    return null;
  }

  const userId = toTrimmedString(claimData.userId);
  const merchantId = toTrimmedString(claimData.merchantId);
  if (!userId || !merchantId) {
    return null;
  }

  const merchantRef = db().doc(`merchants/${merchantId}`);
  const userRef = db().doc(`users/${userId}`);
  const privateRef = db().doc(`merchant_claim_private/${params.claimId}`);

  const [merchantSnap, userSnap, privateSnap] = await Promise.all([
    merchantRef.get(),
    userRef.get(),
    privateRef.get(),
  ]);

  const merchantData = merchantSnap.data() ?? {};
  const userData = userSnap.data() ?? {};
  const privateData = privateSnap.data() ?? {};
  const privateVault =
    privateData.sensitiveVault != null && typeof privateData.sensitiveVault === "object"
      ? (privateData.sensitiveVault as Record<string, unknown>)
      : {};
  const fingerprintPrimary = toTrimmedString(
    privateData.fingerprintPrimary ?? privateVault.fingerprintPrimary
  );

  let authEmail = "";
  try {
    const userRecord = await getAuth().getUser(userId);
    authEmail = typeof userRecord.email === "string" ? userRecord.email.trim().toLowerCase() : "";
  } catch {
    authEmail = toLowerTrimmedString(claimData.authenticatedEmail);
  }

  const [duplicateSnap, conflictSnap, contactReuseSnap] = await Promise.all([
    db()
      .collection("merchant_claims")
      .where("userId", "==", userId)
      .where("merchantId", "==", merchantId)
      .where("claimStatus", "in", [...ACTIVE_STATUSES])
      .limit(3)
      .get(),
    db()
      .collection("merchant_claims")
      .where("merchantId", "==", merchantId)
      .where("claimStatus", "in", [...ACTIVE_STATUSES])
      .limit(6)
      .get(),
    fingerprintPrimary
      ? db()
          .collection("merchant_claim_private")
          .where("fingerprintPrimary", "==", fingerprintPrimary)
          .limit(4)
          .get()
      : Promise.resolve(null),
  ]);

  const hasSameUserActiveEquivalentClaim = duplicateSnap.docs.some(
    (doc) => doc.id !== params.claimId
  );
  const hasOtherUserActiveClaimOnMerchant = conflictSnap.docs.some((doc) => {
    if (doc.id === params.claimId) return false;
    const otherUserId = toTrimmedString(doc.data().userId);
    return otherUserId.length > 0 && otherUserId !== userId;
  });
  const contactReuseDetected =
    contactReuseSnap != null &&
    contactReuseSnap.docs.some((doc) => {
      if (doc.id === params.claimId) return false;
      const otherData = doc.data() ?? {};
      const otherUserId = toTrimmedString(otherData.userId);
      const otherMerchantId = toTrimmedString(otherData.merchantId);
      return otherUserId !== userId || otherMerchantId !== merchantId;
    });

  const categoryId = toLowerTrimmedString(
    claimData.categoryId || merchantData.categoryId || ""
  );
  const zoneId = toLowerTrimmedString(claimData.zoneId || merchantData.zoneId || "");
  const evidenceRaw = Array.isArray(claimData.evidenceFiles)
    ? (claimData.evidenceFiles as Array<Record<string, unknown>>)
    : [];
  const evidenceKinds = evidenceRaw
    .map((entry) => toTrimmedString(entry.kind))
    .filter((value) => value.length > 0);

  const evaluationInput = {
    claimId: params.claimId,
    userId,
    merchantId,
    categoryId,
    zoneId,
    claimAuthenticatedEmail: toLowerTrimmedString(claimData.authenticatedEmail),
    authEmail: authEmail || null,
    hasAcceptedDataProcessingConsent: toBoolean(claimData.hasAcceptedDataProcessingConsent),
    hasAcceptedLegitimacyDeclaration: toBoolean(claimData.hasAcceptedLegitimacyDeclaration),
    evidence: evidenceKinds.map((kind) => ({ kind })),
    merchantExists: merchantSnap.exists,
    merchantOwnerUserId: toTrimmedString(merchantData.ownerUserId) || null,
    merchantOwnershipStatus: toLowerTrimmedString(merchantData.ownershipStatus) || null,
    hasOtherUserActiveClaimOnMerchant,
    hasSameUserActiveEquivalentClaim,
    userBlockedForClaims: toLowerTrimmedString(userData.status) === "blocked",
    riskSignals: {
      contactReuseDetected,
      abusePatternDetected: false,
      nonTerminalInconsistency: false,
    },
  };

  const evaluation = evaluateMerchantClaimAutoValidation(evaluationInput);
  const inputHash = buildAutoValidationInputHash({
    claimId: params.claimId,
    userId,
    merchantId,
    categoryId,
    zoneId,
    authenticatedEmail: toLowerTrimmedString(claimData.authenticatedEmail),
    declaredRole: toTrimmedString(claimData.declaredRole),
    hasAcceptedDataProcessingConsent: toBoolean(claimData.hasAcceptedDataProcessingConsent),
    hasAcceptedLegitimacyDeclaration: toBoolean(claimData.hasAcceptedLegitimacyDeclaration),
    evidenceKinds,
    merchantOwnerUserId: toTrimmedString(merchantData.ownerUserId),
    merchantOwnershipStatus: toLowerTrimmedString(merchantData.ownershipStatus),
    hasOtherUserActiveClaimOnMerchant,
    hasSameUserActiveEquivalentClaim,
    userBlockedForClaims: toLowerTrimmedString(userData.status) === "blocked",
    authEmail,
    contactReuseDetected,
    abusePatternDetected: false,
    nonTerminalInconsistency: false,
  });

  let didChange = false;
  let noOp = false;
  let previousStatus = claimStatus;
  let nextStatus = claimStatus;

  await db().runTransaction(async (tx) => {
    const freshClaimSnap = await tx.get(claimRef);
    if (!freshClaimSnap.exists) return;
    const fresh = freshClaimSnap.data() ?? {};
    const freshStatus = toLowerTrimmedString(fresh.userVisibleStatus ?? fresh.claimStatus);
    previousStatus = freshStatus;
    if (!params.force && freshStatus !== "submitted") {
      noOp = true;
      nextStatus = freshStatus;
      return;
    }

    const nextPayload: Record<string, unknown> = {
      claimStatus: evaluation.nextStatus,
      userVisibleStatus: evaluation.nextStatus,
      internalWorkflowStatus: mapInternalWorkflowStatus(evaluation.nextStatus),
      workflowManagedBy: CLAIM_AUTO_VALIDATION_SYSTEM,
      autoValidationVersion: CLAIM_AUTO_VALIDATION_VERSION,
      autoValidationStatus: evaluation.autoValidationStatus,
      autoValidationResult: evaluation.autoValidationStatus,
      autoValidationReasons: evaluation.reasonCodes,
      autoValidationReasonCode: evaluation.reasonCodes[0] ?? null,
      autoValidationCompletedAt: FieldValue.serverTimestamp(),
      hasConflict: evaluation.hasConflict,
      hasDuplicate: evaluation.hasDuplicate,
      requiresManualReview: evaluation.requiresManualReview,
      missingEvidence: evaluation.missingEvidence,
      missingEvidenceTypes: evaluation.missingEvidenceTypes,
      riskFlags: evaluation.riskFlags,
      riskPriority: evaluation.riskPriority,
      reviewQueuePriority: evaluation.reviewQueuePriority,
      processedBySystem: true,
      systemVersion: CLAIM_AUTO_VALIDATION_SYSTEM,
      duplicateOfClaimId: evaluation.hasDuplicate
        ? duplicateSnap.docs.find((doc) => doc.id !== params.claimId)?.id ?? null
        : null,
      conflictType: evaluation.hasConflict
        ? evaluation.reasonCodes.includes("existing_owner_conflict")
          ? "merchant_already_owned"
          : "active_claim_exists"
        : null,
      lastAutoValidationHash: inputHash,
      updatedAt: FieldValue.serverTimestamp(),
      lastStatusAt: FieldValue.serverTimestamp(),
    };

    const current = pickAutoValidationState(fresh as Record<string, unknown>);
    const expected = pickAutoValidationState(nextPayload);
    const currentStatusComparable = toLowerTrimmedString(
      fresh.userVisibleStatus ?? fresh.claimStatus
    );
    const shouldSkip =
      currentStatusComparable === evaluation.nextStatus &&
      JSON.stringify(current) === JSON.stringify(expected) &&
      current.lastAutoValidationHash === inputHash;

    if (shouldSkip) {
      noOp = true;
      nextStatus = currentStatusComparable;
      return;
    }

    tx.set(claimRef, nextPayload, { merge: true });
    didChange = true;
    nextStatus = evaluation.nextStatus;
  });

  if (didChange) {
    await syncOwnerPendingAccess({
      userId,
      claimId: params.claimId,
      claimStatus: evaluation.nextStatus,
      merchantId,
    });
  }

  logStructured("merchant_claim_auto_validation", {
    claimId: params.claimId,
    merchantId,
    userId,
    origin: params.origin,
    previousStatus,
    nextStatus,
    didChange,
    noOp,
    reasonCodes: evaluation.reasonCodes,
    hasConflict: evaluation.hasConflict,
    hasDuplicate: evaluation.hasDuplicate,
    requiresManualReview: evaluation.requiresManualReview,
    durationMs: Date.now() - startedAt,
  });

  return {
    claimId: params.claimId,
    merchantId,
    userId,
    previousStatus,
    nextStatus,
    didChange,
    noOp,
    reasonCodes: evaluation.reasonCodes,
  };
}

export function shouldRunAutoValidationFromTransition(params: {
  beforeStatus: string | null;
  afterStatus: string | null;
}): boolean {
  const before = (params.beforeStatus ?? "").trim().toLowerCase();
  const after = (params.afterStatus ?? "").trim().toLowerCase();
  if (after !== "submitted") return false;
  return before !== "submitted";
}

export function readClaimStatusFromSnapshotData(
  data: Record<string, unknown> | undefined
): string | null {
  if (!data) return null;
  const status = data.userVisibleStatus ?? data.claimStatus;
  return typeof status === "string" ? status.trim().toLowerCase() : null;
}

export function readUpdatedAtMillisFromClaimData(data: Record<string, unknown>): number | null {
  return safeTimestampMillis(data.updatedAt);
}
