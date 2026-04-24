import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tum2/modules/merchant_detail/analytics/merchant_detail_analytics.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_actions.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_controller.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_detail_state.dart';
import 'package:tum2/modules/merchant_detail/application/merchant_location_reader.dart';
import 'package:tum2/modules/merchant_detail/data/merchant_detail_repository.dart';

import '../test_fakes.dart';

void main() {
  group('MerchantDetailController', () {
    ProviderContainer buildContainer({
      required FakeMerchantDetailRepository repository,
      RecordingMerchantDetailAnalytics? analytics,
      FakeMerchantDetailActions? actions,
      FakeLocationReader? locationReader,
    }) {
      return ProviderContainer(
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
      );
    }

    test('farmacia con guardia y endsAt', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            hasPharmacyDutyToday: true,
          );
      repository.fetchDutyHandler = (_) async => buildDutyDto(
            endsAt: DateTime(2026, 4, 7, 23, 30),
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;
      final analytics = RecordingMerchantDetailAnalytics();

      final container = buildContainer(
        repository: repository,
        analytics: analytics,
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        merchantDetailControllerProvider('merchant-1'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = subscription.read().valueOrNull!;
      expect(state.merchant.hasPharmacyDutyToday, isTrue);
      expect(state.pharmacyDuty.valueOrNull?.endsAt, isNotNull);
      expect(analytics.dutyBannerEvents.single['hasEndsAt'], isTrue);
    });

    test('farmacia con guardia sin endsAt', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            hasPharmacyDutyToday: true,
          );
      repository.fetchDutyHandler = (_) async => buildDutyDto();
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);

      final subscription = container.listen(
        merchantDetailControllerProvider('merchant-1'),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = subscription.read().valueOrNull!;
      expect(state.pharmacyDuty.valueOrNull?.endsAt, isNull);
      expect(state.badge.label, 'Farmacia de turno');
    });

    test('comercio estandar', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            categoryId: 'kiosk',
            categoryLabel: 'Kioscos',
            hasPharmacyDutyToday: false,
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;

      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);

      final state = await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      expect(state.merchant.categoryLabel, 'Kioscos');
      expect(state.merchant.hasPharmacyDutyToday, isFalse);
      expect(state.pharmacyDuty.valueOrNull, isNull);
      expect(state.badge.label, 'Abierto ahora');
    });

    test('comercio sin telefono no dispara accion de llamada', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            phonePrimary: null,
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;
      final actions = FakeMerchantDetailActions();

      final container = buildContainer(
        repository: repository,
        actions: actions,
      );
      addTearDown(container.dispose);

      await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      await container
          .read(merchantDetailControllerProvider('merchant-1').notifier)
          .onCallTap();
      await container
          .read(merchantDetailControllerProvider('merchant-1').notifier)
          .onWhatsAppTap();

      expect(actions.callCount, 0);
      expect(actions.whatsappCount, 0);
    });

    test('comercio con telefono dispara accion de whatsapp', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => buildCoreDto(
            phonePrimary: '+54 11 5555-9999',
          );
      repository.fetchProductsHandler = (_, __, ___) async => [];
      repository.fetchScheduleHandler = (_) async => null;
      repository.fetchSignalsHandler = (_) async => null;
      final actions = FakeMerchantDetailActions();
      final analytics = RecordingMerchantDetailAnalytics();

      final container = buildContainer(
        repository: repository,
        actions: actions,
        analytics: analytics,
      );
      addTearDown(container.dispose);

      await container.read(
        merchantDetailControllerProvider('merchant-1').future,
      );
      await container
          .read(merchantDetailControllerProvider('merchant-1').notifier)
          .onWhatsAppTap();
      await Future<void>.delayed(Duration.zero);

      expect(actions.whatsappCount, 1);
      expect(analytics.whatsappEvents, isNotEmpty);
    });

    test('comercio no visible/no encontrado', () async {
      final repository = FakeMerchantDetailRepository();
      repository.fetchCoreHandler = (_) async => null;
      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);

      expect(
        () async => container.read(
          merchantDetailControllerProvider('merchant-1').future,
        ),
        throwsA(isA<MerchantDetailNotFoundException>()),
      );
    });
  });
}
