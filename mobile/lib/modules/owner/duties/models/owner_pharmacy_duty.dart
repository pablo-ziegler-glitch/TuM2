import 'package:cloud_firestore/cloud_firestore.dart';

enum OwnerPharmacyDutyStatus { draft, published, cancelled }

OwnerPharmacyDutyStatus statusFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'published':
      return OwnerPharmacyDutyStatus.published;
    case 'cancelled':
      return OwnerPharmacyDutyStatus.cancelled;
    default:
      return OwnerPharmacyDutyStatus.draft;
  }
}

String statusToString(OwnerPharmacyDutyStatus status) {
  switch (status) {
    case OwnerPharmacyDutyStatus.published:
      return 'published';
    case OwnerPharmacyDutyStatus.cancelled:
      return 'cancelled';
    case OwnerPharmacyDutyStatus.draft:
      return 'draft';
  }
}

class OwnerPharmacyDuty {
  const OwnerPharmacyDuty({
    required this.id,
    required this.dateKey,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final String dateKey;
  final DateTime startsAt;
  final DateTime endsAt;
  final OwnerPharmacyDutyStatus status;
  final DateTime? updatedAt;
  final String? notes;

  factory OwnerPharmacyDuty.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    DateTime? parseNullable(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    return OwnerPharmacyDuty(
      id: id,
      dateKey: (data['date'] as String?)?.trim() ?? '',
      startsAt: parseDate(data['startsAt']),
      endsAt: parseDate(data['endsAt']),
      status: statusFromString((data['status'] as String?) ?? ''),
      updatedAt: parseNullable(data['updatedAt']),
      notes: (data['notes'] as String?)?.trim(),
    );
  }
}
