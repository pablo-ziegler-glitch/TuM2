import 'package:cloud_firestore/cloud_firestore.dart';

enum OwnerRestrictionState {
  none,
  cooldown,
  manualReviewOnly,
  blocked,
}

enum OwnerPrimaryContextMode {
  customer,
  ownerSingle,
  ownerMulti,
  ownerWithPending,
  ownerPendingOnly,
  restricted,
}

class OwnerAccessSummary {
  const OwnerAccessSummary({
    required this.summaryVersion,
    required this.defaultMerchantId,
    required this.approvedMerchantIdsCount,
    required this.pendingClaimMerchantIdsCount,
    required this.hasConcurrentPendingClaims,
    required this.primaryContextMode,
    required this.restrictionState,
    required this.restrictionReasonCode,
    required this.blockedUntil,
  });

  final int summaryVersion;
  final String? defaultMerchantId;
  final int approvedMerchantIdsCount;
  final int pendingClaimMerchantIdsCount;
  final bool hasConcurrentPendingClaims;
  final OwnerPrimaryContextMode primaryContextMode;
  final OwnerRestrictionState restrictionState;
  final String? restrictionReasonCode;
  final DateTime? blockedUntil;

  bool get hasApprovedMerchants => approvedMerchantIdsCount > 0;

  bool get hasPendingClaims => pendingClaimMerchantIdsCount > 0;

  bool get restrictionActive {
    if (restrictionState == OwnerRestrictionState.none) return false;
    if (restrictionState == OwnerRestrictionState.cooldown &&
        blockedUntil != null &&
        !blockedUntil!.isAfter(DateTime.now())) {
      return false;
    }
    if (restrictionState == OwnerRestrictionState.blocked &&
        blockedUntil != null &&
        !blockedUntil!.isAfter(DateTime.now())) {
      return false;
    }
    return true;
  }

  factory OwnerAccessSummary.fromMap(Map<String, dynamic>? raw) {
    final data = raw ?? const <String, dynamic>{};
    final defaultMerchantId = (data['defaultMerchantId'] as String?)?.trim();
    final restrictionRaw =
        (data['restrictionState'] as String?)?.trim().toLowerCase();
    final contextRaw =
        (data['primaryContextMode'] as String?)?.trim().toLowerCase();
    return OwnerAccessSummary(
      summaryVersion: _readNonNegativeInt(data['summaryVersion']) ?? 0,
      defaultMerchantId:
          (defaultMerchantId == null || defaultMerchantId.isEmpty)
              ? null
              : defaultMerchantId,
      approvedMerchantIdsCount:
          _readNonNegativeInt(data['approvedMerchantIdsCount']) ?? 0,
      pendingClaimMerchantIdsCount:
          _readNonNegativeInt(data['pendingClaimMerchantIdsCount']) ?? 0,
      hasConcurrentPendingClaims: data['hasConcurrentPendingClaims'] == true,
      primaryContextMode: switch (contextRaw) {
        'owner_single' => OwnerPrimaryContextMode.ownerSingle,
        'owner_multi' => OwnerPrimaryContextMode.ownerMulti,
        'owner_with_pending' => OwnerPrimaryContextMode.ownerWithPending,
        'owner_pending_only' => OwnerPrimaryContextMode.ownerPendingOnly,
        'restricted' => OwnerPrimaryContextMode.restricted,
        _ => OwnerPrimaryContextMode.customer,
      },
      restrictionState: switch (restrictionRaw) {
        'cooldown' => OwnerRestrictionState.cooldown,
        'manual_review_only' => OwnerRestrictionState.manualReviewOnly,
        'blocked' => OwnerRestrictionState.blocked,
        _ => OwnerRestrictionState.none,
      },
      restrictionReasonCode: (data['restrictionReasonCode'] as String?)?.trim(),
      blockedUntil: _readDateTime(data['blockedUntil']),
    );
  }

  static int? _readNonNegativeInt(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0 && value == value.toInt()) {
      return value.toInt();
    }
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
