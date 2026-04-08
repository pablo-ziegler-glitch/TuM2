import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/merchant_search_item.dart';

enum MapClusterPriority {
  guardia,
  open,
  defaultState,
  closed,
}

class MapCluster {
  const MapCluster({
    required this.center,
    required this.items,
    required this.count,
    required this.priority,
  });

  final LatLng center;
  final List<MerchantSearchItem> items;
  final int count;
  final MapClusterPriority priority;
}
