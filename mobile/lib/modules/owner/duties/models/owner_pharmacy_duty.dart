import 'package:cloud_firestore/cloud_firestore.dart';

enum OwnerPharmacyDutyStatus {
  scheduled,
  active,
  incidentReported,
  replacementPending,
  reassigned,
  cancelled,
}

enum OwnerPharmacyDutyConfirmationStatus {
  pending,
  confirmed,
  overdue,
  incidentReported,
  replaced,
}

OwnerPharmacyDutyStatus statusFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'active':
      return OwnerPharmacyDutyStatus.active;
    case 'incident_reported':
      return OwnerPharmacyDutyStatus.incidentReported;
    case 'replacement_pending':
      return OwnerPharmacyDutyStatus.replacementPending;
    case 'reassigned':
      return OwnerPharmacyDutyStatus.reassigned;
    case 'cancelled':
      return OwnerPharmacyDutyStatus.cancelled;
    case 'published':
    case 'draft':
    case 'scheduled':
    default:
      return OwnerPharmacyDutyStatus.scheduled;
  }
}

String statusToString(OwnerPharmacyDutyStatus status) {
  switch (status) {
    case OwnerPharmacyDutyStatus.scheduled:
      return 'scheduled';
    case OwnerPharmacyDutyStatus.active:
      return 'active';
    case OwnerPharmacyDutyStatus.incidentReported:
      return 'incident_reported';
    case OwnerPharmacyDutyStatus.replacementPending:
      return 'replacement_pending';
    case OwnerPharmacyDutyStatus.reassigned:
      return 'reassigned';
    case OwnerPharmacyDutyStatus.cancelled:
      return 'cancelled';
  }
}

OwnerPharmacyDutyConfirmationStatus confirmationStatusFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'confirmed':
      return OwnerPharmacyDutyConfirmationStatus.confirmed;
    case 'overdue':
      return OwnerPharmacyDutyConfirmationStatus.overdue;
    case 'incident_reported':
      return OwnerPharmacyDutyConfirmationStatus.incidentReported;
    case 'replaced':
      return OwnerPharmacyDutyConfirmationStatus.replaced;
    case 'pending':
    default:
      return OwnerPharmacyDutyConfirmationStatus.pending;
  }
}

class OwnerPharmacyDuty {
  const OwnerPharmacyDuty({
    required this.id,
    required this.dateKey,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.confirmationStatus,
    required this.updatedAt,
    this.notes,
    this.incidentOpen,
    this.replacementRoundOpen,
    this.replacementMerchantId,
  });

  final String id;
  final String dateKey;
  final DateTime startsAt;
  final DateTime endsAt;
  final OwnerPharmacyDutyStatus status;
  final OwnerPharmacyDutyConfirmationStatus confirmationStatus;
  final DateTime? updatedAt;
  final String? notes;
  final bool? incidentOpen;
  final bool? replacementRoundOpen;
  final String? replacementMerchantId;

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
      confirmationStatus: confirmationStatusFromString(
        (data['confirmationStatus'] as String?) ?? '',
      ),
      updatedAt: parseNullable(data['updatedAt']),
      notes: (data['notes'] as String?)?.trim(),
      incidentOpen: data['incidentOpen'] as bool?,
      replacementRoundOpen: data['replacementRoundOpen'] as bool?,
      replacementMerchantId: (data['replacementMerchantId'] as String?)?.trim(),
    );
  }
}
