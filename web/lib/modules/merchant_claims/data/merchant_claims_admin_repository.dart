import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum MerchantClaimStatus {
  draft,
  submitted,
  underReview,
  needsMoreInfo,
  approved,
  rejected,
  duplicateClaim,
  conflictDetected,
}

MerchantClaimStatus merchantClaimStatusFromApi(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'draft' => MerchantClaimStatus.draft,
    'submitted' => MerchantClaimStatus.submitted,
    'under_review' => MerchantClaimStatus.underReview,
    'needs_more_info' => MerchantClaimStatus.needsMoreInfo,
    'approved' => MerchantClaimStatus.approved,
    'rejected' => MerchantClaimStatus.rejected,
    'duplicate_claim' => MerchantClaimStatus.duplicateClaim,
    'conflict_detected' => MerchantClaimStatus.conflictDetected,
    _ => MerchantClaimStatus.draft,
  };
}

extension MerchantClaimStatusX on MerchantClaimStatus {
  String get apiValue {
    return switch (this) {
      MerchantClaimStatus.draft => 'draft',
      MerchantClaimStatus.submitted => 'submitted',
      MerchantClaimStatus.underReview => 'under_review',
      MerchantClaimStatus.needsMoreInfo => 'needs_more_info',
      MerchantClaimStatus.approved => 'approved',
      MerchantClaimStatus.rejected => 'rejected',
      MerchantClaimStatus.duplicateClaim => 'duplicate_claim',
      MerchantClaimStatus.conflictDetected => 'conflict_detected',
    };
  }

  String get label {
    return switch (this) {
      MerchantClaimStatus.draft => 'Borrador',
      MerchantClaimStatus.submitted => 'Enviado',
      MerchantClaimStatus.underReview => 'En revision',
      MerchantClaimStatus.needsMoreInfo => 'Requiere mas informacion',
      MerchantClaimStatus.approved => 'Aprobado',
      MerchantClaimStatus.rejected => 'Rechazado',
      MerchantClaimStatus.duplicateClaim => 'Duplicado',
      MerchantClaimStatus.conflictDetected => 'Conflicto',
    };
  }
}

enum SensitiveFieldKind { phone, claimantDisplayName, claimantNote }

extension SensitiveFieldKindX on SensitiveFieldKind {
  String get apiValue {
    return switch (this) {
      SensitiveFieldKind.phone => 'phone',
      SensitiveFieldKind.claimantDisplayName => 'claimantDisplayName',
      SensitiveFieldKind.claimantNote => 'claimantNote',
    };
  }
}

class MerchantClaimReviewCursor {
  const MerchantClaimReviewCursor({
    required this.createdAtMillis,
    required this.claimId,
  });

  final int createdAtMillis;
  final String claimId;
}

class MerchantClaimReviewFilters {
  const MerchantClaimReviewFilters({
    required this.provinceName,
    required this.departmentName,
    this.zoneId,
    required this.statuses,
    this.limit = 20,
    this.cursor,
  });

  final String provinceName;
  final String departmentName;
  final String? zoneId;
  final List<MerchantClaimStatus> statuses;
  final int limit;
  final MerchantClaimReviewCursor? cursor;
}

class MerchantClaimReviewItem {
  const MerchantClaimReviewItem({
    required this.claimId,
    required this.merchantId,
    required this.userId,
    required this.zoneId,
    required this.categoryId,
    required this.claimStatus,
    required this.declaredRole,
    required this.merchantName,
    required this.submittedAtMillis,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    required this.hasConflict,
    required this.hasDuplicate,
    required this.requiresManualReview,
    required this.riskPriority,
    required this.reviewQueuePriority,
    required this.autoValidationReasons,
  });

  final String claimId;
  final String merchantId;
  final String userId;
  final String zoneId;
  final String? categoryId;
  final MerchantClaimStatus claimStatus;
  final String declaredRole;
  final String? merchantName;
  final int? submittedAtMillis;
  final int? createdAtMillis;
  final int? updatedAtMillis;
  final bool hasConflict;
  final bool hasDuplicate;
  final bool requiresManualReview;
  final String? riskPriority;
  final int? reviewQueuePriority;
  final List<String> autoValidationReasons;
}

class MerchantClaimReviewPage {
  const MerchantClaimReviewPage({
    required this.claims,
    required this.nextCursor,
  });

  final List<MerchantClaimReviewItem> claims;
  final MerchantClaimReviewCursor? nextCursor;
}

