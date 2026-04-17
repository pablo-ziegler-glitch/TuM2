import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
      MerchantClaimStatus.draft => 'Draft',
      MerchantClaimStatus.submitted => 'Submitted',
      MerchantClaimStatus.underReview => 'Under review',
      MerchantClaimStatus.needsMoreInfo => 'Needs more info',
      MerchantClaimStatus.approved => 'Approved',
      MerchantClaimStatus.rejected => 'Rejected',
      MerchantClaimStatus.duplicateClaim => 'Duplicate',
      MerchantClaimStatus.conflictDetected => 'Conflict',
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
    required this.zoneId,
    required this.statuses,
    this.limit = 20,
    this.cursor,
  });

  final String zoneId;
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
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAtMillis,
    required this.originalFileName,
  });

  final String id;
  final String kind;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final int? uploadedAtMillis;
  final String? originalFileName;
}

class MerchantClaimDetail {
  const MerchantClaimDetail({
    required this.claimId,
    required this.userId,
    required this.merchantId,
    required this.zoneId,
    required this.categoryId,
    required this.claimStatus,
    required this.userVisibleStatus,
    required this.internalWorkflowStatus,
    required this.declaredRole,
    required this.merchantName,
    required this.authenticatedEmail,
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
    required this.hasConflict,
    required this.hasDuplicate,
    required this.requiresManualReview,
    required this.missingEvidenceTypes,
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
  });

  final String claimId;
  final String userId;
  final String merchantId;
  final String? zoneId;
  final String? categoryId;
  final MerchantClaimStatus claimStatus;
  final MerchantClaimStatus userVisibleStatus;
  final String? internalWorkflowStatus;
  final String? declaredRole;
  final String? merchantName;
  final String? authenticatedEmail;
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
  final bool hasConflict;
  final bool hasDuplicate;
  final bool requiresManualReview;
  final List<String> missingEvidenceTypes;
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

class MerchantClaimsAdminRepository {
  MerchantClaimsAdminRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<MerchantClaimReviewPage> listForReview({
    required MerchantClaimReviewFilters filters,
  }) async {
    final callable = _functions.httpsCallable('listMerchantClaimsForReview');
    final response = await callable.call(<String, dynamic>{
      'zoneId': filters.zoneId,
      'statuses': filters.statuses.map((status) => status.apiValue).toList(),
      'limit': filters.limit,
      if (filters.cursor != null)
        'cursorCreatedAtMillis': filters.cursor!.createdAtMillis,
      if (filters.cursor != null) 'cursorClaimId': filters.cursor!.claimId,
    });

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
    final snapshot = await _firestore
        .collection('merchant_claims')
        .doc(claimId)
        .get();
    if (!snapshot.exists) {
      throw StateError('No encontramos el claim seleccionado.');
    }
    final data = snapshot.data() ?? <String, dynamic>{};
    final evidenceFiles = _asList(data['evidenceFiles'])
        .map(_asMap)
        .map(
          (item) => MerchantClaimEvidenceFile(
            id: _readString(item['id']) ?? '',
            kind: _readString(item['kind']) ?? '',
            storagePath: _readString(item['storagePath']) ?? '',
            contentType: _readString(item['contentType']) ?? '',
            sizeBytes: _readInt(item['sizeBytes']) ?? 0,
            uploadedAtMillis: _timestampToMillis(item['uploadedAt']),
            originalFileName: _readString(item['originalFileName']),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);

    return MerchantClaimDetail(
      claimId: snapshot.id,
      userId: _readString(data['userId']) ?? '',
      merchantId: _readString(data['merchantId']) ?? '',
      zoneId: _readString(data['zoneId']),
      categoryId: _readString(data['categoryId']),
      claimStatus: merchantClaimStatusFromApi(
        _readString(data['claimStatus']) ?? 'draft',
      ),
      userVisibleStatus: merchantClaimStatusFromApi(
        _readString(data['userVisibleStatus']) ??
            _readString(data['claimStatus']) ??
            'draft',
      ),
      internalWorkflowStatus: _readString(data['internalWorkflowStatus']),
      declaredRole: _readString(data['declaredRole']),
      merchantName: _readString(data['merchantName']),
      authenticatedEmail: _readString(data['authenticatedEmail']),
      phoneMasked: _readString(data['phoneMasked']),
      claimantDisplayNameMasked: _readString(data['claimantDisplayNameMasked']),
      claimantNoteMasked: _readString(data['claimantNoteMasked']),
      reviewReasonCode: _readString(data['reviewReasonCode']),
      reviewNotes: _readString(data['reviewNotes']),
      reviewedByUid: _readString(data['reviewedByUid']),
      conflictType: _readString(data['conflictType']),
      duplicateOfClaimId: _readString(data['duplicateOfClaimId']),
      autoValidationReasonCode: _readString(data['autoValidationReasonCode']),
      autoValidationReasons: _asList(data['autoValidationReasons'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      hasConflict: _readBool(data['hasConflict']),
      hasDuplicate: _readBool(data['hasDuplicate']),
      requiresManualReview: _readBool(data['requiresManualReview']),
      missingEvidenceTypes: _asList(data['missingEvidenceTypes'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      riskFlags: _asList(data['riskFlags'])
          .map((item) => _readString(item) ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      riskPriority: _readString(data['riskPriority']),
      reviewQueuePriority: _readInt(data['reviewQueuePriority']),
      storefrontPhotoUploaded: _readBool(data['storefrontPhotoUploaded']),
      ownershipDocumentUploaded: _readBool(data['ownershipDocumentUploaded']),
      hasAcceptedDataProcessingConsent: _readBool(
        data['hasAcceptedDataProcessingConsent'],
      ),
      hasAcceptedLegitimacyDeclaration: _readBool(
        data['hasAcceptedLegitimacyDeclaration'],
      ),
      evidenceFiles: evidenceFiles,
      createdAtMillis: _timestampToMillis(data['createdAt']),
      submittedAtMillis: _timestampToMillis(data['submittedAt']),
      updatedAtMillis: _timestampToMillis(data['updatedAt']),
      reviewedAtMillis: _timestampToMillis(data['reviewedAt']),
      lastStatusAtMillis: _timestampToMillis(data['lastStatusAt']),
    );
  }

  Future<MerchantClaimEvaluateResult> evaluateClaim({
    required String claimId,
  }) async {
    final callable = _functions.httpsCallable('evaluateMerchantClaim');
    final response = await callable.call(<String, dynamic>{'claimId': claimId});
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
  }) async {
    final callable = _functions.httpsCallable('resolveMerchantClaim');
    final response = await callable.call(<String, dynamic>{
      'claimId': claimId,
      'userVisibleStatus': targetStatus.apiValue,
      if (reviewReasonCode != null && reviewReasonCode.trim().isNotEmpty)
        'reviewReasonCode': reviewReasonCode.trim(),
      if (reviewNotes != null && reviewNotes.trim().isNotEmpty)
        'reviewNotes': reviewNotes.trim(),
    });
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
  }) async {
    final callable = _functions.httpsCallable(
      'revealMerchantClaimSensitiveData',
    );
    final response = await callable.call(<String, dynamic>{
      'claimId': claimId,
      'reasonCode': reasonCode,
      'fields': fields.map((field) => field.apiValue).toList(growable: false),
    });
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

int? _timestampToMillis(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
