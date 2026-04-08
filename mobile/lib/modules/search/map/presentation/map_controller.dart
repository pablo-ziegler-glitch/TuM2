import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/merchant_search_item.dart';
import '../cluster/map_cluster_factory.dart';
import '../cluster/map_cluster_model.dart';
import '../cluster/map_cluster_resolver.dart';
import '../marker/map_marker_factory.dart';
import 'map_state.dart';

class SearchMapController {
  SearchMapController({
    MapMarkerFactory? markerFactory,
    MapClusterResolver? clusterResolver,
    MapClusterFactory? clusterFactory,
  })  : _markerFactory = markerFactory ?? MapMarkerFactory(),
        _clusterResolver = clusterResolver ?? const MapClusterResolver(),
        _clusterFactory = clusterFactory ?? MapClusterFactory();

  final MapMarkerFactory _markerFactory;
  final MapClusterResolver _clusterResolver;
  final MapClusterFactory _clusterFactory;

  _MapComputationFingerprint? _lastFingerprint;
  SearchMapState? _lastState;

  static const _clusterActivationCount = 20;

  Future<SearchMapState> buildState({
    required List<MerchantSearchItem> merchants,
    required LatLngBounds? viewportBounds,
    required double zoom,
    required double pixelRatio,
    required String? selectedMerchantId,
    required void Function(String merchantId) onMerchantTap,
    required void Function(LatLng center, double nextZoom) onClusterTap,
  }) async {
    final visible = _visibleMerchants(
      merchants: merchants,
      bounds: viewportBounds,
    );

    final fingerprint = _MapComputationFingerprint(
      merchantsHash: _hashMerchants(visible),
      selectedMerchantId: selectedMerchantId,
      zoomBucket: zoom.floor(),
      boundsKey: _boundsKey(viewportBounds),
    );

    if (_lastFingerprint == fingerprint && _lastState != null) {
      return _lastState!;
    }

    final clusteringEnabled = visible.length > _clusterActivationCount;
    final markers = <Marker>{};

    if (!clusteringEnabled || viewportBounds == null) {
      final built = await Future.wait(
        visible.map(
          (merchant) => _buildIndividualMarker(
            merchant: merchant,
            selectedMerchantId: selectedMerchantId,
            pixelRatio: pixelRatio,
            onTap: onMerchantTap,
          ),
        ),
      );
      markers.addAll(built);
    } else {
      final clusters = _clusterResolver.resolveClusters(
        items: visible,
        bounds: viewportBounds,
        zoom: zoom,
      );
      final clusterMarkers = await Future.wait(
        clusters.map(
          (cluster) => _buildClusterOrSingleMarker(
            cluster: cluster,
            selectedMerchantId: selectedMerchantId,
            pixelRatio: pixelRatio,
            zoom: zoom,
            onMerchantTap: onMerchantTap,
            onClusterTap: onClusterTap,
          ),
        ),
      );
      markers.addAll(clusterMarkers);
    }

    final state = SearchMapState(
      markers: markers,
      clusteringEnabled: clusteringEnabled,
      visibleMerchants: visible.length,
      viewportBounds: viewportBounds,
    );

    _lastFingerprint = fingerprint;
    _lastState = state;
    return state;
  }

  Future<Marker> _buildIndividualMarker({
    required MerchantSearchItem merchant,
    required String? selectedMerchantId,
    required double pixelRatio,
    required void Function(String merchantId) onTap,
  }) async {
    final selected = selectedMerchantId == merchant.merchantId;
    final spec = _markerFactory.resolveSpec(
      merchant: merchant,
      isSelected: selected,
    );
    final icon = await _markerFactory.resolveIcon(
      visualType: spec.visualType,
      pixelRatio: pixelRatio,
    );

    return Marker(
      markerId: MarkerId('merchant_${merchant.merchantId}'),
      position: LatLng(merchant.lat!, merchant.lng!),
      icon: icon,
      zIndexInt: spec.zIndex.round(),
      onTap: () => onTap(merchant.merchantId),
    );
  }

