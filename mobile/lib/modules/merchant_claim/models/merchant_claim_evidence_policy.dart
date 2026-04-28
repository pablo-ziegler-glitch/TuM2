import 'merchant_claim_models.dart';

const kMerchantClaimEvidencePolicyVersion = '2026-04-19.v1';
const kClaimAllowedCategoryIds = <String>{
  'farmacia',
  'kiosco',
  'almacen',
  'veterinaria',
  'comida_al_paso',
  'casa_de_comidas',
  'gomeria',
  'panaderia',
  'confiteria',
};

class MerchantClaimEvidencePolicy {
  const MerchantClaimEvidencePolicy({
    required this.categoryId,
    required this.policyVersion,
    required this.strictnessLevel,
    required this.primaryVisualAcceptedKinds,
    required this.relationshipAcceptedKinds,
    required this.requiredAdditionalKinds,
    required this.preferredPrimaryVisualKind,
    required this.preferredRelationshipKind,
    required this.title,
    required this.subtitle,
    required this.primaryVisualHint,
    required this.relationshipHint,
    required this.supportsMobileOrInformalOperation,
    required this.manualReviewTriggers,
  });

  final String categoryId;
  final String policyVersion;
  final String strictnessLevel;
  final List<MerchantClaimEvidenceKind> primaryVisualAcceptedKinds;
  final List<MerchantClaimEvidenceKind> relationshipAcceptedKinds;
  final List<MerchantClaimEvidenceKind> requiredAdditionalKinds;
  final MerchantClaimEvidenceKind preferredPrimaryVisualKind;
  final MerchantClaimEvidenceKind preferredRelationshipKind;
  final String title;
  final String subtitle;
  final String primaryVisualHint;
  final String relationshipHint;
  final bool supportsMobileOrInformalOperation;
  final List<String> manualReviewTriggers;

  bool isPrimaryVisualSatisfied(List<MerchantClaimEvidenceFile> evidenceFiles) {
    return evidenceFiles.any(
      (file) => primaryVisualAcceptedKinds.contains(file.kind),
    );
  }

  bool isRelationshipSatisfied(List<MerchantClaimEvidenceFile> evidenceFiles) {
    return evidenceFiles.any(
      (file) => relationshipAcceptedKinds.contains(file.kind),
    );
  }

  bool isAdditionalSatisfied(List<MerchantClaimEvidenceFile> evidenceFiles) {
    for (final requiredKind in requiredAdditionalKinds) {
      final exists = evidenceFiles.any((file) => file.kind == requiredKind);
      if (!exists) return false;
    }
    return true;
  }

  bool isSatisfied(List<MerchantClaimEvidenceFile> evidenceFiles) {
    return isPrimaryVisualSatisfied(evidenceFiles) &&
        isRelationshipSatisfied(evidenceFiles) &&
        isAdditionalSatisfied(evidenceFiles);
  }

  List<MerchantClaimEvidenceKind> missingRequiredKinds(
    List<MerchantClaimEvidenceFile> evidenceFiles,
  ) {
    final missing = <MerchantClaimEvidenceKind>[];
    if (!isPrimaryVisualSatisfied(evidenceFiles)) {
      missing.add(preferredPrimaryVisualKind);
    }
    if (!isRelationshipSatisfied(evidenceFiles)) {
      missing.add(preferredRelationshipKind);
    }
    for (final requiredKind in requiredAdditionalKinds) {
      final exists = evidenceFiles.any((file) => file.kind == requiredKind);
      if (!exists) missing.add(requiredKind);
    }
    return missing;
  }
}

const _generalCategoryIds = <String>{
  'kiosco',
  'almacen',
  'casa_de_comidas',
  'gomeria',
  'panaderia',
  'confiteria',
};

const _generalPolicy = MerchantClaimEvidencePolicy(
  categoryId: 'general_local_fixed',
  policyVersion: kMerchantClaimEvidencePolicyVersion,
  strictnessLevel: 'general_local_fixed',
  primaryVisualAcceptedKinds: [MerchantClaimEvidenceKind.storefrontPhoto],
  relationshipAcceptedKinds: [MerchantClaimEvidenceKind.ownershipDocument],
  requiredAdditionalKinds: [],
  preferredPrimaryVisualKind: MerchantClaimEvidenceKind.storefrontPhoto,
  preferredRelationshipKind: MerchantClaimEvidenceKind.ownershipDocument,
  title: 'Evidencia para comercio con local fijo',
  subtitle: 'Subí evidencia visual y una prueba simple de vínculo.',
  primaryVisualHint: 'Subí una foto clara del frente del comercio.',
  relationshipHint: 'Sumá una prueba simple que demuestre tu vínculo.',
  supportsMobileOrInformalOperation: false,
  manualReviewTriggers: ['ambiguous_evidence_context'],
);

