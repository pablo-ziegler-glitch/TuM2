import 'package:flutter_test/flutter_test.dart';
import 'package:tum2_admin/modules/merchant_claims/data/merchant_claims_admin_repository.dart';
import 'package:tum2_admin/modules/merchant_claims/domain/merchant_claims_review_logic.dart';

void main() {
  test('aplica filtros locales y orden por riesgo sin lecturas extra', () {
    final items = [
      MerchantClaimReviewItem(
        claimId: 'claim-1',
        merchantId: 'merchant-1',
        userId: 'user-1',
        zoneId: 'zone-a',
        categoryId: 'pharmacy',
        claimStatus: MerchantClaimStatus.underReview,
        declaredRole: 'owner',
        merchantName: 'Farmacia Centro',
        submittedAtMillis: 100,
        createdAtMillis: 100,
        updatedAtMillis: 100,
        hasConflict: false,
        hasDuplicate: false,
        requiresManualReview: true,
        riskPriority: 'medium',
        reviewQueuePriority: 20,
        autoValidationReasons: const ['missing_storefront_photo'],
      ),
      MerchantClaimReviewItem(
        claimId: 'claim-2',
        merchantId: 'merchant-2',
        userId: 'user-2',
        zoneId: 'zone-b',
        categoryId: 'kiosk',
        claimStatus: MerchantClaimStatus.conflictDetected,
        declaredRole: 'owner',
        merchantName: 'Kiosco Sur',
        submittedAtMillis: 200,
        createdAtMillis: 200,
        updatedAtMillis: 200,
        hasConflict: true,
        hasDuplicate: false,
        requiresManualReview: true,
        riskPriority: 'high',
        reviewQueuePriority: 90,
        autoValidationReasons: const ['existing_owner_conflict'],
      ),
    ];

    final filtered = applyMerchantClaimLocalFilters(
      items: items,
      filters: const MerchantClaimsLocalFilters(
        missingInfoOnly: true,
        sort: MerchantClaimsSortOption.riskFirst,
      ),
    );

    expect(filtered.length, 1);
    expect(filtered.first.claimId, 'claim-1');
  });

  test('detecta stale detail por cambio de updatedAt', () {
    expect(
      isClaimDetailStale(
        openedUpdatedAtMillis: 100,
        currentUpdatedAtMillis: 101,
      ),
      isTrue,
    );
    expect(
      isClaimDetailStale(
        openedUpdatedAtMillis: 100,
        currentUpdatedAtMillis: 100,
      ),
      isFalse,
    );
  });

  test('gating de resolucion respeta allowedStatuses', () {
    const detail = MerchantClaimDetail(
      claimId: 'claim-1',
      userIdMasked: '****1234',
      merchantId: 'merchant-1',
      merchantAddress: null,
      merchantStatus: 'active',
      merchantOwnershipStatus: 'unclaimed',
      existingOwnerMasked: null,
      zoneId: 'zone-1',
      categoryId: 'pharmacy',
      claimStatus: MerchantClaimStatus.underReview,
      userVisibleStatus: MerchantClaimStatus.underReview,
      internalWorkflowStatus: 'auto_validation_passed',
      declaredRole: 'owner',
      merchantName: 'Farmacia Centro',
      authenticatedEmailMasked: 'o***r@example.com',
      phoneMasked: '+5***78',
      claimantDisplayNameMasked: 'J***z',
      claimantNoteMasked: null,
      reviewReasonCode: null,
      reviewNotes: null,
      reviewedByUid: null,
      conflictType: null,
      duplicateOfClaimId: null,
      autoValidationReasonCode: null,
      autoValidationReasons: [],
      hasConflict: false,
      hasDuplicate: false,
      requiresManualReview: true,
      missingEvidenceTypes: [],
      evidencePolicyVersion: '2026-04-19.v1',
      evidencePolicyCategoryId: 'pharmacy',
      evidencePolicyStrictnessLevel: 'regulated_strict',
      requiredEvidenceSatisfied: true,
      primaryVisualEvidenceType: 'storefront_photo',
      relationshipEvidenceTypes: ['ownership_document'],
      sufficiencyLevel: 'sufficient_manual_review',
      manualReviewReasons: ['sensitive_category_requires_manual_review'],
      riskHints: ['high_risk_category'],
      riskFlags: [],
      riskPriority: 'low',
      reviewQueuePriority: 1,
      storefrontPhotoUploaded: true,
      ownershipDocumentUploaded: true,
      hasAcceptedDataProcessingConsent: true,
      hasAcceptedLegitimacyDeclaration: true,
      evidenceFiles: [],
      createdAtMillis: 1,
      submittedAtMillis: 2,
      updatedAtMillis: 3,
      reviewedAtMillis: null,
      lastStatusAtMillis: 3,
      autoValidationCompletedAtMillis: 2,
      capabilities: MerchantClaimCapabilities(
        canViewQueue: true,
        canViewDetail: true,
        canEvaluateClaim: true,
        canResolveStandard: true,
        canResolveCritical: false,
        canRevealSensitive: false,
      ),
      allowedStatuses: [
        MerchantClaimStatus.rejected,
        MerchantClaimStatus.needsMoreInfo,
      ],
      canTakeAction: true,
      canRevealSensitive: false,
      timeline: [],
    );

    expect(canResolveClaimStatus(detail, MerchantClaimStatus.rejected), isTrue);
    expect(
      canResolveClaimStatus(detail, MerchantClaimStatus.approved),
      isFalse,
    );
  });
}
