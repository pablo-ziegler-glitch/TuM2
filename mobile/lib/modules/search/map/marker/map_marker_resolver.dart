import '../../models/merchant_search_item.dart';
import 'map_marker_type.dart';
import 'map_marker_visual_type.dart';

class MapMarkerResolver {
  const MapMarkerResolver._();

  static MapMarkerType resolveBaseType(MerchantSearchItem merchant) {
    if (_isOnDutyToday(merchant)) return MapMarkerType.guardia;
    if (merchant.isOpenNow == true && _is24h(merchant)) {
      return MapMarkerType.open24h;
    }
    if (merchant.isOpenNow == true) return MapMarkerType.open;
    if (merchant.isOpenNow == false) return MapMarkerType.closed;
    return MapMarkerType.defaultState;
  }

  static MapMarkerVisualType resolveVisualType({
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

  static bool _isOnDutyToday(MerchantSearchItem merchant) {
    if (merchant.isOnDutyToday == true) return true;
    final statusLabel = merchant.openStatusLabel.toLowerCase();
    if (statusLabel.contains('guardia') || statusLabel.contains('turno')) {
      return true;
    }
    return merchant.searchKeywords.any((keyword) {
      final normalized = keyword.toLowerCase();
      return normalized.contains('guardia') || normalized.contains('turno');
    });
  }

  static bool _is24h(MerchantSearchItem merchant) {
    if (merchant.is24h == true) return true;
    final statusLabel = merchant.openStatusLabel.toLowerCase();
    if (statusLabel.contains('24')) return true;
    return merchant.searchKeywords.any((keyword) {
      final normalized = keyword.toLowerCase();
      return normalized.contains('24h') || normalized.contains('24hs');
    });
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
