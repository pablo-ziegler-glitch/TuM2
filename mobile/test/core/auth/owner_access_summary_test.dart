import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/core/auth/owner_access_summary.dart';

void main() {
  test('parsea summary owner con pending concurrente', () {
    final summary = OwnerAccessSummary.fromMap({
      'summaryVersion': 1,
      'defaultMerchantId': 'merchant-1',
      'approvedMerchantIdsCount': 2,
      'pendingClaimMerchantIdsCount': 1,
      'hasConcurrentPendingClaims': true,
      'primaryContextMode': 'owner_with_pending',
      'restrictionState': 'none',
      'restrictionReasonCode': null,
      'blockedUntil': null,
    });

    expect(summary.defaultMerchantId, 'merchant-1');
    expect(summary.approvedMerchantIdsCount, 2);
    expect(summary.hasPendingClaims, isTrue);
    expect(
        summary.primaryContextMode, OwnerPrimaryContextMode.ownerWithPending);
    expect(summary.restrictionActive, isFalse);
  });

  test('cooldown expirado no se considera restricción activa', () {
    final summary = OwnerAccessSummary.fromMap({
      'summaryVersion': 1,
      'defaultMerchantId': null,
      'approvedMerchantIdsCount': 0,
      'pendingClaimMerchantIdsCount': 0,
      'hasConcurrentPendingClaims': false,
      'primaryContextMode': 'restricted',
      'restrictionState': 'cooldown',
      'restrictionReasonCode': 'insufficient_evidence',
      'blockedUntil': DateTime.now().subtract(const Duration(minutes: 1)),
    });

    expect(summary.restrictionState, OwnerRestrictionState.cooldown);
    expect(summary.restrictionActive, isFalse);
  });
}
