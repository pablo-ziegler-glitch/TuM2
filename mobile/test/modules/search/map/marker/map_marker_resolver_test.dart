import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/search/map/marker/map_marker_resolver.dart';
import 'package:tum2/modules/search/map/marker/map_marker_type.dart';
import 'package:tum2/modules/search/map/marker/map_marker_visual_type.dart';
import 'package:tum2/modules/search/models/merchant_search_item.dart';

MerchantSearchItem _merchant({
  bool? isOpenNow,
  bool? isOnDutyToday,
  bool? is24h,
  String openStatusLabel = '',
}) {
  return MerchantSearchItem(
    merchantId: 'm1',
    name: 'Farmacia Test',
    categoryId: 'pharmacy',
    categoryLabel: 'Farmacia',
    zoneId: 'palermo',
    address: 'Av Test 123',
    lat: -34.58,
    lng: -58.42,
    verificationStatus: 'verified',
    visibilityStatus: 'visible',
    isOpenNow: isOpenNow,
    isOnDutyToday: isOnDutyToday,
    is24h: is24h,
    openStatusLabel: openStatusLabel,
    sortBoost: 10,
    searchKeywords: const ['farmacia'],
  );
}

void main() {
  group('MapMarkerResolver.resolveBaseType', () {
    test('guardia gana a cualquier otro estado', () {
      final merchant = _merchant(
        isOnDutyToday: true,
        isOpenNow: true,
        is24h: true,
      );
      expect(
        MapMarkerResolver.resolveBaseType(merchant),
        MapMarkerType.guardia,
      );
    });

    test('open24h', () {
      final merchant = _merchant(isOpenNow: true, is24h: true);
      expect(
        MapMarkerResolver.resolveBaseType(merchant),
        MapMarkerType.open24h,
      );
    });

    test('open', () {
      final merchant = _merchant(isOpenNow: true, is24h: false);
      expect(MapMarkerResolver.resolveBaseType(merchant), MapMarkerType.open);
    });

    test('closed', () {
      final merchant = _merchant(isOpenNow: false);
      expect(MapMarkerResolver.resolveBaseType(merchant), MapMarkerType.closed);
    });

    test('default con null', () {
      final merchant = _merchant(isOpenNow: null, is24h: null);
      expect(
        MapMarkerResolver.resolveBaseType(merchant),
        MapMarkerType.defaultState,
      );
    });
  });

  group('MapMarkerResolver.resolveVisualType', () {
    test('selected false', () {
      final visual = MapMarkerResolver.resolveVisualType(
        baseType: MapMarkerType.open,
        isSelected: false,
      );
      expect(visual, MapMarkerVisualType.open);
    });

    test('selected true', () {
      final visual = MapMarkerResolver.resolveVisualType(
        baseType: MapMarkerType.open24h,
        isSelected: true,
      );
      expect(visual, MapMarkerVisualType.selectedOpen24h);
    });
  });

  group('MapMarkerResolver.resolveMarkerZIndex', () {
    test('guardia > open > open24h > default > closed', () {
      final guardia =
          MapMarkerResolver.resolveMarkerZIndex(MapMarkerVisualType.guardia);
      final open =
          MapMarkerResolver.resolveMarkerZIndex(MapMarkerVisualType.open);
      final open24h =
          MapMarkerResolver.resolveMarkerZIndex(MapMarkerVisualType.open24h);
      final defaultState = MapMarkerResolver.resolveMarkerZIndex(
          MapMarkerVisualType.defaultState);
      final closed =
          MapMarkerResolver.resolveMarkerZIndex(MapMarkerVisualType.closed);

      expect(guardia, greaterThan(open));
      expect(open, greaterThan(open24h));
      expect(open24h, greaterThan(defaultState));
      expect(defaultState, greaterThan(closed));
    });

    test('selected por encima de no seleccionado', () {
      final selected = MapMarkerResolver.resolveMarkerZIndex(
        MapMarkerVisualType.selectedClosed,
      );
      final unselected =
          MapMarkerResolver.resolveMarkerZIndex(MapMarkerVisualType.guardia);
      expect(selected, greaterThan(unselected));
    });
  });
}
