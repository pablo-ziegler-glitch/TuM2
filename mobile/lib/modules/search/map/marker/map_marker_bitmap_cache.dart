import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_marker_visual_type.dart';

typedef MarkerBitmapLoader = Future<BitmapDescriptor> Function(
  MapMarkerVisualType visualType,
  double pixelRatio,
);

class MapMarkerBitmapCache {
  MapMarkerBitmapCache({
    MarkerBitmapLoader? loader,
  }) : _loader = loader;

  final MarkerBitmapLoader? _loader;
  final Map<String, Future<BitmapDescriptor>> _entries = {};

  int get size => _entries.length;

  Future<BitmapDescriptor> getOrCreate({
    required MapMarkerVisualType visualType,
    required double pixelRatio,
    MarkerBitmapLoader? loader,
  }) {
    final key = '${visualType.name}@${pixelRatio.toStringAsFixed(2)}';
    return _entries.putIfAbsent(key, () {
      final effectiveLoader = loader ?? _loader;
      if (effectiveLoader == null) {
        throw StateError('MapMarkerBitmapCache requiere loader.');
      }
      return effectiveLoader(visualType, pixelRatio);
    });
  }

  void clear() {
    _entries.clear();
  }
}
