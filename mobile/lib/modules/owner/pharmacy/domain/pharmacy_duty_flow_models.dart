import 'package:cloud_firestore/cloud_firestore.dart';

enum PharmacyDutyIncidentType {
  powerOutage,
  staffShortage,
  technicalIssue,
  operationalIssue,
  other,
}

String incidentTypeToApiValue(PharmacyDutyIncidentType type) {
  switch (type) {
    case PharmacyDutyIncidentType.powerOutage:
      return 'power_outage';
    case PharmacyDutyIncidentType.staffShortage:
      return 'staff_shortage';
    case PharmacyDutyIncidentType.technicalIssue:
      return 'technical_issue';
    case PharmacyDutyIncidentType.operationalIssue:
      return 'operational_issue';
    case PharmacyDutyIncidentType.other:
      return 'other';
  }
}

String incidentTypeLabel(PharmacyDutyIncidentType type) {
  switch (type) {
    case PharmacyDutyIncidentType.powerOutage:
      return 'Corte de luz';
    case PharmacyDutyIncidentType.staffShortage:
      return 'Falta de personal';
    case PharmacyDutyIncidentType.technicalIssue:
      return 'Problema técnico';
    case PharmacyDutyIncidentType.operationalIssue:
      return 'Inconveniente operativo';
    case PharmacyDutyIncidentType.other:
      return 'Otro';
  }
}

class PharmacyDutyFlowSummary {
  const PharmacyDutyFlowSummary({
    required this.dutyId,
    required this.merchantId,
    required this.zoneId,
    required this.dateKey,
    required this.status,
    required this.confirmationStatus,
    required this.startsAt,
    required this.endsAt,
    required this.incidentOpen,
    required this.replacementRoundOpen,
    this.incidentId,
    this.replacementMerchantId,
  });

  final String dutyId;
  final String merchantId;
  final String zoneId;
  final String dateKey;
  final String status;
  final String confirmationStatus;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool incidentOpen;
  final bool replacementRoundOpen;
  final String? incidentId;
  final String? replacementMerchantId;

  bool get canConfirm => !incidentOpen && status != 'cancelled';
  bool get canReportIncident =>
      status != 'cancelled' && confirmationStatus != 'replaced';

  factory PharmacyDutyFlowSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return PharmacyDutyFlowSummary(
      dutyId: id,
      merchantId: (data['merchantId'] as String?)?.trim() ?? '',
      zoneId: (data['zoneId'] as String?)?.trim() ?? '',
      dateKey: (data['date'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'scheduled',
      confirmationStatus:
          (data['confirmationStatus'] as String?)?.trim() ?? 'pending',
      startsAt: parseDate(data['startsAt']),
      endsAt: parseDate(data['endsAt']),
      incidentOpen: data['incidentOpen'] == true,
      replacementRoundOpen: data['replacementRoundOpen'] == true,
      incidentId: (data['incidentId'] as String?)?.trim(),
      replacementMerchantId:
          (data['replacementMerchantId'] as String?)?.trim(),
    );
  }
}

class DutyReplacementCandidate {
  const DutyReplacementCandidate({
    required this.merchantId,
    required this.merchantName,
    required this.zoneId,
    required this.distanceKm,
    required this.distanceBucket,
  });

  final String merchantId;
  final String merchantName;
  final String zoneId;
  final double distanceKm;
  final String distanceBucket;

  factory DutyReplacementCandidate.fromMap(Map<String, dynamic> data) {
    return DutyReplacementCandidate(
      merchantId: (data['merchantId'] as String?)?.trim() ?? '',
      merchantName: (data['merchantName'] as String?)?.trim() ?? '',
      zoneId: (data['zoneId'] as String?)?.trim() ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      distanceBucket: (data['distanceBucket'] as String?)?.trim() ?? '',
    );
  }
}

class DutyReassignmentRound {
  const DutyReassignmentRound({
    required this.roundId,
    required this.dutyId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.acceptedMerchantId,
  });

  final String roundId;
  final String dutyId;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? acceptedMerchantId;

  factory DutyReassignmentRound.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    return DutyReassignmentRound(
      roundId: id,
      dutyId: (data['dutyId'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'open',
      createdAt: parseDate(data['createdAt']),
      expiresAt: parseDate(data['expiresAt']),
      acceptedMerchantId: (data['acceptedMerchantId'] as String?)?.trim(),
    );
  }
}

class DutyReassignmentRequestItem {
  const DutyReassignmentRequestItem({
    required this.requestId,
    required this.roundId,
    required this.dutyId,
    required this.originMerchantId,
    required this.candidateMerchantId,
    required this.status,
    required this.distanceKm,
    this.respondedAt,
    this.responseReason,
    this.expiresAt,
  });

  final String requestId;
  final String roundId;
  final String dutyId;
  final String originMerchantId;
  final String candidateMerchantId;
  final String status;
  final double distanceKm;
  final DateTime? respondedAt;
  final String? responseReason;
  final DateTime? expiresAt;

  factory DutyReassignmentRequestItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    return DutyReassignmentRequestItem(
      requestId: id,
      roundId: (data['roundId'] as String?)?.trim() ?? '',
      dutyId: (data['dutyId'] as String?)?.trim() ?? '',
      originMerchantId: (data['originMerchantId'] as String?)?.trim() ?? '',
      candidateMerchantId:
          (data['candidateMerchantId'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'pending',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      respondedAt: parseDate(data['respondedAt']),
      responseReason: (data['responseReason'] as String?)?.trim(),
      expiresAt: parseDate(data['expiresAt']),
    );
  }
}

class DutyInvitationDetail {
  const DutyInvitationDetail({
    required this.request,
    required this.duty,
    required this.originMerchantName,
  });

  final DutyReassignmentRequestItem request;
  final PharmacyDutyFlowSummary duty;
  final String originMerchantName;
}