  Future<Marker> _buildClusterOrSingleMarker({
    required MapCluster cluster,
    required String? selectedMerchantId,
    required double pixelRatio,
    required double zoom,
    required void Function(String merchantId) onMerchantTap,
    required void Function(LatLng center, double nextZoom) onClusterTap,
  }) async {
    if (cluster.count <= 1) {
      final merchant = cluster.items.first;
      return _buildIndividualMarker(
        merchant: merchant,
        selectedMerchantId: selectedMerchantId,
        pixelRatio: pixelRatio,
        onTap: onMerchantTap,
      );
    }

    final icon = await _clusterFactory.resolveIcon(
      priority: cluster.priority,
      count: cluster.count,
      pixelRatio: pixelRatio,
    );

    return Marker(
      markerId: MarkerId(
        'cluster_${cluster.center.latitude.toStringAsFixed(5)}_'
        '${cluster.center.longitude.toStringAsFixed(5)}_'
        '${cluster.count}',
      ),
      position: cluster.center,
      icon: icon,
      zIndexInt: _clusterZIndex(cluster.priority),
      onTap: () => onClusterTap(cluster.center, zoom + 2.0),
    );
  }

  int _clusterZIndex(MapClusterPriority priority) {
    switch (priority) {
      case MapClusterPriority.guardia:
        return 950;
      case MapClusterPriority.open:
        return 850;
      case MapClusterPriority.defaultState:
        return 750;
      case MapClusterPriority.closed:
        return 650;
    }
  }

  List<MerchantSearchItem> _visibleMerchants({
    required List<MerchantSearchItem> merchants,
    required LatLngBounds? bounds,
  }) {
    if (bounds == null) {
      return merchants
          .where((item) => item.lat != null && item.lng != null)
          .toList(growable: false);
    }
    return merchants.where((item) {
      if (item.lat == null || item.lng == null) return false;
      return _isInsideBounds(
        lat: item.lat!,
        lng: item.lng!,
        bounds: bounds,
      );
    }).toList(growable: false);
  }

  bool _isInsideBounds({
    required double lat,
    required double lng,
    required LatLngBounds bounds,
  }) {
    final south = bounds.southwest.latitude;
    final north = bounds.northeast.latitude;
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;

    final insideLat = lat >= south && lat <= north;
    final crossesDateLine = west > east;
    final insideLng = crossesDateLine
        ? (lng >= west || lng <= east)
        : (lng >= west && lng <= east);
    return insideLat && insideLng;
  }

  String _boundsKey(LatLngBounds? bounds) {
    if (bounds == null) return 'none';
    return '${bounds.southwest.latitude.toStringAsFixed(3)}:'
        '${bounds.southwest.longitude.toStringAsFixed(3)}:'
        '${bounds.northeast.latitude.toStringAsFixed(3)}:'
        '${bounds.northeast.longitude.toStringAsFixed(3)}';
  }

  int _hashMerchants(List<MerchantSearchItem> merchants) {
    return merchants.fold<int>(0, (hash, item) {
      final idHash = item.merchantId.hashCode;
      final openHash = item.isOpenNow.hashCode;
      final dutyHash = item.isOnDutyToday.hashCode;
      final h24Hash = item.is24h.hashCode;
      return (hash * 31) ^ idHash ^ openHash ^ dutyHash ^ h24Hash;
    });
  }
}

class _MapComputationFingerprint {
  const _MapComputationFingerprint({
    required this.merchantsHash,
    required this.selectedMerchantId,
    required this.zoomBucket,
    required this.boundsKey,
  });

  final int merchantsHash;
  final String? selectedMerchantId;
  final int zoomBucket;
  final String boundsKey;

  @override
  bool operator ==(Object other) {
    return other is _MapComputationFingerprint &&
        other.merchantsHash == merchantsHash &&
        other.selectedMerchantId == selectedMerchantId &&
        other.zoomBucket == zoomBucket &&
        other.boundsKey == boundsKey;
  }

  @override
  int get hashCode => Object.hash(
        merchantsHash,
        selectedMerchantId,
        zoomBucket,
        boundsKey,
      );
}
