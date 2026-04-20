export const CLAIM_EVIDENCE_POLICY_VERSION = "2026-04-19.v1";
export const CLAIM_ALLOWED_CATEGORY_IDS = [
  "pharmacy",
  "kiosk",
  "almacen",
  "veterinary",
  "fast_food",
  "casa_de_comidas",
  "gomeria",
] as const;

export type ClaimEvidenceKind =
  | "storefront_photo"
  | "ownership_document"
  | "regulatory_document"
  | "reinforced_relationship_evidence"
  | "operational_point_photo"
  | "alternative_relationship_evidence";

export type ClaimEvidenceStrictnessLevel =
  | "general_local_fixed"
  | "regulated_strict"
  | "reinforced_intermediate"
  | "flexible_contextual"
  | "fallback_safe";

export interface ClaimEvidencePolicy {
  categoryId: string;
  policyVersion: string;
  strictnessLevel: ClaimEvidenceStrictnessLevel;
  requiredPrimaryVisualEvidence: ClaimEvidenceKind[];
  requiredRelationshipEvidence: ClaimEvidenceKind[];
  requiredAdditionalEvidence: ClaimEvidenceKind[];
  optionalSupportingEvidence: ClaimEvidenceKind[];
  allowedAlternativeCombinations: Array<{
    id: string;
    primaryVisualAnyOf: ClaimEvidenceKind[];
    relationshipAnyOf: ClaimEvidenceKind[];
  }>;
  manualReviewTriggers: string[];
  copyOverrides: {
    primaryVisualTitle: string;
    primaryVisualHint: string;
    relationshipHint: string;
  };
  autoValidationTolerance: "strict" | "balanced" | "flexible";
  fallbackMode: "manual_review_safe";
  riskLevel: "low" | "medium" | "high";
  supportsMobileOrInformalOperation: boolean;
}

export interface ClaimEvidenceEvaluation {
  policyVersion: string;
  policyCategoryId: string;
  strictnessLevel: ClaimEvidenceStrictnessLevel;
  requiredEvidenceSatisfied: boolean;
  primaryVisualEvidenceType: ClaimEvidenceKind | null;
  relationshipEvidenceTypes: ClaimEvidenceKind[];
  missingVisual: boolean;
  missingRelationship: boolean;
  missingCategoryEvidence: ClaimEvidenceKind[];
  missingEvidenceTypes: ClaimEvidenceKind[];
  sufficiencyLevel:
    | "insufficient"
    | "sufficient_manual_review"
    | "sufficient";
  manualReviewReasons: string[];
  riskHints: string[];
}

const GENERAL_FIXED_CATEGORY_IDS = new Set([
  "kiosk",
  "kiosco",
  "almacen",
  "rotiseria",
  "casa_de_comidas",
  "casa_comidas",
  "comercio_general",
  "house_food",
  "food_house",
  "gomeria",
  "tire_shop",
]);

const CATEGORY_ALIASES: Record<string, string> = {
  farmacia: "pharmacy",
  drugstore: "pharmacy",
  veterinary: "veterinary",
  veterinaria: "veterinary",
  vet: "veterinary",
  comida_al_paso: "fast_food",
  comida_rapida: "fast_food",
  prepared_food: "casa_de_comidas",
  rotiseria: "casa_de_comidas",
  house_food: "casa_de_comidas",
  kiosk: "kiosk",
  kiosco: "kiosk",
  grocery: "almacen",
  store: "almacen",
  tire_shop: "gomeria",
  supermercado: "unsupported_non_mvp",
  supermarket: "unsupported_non_mvp",
  cafeteria: "unsupported_non_mvp",
  cafe: "unsupported_non_mvp",
  panaderia: "unsupported_non_mvp",
  "panadería": "unsupported_non_mvp",
  confiteria: "unsupported_non_mvp",
  "confitería": "unsupported_non_mvp",
  bakery: "unsupported_non_mvp",
  other: "unsupported_non_mvp",
  otro: "unsupported_non_mvp",
};

const FALLBACK_POLICY: ClaimEvidencePolicy = {
  categoryId: "fallback",
  policyVersion: CLAIM_EVIDENCE_POLICY_VERSION,
  strictnessLevel: "fallback_safe",
  requiredPrimaryVisualEvidence: ["storefront_photo", "operational_point_photo"],
  requiredRelationshipEvidence: ["ownership_document", "alternative_relationship_evidence"],
  requiredAdditionalEvidence: [],
  optionalSupportingEvidence: ["regulatory_document", "reinforced_relationship_evidence"],
  allowedAlternativeCombinations: [
    {
      id: "fallback-contextual",
      primaryVisualAnyOf: ["storefront_photo", "operational_point_photo"],
      relationshipAnyOf: ["ownership_document", "alternative_relationship_evidence"],
    },
  ],
  manualReviewTriggers: [
    "unknown_category_policy_fallback",
    "ambiguous_evidence_context",
  ],
  copyOverrides: {
    primaryVisualTitle: "Evidencia visual principal",
    primaryVisualHint: "Subí una foto clara del punto de atención o frente visible.",
    relationshipHint: "Subí una prueba simple que demuestre vínculo con el comercio.",
  },
  autoValidationTolerance: "balanced",
  fallbackMode: "manual_review_safe",
  riskLevel: "medium",
  supportsMobileOrInformalOperation: true,
};

