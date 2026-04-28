enum TrustBadgeId {
  verifiedMerchant('verified_merchant'),
  validatedInfo('validated_info'),
  claimedByOwner('claimed_by_owner'),
  communityInfo('community_info'),
  scheduleUpdated('schedule_updated'),
  scheduleVerified('schedule_verified'),
  dutyLoaded('duty_loaded');

  const TrustBadgeId(this.value);
  final String value;

  static TrustBadgeId? fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final badge in TrustBadgeId.values) {
      if (badge.value == normalized) return badge;
    }
    return null;
  }
}

List<TrustBadgeId> parseTrustBadges(dynamic raw) {
  if (raw is! List) return const <TrustBadgeId>[];
  final output = <TrustBadgeId>[];
  for (final item in raw) {
    final badge = TrustBadgeId.fromValue(item?.toString());
    if (badge != null && !output.contains(badge)) {
      output.add(badge);
    }
  }
  return output;
}

class MerchantScheduleSummary {
  const MerchantScheduleSummary({
    required this.isOpenNow,
    required this.source,
    required this.todayLabel,
  });

  final bool? isOpenNow;
  final String? source;
  final String? todayLabel;

  static MerchantScheduleSummary fromMap(Map<String, dynamic> map) {
    return MerchantScheduleSummary(
      isOpenNow: map['isOpenNow'] is bool ? map['isOpenNow'] as bool : null,
      source: map['source']?.toString(),
      todayLabel: map['todayLabel']?.toString(),
    );
  }
}
