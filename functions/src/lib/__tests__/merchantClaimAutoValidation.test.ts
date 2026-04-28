import assert from "node:assert/strict";
import test from "node:test";
import {
  MerchantClaimAutoValidationInput,
  buildAutoValidationInputHash,
  evaluateMerchantClaimAutoValidation,
} from "../merchantClaimAutoValidation";

function baseInput(): MerchantClaimAutoValidationInput {
  return {
    claimId: "claim-1",
    userId: "user-1",
    merchantId: "merchant-1",
    categoryId: "kiosco",
    zoneId: "zone-1",
    claimAuthenticatedEmail: "owner@example.com",
    authEmail: "owner@example.com",
    hasAcceptedDataProcessingConsent: true,
    hasAcceptedLegitimacyDeclaration: true,
    evidence: [{ kind: "storefront_photo" }, { kind: "ownership_document" }],
    merchantExists: true,
    merchantOwnerUserId: null,
    merchantOwnershipStatus: "unclaimed",
    hasOtherUserActiveClaimOnMerchant: false,
    hasSameUserActiveEquivalentClaim: false,
    userBlockedForClaims: false,
    riskSignals: {
      contactReuseDetected: false,
      abusePatternDetected: false,
      nonTerminalInconsistency: false,
    },
  };
}

test("claim completo general -> under_review", () => {
  const result = evaluateMerchantClaimAutoValidation(baseInput());
  assert.equal(result.nextStatus, "under_review");
  assert.equal(result.evidencePolicyVersion.length > 0, true);
  assert.equal(result.requiredEvidenceSatisfied, true);
});

test("claim sin fachada -> needs_more_info", () => {
  const input = baseInput();
  input.evidence = [{ kind: "ownership_document" }];
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "needs_more_info");
  assert.ok(result.reasonCodes.includes("missing_storefront_photo"));
  assert.equal(result.requiredEvidenceSatisfied, false);
});

test("claim sin documento base -> needs_more_info", () => {
  const input = baseInput();
  input.evidence = [{ kind: "storefront_photo" }];
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "needs_more_info");
  assert.ok(result.reasonCodes.includes("missing_basic_relationship_document"));
});

test("farmacia sin evidencia regulatoria -> needs_more_info", () => {
  const input = baseInput();
  input.categoryId = "farmacia";
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "needs_more_info");
  assert.ok(result.reasonCodes.includes("missing_category_required_evidence"));
});

test("veterinaria sin evidencia reforzada -> needs_more_info", () => {
  const input = baseInput();
  input.categoryId = "veterinaria";
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "needs_more_info");
  assert.ok(result.reasonCodes.includes("missing_category_required_evidence"));
});

test("comida al paso con evidencia flexible válida -> under_review", () => {
  const input = baseInput();
  input.categoryId = "comida_al_paso";
  input.evidence = [
    { kind: "operational_point_photo" },
    { kind: "alternative_relationship_evidence" },
  ];
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "under_review");
  assert.equal(result.requiredEvidenceSatisfied, true);
  assert.ok(result.manualReviewReasons.length > 0);
});

test("mismo user + merchant + claim activo equivalente -> duplicate_claim", () => {
  const input = baseInput();
  input.hasSameUserActiveEquivalentClaim = true;
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "duplicate_claim");
});

test("merchant con owner activo -> conflict_detected", () => {
  const input = baseInput();
  input.merchantOwnerUserId = "owner-actual";
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "conflict_detected");
});

test("claims incompatibles simultáneos -> conflict_detected", () => {
  const input = baseInput();
  input.hasOtherUserActiveClaimOnMerchant = true;
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "conflict_detected");
});

test("email mismatch -> rejected", () => {
  const input = baseInput();
  input.authEmail = "other@example.com";
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "rejected");
  assert.ok(result.reasonCodes.includes("claim_email_mismatch"));
});

test("user bloqueado -> rejected", () => {
  const input = baseInput();
  input.userBlockedForClaims = true;
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "rejected");
  assert.ok(result.reasonCodes.includes("claim_user_ineligible"));
});

test("señal de riesgo moderada sin faltantes -> under_review", () => {
  const input = baseInput();
  input.riskSignals.contactReuseDetected = true;
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "under_review");
  assert.equal(result.riskPriority, "medium");
});

test("precedencia: conflicto gana a duplicado y faltantes", () => {
  const input = baseInput();
  input.hasSameUserActiveEquivalentClaim = true;
  input.hasOtherUserActiveClaimOnMerchant = true;
  input.evidence = [{ kind: "storefront_photo" }];
  const result = evaluateMerchantClaimAutoValidation(input);
  assert.equal(result.nextStatus, "conflict_detected");
});

test("no-op determinístico si resultado idéntico", () => {
  const input = baseInput();
  const first = evaluateMerchantClaimAutoValidation(input);
  const second = evaluateMerchantClaimAutoValidation(input);
  assert.deepEqual(first, second);

  const hashA = buildAutoValidationInputHash({
    claimId: input.claimId,
    userId: input.userId,
    merchantId: input.merchantId,
    categoryId: input.categoryId,
    zoneId: input.zoneId,
    authenticatedEmail: input.claimAuthenticatedEmail ?? "",
    declaredRole: "owner",
    hasAcceptedDataProcessingConsent: input.hasAcceptedDataProcessingConsent,
    hasAcceptedLegitimacyDeclaration: input.hasAcceptedLegitimacyDeclaration,
    evidenceKinds: input.evidence.map((item) => item.kind),
    merchantOwnerUserId: input.merchantOwnerUserId ?? "",
    merchantOwnershipStatus: input.merchantOwnershipStatus ?? "",
    hasOtherUserActiveClaimOnMerchant: input.hasOtherUserActiveClaimOnMerchant,
    hasSameUserActiveEquivalentClaim: input.hasSameUserActiveEquivalentClaim,
    userBlockedForClaims: input.userBlockedForClaims,
    authEmail: input.authEmail ?? "",
    contactReuseDetected: input.riskSignals.contactReuseDetected,
    abusePatternDetected: input.riskSignals.abusePatternDetected,
    nonTerminalInconsistency: input.riskSignals.nonTerminalInconsistency,
  });
  const hashB = buildAutoValidationInputHash({
    claimId: input.claimId,
    userId: input.userId,
    merchantId: input.merchantId,
    categoryId: input.categoryId,
    zoneId: input.zoneId,
    authenticatedEmail: input.claimAuthenticatedEmail ?? "",
    declaredRole: "owner",
    hasAcceptedDataProcessingConsent: input.hasAcceptedDataProcessingConsent,
    hasAcceptedLegitimacyDeclaration: input.hasAcceptedLegitimacyDeclaration,
    evidenceKinds: input.evidence.map((item) => item.kind),
    merchantOwnerUserId: input.merchantOwnerUserId ?? "",
    merchantOwnershipStatus: input.merchantOwnershipStatus ?? "",
    hasOtherUserActiveClaimOnMerchant: input.hasOtherUserActiveClaimOnMerchant,
    hasSameUserActiveEquivalentClaim: input.hasSameUserActiveEquivalentClaim,
    userBlockedForClaims: input.userBlockedForClaims,
    authEmail: input.authEmail ?? "",
    contactReuseDetected: input.riskSignals.contactReuseDetected,
    abusePatternDetected: input.riskSignals.abusePatternDetected,
    nonTerminalInconsistency: input.riskSignals.nonTerminalInconsistency,
  });
  assert.equal(hashA, hashB);
});
