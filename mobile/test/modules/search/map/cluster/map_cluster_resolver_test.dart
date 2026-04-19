import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tum2/modules/search/map/cluster/map_cluster_model.dart';
import 'package:tum2/modules/search/map/cluster/map_cluster_resolver.dart';
import 'package:tum2/modules/search/models/merchant_search_item.dart';

MerchantSearchItem _merchant({
  required String id,
  required double lat,
  required double lng,
  bool? isOpenNow,
  bool? isOnDutyToday,
  bool? is24h,
}) {
  return MerchantSearchItem(
    merchantId: id,
    name: 'M$id',
    categoryId: 'pharmacy',
    categoryLabel: 'Farmacia',
    zoneId: 'palermo',
    address: 'Dir',
    lat: lat,
    lng: lng,
    verificationStatus: 'verified',
    visibilityStatus: 'visible',
    isOpenNow: isOpenNow,
    isOnDutyToday: isOnDutyToday,
    is24h: is24h,
    openStatusLabel: '',
    sortBoost: 10,
    searchKeywords: const ['farmacia'],
  );
}

void main() {
  const resolver = MapClusterResolver();
  final bounds = LatLngBounds(
    southwest: const LatLng(-34.62, -58.48),
    northeast: const LatLng(-34.54, -58.36),
  );

  test('agrupa por grilla', () {
    final clusters = resolver.resolveClusters(
      items: [
        _merchant(id: '1', lat: -34.60, lng: -58.46, isOpenNow: true),
        _merchant(id: '2', lat: -34.60, lng: -58.46, isOpenNow: true),
        _merchant(id: '3', lat: -34.56, lng: -58.38, isOpenNow: false),
      ],
      bounds: bounds,
      zoom: 13,
    );

    expect(clusters.length, greaterThanOrEqualTo(2));
    expect(clusters.any((cluster) => cluster.count >= 2), isTrue);
  });

  test('prioridad roja domina con de turno', () {
    final clusters = resolver.resolveClusters(
      items: [
        _merchant(id: '1', lat: -34.60, lng: -58.46, isOnDutyToday: true),
        _merchant(id: '2', lat: -34.6005, lng: -58.4605, isOpenNow: true),
      ],
      bounds: bounds,
      zoom: 17,
    );

    final cluster = clusters.firstWhere((cluster) => cluster.count == 2);
    expect(cluster.priority, MapClusterPriority.red);
  });

  test('prioridad verde cuando no hay turno ni 24hs', () {
    final clusters = resolver.resolveClusters(
      items: [
        _merchant(id: '1', lat: -34.60, lng: -58.46, isOpenNow: true),
        _merchant(id: '2', lat: -34.6004, lng: -58.4604, isOpenNow: true),
        _merchant(id: '3', lat: -34.6008, lng: -58.4608, isOpenNow: false),
      ],
      bounds: bounds,
      zoom: 17,
    );

    final cluster = clusters.firstWhere((item) => item.count == 3);
    expect(cluster.priority, MapClusterPriority.green);
  });

  test('prioridad azul cuando hay 24hs y no hay turno', () {
    final clusters = resolver.resolveClusters(
      items: [
        _merchant(
            id: '1', lat: -34.60, lng: -58.46, isOpenNow: true, is24h: true),
        _merchant(id: '2', lat: -34.6004, lng: -58.4604, isOpenNow: true),
      ],
      bounds: bounds,
      zoom: 17,
    );

    final cluster = clusters.firstWhere((item) => item.count == 2);
    expect(cluster.priority, MapClusterPriority.blue);
  });
}