const POLICY_BY_CATEGORY: Record<string, ClaimEvidencePolicy> = {
  pharmacy: {
    categoryId: "pharmacy",
    policyVersion: CLAIM_EVIDENCE_POLICY_VERSION,
    strictnessLevel: "regulated_strict",
    requiredPrimaryVisualEvidence: ["storefront_photo"],
    requiredRelationshipEvidence: ["ownership_document"],
    requiredAdditionalEvidence: ["regulatory_document"],
    optionalSupportingEvidence: ["reinforced_relationship_evidence"],
    allowedAlternativeCombinations: [],
    manualReviewTriggers: [
      "sensitive_category_requires_manual_review",
      "regulatory_consistency_check_required",
    ],
    copyOverrides: {
      primaryVisualTitle: "Foto del frente de la farmacia",
      primaryVisualHint: "Mostrá el local y cartel identificatorio de forma legible.",
      relationshipHint: "Adjuntá documentación de vínculo y respaldo regulatorio.",
    },
    autoValidationTolerance: "strict",
    fallbackMode: "manual_review_safe",
    riskLevel: "high",
    supportsMobileOrInformalOperation: false,
  },
  veterinary: {
    categoryId: "veterinary",
    policyVersion: CLAIM_EVIDENCE_POLICY_VERSION,
    strictnessLevel: "reinforced_intermediate",
    requiredPrimaryVisualEvidence: ["storefront_photo"],
    requiredRelationshipEvidence: ["ownership_document"],
    requiredAdditionalEvidence: ["reinforced_relationship_evidence"],
    optionalSupportingEvidence: ["regulatory_document"],
    allowedAlternativeCombinations: [],
    manualReviewTriggers: [
      "sensitive_category_requires_manual_review",
      "reinforced_relationship_check_required",
    ],
    copyOverrides: {
      primaryVisualTitle: "Foto del frente de la veterinaria",
      primaryVisualHint: "Mostrá fachada, cartel o identificación del punto de atención.",
      relationshipHint: "Adjuntá una prueba reforzada que te vincule al comercio.",
    },
    autoValidationTolerance: "balanced",
    fallbackMode: "manual_review_safe",
    riskLevel: "high",
    supportsMobileOrInformalOperation: false,
  },
  fast_food: {
    categoryId: "fast_food",
    policyVersion: CLAIM_EVIDENCE_POLICY_VERSION,
    strictnessLevel: "flexible_contextual",
    requiredPrimaryVisualEvidence: ["operational_point_photo", "storefront_photo"],
    requiredRelationshipEvidence: [
      "alternative_relationship_evidence",
      "ownership_document",
      "regulatory_document",
    ],
    requiredAdditionalEvidence: [],
    optionalSupportingEvidence: ["reinforced_relationship_evidence"],
    allowedAlternativeCombinations: [
      {
        id: "fast-food-mobile",
        primaryVisualAnyOf: ["operational_point_photo", "storefront_photo"],
        relationshipAnyOf: [
          "alternative_relationship_evidence",
          "ownership_document",
          "regulatory_document",
        ],
      },
    ],
    manualReviewTriggers: [
      "ambiguous_food_stand_evidence",
      "identity_not_deducible_minimally",
    ],
    copyOverrides: {
      primaryVisualTitle: "Foto del puesto o punto de venta",
      primaryVisualHint: "Mostrá carro, stand, trailer o espacio donde atendés.",
      relationshipHint: "Sumá una prueba simple que te vincule con ese puesto.",
    },
    autoValidationTolerance: "flexible",
    fallbackMode: "manual_review_safe",
    riskLevel: "medium",
    supportsMobileOrInformalOperation: true,
  },
  general_local_fixed: {
    categoryId: "general_local_fixed",
    policyVersion: CLAIM_EVIDENCE_POLICY_VERSION,
    strictnessLevel: "general_local_fixed",
    requiredPrimaryVisualEvidence: ["storefront_photo"],
    requiredRelationshipEvidence: ["ownership_document"],
    requiredAdditionalEvidence: [],
    optionalSupportingEvidence: [
      "regulatory_document",
      "alternative_relationship_evidence",
    ],
    allowedAlternativeCombinations: [],
    manualReviewTriggers: [
      "ambiguous_evidence_context",
      "merchant_identity_weak",
    ],
    copyOverrides: {
      primaryVisualTitle: "Foto del frente del comercio",
      primaryVisualHint: "Subí una imagen clara del frente o acceso principal.",
      relationshipHint: "Adjuntá una prueba simple que demuestre vínculo.",
    },
    autoValidationTolerance: "balanced",
    fallbackMode: "manual_review_safe",
    riskLevel: "low",
    supportsMobileOrInformalOperation: false,
  },
};

