import '../../../merchant_badges/domain/merchant_marker_resolver.dart';
import '../../models/merchant_search_item.dart';
import 'map_marker_type.dart';
import 'map_marker_visual_type.dart';

class MapMarkerResolver {
  const MapMarkerResolver._();

  static MapMarkerType resolveBaseType(MerchantSearchItem merchant) {
    return MerchantMarkerResolver.resolveMarkerType(merchant);
  }

  static MapMarkerVisualType resolveVisualType({
    required MapMarkerType baseType,
    required bool isSelected,
  }) {
    return MerchantMarkerResolver.resolveMarkerVisualType(
      baseType: baseType,
      isSelected: isSelected,
    );
  }

  static double resolveMarkerZIndex(MapMarkerVisualType type) {
    return MerchantMarkerResolver.resolveMarkerZIndex(type);
  }
}
