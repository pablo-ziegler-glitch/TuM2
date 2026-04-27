import 'package:cloud_firestore/cloud_firestore.dart';

enum TrustBadgeId {
  visibleInTum2('visible_in_tum2'),
  scheduleUpdated('schedule_updated'),
  scheduleVerified('schedule_verified'),
  dutyLoaded('duty_loaded'),
  communityInfo('community_info'),
  claimedByOwner('claimed_by_owner'),
  validatedInfo('validated_info'),
  verifiedMerchant('verified_merchant');

  const TrustBadgeId(this.value);
  final String value;

  static TrustBadgeId? fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final badge in TrustBadgeId.values) {
      if (badge.value == normalized) return badge;
    }
    return null;
  }
}

String trustBadgeLabel(TrustBadgeId badge) {
  switch (badge) {
    case TrustBadgeId.visibleInTum2:
      return 'Visible en TuM2';
    case TrustBadgeId.scheduleUpdated:
      return 'Horario actualizado';
    case TrustBadgeId.scheduleVerified:
      return 'Horario verificado';
    case TrustBadgeId.dutyLoaded:
      return 'Turno cargado';
    case TrustBadgeId.communityInfo:
      return 'Informacion de la comunidad';
    case TrustBadgeId.claimedByOwner:
      return 'Gestionado por su dueno';
    case TrustBadgeId.validatedInfo:
      return 'Informacion validada';
    case TrustBadgeId.verifiedMerchant:
      return 'Comercio verificado';
  }
}

List<TrustBadgeId> parseTrustBadges(dynamic rawBadges) {
  if (rawBadges is! List) return const [];
  final out = <TrustBadgeId>[];
  for (final value in rawBadges) {
    if (value is! String) continue;
    final parsed = TrustBadgeId.fromValue(value);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

class MerchantScheduleSummaryWindow {
  const MerchantScheduleSummaryWindow({
    required this.opensAtLocalMinutes,
    required this.closesAtLocalMinutes,
  });

  final int opensAtLocalMinutes;
  final int closesAtLocalMinutes;

  factory MerchantScheduleSummaryWindow.fromMap(Map<String, dynamic> map) {
    return MerchantScheduleSummaryWindow(
      opensAtLocalMinutes: (map['opensAtLocalMinutes'] as num?)?.toInt() ?? 0,
      closesAtLocalMinutes: (map['closesAtLocalMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class MerchantScheduleSummary {
  const MerchantScheduleSummary({
    required this.timezone,
    required this.todayWindows,
    required this.hasSchedule,
    this.scheduleLastUpdatedAt,
    this.lastVerifiedAt,
  });

  final String timezone;
  final List<MerchantScheduleSummaryWindow> todayWindows;
  final bool hasSchedule;
  final DateTime? scheduleLastUpdatedAt;
  final DateTime? lastVerifiedAt;

  factory MerchantScheduleSummary.fromMap(Map<String, dynamic> map) {
    final rawWindows = map['todayWindows'];
    final windows = rawWindows is List
        ? rawWindows
            .whereType<Map<String, dynamic>>()
            .map(MerchantScheduleSummaryWindow.fromMap)
            .toList(growable: false)
        : const <MerchantScheduleSummaryWindow>[];
    return MerchantScheduleSummary(
      timezone:
          (map['timezone'] as String?)?.trim() ?? 'America/Argentina/Buenos_Aires',
      todayWindows: windows,
      hasSchedule: map['hasSchedule'] == true,
      scheduleLastUpdatedAt: _asDateTime(map['scheduleLastUpdatedAt']),
      lastVerifiedAt: _asDateTime(map['lastVerifiedAt']),
    );
  }
}

DateTime? _asDateTime(dynamic raw) {
  if (raw is Timestamp) return raw.toDate().toLocal();
  if (raw is DateTime) return raw.toLocal();
  if (raw is String) return DateTime.tryParse(raw)?.toLocal();
  return null;
}