class MerchantClaimEvidenceFile {
  const MerchantClaimEvidenceFile({
    required this.id,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAtMillis,
    required this.originalFileName,
  });

  final String id;
  final String kind;
  final String contentType;
  final int sizeBytes;
  final int? uploadedAtMillis;
  final String? originalFileName;
}

class MerchantClaimTimelineEntry {
  const MerchantClaimTimelineEntry({
    required this.code,
    required this.label,
    required this.atMillis,
    required this.actorMasked,
    required this.detail,
  });

  final String code;
  final String label;
  final int atMillis;
  final String? actorMasked;
  final String? detail;
}

class MerchantClaimCapabilities {
  const MerchantClaimCapabilities({
    required this.canViewQueue,
    required this.canViewDetail,
    required this.canEvaluateClaim,
    required this.canResolveStandard,
    required this.canResolveCritical,
    required this.canRevealSensitive,
  });

  final bool canViewQueue;
  final bool canViewDetail;
  final bool canEvaluateClaim;
  final bool canResolveStandard;
  final bool canResolveCritical;
  final bool canRevealSensitive;
}

class MerchantClaimDetail {
  const MerchantClaimDetail({
    required this.claimId,
    required this.userIdMasked,
    required this.merchantId,
    required this.merchantAddress,
    required this.merchantStatus,
    required this.merchantOwnershipStatus,
    required this.existingOwnerMasked,
    required this.zoneId,
    required this.categoryId,
    required this.claimStatus,
    required this.userVisibleStatus,
    required this.internalWorkflowStatus,
    required this.declaredRole,
    required this.merchantName,
    required this.authenticatedEmailMasked,
    required this.phoneMasked,
    required this.claimantDisplayNameMasked,
    required this.claimantNoteMasked,
    required this.reviewReasonCode,
    required this.reviewNotes,
    required this.reviewedByUid,
    required this.conflictType,
    required this.duplicateOfClaimId,
    required this.autoValidationReasonCode,
    required this.autoValidationReasons,
    this.evidencePolicyVersion,
    this.evidencePolicyCategoryId,
    this.evidencePolicyStrictnessLevel,
    this.sufficiencyLevel,
    this.requiredEvidenceSatisfied = false,
    this.primaryVisualEvidenceType,
    this.relationshipEvidenceTypes = const <String>[],
    this.manualReviewReasons = const <String>[],
    this.riskHints = const <String>[],
    required this.hasConflict,
    required this.hasDuplicate,
    required this.requiresManualReview,
    required this.missingEvidenceTypes,
    required this.evidencePolicyVersion,
    required this.evidencePolicyCategoryId,
    required this.evidencePolicyStrictnessLevel,
    required this.requiredEvidenceSatisfied,
    required this.primaryVisualEvidenceType,
    required this.relationshipEvidenceTypes,
    required this.sufficiencyLevel,
    required this.manualReviewReasons,
    required this.riskHints,
    required this.riskFlags,
    required this.riskPriority,
    required this.reviewQueuePriority,
    required this.storefrontPhotoUploaded,
    required this.ownershipDocumentUploaded,
    required this.hasAcceptedDataProcessingConsent,
    required this.hasAcceptedLegitimacyDeclaration,
    required this.evidenceFiles,
    required this.createdAtMillis,
    required this.submittedAtMillis,
    required this.updatedAtMillis,
    required this.reviewedAtMillis,
    required this.lastStatusAtMillis,
    required this.autoValidationCompletedAtMillis,
    required this.capabilities,
    required this.allowedStatuses,
    required this.canTakeAction,
    required this.canRevealSensitive,
    required this.timeline,
  });

