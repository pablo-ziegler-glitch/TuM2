import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/operational_signals.dart';

class OwnerOperationalSignalsUnauthorizedException implements Exception {
  const OwnerOperationalSignalsUnauthorizedException();
}

abstract interface class OwnerOperationalSignalsDataSource {
  Future<OperationalSignalsSnapshot> fetchSignals({
    required String merchantId,
  });

  Future<String?> fetchOwnerUserId({
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
  Future<String?> fetchOwnerUserId({
    required String merchantId,
  }) async {
    final merchantSnapshot =
        await _firestore.collection('merchants').doc(merchantId).get();
    if (!merchantSnapshot.exists) return null;
    final data = merchantSnapshot.data();
    return (data?['ownerUserId'] as String?)?.trim();
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
    final merchantRef = _firestore.collection('merchants').doc(merchantId);
    final signalsRef =
        _firestore.collection('merchant_operational_signals').doc(merchantId);

    await _firestore.runTransaction((transaction) async {
      final merchantSnapshot = await transaction.get(merchantRef);
      final merchantOwnerUserId =
          (merchantSnapshot.data()?['ownerUserId'] as String?)?.trim();
      if (merchantOwnerUserId == null || merchantOwnerUserId != ownerUserId) {
        throw const OwnerOperationalSignalsUnauthorizedException();
      }

      transaction.set(
        signalsRef,
        {
          ...payload,
          'sourceType': ownerOperationalSignalsSourceType,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        },
        SetOptions(merge: true),
      );
    });
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
    final isOwner = await validateOwnership(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
    );
    if (!isOwner) {
      throw const OwnerOperationalSignalsUnauthorizedException();
    }
    return _dataSource.fetchSignals(merchantId: merchantId);
  }

  Future<void> updateSignals({
    required String merchantId,
    required String ownerUserId,
    required Map<OperationalSignalKey, bool> values,
  }) async {
    if (values.isEmpty) return;
    await _dataSource.saveSignalsIfOwned(
      merchantId: merchantId,
      ownerUserId: ownerUserId,
      updatedBy: ownerUserId,
      values: values,
    );
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

  Future<bool> validateOwnership({
    required String merchantId,
    required String ownerUserId,
  }) async {
    if (merchantId.trim().isEmpty || ownerUserId.trim().isEmpty) return false;
    final merchantOwnerUserId = await _dataSource.fetchOwnerUserId(
      merchantId: merchantId,
    );
    if (merchantOwnerUserId == null) return false;
    return merchantOwnerUserId == ownerUserId;
  }
}
