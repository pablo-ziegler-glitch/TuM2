import assert from "node:assert/strict";
import test from "node:test";
import {
  CLAIM_EVIDENCE_POLICY_VERSION,
  evaluateEvidenceAgainstPolicy,
  isAllowedClaimCategoryId,
  normalizeClaimCategoryId,
  resolveClaimEvidencePolicy,
} from "../merchantClaimEvidencePolicy";

test("policy resolver devuelve strict para pharmacy", () => {
  const policy = resolveClaimEvidencePolicy("pharmacy");
  assert.equal(policy.policyVersion, CLAIM_EVIDENCE_POLICY_VERSION);
  assert.equal(policy.strictnessLevel, "regulated_strict");
  assert.deepEqual(policy.requiredAdditionalEvidence, ["regulatory_document"]);
});

test("aliases legacy en español mapean a policy canónica", () => {
  const farmacia = resolveClaimEvidencePolicy("farmacia");
  const veterinaria = resolveClaimEvidencePolicy("veterinaria");
  const comidaAlPaso = resolveClaimEvidencePolicy("comida_al_paso");
  assert.equal(farmacia.categoryId, "pharmacy");
  assert.equal(veterinaria.categoryId, "veterinary");
  assert.equal(comidaAlPaso.categoryId, "fast_food");
});

test("categorías no MVP quedan fuera de allowlist de claims", () => {
  assert.equal(normalizeClaimCategoryId("panaderia"), "unsupported_non_mvp");
  assert.equal(normalizeClaimCategoryId("cafeteria"), "unsupported_non_mvp");
  assert.equal(isAllowedClaimCategoryId("unsupported_non_mvp"), false);
  assert.equal(isAllowedClaimCategoryId("pharmacy"), true);
});

test("fallback policy evita auto-aprobación implícita para categoría desconocida", () => {
  const evaluation = evaluateEvidenceAgainstPolicy({
    categoryId: "legacy_unknown_category",
    evidenceKinds: new Set(["storefront_photo", "ownership_document"]),
  });
  assert.equal(evaluation.requiredEvidenceSatisfied, true);
  assert.equal(evaluation.sufficiencyLevel, "sufficient_manual_review");
  assert.ok(evaluation.manualReviewReasons.includes("fallback_category_policy_applied"));
});

test("fast_food acepta combinación flexible operacional + alternativa", () => {
  const evaluation = evaluateEvidenceAgainstPolicy({
    categoryId: "fast_food",
    evidenceKinds: new Set([
      "operational_point_photo",
      "alternative_relationship_evidence",
    ]),
  });
  assert.equal(evaluation.requiredEvidenceSatisfied, true);
  assert.equal(evaluation.missingEvidenceTypes.length, 0);
});

test("veterinary exige evidencia reforzada específica", () => {
  const evaluation = evaluateEvidenceAgainstPolicy({
    categoryId: "veterinary",
    evidenceKinds: new Set(["storefront_photo", "ownership_document"]),
  });
  assert.equal(evaluation.requiredEvidenceSatisfied, false);
  assert.ok(evaluation.missingEvidenceTypes.includes("reinforced_relationship_evidence"));
});