  final String claimId;
  final String userIdMasked;
  final String merchantId;
  final String? merchantAddress;
  final String? merchantStatus;
  final String? merchantOwnershipStatus;
  final String? existingOwnerMasked;
  final String? zoneId;
  final String? categoryId;
  final MerchantClaimStatus claimStatus;
  final MerchantClaimStatus userVisibleStatus;
  final String? internalWorkflowStatus;
  final String? declaredRole;
  final String? merchantName;
  final String? authenticatedEmailMasked;
  final String? phoneMasked;
  final String? claimantDisplayNameMasked;
  final String? claimantNoteMasked;
  final String? reviewReasonCode;
  final String? reviewNotes;
  final String? reviewedByUid;
  final String? conflictType;
  final String? duplicateOfClaimId;
  final String? autoValidationReasonCode;
  final List<String> autoValidationReasons;
  final String? evidencePolicyVersion;
  final String? evidencePolicyCategoryId;
  final String? evidencePolicyStrictnessLevel;
  final String? sufficiencyLevel;
  final bool requiredEvidenceSatisfied;
  final String? primaryVisualEvidenceType;
  final List<String> relationshipEvidenceTypes;
  final List<String> manualReviewReasons;
  final List<String> riskHints;
  final bool hasConflict;
  final bool hasDuplicate;
  final bool requiresManualReview;
  final List<String> missingEvidenceTypes;
  final String? evidencePolicyVersion;
  final String? evidencePolicyCategoryId;
  final String? evidencePolicyStrictnessLevel;
  final bool requiredEvidenceSatisfied;
  final String? primaryVisualEvidenceType;
  final List<String> relationshipEvidenceTypes;
  final String? sufficiencyLevel;
  final List<String> manualReviewReasons;
  final List<String> riskHints;
  final List<String> riskFlags;
  final String? riskPriority;
  final int? reviewQueuePriority;
  final bool storefrontPhotoUploaded;
  final bool ownershipDocumentUploaded;
  final bool hasAcceptedDataProcessingConsent;
  final bool hasAcceptedLegitimacyDeclaration;
  final List<MerchantClaimEvidenceFile> evidenceFiles;
  final int? createdAtMillis;
  final int? submittedAtMillis;
  final int? updatedAtMillis;
  final int? reviewedAtMillis;
  final int? lastStatusAtMillis;
  final int? autoValidationCompletedAtMillis;
  final MerchantClaimCapabilities capabilities;
  final List<MerchantClaimStatus> allowedStatuses;
  final bool canTakeAction;
  final bool canRevealSensitive;
  final List<MerchantClaimTimelineEntry> timeline;
}

class MerchantClaimEvaluateResult {
  const MerchantClaimEvaluateResult({
    required this.claimId,
    required this.claimStatus,
    required this.reasonCode,
    required this.duplicateOfClaimId,
    required this.updatedAtMillis,
  });

  final String claimId;
  final MerchantClaimStatus claimStatus;
  final String? reasonCode;
  final String? duplicateOfClaimId;
  final int? updatedAtMillis;
}

class MerchantClaimResolveResult {
  const MerchantClaimResolveResult({
    required this.claimId,
    required this.claimStatus,
    required this.reviewedAtMillis,
  });

  final String claimId;
  final MerchantClaimStatus claimStatus;
  final int? reviewedAtMillis;
}

class MerchantClaimRevealResult {
  const MerchantClaimRevealResult({
    required this.claimId,
    required this.expiresAtMillis,
    required this.revealed,
  });

  final String claimId;
  final int expiresAtMillis;
  final Map<SensitiveFieldKind, String> revealed;
}

abstract class MerchantClaimsAdminDataSource {
  Future<MerchantClaimReviewPage> listForReview({
    required MerchantClaimReviewFilters filters,
  });

  Future<MerchantClaimDetail> getClaimDetail({required String claimId});

  Future<MerchantClaimEvaluateResult> evaluateClaim({
    required String claimId,
    int? expectedUpdatedAtMillis,
  });

  Future<MerchantClaimResolveResult> resolveClaim({
    required String claimId,
    required MerchantClaimStatus targetStatus,
    String? reviewReasonCode,
    String? reviewNotes,
    int? expectedUpdatedAtMillis,
  });

  Future<MerchantClaimRevealResult> revealSensitiveData({
    required String claimId,
    required String reasonCode,
    required List<SensitiveFieldKind> fields,
    int? expectedUpdatedAtMillis,
  });
}