const _fallbackPolicy = MerchantClaimEvidencePolicy(
  categoryId: 'fallback',
  policyVersion: kMerchantClaimEvidencePolicyVersion,
  strictnessLevel: 'fallback_safe',
  primaryVisualAcceptedKinds: [
    MerchantClaimEvidenceKind.storefrontPhoto,
    MerchantClaimEvidenceKind.operationalPointPhoto,
  ],
  relationshipAcceptedKinds: [
    MerchantClaimEvidenceKind.ownershipDocument,
    MerchantClaimEvidenceKind.alternativeRelationshipEvidence,
  ],
  requiredAdditionalKinds: [],
  preferredPrimaryVisualKind: MerchantClaimEvidenceKind.storefrontPhoto,
  preferredRelationshipKind: MerchantClaimEvidenceKind.ownershipDocument,
  title: 'Evidencia contextual del comercio',
  subtitle:
      'Vamos a revisar manualmente la evidencia por categoría no estándar.',
  primaryVisualHint: 'Subí una foto clara del punto de atención.',
  relationshipHint:
      'Sumá una prueba simple que permita vincularte al comercio.',
  supportsMobileOrInformalOperation: true,
  manualReviewTriggers: ['fallback_category_policy_applied'],
);

const _policyByCategory = <String, MerchantClaimEvidencePolicy>{
  'farmacia': MerchantClaimEvidencePolicy(
    categoryId: 'farmacia',
    policyVersion: kMerchantClaimEvidencePolicyVersion,
    strictnessLevel: 'regulated_strict',
    primaryVisualAcceptedKinds: [MerchantClaimEvidenceKind.storefrontPhoto],
    relationshipAcceptedKinds: [MerchantClaimEvidenceKind.ownershipDocument],
    requiredAdditionalKinds: [MerchantClaimEvidenceKind.regulatoryDocument],
    preferredPrimaryVisualKind: MerchantClaimEvidenceKind.storefrontPhoto,
    preferredRelationshipKind: MerchantClaimEvidenceKind.ownershipDocument,
    title: 'Evidencia reforzada para farmacia',
    subtitle: 'Necesitamos validación regulatoria adicional.',
    primaryVisualHint:
        'Subí una foto clara del frente y cartel de la farmacia.',
    relationshipHint:
        'Adjuntá documentación de vínculo y un respaldo regulatorio.',
    supportsMobileOrInformalOperation: false,
    manualReviewTriggers: ['sensitive_category_requires_manual_review'],
  ),
  'veterinaria': MerchantClaimEvidencePolicy(
    categoryId: 'veterinaria',
    policyVersion: kMerchantClaimEvidencePolicyVersion,
    strictnessLevel: 'reinforced_intermediate',
    primaryVisualAcceptedKinds: [MerchantClaimEvidenceKind.storefrontPhoto],
    relationshipAcceptedKinds: [MerchantClaimEvidenceKind.ownershipDocument],
    requiredAdditionalKinds: [
      MerchantClaimEvidenceKind.reinforcedRelationshipEvidence,
    ],
    preferredPrimaryVisualKind: MerchantClaimEvidenceKind.storefrontPhoto,
    preferredRelationshipKind: MerchantClaimEvidenceKind.ownershipDocument,
    title: 'Evidencia reforzada para veterinaria',
    subtitle: 'Pedimos una prueba adicional de vínculo comercial.',
    primaryVisualHint:
        'Subí una foto clara del frente o señalización del local.',
    relationshipHint: 'Adjuntá prueba de vínculo y evidencia reforzada.',
    supportsMobileOrInformalOperation: false,
    manualReviewTriggers: ['sensitive_category_requires_manual_review'],
  ),
  'comida_al_paso': MerchantClaimEvidencePolicy(
    categoryId: 'comida_al_paso',
    policyVersion: kMerchantClaimEvidencePolicyVersion,
    strictnessLevel: 'flexible_contextual',
    primaryVisualAcceptedKinds: [
      MerchantClaimEvidenceKind.operationalPointPhoto,
      MerchantClaimEvidenceKind.storefrontPhoto,
    ],
    relationshipAcceptedKinds: [
      MerchantClaimEvidenceKind.alternativeRelationshipEvidence,
      MerchantClaimEvidenceKind.ownershipDocument,
      MerchantClaimEvidenceKind.regulatoryDocument,
    ],
    requiredAdditionalKinds: [],
    preferredPrimaryVisualKind: MerchantClaimEvidenceKind.operationalPointPhoto,
    preferredRelationshipKind:
        MerchantClaimEvidenceKind.alternativeRelationshipEvidence,
    title: 'Evidencia para puesto o comercio móvil',
    subtitle: 'Aceptamos evidencia contextual del punto de venta.',
    primaryVisualHint:
        'Subí una foto clara de tu puesto, carro, tráiler o stand en operación.',
    relationshipHint:
        'Sumá una prueba simple de vínculo con el puesto (branding, perfil o comprobante).',
    supportsMobileOrInformalOperation: true,
    manualReviewTriggers: ['ambiguous_food_stand_evidence'],
  ),
};

MerchantClaimEvidencePolicy resolveMerchantClaimEvidencePolicy(
  String? categoryId,
) {
  final raw = (categoryId ?? '').trim().toLowerCase();
  final normalized = raw;
  if (_policyByCategory.containsKey(normalized)) {
    return _policyByCategory[normalized]!;
  }
  if (_generalCategoryIds.contains(normalized)) return _generalPolicy;
  return _fallbackPolicy;
}

bool isAllowedMerchantClaimCategoryId(String? categoryId) {
  final raw = (categoryId ?? '').trim().toLowerCase();
  return kClaimAllowedCategoryIds.contains(raw);
}
