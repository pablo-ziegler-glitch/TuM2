import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/dtos/merchant_detail_dto.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';
import 'package:tum2/modules/merchant_detail/domain/merchant_maps.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_copy.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_page.dart';

import '../test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeMerchantDetailRepository repository,
    RecordingMerchantDetailAnalytics? analytics,
    RecordingMapsLauncher? mapsLauncher,
    FakeLocationReader? locationReader,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantDetailRepositoryProvider.overrideWithValue(repository),
          merchantDetailAnalyticsProvider.overrideWithValue(
            analytics ?? RecordingMerchantDetailAnalytics(),
          ),
          merchantMapsLauncherProvider.overrideWithValue(
            mapsLauncher ?? RecordingMapsLauncher(),
          ),
          merchantLocationReaderProvider.overrideWithValue(
            locationReader ?? FakeLocationReader(null),
          ),
        ],
        child: const MaterialApp(
          home: MerchantDetailPage(merchantId: 'merchant-1'),
        ),
      ),
    );
  }

  group('MerchantDetailPage widget states', () {
    testWidgets('loading critico', (tester) async {
      final repository = FakeMerchantDetailRepository();
      final coreCompleter = Completer<MerchantCoreDto?>();
      repository.fetchCoreHandler = (_) => coreCompleter.future;

      await pumpPage(tester, repository: repository);
      await tester.pump();

      expect(find.byKey(const Key('merchant_detail_loading_state')),
          findsOneWidget);
      expect(find.text(MerchantDetailCopy.loadingPrimary), findsOneWidget);
    });

    testWidgets('ready sin productos', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Farmacia Central'), findsOneWidget);
      expect(find.text(MerchantDetailCopy.emptyProducts), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async {
        throw TimeoutException('network timeout');
      };

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('merchant_detail_error_state')), findsOneWidget);
      expect(find.text(MerchantDetailCopy.connectionError), findsOneWidget);
    });

    testWidgets('not found', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_detail_not_found_state')),
          findsOneWidget);
      expect(find.text(MerchantDetailCopy.notFound), findsOneWidget);
    });

    testWidgets('horarios expandidos', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto();
      repository.fetchProductsHandler = (_, __) async => [];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      final expansionTile =
          find.byKey(const Key('merchant_schedule_expansion_tile'));
      expect(expansionTile, findsOneWidget);

      await tester.scrollUntilVisible(
        expansionTile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(expansionTile);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('schedule_day_monday')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Lunes'), findsOneWidget);
      expect(find.byKey(const Key('schedule_day_monday')), findsOneWidget);
    });
  });
}
