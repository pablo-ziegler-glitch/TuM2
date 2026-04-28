import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_claim/models/merchant_claim_evidence_policy.dart';
import 'package:tum2/modules/merchant_claim/models/merchant_claim_models.dart';

void main() {
  test('policy farmacia exige evidencia regulatoria', () {
    final policy = resolveMerchantClaimEvidencePolicy('farmacia');
    expect(policy.categoryId, 'farmacia');
    expect(
      policy.requiredAdditionalKinds,
      contains(MerchantClaimEvidenceKind.regulatoryDocument),
    );
  });

  test('policy comida_al_paso acepta visual y vínculo contextual', () {
    final policy = resolveMerchantClaimEvidencePolicy('comida_al_paso');
    final evidence = [
      const MerchantClaimEvidenceFile(
        id: 'e1',
        kind: MerchantClaimEvidenceKind.operationalPointPhoto,
        storagePath: 'merchant-claims/u1/c1/operational_point_photo/a.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 900,
      ),
      const MerchantClaimEvidenceFile(
        id: 'e2',
        kind: MerchantClaimEvidenceKind.alternativeRelationshipEvidence,
        storagePath:
            'merchant-claims/u1/c1/alternative_relationship_evidence/b.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 1100,
      ),
    ];
    expect(policy.isSatisfied(evidence), isTrue);
  });

  test('fallback fuerza revisión manual por categoría desconocida', () {
    final policy = resolveMerchantClaimEvidencePolicy('legacy_unknown');
    expect(policy.categoryId, 'fallback');
    expect(policy.manualReviewTriggers,
        contains('fallback_category_policy_applied'));
  });

  test('categorías canónicas resuelven a policy canónica', () {
    expect(
        resolveMerchantClaimEvidencePolicy('farmacia').categoryId, 'farmacia');
    expect(
      resolveMerchantClaimEvidencePolicy('veterinaria').categoryId,
      'veterinaria',
    );
    expect(
      resolveMerchantClaimEvidencePolicy('comida_al_paso').categoryId,
      'comida_al_paso',
    );
  });

  test('allowlist de claims bloquea categorías no MVP', () {
    expect(isAllowedMerchantClaimCategoryId('panaderia'), isTrue);
    expect(isAllowedMerchantClaimCategoryId('bakery'), isFalse);
    expect(isAllowedMerchantClaimCategoryId('confiteria'), isTrue);
    expect(isAllowedMerchantClaimCategoryId('otro'), isFalse);
    expect(isAllowedMerchantClaimCategoryId('farmacia'), isTrue);
    expect(isAllowedMerchantClaimCategoryId('kiosco'), isTrue);
  });
}
