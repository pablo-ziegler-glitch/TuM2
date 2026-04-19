import '../../search/models/merchant_search_item.dart';
import '../../search/map/cluster/map_cluster_model.dart';
import '../../search/map/marker/map_marker_type.dart';
import '../../search/map/marker/map_marker_visual_type.dart';
import 'merchant_badge_resolver.dart';
import 'merchant_visual_models.dart';

class MerchantMarkerResolver {
  const MerchantMarkerResolver._();

  static MapMarkerType resolveMarkerType(MerchantSearchItem merchant) {
    final resolution = MerchantBadgeResolver.resolve(
      state: MerchantVisualStateMapper.fromSearchItem(merchant),
      surface: MerchantSurface.mapMarker,
    );
    final primary = resolution.primary;

    if (primary == MerchantBadgeKey.onDuty ||
        primary == MerchantBadgeKey.guardVerification ||
        primary == MerchantBadgeKey.operationalChange) {
      return MapMarkerType.guardia;
    }

    final has24h = merchant.is24h == true;
    if (primary == MerchantBadgeKey.openNow && has24h) {
      return MapMarkerType.open24h;
    }
    if (primary == MerchantBadgeKey.openNow) {
      return MapMarkerType.open;
    }
    if (primary == MerchantBadgeKey.closed ||
        primary == MerchantBadgeKey.closedForVacation ||
        primary == MerchantBadgeKey.temporaryClosure ||
        primary == MerchantBadgeKey.opensLater) {
      return MapMarkerType.closed;
    }
    return MapMarkerType.defaultState;
  }

  static MapMarkerVisualType resolveMarkerVisualType({
    required MapMarkerType baseType,
    required bool isSelected,
  }) {
    if (!isSelected) {
      switch (baseType) {
        case MapMarkerType.guardia:
          return MapMarkerVisualType.guardia;
        case MapMarkerType.open:
          return MapMarkerVisualType.open;
        case MapMarkerType.open24h:
          return MapMarkerVisualType.open24h;
        case MapMarkerType.defaultState:
          return MapMarkerVisualType.defaultState;
        case MapMarkerType.closed:
          return MapMarkerVisualType.closed;
      }
    }
    switch (baseType) {
      case MapMarkerType.guardia:
        return MapMarkerVisualType.selectedGuardia;
      case MapMarkerType.open:
        return MapMarkerVisualType.selectedOpen;
      case MapMarkerType.open24h:
        return MapMarkerVisualType.selectedOpen24h;
      case MapMarkerType.defaultState:
        return MapMarkerVisualType.selectedDefaultState;
      case MapMarkerType.closed:
        return MapMarkerVisualType.selectedClosed;
    }
  }

  static double resolveMarkerZIndex(MapMarkerVisualType type) {
    final selectedBoost = _isSelected(type) ? 1000 : 0;
    final base = switch (_baseTypeFromVisual(type)) {
      MapMarkerType.guardia => 500.0,
      MapMarkerType.open => 400.0,
      MapMarkerType.open24h => 300.0,
      MapMarkerType.defaultState => 200.0,
      MapMarkerType.closed => 100.0,
    };
    return base + selectedBoost;
  }

  static MapClusterPriority resolveClusterPriority(
      List<MerchantSearchItem> items) {
    var hasOnDuty = false;
    var has24h = false;
    var hasOpen = false;

    for (final item in items) {
      final type = resolveMarkerType(item);
      if (type == MapMarkerType.guardia) hasOnDuty = true;
      if (type == MapMarkerType.open24h) has24h = true;
      if (type == MapMarkerType.open || type == MapMarkerType.open24h) {
        hasOpen = true;
      }
    }

    if (hasOnDuty) return MapClusterPriority.red;
    if (has24h) return MapClusterPriority.blue;
    if (hasOpen) return MapClusterPriority.green;
    return MapClusterPriority.neutral;
  }

  static bool _isSelected(MapMarkerVisualType type) {
    switch (type) {
      case MapMarkerVisualType.selectedGuardia:
      case MapMarkerVisualType.selectedOpen:
      case MapMarkerVisualType.selectedOpen24h:
      case MapMarkerVisualType.selectedDefaultState:
      case MapMarkerVisualType.selectedClosed:
        return true;
      case MapMarkerVisualType.guardia:
      case MapMarkerVisualType.open:
      case MapMarkerVisualType.open24h:
      case MapMarkerVisualType.defaultState:
      case MapMarkerVisualType.closed:
        return false;
    }
  }

  static MapMarkerType _baseTypeFromVisual(MapMarkerVisualType type) {
    switch (type) {
      case MapMarkerVisualType.guardia:
      case MapMarkerVisualType.selectedGuardia:
        return MapMarkerType.guardia;
      case MapMarkerVisualType.open:
      case MapMarkerVisualType.selectedOpen:
        return MapMarkerType.open;
      case MapMarkerVisualType.open24h:
      case MapMarkerVisualType.selectedOpen24h:
        return MapMarkerType.open24h;
      case MapMarkerVisualType.defaultState:
      case MapMarkerVisualType.selectedDefaultState:
        return MapMarkerType.defaultState;
      case MapMarkerVisualType.closed:
      case MapMarkerVisualType.selectedClosed:
        return MapMarkerType.closed;
    }
  }
}

class MerchantVisualStateMapper {
  const MerchantVisualStateMapper._();

  static MerchantVisualState fromSearchItem(MerchantSearchItem item) {
    return MerchantVisualState(
      visibility: _visibility(item.visibilityStatus),
      lifecycle: MerchantLifecycleState.active,
      confidence: _confidence(item.verificationStatus),
      opening: _opening(item.isOpenNow),
      guardState: _guardState(item),
      operationalSignal: _operational(item.operationalSignalType),
      show24hBadge: item.is24h == true,
      twentyFourHourCooldownActive:
          _isCooldownActive(item.twentyFourHourCooldownUntil),
      categoryLabel:
          item.categoryLabel.trim().isEmpty ? null : item.categoryLabel.trim(),
      claimState: null,
      hasSufficientScheduleInfo: item.openStatusLabel.trim().isNotEmpty,
      manualOverrideMode: item.manualOverrideMode,
      informational: item.manualOverrideMode == 'informational',
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

  static MerchantOpeningState _opening(bool? isOpenNow) {
    if (isOpenNow == true) return MerchantOpeningState.openNow;
    if (isOpenNow == false) return MerchantOpeningState.closed;
    return MerchantOpeningState.noInfo;
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

  static MerchantPharmacyGuardState _guardState(MerchantSearchItem item) {
    if (item.isOnDutyToday == true) return MerchantPharmacyGuardState.onDuty;
    final publicLabel = (item.publicStatusLabel ?? '').trim().toLowerCase();
    if (publicLabel == 'guardia_en_verificacion') {
      return MerchantPharmacyGuardState.guardVerification;
    }
    if (publicLabel == 'cambio_operativo_en_curso') {
      return MerchantPharmacyGuardState.guardOperationalChange;
    }
    return MerchantPharmacyGuardState.none;
  }

  static bool _isCooldownActive(DateTime? cooldownUntil) {
    if (cooldownUntil == null) return false;
    return cooldownUntil.isAfter(DateTime.now());
  }
}
