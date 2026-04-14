import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operational_signals.dart';

class OwnerOperationalSignalsUnauthorizedException implements Exception {
  const OwnerOperationalSignalsUnauthorizedException();
}

abstract interface class OwnerOperationalSignalsDataSource {
  Future<OwnerOperationalSignal?> fetchSignal({
    required String merchantId,
  });

  Future<void> upsertSignal({
    required String merchantId,
    required String ownerUserId,
    required OperationalSignalType signalType,
    required String? message,
  });

  Future<void> clearSignal({
    required String merchantId,
    required String ownerUserId,
  });
}

class FirestoreOwnerOperationalSignalsDataSource
    implements OwnerOperationalSignalsDataSource {
  FirestoreOwnerOperationalSignalsDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<OwnerOperationalSignal?> fetchSignal({
    required String merchantId,
  }) async {
    final snapshot = await _firestore
        .collection('merchant_operational_signals')
        .doc(merchantId)
        .get();

    if (!snapshot.exists) return null;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final ownerUserId = (data['ownerUserId'] as String?)?.trim();
    final updatedByUid = (data['updatedByUid'] as String?)?.trim();
    // Mantener parseo aun en docs de origen scheduler sin ownerUserId.
    final resolvedOwnerUserId = ownerUserId != null && ownerUserId.isNotEmpty
        ? ownerUserId
        : (updatedByUid != null && updatedByUid.isNotEmpty
            ? updatedByUid
            : '__system__');

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    // Compatibilidad de migración desde esquema legacy.
    final legacyTemporaryClosed = data['temporaryClosed'] == true ||
        (data['signals'] is Map<String, dynamic> &&
            (data['signals'] as Map<String, dynamic>)['temporaryClosed'] ==
                true);
    final signalType = OperationalSignalTypeX.fromFirestoreValue(
      data['signalType'] as String?,
    );
    final isActive = data['isActive'] == true || legacyTemporaryClosed;
    final effectiveType =
        legacyTemporaryClosed && signalType == OperationalSignalType.none
            ? OperationalSignalType.temporaryClosure
            : signalType;

    return OwnerOperationalSignal(
      merchantId: merchantId,
      ownerUserId: resolvedOwnerUserId,
      signalType: effectiveType,
      isActive: effectiveType == OperationalSignalType.none ? false : isActive,
      message: (data['message'] as String?)?.trim(),
      forceClosed: data['forceClosed'] == true ||
          effectiveType == OperationalSignalType.vacation ||
          effectiveType == OperationalSignalType.temporaryClosure,
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ??
          operationalSignalSchemaVersion,
      updatedAt: readDate(data['updatedAt']),
      createdAt: readDate(data['createdAt']),
      updatedByUid: (data['updatedByUid'] as String?)?.trim(),
      isOpenNow: data['isOpenNow'] is bool ? data['isOpenNow'] as bool : null,
      todayScheduleLabel: (data['todayScheduleLabel'] as String?)?.trim(),
      hasScheduleConfigured: data['hasScheduleConfigured'] is bool
          ? data['hasScheduleConfigured'] as bool
          : null,
    );
  }

  @override
  Future<void> upsertSignal({
    required String merchantId,
    required String ownerUserId,
    required OperationalSignalType signalType,
    required String? message,
  }) async {
    final normalizedMessage = (message ?? '').trim();
    final signalRef =
        _firestore.collection('merchant_operational_signals').doc(merchantId);

    await signalRef.set(
      {
        'merchantId': merchantId,
        'ownerUserId': ownerUserId,
        'signalType': signalType.firestoreValue,
        'isActive': signalType != OperationalSignalType.none,
        'message': normalizedMessage.isEmpty ? null : normalizedMessage,
        'forceClosed': signalType.forcesClosed,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': ownerUserId,
        'schemaVersion': operationalSignalSchemaVersion,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> clearSignal({
    required String merchantId,
    required String ownerUserId,
  }) async {
    final signalRef =
        _firestore.collection('merchant_operational_signals').doc(merchantId);
    await signalRef.set(
      {
        'merchantId': merchantId,
        'ownerUserId': ownerUserId,
        'signalType': OperationalSignalType.none.firestoreValue,
        'isActive': false,
        'message': null,
        'forceClosed': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': ownerUserId,
        'schemaVersion': operationalSignalSchemaVersion,
      },
      SetOptions(merge: true),
    );
  }
}

class OwnerOperationalSignalsRepository {
  OwnerOperationalSignalsRepository({
    OwnerOperationalSignalsDataSource? dataSource,
  }) : _dataSource = dataSource ?? FirestoreOwnerOperationalSignalsDataSource();

  final OwnerOperationalSignalsDataSource _dataSource;

  Future<OwnerOperationalSignal?> fetchSignal({
    required String merchantId,
  }) async {
    try {
      return _dataSource.fetchSignal(merchantId: merchantId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }
      rethrow;
    }
  }

  Future<void> upsertSignal({
    required String merchantId,
    required String ownerUserId,
    required OperationalSignalType signalType,
    required String? message,
  }) async {
    try {
      await _dataSource.upsertSignal(
        merchantId: merchantId,
        ownerUserId: ownerUserId,
        signalType: signalType,
        message: message,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }
      rethrow;
    }
  }

  Future<void> clearSignal({
    required String merchantId,
    required String ownerUserId,
  }) async {
    try {
      await _dataSource.clearSignal(
        merchantId: merchantId,
        ownerUserId: ownerUserId,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }
      rethrow;
    }
  }
}
