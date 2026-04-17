import { createHash } from "node:crypto";

export const CLAIM_AUTO_VALIDATION_VERSION = 3;
export const CLAIM_AUTO_VALIDATION_SYSTEM = "merchant_claim_auto_validation_v3";

export type ClaimAutoValidationStatus =
  | "under_review"
  | "needs_more_info"
  | "duplicate_claim"
  | "conflict_detected"
  | "rejected";

export type ClaimAutoValidationReasonCode =
  | "auth_user_missing"
  | "claim_email_mismatch"
  | "claim_user_ineligible"
  | "missing_required_consent"
  | "missing_storefront_photo"
  | "missing_basic_relationship_document"
  | "missing_category_required_evidence"
  | "missing_merchant_identification_data"
  | "duplicate_active_claim_same_user_same_merchant"
  | "existing_owner_conflict"
  | "multiple_incompatible_claims"
  | "merchant_state_conflict"
  | "sensitive_category_requires_manual_review"
  | "ambiguous_food_stand_evidence"
  | "risk_signal_contact_reuse"
  | "risk_signal_abuse_pattern"
  | "risk_signal_non_terminal_inconsistency";

export type ClaimAutoValidationRiskPriority = "low" | "medium" | "high" | "critical";

export type ClaimEvidenceKind =
  | "storefront_photo"
  | "ownership_document"
  | "regulatory_document"
  | "reinforced_relationship_evidence"
  | "operational_point_photo"
  | "alternative_relationship_evidence";

export interface MerchantClaimEvidenceSummary {
  kind: string;
}

export interface MerchantClaimAutoValidationInput {
  claimId: string;
  userId: string;
  merchantId: string;
  categoryId: string;
  zoneId: string;
  claimAuthenticatedEmail: string | null;
  authEmail: string | null;
  hasAcceptedDataProcessingConsent: boolean;
  hasAcceptedLegitimacyDeclaration: boolean;
  evidence: MerchantClaimEvidenceSummary[];
  merchantExists: boolean;
  merchantOwnerUserId: string | null;
  merchantOwnershipStatus: string | null;
  hasOtherUserActiveClaimOnMerchant: boolean;
  hasSameUserActiveEquivalentClaim: boolean;
  userBlockedForClaims: boolean;
  riskSignals: {
    contactReuseDetected: boolean;
    abusePatternDetected: boolean;
    nonTerminalInconsistency: boolean;
  };
}

export interface MerchantClaimAutoValidationOutput {
  nextStatus: ClaimAutoValidationStatus;
  reasonCodes: ClaimAutoValidationReasonCode[];
  hasConflict: boolean;
  hasDuplicate: boolean;
  requiresManualReview: boolean;
  missingEvidence: boolean;
  missingEvidenceTypes: string[];
  riskFlags: ClaimAutoValidationReasonCode[];
  riskPriority: ClaimAutoValidationRiskPriority;
  reviewQueuePriority: number;
  autoValidationStatus: "passed" | "blocked";
}

function normalizeKind(kind: string): ClaimEvidenceKind | null {
  const normalized = kind.trim();
  switch (normalized) {
    case "storefront_photo":
    case "ownership_document":
    case "regulatory_document":
    case "reinforced_relationship_evidence":
    case "operational_point_photo":
    case "alternative_relationship_evidence":
      return normalized as ClaimEvidenceKind;
    default:
      return null;
  }
}

function collectKinds(evidence: MerchantClaimEvidenceSummary[]): Set<ClaimEvidenceKind> {
  const kinds = new Set<ClaimEvidenceKind>();
  for (const entry of evidence) {
    const kindRaw = typeof entry.kind === "string" ? entry.kind : "";
    const kind = normalizeKind(kindRaw);
    if (kind) kinds.add(kind);
  }
  return kinds;
}

function isTruthy(value: string | null | undefined): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function resolveReviewQueuePriority(params: {
  status: ClaimAutoValidationStatus;
  riskPriority: ClaimAutoValidationRiskPriority;
}): number {
  if (params.status === "rejected") return 100;
  if (params.status === "conflict_detected") return 90;
  if (params.status === "duplicate_claim") return 75;
  if (params.status === "needs_more_info") return 65;
  if (params.riskPriority === "critical") return 90;
  if (params.riskPriority === "high") return 80;
  if (params.riskPriority === "medium") return 65;
  return 50;
}

