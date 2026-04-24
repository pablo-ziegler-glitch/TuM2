import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tum2/modules/search/analytics/search_analytics.dart';
import 'package:tum2/modules/search/models/merchant_search_item.dart';
import 'package:tum2/modules/search/models/search_filters.dart';
import 'package:tum2/modules/search/models/search_zone_item.dart';
import 'package:tum2/modules/search/providers/search_notifier.dart';
import 'package:tum2/modules/search/repositories/merchant_search_repository.dart';
import 'package:tum2/modules/search/repositories/zone_search_repository.dart';

class _FakeMerchantRepository implements MerchantSearchDataSource {
  _FakeMerchantRepository(this.items);

  final List<MerchantSearchItem> items;

  @override
  Future<List<MerchantSearchItem>> fetchZoneCorpus(
    String zoneId, {
    List<String> visibilityStatuses = const ['visible', 'review_pending'],
  }) async {
    return items.where((item) => item.zoneId == zoneId).toList();
  }
}

class _FakeZoneRepository implements ZoneSearchDataSource {
  @override
  Future<List<SearchZoneItem>> fetchAvailableZones() async {
    return const [
      SearchZoneItem(zoneId: 'palermo', name: 'Palermo', cityId: 'caba'),
    ];
  }
}

class _NoopSearchAnalytics implements SearchAnalyticsSink {
  @override
  Future<void> logMapRecenterTapped({
    required String surface,
    required String zoneId,
  }) async {}

  @override
  Future<void> logMapSearchThisAreaTapped({
    required String surface,
    required String zoneId,
  }) async {}

  @override
  Future<void> logMapViewed({
    required String zoneId,
    required int resultCount,
  }) async {}

  @override
  Future<void> logMerchantCardImpression({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
    required String source,
  }) async {}

  @override
  Future<void> logMerchantDetailOpened({
    required String surface,
    required String zoneId,
    required String merchantId,
    required String categoryId,
    required String distanceBucket,
    required String source,
  }) async {}

  @override
  Future<void> logSearchExecuted({
    required String surface,
    required String zoneId,
    required int queryLength,
    required int resultsCount,
  }) async {}

  @override
  Future<void> logSearchFilterApplied({
    required String surface,
    required String zoneId,
    required String categoryId,
    required int resultCount,
  }) async {}

  @override
  Future<void> logSearchResultsViewed({
    required String surface,
    required String zoneId,
    required int resultsCount,
    required bool isOpenNowShown,
    required bool isOnDutyShown,
  }) async {}
}

MerchantSearchItem _item({
  required String id,
  required String name,
  required String categoryId,
  required bool? isOpenNow,
  required double sortBoost,
}) {
  return MerchantSearchItem(
    merchantId: id,
    name: name,
    categoryId: categoryId,
    categoryLabel: categoryId,
    zoneId: 'palermo',
    address: 'Av Santa Fe',
    lat: -34.58,
    lng: -58.42,
    verificationStatus: 'verified',
    visibilityStatus: 'visible',
    isOpenNow: isOpenNow,
    openStatusLabel: '',
    sortBoost: sortBoost,
    searchKeywords: const ['farmacia', 'nandu'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    ProviderContainer buildContainer(List<MerchantSearchItem> items) {
      return ProviderContainer(
        overrides: [
          merchantSearchRepositoryProvider.overrideWithValue(
            _FakeMerchantRepository(items),
          ),
          zoneSearchRepositoryProvider.overrideWithValue(_FakeZoneRepository()),
          searchAnalyticsProvider.overrideWithValue(_NoopSearchAnalytics()),
        ],
      );
    }

    test('normaliza query sin tildes', () async {
      final container = buildContainer([
        _item(
          id: 'm1',
          name: 'Farmácia Ñandú',
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBoost: 10,
        ),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(searchNotifierProvider.notifier);
      await notifier.setZone('palermo');
      await notifier.submitQuery('farmacia nandu');

      final state = container.read(searchNotifierProvider);
      expect(state.results.length, 1);
      expect(state.results.first.merchantId, 'm1');
    });

    test('query menor a 3 no filtra resultados', () async {
      final container = buildContainer([
        _item(
          id: 'm1',
          name: 'Farmacia Uno',
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBoost: 10,
        ),
        _item(
          id: 'm2',
          name: 'Kiosco Dos',
          categoryId: 'kiosk',
          isOpenNow: false,
          sortBoost: 5,
        ),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(searchNotifierProvider.notifier);
      await notifier.setZone('palermo');
      await notifier.submitQuery('fa');

      expect(container.read(searchNotifierProvider).results.length, 2);
    });

    test('openNow activo excluye isOpenNow == null', () async {
      final container = buildContainer([
        _item(
          id: 'm1',
          name: 'Abierto',
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBoost: 2,
        ),
        _item(
          id: 'm2',
          name: 'Cerrado',
          categoryId: 'pharmacy',
          isOpenNow: false,
          sortBoost: 9,
        ),
        _item(
          id: 'm3',
          name: 'Sin horario',
          categoryId: 'pharmacy',
          isOpenNow: null,
          sortBoost: 12,
        ),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(searchNotifierProvider.notifier);
      await notifier.setZone('palermo');
      notifier.setFilters(const SearchFilters(isOpenNow: true));

      final results = container.read(searchNotifierProvider).results;
      expect(results.map((e) => e.merchantId).toList(), ['m1']);
    });

    test('aplica filtros en cascada y orden por relevancia', () async {
      final container = buildContainer([
        _item(
          id: 'm1',
          name: 'Farmacia Alta',
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBoost: 100,
        ),
        _item(
          id: 'm2',
          name: 'Farmacia Media',
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBoost: 50,
        ),
        _item(
          id: 'm3',
          name: 'Kiosco',
          categoryId: 'kiosk',
          isOpenNow: true,
          sortBoost: 999,
        ),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(searchNotifierProvider.notifier);
      await notifier.setZone('palermo');
      notifier.setFilters(
        const SearchFilters(
          categoryId: 'pharmacy',
          isOpenNow: true,
          sortBy: SearchSortBy.sortBoost,
        ),
      );
      await notifier.submitQuery('farmacia');

      final results = container.read(searchNotifierProvider).results;
      expect(results.map((e) => e.merchantId).toList(), ['m1', 'm2']);
    });
  });
}
