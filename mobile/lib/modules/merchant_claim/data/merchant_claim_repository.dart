import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/merchant_claim_models.dart';

class MerchantClaimRepositoryException implements Exception {
  const MerchantClaimRepositoryException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;
}

class MerchantClaimRepository {
  MerchantClaimRepository({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxSearchLimit = 20;

  Future<List<ClaimableMerchantCandidate>> searchClaimableMerchants({
    required String zoneId,
    required String query,
    int limit = 12,
  }) async {
    try {
      final callable = _functions.httpsCallable('searchClaimableMerchants');
      final response = await callable.call(<String, dynamic>{
        'zoneId': zoneId.trim(),
        'query': query.trim(),
        'limit': max(1, min(limit, _maxSearchLimit)),
      }).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final merchantsRaw =
          (data['merchants'] as List?)?.cast<Map>() ?? const [];
      return merchantsRaw
          .map(
            (raw) => ClaimableMerchantCandidate(
              merchantId: (raw['merchantId'] as String? ?? '').trim(),
              name: (raw['name'] as String? ?? '').trim(),
              categoryId: (raw['categoryId'] as String? ?? '').trim(),
              zoneId: (raw['zoneId'] as String? ?? '').trim(),
              ownershipStatus: (raw['ownershipStatus'] as String? ?? '').trim(),
              hasOwner: raw['hasOwner'] == true,
              address: (raw['address'] as String?)?.trim(),
            ),
          )
          .where((merchant) => merchant.merchantId.isNotEmpty)
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on TimeoutException catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-search-timeout',
        message: 'La búsqueda tardó más de lo esperado. Probá de nuevo.',
        cause: error,
      );
    } catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-search-failed',
        message: 'No pudimos buscar comercios para reclamo.',
        cause: error,
      );
    }
  }

  Future<({String claimId, MerchantClaimStatus claimStatus})> upsertDraft(
    MerchantClaimDraftInput input,
  ) async {
    try {
      final callable = _functions.httpsCallable('upsertMerchantClaimDraft');
      final response = await callable.call(<String, dynamic>{
        'claimId': input.claimId,
        'merchantId': input.merchantId,
        'declaredRole': input.declaredRole.apiValue,
        'phone': input.phone,
        'claimantDisplayName': input.claimantDisplayName,
        'claimantNote': input.claimantNote,
        'hasAcceptedDataProcessingConsent':
            input.hasAcceptedDataProcessingConsent,
        'hasAcceptedLegitimacyDeclaration':
            input.hasAcceptedLegitimacyDeclaration,
        'evidenceFiles':
            input.evidenceFiles.map((file) => file.toPayload()).toList(),
      }).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final claimId = (data['claimId'] as String? ?? '').trim();
      if (claimId.isEmpty) {
        throw const MerchantClaimRepositoryException(
          code: 'claim-draft-invalid-response',
          message: 'No pudimos guardar el borrador del reclamo.',
        );
      }
      final statusRaw = (data['claimStatus'] as String? ?? '').trim();
      return (
        claimId: claimId,
        claimStatus: MerchantClaimStatusX.fromApi(statusRaw),
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on TimeoutException catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-draft-timeout',
        message: 'Guardar borrador tardó más de lo esperado.',
        cause: error,
      );
    }
  }

  Future<MerchantClaimStatusSummary> submitClaim({
    required String claimId,
  }) async {
    try {
      final callable = _functions.httpsCallable('submitMerchantClaim');
      final response = await callable
          .call(<String, dynamic>{'claimId': claimId}).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final status = MerchantClaimStatusX.fromApi(
        (data['claimStatus'] as String? ?? '').trim(),
      );
      final summary = await getMyStatus(claimId: claimId);
      if (summary != null) return summary;
      return MerchantClaimStatusSummary(
        claimId: claimId,
        claimStatus: status,
        merchantId: '',
        updatedAtMillis: null,
        submittedAtMillis: (data['submittedAtMillis'] as num?)?.toInt(),
        needsMoreInfo: status == MerchantClaimStatus.needsMoreInfo,
        conflictDetected: status == MerchantClaimStatus.conflictDetected,
        duplicateDetected: status == MerchantClaimStatus.duplicateClaim,
        duplicateOfClaimId: null,
        conflictType: null,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on TimeoutException catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-submit-timeout',
        message: 'El envío tardó más de lo esperado.',
        cause: error,
      );
    }
  }

  Future<MerchantClaimStatusSummary?> getMyStatus({String? claimId}) async {
    try {
      final callable = _functions.httpsCallable('getMyMerchantClaimStatus');
      final response = await callable.call(<String, dynamic>{
        if (claimId != null && claimId.trim().isNotEmpty)
          'claimId': claimId.trim(),
      }).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final claimRaw = data['claim'];
      if (claimRaw is! Map) return null;
      final claim = claimRaw.cast<String, dynamic>();
      final id = (claim['claimId'] as String? ?? '').trim();
      if (id.isEmpty) return null;
      return MerchantClaimStatusSummary(
        claimId: id,
        claimStatus: MerchantClaimStatusX.fromApi(
          (claim['claimStatus'] as String? ?? '').trim(),
        ),
        merchantId: (claim['merchantId'] as String? ?? '').trim(),
        merchantName: (claim['merchantName'] as String?)?.trim(),
        updatedAtMillis: (claim['updatedAtMillis'] as num?)?.toInt(),
        submittedAtMillis: (claim['submittedAtMillis'] as num?)?.toInt(),
        needsMoreInfo: claim['needsMoreInfo'] == true,
        conflictDetected: claim['conflictDetected'] == true,
        duplicateDetected: claim['duplicateDetected'] == true,
        duplicateOfClaimId: (claim['duplicateOfClaimId'] as String?)?.trim(),
        conflictType: (claim['conflictType'] as String?)?.trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    } on TimeoutException catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-status-timeout',
        message: 'No pudimos obtener el estado del reclamo.',
        cause: error,
      );
    }
  }

  Future<MerchantClaimEvidenceFile> uploadEvidence({
    required String claimId,
    required MerchantClaimEvidenceUpload upload,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const MerchantClaimRepositoryException(
        code: 'claim-auth-required',
        message: 'Necesitás iniciar sesión para subir evidencia.',
      );
    }
    final uid = user.uid;
    final safeName = upload.originalFileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .toLowerCase();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${upload.id}_$safeName';
    final storagePath =
        'merchant-claims/$uid/$claimId/${upload.kind.apiValue}/$fileName';
    final ref = _storage.ref(storagePath);

    try {
      await ref.putData(
        upload.bytes,
        SettableMetadata(
          contentType: upload.contentType,
          cacheControl: 'private,max-age=3600',
        ),
      );
      return MerchantClaimEvidenceFile(
        id: upload.id,
        kind: upload.kind,
        storagePath: storagePath,
        contentType: upload.contentType,
        sizeBytes: upload.bytes.length,
        originalFileName: upload.originalFileName,
      );
    } on FirebaseException catch (error) {
      throw MerchantClaimRepositoryException(
        code: 'claim-evidence-upload-failed',
        message: _mapStorageErrorMessage(error),
        cause: error,
      );
    }
  }

  MerchantClaimRepositoryException _mapFunctionsError(
    FirebaseFunctionsException error,
  ) {
    final details = error.details;
    if (details is Map) {
      final code = details['code'];
      if (code is String && code.trim().isNotEmpty) {
        return MerchantClaimRepositoryException(
          code: code.trim(),
          message: error.message ?? 'No se pudo completar la operación.',
          cause: error,
        );
      }
    }
    return MerchantClaimRepositoryException(
      code: error.code,
      message: error.message ?? 'No se pudo completar la operación.',
      cause: error,
    );
  }

  String _mapStorageErrorMessage(FirebaseException error) {
    if (error.code == 'unauthorized') {
      return 'No tenés permisos para subir esta evidencia.';
    }
    if (error.code == 'canceled') {
      return 'Se canceló la carga del archivo.';
    }
    return 'No pudimos subir el archivo. Revisá tu conexión y reintentá.';
  }
}
