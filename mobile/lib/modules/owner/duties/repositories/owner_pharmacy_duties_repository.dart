import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_pharmacy_duty.dart';
import '../../pharmacy/services/pharmacy_duty_command_service.dart';

class OwnerDutyMutationResult {
  const OwnerDutyMutationResult({
    required this.dutyId,
    required this.updatedAtMillis,
  });

  final String dutyId;
  final int updatedAtMillis;
}

class OwnerDutyException implements Exception {
  const OwnerDutyException({
    required this.code,
    required this.message,
    this.conflict,
  });

  final String code;
  final String message;
  final OwnerDutyConflict? conflict;
}

class OwnerDutyConflict {
  const OwnerDutyConflict({
    required this.dutyId,
    required this.startsAtMillis,
    required this.endsAtMillis,
    required this.date,
  });

  final String dutyId;
  final int startsAtMillis;
  final int endsAtMillis;
  final String date;
}

class OwnerPharmacyDutiesRepository {
  OwnerPharmacyDutiesRepository({
    FirebaseFirestore? firestore,
    PharmacyDutyCommandService? commandService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _commandService = commandService ?? PharmacyDutyCommandService();

  final FirebaseFirestore _firestore;
  final PharmacyDutyCommandService _commandService;

  static const Duration _timeout = Duration(seconds: 8);

  Future<List<OwnerPharmacyDuty>> listMonthDuties({
    required String merchantId,
    required DateTime month,
  }) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    String asDateKey(DateTime date) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final snap = await _firestore
        .collection('pharmacy_duties')
        .where('merchantId', isEqualTo: merchantId)
        .where('date', isGreaterThanOrEqualTo: asDateKey(firstDay))
        .where('date', isLessThanOrEqualTo: asDateKey(lastDay))
        .orderBy('date')
        .get()
        .timeout(_timeout);

    final duties = snap.docs
        .map((doc) => OwnerPharmacyDuty.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
    duties.sort((a, b) {
      final byDate = a.dateKey.compareTo(b.dateKey);
      if (byDate != 0) return byDate;
      return a.startsAt.compareTo(b.startsAt);
    });
    return duties;
  }

  Future<OwnerDutyMutationResult> upsertDuty({
    required String merchantId,
    String? dutyId,
    required String date,
    required String startsAtIso,
    required String endsAtIso,
    required OwnerPharmacyDutyStatus status,
    int? expectedUpdatedAtMillis,
    String? notes,
  }) async {
    try {
      final data = await _commandService.upsertDuty(
        merchantId: merchantId,
        dutyId: dutyId,
        date: date,
        startsAtIso: startsAtIso,
        endsAtIso: endsAtIso,
        status: statusToString(status),
        expectedUpdatedAtMillis: expectedUpdatedAtMillis,
        notes: notes,
      );
      return OwnerDutyMutationResult(
        dutyId: (data['dutyId'] as String?)?.trim() ?? '',
        updatedAtMillis: (data['updatedAtMillis'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } on PharmacyDutyCommandException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  Future<OwnerDutyMutationResult> changeDutyStatus({
    required String dutyId,
    required OwnerPharmacyDutyStatus status,
    int? expectedUpdatedAtMillis,
  }) async {
    try {
      final data = await _commandService.changeDutyStatus(
        dutyId: dutyId,
        status: statusToString(status),
        expectedUpdatedAtMillis: expectedUpdatedAtMillis,
      );
      return OwnerDutyMutationResult(
        dutyId: (data['dutyId'] as String?)?.trim() ?? dutyId,
        updatedAtMillis: (data['updatedAtMillis'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } on PharmacyDutyCommandException catch (error) {
      throw _mapFunctionError(error);
    }
  }

  OwnerDutyException _mapFunctionError(PharmacyDutyCommandException error) {
    final details = (error.details is Map)
        ? error.details!
        : const <String, dynamic>{};
    final detailCode = (details['code'] as String?)?.trim();
    if (detailCode == 'duty_conflict') {
      final conflictRaw =
          (details['conflict'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      return OwnerDutyException(
        code: 'duty_conflict',
        message: 'Ya existe un turno cargado para ese día y horario.',
        conflict: OwnerDutyConflict(
          dutyId: (conflictRaw['dutyId'] as String?)?.trim() ?? '',
          startsAtMillis: (conflictRaw['startsAtMillis'] as num?)?.toInt() ?? 0,
          endsAtMillis: (conflictRaw['endsAtMillis'] as num?)?.toInt() ?? 0,
          date: (conflictRaw['date'] as String?)?.trim() ?? '',
        ),
      );
    }
    if (error.code == 'aborted') {
      return const OwnerDutyException(
        code: 'stale_write',
        message: 'Este turno fue actualizado en otra sesión.',
      );
    }
    if (error.code == 'permission-denied') {
      return const OwnerDutyException(
        code: 'permission_denied',
        message: 'Tu comercio no está habilitado para cargar guardias.',
      );
    }
    if (error.code == 'failed-precondition') {
      return OwnerDutyException(
        code: 'failed_precondition',
        message: error.message,
      );
    }
    return OwnerDutyException(
      code: error.code,
      message: error.message,
    );
  }
}
