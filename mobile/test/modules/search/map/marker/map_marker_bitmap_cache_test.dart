import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tum2/modules/search/map/marker/map_marker_bitmap_cache.dart';
import 'package:tum2/modules/search/map/marker/map_marker_visual_type.dart';

void main() {
  test('MapMarkerBitmapCache reutiliza misma instancia para misma key',
      () async {
    var calls = 0;
    final cache = MapMarkerBitmapCache(
      loader: (type, ratio) async {
        calls++;
        return BitmapDescriptor.defaultMarker;
      },
    );

    final a = cache.getOrCreate(
      visualType: MapMarkerVisualType.open,
      pixelRatio: 2.0,
    );
    final b = cache.getOrCreate(
      visualType: MapMarkerVisualType.open,
      pixelRatio: 2.0,
    );

    expect(identical(a, b), isTrue);
    await Future.wait([a, b]);
    expect(calls, 1);
    expect(cache.size, 1);
  });
}
