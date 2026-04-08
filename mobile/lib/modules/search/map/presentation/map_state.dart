import 'package:google_maps_flutter/google_maps_flutter.dart';

class SearchMapState {
  const SearchMapState({
    required this.markers,
    required this.clusteringEnabled,
    required this.visibleMerchants,
    required this.viewportBounds,
  });

  final Set<Marker> markers;
  final bool clusteringEnabled;
  final int visibleMerchants;
  final LatLngBounds? viewportBounds;

  static const initial = SearchMapState(
    markers: {},
    clusteringEnabled: false,
    visibleMerchants: 0,
    viewportBounds: null,
  );
}
