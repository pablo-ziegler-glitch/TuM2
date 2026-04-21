import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tum2_admin/modules/import_data/data/import_data_repository.dart';
import 'package:tum2_admin/modules/merchant_claims/data/merchant_claims_admin_repository.dart';
import 'package:tum2_admin/modules/merchant_claims/screens/merchant_claims_review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets('renderiza lista y abre detalle del claim', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    final repository = _FakeMerchantClaimsRepository(
      claims: [
        MerchantClaimReviewItem(
          claimId: 'claim-1',
          merchantId: 'merchant-1',
          userId: 'user-1',
          zoneId: 'zone-1',
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
          reviewQueuePriority: 10,
          autoValidationReasons: const [],
        ),
      ],
      detail: _buildDetail(canRevealSensitive: false),
    );

    await tester.pumpWidget(
      _buildHarness(repository: repository, fetchZones: _fakeFetchZones),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cola de claims'), findsOneWidget);
    expect(find.text('Farmacia Centro'), findsOneWidget);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Decisiones manuales'), findsOneWidget);
    expect(find.text('Reveal sensible'), findsOneWidget);
  });

  testWidgets('deshabilita reveal cuando la capability no existe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    final repository = _FakeMerchantClaimsRepository(
      claims: const [],
      detail: _buildDetail(canRevealSensitive: false),
    );

    await tester.pumpWidget(
      _buildHarness(
        repository: repository,
        fetchZones: _fakeFetchZones,
        initialLocation: '/claims/claim-1',
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Revelar'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('no puede revelar sensibles'), findsOneWidget);
  });
}

Widget _buildHarness({
  required MerchantClaimsAdminDataSource repository,
  required Future<List<ZoneOption>> Function() fetchZones,
  String initialLocation = '/claims',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/claims',
        builder: (context, state) => MerchantClaimsReviewScreen(
          repository: repository,
          fetchZones: fetchZones,
        ),
      ),
      GoRoute(
        path: '/claims/:claimId',
        builder: (context, state) => MerchantClaimsReviewScreen(
          initialClaimId: state.pathParameters['claimId'],
          repository: repository,
          fetchZones: fetchZones,
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

MerchantClaimDetail _buildDetail({required bool canRevealSensitive}) {
  return MerchantClaimDetail(
    claimId: 'claim-1',
    userIdMasked: '****0001',
    merchantId: 'merchant-1',
    merchantAddress: 'Av. Siempre Viva 123',
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
    autoValidationReasons: const ['sensitive_category_requires_manual_review'],
    hasConflict: false,
    hasDuplicate: false,
    requiresManualReview: true,
    missingEvidenceTypes: const [],
    evidencePolicyVersion: '2026-04-19.v1',
    evidencePolicyCategoryId: 'pharmacy',
    evidencePolicyStrictnessLevel: 'regulated_strict',
    requiredEvidenceSatisfied: true,
    primaryVisualEvidenceType: 'storefront_photo',
    relationshipEvidenceTypes: const ['ownership_document'],
    sufficiencyLevel: 'sufficient_manual_review',
    manualReviewReasons: const ['sensitive_category_requires_manual_review'],
    riskHints: const ['high_risk_category'],
    riskFlags: const [],
    riskPriority: 'medium',
    reviewQueuePriority: 50,
    storefrontPhotoUploaded: true,
    ownershipDocumentUploaded: true,
    hasAcceptedDataProcessingConsent: true,
    hasAcceptedLegitimacyDeclaration: true,
    evidenceFiles: const [],
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
      canResolveCritical: true,
      canRevealSensitive: canRevealSensitive,
      canApprove: true,
      canDownloadSensitiveAttachments: false,
    ),
    allowedStatuses: const [
      MerchantClaimStatus.approved,
      MerchantClaimStatus.rejected,
      MerchantClaimStatus.needsMoreInfo,
    ],
    canTakeAction: true,
    canRevealSensitive: canRevealSensitive,
    timeline: const [
      MerchantClaimTimelineEntry(
        code: 'created',
        label: 'Claim creado',
        atMillis: 1,
        actorMasked: '****0001',
        detail: null,
      ),
    ],
  );
}

Future<List<ZoneOption>> _fakeFetchZones() async {
  return const [
    ZoneOption(
      zoneId: 'zone-1',
      name: 'Ezeiza',
      cityId: 'city-1',
      departmentName: 'Ezeiza',
      countryName: 'Argentina',
      provinceName: 'Buenos Aires',
      localityName: 'Ezeiza',
    ),
  ];
}

class _FakeMerchantClaimsRepository implements MerchantClaimsAdminDataSource {
  _FakeMerchantClaimsRepository({
    required List<MerchantClaimReviewItem> claims,
    required MerchantClaimDetail detail,
  })  : _claims = claims,
        _detail = detail;

  final List<MerchantClaimReviewItem> _claims;
  final MerchantClaimDetail _detail;

  @override
  Future<MerchantClaimReviewPage> listForReview({
    required MerchantClaimReviewFilters filters,
  }) async {
    return MerchantClaimReviewPage(claims: _claims, nextCursor: null);
  }

  @override
  Future<MerchantClaimDetail> getClaimDetail({required String claimId}) async {
    return _detail;
  }

  @override
  Future<MerchantClaimEvaluateResult> evaluateClaim({
    required String claimId,
    int? expectedUpdatedAtMillis,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MerchantClaimResolveResult> resolveClaim({
    required String claimId,
    required MerchantClaimStatus targetStatus,
    String? reviewReasonCode,
    String? reviewNotes,
    int? expectedUpdatedAtMillis,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MerchantClaimRevealResult> revealSensitiveData({
    required String claimId,
    required SensitiveReasonCode reasonCode,
    required List<SensitiveFieldKind> fields,
    String? reasonDetail,
    int? expectedUpdatedAtMillis,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MerchantClaimAttachmentAccessResult> getAttachmentPreviewUrl({
    required String claimId,
    required String attachmentId,
    required SensitiveReasonCode reasonCode,
    String? reasonDetail,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MerchantClaimAttachmentAccessResult> getAttachmentDownloadUrl({
    required String claimId,
    required String attachmentId,
    required SensitiveReasonCode reasonCode,
    String? reasonDetail,
  }) {
    throw UnimplementedError();
  }
}
