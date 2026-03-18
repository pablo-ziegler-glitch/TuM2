import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/signal_model.dart';

class SignalRepository {
  final FirebaseFirestore _db;

  SignalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _signalsCollection(
          String storeId) =>
      _db.collection('stores').doc(storeId).collection('operationalSignals');

  /// Streams all operational signals for a store.
  Stream<List<OperationalSignalModel>> watchSignals(String storeId) {
    return _signalsCollection(storeId).snapshots().map((snap) =>
        snap.docs
            .map((doc) => OperationalSignalModel.fromFirestore(doc))
            .toList());
  }

  /// Creates or updates an operational signal for a specific type.
  /// Only one signal per type is maintained per store.
  Future<void> setSignal({
    required String storeId,
    required SignalType signalType,
    required bool active,
    String notes = '',
  }) async {
    final typeString = OperationalSignalModel.typeToString(signalType);
    final snap = await _signalsCollection(storeId)
        .where('signalType', isEqualTo: typeString)
        .limit(1)
        .get();

    final data = {
      'storeId': storeId,
      'signalType': typeString,
      'status': active ? 'active' : 'inactive',
      'notes': notes,
      'sourceType': 'owner',
      'confidenceLevel': 'high',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (snap.docs.isEmpty) {
      data['id'] = typeString; // Use type as document ID for uniqueness
      await _signalsCollection(storeId).doc(typeString).set(data);
    } else {
      await snap.docs.first.reference.update(data);
    }
  }
}

// Add missing helper method
extension on OperationalSignalModel {
  static String typeToString(SignalType type) {
    switch (type) {
      case SignalType.hs24: return '24hs';
      case SignalType.lateNight: return 'late_night';
      case SignalType.specialHours: return 'special_hours';
      case SignalType.specialService: return 'special_service';
      case SignalType.nightDelivery: return 'night_delivery';
    }
  }
}