function isSensitiveCategory(categoryId: string): boolean {
  return categoryId === "pharmacy" || categoryId === "veterinary";
}

function isFoodStandCategory(categoryId: string): boolean {
  return categoryId === "fast_food";
}

export function evaluateMerchantClaimAutoValidation(
  input: MerchantClaimAutoValidationInput
): MerchantClaimAutoValidationOutput {
  const rejectedReasons: ClaimAutoValidationReasonCode[] = [];
  const conflictReasons: ClaimAutoValidationReasonCode[] = [];
  const duplicateReasons: ClaimAutoValidationReasonCode[] = [];
  const missingReasons: ClaimAutoValidationReasonCode[] = [];
  const missingEvidenceTypes: string[] = [];
  const riskFlags: ClaimAutoValidationReasonCode[] = [];
  const normalizedCategoryId = input.categoryId.trim().toLowerCase();
  const evidenceKinds = collectKinds(input.evidence);

  if (!isTruthy(input.userId)) {
    rejectedReasons.push("auth_user_missing");
  }
  const claimEmail = (input.claimAuthenticatedEmail ?? "").trim().toLowerCase();
  const authEmail = (input.authEmail ?? "").trim().toLowerCase();
  if (!claimEmail || !authEmail || claimEmail !== authEmail) {
    rejectedReasons.push("claim_email_mismatch");
  }
  if (input.userBlockedForClaims) {
    rejectedReasons.push("claim_user_ineligible");
  }
  if (
    input.hasAcceptedDataProcessingConsent !== true ||
    input.hasAcceptedLegitimacyDeclaration !== true
  ) {
    rejectedReasons.push("missing_required_consent");
  }
  if (!input.merchantExists || !isTruthy(input.merchantId) || !isTruthy(input.zoneId)) {
    rejectedReasons.push("missing_merchant_identification_data");
  }

  const hasStorefront = evidenceKinds.has("storefront_photo");
  const hasOperationalPointPhoto = evidenceKinds.has("operational_point_photo");
  const hasVisualEvidence = isFoodStandCategory(normalizedCategoryId)
    ? hasStorefront || hasOperationalPointPhoto
    : hasStorefront;
  if (!hasVisualEvidence) {
    missingReasons.push("missing_storefront_photo");
    missingEvidenceTypes.push("storefront_photo");
  }

  const hasBasicRelationshipDocument = evidenceKinds.has("ownership_document");
  const hasAlternativeRelationshipDocument = evidenceKinds.has(
    "alternative_relationship_evidence"
  );
  const hasRegulatoryDocument = evidenceKinds.has("regulatory_document");
  const hasRelationshipEvidence = isFoodStandCategory(normalizedCategoryId)
    ? hasBasicRelationshipDocument ||
      hasAlternativeRelationshipDocument ||
      hasRegulatoryDocument
    : hasBasicRelationshipDocument;
  if (!hasRelationshipEvidence) {
    missingReasons.push("missing_basic_relationship_document");
    missingEvidenceTypes.push("ownership_document");
  }

  if (normalizedCategoryId === "pharmacy" && !hasRegulatoryDocument) {
    missingReasons.push("missing_category_required_evidence");
    missingEvidenceTypes.push("regulatory_document");
  }
  if (
    normalizedCategoryId === "veterinary" &&
    !evidenceKinds.has("reinforced_relationship_evidence")
  ) {
    missingReasons.push("missing_category_required_evidence");
    missingEvidenceTypes.push("reinforced_relationship_evidence");
  }

  const merchantOwnerUserId = (input.merchantOwnerUserId ?? "").trim();
  const ownershipStatus = (input.merchantOwnershipStatus ?? "").trim().toLowerCase();
  if (
    (merchantOwnerUserId.length > 0 && merchantOwnerUserId !== input.userId) ||
    ownershipStatus === "claimed"
  ) {
    conflictReasons.push("existing_owner_conflict");
  }
  if (ownershipStatus === "disputed" || ownershipStatus === "restricted") {
    conflictReasons.push("merchant_state_conflict");
  }
  if (input.hasOtherUserActiveClaimOnMerchant) {
    conflictReasons.push("multiple_incompatible_claims");
  }

  if (input.hasSameUserActiveEquivalentClaim) {
    duplicateReasons.push("duplicate_active_claim_same_user_same_merchant");
  }

  if (isSensitiveCategory(normalizedCategoryId)) {
    riskFlags.push("sensitive_category_requires_manual_review");
  }
  if (
    isFoodStandCategory(normalizedCategoryId) &&
    (hasAlternativeRelationshipDocument || hasOperationalPointPhoto)
  ) {
    riskFlags.push("ambiguous_food_stand_evidence");
  }
  if (input.riskSignals.contactReuseDetected) {
    riskFlags.push("risk_signal_contact_reuse");
  }
  if (input.riskSignals.abusePatternDetected) {
    riskFlags.push("risk_signal_abuse_pattern");
  }
  if (input.riskSignals.nonTerminalInconsistency) {
    riskFlags.push("risk_signal_non_terminal_inconsistency");
  }

  let nextStatus: ClaimAutoValidationStatus = "under_review";
  if (rejectedReasons.length > 0) {
    nextStatus = "rejected";
  } else if (conflictReasons.length > 0) {
    nextStatus = "conflict_detected";
  } else if (duplicateReasons.length > 0) {
    nextStatus = "duplicate_claim";
  } else if (missingReasons.length > 0) {
    nextStatus = "needs_more_info";
  }

  let riskPriority: ClaimAutoValidationRiskPriority = "low";
  if (nextStatus === "rejected") {
    riskPriority = "critical";
  } else if (nextStatus === "conflict_detected") {
    riskPriority = "high";
  } else if (riskFlags.length >= 2) {
    riskPriority = "high";
  } else if (riskFlags.length === 1 || nextStatus === "duplicate_claim") {
    riskPriority = "medium";
  }

  const reasonCodes = [
    ...rejectedReasons,
    ...conflictReasons,
    ...duplicateReasons,
    ...missingReasons,
    ...riskFlags,
  ];

  return {
    nextStatus,
    reasonCodes,
    hasConflict: conflictReasons.length > 0 || nextStatus === "conflict_detected",
    hasDuplicate: duplicateReasons.length > 0 || nextStatus === "duplicate_claim",
    requiresManualReview: nextStatus === "under_review" || nextStatus === "conflict_detected",
    missingEvidence: missingReasons.length > 0,
    missingEvidenceTypes: [...new Set(missingEvidenceTypes)],
    riskFlags: [...new Set(riskFlags)],
    riskPriority,
    reviewQueuePriority: resolveReviewQueuePriority({
      status: nextStatus,
      riskPriority,
    }),
    autoValidationStatus: nextStatus === "under_review" ? "passed" : "blocked",
  };
}