function normalizedKinds(
  kinds: ReadonlySet<ClaimEvidenceKind>,
  candidates: ClaimEvidenceKind[]
): ClaimEvidenceKind[] {
  return candidates.filter((kind) => kinds.has(kind));
}

function pickFirstKind(
  kinds: ReadonlySet<ClaimEvidenceKind>,
  candidates: ClaimEvidenceKind[]
): ClaimEvidenceKind | null {
  const found = normalizedKinds(kinds, candidates);
  return found.length > 0 ? found[0] : null;
}

function hasAnyKind(
  kinds: ReadonlySet<ClaimEvidenceKind>,
  candidates: ClaimEvidenceKind[]
): boolean {
  return candidates.some((kind) => kinds.has(kind));
}

export function normalizeClaimCategoryId(categoryId: string): string {
  const normalized = categoryId.trim().toLowerCase();
  return CATEGORY_ALIASES[normalized] ?? normalized;
}

export function isAllowedClaimCategoryId(categoryId: string): boolean {
  if (!categoryId) return false;
  return (CLAIM_ALLOWED_CATEGORY_IDS as readonly string[]).includes(categoryId);
}

export function resolveClaimEvidencePolicy(categoryId: string): ClaimEvidencePolicy {
  const normalized = normalizeClaimCategoryId(categoryId);
  if (normalized in POLICY_BY_CATEGORY) {
    return POLICY_BY_CATEGORY[normalized];
  }
  if (GENERAL_FIXED_CATEGORY_IDS.has(normalized)) {
    return POLICY_BY_CATEGORY.general_local_fixed;
  }
  return FALLBACK_POLICY;
}

export function evaluateEvidenceAgainstPolicy(params: {
  categoryId: string;
  evidenceKinds: ReadonlySet<ClaimEvidenceKind>;
}): ClaimEvidenceEvaluation {
  const policy = resolveClaimEvidencePolicy(params.categoryId);
  const primaryVisualEvidenceType = pickFirstKind(
    params.evidenceKinds,
    policy.requiredPrimaryVisualEvidence
  );
  const relationshipEvidenceTypes = normalizedKinds(
    params.evidenceKinds,
    policy.requiredRelationshipEvidence
  );
  const missingCategoryEvidence = policy.requiredAdditionalEvidence.filter(
    (kind) => !params.evidenceKinds.has(kind)
  );
  const missingVisual = primaryVisualEvidenceType == null;
  const missingRelationship = relationshipEvidenceTypes.length === 0;
  const missingEvidenceTypes: ClaimEvidenceKind[] = [];
  if (missingVisual) {
    missingEvidenceTypes.push(policy.requiredPrimaryVisualEvidence[0] ?? "storefront_photo");
  }
  if (missingRelationship) {
    missingEvidenceTypes.push(policy.requiredRelationshipEvidence[0] ?? "ownership_document");
  }
  missingEvidenceTypes.push(...missingCategoryEvidence);

  const manualReviewReasons = [...policy.manualReviewTriggers];
  if (policy.categoryId === "fallback") {
    manualReviewReasons.push("fallback_category_policy_applied");
  }
  if (
    policy.categoryId === "fast_food" &&
    hasAnyKind(params.evidenceKinds, ["operational_point_photo", "alternative_relationship_evidence"])
  ) {
    manualReviewReasons.push("ambiguous_food_stand_evidence");
  }

  const requiredEvidenceSatisfied = missingEvidenceTypes.length === 0;
  const sufficiencyLevel = !requiredEvidenceSatisfied
    ? "insufficient"
    : manualReviewReasons.length > 0
    ? "sufficient_manual_review"
    : "sufficient";

  const riskHints = [
    ...new Set(
      [
        policy.riskLevel === "high" ? "high_risk_category" : null,
        policy.supportsMobileOrInformalOperation
          ? "supports_mobile_or_informal_operation"
          : null,
      ].filter((item): item is string => item != null)
    ),
  ];

  return {
    policyVersion: policy.policyVersion,
    policyCategoryId: policy.categoryId,
    strictnessLevel: policy.strictnessLevel,
    requiredEvidenceSatisfied,
    primaryVisualEvidenceType,
    relationshipEvidenceTypes,
    missingVisual,
    missingRelationship,
    missingCategoryEvidence,
    missingEvidenceTypes,
    sufficiencyLevel,
    manualReviewReasons: [...new Set(manualReviewReasons)],
    riskHints,
  };
}
