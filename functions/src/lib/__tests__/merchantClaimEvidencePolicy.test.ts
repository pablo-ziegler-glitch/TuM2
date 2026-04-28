import assert from "node:assert/strict";
import test from "node:test";
import {
  CLAIM_EVIDENCE_POLICY_VERSION,
  evaluateEvidenceAgainstPolicy,
  isAllowedClaimCategoryId,
  normalizeClaimCategoryId,
  resolveClaimEvidencePolicy,
} from "../merchantClaimEvidencePolicy";

test("policy resolver devuelve strict para farmacia", () => {
  const policy = resolveClaimEvidencePolicy("farmacia");
  assert.equal(policy.policyVersion, CLAIM_EVIDENCE_POLICY_VERSION);
  assert.equal(policy.strictnessLevel, "regulated_strict");
  assert.deepEqual(policy.requiredAdditionalEvidence, ["regulatory_document"]);
});

test("categorías canónicas resuelven policy canónica", () => {
  const farmacia = resolveClaimEvidencePolicy("farmacia");
  const veterinaria = resolveClaimEvidencePolicy("veterinaria");
  const comidaAlPaso = resolveClaimEvidencePolicy("comida_al_paso");
  assert.equal(farmacia.categoryId, "farmacia");
  assert.equal(veterinaria.categoryId, "veterinaria");
  assert.equal(comidaAlPaso.categoryId, "comida_al_paso");
});

test("categorías no MVP quedan fuera de allowlist de claims", () => {
  assert.equal(normalizeClaimCategoryId("panaderia"), "panaderia");
  assert.equal(normalizeClaimCategoryId("bakery"), "bakery");
  assert.equal(normalizeClaimCategoryId("confiteria"), "confiteria");
  assert.equal(normalizeClaimCategoryId("cafeteria"), "cafeteria");
  assert.equal(isAllowedClaimCategoryId("bakery"), false);
  assert.equal(isAllowedClaimCategoryId("cafeteria"), false);
  assert.equal(isAllowedClaimCategoryId("panaderia"), true);
  assert.equal(isAllowedClaimCategoryId("confiteria"), true);
  assert.equal(isAllowedClaimCategoryId("farmacia"), true);
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

test("comida_al_paso acepta combinación flexible operacional + alternativa", () => {
  const evaluation = evaluateEvidenceAgainstPolicy({
    categoryId: "comida_al_paso",
    evidenceKinds: new Set([
      "operational_point_photo",
      "alternative_relationship_evidence",
    ]),
  });
  assert.equal(evaluation.requiredEvidenceSatisfied, true);
  assert.equal(evaluation.missingEvidenceTypes.length, 0);
});

test("veterinaria exige evidencia reforzada específica", () => {
  const evaluation = evaluateEvidenceAgainstPolicy({
    categoryId: "veterinaria",
    evidenceKinds: new Set(["storefront_photo", "ownership_document"]),
  });
  assert.equal(evaluation.requiredEvidenceSatisfied, false);
  assert.ok(evaluation.missingEvidenceTypes.includes("reinforced_relationship_evidence"));
});
