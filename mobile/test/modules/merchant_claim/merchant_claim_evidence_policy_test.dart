import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_claim/models/merchant_claim_evidence_policy.dart';
import 'package:tum2/modules/merchant_claim/models/merchant_claim_models.dart';

void main() {
  test('policy pharmacy exige evidencia regulatoria', () {
    final policy = resolveMerchantClaimEvidencePolicy('pharmacy');
    expect(policy.categoryId, 'pharmacy');
    expect(
      policy.requiredAdditionalKinds,
      contains(MerchantClaimEvidenceKind.regulatoryDocument),
    );
  });

  test('policy fast_food acepta visual y vínculo contextual', () {
    final policy = resolveMerchantClaimEvidencePolicy('fast_food');
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

  test('aliases legacy en español resuelven a policy canónica', () {
    expect(
        resolveMerchantClaimEvidencePolicy('farmacia').categoryId, 'pharmacy');
    expect(
      resolveMerchantClaimEvidencePolicy('veterinaria').categoryId,
      'veterinary',
    );
    expect(
      resolveMerchantClaimEvidencePolicy('comida_al_paso').categoryId,
      'fast_food',
    );
  });

  test('allowlist de claims bloquea categorías no MVP', () {
    expect(isAllowedMerchantClaimCategoryId('panaderia'), isFalse);
    expect(isAllowedMerchantClaimCategoryId('bakery'), isFalse);
    expect(isAllowedMerchantClaimCategoryId('otro'), isFalse);
    expect(isAllowedMerchantClaimCategoryId('pharmacy'), isTrue);
    expect(isAllowedMerchantClaimCategoryId('kiosco'), isTrue);
  });
}
