import 'package:cloud_firestore/cloud_firestore.dart';

enum DutyStatus { scheduled, confirmed, modified }

class DutyScheduleModel {
  final String id;
  final String storeId;
  final String date; // "YYYY-MM-DD"
  final String startTime;
  final String endTime;
  final DutyStatus status;
  final String notes;
  final String sourceType;
  final DateTime updatedAt;

  const DutyScheduleModel({
    required this.id,
    required this.storeId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.notes,
    required this.sourceType,
    required this.updatedAt,
  });

  factory DutyScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DutyScheduleModel(
      id: doc.id,
      storeId: data['storeId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '00:00',
      endTime: data['endTime'] as String? ?? '24:00',
      status: _parseStatus(data['status'] as String? ?? 'scheduled'),
      notes: data['notes'] as String? ?? '',
      sourceType: data['sourceType'] as String? ?? 'owner',
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static DutyStatus _parseStatus(String value) {
    switch (value) {
      case 'confirmed': return DutyStatus.confirmed;
      case 'modified': return DutyStatus.modified;
      default: return DutyStatus.scheduled;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'storeId': storeId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'status': _statusToString(status),
        'notes': notes,
        'sourceType': sourceType,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static String _statusToString(DutyStatus s) {
    switch (s) {
      case DutyStatus.confirmed: return 'confirmed';
      case DutyStatus.modified: return 'modified';
      case DutyStatus.scheduled: return 'scheduled';
    }
  }
}