export function buildAutoValidationInputHash(input: {
  claimId: string;
  userId: string;
  merchantId: string;
  categoryId: string;
  zoneId: string;
  authenticatedEmail: string;
  declaredRole: string;
  hasAcceptedDataProcessingConsent: boolean;
  hasAcceptedLegitimacyDeclaration: boolean;
  evidenceKinds: string[];
  merchantOwnerUserId: string;
  merchantOwnershipStatus: string;
  hasOtherUserActiveClaimOnMerchant: boolean;
  hasSameUserActiveEquivalentClaim: boolean;
  userBlockedForClaims: boolean;
  authEmail: string;
  contactReuseDetected: boolean;
  abusePatternDetected: boolean;
  nonTerminalInconsistency: boolean;
}): string {
  const canonical = JSON.stringify({
    claimId: input.claimId,
    userId: input.userId,
    merchantId: input.merchantId,
    categoryId: input.categoryId,
    zoneId: input.zoneId,
    authenticatedEmail: input.authenticatedEmail,
    declaredRole: input.declaredRole,
    hasAcceptedDataProcessingConsent: input.hasAcceptedDataProcessingConsent,
    hasAcceptedLegitimacyDeclaration: input.hasAcceptedLegitimacyDeclaration,
    evidenceKinds: [...input.evidenceKinds].sort(),
    merchantOwnerUserId: input.merchantOwnerUserId,
    merchantOwnershipStatus: input.merchantOwnershipStatus,
    hasOtherUserActiveClaimOnMerchant: input.hasOtherUserActiveClaimOnMerchant,
    hasSameUserActiveEquivalentClaim: input.hasSameUserActiveEquivalentClaim,
    userBlockedForClaims: input.userBlockedForClaims,
    authEmail: input.authEmail,
    contactReuseDetected: input.contactReuseDetected,
    abusePatternDetected: input.abusePatternDetected,
    nonTerminalInconsistency: input.nonTerminalInconsistency,
  });
  return createHash("sha256").update(canonical).digest("hex");
}
