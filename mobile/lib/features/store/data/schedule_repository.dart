import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/schedule_model.dart';

class ScheduleRepository {
  final FirebaseFirestore _db;

  ScheduleRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _schedulesCollection(
          String storeId) =>
      _db.collection('stores').doc(storeId).collection('schedules');

  /// Streams the weekly schedule for a store.
  Stream<WeeklyScheduleModel?> watchSchedule(String storeId) {
    return _schedulesCollection(storeId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return WeeklyScheduleModel.fromFirestore(snap.docs.first);
    });
  }

  /// Saves (creates or updates) the weekly schedule for a store.
  Future<void> saveSchedule(
      String storeId, WeeklyScheduleModel schedule) async {
    final data = schedule.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final snap = await _schedulesCollection(storeId).limit(1).get();

    if (snap.docs.isEmpty) {
      // Create new schedule document
      await _schedulesCollection(storeId).add(data);
    } else {
      // Update existing
      await snap.docs.first.reference.update(data);
    }
  }
}
