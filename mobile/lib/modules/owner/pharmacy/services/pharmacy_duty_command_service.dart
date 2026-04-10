import 'package:cloud_functions/cloud_functions.dart';

import '../domain/pharmacy_duty_flow_models.dart';

class PharmacyDutyCommandException implements Exception {
  const PharmacyDutyCommandException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
}

class PharmacyDutyCommandService {
  PharmacyDutyCommandService({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const Duration _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> _call(
    String callableName,
    Map<String, dynamic> payload,
  ) async {
    try {
      final callable = _functions.httpsCallable(callableName);
      final response = await callable.call(payload).timeout(_timeout);
      final data = (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return data;
    } on FirebaseFunctionsException catch (error) {
      throw PharmacyDutyCommandException(
        code: error.code,
        message: error.message ?? 'No se pudo completar la operación.',
        details: (error.details is Map)
            ? (error.details as Map).cast<String, dynamic>()
            : null,
      );
    }
  }

  Future<Map<String, dynamic>> upsertDuty({
    required String merchantId,
    String? dutyId,
    required String date,
    required String startsAtIso,
    required String endsAtIso,
    required String status,
    int? expectedUpdatedAtMillis,
    String? notes,
  }) {
    return _call('upsertPharmacyDuty', {
      'merchantId': merchantId,
      'dutyId': dutyId,
      'date': date,
      'startsAt': startsAtIso,
      'endsAt': endsAtIso,
      'status': status,
      'expectedUpdatedAtMillis': expectedUpdatedAtMillis,
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> changeDutyStatus({
    required String dutyId,
    required String status,
    int? expectedUpdatedAtMillis,
  }) {
    return _call('changePharmacyDutyStatus', {
      'dutyId': dutyId,
      'status': status,
      'expectedUpdatedAtMillis': expectedUpdatedAtMillis,
    });
  }

  Future<void> confirmPharmacyDuty({
    required String dutyId,
  }) async {
    await _call('confirmPharmacyDuty', {
      'dutyId': dutyId,
    });
  }

  Future<String> reportIncident({
    required String dutyId,
    required PharmacyDutyIncidentType incidentType,
    String? note,
  }) async {
    final data = await _call('reportPharmacyDutyIncident', {
      'dutyId': dutyId,
      'incidentType': incidentTypeToApiValue(incidentType),
      'note': note,
    });
    return (data['incidentId'] as String?)?.trim() ?? '';
  }

  Future<
      ({
        String dutyId,
        String originMerchantId,
        int maxCandidatesPerRound,
        List<DutyReplacementCandidate> candidates,
      })> getEligibleCandidates({
    required String dutyId,
  }) async {
    final data = await _call('getEligibleReplacementCandidates', {
      'dutyId': dutyId,
    });
    final candidatesRaw =
        (data['candidates'] as List?)?.cast<Map>() ?? const <Map>[];
    final candidates = candidatesRaw
        .map((entry) => DutyReplacementCandidate.fromMap(
              entry.cast<String, dynamic>(),
            ))
        .toList(growable: false);
    return (
      dutyId: (data['dutyId'] as String?)?.trim() ?? dutyId,
      originMerchantId: (data['originMerchantId'] as String?)?.trim() ?? '',
      maxCandidatesPerRound:
          (data['maxCandidatesPerRound'] as num?)?.toInt() ?? 5,
      candidates: candidates,
    );
  }

  Future<String> createReassignmentRound({
    required String dutyId,
    required List<String> candidateMerchantIds,
  }) async {
    final data = await _call('createReassignmentRound', {
      'dutyId': dutyId,
      'candidateMerchantIds': candidateMerchantIds,
    });
    return (data['roundId'] as String?)?.trim() ?? '';
  }

  Future<String> respondToReassignmentRequest({
    required String requestId,
    required String action,
  }) async {
    final data = await _call('respondToReassignmentRequest', {
      'requestId': requestId,
      'action': action,
    });
    return (data['requestStatus'] as String?)?.trim() ?? '';
  }

  Future<void> cancelReassignmentRound({
    required String roundId,
  }) async {
    await _call('cancelReassignmentRound', {
      'roundId': roundId,
    });
  }
}
