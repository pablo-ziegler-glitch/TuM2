import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_actions.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';
import 'package:tum2/modules/merchant_detail/presentation/merchant_detail_page.dart';

import '../test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeMerchantDetailRepository repository,
    RecordingMerchantDetailAnalytics? analytics,
    FakeMerchantDetailActions? actions,
    FakeLocationReader? locationReader,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantDetailRepositoryProvider.overrideWithValue(repository),
          merchantDetailAnalyticsProvider.overrideWithValue(
            analytics ?? RecordingMerchantDetailAnalytics(),
          ),
          merchantDetailActionsProvider.overrideWithValue(
            actions ?? FakeMerchantDetailActions(),
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

  group('MerchantDetailPage', () {
    testWidgets('farmacia con guardia y endsAt', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            hasPharmacyDutyToday: true,
          );
      repository.fetchDutyHandler = (_) async => buildDutyDto(
            endsAt: DateTime(2026, 4, 7, 22, 0),
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pharmacy_duty_banner')), findsOneWidget);
      expect(find.textContaining('Guardia activa hasta las 22:00'),
          findsOneWidget);
      expect(find.byKey(const Key('merchant_cta_call')), findsOneWidget);
    });

    testWidgets('farmacia con guardia sin endsAt', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            hasPharmacyDutyToday: true,
          );
      repository.fetchDutyHandler = (_) async => buildDutyDto();
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pharmacy_duty_banner')), findsOneWidget);
      expect(
          find.text('Horario de finalización no disponible'), findsOneWidget);
    });

    testWidgets('comercio estandar', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            categoryId: 'kiosk',
            categoryLabel: 'Kioscos',
            hasPharmacyDutyToday: false,
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => buildScheduleDto();
      repository.fetchSignalsHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Kioscos'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('pharmacy_duty_banner')), findsNothing);
      expect(find.textContaining('Hoy: 09:00-20:00'), findsOneWidget);
    });

    testWidgets('comercio sin telefono', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            phonePrimary: null,
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;
      final actions = FakeMerchantDetailActions();

      await pumpPage(
        tester,
        repository: repository,
        actions: actions,
      );
      await tester.pumpAndSettle();

      final callCta = find.byKey(const Key('merchant_cta_call'));
      await tester.scrollUntilVisible(
        callCta,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(callCta);
      await tester.pumpAndSettle();

      expect(actions.callCount, 0);
    });

    testWidgets('comercio no visible/no encontrado', (tester) async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => null;

      await pumpPage(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_detail_not_found_state')),
          findsOneWidget);
    });
  });
}
