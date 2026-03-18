import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../domain/duty_schedule_model.dart';

class DutyScheduleRepository {
  final FirebaseFirestore _db;

  DutyScheduleRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Streams today's duty schedules with their associated store names.
  Stream<List<DutyScheduleModel>> watchTodayDutySchedules() {
    return _db
        .collection('dutySchedules')
        .where('date', isEqualTo: _today)
        .where('status', whereNotIn: ['cancelled'])
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DutyScheduleModel.fromFirestore(doc))
            .toList());
  }

  /// Creates a new duty schedule.
  Future<void> createDutySchedule(DutyScheduleModel schedule) async {
    final data = schedule.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('dutySchedules').add(data);
  }

  /// Updates a duty schedule status.
  Future<void> updateStatus(String id, DutyStatus status) async {
    final statusStr = _statusToString(status);
    await _db.collection('dutySchedules').doc(id).update({
      'status': statusStr,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String _statusToString(DutyStatus s) {
    switch (s) {
      case DutyStatus.confirmed: return 'confirmed';
      case DutyStatus.modified: return 'modified';
      case DutyStatus.scheduled: return 'scheduled';
    }
  }
}