class MerchantClaimsAdminRepository implements MerchantClaimsAdminDataSource {
  MerchantClaimsAdminRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<HttpsCallableResult<dynamic>> _callWithAuthRetry({
    required String callableName,
    required Map<String, dynamic> payload,
  }) async {
    Future<HttpsCallableResult<dynamic>> invoke() async {
      final user = _auth.currentUser;
      if (user != null) {
        // Fuerza refresh de token antes del callable para evitar sesiones
        // visibles con token vencido/no propagado.
        await user.getIdToken(true);
      }
      final callable = _functions.httpsCallable(callableName);
      return callable.call(payload);
    }

    try {
      return await invoke();
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'unauthenticated') rethrow;
      final user = _auth.currentUser;
      if (user == null) rethrow;
      await user.getIdToken(true);
      return invoke();
    }
  }

  Future<MerchantClaimReviewPage> listForReview({
    required MerchantClaimReviewFilters filters,
  }) async {
    final response = await _callWithAuthRetry(
      callableName: 'listMerchantClaimsForReview',
      payload: <String, dynamic>{
        'provinceName': filters.provinceName,
        'departmentName': filters.departmentName,
        if (filters.zoneId != null && filters.zoneId!.trim().isNotEmpty)
          'zoneId': filters.zoneId,
        'statuses': filters.statuses.map((status) => status.apiValue).toList(),
        'limit': filters.limit,
        if (filters.cursor != null)
          'cursorCreatedAtMillis': filters.cursor!.createdAtMillis,
        if (filters.cursor != null) 'cursorClaimId': filters.cursor!.claimId,
      },
    );

    final data = _asMap(response.data);
    final claimsRaw = _asList(data['claims']);
    final claims = claimsRaw
        .map(_asMap)
        .map(
          (row) => MerchantClaimReviewItem(
            claimId: _readString(row['claimId']) ?? '',
            merchantId: _readString(row['merchantId']) ?? '',
            userId: _readString(row['userId']) ?? '',
            zoneId: _readString(row['zoneId']) ?? '',
            categoryId: _readString(row['categoryId']),
            claimStatus: merchantClaimStatusFromApi(
              _readString(row['claimStatus']) ?? 'draft',
            ),
            declaredRole: _readString(row['declaredRole']) ?? 'owner',
            merchantName: _readString(row['merchantName']),
            submittedAtMillis: _readInt(row['submittedAtMillis']),
            createdAtMillis: _readInt(row['createdAtMillis']),
            updatedAtMillis: _readInt(row['updatedAtMillis']),
            hasConflict: _readBool(row['hasConflict']),
            hasDuplicate: _readBool(row['hasDuplicate']),
            requiresManualReview: _readBool(row['requiresManualReview']),
            riskPriority: _readString(row['riskPriority']),
            reviewQueuePriority: _readInt(row['reviewQueuePriority']),
            autoValidationReasons: _asList(row['autoValidationReasons'])
                .map((item) => _readString(item) ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
          ),
        )
        .where((row) => row.claimId.isNotEmpty)
        .toList(growable: false);

    final nextCursorRaw = _asMapOrNull(data['nextCursor']);
    final nextCursor = nextCursorRaw == null
        ? null
        : MerchantClaimReviewCursor(
            createdAtMillis: _readInt(nextCursorRaw['createdAtMillis']) ?? 0,
            claimId: _readString(nextCursorRaw['claimId']) ?? '',
          );

    if (nextCursor != null &&
        (nextCursor.createdAtMillis <= 0 || nextCursor.claimId.isEmpty)) {
      return MerchantClaimReviewPage(claims: claims, nextCursor: null);
    }

    return MerchantClaimReviewPage(claims: claims, nextCursor: nextCursor);
  }

  Future<MerchantClaimDetail> getClaimDetail({required String claimId}) async {
    final response = await _callWithAuthRetry(
      callableName: 'getMerchantClaimReviewDetail',
      payload: <String, dynamic>{'claimId': claimId},
    );
    final data = _asMap(response.data);
    final claim = _asMap(data['claim']);
    final capabilitiesRaw = _asMap(data['capabilities']);
    final timeline = _asList(data['timeline'])
        .map(_asMap)
        .map(
          (item) => MerchantClaimTimelineEntry(
            code: _readString(item['code']) ?? '',
            label: _readString(item['label']) ?? '',
            atMillis: _readInt(item['atMillis']) ?? 0,
            actorMasked: _readString(item['actorMasked']),
            detail: _readString(item['detail']),
          ),
        )
        .where((item) => item.code.isNotEmpty && item.label.isNotEmpty)
        .toList(growable: false);
    final allowedStatuses = _asList(data['allowedStatuses'])
        .map((item) => merchantClaimStatusFromApi(_readString(item) ?? 'draft'))
        .toList(growable: false);

    return MerchantClaimDetail(
      claimId: _readString(claim['claimId']) ?? claimId,
      userIdMasked: _readString(claim['userIdMasked']) ?? '****',
      merchantId: _readString(claim['merchantId']) ?? '',
      merchantAddress: _readString(claim['merchantAddress']),
      merchantStatus: _readString(claim['merchantStatus']),
      merchantOwnershipStatus: _readString(claim['merchantOwnershipStatus']),
      existingOwnerMasked: _readString(claim['existingOwnerMasked']),
      zoneId: _readString(claim['zoneId']),
      categoryId: _readString(claim['categoryId']),
      claimStatus: merchantClaimStatusFromApi(
        _readString(claim['claimStatus']) ?? 'draft',
      ),
      userVisibleStatus: merchantClaimStatusFromApi(
        _readString(claim['userVisibleStatus']) ??
            _readString(claim['claimStatus']) ??
            'draft',
      ),
      internalWorkflowStatus: _readString(claim['internalWorkflowStatus']),
      declaredRole: _readString(claim['declaredRole']),
      merchantName: _readString(claim['merchantName']),
      authenticatedEmailMasked: _readString(claim['authenticatedEmailMasked']),
      phoneMasked: _readString(claim['phoneMasked']),
      claimantDisplayNameMasked: _readString(
        claim['claimantDisplayNameMasked'],
      ),
      claimantNoteMasked: _readString(claim['claimantNoteMasked']),
      reviewReasonCode: _readString(claim['reviewReasonCode']),
      reviewNotes: _readString(claim['reviewNotes']),
      reviewedByUid: _readString(claim['reviewedByUidMasked']),
      conflictType: _readString(claim['conflictType']),
      duplicateOfClaimId: _readString(claim['duplicateOfClaimId']),
      autoValidationReasonCode: _readString(claim['autoValidationReasonCode']),
      autoValidationReasons: _asList(claim['autoValidationReasons'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      hasConflict: _readBool(claim['hasConflict']),
      hasDuplicate: _readBool(claim['hasDuplicate']),
      requiresManualReview: _readBool(claim['requiresManualReview']),
      missingEvidenceTypes: _asList(claim['missingEvidenceTypes'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      evidencePolicyVersion: _readString(claim['evidencePolicyVersion']),
      evidencePolicyCategoryId: _readString(claim['evidencePolicyCategoryId']),
      evidencePolicyStrictnessLevel:
          _readString(claim['evidencePolicyStrictnessLevel']),
      requiredEvidenceSatisfied: _readBool(claim['requiredEvidenceSatisfied']),
      primaryVisualEvidenceType:
          _readString(claim['primaryVisualEvidenceType']),
      relationshipEvidenceTypes: _asList(claim['relationshipEvidenceTypes'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      sufficiencyLevel: _readString(claim['sufficiencyLevel']),
      manualReviewReasons: _asList(claim['manualReviewReasons'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      riskHints: _asList(claim['riskHints'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      riskFlags: _asList(claim['riskFlags'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      riskPriority: _readString(claim['riskPriority']),
      reviewQueuePriority: _readInt(claim['reviewQueuePriority']),
      storefrontPhotoUploaded: _readBool(claim['storefrontPhotoUploaded']),
      ownershipDocumentUploaded: _readBool(claim['ownershipDocumentUploaded']),
      hasAcceptedDataProcessingConsent: _readBool(
        claim['hasAcceptedDataProcessingConsent'],
      ),
      hasAcceptedLegitimacyDeclaration: _readBool(
        claim['hasAcceptedLegitimacyDeclaration'],
      ),
      evidenceFiles: _asList(claim['evidenceFiles'])
          .map(_asMap)
          .map(
            (item) => MerchantClaimEvidenceFile(
              id: _readString(item['id']) ?? '',
              kind: _readString(item['kind']) ?? '',
              contentType: _readString(item['contentType']) ?? '',
              sizeBytes: _readInt(item['sizeBytes']) ?? 0,
              uploadedAtMillis: _readInt(item['uploadedAtMillis']),
              originalFileName: _readString(item['originalFileName']),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      createdAtMillis: _readInt(claim['createdAtMillis']),
      submittedAtMillis: _readInt(claim['submittedAtMillis']),
      updatedAtMillis: _readInt(claim['updatedAtMillis']),
      reviewedAtMillis: _readInt(claim['reviewedAtMillis']),
      lastStatusAtMillis: _readInt(claim['lastStatusAtMillis']),
      autoValidationCompletedAtMillis: _readInt(
        claim['autoValidationCompletedAtMillis'],
      ),
      capabilities: MerchantClaimCapabilities(
        canViewQueue: _readBool(capabilitiesRaw['canViewQueue']),
        canViewDetail: _readBool(capabilitiesRaw['canViewDetail']),
        canEvaluateClaim: _readBool(capabilitiesRaw['canEvaluateClaim']),
        canResolveStandard: _readBool(capabilitiesRaw['canResolveStandard']),
        canResolveCritical: _readBool(capabilitiesRaw['canResolveCritical']),
        canRevealSensitive: _readBool(capabilitiesRaw['canRevealSensitive']),
      ),
      allowedStatuses: allowedStatuses,
      canTakeAction: _readBool(data['canTakeAction']),
      canRevealSensitive: _readBool(data['canRevealSensitive']),
      timeline: timeline,
    );
  }

  Future<MerchantClaimEvaluateResult> evaluateClaim({
    required String claimId,
    int? expectedUpdatedAtMillis,
  }) async {
    final response = await _callWithAuthRetry(
      callableName: 'evaluateMerchantClaim',
      payload: <String, dynamic>{
        'claimId': claimId,
        if (expectedUpdatedAtMillis != null)
          'expectedUpdatedAtMillis': expectedUpdatedAtMillis,
      },
    );
    final data = _asMap(response.data);
    return MerchantClaimEvaluateResult(
      claimId: _readString(data['claimId']) ?? claimId,
      claimStatus: merchantClaimStatusFromApi(
        _readString(data['claimStatus']) ?? 'draft',
      ),
      reasonCode: _readString(data['reasonCode']),
      duplicateOfClaimId: _readString(data['duplicateOfClaimId']),
      updatedAtMillis: _readInt(data['updatedAtMillis']),
    );
  }

  Future<MerchantClaimResolveResult> resolveClaim({
    required String claimId,
    required MerchantClaimStatus targetStatus,
    String? reviewReasonCode,
    String? reviewNotes,
    int? expectedUpdatedAtMillis,
  }) async {
    final response = await _callWithAuthRetry(
      callableName: 'resolveMerchantClaim',
      payload: <String, dynamic>{
        'claimId': claimId,
        'userVisibleStatus': targetStatus.apiValue,
        if (reviewReasonCode != null && reviewReasonCode.trim().isNotEmpty)
          'reviewReasonCode': reviewReasonCode.trim(),
        if (reviewNotes != null && reviewNotes.trim().isNotEmpty)
          'reviewNotes': reviewNotes.trim(),
        if (expectedUpdatedAtMillis != null)
          'expectedUpdatedAtMillis': expectedUpdatedAtMillis,
      },
    );
    final data = _asMap(response.data);
    return MerchantClaimResolveResult(
      claimId: _readString(data['claimId']) ?? claimId,
      claimStatus: merchantClaimStatusFromApi(
        _readString(data['claimStatus']) ?? 'draft',
      ),
      reviewedAtMillis: _readInt(data['reviewedAtMillis']),
    );
  }

  Future<MerchantClaimRevealResult> revealSensitiveData({
    required String claimId,
    required String reasonCode,
    required List<SensitiveFieldKind> fields,
    int? expectedUpdatedAtMillis,
  }) async {
    final response = await _callWithAuthRetry(
      callableName: 'revealMerchantClaimSensitiveData',
      payload: <String, dynamic>{
        'claimId': claimId,
        'reasonCode': reasonCode,
        'fields': fields.map((field) => field.apiValue).toList(growable: false),
        if (expectedUpdatedAtMillis != null)
          'expectedUpdatedAtMillis': expectedUpdatedAtMillis,
      },
    );
    final data = _asMap(response.data);
    final revealedRaw = _asMap(data['revealed']);
    final revealed = <SensitiveFieldKind, String>{};
    for (final entry in revealedRaw.entries) {
      final value = entry.value;
      if (value is! String) continue;
      final key = entry.key.trim();
      if (key == SensitiveFieldKind.phone.apiValue) {
        revealed[SensitiveFieldKind.phone] = value;
        continue;
      }
      if (key == SensitiveFieldKind.claimantDisplayName.apiValue) {
        revealed[SensitiveFieldKind.claimantDisplayName] = value;
        continue;
      }
      if (key == SensitiveFieldKind.claimantNote.apiValue) {
        revealed[SensitiveFieldKind.claimantNote] = value;
      }
    }
    return MerchantClaimRevealResult(
      claimId: _readString(data['claimId']) ?? claimId,
      expiresAtMillis: _readInt(data['expiresAtMillis']) ?? 0,
      revealed: revealed,
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic rawValue) {
      return MapEntry(key.toString(), rawValue);
    });
  }
  return <String, dynamic>{};
}

Map<String, dynamic>? _asMapOrNull(Object? value) {
  final map = _asMap(value);
  if (map.isEmpty) return null;
  return map;
}

List<Object?> _asList(Object? value) {
  if (value is List) return value.cast<Object?>();
  return const <Object?>[];
}

String? _readString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}
