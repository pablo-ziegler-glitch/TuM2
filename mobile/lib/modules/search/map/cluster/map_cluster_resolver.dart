import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/merchant_search_item.dart';
import '../marker/map_marker_resolver.dart';
import '../marker/map_marker_type.dart';
import 'map_cluster_model.dart';

class MapClusterResolver {
  const MapClusterResolver();

  List<MapCluster> resolveClusters({
    required List<MerchantSearchItem> items,
    required LatLngBounds bounds,
    required double zoom,
  }) {
    if (items.isEmpty) return const [];

    final grid = _gridDimensionForZoom(zoom);
    final cells = <String, List<MerchantSearchItem>>{};

    for (final item in items) {
      if (item.lat == null || item.lng == null) continue;
      final key = _cellKey(
        lat: item.lat!,
        lng: item.lng!,
        bounds: bounds,
        columns: grid.columns,
        rows: grid.rows,
      );
      cells.putIfAbsent(key, () => <MerchantSearchItem>[]).add(item);
    }

    return cells.values
        .map(
          (cellItems) => MapCluster(
            center: _center(cellItems),
            items: cellItems,
            count: cellItems.length,
            priority: _resolvePriority(cellItems),
          ),
        )
        .toList(growable: false);
  }

  ({int columns, int rows}) _gridDimensionForZoom(double zoom) {
    if (zoom >= 16) return (columns: 10, rows: 10);
    if (zoom >= 14) return (columns: 8, rows: 8);
    if (zoom >= 12) return (columns: 6, rows: 6);
    return (columns: 4, rows: 4);
  }

  String _cellKey({
    required double lat,
    required double lng,
    required LatLngBounds bounds,
    required int columns,
    required int rows,
  }) {
    final latMin = bounds.southwest.latitude;
    final latMax = bounds.northeast.latitude;
    final lngMin = bounds.southwest.longitude;
    final lngMax = bounds.northeast.longitude;

    final safeLatSpan =
        (latMax - latMin).abs() < 0.000001 ? 0.000001 : (latMax - latMin).abs();
    final rawLngSpan = (lngMax - lngMin).abs();
    final safeLngSpan = rawLngSpan < 0.000001 ? 0.000001 : rawLngSpan;

    final row =
        (((lat - latMin) / safeLatSpan) * rows).floor().clamp(0, rows - 1);
    final col = (((lng - lngMin) / safeLngSpan) * columns)
        .floor()
        .clamp(0, columns - 1);

    return '$row:$col';
  }

  LatLng _center(List<MerchantSearchItem> items) {
    var sumLat = 0.0;
    var sumLng = 0.0;
    var count = 0;
    for (final item in items) {
      if (item.lat == null || item.lng == null) continue;
      sumLat += item.lat!;
      sumLng += item.lng!;
      count++;
    }
    if (count == 0) return const LatLng(0, 0);
    return LatLng(sumLat / count, sumLng / count);
  }

  MapClusterPriority _resolvePriority(List<MerchantSearchItem> items) {
    var guardia = 0;
    var open = 0;
    var closed = 0;
    var defaultState = 0;

    for (final item in items) {
      final type = MapMarkerResolver.resolveBaseType(item);
      switch (type) {
        case MapMarkerType.guardia:
          guardia++;
          break;
        case MapMarkerType.open:
        case MapMarkerType.open24h:
          open++;
          break;
        case MapMarkerType.closed:
          closed++;
          break;
        case MapMarkerType.defaultState:
          defaultState++;
          break;
      }
    }

    if (guardia > 0) {
      return MapClusterPriority.guardia;
    }
    if (open > defaultState && open > closed) {
      return MapClusterPriority.open;
    }
    if (closed > open && closed > defaultState) {
      return MapClusterPriority.closed;
    }
    return MapClusterPriority.defaultState;
  }
}
