import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operational_signals.dart';

class OwnerOperationalSignalsUnauthorizedException implements Exception {
  const OwnerOperationalSignalsUnauthorizedException();
}

abstract interface class OwnerOperationalSignalsDataSource {
  Future<OperationalSignalsSnapshot> fetchSignals({
    required String merchantId,
  });

  Future<void> saveSignalsIfOwned({
    required String merchantId,
    required String ownerUserId,
    required String updatedBy,
    required Map<OperationalSignalKey, bool> values,
  });
}

class FirestoreOwnerOperationalSignalsDataSource
    implements OwnerOperationalSignalsDataSource {
  FirestoreOwnerOperationalSignalsDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<OperationalSignalsSnapshot> fetchSignals({
    required String merchantId,
  }) async {
    final snapshot = await _firestore
        .collection('merchant_operational_signals')
        .doc(
          merchantId,
        )
        .get();

    if (!snapshot.exists) return OperationalSignalsSnapshot.defaults;

    final data = snapshot.data();
    final signals = (data?['signals'] as Map<String, dynamic>?);
    final updatedAtRaw = data?['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    } else if (updatedAtRaw is DateTime) {
      updatedAt = updatedAtRaw;
    }

    return OperationalSignalsSnapshot(
      signals: OperationalSignals.fromMap(signals),
      updatedAt: updatedAt,
      updatedBy: (data?['updatedBy'] as String?)?.trim(),
    );
  }

  @override
  Future<void> saveSignalsIfOwned({
    required String merchantId,
    required String ownerUserId,
    required String updatedBy,
    required Map<OperationalSignalKey, bool> values,
  }) async {
    // Escritura privada en dual-collection:
    // - Se actualiza solo `merchant_operational_signals/{merchantId}`
    // - El trigger backend recompone `merchant_public`
    // - Flutter nunca escribe `merchant_public`
    // TODO(tum2-0067): agregar test de integración con emulador de Firestore
    // para validar shape exacto del write y enforcement de Rules por ownership.
    final payload = <String, dynamic>{
      for (final entry in values.entries)
        'signals.${entry.key.fieldName}': entry.value,
    };
    final signalsRef =
        _firestore.collection('merchant_operational_signals').doc(merchantId);

    await signalsRef.set(
      {
        ...payload,
        'sourceType': ownerOperationalSignalsSourceType,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
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

  Future<OperationalSignalsSnapshot> fetchSignals({
    required String merchantId,
    required String ownerUserId,
  }) async {
    try {
      return _dataSource.fetchSignals(merchantId: merchantId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }
      rethrow;
    }
  }

  Future<void> updateSignals({
    required String merchantId,
    required String ownerUserId,
    required Map<OperationalSignalKey, bool> values,
  }) async {
    if (values.isEmpty) return;
    try {
      await _dataSource.saveSignalsIfOwned(
        merchantId: merchantId,
        ownerUserId: ownerUserId,
        updatedBy: ownerUserId,
        values: values,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }
      rethrow;
    }
  }

  Future<void> updateSignal({
    required String merchantId,
    required String ownerUserId,
    required OperationalSignalKey key,
    required bool value,
  }) {
    return updateSignals(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      values: {key: value},
    );
  }
}
