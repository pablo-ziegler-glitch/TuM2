import '../../home/models/open_now_models.dart';
import '../../pharmacy/models/pharmacy_duty_item.dart';
import '../../search/models/merchant_search_item.dart';
import 'merchant_marker_resolver.dart';
import 'operational_status_resolver.dart';
import 'merchant_visual_models.dart';

class MerchantVisualStateMappers {
  const MerchantVisualStateMappers._();

  static MerchantVisualState fromSearchItem(MerchantSearchItem item) {
    return MerchantVisualStateMapper.fromSearchItem(item);
  }

  static MerchantVisualState fromOpenNowMerchant(OpenNowMerchant merchant) {
    final resolvedOperational = resolveOperationalStatus(
      now: DateTime.now(),
      merchant: MerchantOperationalProjection(
        scheduleSummary: merchant.scheduleSummary,
        nextOpenAt: merchant.nextOpenAt,
        nextCloseAt: merchant.nextCloseAt,
        nextTransitionAt: merchant.nextTransitionAt,
        hasOperationalSignal: merchant.hasOperationalSignal,
        operationalSignalType: merchant.operationalSignalType,
        operationalStatusLabel: merchant.operationalStatusLabel,
      ),
    );

    return MerchantVisualState(
      visibility: _visibility(merchant.visibilityStatus),
      lifecycle: MerchantLifecycleState.active,
      confidence: _confidence(merchant.verificationStatus),
      opening:
          resolvedOperational.type == ResolvedOperationalStatusType.openNow ||
                  resolvedOperational.type ==
                      ResolvedOperationalStatusType.closingSoon
              ? MerchantOpeningState.openNow
              : MerchantOpeningState.closed,
      guardState: _guard(
        isOnDuty: merchant.isOnDutyToday,
        publicStatusLabel: merchant.publicStatusLabel,
      ),
      operationalSignal: _operational(merchant.operationalSignalType),
      show24hBadge: merchant.is24h == true,
      twentyFourHourCooldownActive:
          _isCooldownActive(merchant.twentyFourHourCooldownUntil),
      categoryLabel:
          merchant.categoryName.trim().isEmpty ? null : merchant.categoryName,
      claimState: null,
      hasSufficientScheduleInfo:
          merchant.scheduleSummary?.hasSchedule == true ||
              merchant.effectiveScheduleLabel.trim().isNotEmpty,
      manualOverrideMode: merchant.manualOverrideMode,
      informational: merchant.manualOverrideMode == 'informational',
    );
  }

  static MerchantVisualState fromPharmacyDutyItem(PharmacyDutyItem item) {
    return MerchantVisualState(
      visibility: MerchantVisibilityState.visible,
      lifecycle: MerchantLifecycleState.active,
      confidence: _confidence(item.verificationStatus),
      opening: (item.isOpenNow || item.is24Hours)
          ? MerchantOpeningState.openNow
          : MerchantOpeningState.closed,
      guardState: MerchantPharmacyGuardState.onDuty,
      operationalSignal: MerchantOperationalSignalState.none,
      show24hBadge: item.is24Hours,
      twentyFourHourCooldownActive: false,
      categoryLabel: 'Farmacia',
      claimState: null,
      hasSufficientScheduleInfo: true,
      manualOverrideMode: 'none',
      informational: false,
    );
  }

  static MerchantVisibilityState _visibility(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'visible':
        return MerchantVisibilityState.visible;
      case 'review_pending':
        return MerchantVisibilityState.reviewPending;
      case 'suppressed':
        return MerchantVisibilityState.suppressed;
      default:
        return MerchantVisibilityState.hidden;
    }
  }

  static MerchantConfidenceState _confidence(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'verified':
        return MerchantConfidenceState.verified;
      case 'validated':
        return MerchantConfidenceState.validated;
      case 'claimed':
        return MerchantConfidenceState.claimed;
      case 'community_submitted':
        return MerchantConfidenceState.communitySubmitted;
      case 'referential':
        return MerchantConfidenceState.referential;
      default:
        return MerchantConfidenceState.unverified;
    }
  }

  static MerchantOperationalSignalState _operational(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'vacation':
        return MerchantOperationalSignalState.vacation;
      case 'temporary_closure':
        return MerchantOperationalSignalState.temporaryClosure;
      case 'delay':
        return MerchantOperationalSignalState.opensLater;
      default:
        return MerchantOperationalSignalState.none;
    }
  }

  static MerchantPharmacyGuardState _guard({
    required bool isOnDuty,
    required String? publicStatusLabel,
  }) {
    final label = (publicStatusLabel ?? '').trim().toLowerCase();
    if (label == 'guardia_en_verificacion') {
      return MerchantPharmacyGuardState.guardVerification;
    }
    if (label == 'cambio_operativo_en_curso') {
      return MerchantPharmacyGuardState.guardOperationalChange;
    }
    if (isOnDuty) return MerchantPharmacyGuardState.onDuty;
    return MerchantPharmacyGuardState.none;
  }

  static bool _isCooldownActive(DateTime? cooldownUntil) {
    if (cooldownUntil == null) return false;
    return cooldownUntil.isAfter(DateTime.now());
  }
}
