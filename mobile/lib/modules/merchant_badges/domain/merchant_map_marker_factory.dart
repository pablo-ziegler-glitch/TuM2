import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../search/map/marker/map_marker_factory.dart';
import '../../search/map/marker/map_marker_visual_type.dart';
import '../../search/models/merchant_search_item.dart';
import 'merchant_marker_resolver.dart';

class MerchantMapMarkerFactory {
  MerchantMapMarkerFactory({
    MapMarkerFactory? markerFactory,
  }) : _markerFactory = markerFactory ?? MapMarkerFactory();

  final MapMarkerFactory _markerFactory;

  MapMarkerSpec resolveSpec({
    required MerchantSearchItem merchant,
    required bool isSelected,
  }) {
    final markerType = MerchantMarkerResolver.resolveMarkerType(merchant);
    final visualType = MerchantMarkerResolver.resolveMarkerVisualType(
      baseType: markerType,
      isSelected: isSelected,
    );
    return MapMarkerSpec(
      baseType: markerType,
      visualType: visualType,
      zIndex: MerchantMarkerResolver.resolveMarkerZIndex(visualType),
    );
  }

  Future<BitmapDescriptor> resolveIcon({
    required MapMarkerVisualType visualType,
    required double pixelRatio,
  }) {
    return _markerFactory.resolveIcon(
      visualType: visualType,
      pixelRatio: pixelRatio,
    );
  }
}
